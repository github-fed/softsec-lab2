#include <stdio.h>
#include <stdlib.h>
#include <sixel.h>

int main(int argc, char **argv) {
    if (argc < 2) return 1;

    /* Silence the encoder's default stdout writes so AFL doesn't
       waste time piping SIXEL escape sequences to the terminal. */
    if (!freopen("/dev/null", "w", stdout)) return 1;

    sixel_encoder_t *encoder = NULL;
    if (sixel_encoder_new(&encoder, NULL) != SIXEL_OK)
        return 0;

    sixel_encoder_encode(encoder, argv[1]);

    sixel_encoder_unref(encoder);
    return 0;
}