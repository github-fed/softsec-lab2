#!/usr/bin/env python3
import os

ESC = b'\x1b'

def sixel(body: str) -> bytes:
    return ESC + b'Pq\n' + body.encode() + ESC + b'\\'

def sixel_params(p1, p2, p3, body: str) -> bytes:
    header = f'{p1};{p2};{p3}q\n'.encode()
    return ESC + b'P' + header + body.encode() + ESC + b'\\'

seeds = {
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

out_dir = os.path.dirname(os.path.abspath(__file__))
for name, data in seeds.items():
    path = os.path.join(out_dir, name)
    with open(path, 'wb') as f:
        f.write(data)
    print(f'wrote {path} ({len(data)} bytes)')
