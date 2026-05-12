#!/usr/bin/env python3
import os
import struct
import zlib

ESC = b'\x1b'

SEEDS_DIR  = os.path.dirname(os.path.abspath(__file__))
IMAGES_DIR = os.path.join(SEEDS_DIR, '..', 'seeds_images')


def sixel(body: str) -> bytes:
    return ESC + b'Pq\n' + body.e({len(data)} bytes)')

write_seeds(SEEDS_DIR,  sixel_seeds)
writ