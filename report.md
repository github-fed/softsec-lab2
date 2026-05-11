### Note that this is not the final report, we have to submit a USENIX style pdf


# Library Version
We fuzz version 1.8.6 of libsixel. The reason for this choice is mentioned in Q1
Harness Design.

# Questions
## Q1 Harness Design
- [X] Describe entrypoints and justify why
- [X] Discuss alternative entrypoints and reason why rejected or why it would be
  worth fuzzing them too
- [ ] Walk through harness code, explain data flow from AFL++ input file to
  library API call
- [ ] For every guard in the code (error handling, dimension limits, etc.),
  explain why it is needed from a fuzzing perspective




Encoding and decoding sixel files are among the most used functionalities of
libsixel, so `sixel_decode()` and `sixel_encode()` are interesting candidates
for fuzzing. The function `sixel_decode()` is annotated as deprecated, so
`sixel_decode_raw()` seems like a better target. From experience, resizing
images can also be tricky. So while skimming through the header file in the
include directory, `sixel_frame_resize()` also stood out as a candidate for
fuzzing. That function however contains a lot of error handling and argument
checking, which we don't want to execute repeatedly in our fuzzing campaign. So
`sixel_helper_scale_image()` or `sixel_helper_normalize_pixelformat()` which are
called deeper down the function stack are better targets with less overhead.

While the latter functions might not be as well explored with fuzzing as the
decoding and encoding process, it is in our opinion more interesting to fuzz one
of the main functionalities of the library. Between `sixel_decode_raw()` and
`sixel_encode()`, the latter takes a lot of parameters as input and thus
needs much more execution time to set up the inputs. This again means that the
harness would spend more time for setup that could be spent executing the
library function. It turns out there is a CVE in decode_raw() in version 1.8.7,
so we fuzz the version 1.8.6 in hopes of finding that CVE.


So we have decided on `sixel_decode_raw()` as our fuzzing target since it is
an important functionality of the library and doesn't require as many inputs as
encoding. `sixel_encode()` and `sixel_helper_normalize_pixelformat()`
would still be interesting fuzzing targets for the above-mentioned reasons.


## Q2 Instrumentation and Sanitizers


### Build 1 instrumented (white-box, AFL++ + ASan)

```
CC=afl-clang-lto
CFLAGS="-fsanitize=address -g -O1"
LDFLAGS="-fsanitize=address"
./configure --disable-shared --disable-python --prefix=/lab/libsixel-inst
```

| Flag | What it does | If omitted |
|------|--------------|------------|
| `CC=afl-clang-lto` | AFL++ instrumentation at link time via LLVM LTO: 
collision-free edge IDs in every basic block of libsixel. | No coverage 
feedback → AFL degenerates into blind random fuzzing; `paths_found` stays near 0. |

| `-fsanitize=address` (CFLAGS) | Compiles with ASan: red-zones around 
allocs, shadow memory, quarantine on free. | Heap OOB / UAF / double-free 
would silently corrupt memory without crashing → AFL never saves them under 
`crashes/`. |

| `-fsanitize=address` (LDFLAGS) | Links the ASan runtime (`libclang_rt.asan`)
 and its `malloc`/`free` interceptors. | Undefined references at link time, 
 or binary runs without the runtime active. |

| `-g` | DWARF debug info. | ASan stack traces show raw addresses only; 
triage with `addr2line` becomes painful. |

| `-O1` | Light optimization. | `-O0` bloats the edge map and slows `exec/s`; 
`-O2/-O3` inlines aggressively → some edges vanish and crashes become 
non-reproducible between builds. |

| `--disable-shared` | Produces only `libsixel.a`. | A `.so` loaded dynamically
 bypasses AFL's shm map → 0 % coverage inside libsixel. |

| `--disable-python` | Skips the Python bindings. | Build fails 
(no `python-dev` in the container) and pollutes the archive with unrelated code. |

### Build 2 — vanilla (black-box, QEMU mode)

```
CC=clang
CFLAGS="-g -O1"
./configure --disable-shared --disable-python --prefix=/lab/libsixel-vanilla
```

| Flag | What it does | If omitted |
|------|--------------|------------|
| `CC=clang` | Plain Clang, **no** instrumentation. | Required for
 `afl-fuzz -Q` (QEMU user-mode); any compiler-side instrumentation 
 would conflict with QEMU's block translation. |

| `-g` | DWARF debug info for QEMU-side triage. |
 Crashes become hard to symbolize. |

| `-O1` | Same optimisation level as Build 1. | Different `-O` makes
 coverage comparison between the two campaigns meaningless. |

| `--disable-shared` / `--disable-python` | Same as Build 1. | Same reasons. |

### Patches applied to libsixel

None.The Dockerfile clones the official upstream, checks out tag 
`v1.8.6`, and builds with an unmodified `./configure && make`, 
no `patch`, `sed -i`, `git apply`, nor any `COPY *.patch`.

Effect on path discovery: no checksum or validation has been removed,
so the fuzzer must legitimately defeat every format check in the SIXEL parser.
Every crash is therefore a real bug against upstream, not an artefact
of harness-side weakening.



## Q3 Seed Corpus and Dictionary


## Q4 Campaign Analysis


## Q5 Crash Triage


Crashes found:
The `harness_load_image` campaign produced 4 crash files. After triage with
ASan, all 4 reduce to a **single unique bug** (identical call stack and
sanitizer output).


Bug: uninitialized `rows` variable in `load_png`
- **File / line**: `libsixel/src/loader.c:633`
- **Sanitizer**: AddressSanitizer reports `bad-free` (free on a pointer
  that was not returned by `malloc`).
- **Trigger**: any malformed PNG that causes libpng to fail decoding
  (e.g. corrupted IDAT). Minimal PoC: 60 bytes.
- **CWE**: CWE-457 (Use of Uninitialized Variable), with secondary
  CWE-755 and CWE-761.


Root cause :
In `load_png()`, the local variable `unsigned char **rows` is declared without
`volatile` and without initializer. Two `setjmp` calls capture state early in
the function. When libpng later detects the malformed PNG, it triggers a
`longjmp` back to one of these `setjmp` sites. Per C11 §7.13.2.1, the value of a
non-`volatile` local modified between `setjmp` and `longjmp` is
**indeterminate** after the longjmp. In practice GCC keeps `rows` in a register,
so the longjmp restores it to its initial **uninitialized** stack value (residue
from a previous call frame). The `cleanup` label then calls

## Q6 Attack Surface Analysis

### Two real world applications

`img2sixel` is a command-line utility provided directly by the
libsixel project itself. It converts image formats like PNG, JPEG or BMP
into SIXEL format so they can be displayed in the terminal.

Another application could be FFmpeg-SIXEL. A collection of libraries and tools
to process multimedia content such as audio, video, subtitles and related
metadata. It allows for instance for youtube streaming in the terminal.

### Concrete attack scenario

In unsecure remote environments, one coud have arbitrary code execution because
of the bad-free. The attacker can craft an image that forces libsixel to
allocate memory in a predictable pattern. When the bad-free is triggered, the
allocator can be tricked into writing data into a location it shouldn't (for
intance a function pointer). At this point, when the library returns, it will go
to a location controlled by the attacker which could launch a shellcode, for
instance.

### Two unexercised code paths
