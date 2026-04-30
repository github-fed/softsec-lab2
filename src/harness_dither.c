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

    if (size < 4 || size > 1000000) {
        fclose(f);
        return 0;
    }

    unsigned char *data = malloc(size);
    if (!data) { fclose(f); return 1; }
    fread(data, 1, size, f);
    fclose(f);

    uint16_t width  = (uint16_t)(((uint16_t)data[0] | ((uint16_t)data[1] << 8)) % 1024) + 1;
    uint16_t height = (uint16_t)(((uint16_t)data[2] | ((uint16_t)data[3] << 8)) % 1024) + 1;

    if (size < 4 + (size_t)width * height * 3) {
        free(data);
        return 0;
    }

    sixel_dither_t *dither = NULL;
    if (sixel_dither_new(&dither, 256, NULL) != SIXEL_OK) {
        free(data);
        return 0;
    }

    sixel_dither_initialize(dither, data + 4, width, height,
                            SIXEL_PIXELFORMAT_RGB888, 0, 0, 0);

    sixel_dither_unref(dither);
    free(data);
    return 0;
}
