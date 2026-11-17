#!/usr/bin/env python3
"""Check that Cut leaves stubble on every grass metatile a map places, and generate the stubble.

SetCutGrassMetatile (src/fldeff_cut.c) looks a cut grass metatile up in sCutGrassMetatiles, keyed on
the tileset that holds it. Every row is generated into src/data/field_effects/cut_grass_metatiles.h
by this script, together with the stubble metatiles and tiles the rows name.

A grass metatile draws its grass on one layer and keeps the other: tall grass draws the blades on the
bottom layer under a tree top or roof overlay, and Route 38's wheat draws the wheat on the top layer
over the field. Cut turns it into stubble: the ground the grass grows on, with short stalks of that
grass left standing, and the other layer exactly as it was.

The ground is, in order:
  1. for wheat (grass on the top layer): the field under it;
  2. when the grass draws the same bottom layer as its tileset's plain tall grass (metatile 0x00D):
     the ground that plain grass is cut to;
  3. in Hoenn, pokeemerald's own pair (sCutGrassMetatiles);
  4. in Kanto and Johto, pokefirered's own pair (sCutGrassMetatileMapping) when it fits here, else the
     metatile with the same top layer whose bottom layer best matches the ground beside every
     placement of that tileset's grass sharing this overlay, among those drawn (90% of pixels or
     more) in that group's grass colours. Votes are pooled over that group, and the colour test drops
     the path or wall bordering a field.
The stubble is that ground with tufts of the grass's own pixels on it. A blade is a vertical run of
grass pixels, split where the colour turns lighter going down (the tip of the next blade below); a
blade of 3 pixels or more has its base at its lowest pixel. Bases are taken longest blade first,
darkest first, at least 5 pixels apart (the tile wraps, so a field of stubble keeps the spacing), and
each keeps the grass pixels of a tuft 3 pixels wide, 3 tall in the middle and 2 at the sides. Each
8x8 quarter is drawn with whichever of its ground's or grass's palettes holds its colours.

--write regenerates the header and the stubble art: it frees the stubble metatiles and tiles the
header's stubble rows name (any that only they use), keeping each one's slot when it is still needed, then writes each stubble metatile into its grass's tileset half,
reusing an identical tile where one exists and else a tile slot no metatile and no tileset animation
uses. Metatiles go into a blank slot no layout (used by a map or not), label or script of that tileset uses, else appended,
else into the last unplaced, unreferenced slot. Slot 0 of either half is never used.

This fails when:
  1. a map places a grass metatile (tall, long, ash or cycling road grass, or a long grass south
     edge), or the game places one at run time (Hoenn's ash-free grass), with no rule keyed on its
     own tileset;
  2. a rule's stubble tile, drawn in a layout that places the grass, is missing, outside the grass's
     tileset, still grass, has wild encounters, has the wrong behavior (plain ground, or the cycling
     road slope for its grass), changes the layer the grass does not draw on, shows no stubble, or
     differs from the recipe above;
  3. the header has a row the recipe does not derive.

Run from the repo root: python3 test/overworld/ValidateCutGrass.py [--write]
"""
import collections
import glob
import json
import os
import re
import struct
import sys
import zlib

from ValidateBattleScenes import ROOT, png_pixels
from ValidateFrostyGrass import FRLG_SPLIT, behavior_names, cut_rules, read, read_pal, tilesets

HEADER = "src/data/field_effects/cut_grass_metatiles.h"
GRASS = {"MB_TALL_GRASS", "MB_LONG_GRASS", "MB_ASHGRASS", "MB_CYCLING_ROAD_PULL_DOWN_GRASS", "MB_LONG_GRASS_SOUTH_EDGE"}
GROUND_OF = {"MB_CYCLING_ROAD_PULL_DOWN_GRASS": "MB_CYCLING_ROAD_PULL_DOWN"}
# pokefirered src/fldeff_cut.c sCutGrassMetatileMapping (General, CeladonCity, FuchsiaCity, ViridianForest).
POKEFIRERED = {0x00D: 0x001, 0x00A: 0x013, 0x00B: 0x00E, 0x00C: 0x00F, 0x352: 0x33E,
               0x300: 0x310, 0x301: 0x311, 0x302: 0x312, 0x284: 0x281}
# pokeemerald src/fldeff_cut.c sCutGrassMetatiles, keyed on the tileset that holds each grass. Ash-free
# grass (Fallarbor 0x212) is placed at run time where the player collects ash.
_GENERAL = {0x015: 0x001, 0x00D: 0x001, 0x1C6: 0x1CE, 0x1C7: 0x1CF, 0x025: 0x00E}
POKEEMERALD = {"gTileset_General": _GENERAL, "gTileset_GeneralNight": _GENERAL,
               "gTileset_Fortree": {0x208: 0x001, 0x281: 0x279, 0x282: 0x27A, 0x283: 0x27B},
               "gTileset_Lavaridge": {0x206: 0x271, 0x207: 0x271},
               "gTileset_Fallarbor": {0x212: 0x218, 0x20A: 0x218}}
PLAIN_GRASS = 0x00D
REGION = {"emerald": "Hoenn", "frlg": "Kanto", "johto": "Johto"}
BLADE_STEP, MIN_BLADE, TUFT_SPACING = 24, 3, 5
TUFT = ((-1, 2), (0, 3), (1, 2))


def encounter_behaviors():
    body = read("src/metatile_behavior.c")
    return set(re.findall(r"\[(MB_\w+)\]\s*=[^,\n]*TILE_FLAG_HAS_ENCOUNTERS", body))


def read_bytes(path):
    return bytearray(open(path, "rb").read())


def luma(color):
    return 0.299 * color[0] + 0.587 * color[1] + 0.114 * color[2]


class Layout:
    """One map layout's two tilesets, able to draw any metatile id it can hold."""

    def __init__(self, data, sets, names, cache):
        self.id, self.version = data["id"], data["layout_version"]
        self.width, self.height = data["width"], data["height"]
        self.split, self.primary_pals = FRLG_SPLIT[self.version]
        self.tilesets = (data["primary_tileset"], data["secondary_tileset"])
        self.halves = [sets[n] for n in self.tilesets]
        self.names, self.cache = names, cache
        unpack = lambda path: [b & 0x3FF for (b,) in struct.iter_unpack("<H", open(os.path.join(ROOT, path), "rb").read())]
        self.blocks = unpack(data["blockdata_filepath"])
        self.border = unpack(data["border_filepath"]) if os.path.exists(os.path.join(ROOT, data["border_filepath"])) else []

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

    def palette(self, bank):
        return self._file(os.path.join(self.halves[int(bank >= self.primary_pals)][1], f"{bank:02d}.pal"), read_pal)

    def layer(self, entries):
        """RGB pixels (None where transparent) of four tile entries drawn as one 16x16 layer."""
        out = []
        for ty in range(2):
            for y in range(8):
                for tx in range(2):
                    e = entries[ty * 2 + tx]
                    tile, hflip, vflip, bank = e & 0x3FF, e >> 10 & 1, e >> 11 & 1, e >> 12
                    rows = self._file(self.halves[int(tile >= self.split)][0], png_pixels)
                    pal = self.palette(bank)
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


def all_layouts():
    return json.loads(read("data/layouts/layouts.json"))["layouts"]


def load_layouts(every=False):
    """The layouts a map uses (every layout, even unused ones, with every=True)."""
    sets, names, cache = tilesets(), behavior_names(), {}
    placed = {json.load(open(p, encoding="utf-8"))["layout"] for p in glob.glob(os.path.join(ROOT, "data/maps/*/map.json"))}
    return [Layout(d, sets, names, cache) for d in all_layouts()
            if (every or d.get("id") in placed) and d.get("primary_tileset") in sets and d.get("secondary_tileset") in sets]


def placements(layouts):
    """{(tileset, grass metatile): [(layout, block index)]} for every grass metatile a map places."""
    out = collections.defaultdict(list)
    for L in layouts:
        for i, m in enumerate(L.blocks):
            e = L.entry(m)
            if e and e[0] in GRASS:
                out[(L.tileset_of(m), m)].append((L, i))
    return out


def grass_keys(layouts, places):
    """{(tileset, grass): a layout to draw it in}: every placed grass, and Hoenn's run-time grass."""
    keys = {key: pl[0][0] for key, pl in places.items()}
    for tileset, pairs in POKEEMERALD.items():
        L = next((L for L in layouts if tileset in L.tilesets), None)
        for grass in pairs:
            if L is not None and (tileset, grass) not in keys:
                keys[(tileset, grass)] = L
    return keys


def quads(layer):
    return [tuple(layer[(qy * 8 + y) * 16 + qx * 8 + x] for y in range(8) for x in range(8)) for qy in range(2) for qx in range(2)]


def grass_layer(L, metatile):
    """0 when the grass is drawn on the bottom layer, 1 when on the top layer: the grass layer is the
    one no other metatile shares, and a bottom layer other metatiles draw too is ground."""
    bottom, top = L.layers(metatile)
    bottoms, tops = L.ground_layers()
    return 1 if bottom in bottoms and top not in tops and any(top) else 0


def ground_ok(L, grass, cut, gk, encounters=None):
    """Why cut cannot stand for grass's ground in layout L, or None when it can. A ground or stubble
    tile is plain ground (MB_NORMAL, or the cycling road slope), keeps everything the top layer of
    bottom-layer grass shows (stubble may add stalks where it is clear), and has no holes in its
    bottom layer. Wheat's field is checked by the recipe."""
    g, c = L.entry(grass), L.entry(cut)
    if c is None:
        return f"metatile {cut:#x} does not exist"
    want = GROUND_OF.get(g[0], "MB_NORMAL")
    if c[0] in GRASS:
        return f"metatile {cut:#x} is still grass ({c[0]})"
    if encounters is not None and c[0] in encounters:
        return f"metatile {cut:#x} has wild encounters ({c[0]})"
    if c[0] != want:
        return f"metatile {cut:#x} is {c[0]}, not {want}"
    kept, shown = L.layers(grass)[1], L.layers(cut)[1]
    if gk == 0 and any(k is not None and k != c for k, c in zip(kept, shown)):
        return f"metatile {cut:#x} changes the top layer, which the grass does not draw on"
    if gk == 0 and encounters is None and shown != kept:
        return f"metatile {cut:#x} adds to the top layer"
    if None in L.layers(cut)[0]:
        return f"metatile {cut:#x} has holes in its bottom layer"
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


def derive_ground(places, key, L):
    """(the four bottom-layer tile entries of the ground a grass grows on, how it was found)."""
    tileset, grass = key
    gk = grass_layer(L, grass)
    entry = L.entry(grass)
    if gk == 1:
        return entry[3][:4], "the field under it"
    plain = L.entry(PLAIN_GRASS)
    if grass != PLAIN_GRASS and plain and plain[0] == "MB_TALL_GRASS" and L.layers(grass)[0] == L.layers(PLAIN_GRASS)[0]:
        ground, how = derive_ground(places, (L.tileset_of(PLAIN_GRASS), PLAIN_GRASS), L)
        return ground, "the ground plain grass grows on"
    if tileset in POKEEMERALD:
        return L.entry(POKEEMERALD[tileset][grass])[3][:4], "pokeemerald"
    cands = candidates(L, grass, gk)
    if POKEFIRERED.get(grass) in cands:
        return L.entry(POKEFIRERED[grass])[3][:4], "pokefirered"
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

    limit = L.split if grass < L.split else L.split + 1024
    cut = pick(cands) or pick([c for c in range(limit) if L.entry(c) and L.entry(c)[0] == "MB_NORMAL" and None not in L.layers(c)[0]])
    return L.entry(cut)[3][:4], "the ground beside it"


def stubble_pixels(grass_pixels, ground_pixels, blade):
    """The ground with tufts of the grass's own pixels left at its blade bases."""
    bases = []
    for x in range(16):
        run = []
        for y in range(17):
            on = y < 16 and blade[y * 16 + x]
            if run and (not on or luma(grass_pixels[y * 16 + x]) > luma(grass_pixels[(y - 1) * 16 + x]) + BLADE_STEP):
                if len(run) >= MIN_BLADE:
                    bases.append((-len(run), luma(grass_pixels[run[-1] * 16 + x]), x, run[-1]))
                run = []
            if on:
                run.append(y)
    tufts = []
    wrap = lambda a, b: min(abs(a - b), 16 - abs(a - b))
    for _, _, x, y in sorted(bases):
        if all(wrap(x, a) >= TUFT_SPACING or wrap(y, b) >= TUFT_SPACING for a, b in tufts):
            tufts.append((x, y))
    keep = {(y - k) * 16 + x + dx for x, y in tufts for dx, h in TUFT for k in range(h)
            if 0 <= x + dx < 16 and 0 <= y - k < 16 and blade[(y - k) * 16 + x + dx]}
    return tuple(grass_pixels[i] if i in keep else ground_pixels[i] for i in range(256)), len(keep)


def recipe(places, key, L):
    """What Cut leaves on a grass metatile: {"quarters": the eight 8x8 quarters (bottom layer, then
    top) as (colours, candidate palette banks, the entry kept when the colours are unchanged, its
    colours), "attr", "how", "visible" (stalk pixels left in sight)}. Stalks go on the bottom layer
    when its ground's or grass's palette holds their colours, else on the empty top layer, drawn under
    sprites (layer type COVERED)."""
    tileset, grass = key
    gk = grass_layer(L, grass)
    behavior, grass_attr, width, entries = L.entry(grass)
    ground, how = derive_ground(places, key, L)
    ground_px = L.layer(ground)
    bottom, top = L.layers(grass)
    if gk == 0:
        grass_px, blade, grass_entries = bottom, [bottom[i] != ground_px[i] for i in range(256)], entries[:4]
        top_entries, top_px = entries[4:], top
    else:
        grass_px, blade, grass_entries = tuple(t or b for t, b in zip(top, bottom)), [t is not None for t in top], entries[4:]
        top_entries, top_px = (0, 0, 0, 0), (None,) * 256
    px, _ = stubble_pixels(grass_px, ground_px, blade)
    banks = [(ground[i] >> 12, grass_entries[i] >> 12) for i in range(4)]
    kept = lambda layer, ents: [(q, (), ents[i], q) for i, q in enumerate(quads(layer))]
    on_bottom = [(q, banks[i], ground[i], g) for i, (q, g) in enumerate(zip(quads(px), quads(ground_px)))]
    exact = all(encode(L, q, b)[2] == 0 for q, b, _, g in on_bottom if q != g)
    layer_mask, covered = (0x60000000, 1 << 29) if width == 4 else (0xF000, 1 << 12)
    ground_behavior = L.names.index(GROUND_OF.get(behavior, "MB_NORMAL"))
    if exact or any(top_px):
        quarters = on_bottom + kept(top_px, top_entries)
        attr = (grass_attr & layer_mask if gk == 0 else 0) | ground_behavior
    else:
        stalks = tuple(p if p != g else None for p, g in zip(px, ground_px))
        quarters = kept(ground_px, ground) + [(q, (banks[i][1],), 0, (None,) * 64) for i, q in enumerate(quads(stalks))]
        attr = covered | ground_behavior
    visible = sum(1 for i in range(256) if px[i] != ground_px[i] and top_px[i] is None)
    return {"quarters": quarters, "attr": attr, "how": how, "visible": visible, "gk": gk}


def encode(L, pixels, banks):
    """(bank, 64 palette indices, worst channel error) drawing an 8x8 quarter's colours (None is
    transparent, index 0)."""
    best = None
    for bank in dict.fromkeys(banks):
        pal = L.palette(bank)
        indices, worst = [], 0
        for c in pixels:
            if c is None:
                indices.append(0)
                continue
            i = min(range(1, len(pal)), key=lambda i: sum((a - b) ** 2 for a, b in zip(pal[i], c)))
            indices.append(i)
            worst = max(worst, max(abs(a - b) for a, b in zip(pal[i], c)))
        if best is None or worst < best[2]:
            best = (bank, tuple(indices), worst)
    return best


def expected_layers(L, rec):
    """The bottom and top layers the stubble must draw (its quarters in the palettes that hold them)."""
    out = [[None] * 256, [None] * 256]
    for n, (pixels, banks, entry, unchanged) in enumerate(rec["quarters"]):
        q = n % 4
        if pixels == unchanged:
            drawn = quads(L.layer((entry,) * 4))[0]
        else:
            bank, indices, _ = encode(L, pixels, banks)
            pal = L.palette(bank)
            drawn = [pal[i] if i else None for i in indices]
        for i, c in enumerate(drawn):
            out[n // 4][(q // 2 * 8 + i // 8) * 16 + q % 2 * 8 + i % 8] = c
    return tuple(out[0]), tuple(out[1])


# --- writing the stubble art -------------------------------------------------------------------

def anim_tiles():
    """Absolute tile numbers a tileset animation writes (generously: 48 tiles where no count is given)."""
    text = read("src/tileset_anims.c")
    out = set()
    for expr, count in re.findall(r"TILE_OFFSET_4BPP\(([^()]*)\)\)\s*(?:,\s*(\d+)\s*\*\s*TILE_SIZE_4BPP)?", text):
        start = eval(expr.replace("NUM_TILES_IN_PRIMARY_FRLG", "640").replace("NUM_TILES_IN_PRIMARY", "512"))
        out.update(range(start, start + (int(count) if count else 48)))
    return out


def reserved_metatiles():
    """{tileset: metatile ids a label or a script names}: labels for the tileset their trailing or
    heading "// gTileset_X" comment names,
    and setmetatile numbers in a map's scripts for that map's tilesets (anywhere else, for all)."""
    out = collections.defaultdict(set)
    tileset = None
    for line in read("include/constants/metatile_labels.h").splitlines():
        heading = re.match(r"//\s*(gTileset_\w+)", line)
        tileset = heading.group(1) if heading else tileset
        label = re.match(r"#define METATILE_\w+\s+(0x[0-9A-Fa-f]+|\d+)\s*(?://\s*(gTileset_\w+))?", line)
        if label:
            out[label.group(2) or tileset].add(int(label.group(1), 0))
    layouts = {d.get("id"): d for d in all_layouts()}
    for path in glob.glob(os.path.join(ROOT, "data/**/*.inc"), recursive=True) + glob.glob(os.path.join(ROOT, "data/**/*.pory"), recursive=True):
        found = re.findall(r"setmetatile\s+[^,\n]+,\s*[^,\n]+,\s*(0[xX][0-9A-Fa-f]+|\d+)\b", open(path, encoding="utf-8", errors="replace").read())
        if not found:
            continue
        owner = os.path.join(os.path.dirname(path), "map.json")
        names = [None]
        if os.path.exists(owner):
            d = layouts.get(json.load(open(owner, encoding="utf-8"))["layout"], {})
            names = [d.get("primary_tileset"), d.get("secondary_tileset")]
        for name in names:
            out[name].update(int(v, 0) for v in found)
    return out


def png_write(path, rows):
    """Rewrite an indexed PNG's pixels (same width and depth, any height), keeping its other chunks."""
    full = os.path.join(ROOT, path)
    data = open(full, "rb").read()
    depth = data[24]
    pack = (lambda row: bytes(row)) if depth == 8 else (lambda row: bytes((row[i] << 4) | row[i + 1] for i in range(0, len(row), 2)))
    idat = zlib.compress(b"".join(b"\0" + pack(r) for r in rows), 9)
    out, pos, done = [data[:8]], 8, False
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        chunk = data[pos:pos + 12 + length]
        pos += 12 + length
        if kind == b"IHDR":
            body = chunk[8:12] + struct.pack(">I", len(rows)) + chunk[16:8 + length]
            chunk = struct.pack(">I", length) + b"IHDR" + body + struct.pack(">I", zlib.crc32(b"IHDR" + body))
        if kind == b"IDAT":
            if not done:
                out.append(struct.pack(">I", len(idat)) + b"IDAT" + idat + struct.pack(">I", zlib.crc32(b"IDAT" + idat)))
                done = True
            continue
        out.append(chunk)
    open(full, "wb").write(b"".join(out))


class Store:
    """The tiles, metatile slots and attributes that one half of a set of tilesets shares: General and
    GeneralNight share tiles and attributes and keep their own metatiles."""

    def __init__(self, names, half, split):
        sets = tilesets()
        self.names, self.half, self.split = names, half, split
        self.png, _, _, self.attr_path = sets[names[0]]
        self.mt_paths = sorted({sets[n][2] for n in names})
        self.rows = png_pixels(os.path.join(ROOT, self.png))
        self.columns = len(self.rows[0]) // 8
        self.count = self.columns * (len(self.rows) // 8)
        self.mts = {p: read_bytes(os.path.join(ROOT, p)) for p in self.mt_paths}
        self.attrs = read_bytes(os.path.join(ROOT, self.attr_path))
        self.width = len(self.attrs) * 16 // len(self.mts[self.mt_paths[0]])
        self.dirty = False

    def tile(self, t):
        x, y = t % self.columns * 8, t // self.columns * 8
        return tuple(self.rows[y + j][x + i] & 15 for j in range(8) for i in range(8))

    def set_tile(self, t, indices):
        x, y = t % self.columns * 8, t // self.columns * 8
        for i, v in enumerate(indices):
            self.rows[y + i // 8][x + i % 8] = v
        self.dirty = True

    def slots(self):
        return len(self.mts[self.mt_paths[0]]) // 16


def flips(indices):
    rows = [indices[r * 8:r * 8 + 8] for r in range(8)]
    return {(0, 0): indices, (1, 0): tuple(v for r in rows for v in r[::-1]),
            (0, 1): tuple(v for r in rows[::-1] for v in r), (1, 1): tuple(v for r in rows[::-1] for v in r[::-1])}


def write_art(keys, places, rules):
    """Write every stubble metatile and its tiles; return {(tileset, grass): (stubble id, how)}."""
    sets = tilesets()
    layouts_json = all_layouts()
    groups = collections.defaultdict(list)
    for name, (png, _, _, attr) in sets.items():
        groups[(png, attr)].append(name)
    store_of, stores = {}, {}
    for (tileset, grass), L in sorted(keys.items()):
        half = int(grass >= L.split)
        group = tuple(sorted(next(g for g in groups.values() if tileset in g)))
        if (group, half) not in stores:
            stores[(group, half)] = Store(list(group), half, L.split)
        store_of[(tileset, grass)] = stores[(group, half)]
    reserved = reserved_metatiles()
    animated = anim_tiles()
    placed = collections.defaultdict(set)
    for L in load_layouts(every=True):
        for n in L.tilesets:
            placed[n].update(L.blocks + L.border)

    def tile_refs(store, skip):
        """Local tile numbers any metatile of a tileset that can draw this store's tiles names, except
        the metatile slots in skip ({metatiles.bin path: slots}, the stubble being replaced)."""
        files = set(store.mt_paths)
        if store.half == 0:
            for d in layouts_json:
                if d.get("primary_tileset") in store.names and d.get("secondary_tileset") in sets:
                    files.add(sets[d["secondary_tileset"]][2])
        refs = set()
        for path in files:
            data = store.mts.get(path) or read_bytes(os.path.join(ROOT, path))
            for slot in range(len(data) // 16):
                if slot in skip.get(path, ()):
                    continue
                for e in struct.unpack("<8H", data[slot * 16:slot * 16 + 16]):
                    t = e & 0x3FF
                    if (t >= store.split) == bool(store.half):
                        refs.add(t - store.split * store.half)
        return refs

    header = open(os.path.join(ROOT, HEADER), encoding="ascii").read() if os.path.exists(os.path.join(ROOT, HEADER)) else ""
    stubble = {(t, int(g, 16)): int(c, 16) for t, g, c in re.findall(r"\{&(\w+), 0x(\w+), 0x(\w+)\}, // stubble", header)}
    owned = collections.defaultdict(set)
    for (tileset, grass), cut in stubble.items():
        if (tileset, grass) in store_of and cut not in reserved[tileset] | reserved[None] and cut not in placed[tileset]:
            store = store_of[(tileset, grass)]
            if (cut >= store.split) == bool(store.half):
                owned[id(store)].add(cut - store.split * store.half)
    skip = {path: owned[id(store)] for store in stores.values() for path in store.mt_paths}
    pools = {}
    for store in stores.values():
        mine = owned[id(store)]
        keep_refs = tile_refs(store, skip)
        old_refs = tile_refs(store, {}) - keep_refs
        for slot in mine:
            for data in store.mts.values():
                data[slot * 16:slot * 16 + 16] = bytes(16)
            store.attrs[slot * store.width:(slot + 1) * store.width] = bytes(store.width)
        previous = {store.tile(t): t for t in sorted(old_refs, reverse=True)}
        for t in old_refs:
            store.set_tile(t, (0,) * 64)
        base = store.split * store.half
        free_tiles = [t for t in range(store.count) if t not in keep_refs and t + base not in animated]
        free_tiles.sort(key=lambda t: (any(store.tile(t)), t))
        used = {m - base for n in store.names + [None] for m in placed[n] | reserved[n]}
        blank = lambda s: all(d[s * 16:s * 16 + 16] == bytes(16) for d in store.mts.values())
        room = (1024 - store.split) if store.half else store.split
        slots = [s for s in range(1, store.slots()) if s not in used and blank(s)]
        slots += [s for s in range(store.slots(), room) if s not in used]
        slots += [s for s in range(store.slots() - 1, 0, -1) if s not in used and not blank(s)]
        index = {}
        for t in range(store.count):
            if t in keep_refs:
                for (h, v), form in flips(store.tile(t)).items():
                    index.setdefault(form, (t, h, v))
        pools[id(store)] = {"tiles": free_tiles, "slots": slots, "index": index, "shared": None,
                            "previous": previous, "owned": mine}
        if "-v" in sys.argv:
            print(f"{'/'.join(store.names)} half {store.half}: {len(free_tiles)} free tiles, {len(slots)} free metatile slots")

    for store in stores.values():
        primaries = {d["primary_tileset"] for d in layouts_json if d.get("secondary_tileset") in store.names}
        owners = {s for s in stores.values() if s.half == 0 and primaries <= set(s.names)}
        if store.half == 1 and len(owners) == 1:
            pools[id(store)]["shared"] = owners.pop()

    def find(store, indices):
        """(tile entry bits) of an existing tile drawing indices, in this half or, for a secondary
        whose layouts all share one primary, in that primary."""
        if indices in pools[id(store)]["index"]:
            t, h, v = pools[id(store)]["index"][indices]
            return (t + store.split * store.half) | h << 10 | v << 11
        shared = pools[id(store)]["shared"]
        if shared is not None and indices in pools[id(shared)]["index"]:
            t, h, v = pools[id(shared)]["index"][indices]
            return t | h << 10 | v << 11
        return None

    out = {}
    by_slot = collections.defaultdict(dict)
    for key in sorted(keys, key=lambda k: (int(k[1] >= keys[k].split), k)):
        tileset, grass = key
        L, store = keys[key], store_of[key]
        pool = pools[id(store)]
        rec = recipe(places, key, L)
        entries = []
        for pixels, banks, kept, unchanged in rec["quarters"]:
            if pixels == unchanged:
                entries.append(kept)
                continue
            bank, indices, _ = encode(L, pixels, banks)
            if find(store, indices) is None:
                if not pool["tiles"] and store.count + store.columns <= (1024 - store.split if store.half else store.split):
                    store.rows += [[0] * (store.columns * 8) for _ in range(8)]
                    pool["tiles"] += list(range(store.count, store.count + store.columns))
                    store.count += store.columns
                if not pool["tiles"]:
                    raise SystemExit(f"{'/'.join(store.names)}: no free tile slot left for {key[0]} {key[1]:#x}'s stubble")
                t = pool["previous"].get(indices)
                t = t if t in pool["tiles"] else pool["tiles"][0]
                pool["tiles"].remove(t)
                store.set_tile(t, indices)
                for (h, v), form in flips(indices).items():
                    pool["index"].setdefault(form, (t, h, v))
            entries.append(find(store, indices) | bank << 12)
        entries = tuple(entries)
        group_key = (id(store), grass)
        if group_key not in by_slot:
            if not pool["slots"]:
                raise SystemExit(f"{'/'.join(store.names)}: no free metatile slot left for {key[0]} {key[1]:#x}'s stubble")
            had = rules.get(key, -1) - store.split * store.half
            slot = had if had in pool["owned"] and had in pool["slots"] else pool["slots"][0]
            pool["slots"].remove(slot)
            by_slot[group_key]["slot"] = slot
        slot = by_slot[group_key]["slot"]
        by_slot[group_key][sets[tileset][2]] = entries
        if len(store.attrs) < (slot + 1) * store.width:
            store.attrs.extend(bytes((slot + 1) * store.width - len(store.attrs)))
        store.attrs[slot * store.width:(slot + 1) * store.width] = rec["attr"].to_bytes(store.width, "little")
        out[key] = (slot + store.split * store.half, rec["how"])
        by_slot[group_key]["store"] = store
    for group_key, info in by_slot.items():
        store, slot = info["store"], info["slot"]
        written = [p for p in store.mt_paths if p in info]
        for path in store.mt_paths:
            data = store.mts[path]
            if len(data) < (slot + 1) * 16:
                data.extend(bytes((slot + 1) * 16 - len(data)))
            data[slot * 16:slot * 16 + 16] = struct.pack("<8H", *info[path if path in info else written[0]])
    for store in stores.values():
        for path, data in store.mts.items():
            open(os.path.join(ROOT, path), "wb").write(data)
        open(os.path.join(ROOT, store.attr_path), "wb").write(store.attrs)
        if store.dirty:
            png_write(store.png, store.rows)
    return out


def render_header(rows):
    lines = ["// Generated by test/overworld/ValidateCutGrass.py --write from every region's tilesets. Do not edit.",
             "// Each row cuts a grass metatile to its stubble: the ground it grows on with short stalks left",
             "// standing (see the script for the recipe). Included inside sCutGrassMetatiles in src/fldeff_cut.c."]
    for (tileset, grass), (cut, how) in sorted(rows.items()):
        lines.append(f"{{&{tileset}, 0x{grass:03X}, 0x{cut:03X}}}, // stubble on {how}")
    return "\n".join(lines) + "\n"


def main():
    write = "--write" in sys.argv[1:]
    layouts = load_layouts()
    places = placements(layouts)
    keys = grass_keys(layouts, places)
    rules = {(t, g): c for t, g, c in reversed(cut_rules())}
    if write:
        rows = write_art(keys, places, rules)
        open(os.path.join(ROOT, HEADER), "w", encoding="ascii").write(render_header(rows))
        layouts = load_layouts()
        places = placements(layouts)
        keys = grass_keys(layouts, places)
        rules = {(t, g): c for t, g, c in reversed(cut_rules())}
    encounters = encounter_behaviors()
    bad, missing, worst = [], collections.Counter(), 0
    hows = {}
    for (tileset, grass), L in sorted(keys.items()):
        pl = places.get((tileset, grass), [])
        layout_ids = sorted({L.id for L, _ in pl}) or [L.id + " (placed at run time)"]
        where = f"{tileset} metatile {grass:#x} ({len(pl)} placed in {', '.join(layout_ids[:3])}{'...' if len(layout_ids) > 3 else ''})"
        if (tileset, grass) not in rules:
            bad.append(f"{where}: Cut leaves it standing (no rule keyed on {tileset})")
            for L2 in {L2 for L2, _ in pl}:
                missing[(REGION[L2.version], L2.id, grass)] += 1
            continue
        cut = rules[(tileset, grass)]
        if (cut >= L.split) != (grass >= L.split):
            bad.append(f"{where}: its stubble {cut:#x} is outside {tileset}")
            continue
        rec = recipe(places, (tileset, grass), L)
        hows[(tileset, grass)] = (cut, rec["how"])
        colour_error = max([encode(L, p, b)[2] for p, b, _, u in rec["quarters"] if p != u], default=0)
        worst = max(worst, colour_error)
        blank_top = all(c is None for c in L.layer((0, 0, 0, 0)))
        problems = collections.defaultdict(list)
        for L2 in sorted({L2 for L2, _ in pl} or {L}, key=lambda L2: L2.id):
            gk = grass_layer(L2, grass)
            why = ground_ok(L2, grass, cut, gk, encounters)
            if why is None and colour_error:
                why = f"its stalks need colours no palette of its quarters holds (off by {colour_error})"
            if why is None and not blank_top and any(e == 0 and u == (None,) * 64 for _, _, e, u in rec["quarters"]):
                why = "tile 0 is not blank, so it cannot stand for the empty top layer"
            if why is None and rec["visible"] == 0:
                why = f"metatile {cut:#x} shows no stubble, only bare ground"
            if why is None and L2.layers(cut) != expected_layers(L2, rec):
                why = f"metatile {cut:#x} differs from the stubble recipe (run with --write)"
            if why is None and L2.entry(cut)[1] != rec["attr"]:
                why = f"metatile {cut:#x} has attributes {L2.entry(cut)[1]:#x}, not {rec['attr']:#x}"
            if why:
                problems[why].append(L2.id)
        for why, ids in problems.items():
            bad.append(f"{where}: {why} (in {len(ids)} layout(s), first {ids[0]})")
    for key in sorted(set(rules) - set(keys)):
        bad.append(f"{key[0]} metatile {key[1]:#x}: a Cut rule for a grass no map places")
    current = open(os.path.join(ROOT, HEADER), encoding="ascii").read() if os.path.exists(os.path.join(ROOT, HEADER)) else ""
    if not missing and len(hows) == len(keys) and render_header(hows) != current:
        bad.append(f"{HEADER}: differs from the derived rules (run python3 test/overworld/ValidateCutGrass.py --write)")
    for line in bad:
        print("ERROR: " + line)
    regions = collections.Counter(REGION[L.version] for L in keys.values())
    by_region = collections.Counter(r for r, _, _ in missing)
    print(f"ValidateCutGrass: {len(keys)} grass metatiles ({', '.join(f'{n} {r}' for r, n in sorted(regions.items()))}), "
          f"{len(rules)} rules, {sum(by_region.values())} layout placements without a rule "
          f"({', '.join(f'{n} {r}' for r, n in sorted(by_region.items())) or 'none'}), worst palette error {worst}, {len(bad)} error(s)")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
