/* Copyright (c) 2025 8891689
 * author： https://github.com/8891689
 */

#include <iostream>
#include <vector>
#include <string>
#include <cmath>
#include <chrono>
#include <cuda_runtime.h>
#include <stdexcept>
#include <iomanip>
#include <cstdlib> 
#include <ctime>   

#include "xxhash32.cuh"
#include "utils.h"
#include "passphrase.h"

#include "bip39.cuh"
#include "sha512.cuh"
#include "sha256.cuh"

// ============================================================================
// ============================================================================
int global_num_words = 12;
bool is_random_mode = false;
bool is_pubkey_mode = false;
uint8_t target_pubkey[65];
size_t target_pubkey_len = 0;

uint64_t opt_batch_size = 40000ULL;

bool opt_btc_bech32 = false; 
bool opt_btc_legacy = false; 
bool opt_btc_p2sh   = false; 
bool opt_eth  = false; 
bool opt_trx  = false; 
bool opt_ltc  = false; 
bool opt_doge = false; 
bool opt_dash = false; 
bool opt_bch  = false; 
bool opt_zec  = false; 
bool opt_btg  = false; 


__device__ bool check_target_gpu(const uint32_t* h160, const uint32_t* targets, int num_targets) {
    int low = 0, high = num_targets - 1;
    while (low <= high) {
        int mid = (low + high) / 2;
        const uint32_t* m_ptr = targets + (mid * 5);
        
        #pragma unroll
        for (int i = 0; i < 5; i++) {
            if (h160[i] < m_ptr[i]) { 
                high = mid - 1; 
                goto next_iteration; 
            }
            if (h160[i] > m_ptr[i]) { 
                low = mid + 1; 
                goto next_iteration; 
            }
        }
        return true; 
        
    next_iteration:;
    }
    return false;
}

#include "coin_kernels.cuh"


// ============================================================================
// ============================================================================
std::string abbreviate_mnemonic(const std::string& mnemonic) {
    std::vector<std::string> words;
    size_t start = 0, end = 0;
    while ((end = mnemonic.find(' ', start)) != std::string::npos) {
        if (end != start) words.push_back(mnemonic.substr(start, end - start));
        start = end + 1;
    }
    if (start < mnemonic.length()) words.push_back(mnemonic.substr(start));

    if (words.size() <= 8) return mnemonic;
    
    return words[0] + " " + words[1] + " " + words[2] + " " + words[3] + "..." +
           words[words.size()-4] + " " + words[words.size()-3] + " " + words[words.size()-2] + " " + words[words.size()-1];
}

// ============================================================================
// ============================================================================
void perform_recovery(const char *mnemonic_template, const char* target_str, const char* batch_file, PassphraseGenConfig& pass_cfg)
{
    std::string display_mnemonic = abbreviate_mnemonic(mnemonic_template);

    std::vector<uint32_t> h_targets;
    if (batch_file) {
        if (!load_targets_to_vector(batch_file, h_targets)) {
            fprintf(stderr, "[-] Failed to load targets from file: %s\n", batch_file);
            return;
        }
    } else {
        uint8_t h160_raw[20];
        if (target_address_to_hash160(target_str, h160_raw) == 0) {
            for(int k=0; k<5; k++) {
                uint32_t val = ((uint32_t)h160_raw[k*4] << 24) | ((uint32_t)h160_raw[k*4+1] << 16) | 
                               ((uint32_t)h160_raw[k*4+2] << 8) | ((uint32_t)h160_raw[k*4+3]);
                h_targets.push_back(val);
            }
        } else {
            fprintf(stderr, "[-] Invalid target address or hash format: %s\n", target_str);
            return;
        }
    }
    
    BloomFilter h_bloom;
    build_bloom_filter(h_targets, &h_bloom);
    
    double bloom_size_mb = (double)sizeof(h_bloom.bits) / (1024.0 * 1024.0);
    double target_size_mb = (double)(h_targets.size() * sizeof(uint32_t)) / (1024.0 * 1024.0);
    printf("[+] Loading complete!\n");
    printf("[+] Initial filter target hash: %.2f MB\n", bloom_size_mb);
    printf("[+] Target hash list size: %.2f MB\n", target_size_mb);
    
    uint32_t* d_bloom_bits;
    cudaMalloc(&d_bloom_bits, sizeof(h_bloom.bits));
    cudaMemcpy(d_bloom_bits, h_bloom.bits, sizeof(h_bloom.bits), cudaMemcpyHostToDevice);

    uint32_t* d_targets;
    cudaMalloc(&d_targets, h_targets.size() * sizeof(uint32_t));
    cudaMemcpy(d_targets, h_targets.data(), h_targets.size() * sizeof(uint32_t), cudaMemcpyHostToDevice);
    int num_targets = h_targets.size() / 5;

    RecoveryTask h_task;
    h_task.word_count = global_num_words;
    h_task.d_bloom_bits = d_bloom_bits; 
    
    if (mnemonic_to_indices(mnemonic_template, h_task.base_indices) <= 0) {
         fprintf(stderr, "[-] Invalid mnemonic template.\n"); return;
    }
    h_task.num_missing = 0;
    for(int i=0; i<h_task.word_count; ++i) {
        if (h_task.base_indices[i] == 0xFFFF) h_task.missing_pos[h_task.num_missing++] = i;
    }

    MatchResult* d_res;
    cudaMallocManaged(&d_res, sizeof(MatchResult));
    d_res->found = 0; 

    PassphraseGenConfig* d_pass_cfg;
    cudaMalloc(&d_pass_cfg, sizeof(PassphraseGenConfig));
    cudaMemcpy(d_pass_cfg, &pass_cfg, sizeof(PassphraseGenConfig), cudaMemcpyHostToDevice);

    u128 mnemonic_combos = 1;
    if (h_task.num_missing >= 11) {

        mnemonic_combos = ~((u128)0); 
    } else {
        for (int i = 0; i < h_task.num_missing; i++) mnemonic_combos *= 2048;
    }
    
    u128 pass_combos = pass_cfg.active ? pass_cfg.total_combinations : 1;
    h_task.total_work_items_per_coin = (uint64_t)(mnemonic_combos * pass_combos);

    printf("[+] Mnemonic combinations: "); print_u128(mnemonic_combos); printf("\n");
    printf("[+] Passphrase combos    : "); print_u128(pass_combos); printf("\n");
    
    auto start_time = std::chrono::high_resolution_clock::now();
    uint64_t total_checked = 0;

    uint32_t coin_mask = 0;
    if(opt_btc_bech32) coin_mask |= (1 << COIN_BTC_BECH32);
    if(opt_btc_legacy) coin_mask |= (1 << COIN_BTC_LEGACY);
    if(opt_btc_p2sh)   coin_mask |= (1 << COIN_BTC_P2SH);
    if(opt_eth)        coin_mask |= (1 << COIN_ETH);
    if(opt_trx)        coin_mask |= (1 << COIN_TRX);
    if(opt_ltc)        coin_mask |= (1 << COIN_LTC);
    if(opt_doge)       coin_mask |= (1 << COIN_DOGE);
    if(opt_dash)       coin_mask |= (1 << COIN_DASH);
    if(opt_bch)        coin_mask |= (1 << COIN_BCH);
    if(opt_zec)        coin_mask |= (1 << COIN_ZEC);
    if(opt_btg)        coin_mask |= (1 << COIN_BTG);
    
    if (coin_mask == 0) coin_mask |= (1 << COIN_BTC_BECH32); 

    printf("[+] Starting Mega-Kernel search for ALL selected coins simultaneously...\n");
    if (is_random_mode) {
        printf("[+] Search Mode: RANDOM (Infinite)\n");
    } else {
        printf("[+] Search Mode: LINEAR\n");
    }

    uint64_t m_combos_64 = (mnemonic_combos > 0xFFFFFFFFFFFFFFFFULL) ? 0xFFFFFFFFFFFFFFFFULL : (uint64_t)mnemonic_combos;
    uint64_t p_combos_64 = (uint64_t)pass_combos;
    uint64_t BATCH_LIMIT = opt_batch_size;

    if (is_random_mode) {
        srand((unsigned int)time(NULL));
        while (!d_res->found) {
            uint64_t r_m = m_combos_64 > 1 ? (((uint64_t)rand() << 32) ^ rand()) % m_combos_64 : 0;
            uint64_t r_p = p_combos_64 > 1 ? (((uint64_t)rand() << 32) ^ rand()) % p_combos_64 : 0;

            h_task.m_start_offset = r_m;
            h_task.p_start_offset = r_p;
            h_task.num_mnemonics_per_pass = m_combos_64;
            h_task.total_work_items_per_coin = BATCH_LIMIT; 

            dim3 threads(256);
            dim3 blocks((BATCH_LIMIT + threads.x - 1) / threads.x);

            mega_coin_kernel<<<blocks, threads>>>(h_task, d_pass_cfg, coin_mask, d_targets, num_targets, d_res);
            cudaDeviceSynchronize(); 
            
            total_checked += BATCH_LIMIT;
            
            auto current_time = std::chrono::high_resolution_clock::now();
            double elapsed = std::chrono::duration<double>(current_time - start_time).count();
            if (elapsed > 0.1) {
                double speed = total_checked / elapsed;
                printf("\r[+] Speed: %.0f / s | Checked: %llu | Mnemonic: %s   ", 
                       speed, (unsigned long long)total_checked, display_mnemonic.c_str());
                fflush(stdout);
            }
        }
    } else {
        if (m_combos_64 >= BATCH_LIMIT) {
            for (uint64_t p_offset = 0; p_offset < p_combos_64; p_offset++) {
                if (d_res->found) break;
                for (uint64_t m_offset = 0; m_offset < m_combos_64; m_offset += BATCH_LIMIT) {
                    if (d_res->found) break;

                    uint64_t current_m_batch = std::min(BATCH_LIMIT, m_combos_64 - m_offset);
                    h_task.m_start_offset = m_offset;
                    h_task.p_start_offset = p_offset;
                    h_task.num_mnemonics_per_pass = m_combos_64;
                    h_task.total_work_items_per_coin = current_m_batch;

                    dim3 threads(256);
                    dim3 blocks((current_m_batch + threads.x - 1) / threads.x);

                    mega_coin_kernel<<<blocks, threads>>>(h_task, d_pass_cfg, coin_mask, d_targets, num_targets, d_res);
                    cudaDeviceSynchronize(); 
                    
                    total_checked += current_m_batch;
                    
                    auto current_time = std::chrono::high_resolution_clock::now();
                    double elapsed = std::chrono::duration<double>(current_time - start_time).count();
                    if (elapsed > 0.1) {
                        double speed = total_checked / elapsed;
                        double progress = ((double)(p_offset * m_combos_64 + m_offset + current_m_batch) / (m_combos_64 * p_combos_64)) * 100.0;
                        printf("\r[+] Progress: %.2f%% | Speed: %.0f / s | Checked: %llu | Mnemonic: %s   ", 
                               progress, speed, (unsigned long long)total_checked, display_mnemonic.c_str());
                        fflush(stdout);
                    }
                }
            }
        } else {
            uint64_t pass_batch_size = std::max((uint64_t)1, BATCH_LIMIT / m_combos_64);
            for (uint64_t p_offset = 0; p_offset < p_combos_64; p_offset += pass_batch_size) {
                if (d_res->found) break;

                uint64_t passes_in_batch = std::min(pass_batch_size, p_combos_64 - p_offset);
                uint64_t total_work_items_in_batch = m_combos_64 * passes_in_batch;
                
                h_task.m_start_offset = 0;
                h_task.p_start_offset = p_offset;
                h_task.num_mnemonics_per_pass = m_combos_64;
                h_task.total_work_items_per_coin = total_work_items_in_batch;
                
                dim3 threads(256);
                dim3 blocks((total_work_items_in_batch + threads.x - 1) / threads.x);

                mega_coin_kernel<<<blocks, threads>>>(h_task, d_pass_cfg, coin_mask, d_targets, num_targets, d_res);
                cudaDeviceSynchronize(); 
                
                total_checked += total_work_items_in_batch;
                
                auto current_time = std::chrono::high_resolution_clock::now();
                double elapsed = std::chrono::duration<double>(current_time - start_time).count();
                if (elapsed > 0.1) {
                    double speed = total_checked / elapsed;
                    double progress = ((double)(p_offset + passes_in_batch) / p_combos_64) * 100.0;
                    printf("\r[+] Progress: %.2f%% | Speed: %.0f / s | Checked: %llu | Mnemonic: %s   ", 
                           progress, speed, (unsigned long long)total_checked, display_mnemonic.c_str());
                    fflush(stdout);
                }
            }
        }
    }
    
    if (d_res->found != 0) {
        MatchResult h_res;
        cudaMemcpy(&h_res, d_res, sizeof(MatchResult), cudaMemcpyDeviceToHost);
        format_and_print_result(&h_res, h_res.solved_indices, h_task.word_count);

        FILE *fp = fopen("found.txt", "a");
        if (fp) {
            char m_str[512];
            indices_to_mnemonic(h_res.solved_indices, h_task.word_count, m_str);
            fprintf(fp, "================ MATCH FOUND ================\n");
            fprintf(fp, "Mnemonic   : %s\n", m_str);
            fprintf(fp, "Passphrase : %s\n", strlen(h_res.solved_passphrase) > 0 ? h_res.solved_passphrase : "None");
            fprintf(fp, "PrivKey HEX: ");
            for(int i=0; i<32; i++) fprintf(fp, "%02x", h_res.solved_privkey_bytes[i]);
            fprintf(fp, "\n=============================================\n\n");
            fclose(fp);
            printf("\n[+] Success! Result saved to 'found.txt'\n");
        } else {
            printf("\n[-] Warning: Found match, but failed to save to 'found.txt' (Check permissions).\n");
        }
    } else {
        printf("\n[-] Search completed. No match found.\n");
    }

    cudaFree(d_targets);
    cudaFree(d_res);
    cudaFree(d_pass_cfg);
    cudaFree(d_bloom_bits);
}

// ============================================================================
// ============================================================================
int main(int argc, char *argv[]) {
        printf("[+] Version 2.1 Technical Support: https://www.8891689.com\n");
        printf("[+] Search Engine Initialization...\n");
    if (argc < 2 || strcmp(argv[1], "-h") == 0 || strcmp(argv[1], "--help") == 0) { 
        printf("====================================================================\n");
        printf(" GPU Mnemonic & Passphrase Recovery Tool\n");
        printf("====================================================================\n");
        printf("Usage: %s [options] [mnemonic_words...] [target_address]\n\n", argv[0]); 
        printf("Options:\n");
        printf("  -h, --help               Show this help message.\n");
        printf("  -R                       Infinite Random Mode (Guess words randomly forever).\n");
        printf("  -f <file>                Batch mode: Check against multiple addresses in a file.\n");
        printf("  -n <number>              Set GPU batch size (default: 40000, e.g., -n 50000).\n");
        printf("  -l <min-max>             Set Passphrase length range (e.g., -l 1-3).\n");
        printf("  -c <charset>             Set Passphrase charset. Built-in codes:\n");
        printf("                             'd' = digits (0-9)\n");
        printf("                             'u' = lowercase (a-z)\n");
        printf("                             'i' = uppercase (A-Z)\n");
        printf("                             's' = symbols (!@#$...)\n");
        printf("                           'all' = All types (0-9a-zA-Z!@#$...)\n");
        printf("                           * Can be combined (e.g., 'd,u' for lowercase + digits)\n");
        printf("  -12, -15, -18, -21, -24  Set the number of mnemonic words (default: -12).\n");
        printf("\nTarget Coin Types:\n");
        printf("  -bc1q                    BTC Native SegWit (Default)\n");
        printf("  -1                       BTC Legacy (P2PKH)\n");
        printf("  -3                       BTC P2SH\n");
        printf("  -eth                     Ethereum\n");
        printf("  -trx                     TRON\n");
        printf("  -doge, -ltc, -bch, -dash, -zec, -btg (Other supported coins)\n\n");
        printf("Example 1: %s -12 -eth word1 ? word3 ... 0xTargetAddress\n", argv[0]);
        printf("Example 2: %s \"word1 ? word3 ...\" -l 1-4 -c d,u -R -bc1q bc1qTarget...\n", argv[0]);
        printf("Example 3: %s -12 -eth -f hash160.all.txt...\n", argv[0]);
        printf("====================================================================\n");
        return 0; 
    }

    cudaSetDevice(0);
    sha512_setup_constants();
    sha256_setup_constants();
    
    static char flat_wordlist[2048][12];
    for (int i = 0; i < 2048; i++) {
        memset(flat_wordlist[i], 0, 12);
        const char* w = get_bip39_word(i); 
        if (w) {
            for (int j = 0; j < 11 && w[j] != '\0'; j++) {
                flat_wordlist[i][j] = w[j];
            }
        }
    }
    bip39_init_gpu_mem(flat_wordlist);

    PassphraseGenConfig pass_cfg;
    char *batch_file = NULL;
    char *charset_ids = NULL;
    int minL = 0, maxL = 0;
    bool pass_random = false;
    std::vector<std::string> free_args;

    for (int i = 1; i < argc; i++) {
         if (strcmp(argv[i], "-1") == 0) { opt_btc_legacy = true; }
         else if (strcmp(argv[i], "-3") == 0) { opt_btc_p2sh = true; }
         else if (strcmp(argv[i], "-bc1q") == 0) { opt_btc_bech32 = true; }
         else if (strcmp(argv[i], "-eth") == 0) { opt_eth = true; }
         else if (strcmp(argv[i], "-trx") == 0) { opt_trx = true; }
         else if (strcmp(argv[i], "-doge") == 0) { opt_doge = true; }
         else if (strcmp(argv[i], "-ltc") == 0) { opt_ltc = true; }
         else if (strcmp(argv[i], "-dash") == 0) { opt_dash = true; }
         else if (strcmp(argv[i], "-bch") == 0) { opt_bch = true; }
         else if (strcmp(argv[i], "-zec") == 0) { opt_zec = true; }
         else if (strcmp(argv[i], "-btg") == 0) { opt_btg = true; }
         else if (strcmp(argv[i], "-l") == 0 && i + 1 < argc) {
             char *range = argv[++i], *dash = strchr(range, '-');
             if (dash) { *dash = '\0'; minL = atoi(range); maxL = atoi(dash + 1); } else { minL = maxL = atoi(range); }
         }
         else if (strcmp(argv[i], "-c") == 0 && i + 1 < argc) { charset_ids = argv[++i]; }
         else if (strcmp(argv[i], "-PR") == 0) pass_random = true;
         else if (strcmp(argv[i], "-R") == 0) is_random_mode = true;
         else if (strcmp(argv[i], "-f") == 0 && i + 1 < argc) { batch_file = argv[++i]; }

         else if (strcmp(argv[i], "-n") == 0 && i + 1 < argc) { opt_batch_size = std::strtoull(argv[++i], nullptr, 10); }
         else if (argv[i][0] == '-' && isdigit(argv[i][1])) { 
             global_num_words = atoi(argv[i] + 1);
         }
         else { free_args.push_back(argv[i]); } 
    }

    if (!opt_btc_legacy && !opt_btc_p2sh && !opt_eth && !opt_trx && !opt_doge && !opt_ltc && !opt_dash && !opt_bch && !opt_zec && !opt_btg) {
        opt_btc_bech32 = true;
    }

    if (charset_ids && minL > 0) {
        if (!passphrase_init(pass_cfg, charset_ids, minL, maxL, pass_random)) {
            fprintf(stderr, "[-] Error: Passphrase config init failed.\n"); return 1;
        }
    } else { pass_cfg.active = false; }
    
    std::string mnemonic_arg = "";
    std::string target_arg = "";
    if (batch_file) {
        for(size_t i=0; i<free_args.size(); ++i) mnemonic_arg += (i > 0 ? " " : "") + free_args[i];
    } else {
        if (free_args.size() >= 1) {
            target_arg = free_args.back();
            free_args.pop_back();
            for(size_t i=0; i<free_args.size(); ++i) mnemonic_arg += (i > 0 ? " " : "") + free_args[i];
        } else {
            fprintf(stderr, "[-] Error: Target address/hash/pubkey is missing.\n"); return 1;
        }
    }
    
    if (mnemonic_arg.empty()) {

        for (int i = 0; i < global_num_words; i++) {
            mnemonic_arg += (i > 0 ? " " : "") + std::string("?");
        }
        
        printf("[+] No mnemonic provided. Auto-generating %d unknown words ('?').\n", global_num_words);
        
        if (!is_random_mode) {
             printf("[!] Warning: Full blind search requires Random Mode. Auto-enabling '-R'.\n");
             is_random_mode = true;
        }
    }

    perform_recovery(mnemonic_arg.c_str(), target_arg.c_str(), batch_file, pass_cfg);

    return 0;
}
