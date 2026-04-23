# Compiler and Path Definitions
CC_INST    = afl-clang-fast
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
build: build-inst build-vanilla build-persistent

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

# Persistent mode build for performance comparison
build-persistent: src/harness_persistent.c
	$(CC_INST) $(CFLAGS) -fsanitize=address $(INCLUDES_INST) \
		src/harness_persistent.c $(INST_DIR)/lib/libsixel.a \
		$(LIBS) -fsanitize=address -o harness_persistent

### Fuzzing targets

# Standard coverage-guided fuzzing
fuzz:
	afl-fuzz -V 1800 -i seeds -o findings -x /lab/libsixel/etc/sixel.dict -- ./harness_inst @@

# Binary-only fuzzing using QEMU mode
fuzz-qemu:
	afl-fuzz -V 1800 -Q -i seeds -o findings-qemu -x /lab/libsixel/etc/sixel.dict -- ./harness_vanilla @@

# Persistent mode fuzzing for speed comparison
fuzz-persistent:
	afl-fuzz -V 1800 -i seeds -o findings-persistent -- ./harness_persistent

### Analysis and cleanup

# Generate plots for the report
plot:
	afl-plot findings/default plot_output
	afl-plot findings-qemu/default plot_output_qemu
	afl-plot findings-persistent/default plot_output_persistent

clean:
	rm -f harness_inst harness_vanilla harness_persistent
	rm -rf findings findings-qemu findings-persistent plot_output*