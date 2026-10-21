#!/usr/bin/env python3
"""Convert approved artwork to standard Mac icon sizes; no artwork redraw."""
import argparse
import pathlib
import shutil
import subprocess

p = argparse.ArgumentParser()
p.add_argument('--source', required=True)
p.add_argument('--output', required=True)
a = p.parse_args()
source, output = pathlib.Path(a.source), pathlib.Path(a.output)
output.mkdir(parents=True, exist_ok=True)
for appearance in ('Light', 'Dark'):
    original = source / f'ShipianIcon{appearance}.png'
    if not original.is_file():
        raise SystemExit(f'Missing approved artwork: {original}')
    iconset = output / f'Shipian{appearance}.iconset'
    iconset.mkdir(exist_ok=True)
    for points in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            pixels = points * scale
            suffix = '@2x' if scale == 2 else ''
            target = iconset / f'icon_{points}x{points}{suffix}.png'
            subprocess.run(['sips', '-z', str(pixels), str(pixels), str(original), '--out', str(target)], check=True, stdout=subprocess.DEVNULL)
    subprocess.run(['iconutil', '-c', 'icns', str(iconset), '-o', str(output / f'Shipian{appearance}.icns')], check=True)
    shutil.copy2(iconset / 'icon_512x512@2x.png', output / f'ShipianIcon{appearance}.png')
