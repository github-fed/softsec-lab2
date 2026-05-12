# Compiler and Path Definitions
CC_INST    = afl-clang-lto
CC_VANILLA = clang
LIBS       = -lcurl -lpng -ljpeg -lm
CFLAGS     = -g -O1

# Directories from Dockerfile
INST_DIR    = /lab/libsixel-inst
VANILLA_DIR = /lab/libsixel-vanilla
INCLUDES_INST    = -I$(INST_DIR)/include
INCLUDES_VANILLA = -I$(VANILLA_DIR)/include

all: build

### Build targets

build: build-decode-raw build-decode build-load-image \
       build-persistent build-vanilla build-no-asan

# sixel_decode_raw(): low-level Sixel decoder
build-decode-raw: src/harness_decode_raw.c
	$(CC_INST) $(CFLAGS) -fsanitize=address $(INCLUDES_INST) \
		src/harness_decode_raw.c $(INST_DIR)/lib/libsixel.a \
		$(LIBS) -fsanitize=address -o harness_decode_raw

# sixel_decode(): higher-level decode with callbacks
build-decode: src/harness_decode.c
	$(CC_INST) $(CFLAGS) -fsanitize=address $(INCLUDES_INST) \
		src/harness_decode.c $(INST_DIR)/lib/libsixel.a \
		$(LIBS) -fsanitize=address -o harness_decode

# sixel_encoder_encode(): image file loading pipeline
build-load-image: src/harness_load_image.c
	$(CC_INST) $(CFLAGS) -fsanitize=address $(INCLUDES_INST) \
		src/harness_load_image.c $(INST_DIR)/lib/libsixel.a \
		$(LIBS) -fsanitize=address -o harness_load_image

# ASan + persistent mode — used for Q8 exec-speed comparison
build-persistent: src/harness_persistent.c
	$(CC_INST) $(CFLAGS) -fsanitize=address $(INCLUDES_INST) \
		src/harness_persistent.c $(INST_DIR)/lib/libsixel.a \
		$(LIBS) -fsanitize=address -o harness_persistent

# No instrumentation, no sanitizers — used for QEMU fuzzing (Q7)
build-vanilla: src/harness_decode_raw.c
	$(CC_VANILLA) $(CFLAGS) $(INCLUDES_VANILLA) \
		src/harness_decode_raw.c $(VANILLA_DIR)/lib/libsixel.a \
		$(LIBS) -o harness_vanilla

# No sanitizer, instrumented — used for Q8 exec-speed baseline
build-no-asan: src/harness_decode_raw.c
	$(CC_INST) $(CFLAGS) $(INCLUDES_VANILLA) \
		src/harness_decode_raw.c $(VANILLA_DIR)/lib/libsixel.a \
		$(LIBS) -o harness_no_asan

### Seed generation

gen-seeds:
	python3 seeds/gen_seeds.py

### Fuzzing targets (instrumented, white-box)

# sixel_decode_raw()
fuzz-decode-raw: gen-seeds
	AFL_AUTORESUME=1 afl-fuzz -V 2400 -i seeds -o findings/decode-raw -x sixel.dict -- ./harness_decode_raw @@

# sixel_decode()
fuzz-decode: gen-seeds
	AFL_AUTORESUME=1 afl-fuzz -V 2400 -i seeds -o findings/decode -x sixel.dict -- ./harness_decode @@

# sixel_encoder_encode()
fuzz-load-image: gen-seeds
	AFL_AUTORESUME=1 afl-fuzz -V 2400 -i seeds_images -o findings/load-image -- ./harness_load_image @@

# ASan + persistent mode — Q8 exec-speed measurement
fuzz-persistent: gen-seeds
	AFL_AUTORESUME=1 afl-fuzz -V 300 -i seeds -o findings/persistent -x sixel.dict -- ./harness_persistent

# No sanitizer + fork mode — Q8 exec-speed baseline
fuzz-no-asan: gen-seeds
	AFL_AUTORESUME=1 afl-fuzz -V 300 -i seeds -o findings/no-asan -x sixel.dict -- ./harness_no_asan @@

### Fuzzing targets (binary-only, QEMU mode)

# sixel_decode_raw() under QEMU — Q7
fuzz-qemu: gen-seeds
	AFL_AUTORESUME=1 afl-fuzz -V 2400 -Q -i seeds -o findings/qemu -x sixel.dict -- ./harness_vanilla @@

### Smoke test (60 s per harness, sanity check only)

fuzz-test: gen-seeds
	afl-fuzz -V 60 -i seeds        -o findings/test-decode-raw    -x sixel.dict -- ./harness_decode_raw @@
	afl-fuzz -V 60 -i seeds        -o findings/test-decode        -x sixel.dict -- ./harness_decode @@
	afl-fuzz -V 60 -i seeds_images -o findings/test-load-image                  -- ./harness_load_image @@
	afl-fuzz -V 60 -i seeds        -o findings/test-persistent    -x sixel.dict -- ./harness_persistent
	afl-fuzz -V 60 -i seeds        -o findings/test-no-asan       -x sixel.dict -- ./harness_no_asan @@
	afl-fuzz -V 60 -Q -i seeds     -o findings/test-qemu          -x sixel.dict -- ./harness_vanilla @@

### Run all campaigns in parallel

fuzz-all: gen-seeds
	AFL_AUTORESUME=1 afl-fuzz -V 2400 -i seeds        -o findings/decode-raw    -x sixel.dict -- ./harness_decode_raw   @@ &
	AFL_AUTORESUME=1 afl-fuzz -V 2400 -i seeds        -o findings/decode        -x sixel.dict -- ./harness_decode        @@ &
	AFL_AUTORESUME=1 afl-fuzz -V 2400 -i seeds_images -o findings/load-image                 -- ./harness_load_image     @@ &
	AFL_AUTORESUME=1 afl-fuzz -V 300  -i seeds        -o findings/persistent    -x sixel.dict -- ./harness_persistent          &
	AFL_AUTORESUME=1 afl-fuzz -V 300  -i seeds        -o findings/no-asan       -x sixel.dict -- ./harness_no_asan        @@ &
	AFL_AUTORESUME=1 afl-fuzz -V 2400 -Q -i seeds     -o findings/qemu          -x sixel.dict -- ./harness_vanilla        @@ &
	wait

### Analysis

plot:
	mkdir -p plot_output
	afl-plot findings/decode-raw/default    plot_output/decode-raw
	afl-plot findings/decode/default        plot_output/decode
	afl-plot findings/load-image/default    plot_output/load-image
	afl-plot findings/persistent/default    plot_output/persistent
	afl-plot findings/no-asan/default       plot_output/no-asan
	afl-plot findings/qemu/default          plot_output/qemu

clean:
	rm -f harness_decode_raw harness_decode harness_load_image \
	      harness_persistent harness_vanilla harness_no_asan
	rm -rf findings plot_output