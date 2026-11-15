#!/usr/bin/env python3
"""Flag map borders that show the wrong terrain inside the camera view.

The field camera draws 7 cells past each edge of the current map. Cells a connection fills
show the neighbour's blocks (Fill*Connection, src/fieldmap.c); every other cell shows the map's
own border pattern (GetBorderBlockAt). Where no connection covers a corner the player can see,
the border is what the player sees. Olivine City's border was four tree metatiles, so its two
sea corners drew hard-edged squares of forest in open water.

For every map this rebuilds that frame from data/maps and data/layouts, takes the uncovered
cells within one screen (15 columns, 4 rows above to 6 below) of any collision-free cell, groups
them into connected regions, and classifies each region's covered neighbours as water (a
TILE_FLAG_SURFABLE behaviour), open land or blocked land. A region is a finding when

  * the border is all land and at least half of its neighbours are water, or
  * the border is all water and at least half of its neighbours are open land.

Most findings are not this tree's to fix: vanilla Emerald draws some of them, and on the Johto
maps below the visible corners touch land and sea at once, so no single 2x2 border suits both.
KNOWN lists each with its reason; an unlisted finding or a stale KNOWN entry fails.

Usage:
    python3 test/overworld/ValidateBorderTerrain.py [--root DIR] [--show MAP_NAME]
"""

import argparse
import json
import os
import re
import struct
import sys

MAP_OFFSET = 7
VIEW_X, VIEW_UP, VIEW_DOWN = 7, 4, 6

KNOWN = {
    "AbandonedShip_Underwater1": "vanilla: the underwater rooms sit in a black void border",
    "AbandonedShip_Underwater2": "vanilla: the underwater rooms sit in a black void border",
    "MauvilleCity": "vanilla: a sea-border corner between Route 111 and Route 117",
    "Route104": "vanilla: tree border west of the sea",
    "Route106": "vanilla: tree border around the sea",
    "Route121": "vanilla: tree border south of the ponds",
    "CianwoodCity": "sea border west of the coast, as pokemonHnS draws it",
    "GoldenrodCity": "sea border west of the harbour, as pokemonHnS draws it",
    "CherrygroveCity": "pokemonHnS: the bay runs off the west and south edges, but the forest "
                       "also meets the west edge, so a sea border trades one artifact for another",
    "Route26": "pokemonHnS: the sea runs off the east and south edges, but the mountains and a "
               "cave canyon meet the west edge",
    "Route34": "pokemonHnS: sea at the north-west and south-west corners, forest along the rest "
               "of the west edge",
}


def read(root, rel):
    with open(os.path.join(root, rel)) as f:
        return f.read()


def surfable_behaviours(root):
    body = read(root, "include/constants/metatile_behaviors.h")
    body = body[body.index("enum {") + 6: body.index("};")]
    values, i = {}, 0
    for line in body.splitlines():
        line = line.split("//")[0].strip().rstrip(",")
        if not line:
            continue
        if "=" in line:
            line, value = [s.strip() for s in line.split("=")]
            i = int(value, 0)
        values[line] = i
        i += 1
    flags = re.finditer(r"\[(MB_\w+)\]\s*=\s*[^\n]*TILE_FLAG_SURFABLE", read(root, "src/metatile_behavior.c"))
    return {values[m.group(1)] for m in flags}


def tileset_behaviours(root):
    attr_files = {}
    for m in re.finditer(r'const (u16|u32) (gMetatileAttributes_\w+)\[\] = INCBIN_U(?:16|32)\("([^"]+)"\)',
                         read(root, "src/data/tilesets/metatiles.h")):
        attr_files[m.group(2)] = (m.group(3), m.group(1) == "u32")
    tilesets = {}
    for m in re.finditer(r"const struct Tileset (gTileset_\w+) =\s*\{(.*?)\n\};",
                         read(root, "src/data/tilesets/headers.h"), re.S):
        attrs = re.search(r"TILESET_METATILES\(\w+,\s*(\w+)\)", m.group(2))
        if not attrs:
            continue
        path, wide = attr_files[attrs.group(1)]
        with open(os.path.join(root, path), "rb") as f:
            raw = f.read()
        if wide:
            tilesets[m.group(1)] = [v & 0x1FF for v in struct.unpack("<%dI" % (len(raw) // 4), raw)]
        else:
            tilesets[m.group(1)] = [v & 0xFF for v in struct.unpack("<%dH" % (len(raw) // 2), raw)]
    return tilesets


class World:
    def __init__(self, root):
        self.root = root
        self.surfable = surfable_behaviours(root)
        self.tilesets = tileset_behaviours(root)
        layouts = json.loads(read(root, "data/layouts/layouts.json"))["layouts"]
        self.layouts = {l["id"]: l for l in layouts if l}
        self.maps = {}
        for name in sorted(os.listdir(os.path.join(root, "data/maps"))):
            path = os.path.join(root, "data/maps", name, "map.json")
            if os.path.exists(path):
                with open(path) as f:
                    m = json.load(f)
                if "layout" in m and m["layout"] in self.layouts:
                    self.maps[m["id"]] = m
        self._blocks = {}

    def blocks(self, layout):
        if layout["id"] not in self._blocks:
            w, h = layout["width"], layout["height"]
            with open(os.path.join(self.root, layout["blockdata_filepath"]), "rb") as f:
                self._blocks[layout["id"]] = (w, h, struct.unpack("<%dH" % (w * h), f.read()[:w * h * 2]))
        return self._blocks[layout["id"]]

    def is_water(self, layout, block):
        metatile = block & 0x3FF
        split = 512 if layout.get("layout_version", "emerald") == "emerald" else 640
        name, index = (layout["primary_tileset"], metatile) if metatile < split \
            else (layout["secondary_tileset"], metatile - split)
        behaviours = self.tilesets.get(name)
        if behaviours is None or index >= len(behaviours):
            return None
        return behaviours[index] in self.surfable

    def frame(self, map_id):
        """The camera's grid for a map: (x, y) -> (source map id, block) for every covered cell."""
        m = self.maps[map_id]
        w, h, own = self.blocks(self.layouts[m["layout"]])
        grid = {(x, y): (map_id, own[y * w + x]) for y in range(h) for x in range(w)}
        for c in m.get("connections") or []:
            other = self.maps.get(c["map"])
            if not other:
                continue
            cw, ch, theirs = self.blocks(self.layouts[other["layout"]])
            off, d = c["offset"], c["direction"]
            for i in range(MAP_OFFSET + (d == "right")):
                if d in ("down", "up"):
                    sy = i if d == "down" else ch - MAP_OFFSET + i
                    y = h + i if d == "down" else -MAP_OFFSET + i
                    if 0 <= sy < ch:
                        for sx in range(cw):
                            if -MAP_OFFSET <= off + sx <= w + MAP_OFFSET:
                                grid.setdefault((off + sx, y), (c["map"], theirs[sy * cw + sx]))
                elif d in ("left", "right"):
                    sx = cw - MAP_OFFSET + i if d == "left" else i
                    x = -MAP_OFFSET + i if d == "left" else w + i
                    if 0 <= sx < cw:
                        for sy in range(ch):
                            if -MAP_OFFSET <= off + sy < h + MAP_OFFSET:
                                grid.setdefault((x, off + sy), (c["map"], theirs[sy * cw + sx]))
        return grid

    def border_at(self, layout):
        with open(os.path.join(self.root, layout["border_filepath"]), "rb") as f:
            raw = f.read()
        border = struct.unpack("<%dH" % (len(raw) // 2), raw)
        if layout.get("layout_version") == "frlg":
            bw, bh = layout["border_width"], layout["border_height"]
            return (lambda x, y: border[(x % bw) + (y % bh) * bw]), border[:bw * bh]
        return (lambda x, y: border[(x & 1) + (y & 1) * 2]), border[:4]

    def findings(self, map_id):
        m = self.maps[map_id]
        layout = self.layouts[m["layout"]]
        w, h, own = self.blocks(layout)
        grid = self.frame(map_id)
        border_at, pattern = self.border_at(layout)
        kinds = {self.is_water(layout, b) for b in pattern}
        visible = set()
        for y in range(h):
            for x in range(w):
                if (own[y * w + x] >> 10) & 3:
                    continue
                for dy in range(-VIEW_UP, VIEW_DOWN + 1):
                    for dx in range(-VIEW_X, VIEW_X + 1):
                        if (x + dx, y + dy) not in grid:
                            visible.add((x + dx, y + dy))
        out = []
        for region in regions(visible):
            water = open_land = blocked = 0
            edge = set()
            for (x, y) in region:
                for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if n in grid and n not in edge:
                        edge.add(n)
                        block = grid[n][1]
                        if self.is_water(layout, block):
                            water += 1
                        elif (block >> 10) & 3:
                            blocked += 1
                        else:
                            open_land += 1
            total = water + open_land + blocked
            if kinds == {False} and total and water * 2 >= total:
                kind = "land border beside sea"
            elif kinds == {True} and total and open_land * 2 >= total:
                kind = "sea border beside open land"
            else:
                continue
            out.append((kind, region, water, open_land, blocked))
        return out, grid, border_at, layout, visible


def regions(cells):
    cells, out = set(cells), []
    while cells:
        stack = [cells.pop()]
        region = list(stack)
        while stack:
            x, y = stack.pop()
            for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if n in cells:
                    cells.remove(n)
                    region.append(n)
                    stack.append(n)
        out.append(region)
    return out


def show(world, name):
    map_id = next(i for i, m in world.maps.items() if m["name"] == name)
    found, grid, border_at, layout, visible = world.findings(map_id)
    w, h, _ = world.blocks(layout)
    print("%s: ~ water  . open  # blocked (o , %% from a connection)  W/T visible border sea/land" % name)
    for y in range(-MAP_OFFSET, h + MAP_OFFSET):
        row = []
        for x in range(-MAP_OFFSET, w + MAP_OFFSET + 1):
            if (x, y) in grid:
                src, block = grid[(x, y)]
                ch = "~" if world.is_water(layout, block) else ("#" if (block >> 10) & 3 else ".")
                row.append(ch if src == map_id else {"~": "o", "#": "%", ".": ","}[ch])
            elif (x, y) in visible:
                row.append("W" if world.is_water(layout, border_at(x, y)) else "T")
            else:
                row.append(" ")
        print("%4d %s" % (y, "".join(row)))


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
    ap.add_argument("--show", metavar="MAP_NAME")
    args = ap.parse_args()
    world = World(args.root)
    if args.show:
        show(world, args.show)
        return 0

    flagged, failures = set(), []
    for map_id in sorted(world.maps):
        name = world.maps[map_id]["name"]
        for kind, region, water, open_land, blocked in world.findings(map_id)[0]:
            flagged.add(name)
            xs, ys = [c[0] for c in region], [c[1] for c in region]
            line = "%s: %s, %d cells x %d..%d y %d..%d (edge: %d sea, %d open, %d blocked)" % (
                name, kind, len(region), min(xs), max(xs), min(ys), max(ys), water, open_land, blocked)
            if name in KNOWN:
                print("known  " + line)
            else:
                failures.append(line)
                print("NEW    " + line)
    stale = sorted(set(KNOWN) - flagged)
    for name in stale:
        print("STALE  %s is in KNOWN but no longer flagged; remove it" % name)
    if failures or stale:
        print("FAIL: %d new border-terrain finding(s), %d stale KNOWN entr%s" % (
            len(failures), len(stale), "y" if len(stale) == 1 else "ies"))
        return 1
    print("PASS: border terrain (%d maps, %d known findings)" % (len(world.maps), len(flagged)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
