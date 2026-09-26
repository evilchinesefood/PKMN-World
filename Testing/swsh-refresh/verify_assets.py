#!/usr/bin/env python3
"""Audit the selective import against pinned donor and World objects; no writes."""
import argparse
import io
import struct
import subprocess
from pathlib import Path
from PIL import Image

p = argparse.ArgumentParser()
p.add_argument('--donor', type=Path, required=True)
p.add_argument('--base', default='8f98876d0237b5e845707471b2f4e821bb61cc82')
a = p.parse_args()
root = Path(__file__).resolve().parents[2]
bag = '4d15e63ade9d835602e09dd26ea672098e13bf1e'
pc = '5ea873b96d7f6238fc3ea503b4685b14279eb91a'
def blob(repo, rev, path):
    return subprocess.check_output(['git', '-C', str(repo), 'show', rev + ':' + path])

def check(path, expected):
    assert (root / path).read_bytes() == expected, path

for name in ('tiles.png', 'bg2.bin', 'bg3.bin', 'contest_hearts.png', 'frame_money.bin',
             'frame_price.bin', 'hm.png', 'select_button.png', 'pocket_arrows.png', 'money.png'):
    path = 'graphics/bag/swsh/' + name
    check(path, blob(a.donor, bag, path))
path = 'graphics/bag/swsh/party_slots.bin'
wide = blob(a.donor, bag, path)
check(path, bytes(wide[row * 8 + col] for row in range(18) for col in (0, 1, 2, 3, 6, 7)))

# Preserve World's existing partner cue while adopting the new sheet's black/white indices.
old = Image.open(io.BytesIO(blob(root, a.base, 'graphics/bag/swsh/tiles.png')))
ids = blob(root, a.base, 'graphics/bag/swsh/multi_battle_swap_prompt.bin')
cue = bytearray()
for tile in ids:
    x, y = (tile % (old.width // 8)) * 8, (tile // (old.width // 8)) * 8
    for dy in range(8):
        for dx in range(0, 8, 2):
            lo, hi = (old.getpixel((x + dx + n, y + dy)) & 15 for n in (0, 1))
            lo, hi = ({4: 5, 9: 4}.get(n, n) for n in (lo, hi))
            cue.append(lo | hi << 4)
check('graphics/bag/swsh/multi_battle_swap_prompt_tiles.bin', cue)
check('graphics/pokemon_storage/swsh/tiles.png', blob(a.donor, pc, 'graphics/pokemon_storage/swsh/tiles.png'))
wallpapers = list((root / 'graphics/pokemon_storage/swsh/wallpapers').glob('*.bin'))
assert len(wallpapers) == 20
for file in wallpapers:
    path = str(file.relative_to(root))
    old = struct.unpack('<1024H', blob(root, a.base, path))
    assert all(tile >> 12 == 1 for tile in old), path
    check(path, struct.pack('<1024H', *(tile & 0x0FFF | 0x2000 for tile in old)))
    check(path, blob(a.donor, pc, path))
print('PASS: 10 exact Bag assets, adapted six-column party frame, preserved World partner cue, exact PC sheet, 20 palette-only wallpaper remaps')
