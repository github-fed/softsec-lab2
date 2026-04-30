#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <sixel.h>

int main(int argc, char **argv) {
    if (argc < 2) return 1;

    FILE *f = fopen(argv[1], "rb");
    if (!f) return 1;

    fseek(f, 0, SEEK_END);
    size_t size = ftell(f);
    fseek(f, 0, SEEK_SET);

    if (size < 8 || size > 1000000) {
        fclose(f);
        return 0;
    }

    unsigned char *data = malloc(size);
    if (!data) { fclose(f); return 1; }
    fread(data, 1, size, f);
    fclose(f);

    uint16_t srcw = (uint16_t)(((uint16_t)data[0] | ((uint16_t)data[1] << 8)) % 1024) + 1;
    uint16_t srch = (uint16_t)(((uint16_t)data[2] | ((uint16_t)data[3] << 8)) % 1024) + 1;
    uint16_t dstw = (uint16_t)(((uint16_t)data[4] | ((uint16_t)data[5] << 8)) % 512)  + 1;
    uint16_t dsth = (uint16_t)(((uint16_t)data[6] | ((uint16_t)data[7] << 8)) % 512)  + 1;

    if (size < 8 + (size_t)srcw * srch * 3) {
        free(data);
        return 0;
    }

    size_t dst_size = (size_t)dstw * dsth * 3;
    unsigned char *dst = malloc(dst_size);
    if (!dst) { free(data); return 1; }

    sixel_helper_scale_image(dst, data + 8, srcw, srch,
                             SIXEL_PIXELFORMAT_RGB888,
                             dstw, dsth, 0, NULL);

    free(dst);
    free(data);
    return 0;
}
