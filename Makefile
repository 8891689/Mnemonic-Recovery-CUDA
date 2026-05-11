# ==========================================
# ==========================================

NVCC := nvcc
CXX  := g++
CC   := gcc

CUDA_ARCH_FLAGS := \
    -gencode arch=compute_60,code=sm_60 \
    -gencode arch=compute_61,code=sm_61 \
    -gencode arch=compute_70,code=sm_70 \
    -gencode arch=compute_75,code=sm_75 \
    -gencode arch=compute_80,code=sm_80 \
    -gencode arch=compute_86,code=sm_86 \
    -gencode arch=compute_89,code=sm_89 \
    -gencode arch=compute_90,code=sm_90 \
    -gencode arch=compute_100,code=sm_100 \
    -gencode arch=compute_120,code=sm_120 \
    -gencode arch=compute_120,code=compute_120 \
    -Wno-deprecated-gpu-targets

HOST_FLAGS := -O3 -march=native -mtune=native -fopenmp

NVCC_FLAGS := $(CUDA_ARCH_FLAGS) -std=c++14 --extended-lambda -O3 \
              --use_fast_math \
              -Xcompiler "$(HOST_FLAGS)" \
              -Xptxas -O3 \
              -DUSE_BLOOM -I.

CXX_FLAGS := $(HOST_FLAGS) -std=c++14 -DUSE_BLOOM -I.
CC_FLAGS  := $(HOST_FLAGS) -DUSE_BLOOM -I.

LDFLAGS := -lcuda -lrt -lpthread -lgomp

STATIC_LDFLAGS := -cudart=static -Xcompiler "-static-libstdc++ -static-libgcc" -lcuda -lrt -lpthread -lgomp

TARGET := m
STATIC_TARGET := m_static
OBJS := main.o Bip39Manager.o utils.o passphrase.o \
        random.o bip39.o sha2_avx2.o base58.o bech32.o \
        cashaddr.o ripemd160_avx2.o keccak_avx2.o

.PHONY: all static clean


all: $(TARGET)
	@echo "[+] Dynamic build successful: $(TARGET)"
	@echo "[+] Auto-removing intermediate object files..."
	@rm -f $(OBJS)

static: $(OBJS)
	$(NVCC) $(CUDA_ARCH_FLAGS) -o $(STATIC_TARGET) $^ $(STATIC_LDFLAGS)
	@echo "[+] Static (Portable) build successful: $(STATIC_TARGET)"
	@echo "[+] Auto-removing intermediate object files..."
	@rm -f $(OBJS)

$(TARGET): $(OBJS)
	$(NVCC) $(CUDA_ARCH_FLAGS) -o $@ $^ $(LDFLAGS)

%.o: %.cu
	$(NVCC) $(NVCC_FLAGS) -c $< -o $@

%.o: %.cpp
	$(CXX) $(CXX_FLAGS) -c $< -o $@

%.o: %.c
	$(CC) $(CC_FLAGS) -c $< -o $@

clean:
	@echo "[+] Cleaning up all build files..."
	rm -f $(OBJS) $(TARGET) $(STATIC_TARGET)
