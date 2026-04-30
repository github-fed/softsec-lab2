#include <stdio.h>
#include <stdlib.h>
#include <sixel.h>

int main(int argc, char **argv) {
    if (argc < 2) return 1;

    FILE *f = fopen(argv[1], "rb");
    if (!f) return 1;

    fseek(f, 0, SEEK_END);
    size_t size = ftell(f);
    fseek(f, 0, SEEK_SET);

    if (size == 0 || size > 1000000) {
        fclose(f);
        return 0;
    }

    unsigned char *data = malloc(size);
    if (!data) {
        fclose(f);
        return 1;
    }
    fread(data, 1, size, f);
    fclose(f);

    unsigned char *pixels = NULL;
    int width = 0;
    int height = 0;
    unsigned char *palette = NULL;
    int ncolors = 0;

    sixel_decode_raw(data, (int)size, &pixels, &width, &height, &palette, &ncolors, NULL);

    free(data);
    free(pixels);
    free(palette);

    return 0;
}