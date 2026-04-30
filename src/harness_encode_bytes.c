#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <sixel.h>

static int null_write(char *data, int size, void *priv) {
    (void)data; (void)size; (void)priv;
    return 0;
}

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

    sixel_output_t *output = NULL;
    sixel_dither_t *dither = NULL;

    if (sixel_output_new(&output, null_write, NULL, NULL) != SIXEL_OK)
        goto done;

    dither = sixel_dither_get(SIXEL_BUILTIN_XTERM256);
    if (!dither) goto done;

    sixel_encode(data + 4, width, height, 3, dither, output);

done:
    if (output) sixel_output_unref(output);
    if (dither) sixel_dither_unref(dither);
    free(data);
    return 0;
}
