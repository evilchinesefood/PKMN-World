#!/usr/bin/env python3
"""Find every "dead animated door" in the tree.

A warp event standing on a metatile whose behavior is MB_ANIMATED_DOOR, but for
which sDoorAnimGraphicsTable (src/field_door.c) has no row the game could match,
is a dead door: the player warps straight through with no door animation.

The matching rule is lifted verbatim from GetDoorGraphics() in src/field_door.c:

    if (gfx->metatileNum == metatileNum
     && (gfx->tileset == gMapHeader.mapLayout->primaryTileset
      || gfx->tileset == gMapHeader.mapLayout->secondaryTileset))

so a row matches on the GLOBAL metatile id (what MapGridGetMetatileIdAt returns,
0..1023) and on the tileset POINTER being either half of the layout's pair.

Everything this script needs is derived from the tree, never assumed:

  * the map-grid bit layout, from include/global.fieldmap.h
  * the metatile-attribute width and behavior mask, per TILESET, from the actual
    sizes of metatiles.bin / metatile_attributes.bin -- exactly what the
    TILESET_METATILES macro does with sizeof()
  * the primary metatile count (512 Emerald / 640 FRLG+Johto), from
    GetNumMetatilesInPrimary() in src/fieldmap.c crossed with the layout_version
    -> isFrlg/isJohto mapping that tools/mapjson/mapjson.cpp emits
  * MB_ANIMATED_DOOR's numeric value, by counting the enum in
    include/constants/metatile_behaviors.h

Usage:
    python3 Testing/ValidateDoorAnims.py [--max N] [--root DIR] [--verbose]

Exit code is always 0 (this is a report, not a gate) unless --max N is given, in
which case it exits 1 when the dead count exceeds N.
"""

import argparse
import json
import os
import re
import struct
import sys
from collections import Counter, defaultdict

# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

# Warps whose metatile behavior cannot be read AT ALL, because the layout paints a metatile
# id past the end of the tileset actually wired to it. Two separate pre-existing authoring
# bugs, neither of them about doors: JohtoVictoryRoad_1F/B1F/B2F are tagged
# layout_version "johto" (which makes GetNumMetatilesInPrimary use the 640 split) while
# their primary is the 512-metatile gTileset_General, so ids 512-639 run off the end of it;
# and Route28 / Route34_DayCare paint secondary ids past the end of gTileset_ViridianCity
# (95 entries) and gTileset_PokemonDayCare (68 entries). The engine does the same unbounded
# read -- GetAttributeByMetatileIdAndMapLayout and DrawMetatileAt both index
# tileset->metatileAttributes[] / ->metatiles[] with no bounds check -- so these tiles draw
# and behave as whatever .rodata happens to follow the array. On the current build none of
# them lands on MB_ANIMATED_DOOR, which is why the dead count is a true zero today; but that
# is an accident of link order, not a design fact, so the number is pinned rather than
# ignored. Tracked separately from the door work.
UNRESOLVED_BASELINE = 18

BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.S)
LINE_COMMENT = re.compile(r"//[^\n]*")


def strip_c_comments(text):
    return LINE_COMMENT.sub("", BLOCK_COMMENT.sub("", text))


def read_text(path):
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        return fh.read()


def read_bytes(path):
    with open(path, "rb") as fh:
        return fh.read()


class Fatal(Exception):
    pass


# ---------------------------------------------------------------------------
# 1. Constants pulled out of headers
# ---------------------------------------------------------------------------


def parse_define_ints(path, prefix):
    """Parse `#define <PREFIX>Foo 0x123` style constants."""
    out = {}
    pat = re.compile(
        r"^\s*#define\s+(" + re.escape(prefix) + r"\w+)\s+"
        r"\(?\s*(0[xX][0-9A-Fa-f]+|\d+)\s*\)?\s*$"
    )
    for line in read_text(path).splitlines():
        line = LINE_COMMENT.sub("", line)
        m = pat.match(line)
        if m:
            out[m.group(1)] = int(m.group(2), 0)
    return out


def parse_mapgrid_masks(root):
    """MAPGRID_* masks/shifts from include/global.fieldmap.h -- do not assume 0-9."""
    path = os.path.join(root, "include", "global.fieldmap.h")
    d = parse_define_ints(path, "MAPGRID_")
    for key in ("MAPGRID_METATILE_ID_MASK", "MAPGRID_METATILE_ID_SHIFT"):
        if key not in d:
            raise Fatal("could not find %s in %s" % (key, path))
    return d["MAPGRID_METATILE_ID_MASK"], d["MAPGRID_METATILE_ID_SHIFT"]


def parse_attr_masks(root):
    """METATILE_ATTR_BEHAVIOR_* masks/shifts, Emerald (u16) and FRLG (u32)."""
    path = os.path.join(root, "include", "global.fieldmap.h")
    d = parse_define_ints(path, "METATILE_ATTR_")
    need = (
        "METATILE_ATTR_BEHAVIOR_MASK",
        "METATILE_ATTR_BEHAVIOR_SHIFT",
        "METATILE_ATTR_BEHAVIOR_MASK_FRLG",
        "METATILE_ATTR_BEHAVIOR_SHIFT_FRLG",
    )
    for key in need:
        if key not in d:
            raise Fatal("could not find %s in %s" % (key, path))
    return {
        2: (d["METATILE_ATTR_BEHAVIOR_MASK"], d["METATILE_ATTR_BEHAVIOR_SHIFT"]),
        4: (d["METATILE_ATTR_BEHAVIOR_MASK_FRLG"], d["METATILE_ATTR_BEHAVIOR_SHIFT_FRLG"]),
    }


def parse_primary_counts(root):
    """NUM_METATILES_IN_PRIMARY / _FRLG plus NUM_METATILES_TOTAL from include/fieldmap.h."""
    path = os.path.join(root, "include", "fieldmap.h")
    d = parse_define_ints(path, "NUM_METATILES_")
    need = ("NUM_METATILES_IN_PRIMARY", "NUM_METATILES_IN_PRIMARY_FRLG", "NUM_METATILES_TOTAL")
    for key in need:
        if key not in d:
            raise Fatal("could not find %s in %s" % (key, path))
    return (
        d["NUM_METATILES_IN_PRIMARY"],
        d["NUM_METATILES_IN_PRIMARY_FRLG"],
        d["NUM_METATILES_TOTAL"],
    )


def parse_map_offset(root):
    """MAP_OFFSET from include/fieldmap.h -- how deep a connected map's fringe is copied into
    gBackupMapLayout, and therefore how much of a neighbour can be on screen."""
    path = os.path.join(root, "include", "fieldmap.h")
    d = parse_define_ints(path, "MAP_")
    if "MAP_OFFSET" not in d:
        raise Fatal("could not find MAP_OFFSET in %s" % path)
    return d["MAP_OFFSET"]


def parse_tile_total(root):
    """NUM_TILES_TOTAL from include/fieldmap.h. The door scratch window is defined off it
    (DOOR_TILE_START_SIZE1/2 = NUM_TILES_TOTAL - 8 / - 16), so it is read, never assumed."""
    path = os.path.join(root, "include", "fieldmap.h")
    d = parse_define_ints(path, "NUM_TILES_")
    if "NUM_TILES_TOTAL" not in d:
        raise Fatal("could not find NUM_TILES_TOTAL in %s" % path)
    return d["NUM_TILES_TOTAL"]


def parse_behavior_enum(root):
    """Number the MB_* enum in include/constants/metatile_behaviors.h."""
    path = os.path.join(root, "include", "constants", "metatile_behaviors.h")
    text = strip_c_comments(read_text(path))
    m = re.search(r"enum\s*\{(.*?)\}\s*;", text, re.S)
    if not m:
        raise Fatal("could not find the MB_ enum in %s" % path)
    values = {}
    counter = 0
    for entry in m.group(1).split(","):
        entry = entry.strip()
        if not entry:
            continue
        if "=" in entry:
            name, val = entry.split("=", 1)
            counter = int(val.strip(), 0)
            name = name.strip()
        else:
            name = entry
        values[name] = counter
        counter += 1
    if "MB_ANIMATED_DOOR" not in values:
        raise Fatal("MB_ANIMATED_DOOR not found in %s" % path)
    return values


def parse_metatile_labels(root):
    """METATILE_* macros from include/constants/metatile_labels.h."""
    path = os.path.join(root, "include", "constants", "metatile_labels.h")
    labels = parse_define_ints(path, "METATILE_")
    if not labels:
        raise Fatal("no METATILE_* labels parsed from %s" % path)
    return labels


# ---------------------------------------------------------------------------
# 2. Tilesets: symbol -> binaries, and the attribute width the game will use
# ---------------------------------------------------------------------------


def parse_tilesets(root):
    """Map gTileset_* -> {metatiles/attributes paths, bytes-per-attr, metatile count}.

    src/data/tilesets/headers.h ties each tileset symbol to a pair of data symbols
    via TILESET_METATILES(mt, attrs); src/data/tilesets/metatiles.h ties those data
    symbols to .bin files. hasFrlgAttributes is then derived exactly the way the
    TILESET_METATILES macro derives it: sizeof(attrs) * 16 / sizeof(mt) == 4.
    """
    metatiles_h = os.path.join(root, "src", "data", "tilesets", "metatiles.h")
    headers_h = os.path.join(root, "src", "data", "tilesets", "headers.h")

    sym_to_path = {}
    incbin = re.compile(r"\b(g\w+)\s*\[\s*\]\s*=\s*INCBIN_\w+\(\s*\"([^\"]+)\"")
    for sym, path in incbin.findall(strip_c_comments(read_text(metatiles_h))):
        sym_to_path[sym] = path

    tilesets = {}
    text = strip_c_comments(read_text(headers_h))
    decl = re.compile(
        r"const\s+struct\s+Tileset\s+(gTileset_\w+)\s*=\s*\{(.*?)\}\s*;", re.S
    )
    for name, body in decl.findall(text):
        m = re.search(r"TILESET_METATILES\s*\(\s*(\w+)\s*,\s*(\w+)\s*\)", body)
        if not m:
            continue
        mt_sym, attr_sym = m.group(1), m.group(2)
        mt_rel = sym_to_path.get(mt_sym)
        attr_rel = sym_to_path.get(attr_sym)
        if mt_rel is None or attr_rel is None:
            tilesets[name] = {"error": "no INCBIN for %s / %s" % (mt_sym, attr_sym)}
            continue
        mt_abs = os.path.join(root, mt_rel)
        attr_abs = os.path.join(root, attr_rel)
        if not os.path.exists(mt_abs) or not os.path.exists(attr_abs):
            tilesets[name] = {"error": "missing binary %s or %s" % (mt_rel, attr_rel)}
            continue
        mt_size = os.path.getsize(mt_abs)
        attr_size = os.path.getsize(attr_abs)
        if mt_size == 0:
            tilesets[name] = {"error": "empty metatiles.bin %s" % mt_rel}
            continue
        # metatiles.bin is 16 bytes per metatile (NUM_TILES_PER_METATILE * 2).
        num_metatiles = mt_size // 16
        bytes_per_attr = (attr_size * 16) // mt_size
        tilesets[name] = {
            "metatiles_path": mt_rel,
            "metatiles_abs": mt_abs,
            "attributes_path": attr_rel,
            "attributes_abs": attr_abs,
            "num_metatiles": num_metatiles,
            "bytes_per_attr": bytes_per_attr,
            "has_frlg_attributes": bytes_per_attr == 4,
            "attr_bytes": attr_size,
            "error": None,
        }
    if not tilesets:
        raise Fatal("no tilesets parsed from %s" % headers_h)
    return tilesets


class AttributeReader:
    """Decodes metatile behaviors, caching each metatile_attributes.bin."""

    def __init__(self, root, tilesets, attr_masks):
        self.root = root
        self.tilesets = tilesets
        self.attr_masks = attr_masks
        self._cache = {}

    def _blob(self, tileset_name):
        if tileset_name not in self._cache:
            self._cache[tileset_name] = read_bytes(
                self.tilesets[tileset_name]["attributes_abs"]
            )
        return self._cache[tileset_name]

    def behavior(self, tileset_name, local_index):
        """Return (behavior, None) or (None, reason)."""
        ts = self.tilesets.get(tileset_name)
        if ts is None:
            return None, "unknown tileset %s" % tileset_name
        if ts.get("error"):
            return None, ts["error"]
        width = ts["bytes_per_attr"]
        if width not in self.attr_masks:
            return None, "unhandled attribute width %d bytes" % width
        blob = self._blob(tileset_name)
        off = local_index * width
        if off + width > len(blob):
            return None, "metatile %d past end of %s (%d entries)" % (
                local_index,
                ts["attributes_path"],
                len(blob) // width,
            )
        value = int.from_bytes(blob[off:off + width], "little")
        mask, shift = self.attr_masks[width]
        return (value & mask) >> shift, None


# ---------------------------------------------------------------------------
# 3. sDoorAnimGraphicsTable
# ---------------------------------------------------------------------------


def parse_door_table(root, labels):
    path = os.path.join(root, "src", "field_door.c")
    text = read_text(path)
    m = re.search(r"sDoorAnimGraphicsTable\s*\[\s*\]\s*=\s*\{", text)
    if not m:
        raise Fatal("sDoorAnimGraphicsTable not found in %s" % path)
    # Walk braces from the opening one to find the table body.
    start = text.index("{", m.end() - 1)
    depth = 0
    end = None
    for i in range(start, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                end = i
                break
    if end is None:
        raise Fatal("unterminated sDoorAnimGraphicsTable in %s" % path)
    body = strip_c_comments(text[start + 1:end])

    # `size` is captured because it, together with the LAYOUT's isFrlg/isJohto, decides how much
    # VRAM the animation borrows: CopyDoorTilesToVram writes 16 tiles at NUM_TILES_TOTAL-16 for a
    # size-2 row on a non-FRLG, non-Johto layout, and 8 tiles at NUM_TILES_TOTAL-8 otherwise.
    row_re = re.compile(
        r"\{\s*(?P<mt>[A-Za-z_]\w*|0[xX][0-9A-Fa-f]+|\d+)\s*,"
        r"\s*(?P<ts>&\s*\w+|NULL)\s*,"
        r"(?:\s*(?P<sound>\w+)\s*,\s*(?P<size>\d+)\s*,)?"
    )
    # GetDoorGraphics walks the table with `while (gfx->tiles != NULL)`, so the
    # FIRST row with no tiles ends it. In the source that row is the bare `{}`
    # terminator. Anything written after it is dead weight the game never reads --
    # and "append your row at the end of the table" puts it exactly there, which
    # is the single most likely way a future fix silently does nothing. Truncate
    # the body at the terminator so this script sees what the game sees.
    term = re.search(r"\{\s*\}\s*,", body)
    if not term:
        raise Fatal(
            "no `{}` terminator found in sDoorAnimGraphicsTable -- "
            "GetDoorGraphics would run off the end of the table"
        )
    ignored_tail = body[term.end():]
    ignored_rows = len(row_re.findall(ignored_tail))
    body = body[:term.start()]

    rows = []
    sizes = {}
    unresolved = []
    null_tileset_rows = []
    for m2 in row_re.finditer(body):
        raw_mt = m2.group("mt")
        if raw_mt.startswith("0x") or raw_mt.startswith("0X") or raw_mt.isdigit():
            mt = int(raw_mt, 0)
        elif raw_mt in labels:
            mt = labels[raw_mt]
        else:
            unresolved.append(raw_mt)
            continue
        raw_ts = m2.group("ts").replace("&", "").strip()
        if raw_ts == "NULL":
            # A NULL tileset can never equal a real layout's primary/secondary
            # pointer, so this row is unreachable. Excluded from matching.
            null_tileset_rows.append((raw_mt, mt))
            continue
        rows.append((mt, raw_ts, raw_mt))
        # No size parsed means the row shape changed; assume the WIDER window rather than
        # silently checking too little.
        raw_size = m2.group("size")
        sz = int(raw_size) if raw_size is not None else 2
        sizes[(mt, raw_ts)] = max(sz, sizes.get((mt, raw_ts), 0))
    if unresolved:
        raise Fatal(
            "unresolved metatile symbols in sDoorAnimGraphicsTable: %s"
            % ", ".join(sorted(set(unresolved)))
        )
    if not rows:
        raise Fatal("parsed zero usable rows from sDoorAnimGraphicsTable")
    if ignored_rows:
        raise Fatal(
            "%d row(s) appear AFTER the `{}` terminator of sDoorAnimGraphicsTable. "
            "GetDoorGraphics stops at the terminator, so those rows are never read "
            "and their doors will not animate. Move them above the terminator."
            % ignored_rows
        )
    index = defaultdict(set)
    for mt, ts, _raw in rows:
        index[mt].add(ts)
    return rows, dict(index), null_tileset_rows, sizes


# ---------------------------------------------------------------------------
# 4. Layouts and maps
# ---------------------------------------------------------------------------

# tools/mapjson/mapjson.cpp: layout_version "frlg" -> isFrlg = TRUE,
# "johto" -> isJohto = TRUE, anything else -> both FALSE.
# src/fieldmap.c GetNumMetatilesInPrimary(): (isFrlg || isJohto) ? 640 : 512.
FRLG_VERSIONS = {"frlg"}
JOHTO_VERSIONS = {"johto"}
EMERALD_VERSIONS = {"emerald"}
VALID_VERSIONS = FRLG_VERSIONS | JOHTO_VERSIONS | EMERALD_VERSIONS


def parse_layouts(root, num_primary_emerald, num_primary_frlg):
    path = os.path.join(root, "data", "layouts", "layouts.json")
    data = json.load(open(path, "r", encoding="utf-8"))
    layouts = {}
    for entry in data.get("layouts", []):
        if not entry:
            continue
        version = (entry.get("layout_version") or "emerald").strip()
        # mapjson.cpp matches these EXACTLY (case-sensitively). A near-miss like
        # "Johto" would silently fall through to the 512 split here and mis-resolve
        # every secondary metatile in that layout, which shows up as doors quietly
        # becoming unresolvable -- i.e. as a LOWER dead count. Refuse instead.
        if version not in VALID_VERSIONS:
            raise Fatal("layout %s has unknown layout_version %r (expected one of %s)"
                        % (entry.get("name", entry.get("id")), version,
                           ", ".join(sorted(VALID_VERSIONS))))
        is_frlg = version in FRLG_VERSIONS
        is_johto = version in JOHTO_VERSIONS
        layouts[entry["id"]] = {
            "id": entry["id"],
            "name": entry.get("name", entry["id"]),
            "width": int(entry["width"]),
            "height": int(entry["height"]),
            "primary": entry.get("primary_tileset"),
            "secondary": entry.get("secondary_tileset"),
            "blockdata": entry.get("blockdata_filepath"),
            "border": entry.get("border_filepath"),
            "version": version,
            "is_frlg": is_frlg,
            "is_johto": is_johto,
            "num_primary": num_primary_frlg if (is_frlg or is_johto) else num_primary_emerald,
        }
    if not layouts:
        raise Fatal("no layouts parsed from %s" % path)
    return layouts


def parse_maps(root):
    maps_dir = os.path.join(root, "data", "maps")
    maps = []
    for name in sorted(os.listdir(maps_dir)):
        path = os.path.join(maps_dir, name, "map.json")
        if not os.path.isfile(path):
            continue
        try:
            data = json.load(open(path, "r", encoding="utf-8"))
        except ValueError as exc:
            raise Fatal("could not parse %s: %s" % (path, exc))
        maps.append(
            {
                "dir": name,
                "path": path,
                "name": data.get("name", name),
                "id": data.get("id", ""),
                "layout": data.get("layout"),
                "warps": data.get("warp_events") or [],
                "connections": data.get("connections") or [],
            }
        )
    if not maps:
        raise Fatal("no maps parsed from %s" % maps_dir)
    return maps


class BlockdataReader:
    def __init__(self, root, mask, shift):
        self.root = root
        self.mask = mask
        self.shift = shift
        self._cache = {}

    def grid(self, layout):
        key = layout["blockdata"]
        if key not in self._cache:
            abs_path = os.path.join(self.root, key)
            self._cache[key] = read_bytes(abs_path)
        return self._cache[key]

    def _ids(self, blob):
        return {(int.from_bytes(blob[i:i + 2], "little") & self.mask) >> self.shift
                for i in range(0, len(blob) - 1, 2)}

    def placed_ids(self, layout):
        """Every distinct metatile id actually placed on this layout."""
        return self._ids(self.grid(layout))

    def border_ids(self, layout):
        """The border block, which is drawn all round the map and is therefore on screen for
        any door near an edge -- and, on a map smaller than the camera, everywhere."""
        rel = layout.get("border")
        if not rel:
            return set()
        abs_path = os.path.join(self.root, rel)
        if not os.path.exists(abs_path):
            return set()
        key = "border:" + rel
        if key not in self._cache:
            self._cache[key] = read_bytes(abs_path)
        return self._ids(self._cache[key])

    def fringe_ids(self, layout, direction, depth):
        """The strip of a CONNECTED map that gets copied into gBackupMapLayout, up to MAP_OFFSET
        metatiles deep along the shared edge. These are drawn with the CURRENT map's tilesets,
        so they are resolved through the door map's pair, not the neighbour's."""
        blob = self.grid(layout)
        w, h = layout["width"], layout["height"]
        if len(blob) < w * h * 2:
            return set()

        def at(x, y):
            off = (y * w + x) * 2
            return (int.from_bytes(blob[off:off + 2], "little") & self.mask) >> self.shift

        if direction == "up":
            ys, xs = range(max(0, h - depth), h), range(w)
        elif direction == "down":
            ys, xs = range(0, min(depth, h)), range(w)
        elif direction == "left":
            xs, ys = range(max(0, w - depth), w), range(h)
        elif direction == "right":
            xs, ys = range(0, min(depth, w)), range(h)
        else:
            return set()
        return {at(x, y) for y in ys for x in xs}

    def metatile_at(self, layout, x, y):
        """Return (metatile_id, None) or (None, reason)."""
        w, h = layout["width"], layout["height"]
        if not (0 <= x < w and 0 <= y < h):
            return None, "out of bounds (map is %dx%d)" % (w, h)
        blob = self.grid(layout)
        expected = w * h * 2
        if len(blob) < expected:
            return None, "%s is %d bytes, expected %d for %dx%d" % (
                layout["blockdata"], len(blob), expected, w, h,
            )
        off = (y * w + x) * 2
        block = int.from_bytes(blob[off:off + 2], "little")
        return (block & self.mask) >> self.shift, None


# ---------------------------------------------------------------------------
# 5. Main scan
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# The door animation borrows VRAM while it runs.
# ---------------------------------------------------------------------------
# CopyDoorTilesToVram (src/field_door.c) writes the live frame into a scratch
# window at the top of the tile space, and the NOTE above it says any pre-existing
# tile visible in that region is overwritten. Registering a door therefore has a
# SECOND precondition beyond having a table row: the tilesets on that map must not
# DRAW from the window, or opening the door silently corrupts whatever does -- for
# as long as it is open, and again in reverse when it shuts. It is invisible until
# someone animates a door on that map, which is exactly how it slipped through:
# Mahogany's roof lost its ridge detail the moment its door started working.
#
# The window is NOT one fixed range. CopyDoorTilesToVram picks it from the row's
# `size` AND the layout's flags:
#
#     size == 2 && !isFrlg && !isJohto  ->  16 tiles at NUM_TILES_TOTAL - 16
#     otherwise                         ->   8 tiles at NUM_TILES_TOTAL -  8
#
# so a size-2 door on an Emerald layout reaches eight tiles LOWER than everything
# else. Checking only the 8-tile window would silently miss that half. The caller
# therefore computes the widest window each tileset is actually exposed to, from
# the live warps that reach it, and passes that in.
#
# Metatile tile ids are GLOBAL, so no primary/secondary split is needed here -- a
# tile id at or above the window start is inside it whichever half it resolves
# through.


def door_scratch_collisions(tilesets, exposure, n_prim_em, n_prim_frlg):
    """Metatiles that are ACTUALLY PLACED on a map with a live animated door and that
    draw a tile inside the VRAM window that map's door animation overwrites.

    `exposure` maps map name -> (window_start, layout, placed metatile id set).
    Placement is what makes this precise: gTileset_Johto_Building has two metatiles
    drawing tile 1021, but the only maps that place either of them are three Radio
    Tower floors whose warps are not animated doors -- so nothing is ever corrupted
    and flagging the tileset would be a false alarm.

    Returns (map, tileset, local metatile, window start, offending tile ids) per hit."""
    cache = {}

    def words(ts_name, local):
        blob = cache.get(ts_name)
        if blob is None:
            rec = tilesets.get(ts_name)
            if not rec or rec.get("error") or not rec.get("metatiles_abs"):
                cache[ts_name] = b""
                return None
            blob = cache[ts_name] = read_bytes(rec["metatiles_abs"])
        if not blob or (local + 1) * 16 > len(blob):
            return None
        return [struct.unpack_from("<H", blob, local * 16 + i * 2)[0] & 0x3FF
                for i in range(8)]

    out = []
    for map_name, (start_tile, layout, placed) in sorted(exposure.items()):
        split = n_prim_frlg if layout["version"] in ("frlg", "johto") else n_prim_em
        for gid in sorted(placed):
            if gid < split:
                ts_name, local = layout["primary"], gid
            else:
                ts_name, local = layout["secondary"], gid - split
            if ts_name is None:
                continue
            w = words(ts_name, local)
            if not w:
                continue
            hits = sorted({t for t in w if t >= start_tile})
            if hits:
                out.append((map_name, ts_name, local, start_tile, hits))
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--max", type=int, default=None,
                    help="exit 1 if the dead-door count exceeds N")
    ap.add_argument("--allow-scratch-collisions", action="store_true",
                    help="do not fail when map art draws from the VRAM window a door borrows")
    ap.add_argument("--max-unresolved", type=int, default=UNRESOLVED_BASELINE,
                    help="exit 1 if more than N warps cannot have their behavior read "
                         "at all (default: today's baseline of %d)" % UNRESOLVED_BASELINE)
    ap.add_argument("--root", default=None,
                    help="repo root (default: the parent of this script's directory)")
    ap.add_argument("--verbose", action="store_true",
                    help="also list every LIVE animated-door warp")
    args = ap.parse_args(argv)

    root = args.root or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    root = os.path.abspath(root)

    try:
        grid_mask, grid_shift = parse_mapgrid_masks(root)
        attr_masks = parse_attr_masks(root)
        n_prim_em, n_prim_frlg, n_total = parse_primary_counts(root)
        NUM_TILES_TOTAL_VAL = parse_tile_total(root)
        map_offset = parse_map_offset(root)
        behaviors = parse_behavior_enum(root)
        labels = parse_metatile_labels(root)
        tilesets = parse_tilesets(root)
        door_rows, door_index, null_rows, door_sizes = parse_door_table(root, labels)
        layouts = parse_layouts(root, n_prim_em, n_prim_frlg)
        maps = parse_maps(root)
    except Fatal as exc:
        print("FATAL: %s" % exc, file=sys.stderr)
        return 2

    mb_animated_door = behaviors["MB_ANIMATED_DOOR"]
    attrs = AttributeReader(root, tilesets, attr_masks)
    blocks = BlockdataReader(root, grid_mask, grid_shift)

    print("=" * 78)
    print("DEAD ANIMATED DOOR REPORT")
    print("repo root: %s" % root)
    print("=" * 78)
    print()
    print("--- Derived constants (read from the tree, not assumed) ---")
    print("  map-grid metatile id      : mask 0x%04X, shift %d  (include/global.fieldmap.h)"
          % (grid_mask, grid_shift))
    print("  behavior, 2-byte attrs    : mask 0x%08X, shift %d  (Emerald format)"
          % (attr_masks[2][0], attr_masks[2][1]))
    print("  behavior, 4-byte attrs    : mask 0x%08X, shift %d  (FRLG format)"
          % (attr_masks[4][0], attr_masks[4][1]))
    print("  MB_ANIMATED_DOOR          : %d (0x%02X)" % (mb_animated_door, mb_animated_door))
    print("  NUM_METATILES_IN_PRIMARY  : %d (Emerald layouts)" % n_prim_em)
    print("  ..._IN_PRIMARY_FRLG       : %d (FRLG + Johto layouts)" % n_prim_frlg)
    print("  NUM_METATILES_TOTAL       : %d" % n_total)
    print("  primary-count selection   : GetNumMetatilesInPrimary() = "
          "(isFrlg || isJohto) ? %d : %d" % (n_prim_frlg, n_prim_em))
    print("  layout_version -> flags    : frlg=isFrlg, johto=isJohto, "
          "everything else = neither (tools/mapjson/mapjson.cpp)")
    print()

    width_counts = Counter(
        ts["bytes_per_attr"] for ts in tilesets.values() if not ts.get("error")
    )
    print("--- Metatile-attribute format, detected PER TILESET ---")
    print("  (src/fieldmap.c GetTilesetMetatileAttribute() keys off tileset->hasFrlgAttributes,")
    print("   which TILESET_METATILES derives as sizeof(attrs) * 16 / sizeof(metatiles) == 4)")
    for w in sorted(width_counts):
        fmt = "FRLG u32, behavior in bits 0-8" if w == 4 else (
            "Emerald u16, behavior in bits 0-7" if w == 2 else "UNKNOWN")
        print("  %3d bytes/entry : %4d tilesets   (%s)" % (w, width_counts[w], fmt))
    broken = [n for n, t in tilesets.items() if t.get("error")]
    if broken:
        print("  tilesets with unreadable data: %d -> %s" % (len(broken), ", ".join(sorted(broken)[:5])))
    print()

    # Cross-check: a known-good door must decode to MB_ANIMATED_DOOR.
    print("--- Cross-check on known-good doors ---")
    checks = [
        ("METATILE_General_Door", "gTileset_General", n_prim_em),
        ("METATILE_Johto_General_Door", "gTileset_Johto_General", n_prim_frlg),
        ("METATILE_GeneralFrlg_Door", "gTileset_General_Frlg", n_prim_frlg),
    ]
    check_failures = 0
    for label, ts_name, split in checks:
        if label not in labels or ts_name not in tilesets:
            print("  SKIP  %-32s (%s not present)" % (label, ts_name))
            continue
        gid = labels[label]
        local = gid if gid < split else gid - split
        beh, err = attrs.behavior(ts_name, local)
        if err:
            print("  FAIL  %-32s %-26s -> %s" % (label, ts_name, err))
            check_failures += 1
        elif beh == mb_animated_door:
            print("  OK    %-32s 0x%03X in %-26s local %3d -> behavior %d "
                  "== MB_ANIMATED_DOOR" % (label, gid, ts_name, local, beh))
        else:
            print("  FAIL  %-32s 0x%03X in %-26s local %3d -> behavior %d "
                  "!= MB_ANIMATED_DOOR (%d)" % (label, gid, ts_name, local, beh,
                                                mb_animated_door))
            check_failures += 1
    if check_failures:
        print("  !! attribute decoding looks WRONG -- the numbers below are not trustworthy")
        print("  !! refusing to report a door census from an untrustworthy decode")
        return 2
    print()

    print("--- Door table ---")
    print("  usable rows in sDoorAnimGraphicsTable : %d" % len(door_rows))
    print("  distinct metatile ids covered         : %d" % len(door_index))
    print("  distinct tilesets referenced          : %d"
          % len({ts for _mt, ts, _raw in door_rows}))
    for raw, val in null_rows:
        print("  EXCLUDED row with NULL tileset        : %s (0x%03X) -- a NULL tileset can never"
              % (raw, val))
        print("                                          equal a real layout's tileset pointer")
    missing_ts = sorted({ts for _mt, ts, _raw in door_rows if ts not in tilesets})
    if missing_ts:
        print("  WARNING: rows name tilesets not found in headers.h: %s" % ", ".join(missing_ts))
    print()

    # ---------------------------------------------------------------- scan ---
    total_warps = 0
    scanned_warps = 0
    animated_warps = 0
    scratch_exposure = {}
    # Connections name their neighbour by MAP_ id, so index the maps that way once.
    maps_by_id = {m["id"]: m for m in maps if m.get("id")}
    live = []
    dead = []
    out_of_bounds = []
    problems = []
    maps_missing_layout = []

    for mp in maps:
        layout = layouts.get(mp["layout"])
        if layout is None:
            maps_missing_layout.append((mp["name"], mp["layout"]))
            total_warps += len(mp["warps"])
            continue
        for warp in mp["warps"]:
            total_warps += 1
            try:
                x = int(warp["x"])
                y = int(warp["y"])
            except (KeyError, TypeError, ValueError):
                problems.append((mp["name"], "?", "?", "warp without usable x/y: %r" % (warp,)))
                continue

            gid, err = blocks.metatile_at(layout, x, y)
            if err is not None:
                if err.startswith("out of bounds"):
                    out_of_bounds.append((mp["name"], x, y, layout["name"], err))
                else:
                    problems.append((mp["name"], x, y, err))
                continue
            scanned_warps += 1

            split = layout["num_primary"]
            if gid < split:
                owner = layout["primary"]
                local = gid
                half = "primary"
            elif gid < n_total:
                owner = layout["secondary"]
                local = gid - split
                half = "secondary"
            else:
                problems.append((mp["name"], x, y,
                                 "metatile 0x%03X >= NUM_METATILES_TOTAL" % gid))
                continue

            if owner is None:
                problems.append((mp["name"], x, y,
                                 "layout %s has no %s tileset" % (layout["name"], half)))
                continue

            beh, err = attrs.behavior(owner, local)
            if err is not None:
                problems.append((mp["name"], x, y,
                                 "metatile 0x%03X (%s %s local %d): %s"
                                 % (gid, half, owner, local, err)))
                continue

            if beh != mb_animated_door:
                continue
            animated_warps += 1

            row_tilesets = door_index.get(gid, ())
            matched = None
            for cand in (layout["primary"], layout["secondary"]):
                if cand is not None and cand in row_tilesets:
                    matched = cand
                    break

            # How much VRAM this particular door borrows, computed exactly as
            # CopyDoorTilesToVram does: the row's size AND this layout's isFrlg/isJohto.
            # Both halves of the pair are at risk, because either can draw into the window.
            if matched is not None:
                sz = door_sizes.get((gid, matched), 2)
                wide = sz == 2 and layout["version"] not in ("frlg", "johto")
                start = (NUM_TILES_TOTAL_VAL - 16) if wide else (NUM_TILES_TOTAL_VAL - 8)
                prev = scratch_exposure.get(mp["name"])
                if prev is None:
                    drawable = blocks.placed_ids(layout) | blocks.border_ids(layout)
                    # A connected map's fringe is copied into gBackupMapLayout and drawn with
                    # THIS map's tilesets, so it is exposed to THIS map's door window.
                    for conn in mp.get("connections") or []:
                        neighbour = maps_by_id.get(conn.get("map"))
                        if neighbour is None:
                            continue
                        nlayout = layouts.get(neighbour.get("layout"))
                        if nlayout is None or not nlayout.get("blockdata"):
                            continue
                        drawable |= blocks.fringe_ids(nlayout, conn.get("direction"), map_offset)
                    scratch_exposure[mp["name"]] = (start, layout, drawable)
                elif start < prev[0]:
                    scratch_exposure[mp["name"]] = (start, prev[1], prev[2])

            record = {
                "map": mp["name"],
                "map_dir": mp["dir"],
                "x": x,
                "y": y,
                "layout": layout["name"],
                "version": layout["version"],
                "gid": gid,
                "owner": owner,
                "half": half,
                "local": local,
                "primary": layout["primary"],
                "secondary": layout["secondary"],
                "matched": matched,
            }
            if matched is not None:
                live.append(record)
            else:
                dead.append(record)

    # --------------------------------------------------------------- report ---
    print("--- Scan totals ---")
    print("  layouts parsed            : %d" % len(layouts))
    print("  maps parsed               : %d" % len(maps))
    print("  warp events found         : %d" % total_warps)
    print("  warp events resolved      : %d" % scanned_warps)
    print("  warps out of map bounds   : %d" % len(out_of_bounds))
    print("  other unresolvable warps  : %d" % len(problems))
    if maps_missing_layout:
        print("  maps with unknown layout  : %d" % len(maps_missing_layout))
    print()
    print("  ANIMATED-DOOR warps       : %d" % animated_warps)
    print("    LIVE  (table row match) : %d" % len(live))
    print("    DEAD  (no match)        : %d" % len(dead))
    print()

    print("--- A few LIVE doors (proof the matching actually matches) ---")
    seen = set()
    shown = 0
    for rec in live:
        key = (rec["matched"], rec["gid"])
        if key in seen:
            continue
        seen.add(key)
        print("  %-38s (%3d,%3d)  metatile 0x%03X  matched row tileset %s"
              % (rec["map"], rec["x"], rec["y"], rec["gid"], rec["matched"]))
        shown += 1
        if shown >= 8:
            break
    if not live:
        print("  (none -- something is wrong with the matching)")
    print()

    if args.verbose and live:
        print("--- All LIVE animated-door warps ---")
        for rec in sorted(live, key=lambda r: (r["matched"], r["gid"], r["map"], r["y"], r["x"])):
            print("  %-38s (%3d,%3d)  0x%03X  %s" % (rec["map"], rec["x"], rec["y"],
                                                     rec["gid"], rec["matched"]))
        print()

    print("=" * 78)
    print("DEAD ANIMATED DOORS: %d" % len(dead))
    print("=" * 78)
    if dead:
        groups = defaultdict(list)
        for rec in dead:
            groups[(rec["owner"], rec["gid"])].append(rec)
        for (owner, gid) in sorted(groups, key=lambda k: (k[0] or "", k[1])):
            recs = groups[(owner, gid)]
            rows_for_id = sorted(door_index.get(gid, ()))
            print()
            print("  %s  metatile 0x%03X  (%d warp%s)"
                  % (owner, gid, len(recs), "" if len(recs) == 1 else "s"))
            if rows_for_id:
                print("      table has this metatile id, but only for: %s"
                      % ", ".join(rows_for_id))
            else:
                print("      no row in sDoorAnimGraphicsTable uses metatile 0x%03X at all" % gid)
            for rec in sorted(recs, key=lambda r: (r["map"], r["y"], r["x"])):
                print("      %-38s (%3d,%3d)   layout %s [%s]  %s half, local %d"
                      % (rec["map"], rec["x"], rec["y"], rec["layout"],
                         rec["version"], rec["half"], rec["local"]))
                print("          %-42s primary=%s secondary=%s"
                      % ("", rec["primary"], rec["secondary"]))
        print()
    print("TOTAL DEAD ANIMATED DOORS: %d" % len(dead))
    print("TOTAL LIVE ANIMATED DOORS: %d" % len(live))
    print("TOTAL ANIMATED-DOOR WARPS: %d" % animated_warps)
    print()

    if out_of_bounds:
        print("--- Warps outside their map's bounds (skipped, not counted) ---")
        for name, x, y, lay, err in out_of_bounds:
            print("  %-38s (%3d,%3d)  layout %s: %s" % (name, x, y, lay, err))
        print()
    if problems:
        print("--- Warps that could not be resolved ---")
        for name, x, y, err in problems:
            print("  %-38s (%3s,%3s)  %s" % (name, x, y, err))
        print()
    if maps_missing_layout:
        print("--- Maps whose layout id is not in layouts.json ---")
        for name, lay in maps_missing_layout:
            print("  %-38s %s" % (name, lay))
        print()

    scratch = door_scratch_collisions(tilesets, scratch_exposure, n_prim_em, n_prim_frlg)
    widest = min((v[0] for v in scratch_exposure.values()), default=NUM_TILES_TOTAL_VAL - 8)
    print("--- Map art vs the VRAM window the door animation borrows ---")
    print("  window is 8 tiles at %d, or 16 at %d for a size-2 row on a non-FRLG/Johto layout"
          % (NUM_TILES_TOTAL_VAL - 8, NUM_TILES_TOTAL_VAL - 16))
    print("  maps with a live animated door : %d   widest window any of them opens: %d-%d"
          % (len(scratch_exposure), widest, NUM_TILES_TOTAL_VAL - 1))
    if scratch:
        print("  These metatiles are PLACED on a map whose door animation overwrites the tiles")
        print("  they draw, so they are corrupted for as long as that door is open:")
        for mn, ts, local, start, hits in scratch:
            print("  %-38s %s local %d  window %d+  tiles %s" % (mn, ts, local, start, hits))
    else:
        print("  none -- no metatile placed on a door map draws from that map's window")
    print()

    # Liveness floor. Every remaining way this script can be wrong drives the dead
    # count DOWN, so "0 dead" is only meaningful alongside "and it actually found
    # and matched doors". A scan that resolved nothing is a broken scan, not a pass.
    if not animated_warps or not live:
        print("FAIL: scan found %d animated-door warps and %d live matches -- "
              "that is not a clean tree, it is a broken scan"
              % (animated_warps, len(live)))
        return 2

    if args.max is not None and len(dead) > args.max:
        print("FAIL: %d dead animated doors exceeds --max %d" % (len(dead), args.max))
        return 1

    # The blind spot behind the zero. A warp whose behavior cannot be read is NOT counted
    # dead -- but it is not counted live either, so a new one is a hole in the census, and
    # holes make the dead count go DOWN. Gating it at the known baseline means the day
    # someone paints a warp onto an out-of-range metatile, this says so instead of quietly
    # shrinking the population it checks.
    if scratch and not args.allow_scratch_collisions:
        print("FAIL: %d metatile placement(s) draw a tile that the door animation on their own "
              "map overwrites while it plays. Registering a door is not enough -- the art on that "
              "map has to stay out of the window the animation borrows, or opening the door "
              "corrupts it until it shuts. Each line gives that map's window start; note a size-2 "
              "row on a non-FRLG/Johto layout borrows 16 tiles, not 8. Fix by moving the offending "
              "tiles to free slots and repointing the metatiles -- the move must be an identity, "
              "so verify it by compositing every metatile before and after and requiring the same "
              "pixels AND the same palette numbers." % len(scratch))
        return 1

    if len(problems) > args.max_unresolved:
        print("FAIL: %d warps could not be resolved, over the baseline of %d. These are NOT "
              "counted dead, so a new one SHRINKS the census rather than failing it -- which "
              "is why it is gated separately. Either fix the layout/tileset mismatch or, if "
              "the growth is genuinely intended, raise --max-unresolved deliberately."
              % (len(problems), args.max_unresolved))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
