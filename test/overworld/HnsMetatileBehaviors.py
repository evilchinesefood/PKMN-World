#!/usr/bin/env python3
"""Keep pokemonHnS's metatile behaviour numbers out of the Johto tilesets.

The Johto tilesets were imported from pokemonHnS byte for byte, but HnS numbers 45 behaviours
differently from this tree: HnS 0xA1 is MB_HEADBUTT_TREE, here it is MB_INDIGO_PLATEAU_SIGN_1.
HnsMetatileBehaviors.h is HnS's own header, so the translation goes by NAME. An HnS behaviour
becomes this tree's behaviour of the same name; an HnS MB_UNUSED_*, or a value HnS never
defines, becomes MB_NORMAL; NO_EQUIVALENT names the rest.

A Johto tileset is one whose u16 (Emerald-format) attributes only `layout_version: johto`
layouts use. Those are the HnS imports; a tileset Hoenn also uses keeps this tree's numbering.

    HnsMetatileBehaviors.py                 check: no Johto tileset holds a value that means
                                            something else in HnS and that the translation
                                            never writes (exit 1 names tileset and metatiles)
    HnsMetatileBehaviors.py --report HNS    list each HnS original's behaviours that change
                                            meaning here, and the Johto cells that use them
    HnsMetatileBehaviors.py --convert HNS   rewrite every Johto tileset still byte-identical
                                            to its HnS original; translated or edited ones are
                                            left alone, so a rerun changes nothing

HNS is a pokemonHnS checkout with data/tilesets (see hns-upstream-is-the-oracle). To import
another HnS tileset: copy it, add it to HNS_NAMES if the folder was renamed, run --convert.
"""
import argparse
import collections
import json
import os
import re
import struct
import sys

import ValidateOwMonPlacements as maps

HNS_HEADER = "test/overworld/HnsMetatileBehaviors.h"
HNS_NAMES = {
    "goldenrod_department_store": "department_store",
    "goldenrod_game_corner": "game_corner",
    "johto_day_care": "pokemon_day_care",
    "johto_hall_of_fame": "hall_of_fame",
    "johto_pokemon_league": "pokemon_league",
    "mahogany_town_gym": "sootopolis_gym",
}
# No tile any layout here places carries it: #297 swapped Route 41's HnS return-warp row for ocean.
NO_EQUIVALENT = {"MB_WATER_NORTH_ARROW_WARP": "MB_NORMAL"}
BEHAVIOR_MASK = 0xFF


class Translation:
    def __init__(self):
        ours = maps.load_behavior_names()
        ours["MB_INVALID"] = 0xFF
        self.ours = {v: n for n, v in ours.items()}
        self.hns = collections.defaultdict(list)
        for name, value in re.findall(r"#define\s+(MB_\w+)\s+(0x[0-9A-Fa-f]+|\d+)", maps.read(HNS_HEADER)):
            self.hns[int(value, 0)].append(name)
        if len(self.hns) < maps.MIN_BEHAVIORS:
            maps.die(f"only {len(self.hns)} behaviours parsed from {HNS_HEADER}")
        self.remap = {}
        for value in range(256):
            names = self.hns.get(value, [])
            target = next((n for n in names if n in ours), None)
            target = target or next((NO_EQUIVALENT[n] for n in names if n in NO_EQUIVALENT), None)
            if target is None and (not names or any(n.startswith("MB_UNUSED_") for n in names)):
                target = "MB_NORMAL"
            if target is not None:
                self.remap[value] = ours[target]
        changed = {v for v, t in self.remap.items() if t != v}
        self.foreign = (changed | (set(range(256)) - set(self.remap))) - set(self.remap.values())

    def hns_name(self, value):
        return "/".join(self.hns.get(value, ["(none)"]))

    def our_name(self, value):
        return self.ours.get(value, "(none)")

    def foreign_values(self, blob):
        hits = collections.defaultdict(list)
        for i, attr in enumerate(values(blob)):
            if attr & BEHAVIOR_MASK in self.foreign:
                hits[attr & BEHAVIOR_MASK].append(i)
        return hits

    def translate(self, blob):
        out = []
        for i, attr in enumerate(values(blob)):
            beh = attr & BEHAVIOR_MASK
            if beh not in self.remap:
                return None, i
            out.append((attr & ~BEHAVIOR_MASK) | self.remap[beh])
        return struct.pack(f"<{len(out)}H", *out), None


def values(blob):
    return struct.unpack(f"<{len(blob) // 2}H", blob)


def ids(found, limit):
    return ", ".join(f"{i:#05x}" for i in found[:limit]) + (" ..." if len(found) > limit else "")


def johto_tilesets():
    files = maps.load_tileset_attributes()
    widths = maps.check_attribute_widths(files)
    layouts = [l for l in json.load(open(os.path.join(maps.ROOT, "data/layouts/layouts.json")))["layouts"] if l]
    versions = collections.defaultdict(set)
    for l in layouts:
        versions[l["primary_tileset"]].add(l["layout_version"])
        versions[l["secondary_tileset"]].add(l["layout_version"])
    chosen = {name: files[name][0] for name in files
              if widths[name] == 2 and versions.get(name) == {"johto"}}
    return chosen, layouts


def hns_source(hns_root, rel):
    kind, folder = rel.split("/")[2:4]
    return os.path.join(hns_root, "data/tilesets", kind, HNS_NAMES.get(folder, folder), "metatile_attributes.bin")


def read_blob(path):
    with open(path, "rb") as f:
        return f.read()


def check(tr):
    tilesets, _ = johto_tilesets()
    bad = []
    for name, rel in sorted(tilesets.items()):
        for beh, found in sorted(tr.foreign_values(read_blob(os.path.join(maps.ROOT, rel))).items()):
            bad.append(f"{name} ({rel}): {beh:#04x} means {tr.hns_name(beh)} in HnS and "
                       f"{tr.our_name(beh)} here, metatiles {ids(found, 12)}")
    if bad:
        print(f"FAIL - {len(bad)} pokemonHnS behaviour number(s) left untranslated in Johto tilesets:")
        for line in bad:
            print(f"  {line}")
        print("  Translate the import: python3 test/overworld/HnsMetatileBehaviors.py --convert <pokemonHnS>")
        return 1
    print(f"PASS - {len(tilesets)} Johto tilesets carry this tree's behaviour numbers, none of HnS's")
    return 0


def convert(tr, hns_root):
    tilesets, _ = johto_tilesets()
    written, kept, problems = [], 0, []
    for name, rel in sorted(tilesets.items()):
        src = hns_source(hns_root, rel)
        if not os.path.exists(src):
            continue
        original = read_blob(src)
        out, at = tr.translate(original)
        if out is None:
            beh = values(original)[at] & BEHAVIOR_MASK
            problems.append(f"{name}: metatile {at:#05x} has HnS {beh:#04x} ({tr.hns_name(beh)}), "
                            f"which has no translation; add it to NO_EQUIVALENT")
            continue
        path = os.path.join(maps.ROOT, rel)
        current = read_blob(path)
        if current == original and current != out:
            with open(path, "wb") as f:
                f.write(out)
            written.append(name)
        elif current == out or not tr.foreign_values(current):
            kept += 1
        else:
            problems.append(f"{name}: {rel} was edited after import and still holds HnS numbers; "
                            f"translate it by hand")
    for name in written:
        print(f"translated {name}")
    print(f"{len(written)} translated, {kept} already in this tree's numbering")
    for line in problems:
        print(f"FAIL - {line}")
    return 1 if problems else 0


def report(tr, hns_root):
    tilesets, layouts = johto_tilesets()
    for name, rel in sorted(tilesets.items()):
        src = hns_source(hns_root, rel)
        if not os.path.exists(src):
            continue
        changed = collections.defaultdict(list)
        for i, attr in enumerate(values(read_blob(src))):
            beh = attr & BEHAVIOR_MASK
            if tr.remap.get(beh) != beh:
                changed[beh].append(i)
        if not changed:
            continue
        print(f"{name} ({rel})")
        for beh, found in sorted(changed.items()):
            cells = collections.Counter()
            for l in layouts:
                if l["layout_version"] != "johto" or name not in (l["primary_tileset"], l["secondary_tileset"]):
                    continue
                base = maps.NUM_METATILES_IN_PRIMARY_FRLG if l["secondary_tileset"] == name else 0
                wanted = {base + i for i in found}
                n = sum(1 for v in values(read_blob(os.path.join(maps.ROOT, l["blockdata_filepath"])))
                        if v & 0x3FF in wanted)
                if n:
                    cells[l["id"]] = n
            target = tr.our_name(tr.remap[beh]) if beh in tr.remap else "NO TRANSLATION"
            where = ": " + ", ".join(f"{k} {v}" for k, v in cells.most_common(6)) if cells else ""
            print(f"  {beh:#04x} HnS {tr.hns_name(beh)} reads here as {tr.our_name(beh)}; "
                  f"translates to {target}; metatiles {ids(found, 8)}; "
                  f"{sum(cells.values())} Johto cells{where}")
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--report", metavar="HNS")
    group.add_argument("--convert", metavar="HNS")
    args = parser.parse_args()
    tr = Translation()
    if args.report:
        return report(tr, args.report)
    if args.convert:
        return convert(tr, args.convert) or check(tr)
    return check(tr)


if __name__ == "__main__":
    sys.exit(main())
