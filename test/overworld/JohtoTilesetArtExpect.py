#!/usr/bin/env python3
"""Expected art hashes for test/overworld/lua/JohtoTilesetArt.lua, read from pokemonHnS.

The Johto maps were ported from pokemonHnS, so HnS's own layout and tileset files are the oracle
for what a Johto cell should draw. For each cell the suite checks, this resolves the metatile id
in HnS's blockdata through HnS's tilesets (640/640 split, as every Johto layout uses) and hashes
the 16x16 picture as palette-slot and colour indices: FNV-1a over 256 bytes of (pal << 4 | colour),
row-major, the top layer over the bottom with colour 0 transparent. The suite hashes the same
picture from the running game's metatile entries and BG tile data in VRAM.

Usage: python3 test/overworld/JohtoTilesetArtExpect.py <pokemonHnS clone> [suite]
A sparse clone is enough: data/layouts, data/tilesets/secondary, data/tilesets/primary and src.
Prints the Lua table rows the suite (default JohtoTilesetArt) embeds.
"""
import json
import os
import re
import struct
import sys

from PIL import Image

SPLIT = 640

# suite -> (map key, HnS layout id, cells). Cells mix ones the port drew wrong with controls it
# drew right, so the controls prove the hash matches the game before the others are judged.
SUITES = {}
SUITES["JohtoTilesetArt"] = [
    ("will", "LAYOUT_POKEMON_LEAGUE_WILLS_ROOM", [(3, 0), (9, 0), (6, 9)]),
    ("koga", "LAYOUT_POKEMON_LEAGUE_KOGAS_ROOM", [(2, 4), (10, 6), (5, 0), (6, 9)]),
    ("bruno", "LAYOUT_POKEMON_LEAGUE_BRUNOS_ROOM", [(3, 0), (9, 0), (6, 9)]),
    ("karen", "LAYOUT_POKEMON_LEAGUE_KARENS_ROOM", [(2, 4), (10, 6), (6, 9)]),
    ("champion", "LAYOUT_POKEMON_LEAGUE_CHAMPIONS_ROOM", [(5, 4), (5, 8), (1, 4), (6, 16)]),
    ("hof", "LAYOUT_POKEMON_LEAGUE_HALL_OF_FAME", [(5, 12), (5, 8)]),
    ("cianwood_shop", "LAYOUT_CIANWOOD_SHOP", [(4, 6), (11, 6), (8, 9)]),
]
SUITES["JohtoViridianIndigoTiles"] = [
    ("route28_house", "LAYOUT_ROUTE28", [(21, 6), (20, 9), (19, 10), (21, 7)]),
    ("route28_gate", "LAYOUT_ROUTE28", [(49, 10), (52, 13), (50, 10)]),
    ("route26n", "LAYOUT_ROUTE26NORTH", [(8, 3), (11, 6), (9, 3)]),
    ("indigo", "LAYOUT_INDIGO_PLATEAU", [(11, 8), (8, 9), (7, 5), (10, 4)]),
]


def tileset_files(root):
    hdr = open(os.path.join(root, "src/data/tilesets/headers.h")).read()
    meta = open(os.path.join(root, "src/data/tilesets/metatiles.h")).read()
    gfx = open(os.path.join(root, "src/data/tilesets/graphics.h")).read()
    out = {}
    for name, body in re.findall(r"const struct Tileset (gTileset_\w+)\s*=\s*\{(.*?)\};", hdr, re.S):
        tiles = re.search(r"\.tiles\s*=\s*(\w+)", body)
        mt = re.search(r"(?:\.metatiles\s*=\s*|TILESET_METATILES\()(\w+)", body)
        if not (tiles and mt):
            continue
        t = re.search(re.escape(tiles.group(1)) + r'\[\]\s*=\s*INC\w+\("([^"]+)"', gfx)
        m = re.search(re.escape(mt.group(1)) + r'\[\]\s*=\s*INC\w+\("([^"]+)"', meta)
        if t and m:
            png = re.sub(r"(\.4bpp.*|\.png)$", "", t.group(1)) + ".png"
            out[name] = (os.path.join(root, png), os.path.join(root, m.group(1)))
    return out


def load_tiles(path):
    im = Image.open(path)
    w, h = im.size
    px = im.load()
    return [[[px[tx * 8 + x, ty * 8 + y] & 0xF for x in range(8)] for y in range(8)]
            for ty in range(h // 8) for tx in range(w // 8)]


def cell_hash(tiles, metatiles, blk, width, x, y):
    mid = struct.unpack_from("<H", blk, 2 * (y * width + x))[0] & 0x3FF
    src, idx = (metatiles[0], mid) if mid < SPLIT else (metatiles[1], mid - SPLIT)
    entries = struct.unpack_from("<8H", src, idx * 16)
    pic = [0] * 256
    for layer in range(2):
        for q in range(4):
            e = entries[layer * 4 + q]
            t, hf, vf, pal = e & 0x3FF, (e >> 10) & 1, (e >> 11) & 1, e >> 12
            tile = tiles[0][t] if t < SPLIT else tiles[1][t - SPLIT]
            for ty in range(8):
                for tx in range(8):
                    c = tile[7 - ty if vf else ty][7 - tx if hf else tx]
                    if c == 0 and layer == 1:
                        continue
                    pic[((q >> 1) * 8 + ty) * 16 + (q & 1) * 8 + tx] = 0 if c == 0 else (pal << 4) | c
    h = 0x811C9DC5
    for v in pic:
        h = ((h ^ v) * 16777619) & 0xFFFFFFFF
    return mid, h


def main():
    if len(sys.argv) not in (2, 3):
        sys.exit(__doc__)
    root = sys.argv[1]
    suite = sys.argv[2] if len(sys.argv) == 3 else "JohtoTilesetArt"
    files = tileset_files(root)
    layouts = {l["id"]: l for l in json.load(open(os.path.join(root, "data/layouts/layouts.json")))["layouts"] if l}
    for key, lid, cells in SUITES[suite]:
        lay = layouts[lid]
        prim, sec = files[lay["primary_tileset"]], files[lay["secondary_tileset"]]
        tiles = (load_tiles(prim[0]), load_tiles(sec[0]))
        metatiles = (open(prim[1], "rb").read(), open(sec[1], "rb").read())
        blk = open(os.path.join(root, lay["blockdata_filepath"]), "rb").read()
        rows = []
        for x, y in cells:
            mid, h = cell_hash(tiles, metatiles, blk, lay["width"], x, y)
            rows.append("{ %d, %d, 0x%03X, 0x%08X }" % (x, y, mid, h))
        print("  %s = { %s }," % (key, ", ".join(rows)))


if __name__ == "__main__":
    main()
