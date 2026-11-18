#!/usr/bin/env python3
"""List every tile Fly, Teleport, a whiteout, an Escape Rope or Dig can put the player on, and flag
the ones the player cannot stand on or walk away from.

Landings come from the game's own tables:

  HEAL     each heal location's (map, x, y): Fly (SetFlyDestination), Teleport and the Sky Charm's
           town landing (lastHealLocation) all land here.
  RESPAWN  each heal location's whiteout cell (respawn_map, respawn_x/respawn_y, default 7,4).
  ESCAPE   every warp event on an outdoor map whose destination is not outdoor, from a map that
           does not allow escaping itself: UpdateEscapeWarp (src/overworld.c) stores the cell the
           player stood on, the warp cell for an arrow warp entered facing south and the cell below
           it otherwise. Escape Rope and Dig land there from any escape-allowing map reached behind
           it, indoors or an outdoor map that allows escaping (Viridian Forest, Ilex Forest).

A landing is flagged when its cell is outside the map, carries collision, is a ledge, or when no
move off it reaches a cell walking reaches from the map's warps and connections
(ValidateReachability's movement rules). Water or a waterfall is flagged for HEAL and RESPAWN only:
a warp onto water starts the player surfing (GetAdjustedInitialTransitionFlags). A landing on a cell
an object event starts on is flagged too, unless the object is hidden by a flag.

KNOWN lists the findings that cannot happen in play, each with its reason. An unlisted finding or a
stale KNOWN entry fails.

Usage: python3 test/overworld/ValidateLandings.py [--root DIR] [--list]
"""

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ValidateReachability import FOOT, OUTDOOR, Reach  # noqa: E402

KNOWN = {
    ("ESCAPE", "MAP_ROUTE26", 12, 3): "dead warp: its cell and every approach are trees, and the Reception "
                                      "Gate's warp 0 leads to Route 26 North",
}


def landings(reach):
    world = reach.world
    heals = json.load(open(os.path.join(reach.root, "src/data/heal_locations.json")))["heal_locations"]
    for h in heals:
        yield "HEAL", h["id"], h["map"], h["x"], h["y"]
        if h.get("respawn_map"):
            yield "RESPAWN", h["id"], h["respawn_map"], h.get("respawn_x", 7), h.get("respawn_y", 4)
    south = reach.rules.v["MB_SOUTH_ARROW_WARP"]
    for mid, m in sorted(world.maps.items()):
        if m.get("map_type") not in OUTDOOR or m.get("allow_escaping"):
            continue
        w, h = reach.cells.size(mid)
        for wv in m.get("warp_events") or []:
            dest = world.maps.get(wv["dest_map"])
            if dest is None or dest.get("map_type") in OUTDOOR:
                continue
            behind = escape_maps(world, wv["dest_map"])
            if not behind:
                continue
            x, y = wv["x"], wv["y"]
            inside = 0 <= x < w and 0 <= y < h
            yield "ESCAPE", "%s via %s" % (wv["dest_map"], ",".join(sorted(behind))), mid, x, \
                y + (0 if inside and reach.cells.base(mid, x, y)[2] == south else 1)


def escape_maps(world, start):
    """Escape-allowing maps the player reaches from `start` without passing an outdoor map."""
    seen, stack, out = {start}, [start], set()
    while stack:
        mid = stack.pop()
        m = world.maps[mid]
        if m.get("allow_escaping"):
            out.add(m["name"])
        for wv in m.get("warp_events") or []:
            d = wv["dest_map"]
            if d not in world.maps or d in seen:
                continue
            if world.maps[d].get("map_type") not in OUTDOOR:
                seen.add(d)
                stack.append(d)
            elif world.maps[d].get("allow_escaping"):
                out.add(world.maps[d]["name"])
    return out


def walked(reach):
    """Every state walking reaches from warp cells and scripted warps, without heal-location seeds."""
    heal_cells = set()
    for h in json.load(open(os.path.join(reach.root, "src/data/heal_locations.json")))["heal_locations"]:
        heal_cells.add((h["map"], h["x"], h["y"]))
        if "respawn_map" in h:
            heal_cells.add((h["respawn_map"], h.get("respawn_x", 7), h.get("respawn_y", 4)))
    seeds = [s for s in reach.seeds() if s[:3] not in heal_cells]
    return reach.flood(seeds, set())


def check(reach, seen, kind, mid, x, y):
    if mid not in reach.world.maps:
        return "unknown map"
    w, h = reach.cells.size(mid)
    if not (0 <= x < w and 0 <= y < h):
        return "outside the %dx%d map" % (w, h)
    coll, elev, beh = reach.cells.base(mid, x, y)
    r = reach.rules
    problems = []
    if coll:
        problems.append("collision")
    if kind != "ESCAPE" and (beh in r.surfable or beh == r.waterfall):
        problems.append("water behaviour 0x%02X" % beh)
    if beh in r.ledge:
        problems.append("ledge")
    state = (mid, x, y, 0 if elev == 15 else elev, FOOT)
    if not any(n in seen for n in reach.moves(state)) and state not in seen:
        problems.append("no step reaches walkable ground (elev %d)" % elev)
    for o in reach.world.maps[mid].get("object_events") or []:
        if o.get("x") == x and o.get("y") == y and o.get("flag", "0") in ("0", ""):
            problems.append("object %s stands here" % o.get("graphics_id"))
    return ", ".join(problems)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))
    ap.add_argument("--list", action="store_true", help="print every landing, not only findings")
    args = ap.parse_args()
    reach = Reach(args.root)
    seen = walked(reach)
    total, found = 0, {}
    for kind, what, mid, x, y in landings(reach):
        total += 1
        problem = check(reach, seen, kind, mid, x, y)
        if args.list or problem:
            print("%-8s %-40s %s (%d,%d): %s" % (kind, mid, what, x, y, problem or "ok"))
        if problem:
            found[(kind, mid, x, y)] = problem
    new = sorted(set(found) - set(KNOWN))
    stale = sorted(set(KNOWN) - set(found))
    for key in new:
        print("FAIL %s %s (%d,%d): %s" % (key + (found[key],)))
    for key in stale:
        print("FAIL stale KNOWN entry %s %s (%d,%d)" % key)
    print("%d landings, %d findings, %d known" % (total, len(found), len(set(found) & set(KNOWN))))
    return 1 if new or stale else 0


if __name__ == "__main__":
    sys.exit(main())
