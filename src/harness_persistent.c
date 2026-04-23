#include <stdio.h>
#include <stdlib.h>
#include <sixel.h>

__AFL_FUZZ_INIT();

int main() {
    unsigned char *buf = __AFL_FUZZ_TESTCASE_BUF;

    // Deferred forkserver
    __AFL_INIT();
    
    while (__AFL_LOOP(1000)) {
        int len = __AFL_FUZZ_TESTCASE_LEN;

        // Prevent uninterestingly large inputs from slowing the fuzzer
        if (len > 1000000) {
            continue;
        }

        unsigned char *pixels = NULL;
        int width = 0;
        int height = 0;
        unsigned char *palette = NULL;
        int ncolors = 0;

        // Perform the decode on the buffer in memory
        sixel_decode_raw(buf, len, &pixels, &width, &height, &palette, &ncolors, NULL);

        // Reset state for next iteration
        free(pixels);
        free(palette);
    }

    return 0;
}