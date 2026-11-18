#!/usr/bin/env python3
"""Every evolution between obtainable species needs a route this world can satisfy.

The species table carries the expansion's conditions: time of day, map and map section, weather,
region, held and Bag items, party members. This world has Kanto (with Sevii), Johto and Hoenn plus
the Hub and the Frontier, whose maps all report one of those three regions, and no link trade. A
route can only fire when its method can run here (no EVO_TRADE), each named region is one of the
three, each named map or map section exists, each named weather occurs on some map, each named
party species is obtainable, and each item it needs can be bought, found or stolen somewhere.

An evolution from an obtainable species to an obtainable species fails when none of its routes can
fire. Routes that depend on the clock, a place, the weather or the region are listed for review,
and the shops that sell each evolution item are tabulated per region.

Run from the repo root: python3 test/overworld/ValidateEvoRoutes.py. Exit status 1 on a failure.
"""
import glob
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ValidateConfigRules import ROOT, Config, live_text, read, strip_c_comments  # noqa: E402
import ValidateDeadEvoItems as dead  # noqa: E402

REGIONS_HERE = {"REGION_KANTO", "REGION_JOHTO", "REGION_HOENN"}
PLACE_OR_CLOCK = {"IF_TIME", "IF_NOT_TIME", "IF_IN_MAP", "IF_IN_MAPSEC", "IF_WEATHER", "IF_REGION", "IF_NOT_REGION"}
MIN_ROUTES, MIN_ITEMS = 150, 12


def entries(cfg):
    """{species: [(method, param, target, [(condition, args...)])]} for the live species table."""
    out = {}
    for path in sorted(glob.glob(os.path.join(ROOT, "src/data/pokemon/species_info/gen_*_families.h"))):
        text = live_text(strip_c_comments(open(path, encoding="utf-8", errors="replace").read()), cfg, "c")
        parts = re.split(r"\n\s*\[(SPECIES_\w+)\]\s*=", text)
        for k in range(1, len(parts), 2):
            for e in dead.evolution_entries(parts[k + 1]):
                e = " ".join(e.split())
                m = re.match(r"\{(EVO_\w+),\s*([^,]+?),\s*(SPECIES_\w+)", e)
                conds = re.search(r"CONDITIONS\((.*)\)", e)
                conds = [tuple(a.strip() for a in c.split(",")) for c in re.findall(r"\{([^{}]*)\}", conds.group(1))] if conds else []
                out.setdefault(parts[k], []).append((m.group(1), m.group(2), m.group(3), conds))
    return out


def world():
    """Map names, map sections, weathers and map -> region for every map.json."""
    ids = [s["id"] for s in json.load(open(os.path.join(ROOT, "src/data/region_map/region_map_sections.json")))["map_sections"]]
    k0, sa = ids.index("MAPSEC_PALLET_TOWN"), ids.index("MAPSEC_SPECIAL_AREA")
    j0, j1 = ids.index("MAPSEC_NEW_BARK_TOWN"), ids.index("MAPSEC_JOHTO_INDIGO_PLATEAU")
    maps, secs, weathers, region = set(), set(), set(), {}
    for path in glob.glob(os.path.join(ROOT, "data/maps/*/map.json")):
        d = json.load(open(path))
        sec = d.get("region_map_section", "")
        i = ids.index(sec) if sec in ids else -1
        region[path.split(os.sep)[-2]] = ("KANTO" if k0 <= i < sa else "JOHTO" if j0 <= i <= j1 else "HOENN")
        maps.add(d.get("id"))
        secs.add(sec)
        weathers.add(d.get("weather"))
    return maps, secs, weathers, region


def item_sources(live_items, owned, region):
    """{item: [(kind, region, where)]} from marts, item balls, hidden items, scripts and wild held items."""
    alias = dict(re.findall(r"^\s*(ITEM_\w+)\s*=\s*(ITEM_\w+)\s*,", read("include/constants/items.h"), re.M))
    src = {i: [] for i in live_items}

    def add(it, entry):
        it = alias.get(it, it)
        if it in src:
            src[it].append(entry)
    shops, _ = dead.marts()
    for path, label, stock in shops:
        m = re.match(r"data/maps/([^/]+)/", path)
        for it in stock:
            add(it, ("mart", region.get(m.group(1), "SHARED") if m else "SHARED", label))
    for kind, path, where, it in dead.handouts(set(live_items) | {a for a, b in alias.items() if b in src}):
        m = re.match(r"data/maps/([^/]+)/", path)
        add(it, (kind, region.get(m.group(1), "SHARED") if m else "SHARED", f"{path} {where}"))
    for path in glob.glob(os.path.join(ROOT, "data/**/*.inc"), recursive=True):
        text = open(path, encoding="utf-8", errors="replace").read()
        for it in set(re.findall(r"setitemandprice\s+(ITEM_\w+)", text)):
            add(it, ("exchange", "SHARED", os.path.relpath(path, ROOT)))
    wild = set(re.findall(r'"species":\s*"(SPECIES_\w+)"', read("src/data/wild_encounters.json")))
    for path in glob.glob(os.path.join(ROOT, "src/data/pokemon/species_info/gen_*_families.h")):
        text = strip_c_comments(open(path, encoding="utf-8", errors="replace").read())
        parts = re.split(r"\n\s*\[(SPECIES_\w+)\]\s*=", text)
        for k in range(1, len(parts), 2):
            if parts[k] in wild and parts[k] in owned:
                for it in re.findall(r"\.item(?:Common|Rare)\s*=\s*(ITEM_\w+)", parts[k + 1]):
                    add(it, ("wild held", "SHARED", parts[k]))
    return src


def route_blockers(method, param, conds, owned, maps, secs, weathers, has_source):
    out = []
    if method == "EVO_TRADE":
        out.append("link trade is compiled out")
    if method == "EVO_ITEM" and not has_source(param):
        out.append(f"{param} has no source")
    for c in conds:
        name, args = c[0], c[1:]
        if name == "IF_REGION" and args[0] not in REGIONS_HERE:
            out.append(f"needs {args[0]}")
        elif name == "IF_IN_MAPSEC" and args[0] not in secs:
            out.append(f"no map is in {args[0]}")
        elif name == "IF_IN_MAP" and args[0] not in maps:
            out.append(f"{args[0]} does not exist")
        elif name == "IF_WEATHER" and not any(w and args[0].replace("WEATHER_", "") in w for w in weathers):
            out.append(f"no map has {args[0]}")
        elif name in ("IF_HOLD_ITEM", "IF_BAG_ITEM_COUNT") and not has_source(args[0]):
            out.append(f"{args[0]} has no source")
        elif name == "IF_SPECIES_IN_PARTY" and args[0] not in owned:
            out.append(f"{args[0]} is not obtainable")
    return out


def main():
    cfg = Config()
    owned = dead.obtainable(dead.species_rows(cfg, live=True))
    table = entries(cfg)
    maps, secs, weathers, region = world()
    live = [(s, r) for s in sorted(owned) for r in table.get(s, []) if r[2] in owned]
    live_items = sorted({r[1] for _, r in live if r[0] == "EVO_ITEM"}
                        | {c[1] for _, r in live for c in r[3] if c[0] in ("IF_HOLD_ITEM", "IF_BAG_ITEM_COUNT")})
    src = item_sources(live_items, owned, region)
    if len(live) < MIN_ROUTES or len(live_items) < MIN_ITEMS:
        print(f"FAIL: parse drifted: {len(live)} live routes, {len(live_items)} evolution items")
        return 1

    def has_source(item):
        return bool(src.get(item))

    failures, review, pairs = [], [], {}
    for s, (method, param, target, conds) in live:
        blockers = route_blockers(method, param, conds, owned, maps, secs, weathers, has_source)
        pairs.setdefault((s, target), []).append(blockers)
        if not blockers and any(c[0] in PLACE_OR_CLOCK for c in conds):
            review.append(f"{s} -> {target} by {method} {param} when {conds}")
    for (s, target), routes in sorted(pairs.items()):
        if all(routes):
            failures.append(f"{s} cannot evolve into {target} here: " + "; ".join(", ".join(b) for b in routes))
    print(f"{len(owned)} obtainable species, {len(pairs)} evolutions between them over {len(live)} routes; "
          f"{len(live_items)} evolution items")
    for line in review:
        print(f"NOTE place, clock or region route: {line}")
    for it in live_items:
        per = {reg: sorted({w for k, rg, w in src[it] if k == "mart" and rg == reg}) for reg in ("KANTO", "JOHTO", "HOENN", "SHARED")}
        other = sorted({k for k, _, _ in src[it] if k != "mart"})
        shops = "  ".join(f"{reg} {len(v)}" for reg, v in per.items())
        print(f"ITEM {it:22} marts: {shops}  other: {', '.join(other) or 'none'}")
        if not src[it]:
            failures.append(f"{it} is needed to evolve an obtainable species but nothing sells, hides or holds it")
    for f in failures:
        print(f"FAIL {f}")
    if failures:
        print(f"FAIL: {len(failures)} evolution route problem(s)")
        return 1
    print("OK: every evolution between obtainable species has a route this world can satisfy")
    return 0


if __name__ == "__main__":
    sys.exit(main())
