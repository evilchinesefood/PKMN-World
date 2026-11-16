#!/usr/bin/env python3
"""No mart may sell an evolution item that evolves nothing the player can own.

Gen 4+ families are stripped, so the Dusk Stone, Electirizer, Oval Stone and their kin evolve
nothing in this build, yet Celadon, Lilycove, Mahogany and the Hub sold them as if they did.

An evolution item is any item an evolution entry names, as its item or in a hold-item condition,
in any species table row compiled in or not. It is live when an evolution from an obtainable
species to an obtainable species names it. Obtainable means compiled in, numbered Gen 1-3 in the
National Dex, and either a base-region form or a regional form some map script, wild table or
in-game trade hands out, plus what those evolve into (a regional form only from a regional parent,
so Pikachu does not make Alolan Raichu obtainable). Everything else is dead.

A dead item that still does something when held in battle (Razor Claw raises the critical-hit
ratio) may stay on sale: it is listed as a warning for the owner to decide, not a failure.

Field item balls, hidden items and script gifts of dead items are reported but never fail.

Run from the repo root: python3 test/overworld/ValidateDeadEvoItems.py. Exit status 1 when a mart
sells a dead evolution item with no held effect.
"""
import glob
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ValidateConfigRules import ROOT, Config, live_text, read, strip_c_comments  # noqa: E402

MIN_SPECIES, MIN_EVO_ITEMS, MIN_MARTS = 400, 40, 40
REGIONAL = re.compile(r"\.is(Alolan|Galarian|Hisuian|Paldean)Form\s*=\s*TRUE")


def evolution_entries(block):
    """Each `{EVO_...}` entry inside a species block's EVOLUTION(...) list, braces balanced."""
    m = re.search(r"\.evolutions\s*=\s*EVOLUTION\(", block)
    if not m:
        return []
    out, i = [], m.end()
    while True:
        j = block.find("{EVO_", i)
        end = block.find("),\n", i)
        if j < 0 or (0 <= end < j):
            return out
        depth, k = 0, j
        while k < len(block):
            depth += {"{": 1, "}": -1}.get(block[k], 0)
            k += 1
            if depth == 0:
                break
        out.append(block[j:k])
        i = k


def species_rows(cfg, live):
    dex = re.findall(r"^\s*(NATIONAL_DEX_\w+)\s*,", read("include/constants/pokedex.h"), re.M)
    last_gen3 = dex.index("NATIONAL_DEX_DEOXYS")
    order = {n: i for i, n in enumerate(dex)}
    rows = {}
    for path in sorted(glob.glob(os.path.join(ROOT, "src/data/pokemon/species_info/gen_*_families.h"))):
        text = strip_c_comments(open(path, encoding="utf-8", errors="replace").read())
        if live:
            text = live_text(text, cfg, "c")
        parts = re.split(r"\n\s*\[(SPECIES_\w+)\]\s*=", text)
        for k in range(1, len(parts), 2):
            block = parts[k + 1]
            nat = re.search(r"\.natDexNum\s*=\s*(NATIONAL_DEX_\w+)", block)
            evos = []
            for e in evolution_entries(block):
                target = re.search(r"\bSPECIES_\w+", e)
                items = set(re.findall(r"\bITEM_\w+", e)) - {"ITEM_NONE"}
                if target and items:
                    evos.append((target.group(0), items))
            row = rows.setdefault(parts[k], {"gen3": False, "regional": False, "evos": []})
            row["gen3"] |= bool(nat) and order.get(nat.group(1), 10**6) <= last_gen3
            row["regional"] |= bool(REGIONAL.search(block))
            row["evos"] += evos
    return rows


def handed_out_species():
    seen = set()
    sources = (glob.glob(os.path.join(ROOT, "data/**/*.inc"), recursive=True)
               + [os.path.join(ROOT, p) for p in ("src/data/wild_encounters.json", "src/data/trade.h")])
    for path in sources:
        seen |= set(re.findall(r"\bSPECIES_\w+", open(path, encoding="utf-8", errors="replace").read()))
    return seen


def obtainable(rows):
    handed = handed_out_species()
    base = {s for s, r in rows.items() if r["gen3"] and (not r["regional"] or s in handed)}
    frontier = set(base)
    while frontier:
        frontier = {t for s in frontier for t, _ in rows[s]["evos"]
                    if t in rows and rows[t]["gen3"] and (not rows[t]["regional"] or rows[s]["regional"] or t in handed)} - base
        base |= frontier
    return base


def item_table(cfg):
    text = live_text(strip_c_comments(read("src/data/items.h")), cfg, "c")
    parts = re.split(r"\n\s*\[(ITEM_\w+)\]\s*=", text)
    table = {}
    for k in range(1, len(parts), 2):
        hold = re.search(r"\.holdEffect\s*=\s*(\w+)", parts[k + 1])
        name = re.search(r'\.name\s*=\s*\w*\("([^"]*)"\)', parts[k + 1])
        table[parts[k]] = {"hold": hold.group(1) if hold and hold.group(1) != "HOLD_EFFECT_NONE" else None,
                           "name": name.group(1) if name else parts[k]}
    return table


def marts():
    """(script path, list label, [items]) for every list a `pokemart` command opens."""
    files = glob.glob(os.path.join(ROOT, "data/maps/*/scripts.inc")) + glob.glob(os.path.join(ROOT, "data/scripts/*.inc"))
    texts = {p: open(p, encoding="utf-8", errors="replace").read() for p in sorted(files)}
    wanted = {m for t in texts.values() for m in re.findall(r"^\s*pokemart\s+(\w+)", t, re.M)}
    out = []
    for path, text in texts.items():
        for m in re.finditer(r"^(\w+)::?[ \t]*\n((?:[ \t]*(?:\.2byte\s+\w+|pokemartlistend|@[^\n]*|\.if[^\n]*|\.else|\.endif)?[ \t]*\n)+)", text, re.M):
            if m.group(1) in wanted:
                items = re.findall(r"\.2byte\s+(ITEM_\w+)", m.group(2))
                out.append((os.path.relpath(path, ROOT), m.group(1), [i for i in items if i != "ITEM_NONE"]))
    return out, wanted


def handouts(dead):
    """Item balls, hidden items and script gifts that hand out a dead item."""
    found = []
    for path in sorted(glob.glob(os.path.join(ROOT, "data/maps/*/map.json"))):
        data = json.load(open(path))
        rel = os.path.relpath(path, ROOT)
        for o in data.get("object_events", []):
            item = str(o.get("trainer_sight_or_berry_tree_id", ""))
            if item in dead:
                found.append(("item ball", rel, f"({o.get('x')},{o.get('y')})", item))
        for b in data.get("bg_events", []):
            if b.get("type") == "hidden_item" and b.get("item") in dead:
                found.append(("hidden item", rel, f"({b.get('x')},{b.get('y')})", b["item"]))
    for path in sorted(glob.glob(os.path.join(ROOT, "data/**/*.inc"), recursive=True)):
        rel = os.path.relpath(path, ROOT)
        for ln, line in enumerate(open(path, encoding="utf-8", errors="replace"), 1):
            m = re.match(r"\s*(finditem|giveitem|giveitem_msg|additem)\s+(?:\w+,\s*)?(ITEM_\w+)", line)
            if m and m.group(2) in dead:
                found.append(("item ball" if m.group(1) == "finditem" else "gift", rel, f"line {ln}", m.group(2)))
    return found


def main():
    cfg = Config()
    every = species_rows(cfg, live=False)
    rows = species_rows(cfg, live=True)
    owned = obtainable(rows)
    evo_items = {i for r in every.values() for _, items in r["evos"] for i in items}
    live_items = {i for s in owned for t, items in rows[s]["evos"] if t in owned for i in items}
    dead = evo_items - live_items
    items = item_table(cfg)
    shops, wanted = marts()
    if len(owned) < MIN_SPECIES or len(evo_items) < MIN_EVO_ITEMS or len(shops) < MIN_MARTS or len(shops) < len(wanted):
        print(f"FAIL: parse drifted: {len(owned)} obtainable species, {len(evo_items)} evolution items, "
              f"{len(shops)} of {len(wanted)} mart lists found")
        return 1
    print(f"{len(owned)} obtainable species; {len(evo_items)} evolution items, {len(live_items)} live, {len(dead)} dead; "
          f"{len(shops)} mart lists")
    failures, warnings = [], []
    for path, label, stock in shops:
        for item in stock:
            if item in dead:
                (warnings if items.get(item, {}).get("hold") else failures).append((path, label, item))
    for path, label, item in warnings:
        print(f"WARN {path}:{label} sells {item}: evolves nothing obtainable, but held it has {items[item]['hold']}")
    for kind, path, where, item in handouts(dead):
        hold = items.get(item, {}).get("hold")
        print(f"NOTE {kind} {path} {where} gives {item}" + (f" (held: {hold})" if hold else " (no other use)"))
    for path, label, item in failures:
        print(f"FAIL {path}:{label} sells {item}: no obtainable species evolves with it and it has no held effect")
    if failures:
        print(f"FAIL: {len(failures)} mart slot(s) sell a dead evolution item")
        return 1
    print("OK: no mart sells an evolution item that evolves nothing obtainable")
    return 0


if __name__ == "__main__":
    sys.exit(main())
