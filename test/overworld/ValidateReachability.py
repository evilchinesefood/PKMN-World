#!/usr/bin/env python3
"""Report the item balls, hidden items, trainers and gift NPCs a player can never reach.

One search runs over every map at once, on the game's own movement rules
(src/event_object_movement.c GetCollisionAtCoords, src/field_player_avatar.c
CheckForObjectEventCollision, src/field_control_avatar.c). A state is a map cell, the
player's elevation and whether the player walks, surfs or dives. From a state the player can:

  * walk or surf to a neighbour with no collision bits, no direction block and no elevation
    mismatch (elevation 0 matches anything, 15 is a bridge that keeps the old elevation);
  * jump a ledge, one way, two cells in the ledge's direction;
  * start surfing from elevation 3 onto surfable water whose elevation differs, and stop
    surfing onto an elevation-3 cell;
  * climb a waterfall north, dive on deep water and emerge where emerging is allowed;
  * cross a map connection, or take a warp from its cell or from the cell south of it.

Every field move is assumed unlocked (QOL_FIELD_MOVES_ITEM_GATE), and Cut trees, Rock Smash
rocks, Strength boulders and NPCs are never obstacles, so the search over-approximates. The
seeds are every warp event, heal location, scripted warp target and literal C warp.

An object is reached when the player can face it from an adjacent cell (or across a counter)
with a matching elevation, as GetInteractedObjectEventScript does. A hidden item is reached the
same way through GetBackgroundEventAtPosition; an underfoot hidden item (FRLG) only by standing
on it. A trainer is reached when it can be talked to or when its line of sight, checked as
CheckPathBetweenTrainerAndPlayer does, ends on a reached cell.

A subject the search misses gets two more tries. The runtime tier applies every `setmetatile`
and `setmaplayoutindex` the map's scripts (and the shared scripts they jump into) can run as an
alternative for the cells it touches, and tries objects that `setobjectxyperm`/`setobjectxy`
moves at their new cells; a subject reached there is reported with that mechanism. RUNTIME
names the maps C code or coord-event movement changes instead. The Sky Charm tier lets the
player land, as CanLandOverworldFlight allows, on any free, dry, non-ledge cell of an outdoor
map joined by connections to one the player stands on. A subject only that tier reaches fails
the check: no source game needs flight, and Olivine's Shock Wave ball was reachable only by
landing on a mis-tagged sea tile and walking on water. Anything else unreached and not on a
RUNTIME map fails too.

Usage:
    python3 test/overworld/ValidateReachability.py [--root DIR] [--list] [--map MAP_NAME]
"""

import argparse
import collections
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ValidateBorderTerrain import World, behaviour_values, read  # noqa: E402

FOOT, SURF, DIVE = 0, 1, 2
DIRS = {"S": (0, 1), "N": (0, -1), "W": (-1, 0), "E": (1, 0)}
OUTDOOR = {"MAP_TYPE_TOWN", "MAP_TYPE_CITY", "MAP_TYPE_ROUTE", "MAP_TYPE_OCEAN_ROUTE"}

# Maps whose terrain or objects C code changes at runtime, so a static search cannot speak
# for them. Each entry names the mechanism. An entry that no longer explains anything is stale.
RUNTIME = {
    "AzaleaTown_Gym": "coord events carry the player across the webs on Ariados carts "
                      "(AzaleaTown_Gym_EventScript_Trigger_*)",
}
RUNTIME.update({"BattlePyramidSquare%02d" % n: "battle_pyramid.c builds each floor's layout and objects at runtime"
                for n in range(1, 17)})

GIVE_COMMANDS = ("giveitem", "giveitem_msg", "givemon", "giveegg", "givenamedmon", "giveoddegg",
                 "givedecoration", "giverandomberry", "givecustommon")
JUMPS = ("goto", "call", "goto_if", "call_if")


class Cells:
    """Decoded attributes of every map cell: (collision, elevation, behaviour) per block, plus
    the alternatives runtime scripts can swap in."""

    def __init__(self, world, variants):
        self.world = world
        self.grids = {}
        self.extra = collections.defaultdict(dict)
        for mid, m in world.maps.items():
            layout = world.layouts[m["layout"]]
            w, h, blocks = world.blocks(layout)
            self.grids[mid] = (w, h, [self.decode(layout, b) for b in blocks])
        if variants:
            self.add_variants(variants)

    def decode(self, layout, block):
        return ((block >> 10) & 3, block >> 12, self.world.behaviour(layout, block))

    def size(self, mid):
        w, h, _ = self.grids[mid]
        return w, h

    def base(self, mid, x, y):
        w, _, cells = self.grids[mid]
        return cells[y * w + x]

    def options(self, mid, x, y):
        b = self.base(mid, x, y)
        alt = self.extra[mid].get((x, y)) if mid in self.extra else None
        return (b,) + tuple(alt) if alt else (b,)

    def add_variants(self, variants):
        for mid, (layouts, edits) in variants.items():
            m = self.world.maps[mid]
            w, h, cells = self.grids[mid]
            for lid in layouts:
                other = self.world.layouts.get(lid)
                if not other:
                    continue
                ow, oh, oblocks = self.world.blocks(other)
                for y in range(min(h, oh)):
                    for x in range(min(w, ow)):
                        cell = self.decode(other, oblocks[y * ow + x])
                        if cell != cells[y * w + x]:
                            self.extra[mid].setdefault((x, y), set()).add(cell)
            layout = self.world.layouts[m["layout"]]
            for x, y, metatile, impassable in edits:
                if 0 <= x < w and 0 <= y < h:
                    elev = cells[y * w + x][1]
                    beh = self.world.behaviour(layout, metatile)
                    self.extra[mid].setdefault((x, y), set()).add((1 if impassable else 0, elev, beh))


class Rules:
    def __init__(self, root):
        v = behaviour_values(root)
        self.v = v
        self.ledge = {v["MB_JUMP_EAST"]: "E", v["MB_JUMP_WEST"]: "W", v["MB_JUMP_NORTH"]: "N",
                      v["MB_JUMP_SOUTH"]: "S"}
        self.blocked = {
            "N": {v[n] for n in ("MB_IMPASSABLE_NORTH", "MB_IMPASSABLE_NORTHEAST", "MB_IMPASSABLE_NORTHWEST",
                                 "MB_IMPASSABLE_SOUTH_AND_NORTH")},
            "S": {v[n] for n in ("MB_IMPASSABLE_SOUTH", "MB_IMPASSABLE_SOUTHEAST", "MB_IMPASSABLE_SOUTHWEST",
                                 "MB_IMPASSABLE_SOUTH_AND_NORTH")},
            "E": {v[n] for n in ("MB_IMPASSABLE_EAST", "MB_IMPASSABLE_NORTHEAST", "MB_IMPASSABLE_SOUTHEAST",
                                 "MB_IMPASSABLE_WEST_AND_EAST", "MB_SECRET_BASE_BREAKABLE_DOOR")},
            "W": {v[n] for n in ("MB_IMPASSABLE_WEST", "MB_IMPASSABLE_NORTHWEST", "MB_IMPASSABLE_SOUTHWEST",
                                 "MB_IMPASSABLE_WEST_AND_EAST", "MB_SECRET_BASE_BREAKABLE_DOOR")},
        }
        self.opposite = {"N": "S", "S": "N", "E": "W", "W": "E"}
        self.surf_onto = {v[n] for n in ("MB_POND_WATER", "MB_OCEAN_WATER", "MB_INTERIOR_DEEP_WATER", "MB_DEEP_WATER",
                                         "MB_SOOTOPOLIS_DEEP_WATER", "MB_EASTWARD_CURRENT", "MB_WESTWARD_CURRENT",
                                         "MB_NORTHWARD_CURRENT", "MB_SOUTHWARD_CURRENT")}
        self.diveable = {v[n] for n in ("MB_INTERIOR_DEEP_WATER", "MB_DEEP_WATER", "MB_SOOTOPOLIS_DEEP_WATER")}
        self.no_emerge = {v["MB_NO_SURFACING"], v["MB_SEAWEED_NO_SURFACING"]}
        self.waterfall = v["MB_WATERFALL"]
        self.counter = v["MB_COUNTER"]
        flags = re.finditer(r"\[(MB_\w+)\]\s*=\s*[^\n]*TILE_FLAG_SURFABLE", read(root, "src/metatile_behavior.c"))
        self.surfable = {v[m.group(1)] for m in flags}

    def dir_blocked(self, cur_beh, next_beh, d):
        """IsMetatileDirectionallyImpassable: a wall on the side of the current cell the player
        leaves through, or on the side of the next cell the player enters through."""
        return cur_beh in self.blocked[d] or next_beh in self.blocked[self.opposite[d]]


def elevation_after(prev_elev, cur_elev, elev):
    """ObjectEventUpdateElevation: a bridge (15) on either side keeps the old elevation."""
    return elev if cur_elev == 15 or prev_elev == 15 else cur_elev


def mismatch(elev, cell_elev):
    """IsElevationMismatchAt."""
    return elev != 0 and cell_elev not in (0, 15) and cell_elev != elev


class Reach:
    def __init__(self, root, runtime_variants=False):
        self.root = root
        self.world = World(root)
        self.rules = Rules(root)
        self.scripts = ScriptIndex(root)
        self.variants = self.runtime_variants() if runtime_variants else {}
        self.cells = Cells(self.world, self.variants)
        self.conn = {}
        for mid, m in self.world.maps.items():
            self.conn[mid] = [c for c in (m.get("connections") or []) if c["map"] in self.world.maps]
        self.warps = self.warp_table()

    def neighbour(self, mid, x, y, d):
        dx, dy = DIRS[d]
        nx, ny = x + dx, y + dy
        w, h = self.cells.size(mid)
        if 0 <= nx < w and 0 <= ny < h:
            return mid, nx, ny
        for c in self.conn[mid]:
            cw, ch = self.cells.size(c["map"])
            off, cd = c["offset"], c["direction"]
            if cd == "down" and ny == h and 0 <= nx - off < cw:
                return c["map"], nx - off, 0
            if cd == "up" and ny == -1 and 0 <= nx - off < cw:
                return c["map"], nx - off, ch - 1
            if cd == "left" and nx == -1 and 0 <= ny - off < ch:
                return c["map"], cw - 1, ny - off
            if cd == "right" and nx == w and 0 <= ny - off < ch:
                return c["map"], 0, ny - off
        return None

    def arrival(self, mid, x, y):
        w, h = self.cells.size(mid)
        if not (0 <= x < w and 0 <= y < h):
            return None
        _, elev, beh = self.cells.base(mid, x, y)
        mode = DIVE if self.world.maps[mid].get("map_type") == "MAP_TYPE_UNDERWATER" else \
            SURF if beh in self.rules.surfable else FOOT
        return (mid, x, y, 0 if elev == 15 else elev, mode)

    def warp_table(self):
        """map id -> {(x, y): (dest map id, x, y)} for every resolvable warp event."""
        out = {}
        for mid, m in self.world.maps.items():
            for wv in m.get("warp_events") or []:
                dest = self.world.maps.get(wv["dest_map"])
                try:
                    wid = int(wv["dest_warp_id"])
                except ValueError:
                    continue
                dw = (dest or {}).get("warp_events") or []
                if 0 <= wid < len(dw):
                    out.setdefault(mid, {})[(wv["x"], wv["y"])] = (wv["dest_map"], dw[wid]["x"], dw[wid]["y"])
        return out

    def seeds(self):
        cells = set()
        for mid, m in self.world.maps.items():
            cells.update((mid, wv["x"], wv["y"]) for wv in m.get("warp_events") or [])
            cells.update((mid, x, y) for (x, y) in self.world.entries.get(mid, ()))
        for mid, x, y in c_warp_targets(self.root):
            cells.add((mid, x, y))
        return [s for s in (self.arrival(*c) for c in cells if c[0] in self.world.maps) if s]

    def moves(self, state):
        mid, x, y, elev, mode = state
        r = self.rules
        here = self.cells.options(mid, x, y)
        for d in DIRS:
            t = self.neighbour(mid, x, y, d)
            if not t:
                continue
            for cur in here:
                for nxt in self.cells.options(*t):
                    coll, telev, tbeh = nxt
                    blocked = coll != 0 or r.dir_blocked(cur[2], tbeh, d)
                    off_level = not blocked and mismatch(elev, telev)
                    if off_level and mode == SURF and telev == 3:
                        yield t + (elevation_after(cur[1], telev, elev), FOOT)
                    if r.ledge.get(tbeh) == d:
                        land = self.neighbour(*t, d)
                        if land:
                            yield land + (elevation_after(cur[1], self.cells.base(*land)[1], elev), mode)
                    if not blocked and not off_level:
                        yield t + (elevation_after(cur[1], telev, elev), mode)
                    if (mode == FOOT and elev == 3 and off_level and tbeh in r.surf_onto):
                        yield t + (elevation_after(cur[1], telev, elev), SURF)
                    if mode == SURF and d == "N" and tbeh == r.waterfall:
                        top, last = t, nxt
                        while top and self.cells.base(*top)[2] == r.waterfall:
                            last = self.cells.base(*top)
                            top = self.neighbour(*top, "N")
                        if top:
                            yield top + (elevation_after(last[1], self.cells.base(*top)[1], elev), SURF)
        for cur in here:
            if mode == SURF and cur[2] in r.diveable:
                for c in self.conn[mid]:
                    if c["direction"] == "dive":
                        s = self.arrival(c["map"], x, y)
                        if s:
                            yield s[:4] + (DIVE,)
            if mode == DIVE and cur[2] not in r.no_emerge:
                for c in self.conn[mid]:
                    if c["direction"] == "emerge":
                        s = self.arrival(c["map"], x, y)
                        if s:
                            yield s[:4] + (SURF,)
        table = self.warps.get(mid, {})
        for wx, wy in ((x, y), (x, y - 1)):
            if (wx, wy) in table:
                s = self.arrival(*table[(wx, wy)])
                if s:
                    yield s

    def flood(self, states, seen):
        stack = [s for s in states if s not in seen]
        seen.update(stack)
        while stack:
            for nxt in self.moves(stack.pop()):
                if nxt not in seen:
                    seen.add(nxt)
                    stack.append(nxt)
        return seen

    def landing_cells(self, mid):
        r = self.rules
        w, h = self.cells.size(mid)
        out = []
        for y in range(h):
            for x in range(w):
                for coll, elev, beh in self.cells.options(mid, x, y):
                    if coll == 0 and beh not in r.surfable and beh != r.waterfall and beh not in r.ledge:
                        out.append((mid, x, y, 0 if elev == 15 else elev, FOOT))
                        break
        return out

    def sky(self, seen):
        """Add Sky Charm landings until nothing new is reached."""
        outdoor = {mid for mid, m in self.world.maps.items() if m.get("map_type") in OUTDOOR}
        done = set()
        while True:
            takeoff = {s[0] for s in seen if s[4] == FOOT and s[0] in outdoor} - done
            if not takeoff:
                return seen
            new = []
            for start in takeoff:
                comp, stack = {start}, [start]
                while stack:
                    for c in self.conn[stack.pop()]:
                        if c["map"] in outdoor and c["map"] not in comp:
                            comp.add(c["map"])
                            stack.append(c["map"])
                for mid in comp - done:
                    new.extend(self.landing_cells(mid))
                done |= comp
            self.flood(new, seen)

    def runtime_variants(self):
        metatiles = {}
        for m in re.finditer(r"#define\s+(METATILE_\w+)\s+(0x[0-9A-Fa-f]+|\d+)",
                             read(self.root, "include/constants/metatile_labels.h")):
            metatiles[m.group(1)] = int(m.group(2), 0)
        edit = re.compile(r"^\s*setmetatile\s+(\d+)\s*,\s*(\d+)\s*,\s*(\w+)\s*,\s*(\w+)", re.M)
        swap = re.compile(r"^\s*setmaplayoutindex\s+(LAYOUT_\w+)", re.M)
        out = {}
        for mid, m in self.world.maps.items():
            text = self.scripts.map_code(m["name"])
            edits = []
            for e in edit.finditer(text):
                value = metatiles.get(e.group(3))
                if value is None:
                    try:
                        value = int(e.group(3), 0)
                    except ValueError:
                        continue
                edits.append((int(e.group(1)), int(e.group(2)), value, e.group(4) == "TRUE"))
            layouts = swap.findall(text)
            if edits or layouts:
                out[mid] = (layouts, edits)
        return out


class ScriptIndex:
    """Labels of every map script file and the commands each label's code reaches."""

    def __init__(self, root):
        self.map_text = {}
        self.labels = {}
        self.by_file = collections.defaultdict(list)
        label = re.compile(r"^(\w+)::?\s*$")
        files = [(name, os.path.join(root, "data/maps", name, "scripts.inc"))
                 for name in os.listdir(os.path.join(root, "data/maps"))]
        files += [("data/scripts/" + name, os.path.join(root, "data/scripts", name))
                  for name in os.listdir(os.path.join(root, "data/scripts")) if name.endswith(".inc")]
        for name, path in files:
            if not os.path.exists(path):
                continue
            with open(path) as f:
                text = f.read()
            self.map_text[name] = text
            current = None
            for line in text.splitlines():
                m = label.match(line)
                if m:
                    current = m.group(1)
                    self.labels[current] = (name, [])
                    self.by_file[name].append(current)
                elif current and line.strip() and not line.strip().startswith("@"):
                    self.labels[current][1].append(line.strip())

    def walk(self, starts, home=None):
        """Every line the code from `starts` can run, following jumps (within `home` if given)."""
        seen = {l for l in starts if l in self.labels}
        stack = list(seen)
        while stack:
            for line in self.labels[stack.pop()][1]:
                yield line
                if line.split()[0].startswith(JUMPS):
                    for tok in re.findall(r"\w+", line)[1:]:
                        if tok in self.labels and tok not in seen and home in (None, self.labels[tok][0]):
                            seen.add(tok)
                            stack.append(tok)

    def reaches(self, start, words):
        """Does the code from `start` reach a command in `words` without leaving its file?"""
        home = self.labels[start][0] if start in self.labels else None
        return any(line.split()[0] in words for line in self.walk([start], home))

    def map_code(self, name):
        """The map's own script file plus every shared script it jumps into."""
        return "\n".join(self.walk(self.by_file.get(name, [])))


def c_warp_targets(root):
    pat = re.compile(r"SetWarpDestination\(MAP_GROUP\((MAP_\w+)\),\s*MAP_NUM\(\1\),\s*[\w-]+,\s*(\d+),\s*(\d+)\)")
    out = []
    for name in os.listdir(os.path.join(root, "src")):
        if name.endswith(".c"):
            with open(os.path.join(root, "src", name)) as f:
                out += [(m.group(1), int(m.group(2)), int(m.group(3))) for m in pat.finditer(f.read())]
    return out


FACING = {
    "MOVEMENT_TYPE_FACE_UP": "N", "MOVEMENT_TYPE_FACE_DOWN": "S", "MOVEMENT_TYPE_FACE_LEFT": "W",
    "MOVEMENT_TYPE_FACE_RIGHT": "E", "MOVEMENT_TYPE_FACE_DOWN_AND_UP": "SN", "MOVEMENT_TYPE_FACE_LEFT_AND_RIGHT": "WE",
    "MOVEMENT_TYPE_FACE_UP_AND_LEFT": "NW", "MOVEMENT_TYPE_FACE_UP_AND_RIGHT": "NE",
    "MOVEMENT_TYPE_FACE_DOWN_AND_LEFT": "SW", "MOVEMENT_TYPE_FACE_DOWN_AND_RIGHT": "SE",
    "MOVEMENT_TYPE_FACE_DOWN_UP_AND_LEFT": "SNW", "MOVEMENT_TYPE_FACE_DOWN_UP_AND_RIGHT": "SNE",
    "MOVEMENT_TYPE_FACE_UP_LEFT_AND_RIGHT": "NWE", "MOVEMENT_TYPE_FACE_DOWN_LEFT_AND_RIGHT": "SWE",
    "MOVEMENT_TYPE_WALK_IN_PLACE_DOWN": "S", "MOVEMENT_TYPE_WALK_IN_PLACE_UP": "N",
    "MOVEMENT_TYPE_WALK_IN_PLACE_LEFT": "W", "MOVEMENT_TYPE_WALK_IN_PLACE_RIGHT": "E",
    "MOVEMENT_TYPE_NONE": "S",
}


class Subject:
    """One thing the player has to get to: an object event or a hidden item."""

    def __init__(self, kind, mid, name, index, ev, positions, moved):
        self.kind, self.mid, self.name, self.index, self.ev = kind, mid, name, index, ev
        self.positions, self.moved = positions, moved

    def label(self):
        what = self.ev.get("item") or self.ev.get("script") or ""
        tag = "obj %d" % self.index if self.kind != "hidden item" else "bg"
        return "%s %s (%d,%d) %s %s" % (self.name, tag, self.ev["x"], self.ev["y"], self.kind, what)


def subjects(reach):
    scripts = reach.scripts
    move = re.compile(r"^\s*(?:setobjectxyperm|setobjectxy)\s+(\w+)\s*,\s*(\d+)\s*,\s*(\d+)", re.M)
    out = []
    for mid, m in sorted(reach.world.maps.items()):
        name = m["name"]
        moved = collections.defaultdict(list)
        for e in move.finditer(scripts.map_text.get(name, "")):
            moved[e.group(1)].append((int(e.group(2)), int(e.group(3))))
        for i, ev in enumerate(m.get("object_events") or [], 1):
            if ev.get("type") == "clone" or "x" not in ev:
                continue
            script = ev.get("script", "")
            if ev.get("trainer_type", "TRAINER_TYPE_NONE") != "TRAINER_TYPE_NONE" \
                    or scripts.reaches(script, ("trainerbattle",)):
                kind = "trainer"
            elif script == "Common_EventScript_FindItem" or scripts.reaches(script, ("finditem",)):
                kind = "item ball"
            elif scripts.reaches(script, GIVE_COMMANDS):
                kind = "gift"
            else:
                continue
            ids = {str(i), ev.get("local_id", "")}
            alt = [p for k in ids if k for p in moved.get(k, [])]
            out.append(Subject(kind, mid, name, i, ev, [(ev["x"], ev["y"])], alt))
        for i, ev in enumerate(m.get("bg_events") or []):
            if ev.get("type") == "hidden_item":
                out.append(Subject("hidden item", mid, name, i, ev, [(ev["x"], ev["y"])], []))
    return out


class Index:
    """Reached (elevation, mode) pairs by cell."""

    def __init__(self, seen):
        self.by_cell = collections.defaultdict(set)
        for mid, x, y, elev, mode in seen:
            self.by_cell[(mid, x, y)].add((elev, mode))

    def at(self, mid, x, y):
        return self.by_cell.get((mid, x, y), ())


def reached(reach, index, subj, positions):
    cells = reach.cells
    rules = reach.rules
    mid = subj.mid
    w, h = cells.size(mid)
    ev = subj.ev
    for px, py in positions:
        if not (0 <= px < w and 0 <= py < h):
            continue
        tile_elev = cells.base(mid, px, py)[1]
        if subj.kind == "hidden item":
            if ev.get("underfoot"):
                if index.at(mid, px, py):
                    return "stand"
                continue
            want = ev.get("elevation", 0)
        else:
            want = ev.get("elevation", 0) if tile_elev == 15 else tile_elev
        for d, (dx, dy) in DIRS.items():
            for gap in (1, 2):
                qx, qy = px - dx * gap, py - dy * gap
                if not (0 <= qx < w and 0 <= qy < h):
                    continue
                if gap == 2 and (subj.kind == "hidden item" or
                                 cells.base(mid, px - dx, py - dy)[2] != rules.counter):
                    continue
                stand_elev = cells.base(mid, qx, qy)[1]
                for elev, mode in index.at(mid, qx, qy):
                    pos = 0 if stand_elev == 0 else elev
                    if subj.kind == "hidden item":
                        ok = want == pos or want == 0
                    else:
                        ok = want == 0 or pos == 0 or want == pos
                    if ok:
                        return "face"
        if subj.kind == "trainer" and sees(reach, index, subj, px, py, want):
            return "sight"
    return None


def sees(reach, index, subj, px, py, telev):
    ev = subj.ev
    cells = reach.cells
    mid = subj.mid
    w, h = cells.size(mid)
    try:
        rng = int(ev.get("trainer_sight_or_berry_tree_id", "0"), 0)
    except ValueError:
        rng = 0
    if ev.get("trainer_type") == "TRAINER_TYPE_NORMAL":
        dirs = FACING.get(ev.get("movement_type"), "NSWE")
    else:
        dirs = "NSWE"
    for d in dirs:
        dx, dy = DIRS[d]
        for k in range(1, rng + 1):
            x, y = px + dx * k, py + dy * k
            if not (0 <= x < w and 0 <= y < h):
                break
            coll, elev, beh = cells.base(mid, x, y)
            if coll or mismatch(telev, elev):
                break
            if any(e == 0 or telev == 0 or e == telev for e, _ in index.at(mid, x, y)):
                return True
    return False


def evaluate(root):
    static = Reach(root)
    ground = static.flood(static.seeds(), set())
    runtime = Reach(root, runtime_variants=True)
    loose = runtime.flood(runtime.seeds(), set())
    sky = static.sky(set(ground))
    tiers = [("ground", static, Index(ground)), ("runtime", runtime, Index(loose)), ("sky", static, Index(sky))]
    rows = []
    for subj in subjects(static):
        verdict = None
        for tier, reach, index in tiers:
            how = reached(reach, index, subj, subj.positions)
            if not how and subj.moved:
                how = reached(reach, index, subj, subj.moved) and "moved by script"
            if how:
                verdict = (tier, how)
                break
        rows.append((subj, verdict))
    return static, rows, runtime.variants


def mechanism(subj, verdict, variants):
    if verdict and verdict[0] == "runtime":
        layouts, edits = variants.get(subj.mid, ([], []))
        bits = []
        if edits:
            bits.append("%d setmetatile" % len(edits))
        if layouts:
            bits.append("setmaplayoutindex " + ", ".join(sorted(set(layouts))))
        return " and ".join(bits) or verdict[1]
    if verdict and verdict[1] == "moved by script":
        return "setobjectxyperm"
    return ""


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
    ap.add_argument("--list", action="store_true", help="print every subject and how it is reached")
    ap.add_argument("--map", metavar="MAP_NAME", help="report only this map's subjects")
    args = ap.parse_args()

    _, rows, variants = evaluate(args.root)
    counts, kinds = collections.Counter(), collections.Counter()
    runtime = collections.defaultdict(list)
    failures, explained = [], set()
    for subj, verdict in rows:
        if args.map and subj.name != args.map:
            continue
        kinds[subj.kind] += 1
        tier, how = verdict or (None, None)
        if tier == "ground" and how != "moved by script":
            counts["reachable"] += 1
            if args.list:
                print("ok       %s: %s" % (subj.label(), how))
        elif tier in ("ground", "runtime"):
            runtime[(subj.name, mechanism(subj, verdict, variants))].append(subj)
        elif subj.name in RUNTIME:
            explained.add(subj.name)
            runtime[(subj.name, RUNTIME[subj.name])].append(subj)
        elif tier == "sky":
            failures.append("SKY-ONLY %s: only a Sky Charm landing reaches it" % subj.label())
        else:
            failures.append("UNREACH  %s" % subj.label())
    for (name, why), subjs in sorted(runtime.items()):
        counts["runtime"] += len(subjs)
        print("runtime  %s, %d subject%s: %s" % (name, len(subjs), "" if len(subjs) == 1 else "s", why))
        if args.list:
            for subj in subjs:
                print("           %s" % subj.label())
    for line in failures:
        print(line)
    stale = [] if args.map else sorted(set(RUNTIME) - explained)
    for name in stale:
        print("STALE    RUNTIME entry %s explains nothing; remove it" % name)
    print("checked %d (%s): %d reachable, %d on runtime-changing maps, %d unreachable" % (
        sum(kinds.values()), ", ".join("%d %s" % (n, k) for k, n in sorted(kinds.items())),
        counts["reachable"], counts["runtime"], len(failures)))
    if failures or stale:
        print("FAIL: %d unreachable subject%s, %d stale RUNTIME entr%s" % (
            len(failures), "" if len(failures) == 1 else "s", len(stale), "y" if len(stale) == 1 else "ies"))
        return 1
    print("PASS: every item ball, hidden item, trainer and gift NPC is reachable")
    return 0


if __name__ == "__main__":
    sys.exit(main())
