#!/usr/bin/env python3
"""Host-side check that every battle resolves to a complete, fitting background.

A battle's background comes from the map's battle_scene, the trainer class or the tile, through
gBattleEnvironmentInfo. This fails when:
  1. a map uses a battle_scene that is not defined, or a scene has no row in sMapBattleSceneMapping;
  2. an environment a battle can select lacks entry art, background art or a palette, or one of
     its graphics files is missing;
  3. background art is malformed: a tilemap names a tile its tileset lacks or a palette bank
     outside the three the battlefield owns, or a palette is not 48 colors;
  4. a Gym map is not on the Gym scene, or an Elite Four room is left on the default scene.

Run from the repo root: python3 test/overworld/ValidateBattleScenes.py
"""
import glob
import json
import os
import re
import struct
import sys

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
ELITE_FOUR_ROOM = re.compile(r"(PokemonLeague|EverGrandeCity)_\w+sRoom")


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
