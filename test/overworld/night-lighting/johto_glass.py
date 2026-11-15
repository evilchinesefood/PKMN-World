#!/usr/bin/env python3
"""Give a Johto secondary imported from pokemonHnS the approved amber night glass.

author.py's Johto pass: in each secondary bank 7-12 that has a .pla light mask, the masked
colours that are blue (b > r) are the window glass. The alternate palette (bank + 9) % 16 is the
bank with that glass warmed, it keeps the mask, and swapPalettes gains bit (bank - 7), so
UpdateAltBgPalettes blends the amber in at night. Rerunning writes the same files.

Usage: python3 test/overworld/night-lighting/johto_glass.py gTileset_JohtoViridianCity ...
"""
from pathlib import Path
import re
import sys

from author import warm, write_palette

ROOT = Path(__file__).resolve().parents[3]


def read_palette(path):
    lines = path.read_text().split()
    return [tuple(int(v) for v in lines[3 + 3 * i:6 + 3 * i]) for i in range(16)]


def read_mask(path):
    return sorted(int(line) for line in path.read_text().splitlines() if line.strip().isdigit())


def folder_of(name, graphics):
    m = re.search(r"gTilesetPalettes_" + re.escape(name.removeprefix("gTileset_")) +
                  r'\[\]\[16\]\s*=\s*\{\s*INCGFX_U16\("([^"]+)/palettes/00\.pal"', graphics)
    assert m, f"no palette array for {name} in graphics.h"
    return ROOT / m[1]


def main():
    names = sys.argv[1:]
    if not names:
        sys.exit(__doc__)
    headers_path = ROOT / "src/data/tilesets/headers.h"
    headers = headers_path.read_text()
    graphics = (ROOT / "src/data/tilesets/graphics.h").read_text()
    for name in names:
        folder = folder_of(name, graphics) / "palettes"
        bits = []
        for bank in range(7, 13):
            mask_path = folder / f"{bank:02}.pla"
            if not mask_path.exists():
                continue
            flags = read_mask(mask_path)
            palette = read_palette(folder / f"{bank:02}.pal")
            glass = [i for i in flags if palette[i][2] > palette[i][0]]
            if not glass:
                continue
            alternate = (bank + 9) % 16
            write_palette(folder / f"{alternate:02}.pal", [warm(c) if i in glass else c for i, c in enumerate(palette)])
            (folder / f"{alternate:02}.pla").write_text("".join(f"{i}\n" for i in flags))
            bits.append(bank - 7)
            print(f"{name}: bank {bank} glass {glass} -> alternate {alternate}")
        assert bits, f"{name} has no masked blue glass"
        swap = " | ".join(f"(1 << {bit})" for bit in bits)
        pattern = r"(const struct Tileset " + re.escape(name) + r"\s*=\s*\{)(.*?)(\};)"

        def set_swap(match):
            body = re.sub(r"\n    \.swapPalettes = [^,]+,", "", match[2])
            body = body.replace("    .isCompressed = TRUE,", "    .isCompressed = TRUE,\n    .swapPalettes = " + swap + ",")
            return match[1] + body + match[3]

        headers, count = re.subn(pattern, set_swap, headers, count=1, flags=re.S)
        assert count == 1, name
    headers_path.write_text(headers)


if __name__ == "__main__":
    main()
