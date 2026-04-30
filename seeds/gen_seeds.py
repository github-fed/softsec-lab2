#!/usr/bin/env python3
import os
import struct
import zlib

ESC = b'\x1b'

SEEDS_DIR   = os.path.dirname(os.path.abspath(__file__))
PIXELS_DIR  = os.path.join(SEEDS_DIR, '..', 'seeds_pixels')
IMAGES_DIR  = os.path.join(SEEDS_DIR, '..', 'seeds_images')


def sixel(body: str) -> bytes:
    return ESC + b'Pq\n' + body.encode() + ESC + b'\\'

def sixel_params(p1, p2, p3, body: str) -> bytes:
    header = f'{p1};{p2};{p3}q\n'.encode()
    return ESC + b'P' + header + body.encode() + ESC + b'\\'

sixel_seeds = {
    # Single color (RGB)
    'minimal.six': sixel(
        '#0;2;100;100;100\n'
        '#0~$\n'
    ),

    # EPFL logo
    # sixel_decode_raw should return width=37, height=12, ncolors=3
    'epfl.six': sixel(
        '#0;2;100;0;0\n'
        '#1;2;100;100;100\n'
        '#0!37~$\n'
        '#1?}}eeeee??}}eeee}[??}}eeeee??}}??????-\n'
        '#0!37~$\n'
        '#1?^^XXXXX??^^@@@@????^^@@@@@??^^WWWWW?$\n'
    ),
}


def pixel_seed(width, height, rgb=(128, 128, 128), extra_header=b''):
    """4-byte dimension header + uniform pixel buffer."""
    header = struct.pack('<HH', width, height) + extra_header
    pixels = bytes(rgb) * (width * height)
    return header + pixels

def scale_seed(srcw, srch, dstw, dsth, rgb=(128, 128, 128)):
    """8-byte header (src + dst dims) + src pixel buffer."""
    header = struct.pack('<HHHH', srcw, srch, dstw, dsth)
    pixels = bytes(rgb) * (srcw * srch)
    return header + pixels

pixel_seeds = {
    'pixel_1x1.bin':   pixel_seed(1, 1, (128, 128, 128)),
    'pixel_4x4.bin':   pixel_seed(4, 4, (200,  50,  50)),
    'pixel_16x16.bin': pixel_seed(16, 16, (50, 200, 50)),
    'pixel_64x64.bin': pixel_seed(64, 64, (50,  50, 200)),
}

scale_seeds = {
    'scale_1x1_to_4x4.bin':    scale_seed(1,  1,  4,  4),
    'scale_4x4_to_16x16.bin':  scale_seed(4,  4,  16, 16),
    'scale_16x16_to_8x8.bin':  scale_seed(16, 16, 8,  8),
}


def make_png(width=1, height=1, rgb=(128, 128, 128)):
    def chunk(type_bytes, data):
        crc = zlib.crc32(type_bytes + data) & 0xffffffff
        return struct.pack('>I', len(data)) + type_bytes + data + struct.pack('>I', crc)

    signature = b'\x89PNG\r\n\x1a\n'
    ihdr = chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
    # One row: filter byte 0x00 followed by RGB pixels
    raw = b''.join(b'\x00' + bytes(rgb) for _ in range(height))
    idat = chunk(b'IDAT', zlib.compress(raw))
    iend = chunk(b'IEND', b'')
    return signature + ihdr + idat + iend

def make_bmp(width=1, height=1, rgb=(128, 128, 128)):
    # 24-bit BMP; rows are bottom-up, padded to 4 bytes
    row_size = (width * 3 + 3) & ~3
    pixel_data_size = row_size * height
    file_size = 54 + pixel_data_size
    row = (bytes([rgb[2], rgb[1], rgb[0]]) * width).ljust(row_size, b'\x00')
    bmp  = b'BM'
    bmp += struct.pack('<I', file_size)
    bmp += struct.pack('<HH', 0, 0)
    bmp += struct.pack('<I', 54)
    bmp += struct.pack('<IiiHHIIiiII', 40, width, height, 1, 24, 0,
                       pixel_data_size, 2835, 2835, 0, 0)
    bmp += row * height
    return bmp

image_seeds = {
    'minimal_1x1.png': make_png(1, 1, (128, 128, 128)),
    'minimal_4x4.png': make_png(4, 4, (200,  50,  50)),
    'minimal_1x1.bmp': make_bmp(1, 1, (128, 128, 128)),
    'minimal_4x4.bmp': make_bmp(4, 4, (50, 200,  50)),
}


def write_seeds(directory, seeds_dict):
    os.makedirs(directory, exist_ok=True)
    for name, data in seeds_dict.items():
        path = os.path.join(directory, name)
        with open(path, 'wb') as f:
            f.write(data)
        print(f'wrote {path} ({len(data)} bytes)')

write_seeds(SEEDS_DIR,  sixel_seeds)
write_seeds(PIXELS_DIR, {**pixel_seeds, **scale_seeds})
write_seeds(IMAGES_DIR, image_seeds)
