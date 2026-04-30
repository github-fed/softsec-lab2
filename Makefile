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
build: build-inst build-vanilla build-persistent build-whole-archive build-no-asan

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

### Fuzzing targets

# Smoke test
fuzz-test:
	afl-fuzz -V 60 -i seeds -o findings-test -- ./harness_inst @@
	afl-fuzz -V 60 -Q -i seeds -o findings-test-qemu -- ./harness_vanilla @@
	afl-fuzz -V 60 -i seeds -o findings-test-persistent -- ./harness_persistent
	afl-fuzz -V 60 -i seeds -o findings-test-no-asan -- ./harness_no_asan @@

# Standard coverage-guided fuzzing
fuzz:
	afl-fuzz -V 2400 -i seeds -o findings -- ./harness_inst @@

# Binary-only fuzzing using QEMU mode
fuzz-qemu:
	afl-fuzz -V 2400 -Q -i seeds -o findings-qemu -- ./harness_vanilla @@

# Persistent mode fuzzing — short run, used only to record exec speed for Q8
fuzz-persistent:
	afl-fuzz -V 300 -i seeds -o findings-persistent -- ./harness_persistent

### Analysis and cleanup

# Generate plots for the report
plot:
	afl-plot findings/default plot_output
	afl-plot findings-qemu/default plot_output_qemu
	afl-plot findings-persistent/default plot_output_persistent

clean:
	rm -f harness_inst harness_vanilla harness_persistent harness_whole_archive harness_no_asan
	rm -rf findings findings-qemu findings-persistent findings-no-asan plot_output* findings-test*