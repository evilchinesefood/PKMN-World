#!/usr/bin/env python3
"""Host-side check that every battle resolves to a complete, fitting background.

A battle's background comes from the map's battle_scene, the trainer class or the tile, through
gBattleEnvironmentInfo. This fails when:
  1. a map uses a battle_scene that is not defined, or a scene has no row in sMapBattleSceneMapping;
  2. an environment a battle can select lacks entry art, background art or a palette, or one of
     its graphics files is missing;
  3. background art is malformed: a tilemap names a tile its tileset lacks or a palette bank
     outside the three the battlefield owns, or a palette is not 48 colors;
  4. a Gym map is not on the Gym scene, or an Elite Four room is left on the default scene;
  5. the Battle Tower multi battle intro tilemaps are not cut from the Frontier background.
     BattleIntroSlidePartner draws them over that background with its tiles (char base 2): the
     opponent half is the background's rows 0-9, the player half its rows 10-13 lowered six rows
     with row 2 as filler above, and every other cell is a blank tile;
  6. a palette in battle-palettes/palette-sources.json differs from its recipe (the base palette
     with each listed index replaced by that color of the overworld tileset palette);
  7. a map whose grass encounter tiles are drawn frosty (their colors average at least as blue as
     green) has no grass row in sMapBattlePresentations, or a grass row restyles a green-grass map.

Run from the repo root: python3 test/overworld/ValidateBattleScenes.py
Pass --write to regenerate the two intro tilemaps and the palette-sources.json palettes.
"""
import glob
import json
import os
import re
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GFX = "graphics/battle_environment"

# Environments chosen by BattleSetup_GetEnvironmentId (tile and map type) and by
# GetBattleEnvironmentOverride (battle type, legendary species, trainer class).
SELECTED_BY_CODE = (
    "GRASS LONG_GRASS SAND UNDERWATER WATER POND MOUNTAIN CAVE BUILDING PLAIN "
    "FRONTIER LEADER CHAMPION GROUDON KYOGRE RAYQUAZA"
).split()

# Rooms where the trainer class picks the background, so the scene may stay default.
CLASS_SELECTED_ROOM = re.compile(r"ChampionsRoom|HallOfFame")
PALETTE_SOURCES = "test/overworld/battle-palettes/palette-sources.json"
GRASS_ENVIRONMENTS = {"MB_TALL_GRASS": "GRASS", "MB_CYCLING_ROAD_PULL_DOWN_GRASS": "GRASS", "MB_LONG_GRASS": "LONG_GRASS"}
FRLG_PRIMARY = {"emerald": False, "frlg": True, "johto": True}

ELITE_FOUR_ROOM = re.compile(r"(PokemonLeague|EverGrandeCity)_\w+sRoom")

MULTI_INTRO = {
    "opponent": "graphics/battle_frontier/multi_battle_intro_bg_opponent.bin",
    "player": "graphics/battle_frontier/multi_battle_intro_bg_player.bin",
}


def read(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as fh:
        return fh.read()


def scene_constants():
    """Return (enum members, alias -> enum member) from map_types.h."""
    text = read("include/constants/map_types.h")
    body = re.search(r"enum MapBattleScene\s*\{(.*?)\}", text, re.S).group(1)
    members = [m for m in re.findall(r"\b(MAP_BATTLE_SCENE_\w+)", body) if not m.endswith("_COUNT")]
    alias = {m: m for m in members}
    for name, target in re.findall(r"#define\s+(MAP_BATTLE_SCENE_\w+)\s+(MAP_BATTLE_SCENE_\w+)", text):
        alias[name] = target
    for name in list(alias):
        seen = set()
        while alias[name] != name and alias[name] in alias and alias[name] not in seen and alias[alias[name]] != alias[name]:
            seen.add(alias[name])
            alias[name] = alias[alias[name]]
    return members, alias


def environment_table():
    """Return {environment: entry block text} from gBattleEnvironmentInfo."""
    text = read("src/data/battle_environment.h")
    table = text[text.index("gBattleEnvironmentInfo[BATTLE_ENVIRONMENT_COUNT]"):text.index("sMapBattleSceneMapping")]
    parts = re.split(r"\[BATTLE_ENVIRONMENT_(\w+)\]\s*=", table)
    return {parts[i]: parts[i + 1] for i in range(1, len(parts), 2)}


def scene_mapping():
    text = read("src/data/battle_environment.h")
    body = text[text.index("sMapBattleSceneMapping[] ="):]
    return dict(re.findall(r"\{(MAP_BATTLE_SCENE_\w+),\s*BATTLE_ENVIRONMENT_(\w+)\}", body))


def graphics_files():
    """Return {symbol: source path} from the battle environment graphics header."""
    text = read("src/data/graphics/battle_environment.h")
    return dict(re.findall(r"(gBattleEnvironment\w+)\[\]\s*=\s*INCGFX_U\d+\(\"([^\"]+)\"", text))


def environment_symbols(block):
    """Symbols one table entry uses, or None for each missing part."""
    entry = re.search(r"\.entry\s*=\s*ENVIRONMENT_ENTRY\((\w+)\)", block)
    background = re.search(r"\.background\s*=\s*ENVIRONMENT_BACKGROUND\((\w+)\)", block)
    palette = re.search(r"\.palette\s*=\s*(\w+)", block)
    symbols = []
    if entry:
        symbols += [f"gBattleEnvironmentAnimTiles_{entry.group(1)}", f"gBattleEnvironmentAnimTilemap_{entry.group(1)}"]
    if background:
        symbols += [f"gBattleEnvironmentTiles_{background.group(1)}", f"gBattleEnvironmentTilemap_{background.group(1)}"]
    if palette:
        symbols.append(palette.group(1))
    return {"entry": entry, "background": background, "palette": palette}, symbols


def png_size(path):
    with open(path, "rb") as fh:
        head = fh.read(24)
    return struct.unpack(">II", head[16:24])


def png_pixels(path):
    """Palette indices of an 8-bit or 4-bit indexed PNG, as a list of rows."""
    data = open(path, "rb").read()
    width, height = struct.unpack(">II", data[16:24])
    depth, color = data[24], data[25]
    assert color == 3 and depth in (4, 8), f"{path}: not an indexed 4- or 8-bit PNG"
    pos, idat = 8, b""
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        if kind == b"IDAT":
            idat += data[pos + 8:pos + 8 + length]
        pos += 12 + length
    raw, stride = zlib.decompress(idat), (width * depth + 7) // 8
    rows, prev = [], bytearray(stride)
    for y in range(height):
        kind, line = raw[y * (stride + 1)], bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        for i in range(stride):
            left = line[i - 1] if i else 0
            up, corner = prev[i], prev[i - 1] if i else 0
            if kind == 1:
                line[i] = (line[i] + left) & 0xFF
            elif kind == 2:
                line[i] = (line[i] + up) & 0xFF
            elif kind == 3:
                line[i] = (line[i] + (left + up) // 2) & 0xFF
            elif kind == 4:
                p = left + up - corner
                pa, pb, pc = abs(p - left), abs(p - up), abs(p - corner)
                line[i] = (line[i] + (left if pa <= pb and pa <= pc else up if pb <= pc else corner)) & 0xFF
        prev = line
        rows.append([b >> 4 if x % 2 == 0 else b & 15 for x, b in ((x, line[x // 2]) for x in range(width))]
                    if depth == 4 else list(line[:width]))
    return rows


def first_blank_tile(tiles_path):
    rows = png_pixels(os.path.join(ROOT, tiles_path))
    columns = len(rows[0]) // 8
    for tile in range(columns * (len(rows) // 8)):
        x, y = tile % columns * 8, tile // columns * 8
        if not any(rows[y + j][x + i] for j in range(8) for i in range(8)):
            return tile
    return None


def multi_intro_tilemaps(background, blank):
    """Both intro halves for a 64x32 background tilemap (two 32x32 screens)."""
    opponent, player = [blank] * 2048, [blank] * 2048
    for screen in (0, 1):
        for row in range(32):
            for col in range(32):
                at = screen * 1024 + row * 32 + col
                if row < 10:
                    opponent[at] = background[at]
                if row < 2:
                    player[at] = background[at]
                elif row < 16:
                    player[at] = background[screen * 1024 + 2 * 32 + col]
                elif row < 20:
                    player[at] = background[screen * 1024 + (row - 6) * 32 + col]
    return {"opponent": opponent, "player": player}


def check_multi_intro(bad, table, files, write):
    parts, _ = environment_symbols(table["FRONTIER"])
    name = parts["background"].group(1)
    tiles, tilemap = files[f"gBattleEnvironmentTiles_{name}"], files[f"gBattleEnvironmentTilemap_{name}"]
    blank = first_blank_tile(tiles)
    if blank is None:
        bad.append(f"{tiles}: the multi battle intro needs a blank tile in the Frontier background tileset")
        return
    data = open(os.path.join(ROOT, tilemap), "rb").read()
    background = list(struct.unpack(f"<{len(data) // 2}H", data))
    if len(background) != 2048:
        bad.append(f"{tilemap}: the multi battle intro needs a 64x32 Frontier background tilemap")
        return
    for half, entries in multi_intro_tilemaps(background, blank).items():
        path = os.path.join(ROOT, MULTI_INTRO[half])
        expected = struct.pack("<2048H", *entries)
        if write:
            open(path, "wb").write(expected)
        elif open(path, "rb").read() != expected:
            bad.append(f"{MULTI_INTRO[half]}: not cut from {tilemap} (run with --write to regenerate)")


def read_pal(path, count):
    nums = [int(n) for n in read(path).split()[3:]]
    return [tuple(nums[i * 3:i * 3 + 3]) for i in range(count)]


def write_pal(path, colors):
    with open(os.path.join(ROOT, path), "w", encoding="ascii", newline="") as fh:
        fh.write("JASC-PAL\r\n0100\r\n%d\r\n" % len(colors) + "".join("%d %d %d\r\n" % c for c in colors))


def check_palette_sources(bad, write):
    for entry in json.loads(read(PALETTE_SOURCES)):
        base, source = read_pal(entry["base"], 48), read_pal(entry["color_source"], 16)
        expected = [base[i] if s is None else source[s] for i, s in enumerate(entry["source_indices"])]
        if write:
            write_pal(entry["target"], expected)
        elif read_pal(entry["target"], 48) != expected:
            bad.append(f"{entry['target']}: differs from its recipe in {PALETTE_SOURCES} (run with --write)")


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


def behavior_numbers():
    body = re.search(r"enum\s*\{(.*?)\}", read("include/constants/metatile_behaviors.h"), re.S).group(1)
    names = [e.split("=")[0].strip() for e in re.sub(r"//[^\n]*", "", body).split(",") if e.strip()]
    return {n: i for i, n in enumerate(names)}


def frosty_grass(layout, sets, numbers, pixels):
    """{environment: frosty?} for every grass encounter metatile the layout places."""
    wanted = {numbers[mb]: env for mb, env in GRASS_ENVIRONMENTS.items()}
    frlg = FRLG_PRIMARY[layout["layout_version"]]
    split, primary_pals = (640, 7) if frlg else (512, 6)
    halves = [sets[layout["primary_tileset"]], sets[layout["secondary_tileset"]]]
    blocks = struct.iter_unpack("<H", open(os.path.join(ROOT, layout["blockdata_filepath"]), "rb").read())
    found = {}
    for metatile in sorted({b[0] & 0x3FF for b in blocks}):
        half = 0 if metatile < split else 1
        tiles_png, pal_dir, mt_path, attr_path = halves[half]
        mt, attrs = open(os.path.join(ROOT, mt_path), "rb").read(), open(os.path.join(ROOT, attr_path), "rb").read()
        local, width = metatile - split * half, len(attrs) * 16 // len(mt)
        if local * 16 >= len(mt):
            continue
        attr = int.from_bytes(attrs[local * width:(local + 1) * width], "little")
        env = wanted.get(attr & (0x1FF if width == 4 else 0xFF))
        if env is None:
            continue
        total = [0, 0, 0]
        for (entry,) in struct.iter_unpack("<H", mt[local * 16:local * 16 + 8]):
            tile, bank = entry & 0x3FF, entry >> 12
            png = halves[0][0] if tile < split else halves[1][0]
            pal = read_pal(os.path.join(halves[0][1] if bank < primary_pals else halves[1][1], f"{bank:02d}.pal"), 16)
            rows = pixels(png)
            columns, tile = len(rows[0]) // 8, tile % split
            for j in range(8):
                row = rows[tile // columns * 8 + j] if tile // columns * 8 + j < len(rows) else []
                for i in range(8):
                    index = row[tile % columns * 8 + i] & 15 if row else 0
                    if index:
                        total = [t + c for t, c in zip(total, pal[index])]
        found[env] = found.get(env, False) or total[2] >= total[1] > 0
    return found


def check_frosty_grass(bad):
    rows = set(re.findall(r"\{(MAP_\w+),\s*BATTLE_ENVIRONMENT_(\w+),", read("src/battle_presentation.c")))
    restyled = {(m, e) for m, e in rows if e in GRASS_ENVIRONMENTS.values()}
    sets, numbers, cache = tilesets(), behavior_numbers(), {}
    pixels = lambda png: cache.setdefault(png, png_pixels(os.path.join(ROOT, png)))
    maps = {}
    for path in glob.glob(os.path.join(ROOT, "data/maps/*/map.json")):
        data = json.load(open(path, encoding="utf-8"))
        maps.setdefault(data["layout"], []).append(data["id"])
    seen = set()
    for layout in json.loads(read("data/layouts/layouts.json"))["layouts"]:
        if layout.get("id") not in maps or layout.get("primary_tileset") not in sets or layout.get("secondary_tileset") not in sets:
            continue
        for env, frosty in frosty_grass(layout, sets, numbers, pixels).items():
            for map_id in maps[layout["id"]]:
                seen.add((map_id, env))
                if frosty and (map_id, env) not in restyled:
                    bad.append(f"{map_id}: its {env} tiles are frosty but battles there draw the green grass palette")
                if not frosty and (map_id, env) in restyled:
                    bad.append(f"{map_id}: its {env} tiles are green but sMapBattlePresentations restyles them")
    for map_id, env in sorted(restyled - seen):
        bad.append(f"{map_id}: sMapBattlePresentations restyles {env}, but the map has no such tiles")


def check_art(bad):
    for folder in sorted(glob.glob(os.path.join(ROOT, GFX, "*"))):
        name = os.path.relpath(folder, ROOT)
        for pal in sorted(glob.glob(os.path.join(folder, "*.pal"))):
            lines = open(pal, encoding="ascii").read().split()
            if lines[:2] != ["JASC-PAL", "0100"] or lines[2] != "48" or len(lines) != 3 + 48 * 3:
                bad.append(f"{os.path.relpath(pal, ROOT)}: not a 48-color JASC palette")
        for tiles, tilemap, check_bank in (("tiles.png", "map.bin", True), ("anim_tiles.png", "anim_map.bin", False)):
            tiles_path, map_path = os.path.join(folder, tiles), os.path.join(folder, tilemap)
            if not os.path.exists(tiles_path) and not os.path.exists(map_path):
                continue
            if not os.path.exists(tiles_path) or not os.path.exists(map_path):
                bad.append(f"{name}: {tiles} and {tilemap} must both exist")
                continue
            width, height = png_size(tiles_path)
            count = (width // 8) * (height // 8)
            data = open(map_path, "rb").read()
            for i in range(len(data) // 2):
                entry = data[2 * i] | data[2 * i + 1] << 8
                if (entry & 0x3FF) >= count:
                    bad.append(f"{name}/{tilemap}: entry {i} names tile {entry & 0x3FF}, but {tiles} has {count}")
                    break
                # Rows 14 and below of each 32x32 screen block sit under the text box.
                visible = (i % 1024) // 32 < 14
                if check_bank and visible and not 2 <= entry >> 12 <= 4:
                    bad.append(f"{name}/{tilemap}: entry {i} uses palette bank {entry >> 12}, outside 2-4")
                    break


def main():
    bad = []
    members, alias = scene_constants()
    mapping = scene_mapping()
    table = environment_table()
    files = graphics_files()

    for member in members:
        if member != "MAP_BATTLE_SCENE_NORMAL" and member not in mapping:
            bad.append(f"{member} has no row in sMapBattleSceneMapping, so its maps fall back to Plain")

    needed = {env: "selected by code" for env in SELECTED_BY_CODE}
    for scene, env in mapping.items():
        needed.setdefault(env, f"mapped from {scene}")
    for env, why in sorted(needed.items()):
        block = table.get(env)
        if block is None:
            bad.append(f"BATTLE_ENVIRONMENT_{env} ({why}) is missing from gBattleEnvironmentInfo")
            continue
        parts, symbols = environment_symbols(block)
        for part, found in parts.items():
            if not found:
                bad.append(f"BATTLE_ENVIRONMENT_{env} ({why}) has no {part}")
        for symbol in symbols:
            path = files.get(symbol)
            if path is None:
                bad.append(f"BATTLE_ENVIRONMENT_{env}: {symbol} is not declared in the graphics header")
            elif not os.path.exists(os.path.join(ROOT, path)):
                bad.append(f"BATTLE_ENVIRONMENT_{env}: {symbol} points at missing file {path}")

    check_art(bad)
    check_multi_intro(bad, table, files, "--write" in sys.argv[1:])
    check_palette_sources(bad, "--write" in sys.argv[1:])
    check_frosty_grass(bad)

    maps = 0
    for path in sorted(glob.glob(os.path.join(ROOT, "data/maps/*/map.json"))):
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
        name, scene = data.get("name", os.path.basename(os.path.dirname(path))), data.get("battle_scene")
        if scene is None:
            continue
        maps += 1
        if scene not in alias:
            bad.append(f"{name}: battle_scene {scene} is not defined in map_types.h")
            continue
        resolved = alias[scene]
        if "Gym" in name and resolved != "MAP_BATTLE_SCENE_GYM":
            bad.append(f"{name}: a Gym map must use MAP_BATTLE_SCENE_GYM, not {scene}")
        if ELITE_FOUR_ROOM.search(name) and not CLASS_SELECTED_ROOM.search(name) and resolved == "MAP_BATTLE_SCENE_NORMAL":
            bad.append(f"{name}: an Elite Four room must not resolve to the default scene ({scene})")

    if bad:
        print("ValidateBattleScenes: FAIL")
        for line in bad:
            print("  " + line)
        return 1
    print(f"ValidateBattleScenes: PASS ({maps} maps, {len(needed)} environments, {len(mapping)} mapped scenes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
