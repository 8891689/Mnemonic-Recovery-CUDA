<!--   -->
<p align="center">
  <img src="https://img.shields.io/badge/Utility-Multi--Coin%20HD%20Wallet%20Generator-purple?style=for-the-badge" alt="Multi-Coin HD Wallet Generator">
</p>

<!-- ⛓️   -->
<p align="center">
  <img src="https://img.shields.io/badge/Standards-BIP39%20%7C%2032%20%7C%2044%20%7C%2049%20%7C%2084-orange" alt="Supports BIP39/32/44/49/84">
  <img src="https://img.shields.io/badge/Chains-10+%20Supported%20(BTC,%20ETH,%20TRX...)-blue" alt="Supports 10+ Blockchains">
</p>

<!-- 🛠️   -->
<p align="center">
  <img src="https://img.shields.io/badge/Dependencies-None%20(Self--Contained)-brightgreen" alt="No Dependencies (Self-Contained)">
  <img src="https://img.shields.io/badge/Implementation-From%20Scratch%20in%20C-lightgrey" alt="Implemented from Scratch in C">
  <img src="https://img.shields.io/badge/Interface-CLI%20Tool-black" alt="Command Line Interface Tool">
</p>

<!--   -->
<p align="center">
  <a href="https://github.com/8891689/Mnemonic-Recovery-CUDA/commits/main"><img src="https://img.shields.io/github-last-commit/8891689/Mnemonic-converter" alt="Last Commit"></a>
  <a href="https://github.com/8891689/Mnemonic-Recovery-CUDA/stargazers"><img src="https://img.shields.io/github/stars/8891689/Mnemonic-converter?style=social" alt="GitHub Stars"></a>
  <a href="https://github.com/8891689/Mnemonic-Recovery-CUDA#sponsorship"><img src="https://img.shields.io/badge/Sponsor-❤️-red" alt="Sponsor Project"></a>
</p>

# Mnemonic-Recovery-CUDA

Developed in C and leveraging CUDA for high-performance computing, this software is designed to recover forgotten mnemonic phrases and passphrases. It supports a wide range of assets including BTC, ETH, TRX, DOGE, LTC, DASH, ZEC, BCH, and BTG, adhering to standard BIP32, BIP44, BIP49, and BIP84 derivation paths. The tool is capable of recovering mnemonic passwords and partial seed phrases using its integrated dictionary, offering an efficient and streamlined recovery process.


```
====================================================================
               GPU Mnemonic & Passphrase Recovery Tool
====================================================================
[+] Version 2.1 Technical Support: https://www.8891689.com
[+] Recovered? Please donate 1% to support us. Thanks!
[+] Search Engine Initialization...
[+] Usage: ./m [options] [mnemonic_words...] [target_address]

[+] Options:
            -h, --help               Show this help message.
            -R                       Infinite Random Mode (Guess words randomly forever).
            -g <device_id>           Select GPU device ID (default: 0).
            -f <file>                Batch mode: Check against multiple addresses in a file.
            -n <number>              Set GPU batch size (default: 40000, e.g., -n 50000).
            -l <min-max>             Set Passphrase length range (e.g., -l 1-3).
            -c <charset>             Set Passphrase charset. Built-in codes:
                                     'd' = digits (0-9)
                                     'u' = lowercase (a-z)
                                     'i' = uppercase (A-Z)
                                     's' = symbols (!@#$...)
                                     'all' = All types (0-9a-zA-Z!@#$...)
                                     * Can be combined (e.g., 'd,u' for lowercase + digits)
            -12, -15, -18, -21, -24  Set the number of mnemonic words (default: -12).

[+] Target Coin Types:
            -bc1q                    BTC Native SegWit (Default)
            -1                       BTC Legacy (P2PKH)
            -3                       BTC P2SH
            -eth                     Ethereum
            -trx                     TRON
            -doge, -ltc, -bch, -dash, -zec, -btg (Other supported coins)

[+] Example 1: ./m -12 -eth word1 ? word3 ... 0xTargetAddress
[+] Example 2: ./m "word1 ? word3 ..." -l 1-4 -c d,u -R -bc1q bc1qTarget...
[+] Example 3: ./m -12 -eth -f hash160.all.txt...
====================================================================

```

##  Mnemonic Recovery (Missing Words)

Use `?` to represent unknown words in your 12-24 word seed phrase. -12 is the default value for 12 words. To restore 15 words, you need to add -15!


1. Recover 1 missing word for an Ethereum address
```
./m "echo earn ? table vehicle awful true shop hazard latin useful ?" -eth 0x822bf5eb121b2d35454a43cb748a6128e61b9db3
[+] Version 2.1 Technical Support: https://www.8891689.com
[+] Recovered? Please donate 1% to support us. Thanks!
[+] Search Engine Initialization...
[+] Loading complete!
[+] Initial filter target hash: 0.50 MB
[+] Target hash list size: 0.00 MB
[+] Mnemonic combinations: 4194304
[+] Passphrase combos    : 1
[+] Starting Mega-Kernel search for ALL selected coins simultaneously...
[+] Search Mode: LINEAR
[+] Progress: 64.85% | Speed: 54869 / s | Checked: 2720000 | Mnemonic: echo earn ? table...hazard latin useful ?   

[+] MATCH FOUND!
--------------------------------------------------
[+] Phrase     : echo earn pink table vehicle awful true shop hazard latin useful admit
[+] Passphrase : None
[+] Coin Type  : Ethereum (ETH)
[+] Address    : 0x822bf5eb121b2d35454a43cb748a6128e61b9db3
[+] WIF        : 5Jqj2Ez1s2JgyhDqnnESttVA8RLPrsGjYhAPaGLvc5fsxnwMtCb
[+] PrivKey HEX: 86f672ab1ecedd420c8e12af3e0dd130037173dbb3cc73cc5475d2b5335def20
[+] PubKey  HEX: 042ddcf2e1c64ced63514c72e0a91a34709820de7eea84c030669efec154eaf6c7f261077242847153fe509ec26f022109a431133594a4010a634cfddd48459c6d
--------------------------------------------------

[+] Success! Result saved to 'found.txt'

```
2. Recover multiple missing words for a BTC Native SegWit address
```
./m "echo ? pink ? vehicle awful ? shop hazard ? useful ?" -bc1q bc1qglrv4e5za0uar4kdpaxqcpyjf0yq95keqxfe3k
```
3. Passphrase Brute-Force

Search for forgotten BIP39 passphrases (extension words) using specific character sets.

 Search 1-3 digit numeric passphrase (-c d = digits)
```
./m "dumb change never lawn twist identify guilt ? swap ankle polar method" -l 1-3 -c d bc1qltdx4p04a8g85f7pcn8mu6npsh4hdpmwkak776
[+] Version 2.1 Technical Support: https://www.8891689.com
[+] Recovered? Please donate 1% to support us. Thanks!
[+] Search Engine Initialization...
[+] Loading complete!
[+] Initial filter target hash: 0.50 MB
[+] Target hash list size: 0.00 MB
[+] Mnemonic combinations: 2048
[+] Passphrase combos    : 1110
[+] Starting Mega-Kernel search for ALL selected coins simultaneously...
[+] Search Mode: LINEAR
[+] Progress: 22.25% | Speed: 57938 / s | Checked: 505856 | Mnemonic: dumb change never lawn...swap ankle polar method   

[+] MATCH FOUND!
--------------------------------------------------
[+] Phrase     : dumb change never lawn twist identify guilt control swap ankle polar method
[+] Passphrase : 123
[+] Coin Type  : BTC (Native SegWit)
[+] Address    : bc1qltdx4p04a8g85f7pcn8mu6npsh4hdpmwkak776
[+] WIF        : L4rXqenARtSSQE512VvGtdN6RA7K8tPABZLggomoq1aBYtbjxYdV
[+] PrivKey HEX: e3cde17bd90091f6a8c7f762b316ac384490d6402754ccba0786310b77a343a0
[+] PubKey  HEX: 030d3b5d552c508810353a4d7ad024d34eebbf95dd8e0d87737d250b51436f6e00
--------------------------------------------------

[+] Success! Result saved to 'found.txt'

```
4. Search 1-4 character passphrase with lowercase and digits (-c d,u)
```
./m "mnemonic words..." -l 1-4 -c d,u -eth 0x9B136...
```
5. Batch Mode (Large Scale Recovery)

Compare a mnemonic phrase against a database of multiple addresses or Hash160 values.

6. Check mnemonic against a file of BTC Legacy addresses
```
./m "echo earn pink table vehicle awful true shop hazard latin useful ?" -f add.all.txt
[+] Version 2.1 Technical Support: https://www.8891689.com
[+] Recovered? Please donate 1% to support us. Thanks!
[+] Search Engine Initialization...
[+] Loading data... 100%
[+] Processing unique target hashes (Sorting and Deduplicating)...
[+] Loaded and processed 11 unique target hashes.
[+] Loading complete!
[+] Initial filter target hash: 0.50 MB
[+] Target hash list size: 0.00 MB
[+] Mnemonic combinations: 2048
[+] Passphrase combos    : 1
[+] Starting Mega-Kernel search for ALL selected coins simultaneously...
[+] Search Mode: LINEAR
[+] Progress: 100.00% | Speed: 13095 / s | Checked: 2048 | Mnemonic: echo earn pink table...hazard latin useful ?   

[+] MATCH FOUND!
--------------------------------------------------
[+] Phrase     : echo earn pink table vehicle awful true shop hazard latin useful admit
[+] Passphrase : None
[+] Coin Type  : BTC (Native SegWit)
[+] Address    : bc1qglrv4e5za0uar4kdpaxqcpyjf0yq95keqxfe3k
[+] WIF        : L1MFzV4BjqC2sqShZfMwTKPTKCE3ASfWJTUvbUWagzeEMggs8ipi
[+] PrivKey HEX: 7b3b96da0382b74cb047903a71f08983427f98cdcb73d2363bb11414408d0ea0
[+] PubKey  HEX: 027397c2e951b1587820c9e6eecceeaa31c1d4d3e04aa7a3bb4b81fb8f46abf6ed
--------------------------------------------------

[+] Success! Result saved to 'found.txt'

```
7. Check against a file of TRON public keys
```
./m "echo earn pink table vehicle awful true shop hazard latin useful ?" -trx -f pub.all.txt
[+] Version 2.1 Technical Support: https://www.8891689.com
[+] Recovered? Please donate 1% to support us. Thanks!
[+] Search Engine Initialization...
[+] Loading data... 100%
[+] Processing unique target hashes (Sorting and Deduplicating)...
[+] Loaded and processed 11 unique target hashes.
[+] Loading complete!
[+] Initial filter target hash: 0.50 MB
[+] Target hash list size: 0.00 MB
[+] Mnemonic combinations: 2048
[+] Passphrase combos    : 1
[+] Starting Mega-Kernel search for ALL selected coins simultaneously...
[+] Search Mode: LINEAR
[+] Progress: 100.00% | Speed: 15819 / s | Checked: 2048 | Mnemonic: echo earn pink table...hazard latin useful ?   

[+] MATCH FOUND!
--------------------------------------------------
[+] Phrase     : echo earn pink table vehicle awful true shop hazard latin useful admit
[+] Passphrase : None
[+] Coin Type  : TRON (TRX)
[+] Address    : TYeVsFupZKnKs9XCqjJrCTjhDFeQ7ySYBa
[+] WIF        : 5K9JPBXtAur77CChsfE5oX3u7J6Mjod7yGA8uEKNNwu4vJF8Cv2
[+] PrivKey HEX: aede8ae7dabb418f76e2f8a5c2fb142889c8c0051efbe7534f1e8ab03f9c8b1f
[+] PubKey  HEX: 040384aae86a01bed9c466b983924f87ab0fec847b3c9c4efaf6f12cf2f8eeb3ba82c220d15e3f483e16227e1b8c7b5f854ae0ea8e1dc6ec50980539a0c4462395
--------------------------------------------------

[+] Success! Result saved to 'found.txt'

```
8. Multi-Coin Command Examples
The tool automatically handles derivation paths based on the coin flag.

Bitcoin Cash (BCH)

```
./m "mnemonic words..." -bch bitcoincash:qrskwe...
```
Dogecoin (DOGE)

```
./m "mnemonic words..." -doge DEfZPVkBBx...
```

Litecoin (LTC)

```
./m "mnemonic words..." -ltc Lg3Ai3fcyJp...
```

Tron (TRX)

```
./m "mnemonic words..." -trx TQ9hmJLyURL...
```
9. Performance Tuning
Adjust GPU workload based on your hardware capabilities.

Set GPU batch size to 100,000 for faster processing

```
./m "mnemonic words..." -n 100000 -eth 0x...
```

10. Add support for multiple graphics cards! -g <device_id> Select the GPU device ID (default: 0).

# ⚙️ Dependencies

No dependencies are required. This program is all hand-crafted by me, using AI to assist in creation.

Thanks: gemini

# Sponsorship

If this project has been helpful to you, please consider sponsoring. Your support is greatly appreciated. Thank you!
```
BTC: bc1qt3nh2e6gjsfkfacnkglt5uqghzvlrr6jahyj2k
ETH: 0xD6503e5994bF46052338a9286Bc43bC1c3811Fa1
DOGE: DTszb9cPALbG9ESNJMFJt4ECqWGRCgucky
TRX: TAHUmjyzg7B3Nndv264zWYUhQ9HUmX4Xu4
```
This program is free to use; please contact me if you need the source code or a Windows graphical version!
# 📜 Disclaimer

This code is only used to learn and understand the working principles of standards such as BIP32/BIP39/BIP44. The random number generator uses highly random numbers and complies with encryption industry standards.

# ⚠️ Reminder

Do not enter the real private key on a device connected to the network! Especially when the VPN proxy is connected, the information is intercepted and intercepted, which has a high security risk, or it is infected by viruses and trojans, etc. This project is completely open source and there is no risk of backdoors or interception of information. Please confirm that it is safe before using this program. The developer is not responsible for any financial losses caused by the use of this code.
