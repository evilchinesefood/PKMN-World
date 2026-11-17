#!/usr/bin/env python3
"""Check that Cut clears every grass metatile a map places, and generate the Kanto and Johto rules.

SetCutGrassMetatile (src/fldeff_cut.c) looks a cut grass metatile up in sCutGrassMetatiles, keyed on
the tileset that holds it: Hoenn's rows are written by hand there, and the Kanto and Johto rows are
generated into src/data/field_effects/cut_grass_metatiles.h by this script.

A grass metatile draws its grass on one layer and keeps the other: tall grass draws the blades on the
bottom layer under a tree top or roof overlay, and Route 38's wheat draws the wheat on the top layer
over the field. Cut must replace the grass layer with the ground it grows on and leave the other layer
exactly as it is. For each Kanto and Johto tileset (640 primary metatiles) the cut tile is, in order:
  1. pokefirered's own pair (sCutGrassMetatileMapping, keyed on metatile id), when it fits here.
     Kanto's and Johto's primaries share FRLG's general layout, so it covers both regions' plain grass;
  2. with the grass on the top layer: the metatile with the same bottom layer and nothing on top;
  3. with the grass on the bottom layer: the metatile with the same top layer whose bottom layer best
     matches the ground beside every placement of that tileset's grass sharing this overlay, among
     those drawn (90% of pixels or more) in that group's grass colours. Votes are pooled over that
     group, and the colour test drops the path or wall bordering a field, so an edge row of grass
     takes the same ground as the field it bounds.
If no metatile fits, --write adds one to the grass's tileset (appended, or written into a blank slot
no map places when the tileset is full).

This fails when:
  1. a map places a grass metatile (tall, long, ash or cycling road grass, or a long grass south
     edge) with no rule keyed on its own tileset;
  2. a rule's cut tile, drawn in a layout that places the grass, is missing, is still grass, has wild
     encounters, has the wrong behavior (plain ground, or the cycling road slope for its grass), or
     changes the layer the grass does not draw on;
  3. the generated header differs from what this script derives (run with --write).

Run from the repo root: python3 test/overworld/ValidateCutGrass.py [--write]
"""
import collections
import glob
import json
import os
import re
import struct
import sys

from ValidateBattleScenes import ROOT, png_pixels
from ValidateFrostyGrass import FRLG_SPLIT, behavior_names, cut_rules, read, read_pal, tilesets

HEADER = "src/data/field_effects/cut_grass_metatiles.h"
GRASS = {"MB_TALL_GRASS", "MB_LONG_GRASS", "MB_ASHGRASS", "MB_CYCLING_ROAD_PULL_DOWN_GRASS", "MB_LONG_GRASS_SOUTH_EDGE"}
GROUND_OF = {"MB_CYCLING_ROAD_PULL_DOWN_GRASS": "MB_CYCLING_ROAD_PULL_DOWN"}
# pokefirered src/fldeff_cut.c sCutGrassMetatileMapping (General, CeladonCity, FuchsiaCity, ViridianForest).
POKEFIRERED = {0x00D: 0x001, 0x00A: 0x013, 0x00B: 0x00E, 0x00C: 0x00F, 0x352: 0x33E,
               0x300: 0x310, 0x301: 0x311, 0x302: 0x312, 0x284: 0x281}
REGION = {"emerald": "Hoenn", "frlg": "Kanto", "johto": "Johto"}


def encounter_behaviors():
    body = read("src/metatile_behavior.c")
    return set(re.findall(r"\[(MB_\w+)\]\s*=[^,\n]*TILE_FLAG_HAS_ENCOUNTERS", body))


def read_bytes(path):
    return bytearray(open(path, "rb").read())


class Layout:
    """One map layout's two tilesets, able to draw any metatile id it can hold."""

    def __init__(self, data, sets, names, cache):
        self.id, self.version = data["id"], data["layout_version"]
        self.width, self.height = data["width"], data["height"]
        self.split, self.primary_pals = FRLG_SPLIT[self.version]
        self.tilesets = (data["primary_tileset"], data["secondary_tileset"])
        self.halves = [sets[n] for n in self.tilesets]
        self.names, self.cache = names, cache
        raw = open(os.path.join(ROOT, data["blockdata_filepath"]), "rb").read()
        self.blocks = [b & 0x3FF for (b,) in struct.iter_unpack("<H", raw)]

    def _file(self, path, loader):
        if (loader, path) not in self.cache:
            self.cache[(loader, path)] = loader(os.path.join(ROOT, path))
        return self.cache[(loader, path)]

    def tileset_of(self, metatile):
        return self.tilesets[int(metatile >= self.split)]

    def raw(self, half):
        _, _, mt_path, attr_path = self.halves[half]
        return self._file(mt_path, read_bytes), self._file(attr_path, read_bytes)

    def entry(self, metatile):
        """(behavior name, attributes, attribute width, 8 tile entries), or None past its tileset's end."""
        half = int(metatile >= self.split)
        mt, attrs = self.raw(half)
        local, width = metatile - self.split * half, len(attrs) * 16 // len(mt)
        if local * 16 >= len(mt):
            return None
        attr = int.from_bytes(attrs[local * width:(local + 1) * width], "little")
        behavior = self.names[attr & (0x1FF if width == 4 else 0xFF)]
        return behavior, attr, width, struct.unpack("<8H", mt[local * 16:local * 16 + 16])

    def layer(self, entries):
        """RGB pixels (None where transparent) of four tile entries drawn as one 16x16 layer."""
        out = []
        for ty in range(2):
            for y in range(8):
                for tx in range(2):
                    e = entries[ty * 2 + tx]
                    tile, hflip, vflip, bank = e & 0x3FF, e >> 10 & 1, e >> 11 & 1, e >> 12
                    rows = self._file(self.halves[int(tile >= self.split)][0], png_pixels)
                    pal = self._file(os.path.join(self.halves[int(bank >= self.primary_pals)][1], f"{bank:02d}.pal"), read_pal)
                    columns, local = len(rows[0]) // 8, tile % self.split
                    sy = local // columns * 8 + (7 - y if vflip else y)
                    for x in range(8):
                        sx = local % columns * 8 + (7 - x if hflip else x)
                        index = rows[sy][sx] & 15 if sy < len(rows) else 0
                        out.append(pal[index] if index else None)
        return tuple(out)

    def layers(self, metatile):
        key = ("layers", self.tilesets, self.split, metatile)
        if key not in self.cache:
            info = self.entry(metatile)
            self.cache[key] = None if info is None else (self.layer(info[3][:4]), self.layer(info[3][4:]))
        return self.cache[key]

    def ground_layers(self):
        """The bottom and top layers that metatiles other than grass draw."""
        key = ("ground", self.tilesets, self.split)
        if key not in self.cache:
            seen = (set(), set())
            for c in range(self.split + 1024):
                e = self.entry(c)
                if e and e[0] not in GRASS:
                    for k, layer in enumerate(self.layers(c)):
                        seen[k].add(layer)
            self.cache[key] = seen
        return self.cache[key]


def load_layouts():
    sets, names, cache = tilesets(), behavior_names(), {}
    placed = {json.load(open(p, encoding="utf-8"))["layout"] for p in glob.glob(os.path.join(ROOT, "data/maps/*/map.json"))}
    return [Layout(d, sets, names, cache) for d in json.loads(read("data/layouts/layouts.json"))["layouts"]
            if d.get("id") in placed and d.get("primary_tileset") in sets and d.get("secondary_tileset") in sets]


def placements(layouts):
    """{(tileset, grass metatile): [(layout, block index)]} for every grass metatile a map places."""
    out = collections.defaultdict(list)
    for L in layouts:
        for i, m in enumerate(L.blocks):
            e = L.entry(m)
            if e and e[0] in GRASS:
                out[(L.tileset_of(m), m)].append((L, i))
    return out


def quads(layer):
    return [tuple(layer[(qy * 8 + y) * 16 + qx * 8 + x] for y in range(8) for x in range(8)) for qy in range(2) for qx in range(2)]


def grass_layer(L, metatile):
    """0 when the grass is drawn on the bottom layer, 1 when on the top layer: the grass layer is the
    one no other metatile shares, and a bottom layer other metatiles draw too is ground."""
    bottom, top = L.layers(metatile)
    bottoms, tops = L.ground_layers()
    return 1 if bottom in bottoms and top not in tops and any(top) else 0


def ground_ok(L, grass, cut, gk, encounters=None):
    """Why cut cannot replace grass in layout L, or None when it can. Derived rules need plain ground
    (MB_NORMAL); a rule written by hand may name any ground without wild encounters."""
    g, c = L.entry(grass), L.entry(cut)
    if c is None:
        return f"metatile {cut:#x} does not exist"
    want = GROUND_OF.get(g[0], "MB_NORMAL")
    if encounters is None and c[0] != want:
        return f"metatile {cut:#x} is {c[0]}, not {want}"
    if c[0] in GRASS:
        return f"metatile {cut:#x} is still grass ({c[0]})"
    if encounters is not None and c[0] in encounters:
        return f"metatile {cut:#x} has wild encounters ({c[0]})"
    if g[0] in GROUND_OF and c[0] != want:
        return f"metatile {cut:#x} is {c[0]}, not {want}"
    keep = 1 - gk
    if L.layers(cut)[keep] != L.layers(grass)[keep]:
        return f"metatile {cut:#x} changes the {('bottom', 'top')[keep]} layer, which the grass does not draw on"
    if gk == 0 and None in L.layers(cut)[0]:
        return f"metatile {cut:#x} has holes in its bottom layer"
    if gk == 1 and any(L.layers(cut)[1]):
        return f"metatile {cut:#x} leaves something on the top layer"
    return None


def candidates(L, grass, gk):
    limit = L.split if grass < L.split else L.split + 1024
    return [c for c in range(limit) if ground_ok(L, grass, c, gk) is None]


def votes(group, gk):
    """Bottom (or top) layer 8x8 quarters of the non-grass metatiles beside a group's placements."""
    out = collections.Counter()
    for L, i in group:
        x, y = i % L.width, i // L.width
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if 0 <= x + dx < L.width and 0 <= y + dy < L.height:
                n = L.blocks[(y + dy) * L.width + x + dx]
                e = L.entry(n)
                if e and e[0] not in GRASS:
                    out.update(quads(L.layers(n)[gk]))
    return out


def derive(places, key):
    """(cut metatile or None, how, layout, grass layer, the metatile to add when None)."""
    tileset, grass = key
    L = places[key][0][0]
    gk = grass_layer(L, grass)
    cands = candidates(L, grass, gk)
    if L.split == 640 and POKEFIRERED.get(grass) in cands:
        return POKEFIRERED[grass], "pokefirered", L, gk, None
    entry = L.entry(grass)
    if gk == 1:
        if cands:
            return min(cands), "the field under it", L, gk, None
        return None, "the field under it", L, gk, entry[3][:4] + (0, 0, 0, 0)
    overlay = L.layers(grass)[1]
    members = [m for t, m in places if t == tileset and L.layers(m)[1] == overlay and grass_layer(L, m) == 0]
    tally = votes([p for m in members for p in places[(tileset, m)]], 0)
    colors = {p for m in members for p in L.layers(m)[0]} - {None}
    score = lambda c: sum(tally[q] for q in quads(L.layers(c)[0]))
    shade = lambda c: sum(p in colors for p in L.layers(c)[0])

    def pick(pool):
        pool = [c for c in pool if score(c) > 0]
        best = max(map(shade, pool), default=0)
        pool = [c for c in pool if shade(c) * 10 >= best * 9]
        return max(pool, key=lambda c: (score(c), shade(c), -c)) if pool else None

    cut = pick(cands)
    if cut is not None:
        return cut, "the ground beside it", L, gk, None
    limit = L.split if grass < L.split else L.split + 1024
    ground = pick([c for c in range(limit) if L.entry(c) and L.entry(c)[0] == "MB_NORMAL" and None not in L.layers(c)[0]])
    return None, "the ground beside it", L, gk, L.entry(ground)[3][:4] + entry[3][4:]


def add_metatile(L, grass, entries, layouts):
    """Write a plain ground metatile drawing entries into the grass's tileset; return its id."""
    half = int(grass >= L.split)
    mt, attrs = L.raw(half)
    width = len(attrs) * 16 // len(mt)
    _, attr, _, _ = L.entry(grass)
    layer_bits = attr & (0x60000000 if width == 4 else 0xF000)
    value = (layer_bits | L.names.index("MB_NORMAL")).to_bytes(width, "little")
    count, room = len(mt) // 16, (1024 - L.split) if half else L.split
    if count < room:
        local = count
        mt += struct.pack("<8H", *entries)
        attrs += value
    else:
        used = {m for other in layouts if L.tilesets[half] in other.tilesets for m in other.blocks}
        blank = [loc for loc in range(count) if loc + L.split * half not in used
                 and mt[loc * 16:loc * 16 + 16] == bytes(16)]
        if not blank:
            raise SystemExit(f"{L.tilesets[half]}: full, and no blank unplaced metatile to hold a cut tile")
        local = blank[0]
        mt[local * 16:local * 16 + 16] = struct.pack("<8H", *entries)
        attrs[local * width:(local + 1) * width] = value
    _, _, mt_path, attr_path = L.halves[half]
    open(os.path.join(ROOT, mt_path), "wb").write(mt)
    open(os.path.join(ROOT, attr_path), "wb").write(attrs)
    return local + L.split * half


def generate(places, layouts, write):
    """The generated rows [(tileset, grass, cut, how)], adding missing ground metatiles when writing."""
    rows = []
    for key in sorted(places):
        if places[key][0][0].split != 640:
            continue
        cut, how, L, gk, entries = derive(places, key)
        if cut is None and write:
            cut = add_metatile(L, key[1], entries, layouts)
        rows.append((key[0], key[1], cut, how))
    return rows


def render_header(rows):
    lines = ["// Generated by test/overworld/ValidateCutGrass.py --write from the Kanto and Johto tilesets. Do not edit.",
             "// Each row cuts a grass metatile to the ground it grows on (see the script for how).",
             "// Included inside sCutGrassMetatiles in src/fldeff_cut.c."]
    for tileset, grass, cut, how in rows:
        lines.append(f"{{&{tileset}, 0x{grass:03X}, 0x{cut:03X}}}, // {how}")
    return "\n".join(lines) + "\n"


def main():
    write = "--write" in sys.argv[1:]
    layouts = load_layouts()
    places = placements(layouts)
    encounters = encounter_behaviors()
    rows = generate(places, layouts, write)
    if write:
        layouts = load_layouts()
        places = placements(layouts)
        rows = generate(places, layouts, False)
        if any(r[2] is None for r in rows):
            raise SystemExit("a cut tile could not be derived")
        open(os.path.join(ROOT, HEADER), "w", encoding="ascii").write(render_header(rows))
    text = render_header(rows) if all(r[2] is not None for r in rows) else None
    rules = {(t, g): c for t, g, c in reversed(cut_rules())}
    bad, missing = [], collections.Counter()
    for (tileset, grass), pl in sorted(places.items()):
        layout_ids = sorted({L.id for L, _ in pl})
        where = f"{tileset} metatile {grass:#x} ({len(pl)} placed in {', '.join(layout_ids[:3])}{'...' if len(layout_ids) > 3 else ''})"
        primary = next(L for L, _ in pl).split > grass
        if (tileset, grass) not in rules and primary and (None, grass) in rules:
            rules[(tileset, grass)] = rules[(None, grass)]
        if (tileset, grass) not in rules:
            bad.append(f"{where}: Cut leaves it standing (no rule keyed on {tileset})")
            for L in {L for L, _ in pl}:
                missing[(REGION[L.version], L.id, grass)] += 1
            continue
        cut = rules[(tileset, grass)]
        problems = collections.defaultdict(list)
        for L in sorted({L for L, _ in pl}, key=lambda L: L.id):
            why = ground_ok(L, grass, cut, grass_layer(L, grass), encounters)
            if why:
                problems[why].append(L.id)
        for why, ids in problems.items():
            bad.append(f"{where}: {why} (in {len(ids)} layout(s), first {ids[0]})")
    current = open(os.path.join(ROOT, HEADER), encoding="ascii").read() if os.path.exists(os.path.join(ROOT, HEADER)) else ""
    if text != current:
        bad.append(f"{HEADER}: differs from the derived rules (run python3 test/overworld/ValidateCutGrass.py --write)")
    for line in bad:
        print("ERROR: " + line)
    regions = collections.Counter()
    for L, _ in [pl[0] for pl in places.values()]:
        regions[REGION[L.version]] += 1
    by_region = collections.Counter(r for r, _, _ in missing)
    print(f"ValidateCutGrass: {len(places)} placed grass metatiles ({', '.join(f'{n} {r}' for r, n in sorted(regions.items()))}), "
          f"{len(rows)} generated rules, {sum(by_region.values())} layout placements without a rule "
          f"({', '.join(f'{n} {r}' for r, n in sorted(by_region.items())) or 'none'}), {len(bad)} error(s)")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
