#!/usr/bin/env python3
"""Check the complete Center inventory and each authored arrival/exit tile."""
import json
import re
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def validate():
    source = (ROOT / "src/regional_centers.c").read_text()
    rows = re.findall(
        r'CENTER\((\d+), (MAP_\w+), (REGION_\w+), (\d+), (\d+), '
        r'(HEAL_LOCATION_\w+), (\w+), COMPOUND_STRING\("([^"]+)"\)\)', source)
    maps = {}
    for path in (ROOT / "data/maps").glob("*/map.json"):
        data = json.loads(path.read_text())
        maps[data["id"]] = data
    layouts = {data["id"]: data for data in json.loads(
        (ROOT / "data/layouts/layouts.json").read_text())["layouts"]}
    heals = {data["id"]: data for data in json.loads(
        (ROOT / "src/data/heal_locations.json").read_text())["heal_locations"]}
    exclusions = {
        "MAP_REGION_HUB": "Neutral transit. The regional recovery point remains authoritative.",
        "MAP_BATTLE_FRONTIER_POKEMON_CENTER_1F": "Neutral battle facility, not a campaign checkpoint.",
    }
    expected = {data["respawn_map"] for data in heals.values()
                if "NURSE" in data.get("respawn_npc", "")
                and data["respawn_map"] not in exclusions}
    named_centers = {key for key, data in maps.items()
                     if ("POKEMON_CENTER" in key or "POKECENTER" in key)
                     and "2F" not in key and "B1F" not in key
                     and key not in exclusions}
    actual = {row[1] for row in rows}
    assert expected == actual, f"Recovery inventory mismatch: {expected ^ actual}"
    assert named_centers <= actual, f"Unlisted Center interiors: {named_centers - actual}"
    assert len(rows) == len(actual), "A Center map has multiple checkpoint IDs"
    assert [int(row[0]) for row in rows] == list(range(1, len(rows) + 1)), "IDs have holes or duplicates"
    counts = {}
    rules = set()
    for ident, map_id, region, x, y, heal_id, rule, label in rows:
        x, y = int(x), int(y)
        data = maps[map_id]
        layout = layouts[data["layout"]]
        width, height = layout["width"], layout["height"]
        assert 0 <= x < width and 0 <= y < height, f"{map_id}: arrival outside layout"
        tiles = struct.unpack("<" + "H" * (width * height),
                              (ROOT / layout["blockdata_filepath"]).read_bytes())
        assert (tiles[y * width + x] >> 10) & 3 == 0, f"{map_id}: blocked arrival tile"
        assert not any(event["x"] == x and event["y"] == y
                       for key in ("warp_events", "coord_events", "object_events")
                       for event in data.get(key, [])), f"{map_id}: arrival overlaps an event"
        exits = [event for event in data.get("warp_events", [])
                 if event["x"] == x and event["y"] == y + 1]
        assert exits, f"{map_id}: arrival has no adjacent south exit"
        assert all(maps[event["dest_map"]]["map_type"] in
                   ("MAP_TYPE_TOWN", "MAP_TYPE_CITY", "MAP_TYPE_ROUTE") for event in exits), \
            f"{map_id}: exit does not reach ordinary outdoors"
        assert heals[heal_id]["respawn_map"] == map_id, f"{map_id}: wrong recovery location"
        assert "NURSE" in heals[heal_id]["respawn_npc"], f"{map_id}: recovery has no nurse"
        version = layout["layout_version"]
        expected_region = {"emerald": "REGION_HOENN", "frlg": "REGION_KANTO", "johto": "REGION_JOHTO"}[version]
        assert region == expected_region, f"{map_id}: wrong campaign ownership"
        assert len(label) <= 24, f"{map_id}: name does not fit preview"
        counts[region] = counts.get(region, 0) + 1
        rules.add(rule)
    print(f"Regional Centers: {len(rows)} arrival/exit/recovery entries passed; {counts}; {len(rules)} access rules")
    for map_id, reason in exclusions.items():
        print(f"Excluded {map_id}: {reason}")
    print("Upstairs link rooms, home recovery points, ships, and temporary healers are not Center checkpoints.")


if __name__ == "__main__":
    validate()
