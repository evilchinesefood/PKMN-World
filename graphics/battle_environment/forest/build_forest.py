#!/usr/bin/env python3
"""Build the forest battle background from the tall grass one.

The tall grass platforms and floor stripes stay. Rows 0-5 and the wrapped rows 30-31 of both
32x32 screen blocks become the same seamless 256-pixel tree line drawn in palette bank 4, the third bank
of the environment palette, whose first three colors the tall grass entry slide still uses. Banks
2 and 3 take darker forest-floor greens.

Run from the repo root: python3 graphics/battle_environment/forest/build_forest.py
"""
import math
import random
import struct
from pathlib import Path

from PIL import Image

SRC = Path("graphics/battle_environment/tall_grass")
OUT = Path("graphics/battle_environment/forest")

WIDTH = 256
BAND_ROWS = [30, 31, 0, 1, 2, 3, 4, 5]
BAND_HEIGHT = 8 * len(BAND_ROWS)
GROUND = BAND_HEIGHT

FLOOR = {
    1: (120, 168, 96), 2: (96, 176, 88), 3: (144, 208, 96), 4: (152, 200, 136),
    5: (112, 184, 96), 6: (160, 208, 144), 7: (128, 192, 96), 15: (112, 160, 88),
}
SHADOW, DARK, MID, LEAF, LIGHT, SUN, BARK_DARK, BARK, BARK_LIGHT, MOSS = range(4, 14)
TREE_COLORS = {
    SHADOW: (24, 48, 32), DARK: (32, 72, 40), MID: (48, 104, 48), LEAF: (72, 136, 56),
    LIGHT: (104, 168, 64), SUN: (152, 208, 88), BARK_DARK: (56, 40, 32), BARK: (96, 72, 48),
    BARK_LIGHT: (136, 104, 64), MOSS: (64, 112, 56),
}


def read_pal(path):
    lines = path.read_text().split("\n")[3:]
    return [tuple(int(v) for v in line.split()) for line in lines if line.strip()]


def write_pal(path, colors):
    rows = [f"{r} {g} {b}" for r, g, b in colors]
    path.write_bytes(("\r\n".join(["JASC-PAL", "0100", str(len(colors)), *rows]) + "\r\n").encode())


def disc(img, cx, cy, r, color, squash=1.15):
    for y in range(int(cy - r) - 1, int(cy + r) + 2):
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            if 0 <= y < BAND_HEIGHT and math.hypot(x - cx, (y - cy) * squash) <= r:
                img[x % WIDTH][y] = color


def crown(img, cx, cy, r, body, rim, shade, rng):
    """A tree crown built from leaf clumps: shade under, body, then lit clumps toward the upper left."""
    disc(img, cx + 1, cy + 2, r, shade)
    disc(img, cx, cy, r, body)
    for _ in range(int(r * 1.6)):
        a, d = rng.uniform(0, 2 * math.pi), rng.uniform(0, r * 0.75)
        x, y = cx + d * math.cos(a), cy + d * math.sin(a)
        lit = (cx - x) + (cy - y)
        disc(img, x + 1, y + 1, rng.uniform(2.5, 4), shade)
        disc(img, x, y, rng.uniform(2.5, 4), rim if lit > r * 0.1 else body)


def speckle(img, color, under, chance, rng, y0, y1):
    for y in range(y0, y1):
        for x in range(WIDTH):
            if img[x][y] == under and rng.random() < chance:
                img[x][y] = color


def trunk(img, x0, top, width):
    for y in range(top, GROUND):
        for dx in range(width):
            x = (x0 + dx) % WIDTH
            img[x][y] = BARK_LIGHT if dx == 1 else BARK_DARK if dx >= width - 2 else BARK
    for dx in range(-1, width + 1):
        img[(x0 + dx) % WIDTH][GROUND - 1] = MOSS


def draw_band(rng):
    img = [[SHADOW] * BAND_HEIGHT for _ in range(WIDTH)]
    for i in range(WIDTH // 20):
        crown(img, i * 20 + rng.uniform(-4, 4), rng.uniform(2, 12), rng.uniform(12, 15), DARK, MID, SHADOW, rng)
    for i in range(WIDTH // 32):
        trunk(img, i * 32 + rng.randrange(0, 12), 36, rng.choice([5, 6, 7]))
    for i in range(WIDTH // 26):
        crown(img, i * 32 + 16 + rng.uniform(-4, 4), rng.uniform(24, 30), rng.uniform(13, 16), MID, LIGHT, DARK, rng)
    speckle(img, LEAF, MID, 0.18, rng, 0, BAND_HEIGHT)
    speckle(img, SUN, LIGHT, 0.12, rng, 0, BAND_HEIGHT)
    for i in range(WIDTH // 14):
        crown(img, i * 14 + rng.uniform(-3, 3), GROUND + rng.uniform(-1, 2), rng.uniform(7, 10), DARK, LEAF, SHADOW, rng)
    for x in range(WIDTH):
        if rng.random() < 0.3:
            img[x][GROUND - 1 - rng.randrange(0, 3)] = MOSS
    return img


def tile_key(px, t, per_row):
    return tuple(px[(t % per_row) * 8 + x, (t // per_row) * 8 + y] for y in range(8) for x in range(8))


def main():
    rng = random.Random(0x0F0BE57)
    source = Image.open(SRC / "tiles.png")
    source_px = source.load()
    per_row = source.size[0] // 8
    tilemap = bytearray((SRC / "map.bin").read_bytes())
    entries = struct.unpack(f"<{len(tilemap) // 2}H", tilemap)

    tiles, index_of = [], {}
    def add(key):
        if key not in index_of:
            index_of[key] = len(tiles)
            tiles.append(key)
        return index_of[key]

    add(tile_key(source_px, 0, per_row))
    for i, entry in enumerate(entries):
        struct.pack_into("<H", tilemap, i * 2, (entry & ~0x3FF) | add(tile_key(source_px, entry & 0x3FF, per_row)))

    band = draw_band(rng)
    for row_index, map_row in enumerate(BAND_ROWS):
        for x in range(WIDTH // 8):
            key = tuple(band[x * 8 + px][row_index * 8 + py] for py in range(8) for px in range(8))
            for screen_block in (0, 1):
                struct.pack_into("<H", tilemap, (screen_block * 1024 + map_row * 32 + x) * 2, (4 << 12) | add(key))

    out = Image.new("P", (per_row * 8, (len(tiles) + per_row - 1) // per_row * 8))
    out.putpalette(source.getpalette())
    out_px = out.load()
    for t, key in enumerate(tiles):
        for p, c in enumerate(key):
            out_px[(t % per_row) * 8 + p % 8, (t // per_row) * 8 + p // 8] = c
    OUT.mkdir(parents=True, exist_ok=True)
    out.save(OUT / "tiles.png")
    (OUT / "map.bin").write_bytes(tilemap)

    palette = read_pal(SRC / "palette.pal")
    for bank in (0, 16):
        for index, color in FLOOR.items():
            palette[bank + index] = color
    for index, color in TREE_COLORS.items():
        palette[32 + index] = color
    write_pal(OUT / "palette.pal", palette)
    print(f"{len(tiles)} tiles")


if __name__ == "__main__":
    main()
