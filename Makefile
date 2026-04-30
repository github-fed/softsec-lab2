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

# Targets
all: build

### Build targets
build: build-inst build-vanilla build-persistent build-whole-archive build-no-asan \
       build-decode build-encode-bytes build-dither build-load-image build-scale

# Instrumented build for white-box fuzzing (with ASan)
build-inst: src/harness.c
	$(CC_INST) $(CFLAGS) -fsanitize=address $(INCLUDES_INST) \
		src/harness.c $(INST_DIR)/lib/libsixel.a \
		$(LIBS) -fsanitize=address -o harness_inst

# Vanilla build for black-box/QEMU fuzzing (no instrumentation/sanitizers)
build-vanilla: src/harness.c
	$(CC_VANILLA) $(CFLAGS) $(INCLUDES_VANILLA) \
		src/harness.c $(VANILLA_DIR)/lib/libsixel.a \
		$(LIBS) -o harness_vanilla

build-whole-archive: src/harness.c
	$(CC_INST) $(CFLAGS) -fsanitize=address $(INCLUDES_INST) \
		src/harness.c \
		-Wl,--whole-archive $(INST_DIR)/lib/libsixel.a -Wl,--no-whole-archive \
		$(LIBS) -fsanitize=address -o harness_whole_archive

build-no-asan: src/harness.c
	$(CC_INST) $(CFLAGS) $(INCLUDES_VANILLA) \
		src/harness.c $(VANILLA_DIR)/lib/libsixel.a \
		$(LIBS) -o harness_no_asan

# Persistent mode build for performance comparison
build-persistent: src/harness_persistent.c
	$(CC_INST) $(CFLAGS) -fsanitize=address $(INCLUDES_INST) \
		src/harness_persistent.c $(INST_DIR)/lib/libsixel.a \
		$(LIBS) -fsanitize=address -o harness_persistent

# sixel_decode(): higher-level decode with callbacks (Sixel input)
build-decode: src/harness_decode.c
	$(CC_INST) $(CFLAGS) -fsanitize=address $(INCLUDES_INST) \
		src/harness_decode.c $(INST_DIR)/lib/libsixel.a \
		$(LIBS) -fsanitize=address -o harness_decode

# sixel_encode(): encode path, input is a pixel buffer with embedded dimensions
build-encode-bytes: src/harness_encode_bytes.c
	$(CC_INST) $(CFLAGS) -fsanitize=address $(INCLUDES_INST) \
		src/harness_encode_bytes.c $(INST_DIR)/lib/libsixel.a \
		$(LIBS) -fsanitize=address -o harness_encode_bytes

# sixel_dither_initialize(): color quantization on a pixel buffer
build-dither: src/harness_dither.c
	$(CC_INST) $(CFLAGS) -fsanitize=address $(INCLUDES_INST) \
		src/harness_dither.c $(INST_DIR)/lib/libsixel.a \
		$(LIBS) -fsanitize=address -o harness_dither

# sixel_encoder_encode(): image file loading pipeline
build-load-image: src/harness_load_image.c
	$(CC_INST) $(CFLAGS) -fsanitize=address $(INCLUDES_INST) \
		src/harness_load_image.c $(INST_DIR)/lib/libsixel.a \
		$(LIBS) -fsanitize=address -o harness_load_image

# sixel_helper_scale_image(): image resampling on a pixel buffer
build-scale: src/harness_scale.c
	$(CC_INST) $(CFLAGS) -fsanitize=address $(INCLUDES_INST) \
		src/harness_scale.c $(INST_DIR)/lib/libsixel.a \
		$(LIBS) -fsanitize=address -o harness_scale

### Seed generation

# Generate all seeds
gen-seeds:
	python3 seeds/gen_seeds.py

### Fuzzing targets

# Smoke test
fuzz-test: gen-seeds
	afl-fuzz -V 60 -i seeds -o findings-test -x sixel.dict -- ./harness_inst @@
	afl-fuzz -V 60 -Q -i seeds -o findings-test-qemu -x sixel.dict -- ./harness_vanilla @@
	afl-fuzz -V 60 -i seeds -o findings-test-persistent -x sixel.dict -- ./harness_persistent
	afl-fuzz -V 60 -i seeds -o findings-test-no-asan -x sixel.dict -- ./harness_no_asan @@

# Standard coverage-guided fuzzing
fuzz: gen-seeds
	AFL_AUTORESUME=1 afl-fuzz -V 2400 -i seeds -o findings -x sixel.dict -- ./harness_inst @@

# Binary-only fuzzing using QEMU mode
fuzz-qemu: gen-seeds
	AFL_AUTORESUME=1 afl-fuzz -V 2400 -Q -i seeds -o findings-qemu -x sixel.dict -- ./harness_vanilla @@

# Persistent mode fuzzing — short run, used only to record exec speed for Q8
fuzz-persistent: gen-seeds
	AFL_AUTORESUME=1 afl-fuzz -V 300 -i seeds -o findings-persistent -x sixel.dict -- ./harness_persistent

# sixel_decode(): same Sixel input format and dictionary as the original harness
fuzz-decode: gen-seeds
	AFL_AUTORESUME=1 afl-fuzz -V 2400 -i seeds -o findings-decode -x sixel.dict -- ./harness_decode @@

# sixel_encode(): raw pixel buffer with 4-byte dimension header
fuzz-encode-bytes: gen-seeds
	AFL_AUTORESUME=1 afl-fuzz -V 2400 -i seeds_pixels -o findings-encode-bytes -- ./harness_encode_bytes @@

# sixel_dither_initialize(): raw pixel buffer with 4-byte dimension header
fuzz-dither: gen-seeds
	AFL_AUTORESUME=1 afl-fuzz -V 2400 -i seeds_pixels -o findings-dither -- ./harness_dither @@

# sixel_encoder_encode(): arbitrary image files no Sixel dict
fuzz-load-image: gen-seeds
	AFL_AUTORESUME=1 afl-fuzz -V 2400 -i seeds_images -o findings-load-image -- ./harness_load_image @@

# sixel_helper_scale_image(): raw pixel buffer with 8-byte dimension header
fuzz-scale: gen-seeds
	AFL_AUTORESUME=1 afl-fuzz -V 2400 -i seeds_pixels -o findings-scale -- ./harness_scale @@

fuzz-all: gen-seeds
	mkdir -p logs
	AFL_AUTORESUME=1 afl-fuzz -V 2400 -i seeds        -o findings           -x sixel.dict -- ./harness_inst         @@ > logs/fuzz-inst.log         2>&1 &
	AFL_AUTORESUME=1 afl-fuzz -V 2400 -i seeds        -o findings-decode    -x sixel.dict -- ./harness_decode        @@ > logs/fuzz-decode.log        2>&1 &
	AFL_AUTORESUME=1 afl-fuzz -V 2400 -i seeds_pixels -o findings-encode-bytes            -- ./harness_encode_bytes  @@ > logs/fuzz-encode-bytes.log  2>&1 &
	AFL_AUTORESUME=1 afl-fuzz -V 2400 -i seeds_pixels -o findings-dither                  -- ./harness_dither        @@ > logs/fuzz-dither.log        2>&1 &
	AFL_AUTORESUME=1 afl-fuzz -V 2400 -i seeds_images -o findings-load-image              -- ./harness_load_image    @@ > logs/fuzz-load-image.log    2>&1 &
	AFL_AUTORESUME=1 afl-fuzz -V 2400 -i seeds_pixels -o findings-scale                   -- ./harness_scale         @@ > logs/fuzz-scale.log         2>&1 &
	wait

### Analysis and cleanup

# Generate plots for the report
plot:
	afl-plot findings/default              plot_output
	afl-plot findings-qemu/default         plot_output_qemu
	afl-plot findings-decode/default       plot_output_decode
	afl-plot findings-encode-bytes/default plot_output_encode_bytes
	afl-plot findings-dither/default       plot_output_dither
	afl-plot findings-load-image/default   plot_output_load_image
	afl-plot findings-scale/default        plot_output_scale
	afl-plot findings-persistent/default   plot_output_persistent

clean:
	rm -f harness_inst harness_vanilla harness_persistent harness_whole_archive harness_no_asan \
	      harness_decode harness_encode_bytes harness_dither harness_load_image harness_scale
	rm -rf findings findings-qemu findings-persistent findings-no-asan plot_output* findings-test* \
	       findings-decode findings-encode-bytes findings-dither findings-load-image findings-scale \
	       plot_output_decode plot_output_encode_bytes plot_output_dither plot_output_load_image plot_output_scale \
	       logs