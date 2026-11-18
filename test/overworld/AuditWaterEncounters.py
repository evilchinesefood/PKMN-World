#!/usr/bin/env python3
"""Audit water, fishing, Rock Smash and Headbutt encounter tables against the terrain a player reaches.

The flood is ValidateReachability's (every field move unlocked, obstacles ignored), so a cell it
misses is unreachable and a cell it reaches may still need story progress. For every map it
counts what the player can do there and what wild_encounters.json gives back:

  * surf    reached cells in SURF mode (water_mons rolls there);
  * fish    reached cells where CanFish (src/item_use.c) is TRUE for some facing: on foot at
            elevation 3 facing fishable water at another elevation, or surfing facing open
            surfable water;
  * smash   Rock Smash rocks (object events running EventScript_RockSmash);
  * tree    reached cells facing an MB_HEADBUTT_TREE (EventScript_Headbutt reads rock_smash_mons).

Flags print as `<KIND> <map> ...`. A missing table is not a crash (fishing says "Not even a
nibble", RockSmashWildEncounter returns FALSE), so a flag is a lead to check against the source
game, not a verdict. --hns DIR compares every Johto map's tables with pokemonHnS's (species
sets and level ranges per table). --check exits 1 when an UNUSED table or a MISSING one
that the source game fills appears.

    python3 test/overworld/AuditWaterEncounters.py [--map NAME] [--hns DIR] [--check]
"""

import argparse
import collections
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ValidateReachability import DIRS, DIVE, FOOT, SURF, Reach  # noqa: E402

TABLES = ("water_mons", "fishing_mons", "rock_smash_mons", "land_mons")


def load_tables(path):
    with open(path) as f:
        data = json.load(f)
    out = {}
    for group in data["wild_encounter_groups"]:
        if not group.get("for_maps"):
            continue
        for enc in group["encounters"]:
            out.setdefault(enc["map"], enc)
    return out


def summary(table):
    if not table:
        return None
    mons = table["mons"]
    return (frozenset(m["species"] for m in mons),
            min(m["min_level"] for m in mons), max(m["max_level"] for m in mons))


class Audit:
    def __init__(self, root):
        self.root = root
        self.reach = Reach(root)
        self.seen = self.reach.flood(self.reach.seeds(), set())
        v = self.reach.rules.v
        self.v = v
        self.fishable = {v[n] for n in ("MB_POND_WATER", "MB_OCEAN_WATER", "MB_INTERIOR_DEEP_WATER", "MB_DEEP_WATER",
                                        "MB_SOOTOPOLIS_DEEP_WATER", "MB_EASTWARD_CURRENT", "MB_WESTWARD_CURRENT",
                                        "MB_NORTHWARD_CURRENT", "MB_SOUTHWARD_CURRENT")}
        self.surfable = self.reach.rules.surfable
        self.waterfall = v["MB_WATERFALL"]
        self.tree = v["MB_HEADBUTT_TREE"]
        self.bridge_no_edge = {v[n] for n in v if n.startswith("MB_BRIDGE_OVER") and "EDGE" not in n} \
            if "MB_BRIDGE_OVER_POND_LOW" in v else set()
        self.tables = load_tables(os.path.join(root, "src/data/wild_encounters.json"))

    def activity(self):
        per = collections.defaultdict(lambda: collections.Counter())
        cells = self.reach.cells
        for mid, x, y, elev, mode in self.seen:
            if mode in (SURF, DIVE):
                per[mid]["surf"] += 1
            fish = tree = False
            for d in DIRS:
                t = self.reach.neighbour(mid, x, y, d)
                if not t:
                    continue
                coll, telev, tbeh = cells.base(*t)
                if tbeh == self.waterfall:
                    continue
                if mode == FOOT and elev == 3 and telev not in (0, 3, 15) and coll == 0 and tbeh in self.fishable:
                    fish = True
                if mode == SURF and ((tbeh in self.surfable and coll == 0) or tbeh in self.bridge_no_edge):
                    fish = True
                if mode == FOOT and tbeh == self.tree:
                    tree = True
            if fish:
                per[mid]["fish"] += 1
            if tree:
                per[mid]["tree"] += 1
        for mid, m in self.reach.world.maps.items():
            for ob in m.get("object_events") or []:
                if ob.get("script") == "EventScript_RockSmash":
                    per[mid]["smash"] += 1
        return per

    def region(self, mid):
        m = self.reach.world.maps[mid]
        if m.get("region"):
            return m["region"].replace("REGION_", "")
        version = self.reach.world.layouts[m["layout"]].get("layout_version", "emerald")
        return {"johto": "JOHTO", "frlg": "KANTO"}.get(version, "HOENN")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", default=os.path.normpath(os.path.join(os.path.dirname(__file__), "../..")))
    ap.add_argument("--map")
    ap.add_argument("--hns")
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    audit = Audit(args.root)
    per = audit.activity()
    hns = load_tables(os.path.join(args.hns, "src/data/wild_encounters.json")) if args.hns else {}
    names = {mid: os.path.basename(os.path.dirname(m.get("_path", ""))) or mid for mid, m in audit.reach.world.maps.items()}
    rows = []
    need = {"surf": "water_mons", "fish": "fishing_mons", "smash": "rock_smash_mons", "tree": "rock_smash_mons"}
    failing = 0
    for mid in sorted(set(audit.reach.world.maps) | set(audit.tables)):
        if args.map and args.map not in (mid, audit.reach.world.maps.get(mid, {}).get("name")):
            continue
        act = per.get(mid, collections.Counter())
        enc = audit.tables.get(mid, {})
        region = audit.region(mid) if mid in audit.reach.world.maps else "?"
        name = audit.reach.world.maps.get(mid, {}).get("name", mid)
        for kind, table in need.items():
            if act[kind] and not enc.get(table):
                src = hns.get(mid, {}).get(table) if region == "JOHTO" else None
                tag = "MISSING-SRC" if src else "MISSING"
                failing += bool(src)
                rows.append(f"{tag} {region} {name} {kind}={act[kind]} no {table}"
                            + (f" (HnS has {sorted(summary(src)[0])})" if src else ""))
        for table, kinds in (("water_mons", ("surf",)), ("fishing_mons", ("fish",)),
                             ("rock_smash_mons", ("smash", "tree"))):
            if enc.get(table) and not any(act[k] for k in kinds):
                failing += 1
                rows.append(f"UNUSED {region} {name} {table} with no reachable {'/'.join(kinds)}")
        if region == "JOHTO" and hns and mid in hns:
            for table in TABLES:
                ours, theirs = summary(enc.get(table)), summary(hns[mid].get(table))
                if ours != theirs:
                    rows.append(f"DIFF {name} {table} ours={fmt(ours)} hns={fmt(theirs)}")
        if act and (args.map or os.environ.get("PW_AUDIT_VERBOSE")):
            rows.append(f"INFO {region} {name} {dict(act)} tables={[t for t in TABLES if enc.get(t)]}")
    for r in rows:
        print(r)
    print(f"{len(rows)} rows, {failing} failing")
    return 1 if args.check and failing else 0


def fmt(s):
    if not s:
        return "-"
    return f"L{s[1]}-{s[2]}:{','.join(sorted(x.replace('SPECIES_', '') for x in s[0]))}"


if __name__ == "__main__":
    sys.exit(main())
