#!/usr/bin/env python3
"""Census registered maps and validate structural content; not a playthrough."""
import argparse
import json
import re
from collections import Counter, defaultdict
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--report", type=Path, help="Write a JSON census to this path")
args = parser.parse_args()
ROOT = Path(__file__).resolve().parents[2]
groups = json.loads((ROOT / "data/maps/map_groups.json").read_text())
layouts = {x["id"]: x for x in json.loads((ROOT / "data/layouts/layouts.json").read_text())["layouts"]}
maps = {}
zones = {}
counts = defaultdict(Counter)
issues = []
script_labels = set()
for source in (ROOT / "data").rglob("*"):
    if source.suffix in (".inc", ".s"):
        script_labels.update(re.findall(r"^([A-Za-z_]\w*)::?", source.read_text(), re.M))
for index, group in enumerate(groups["group_order"]):
    zone = "Hoenn" if index < 34 else "Kanto" if index < 75 else "Johto" if index < 100 else "World hub"
    for name in groups[group]:
        path = ROOT / "data/maps" / name / "map.json"
        data = json.loads(path.read_text())
        maps[data["id"]] = data
        zones[data["id"]] = zone
        counts[zone]["registered_maps"] += 1
        layout = layouts.get(data["layout"])
        if layout is None:
            issues.append([zone, name, "missing layout", data["layout"]])
            continue
        raw = ROOT / layout["blockdata_filepath"]
        if not raw.is_file() or raw.stat().st_size != layout["width"] * layout["height"] * 2:
            issues.append([zone, name, "missing or wrong-sized blockdata", str(raw.relative_to(ROOT))])
        if not (ROOT / layout["border_filepath"]).is_file():
            issues.append([zone, name, "missing border", layout["border_filepath"]])
        script = ROOT / "data/maps" / data.get("shared_scripts_map", name) / "scripts.inc"
        if not script.is_file() and data.get("shared_scripts_map", name) + "_MapScripts" not in script_labels:
            issues.append([zone, name, "missing scripts", str(script.relative_to(ROOT))])
        counts[zone]["object_events"] += len(data.get("object_events", []))
        counts[zone]["warp_events"] += len(data.get("warp_events", []))

dynamic = []
for mid, data in maps.items():
    zone = zones[mid]
    for index, warp in enumerate(data.get("warp_events", [])):
        dest = warp["dest_map"]
        if dest in ("MAP_DYNAMIC", "MAP_UNDEFINED"):
            dynamic.append([data["name"], index, dest])
            counts[zone]["dynamic_warps"] += 1
            continue
        target = maps.get(dest)
        if target is None:
            issues.append([zone, data["name"], "unregistered warp destination", dest])
            continue
        wid = str(warp["dest_warp_id"])
        if wid.isdigit() and int(wid) not in (127, 255) and int(wid) >= len(target.get("warp_events", [])):
            issues.append([zone, data["name"], "destination warp out of bounds", dest, wid])
    for connection in data.get("connections") or []:
        if connection["map"] not in maps:
            issues.append([zone, data["name"], "unregistered connection", connection["map"]])

for group in json.loads((ROOT / "src/data/wild_encounters.json").read_text())["wild_encounter_groups"]:
    if not group["for_maps"]:
        continue
    for encounter in group["encounters"]:
        mid = encounter["map"]
        if mid not in maps:
            issues.append(["encounters", mid, "unregistered encounter map"])
            continue
        zone = zones[mid]
        counts[zone]["encounter_headers"] += 1
        for field in ("land_mons", "water_mons", "fishing_mons", "rock_smash_mons", "hidden_mons"):
            if field in encounter:
                counts[zone][field + "_tables"] += 1

result = {"scope": "Registered map groups only. Sealed link, prototype and dynamic facility maps remain in the census. Counts are not completion percentages.",
          "zones": {k: dict(v) for k, v in counts.items()}, "issues": issues, "dynamic_warps": dynamic}
if args.report:
    args.report.write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps({"zones": result["zones"], "issues": issues}, indent=2))
raise SystemExit(bool(issues))
