#include <stdio.h>
#include <stdlib.h>
#include <sixel.h>

static int null_write(char *data, int size, void *priv) {
    (void)data; (void)size; (void)priv;
    return 0;
}

int main(int argc, char **argv) {
    if (argc < 2) return 1;

    sixel_output_t *output = NULL;
    sixel_encoder_t *encoder = NULL;

    if (sixel_output_new(&output, null_write, NULL, NULL) != SIXEL_OK)
        goto done;

    if (sixel_encoder_new(&encoder, NULL) != SIXEL_OK)
        goto done;

    sixel_encoder_encode(encoder, argv[1]);

done:
    if (encoder) sixel_encoder_unref(encoder);
    if (output)  sixel_output_unref(output);
    return 0;
}
