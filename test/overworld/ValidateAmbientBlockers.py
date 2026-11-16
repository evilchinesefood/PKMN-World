#!/usr/bin/env python3
"""Report scriptless objects that can stand where they cut the player off from an exit.

A scriptless object event (an ambient Pokemon, a decorative NPC) is a solid wall that nothing
ever moves out of the way. If it walks onto a warp, onto the cell in front of a door, or into a
one-tile passage, the player waits behind it until its random walk takes it elsewhere. Ecruteak's
Pidgey wandered up the one-tile stair corridor and stood on the Burned Tower door, the only way in.

The player side reuses ValidateReachability's search (collision, elevation, ledges, Surf,
waterfalls, warps and connections, on the game's own movement rules). Per map, every warp
destination and every connected map is an exit; an exit's goal cells are where the player
triggers it (a walk-on warp's own cell, the cell south of a solid door, the edge cells that cross
a connection). A cell blocks when, with it removed, a player arriving through one exit can no
longer reach another exit that was reachable before.

The object side follows GetCollisionAtCoords: an object steps along its movement type's axes,
inside its range box (IsCoordOutsideObjectEventMovementRange; a range is 4 bits, and 0 means 1
for the types sMovementTypeHasRange lists and unbounded for any other), onto collision-0 cells
with no directional wall and no elevation mismatch, updating its elevation as
ObjectEventUpdateElevation does. A cell counts as blocked at every elevation, so an object on a
bridge is charged with the path beneath it.

A moving object whose area contains a blocking cell fails the check. Objects with a script are
skipped (talking to them runs code, and some are deliberate barriers), and so are static ones: the
scriptless static objects standing on doors are cutscene actors that hide flags keep off the map.

Usage:
    python3 test/overworld/ValidateAmbientBlockers.py [--root DIR] [--map MAP_NAME]
"""

import argparse
import collections
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ValidateReachability import DIRS, FOOT, SURF, Reach, elevation_after, mismatch  # noqa: E402

SCRIPTLESS = {"NULL", "0x0", "0", ""}


def ranged_types(root):
    """The movement types TrySpawnObjectEventTemplate bumps a 0 range to 1 for."""
    with open(os.path.join(root, "src/event_object_movement.c")) as f:
        body = re.search(r"sMovementTypeHasRange\[\w+\]\s*=\s*\{(.*?)\};", f.read(), re.S).group(1)
    types = set(re.findall(r"\[(MOVEMENT_TYPE_\w+)\]\s*=\s*TRUE", body))
    if len(types) < 20:
        raise SystemExit("FAIL: parsed only %d sMovementTypeHasRange rows" % len(types))
    return types


def axes(movement):
    """Directions an object of this movement type can step in, or '' if it never moves."""
    m = movement.replace("MOVEMENT_TYPE_", "")
    if "IN_PLACE" in m:
        return ""
    if m in ("WANDER_UP_AND_DOWN", "WANDER_DOWN_AND_UP", "WALK_UP_AND_DOWN", "WALK_DOWN_AND_UP"):
        return "NS"
    if m in ("WANDER_LEFT_AND_RIGHT", "WANDER_RIGHT_AND_LEFT", "WALK_LEFT_AND_RIGHT", "WALK_RIGHT_AND_LEFT"):
        return "WE"
    if m.startswith(("WANDER_AROUND", "WALK_SEQUENCE_", "COPY_PLAYER")):
        return "NSWE"
    return ""


class Mover:
    def __init__(self, mid, name, index, ev):
        self.mid, self.name, self.index, self.ev = mid, name, index, ev
        self.dirs = axes(ev.get("movement_type", ""))

    def label(self):
        ev = self.ev
        gfx = re.sub(r"^OBJ_EVENT_GFX_", "", ev.get("graphics_id", ""))
        return "%s obj %d %s at (%d,%d) %s range %s,%s" % (
            self.name, self.index, gfx, ev["x"], ev["y"],
            ev.get("movement_type", "").replace("MOVEMENT_TYPE_", ""),
            ev.get("movement_range_x", 0), ev.get("movement_range_y", 0))


def movers(reach, only=None):
    out = []
    for mid, m in sorted(reach.world.maps.items()):
        if only and m["name"] != only:
            continue
        for i, ev in enumerate(m.get("object_events") or [], 1):
            if ev.get("type", "object") != "object" or "x" not in ev:
                continue
            if str(ev.get("script", "")) not in SCRIPTLESS:
                continue
            if ev.get("trainer_type", "TRAINER_TYPE_NONE") != "TRAINER_TYPE_NONE":
                continue
            mover = Mover(mid, m["name"], i, ev)
            if mover.dirs:
                out.append(mover)
    return out


def area(reach, mover, ranged):
    """Every cell the object can occupy."""
    cells, rules = reach.cells, reach.rules
    ev = mover.ev
    w, h = cells.size(mover.mid)
    x0, y0 = ev["x"], ev["y"]
    if not (0 <= x0 < w and 0 <= y0 < h):
        return set()
    rx, ry = int(ev.get("movement_range_x", 0)) & 15, int(ev.get("movement_range_y", 0)) & 15
    if ev.get("movement_type") in ranged:
        rx, ry = rx or 1, ry or 1
    start = (x0, y0, int(ev.get("elevation", 0)))
    seen, stack = {start}, [start]
    while stack:
        x, y, elev = stack.pop()
        _, cur_elev, cur_beh = cells.base(mover.mid, x, y)
        for d in mover.dirs:
            dx, dy = DIRS[d]
            nx, ny = x + dx, y + dy
            if not (0 <= nx < w and 0 <= ny < h):
                continue
            if (rx and abs(nx - x0) > rx) or (ry and abs(ny - y0) > ry):
                continue
            coll, nelev, nbeh = cells.base(mover.mid, nx, ny)
            if coll or rules.dir_blocked(cur_beh, nbeh, d) or mismatch(elev, nelev):
                continue
            s = (nx, ny, elevation_after(cur_elev, nelev, elev))
            if s not in seen:
                seen.add(s)
                stack.append(s)
    return {(x, y) for x, y, _ in seen}


class MapGraph:
    """The player's states on one map, the steps between them, and the map's exits."""

    def __init__(self, reach, mid, states):
        self.mid = mid
        self.adj = collections.defaultdict(list)
        self.arrive = collections.defaultdict(set)
        self.goal = collections.defaultdict(set)
        cells = reach.cells
        table = reach.warps.get(mid, {})
        for s in states:
            _, x, y, _, _ = s
            warped = {reach.arrival(*table[c]) for c in ((x, y), (x, y - 1)) if c in table}
            for t in reach.moves(s):
                if t in warped:
                    continue
                if t[0] != mid:
                    self.goal[("conn", t[0])].add((x, y))
                    self.arrive[("conn", t[0])].add(s)
                elif t in states:
                    self.adj[s].append(t)
        self.by_cell = collections.defaultdict(set)
        for s in states:
            self.by_cell[s[1:3]].add(s)
        w, h = cells.size(mid)
        for (wx, wy), dest in table.items():
            if not (0 <= wx < w and 0 <= wy < h):
                continue
            key = ("warp", dest[0])
            self.arrive[key].update(self.by_cell.get((wx, wy), ()))
            solid = cells.base(mid, wx, wy)[0] != 0
            self.goal[key].add((wx, wy + 1) if solid else (wx, wy))
        self.exits = [k for k in self.goal if self.arrive[k]]

    def reach_from(self, starts, removed=None):
        seen = {s for s in starts if s[1:3] != removed}
        parent = {s: None for s in seen}
        stack = list(seen)
        while stack:
            s = stack.pop()
            for t in self.adj[s]:
                if t not in seen and t[1:3] != removed:
                    seen.add(t)
                    parent[t] = s
                    stack.append(t)
        return seen, parent

    def cells_of(self, seen):
        return {s[1:3] for s in seen}

    def cuts(self, interest):
        """cell of `interest` -> sorted [(from exit, to exit)] its occupation separates."""
        out = collections.defaultdict(set)
        for g1 in self.exits:
            seen, parent = self.reach_from(self.arrive[g1])
            reached = self.cells_of(seen)
            targets = {g2: self.goal[g2] & reached for g2 in self.exits if g2 != g1}
            targets = {g2: goals for g2, goals in targets.items() if goals}
            candidates = set()
            for goals in targets.values():
                # A cell on every path to an exit lies on the search-tree path to each goal cell.
                common = None
                for goal in goals:
                    path = set()
                    for s in self.by_cell[goal] & seen:
                        while s is not None:
                            path.add(s[1:3])
                            s = parent[s]
                    common = path if common is None else common & path
                candidates |= common & interest
            for c in candidates:
                after = self.cells_of(self.reach_from(self.arrive[g1], removed=c)[0])
                out[c].update((g1, g2) for g2, goals in targets.items() if not (goals - {c}) & after)
        return {c: sorted(v) for c, v in out.items() if v}


def exit_name(key):
    kind, mid = key
    return ("door/warp to " if kind == "warp" else "edge to ") + mid.replace("MAP_", "")


def evaluate(root, only=None):
    reach = Reach(root)
    seen = reach.flood(reach.seeds(), set())
    by_map = collections.defaultdict(set)
    for s in seen:
        if s[4] in (FOOT, SURF):
            by_map[s[0]].add(s)
    subjects = movers(reach, only)
    ranged = ranged_types(root)
    areas = {mover: area(reach, mover, ranged) for mover in subjects}
    interest = collections.defaultdict(set)
    for mover, cells in areas.items():
        interest[mover.mid] |= cells
    cuts = {mid: MapGraph(reach, mid, by_map.get(mid, set())).cuts(cells) for mid, cells in interest.items()}
    findings = []
    for mover in subjects:
        cut = cuts[mover.mid]
        hits = sorted(c for c in areas[mover] if c in cut)
        if hits:
            findings.append((mover, hits, cut))
    return subjects, findings


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
    ap.add_argument("--map", metavar="MAP_NAME", help="check only this map's objects")
    args = ap.parse_args()

    subjects, findings = evaluate(args.root, args.map)
    for mover, hits, cut in findings:
        print("BLOCKS   %s" % mover.label())
        for c in hits:
            pairs = cut[c]
            print("           can stand on (%d,%d): %s" % (c[0], c[1], "; ".join(
                "%s -> %s" % (exit_name(a), exit_name(b)) for a, b in pairs[:3])
                + (" (+%d more)" % (len(pairs) - 3) if len(pairs) > 3 else "")))
    print("checked %d scriptless moving objects: %d can block an exit" % (len(subjects), len(findings)))
    if findings:
        print("FAIL: tighten the range or move each object so it cannot reach those cells")
        return 1
    print("PASS: no scriptless object can stand where it cuts the player off from an exit")
    return 0


if __name__ == "__main__":
    sys.exit(main())
