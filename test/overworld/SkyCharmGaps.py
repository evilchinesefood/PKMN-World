#!/usr/bin/env python3
"""List the places the Sky Charm reaches that walking cannot, per region, at the badge that unlocks it.

The Sky Charm (StartOverworldFlight) works in a region once the player holds that region's Fly
badge (sFieldMoveBadges in src/field_move.c). Airborne, the player crosses every collision and
every coord event, and lands where CanLandOverworldFlight allows. Story gates that rely on terrain
or on a trigger the player must step on stop working for a flier.

For each region the search holds exactly the badges up to the Fly badge, so the field moves past
it stay locked: their water, waterfalls and dives are closed, and their Cut trees, Rock Smash rocks,
Strength boulders and whirlpools are walls. It walks from the region's arrival points
(src/regional_travel.c) over the movement rules of ValidateReachability.py, inside the region's
maps. A gate is a coord event, or a stationary scripted object that is not an item ball, trainer,
berry tree or field-move obstacle; gates sharing a map and a script form one group. The walk treats
every gate as a wall. Then the Sky Charm lands on every allowed cell of the region's outdoor maps
joined by connections, and the player walks on from there.

Two kinds of flight-only area print:

  GATE     the cells walking reaches once that one gate group opens, with what its script checks
           and sets, so a flier skips it;
  TERRAIN  cells walking never reaches at this badge count, gates open or not;

each with what stands inside: coord events, scripted objects, and warps to other maps. Cells
reached only past two or more gate groups print as SEVERAL.

Usage:
    python3 test/overworld/SkyCharmGaps.py [--region KANTO|JOHTO|HOENN] [--map MAP_NAME] [--min N]
"""

import argparse
import collections
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ValidateBorderTerrain import read  # noqa: E402
from ValidateReachability import DIRS, Reach  # noqa: E402

ARRIVALS = {
    "KANTO": ("MAP_PALLET_TOWN_PLAYERS_HOUSE_2F", "MAP_VERMILION_CITY"),
    "JOHTO": ("MAP_NEW_BARK_TOWN_PLAYERS_HOUSE_2F", "MAP_GOLDENROD_CITY_TRAIN_STATION"),
    "HOENN": ("MAP_LITTLEROOT_TOWN_BRENDANS_HOUSE_2F", "MAP_LITTLEROOT_TOWN_MAYS_HOUSE_2F",
              "MAP_SLATEPORT_CITY_HARBOR"),
}
OBSTACLES = {"EventScript_CutTree": "cut", "EventScript_RockSmash": "rock_smash",
             "EventScript_StrengthBoulder": "strength", "EventScript_Whirlpool": "whirlpool"}
MOVES = {"FIELD_MOVE_CUT": "cut", "FIELD_MOVE_FLASH": "flash", "FIELD_MOVE_ROCK_SMASH": "rock_smash",
         "FIELD_MOVE_STRENGTH": "strength", "FIELD_MOVE_SURF": "surf", "FIELD_MOVE_FLY": "fly",
         "FIELD_MOVE_DIVE": "dive", "FIELD_MOVE_WATERFALL": "waterfall"}
MOVING = re.compile(r"WANDER|WALK_(?:UP|DOWN|LEFT|RIGHT)_AND|SEQUENCE|COPY|JOG|FOLLOW|ROTATE|BERRY")
NO_SCRIPT = ("", "0", "0x0", "NULL")
STATE = re.compile(r"\b(FLAG_\w+|VAR_\w+)")


def badge_table(root):
    """region -> {move: badge index} from sFieldMoveBadges, plus Johto's whirlpool badge."""
    text = read(root, "src/field_move.c")
    body = re.search(r"sFieldMoveBadges\[\]\[[^\]]*\]\s*=\s*\{(.*?)\n\};", text, re.S).group(1)
    out = {}
    for region, entries in re.findall(r"\[REGION_(\w+)\]\s*=\s*\{(.*?)\}", body, re.S):
        out[region] = {MOVES[m]: int(n) for m, n in re.findall(r"\[(FIELD_MOVE_\w+)\]\s*=\s*(\d+)", entries)}
    scripts = read(root, "data/scripts/field_move_scripts.inc")
    whirl = re.search(r"EventScript_Whirlpool::.*?goto_if_unset FLAG_JOHTO_BADGE_(\d)", scripts, re.S)
    out["JOHTO"]["whirlpool"] = int(whirl.group(1)) - 1
    return out


def mapsec_regions(root):
    """MAPSEC name -> region, the ranges GetRegionForSectionId uses, from the JSON the enum is built from."""
    secs = [e["id"] for e in json.loads(read(root, "src/data/region_map/region_map_sections.json"))["map_sections"]]
    idx = {s: i for i, s in enumerate(secs)}
    k0, k1 = idx["MAPSEC_PALLET_TOWN"], idx["MAPSEC_SPECIAL_AREA"]
    j0, j1 = idx["MAPSEC_NEW_BARK_TOWN"], idx["MAPSEC_JOHTO_INDIGO_PLATEAU"]

    def region(sec):
        i = idx.get(sec, -1)
        return "KANTO" if k0 <= i < k1 else "JOHTO" if j0 <= i <= j1 else "HOENN"
    return region


def summary(scripts, label):
    """What a gate's script reads and writes, to judge whether skipping it matters."""
    reads, writes = set(), set()
    for line in scripts.walk([label]):
        op = line.split()[0]
        names = STATE.findall(line)
        if op.startswith(("setflag", "setvar", "clearflag", "addvar", "subvar", "copyvar")):
            writes.update(names[:1])
        elif op.startswith(("goto_if", "call_if", "checkflag", "compare")):
            reads.update(names)
    return "reads %s; writes %s" % (" ".join(sorted(reads)) or "-", " ".join(sorted(writes)) or "-")


def walls(reach, region_maps, locked):
    """(cells field-move obstacles block at this badge count, {cell: gate group key}, {group key: label}).

    Coord events sharing a var and value open together, and so do objects sharing a hide flag."""
    terrain, cell_group, label = set(), {}, {}
    for mid in sorted(region_maps):
        m = reach.world.maps[mid]
        for i, ev in enumerate(m.get("object_events") or [], 1):
            if "x" not in ev:
                continue
            cell = (mid, ev["x"], ev["y"])
            script = ev.get("script", "")
            move = OBSTACLES.get(script)
            if move:
                if move in locked:
                    terrain.add(cell)
                continue
            gfx = ev.get("graphics_id", "")
            if script in NO_SCRIPT or ev.get("trainer_type", "TRAINER_TYPE_NONE") != "TRAINER_TYPE_NONE" \
                    or script == "Common_EventScript_FindItem" or "POKE_BALL" in gfx or "BERRY_TREE" in gfx or MOVING.search(ev.get("movement_type", "")):
                continue
            flag = ev.get("flag", "0")
            key = (m["name"], "flag " + flag if flag not in NO_SCRIPT else "obj " + script)
            cell_group[cell] = key
            label.setdefault(key, set()).add("obj %d (%d,%d) %s" % (i, ev["x"], ev["y"], script))
        for ev in m.get("coord_events") or []:
            if ev.get("type") == "trigger" and ev.get("script") not in NO_SCRIPT:
                key = (m["name"], "coord %s==%s" % (ev.get("var"), ev.get("var_value")))
                cell_group[(mid, ev["x"], ev["y"])] = key
                label.setdefault(key, set()).add("(%d,%d) %s" % (ev["x"], ev["y"], ev["script"]))
    return terrain, cell_group, label


def gate_paths(reach, seeds, cell_group):
    """state -> the gate groups on a path that crosses the fewest of them (0-1 breadth-first search)."""
    best = {s: () for s in seeds}
    queue = collections.deque(seeds)
    while queue:
        s = queue.popleft()
        here = best[s]
        for n in reach.moves(s):
            key = cell_group.get(n[:3]) if n[:3] != s[:3] else None
            path = here + (key,) if key and key not in here else here
            if n not in best or len(path) < len(best[n]):
                best[n] = path
                if len(path) == len(here):
                    queue.appendleft(n)
                else:
                    queue.append(n)
    return best


def contents(world, cells):
    """Coord events, scripted objects and warps on or beside `cells`, map by map."""
    by_map = collections.defaultdict(set)
    for c in cells:
        by_map[c[0]].add(c[1:])
    out = []
    for mid in sorted(by_map):
        m, here = world.maps[mid], by_map[mid]
        for ev in m.get("coord_events") or []:
            if (ev["x"], ev["y"]) in here and ev.get("type") == "trigger":
                out.append("%s coord (%d,%d) %s==%s %s" % (m["name"], ev["x"], ev["y"], ev.get("var"),
                                                           ev.get("var_value"), ev.get("script")))
        for i, ev in enumerate(m.get("object_events") or [], 1):
            if "x" not in ev or OBSTACLES.get(ev.get("script")) or ev.get("script") in NO_SCRIPT:
                continue
            if any((ev["x"] + dx, ev["y"] + dy) in here for dx, dy in list(DIRS.values()) + [(0, 0)]):
                kind = "trainer" if ev.get("trainer_type", "TRAINER_TYPE_NONE") != "TRAINER_TYPE_NONE" else \
                    "item" if ev.get("script") == "Common_EventScript_FindItem" else "obj"
                out.append("%s %s %d (%d,%d) %s flag=%s" % (m["name"], kind, i, ev["x"], ev["y"], ev.get("script"),
                                                           ev.get("flag", "0")))
        for wv in m.get("warp_events") or []:
            if (wv["x"], wv["y"]) in here or (wv["x"], wv["y"] - 1) in here:
                dest = world.maps.get(wv["dest_map"], {}).get("name", wv["dest_map"])
                out.append("%s warp (%d,%d) -> %s" % (m["name"], wv["x"], wv["y"], dest))
    return out


def per_map(world, cells):
    count = collections.Counter(world.maps[c[0]]["name"] for c in cells)
    return ", ".join("%s %d" % kv for kv in sorted(count.items()))


def components(cells):
    """Split (map, x, y) cells into 4-connected groups inside each map."""
    left, out = set(cells), []
    while left:
        start = left.pop()
        group, stack = [start], [start]
        while stack:
            mid, x, y = stack.pop()
            for dx, dy in DIRS.values():
                n = (mid, x + dx, y + dy)
                if n in left:
                    left.remove(n)
                    group.append(n)
                    stack.append(n)
        out.append(group)
    return out


def analyse(reach, region, badges, region_of):
    """(fly badge, locked moves, rows) where a row is (kind, title, cells, contents)."""
    world = reach.world
    region_maps = {mid for mid, m in world.maps.items() if region_of(m.get("region_map_section")) == region}
    table = badges[region]
    fly = table["fly"]
    locked = frozenset(move for move, b in table.items() if b > fly)
    terrain, cell_group, label = walls(reach, region_maps, locked)

    reach.maps_in, reach.locked = region_maps, locked
    seeds = [s for s in reach.seeds() if s[0] in ARRIVALS[region]]
    reach.walls = terrain
    paths = gate_paths(reach, seeds, cell_group)
    reach.walls = terrain | set(cell_group)
    strict = reach.flood(seeds, set())
    gap = {s[:3] for s in reach.sky(set(strict))} - {s[:3] for s in strict}
    reach.maps_in, reach.locked, reach.walls = None, frozenset(), set()

    fewest = {}
    for s, path in paths.items():
        if s[:3] in gap and (s[:3] not in fewest or len(path) < len(fewest[s[:3]])):
            fewest[s[:3]] = path
    behind = collections.defaultdict(set)
    for cell, path in fewest.items():
        behind[path[-1]].add(cell)
    rows = []
    for key in sorted(behind):
        cells = behind[key]
        earlier = collections.Counter(len(fewest[c]) - 1 for c in cells)
        where = sorted(label[key])
        title = "%s %s: %s; %s; %s" % (key[0], key[1], " ".join(where[:2]) + (" +%d" % (len(where) - 2) if len(where) > 2 else ""),
                                       summary(reach.scripts, sorted(label[key])[0].split()[-1]),
                                       "after %d other gates" % min(earlier) if min(earlier) else "first gate")
        rows.append(("GATE", title, cells, contents(world, cells)))
    for group in components(gap - set(fewest)):
        xs, ys = [c[1] for c in group], [c[2] for c in group]
        title = "%s (%d,%d)-(%d,%d)" % (world.maps[group[0][0]]["name"], min(xs), min(ys), max(xs), max(ys))
        rows.append(("TERRAIN", title, set(group), contents(world, group)))
    return fly, locked, rows


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
    ap.add_argument("--region", choices=sorted(ARRIVALS))
    ap.add_argument("--map", metavar="MAP_NAME", help="report only areas with cells on this map")
    ap.add_argument("--min", type=int, default=1, metavar="N",
                    help="skip TERRAIN areas under N cells with nothing inside")
    args = ap.parse_args()

    reach = Reach(args.root)
    badges = badge_table(args.root)
    region_of = mapsec_regions(args.root)
    for region in [args.region] if args.region else sorted(ARRIVALS):
        fly, locked, rows = analyse(reach, region, badges, region_of)
        shown = [r for r in rows
                 if (not args.map or any(reach.world.maps[c[0]]["name"] == args.map for c in r[2]))
                 and (r[0] == "GATE" or len(r[2]) >= args.min or r[3])]
        kinds = collections.Counter(r[0] for r in rows)
        print("== %s: Sky Charm at badge %d; locked: %s; %s; %d shown" % (
            region, fly + 1, ", ".join(sorted(locked)) or "none",
            ", ".join("%d %s" % (n, k) for k, n in sorted(kinds.items())), len(shown)))
        for kind, title, cells, inside in shown:
            print("%-8s %s" % (kind, title))
            print("           %d cells: %s" % (len(cells), per_map(reach.world, cells)))
            for line in inside:
                print("           %s" % line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
