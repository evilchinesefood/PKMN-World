#!/usr/bin/env python3
"""Check that grass field effects are frosted exactly where the map draws frosty grass.

The tall grass rustle, the jump and overworld wild encounter grass hop, and DexNav's shaking grass
take frosty_grass.pal on grass drawn from a secondary tileset listed in sFrostyGrassTilesets
(src/field_effect_helpers.c), and general_1.pal everywhere else. A grass metatile is frosty when its bottom-layer pixels average at
least as blue as green. This fails when:
  1. a map places frosty tall grass from a tileset that is not listed (or from a primary tileset,
     which the runtime lookup never frosts);
  2. a map places green tall grass from a listed tileset's secondary half;
  3. a listed tileset has no frosty tall grass on any map;
  4. a map places frosty long grass (long grass effects keep general_1);
  5. frosty_grass.pal differs from its recipe. Each general_1.pal color the grass effect art draws
     with is replaced by the frosty grass color nearest in relative Rec. 601 luminance: each side's
     luminance scaled to its own darkest-to-lightest range. Plain nearest luminance would turn
     half the green shades into the darkest frost color, since the green art is darker overall.
     Colors the art does not draw stay as they are.

Run from the repo root: python3 test/overworld/ValidateFrostyGrass.py
Pass --write to regenerate frosty_grass.pal from its recipe.
"""
import glob
import json
import os
import re
import struct
import sys

from ValidateBattleScenes import ROOT, png_pixels

GREEN_PAL = "graphics/field_effects/palettes/general_1.pal"
# The art of the effects that take the frosted palette: the rustle, the jump and OWE spawn hop, and
# DexNav's shaking grass (jump_long_grass frame 6 plus unknown_17).
GRASS_ART = ["graphics/field_effects/pics/%s.png" % n for n in ("tall_grass", "jump_tall_grass", "jump_long_grass", "unknown_17")]
FROSTY_PAL = "graphics/field_effects/palettes/frosty_grass.pal"
TALL_GRASS = {"MB_TALL_GRASS", "MB_CYCLING_ROAD_PULL_DOWN_GRASS"}
LONG_GRASS = {"MB_LONG_GRASS"}
FRLG_SPLIT = {"emerald": (512, 6), "frlg": (640, 7), "johto": (640, 7)}


def read(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as fh:
        return fh.read()


def read_pal(path):
    nums = [int(n) for n in read(path).split()[3:]]
    return [tuple(nums[i * 3:i * 3 + 3]) for i in range(len(nums) // 3)]


def write_pal(path, colors):
    with open(os.path.join(ROOT, path), "w", encoding="ascii", newline="") as fh:
        fh.write("JASC-PAL\r\n0100\r\n%d\r\n" % len(colors) + "".join("%d %d %d\r\n" % c for c in colors))


def luma(color):
    r, g, b = color
    return 0.299 * r + 0.587 * g + 0.114 * b


def listed_tilesets():
    body = re.search(r"sFrostyGrassTilesets\[\]\s*=\s*\{(.*?)\};", read("src/field_effect_helpers.c"), re.S)
    return set(re.findall(r"&(gTileset_\w+)", body.group(1))) if body else set()


def tilesets():
    """{gTileset_X: (tiles.png, palettes dir, metatiles.bin, metatile_attributes.bin)}."""
    text = read("src/data/tilesets/graphics.h") + read("src/graphics.c") + read("src/data/tilesets/metatiles.h")
    files = dict(re.findall(r"(\w+)\[\](?:\[16\])?\s*=\s*\{?\s*INC(?:GFX|BIN)_U\d+\(\"([^\"]+)\"", text))
    out = {}
    for name, body in re.findall(r"const struct Tileset (gTileset_\w+) =\s*\{(.*?)\};", read("src/data/tilesets/headers.h"), re.S):
        tiles = re.search(r"\.tiles = (\w+)", body).group(1)
        palettes = re.search(r"\.palettes = (\w+)", body).group(1)
        metatiles, attrs = re.search(r"TILESET_METATILES\((\w+), (\w+)\)", body).groups()
        out[name] = (files[tiles], os.path.dirname(files[palettes]), files[metatiles], files[attrs])
    return out


def behavior_names():
    body = re.search(r"enum\s*\{(.*?)\}", read("include/constants/metatile_behaviors.h"), re.S).group(1)
    return [e.split("=")[0].strip() for e in re.sub(r"//[^\n]*", "", body).split(",") if e.strip()]


def grass_metatiles(sets, names, pixels):
    """Yield (map ids, layout, metatile, tileset, is secondary, behavior, frosty, colors drawn)."""
    maps = {}
    for path in glob.glob(os.path.join(ROOT, "data/maps/*/map.json")):
        data = json.load(open(path, encoding="utf-8"))
        maps.setdefault(data["layout"], []).append(data["id"])
    for layout in json.loads(read("data/layouts/layouts.json"))["layouts"]:
        names_used = (layout.get("primary_tileset"), layout.get("secondary_tileset"))
        if layout.get("id") not in maps or not all(n in sets for n in names_used):
            continue
        split, primary_pals = FRLG_SPLIT[layout["layout_version"]]
        halves = [sets[n] for n in names_used]
        blocks = open(os.path.join(ROOT, layout["blockdata_filepath"]), "rb").read()
        for metatile in sorted({b[0] & 0x3FF for b in struct.iter_unpack("<H", blocks)}):
            half = int(metatile >= split)
            _, _, mt_path, attr_path = halves[half]
            mt, attrs = open(os.path.join(ROOT, mt_path), "rb").read(), open(os.path.join(ROOT, attr_path), "rb").read()
            local, width = metatile - split * half, len(attrs) * 16 // len(mt)
            if local * 16 >= len(mt):
                continue
            attr = int.from_bytes(attrs[local * width:(local + 1) * width], "little")
            behavior = names[attr & (0x1FF if width == 4 else 0xFF)]
            if behavior not in TALL_GRASS | LONG_GRASS:
                continue
            total, colors = [0, 0, 0], set()
            for (entry,) in struct.iter_unpack("<H", mt[local * 16:local * 16 + 8]):
                tile, bank = entry & 0x3FF, entry >> 12
                rows = pixels(halves[0][0] if tile < split else halves[1][0])
                pal = read_pal(os.path.join(halves[0][1] if bank < primary_pals else halves[1][1], f"{bank:02d}.pal"))
                columns, tile = len(rows[0]) // 8, tile % split
                for j in range(8):
                    y = tile // columns * 8 + j
                    for i in range(8):
                        index = rows[y][tile % columns * 8 + i] & 15 if y < len(rows) else 0
                        if index:
                            colors.add(pal[index])
                            total = [t + c for t, c in zip(total, pal[index])]
            frosty = total[2] >= total[1] > 0
            yield maps[layout["id"]], layout["id"], metatile, names_used[half], half == 1, behavior, frosty, colors


def recipe(frost_colors, pixels):
    green = read_pal(GREEN_PAL)
    drawn = sorted({i for art in GRASS_ART for row in pixels(art) for i in row if i})

    def relative(colors):
        lo, hi = min(map(luma, colors)), max(map(luma, colors))
        return lambda c: (luma(c) - lo) / (hi - lo)

    src, dst = relative([green[i] for i in drawn]), relative(frost_colors)
    out = list(green)
    for i in drawn:
        out[i] = min(sorted(frost_colors, key=luma), key=lambda c: abs(dst(c) - src(green[i])))
    return out


def main():
    listed, sets, names, cache = listed_tilesets(), tilesets(), behavior_names(), {}
    pixels = lambda png: cache.setdefault(png, png_pixels(os.path.join(ROOT, png)))
    bad, frosty_sets, frost_colors, counts = [], set(), set(), {True: 0, False: 0}
    for map_ids, layout, metatile, tileset, secondary, behavior, frosty, colors in grass_metatiles(sets, names, pixels):
        where = f"{'/'.join(sorted(map_ids))} ({layout}) metatile {metatile} from {tileset}"
        counts[frosty] += 1
        if behavior in LONG_GRASS:
            if frosty:
                bad.append(f"{where}: frosty long grass, but long grass effects keep general_1")
            continue
        frosted = secondary and tileset in listed
        if frosty and not frosted:
            bad.append(f"{where}: frosty tall grass, but its effects draw general_1 (list the secondary tileset in sFrostyGrassTilesets)")
        elif frosted and not frosty:
            bad.append(f"{where}: green tall grass, but sFrostyGrassTilesets frosts its effects")
        if frosty and frosted:
            frosty_sets.add(tileset)
            frost_colors |= colors
    for tileset in sorted(listed - frosty_sets):
        bad.append(f"{tileset}: listed in sFrostyGrassTilesets, but no map places frosty tall grass from it")
    if frost_colors:
        expected = recipe(frost_colors, pixels)
        if "--write" in sys.argv[1:]:
            write_pal(FROSTY_PAL, expected)
        elif not os.path.exists(os.path.join(ROOT, FROSTY_PAL)) or read_pal(FROSTY_PAL) != expected:
            bad.append(f"{FROSTY_PAL}: differs from its recipe (run with --write)")
    for line in bad:
        print("ERROR: " + line)
    print(f"ValidateFrostyGrass: {counts[True]} frosty and {counts[False]} green grass metatiles placed, "
          f"{len(listed)} frosted tileset(s), {len(bad)} error(s)")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
