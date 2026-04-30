# sofsec-lab2
Lab 2 SoftSec

## Q1 — Harness Design

### Entry point choice: `sixel_decode_raw()`

We chose `sixel_decode_raw()` as the primary fuzzing entry point. It is the lowest-level Sixel parsing function in the library: every higher-level path — `sixel_decode()`, `sixel_decoder_decode()`, and the `sixel2png` command-line tool — eventually bottoms out here. This means it receives the raw, attacker-controlled byte stream with no intermediate abstraction, no I/O overhead, and no callback indirection. It also contains the densest
concentration of per-byte parsing logic: color-table parsing, run-length decoding, escape sequence handling, and raster attribute processing. Choosing the lowest common denominator maximizes both the reach of each fuzz input and the execution speed, since no wrapper setup is needed on every iteration.

### API exploration methodology

We explored the public API surface systematically using three grep passes on the installed header inside the Docker container.

**Step 1 — extract function names:**
```bash
grep -A3 "SIXELAPI" /lab/libsixel-inst/include/sixel.h | grep "sixel_"
```
This shows the function names and keeping only lines containing `sixel_`.

**Step 2 — filter by input-taking parameters:**
```bash
grep -A5 "SIXELAPI" /lab/libsixel-inst/include/sixel.h \
  | grep -B2 "unsigned char \*\|const char \*\|size_t\|int len\|int size"
```
This narrows the list to functions whose signatures contain raw buffer, file path, or length parameters — the indicator that a function processes externally-controlled data and is worth fuzzing.

**Step 4 — cross-reference with source files** to confirm which subsystem each function belongs to:
```bash
ls /lab/libsixel/src/
# fromsixel.c → decode path
# tosixel.c   → encode path
# loader.c    → image file loading (PNG/JPEG/BMP)
# output.c    → output handling
```

Functions that only take integer flags, enum values, or opaque internal structs were excluded.

### Other entry points considered

We explored the full public API surface by listing all `SIXELAPI`-tagged symbols and filtering by parameter type to identify which functions accept externally-controlled data:

| Candidate | Input type | Decision |
|---|---|---|
| `sixel_decode()` | Sixel byte buffer | Thin wrapper over `decode_raw`; exercises callback setup but same core parser. Worth fuzzing as a secondary target. |
| `sixel_decoder_decode()` | Sixel byte buffer (via decoder object with `setopt`) | Adds I/O indirection; mostly exercises the same parsing code. Lower priority. |
| `sixel_encode()` | Raw pixel buffer + dimensions | Encoder path; different code, different input format. Fuzzed separately with `harness_encode_bytes.c`. |
| `sixel_dither_initialize()` | Raw pixel buffer | Color quantization arithmetic; integer overflow risk. Fuzzed separately with `harness_dither.c`. |
| `sixel_encoder_encode()` | File path (PNG/JPEG/BMP/GIF) | Exercises the image loading pipeline and all format-specific parsers. Highest independent value; fuzzed with `harness_load_image.c`. |
| `sixel_helper_scale_image()` | Raw pixel buffer + dimensions | Resampling arithmetic; fuzzed separately with `harness_scale.c`. |
| `sixel_output_set_*`, `sixel_dither_set_*` | Integer flags / enum values | Configuration setters; do not process external data. Not fuzzed. |

The encoder and image-loader harnesses require separate seed corpora because their input formats are completely different from Sixel bytes.


**Guard A — `if (size == 0 || size > 1000000)`**
An empty file triggers an immediate return in the Sixel parser before any interesting code runs. The upper bound (1 MB) prevents the fuzzer from crafting an input that causes a multi-gigabyte allocation for a claimed-large raster attribute.

**`if (!f) return 1;` and `if (!data) { ... return 1; }`**
These guard against file-open and allocation failures.

**`if (argc < 2) return 1;`**
AFL++ always supplies the file path as `argv[1]` when invoked with `@@`. This guard is a defensive check that prevents a segfault if the harness is ever invoked manually without arguments during development.

**`free(pixels)` and `free(palette)`**
`sixel_decode_raw()` allocates the output buffers via the library's internal allocator and transfers ownership to the caller. In persistent mode the same process runs thousands of iterations failing to free these buffers would grow the heap

## Building Docker container
```bash
docker build -t group27-lab2 .
```

## Running
```bash
mkdir -p findings findings-qemu findings-persistent \
         findings-decode findings-encode-bytes findings-dither \
         findings-load-image findings-scale \
         plot_output plot_output_qemu plot_output_persistent \
         plot_output_decode plot_output_encode_bytes plot_output_dither \
         plot_output_load_image plot_output_scale \
         seeds_pixels seeds_images logs
docker run --rm -it \
  -v "$(pwd)/Makefile:/lab/Makefile" \
  -v "$(pwd)/src:/lab/src" \
  -v "$(pwd)/seeds:/lab/seeds" \
  -v "$(pwd)/seeds_pixels:/lab/seeds_pixels" \
  -v "$(pwd)/seeds_images:/lab/seeds_images" \
  -v "$(pwd)/findings:/lab/findings" \
  -v "$(pwd)/findings-qemu:/lab/findings-qemu" \
  -v "$(pwd)/findings-persistent:/lab/findings-persistent" \
  -v "$(pwd)/findings-decode:/lab/findings-decode" \
  -v "$(pwd)/findings-encode-bytes:/lab/findings-encode-bytes" \
  -v "$(pwd)/findings-dither:/lab/findings-dither" \
  -v "$(pwd)/findings-load-image:/lab/findings-load-image" \
  -v "$(pwd)/findings-scale:/lab/findings-scale" \
  -v "$(pwd)/plot_output:/lab/plot_output" \
  -v "$(pwd)/plot_output_qemu:/lab/plot_output_qemu" \
  -v "$(pwd)/plot_output_persistent:/lab/plot_output_persistent" \
  -v "$(pwd)/plot_output_decode:/lab/plot_output_decode" \
  -v "$(pwd)/plot_output_encode_bytes:/lab/plot_output_encode_bytes" \
  -v "$(pwd)/plot_output_dither:/lab/plot_output_dither" \
  -v "$(pwd)/plot_output_load_image:/lab/plot_output_load_image" \
  -v "$(pwd)/plot_output_scale:/lab/plot_output_scale" \
  -v "$(pwd)/logs:/lab/logs" \
  group27-lab2
```
