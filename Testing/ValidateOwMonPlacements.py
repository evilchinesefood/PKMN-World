#!/usr/bin/env python3
"""Validate map-placed overworld Pokemon object events (issue #49).

Why this exists
---------------
A static overworld Pokemon is an ordinary object event whose graphics_id carries the
OBJ_EVENT_MON bit:

    #define OBJ_EVENT_GFX_SPECIES(name) (SPECIES_##name + OBJ_EVENT_MON)

`GetObjectEventGraphicsInfo` tests that bit and routes to `SpeciesToGraphicsInfo`. Without it the
id indexes `gObjectEventGraphicsInfoPointers[]` instead, and the one id that *looks* right,
`OBJ_EVENT_GFX_OW_MON`, points at `gObjectEventGraphicsInfo_Follower` - a runtime placeholder with
`.tileTag = TAG_NONE`, `.paletteTag = OBJ_EVENT_PAL_TAG_DYNAMIC` and no `.images` at all. Nothing
loads tiles or a palette into those slots for a map-placed object, so it draws whatever garbage is
resident. 741 Johto objects shipped like that.

Three further traps this script encodes, all learned the hard way:

* Resolve a tileset's attribute blob through `src/data/tilesets/headers.h` ->
  `src/data/tilesets/metatiles.h`. Deriving the directory by case-splitting the symbol name
  silently fails on the 18 tilesets whose names already contain underscores
  (`gTileset_Johto_General`, `gTileset_Cave_Ice`, ...), and a missing file degrades to attribute 0
  = MB_NORMAL, which inflates every count *plausibly*.
* `map.json` coordinates are not where an object ends up. `setobjectxyperm` relocates it at
  runtime; Ho-Oh's `(10, 1)` on the Tin Tower roof is an off-screen spawn point for a scripted
  flight down. Every positional rule below runs against the runtime position.
* `collision > 0` is not a defect. `GetFacingObject` ignores collision, so an impassable tile
  next to a walkable one is the normal legendary-on-a-ledge idiom. The real test is reachability:
  at least one orthogonal collision-0 neighbour.

And because `OW_SUBSTITUTE_PLACEHOLDER == TRUE`, a species with no `OVERWORLD(...)` entry renders
as a Substitute doll rather than crashing - so "it built and it renders" proves nothing, and rule 2
has to check for the entry explicitly.

Usage:
    python3 Testing/ValidateOwMonPlacements.py            # exit 1 on any violation
    python3 Testing/ValidateOwMonPlacements.py --report    # CSV of every placement, exit 0
"""
import json, os, re, sys, glob, struct

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# A parse that finds nothing must fail loudly: every rule below is a lookup that passes vacuously
# against an empty table. Floors sit well under the real counts.
MIN_BEHAVIORS = 200          # metatile_behaviors.h enum members
MIN_ENCOUNTER_BEHAVIORS = 10  # TILE_FLAG_HAS_ENCOUNTERS rows in sTileBitAttributes
MIN_OVERWORLD_SPECIES = 400   # species with an OVERWORLD(...) entry
MIN_DISABLED_FAMILIES = 300   # P_FAMILY_* FALSE in species_enabled.h
MIN_PLACEMENTS = 700          # OBJ_EVENT_GFX_SPECIES / OW_MON objects tree-wide

MAPGRID_METATILE_ID_MASK = 0x03FF
MAPGRID_COLLISION_MASK = 0x0C00
MAPGRID_COLLISION_SHIFT = 10
MAPGRID_ELEVATION_MASK = 0xF000
MAPGRID_ELEVATION_SHIFT = 12
METATILE_ATTR_BEHAVIOR_MASK = 0x00FF        # Emerald layouts, u16 attributes
METATILE_ATTR_BEHAVIOR_MASK_FRLG = 0x01FF   # FRLG layouts, u32 attributes
NUM_METATILES_IN_PRIMARY = 512
NUM_METATILES_IN_PRIMARY_FRLG = 640         # also used for layout_version "johto"
NUM_METATILES_TOTAL = 1024
METATILE_SIZE_BYTES = 16   # 8 tiles x u16, in metatiles.bin

# The day/night pair is the one flag combination that makes two objects on one tile legitimate:
# exactly one side is ever visible. Nothing cycles these yet (new_game.inc parks the night set
# hidden), which is why half the Johto placements look wrong in isolation.
DAY_NIGHT = {"FLAG_DAY_POKEMON", "FLAG_NIGHT_POKEMON"}

SPECIES_GFX = re.compile(r"^OBJ_EVENT_GFX_SPECIES\((\w+)\)$")


def die(msg):
    print(f"FAIL - {msg}")
    sys.exit(1)


def read(path):
    with open(os.path.join(ROOT, path), encoding="utf-8", errors="replace") as f:
        return f.read()


# ---------------------------------------------------------------------------
# Tables parsed out of the tree
# ---------------------------------------------------------------------------

def load_behavior_names():
    """MB_* enum -> value. It is an `enum`, not #defines: a #define regex yields an empty table."""
    src = read("include/constants/metatile_behaviors.h")
    body = re.search(r"enum\s*\{(.*?)\n\};", src, re.S)
    if not body:
        die("could not find the metatile behaviour enum body in metatile_behaviors.h")
    names, value = {}, 0
    for raw in body.group(1).splitlines():
        line = re.sub(r"//.*", "", raw).strip().rstrip(",").strip()
        if not line:
            continue
        m = re.match(r"^(MB_\w+)\s*=\s*(\w+)$", line)
        if m:
            value = int(m.group(2), 0)
            names[m.group(1)] = value
        elif re.match(r"^MB_\w+$", line):
            names[line] = value
        else:
            continue
        value += 1
    if len(names) < MIN_BEHAVIORS:
        die(f"only {len(names)} metatile behaviours parsed (expected >= {MIN_BEHAVIORS})")
    return names


def load_encounter_behaviors(behavior_names):
    """The behaviours flagged TILE_FLAG_HAS_ENCOUNTERS in sTileBitAttributes."""
    src = read("src/metatile_behavior.c")
    body = re.search(r"sTileBitAttributes\[NUM_METATILE_BEHAVIORS\]\s*=\s*\{(.*?)\n\};", src, re.S)
    if not body:
        die("could not find sTileBitAttributes in src/metatile_behavior.c")
    out = set()
    for m in re.finditer(r"\[(MB_\w+)\]\s*=\s*([^,\n]+)", body.group(1)):
        if "TILE_FLAG_HAS_ENCOUNTERS" in m.group(2):
            if m.group(1) not in behavior_names:
                die(f"sTileBitAttributes names {m.group(1)}, absent from the behaviour enum")
            out.add(behavior_names[m.group(1)])
    if len(out) < MIN_ENCOUNTER_BEHAVIORS:
        die(f"only {len(out)} encounter behaviours parsed (expected >= {MIN_ENCOUNTER_BEHAVIORS})")
    return out


def load_tileset_attributes():
    """gTileset_X -> (metatile_attributes.bin, metatiles.bin), resolved in two hops.

    headers.h names the SYMBOLS each tileset uses; metatiles.h maps those symbols to files. Both
    hops are needed: deriving the directory from the symbol name by case-splitting fails silently
    on the 18 tilesets whose names already contain underscores.

    The INCBIN width in metatiles.h is NOT the attribute width - every blob is declared `const u16`
    even when the data is u32 (gMetatileAttributes_Building_Frlg is 2560 bytes for 640 metatiles).
    The real width belongs to the BLOB, and both C and this script derive it the same way: attribute
    bytes divided by metatile count, where metatiles.bin is 16 bytes per metatile.

    Every tileset must declare both symbols through the TILESET_METATILES macro, which is what
    computes `hasFrlgAttributes`. A hand-written `.metatileAttributes =` would leave that flag FALSE
    and read a u32 blob as u16 - issue #53 in miniature - so it is a hard failure here.
    """
    symbol_to_file = {}
    for m in re.finditer(r"const\s+u(?:16|32)\s+(gMetatile\w+)\[\]\s*=\s*"
                         r"INCBIN_U(?:16|32)\(\"([^\"]+)\"\)", read("src/data/tilesets/metatiles.h")):
        symbol_to_file[m.group(1)] = m.group(2)
    if not symbol_to_file:
        die("no gMetatile* INCBIN rows parsed from src/data/tilesets/metatiles.h")

    out = {}
    headers = read("src/data/tilesets/headers.h")
    for m in re.finditer(r"const\s+struct\s+Tileset\s+(gTileset_\w+)\s*=\s*\{(.*?)\n\};",
                         headers, re.S):
        name, body = m.group(1), m.group(2)
        bare = re.search(r"\.(metatiles|metatileAttributes)\s*=", body)
        if bare:
            die(f"{name} sets .{bare.group(1)} directly; use "
                f"TILESET_METATILES(metatiles, attributes) so hasFrlgAttributes is derived from the "
                f"blob instead of silently defaulting to the Emerald u16 format (issue #53)")
        pair = re.search(r"TILESET_METATILES\(\s*(gMetatiles_\w+)\s*,\s*(gMetatileAttributes_\w+)\s*\)",
                         body)
        if not pair:
            continue
        files = []
        for sym in pair.groups():
            entry = symbol_to_file.get(sym)
            if entry is None:
                die(f"{name} uses {sym}, which metatiles.h does not define")
            files.append(entry)
        out[name] = (files[1], files[0])
    if not out:
        die("no tilesets parsed from src/data/tilesets/headers.h")
    return out


def check_attribute_widths(tileset_files):
    """Every attribute blob must be exactly 2 or 4 bytes per metatile.

    `TILESET_METATILES` decides the format with `(sizeof(attrs) * 16 / sizeof(metatiles)) == 4`.
    Integer division means anything that is not exactly 4 reads as the Emerald u16 format, so a
    truncated or padded blob would be mis-declared with no diagnostic at all. This is the guard that
    makes the compile-time derivation trustworthy, and it is why the layout-vs-blob mismatch of
    issue #53 can no longer happen: the width now comes from the same place in both languages.
    """
    widths, bad = {}, []
    for name, (attr_rel, mt_rel) in sorted(tileset_files.items()):
        attr_path, mt_path = os.path.join(ROOT, attr_rel), os.path.join(ROOT, mt_rel)
        if not os.path.exists(attr_path):
            die(f"metatile attribute blob missing: {attr_rel} (for {name})")
        if not os.path.exists(mt_path):
            die(f"metatiles blob missing: {mt_rel} (for {name}) - the attribute width cannot be "
                f"derived without it, and C derives it the same way")
        attr_bytes, mt_bytes = os.path.getsize(attr_path), os.path.getsize(mt_path)
        if mt_bytes == 0 or mt_bytes % METATILE_SIZE_BYTES:
            bad.append(f"{name}: {mt_rel} is {mt_bytes} bytes, not a non-zero multiple of "
                       f"{METATILE_SIZE_BYTES}")
            continue
        count = mt_bytes // METATILE_SIZE_BYTES
        if attr_bytes % count:
            bad.append(f"{name}: {attr_rel} is {attr_bytes} bytes for {count} metatiles "
                       f"({attr_bytes / count:.2f} bytes each) - not a whole attribute width")
            continue
        width = attr_bytes // count
        if width not in (2, 4):
            bad.append(f"{name}: {attr_rel} is {width} bytes per metatile; only 2 (Emerald) and "
                       f"4 (FRLG) exist, and TILESET_METATILES would declare this one u16")
            continue
        widths[name] = width
    if bad:
        print(f"FAIL - {len(bad)} tileset(s) with an undeclarable metatile-attribute width:")
        for line in bad:
            print(f"  {line}")
        sys.exit(1)
    return widths


def load_overworld_species():
    """SPECIES_* ids that have an OVERWORLD(...) entry, and SPECIES_* -> family guard."""
    have_ow, species_family = set(), {}
    for path in sorted(glob.glob(os.path.join(ROOT, "src/data/pokemon/species_info/gen_*_families.h"))):
        stack, cur = [], None
        for line in open(path, encoding="utf-8", errors="replace"):
            m = re.match(r"\s*#if\s+(P_FAMILY_\w+)", line)
            if m:
                stack.append(m.group(1)); continue
            if re.match(r"\s*#(if|ifdef|ifndef)\b", line):
                stack.append(None); continue
            if re.match(r"\s*#(else|elif)\b", line):
                if stack: stack[-1] = None
                continue
            if re.match(r"\s*#endif", line):
                if stack: stack.pop()
                continue
            m = re.match(r"\s*\[(SPECIES_\w+)\]\s*=", line)
            if m:
                cur = m.group(1)
                fam = next((s for s in reversed(stack) if s), None)
                if fam:
                    species_family[cur] = fam
                continue
            if cur and re.match(r"\s*OVERWORLD\s*\(", line):
                have_ow.add(cur)
    if len(have_ow) < MIN_OVERWORLD_SPECIES:
        die(f"only {len(have_ow)} species with OVERWORLD() parsed (expected >= {MIN_OVERWORLD_SPECIES})")
    return have_ow, species_family


def load_disabled_families():
    out = {m.group(1) for m in re.finditer(r"#define\s+(P_FAMILY_\w+)\s+FALSE\b",
                                          read("include/config/species_enabled.h"))}
    if len(out) < MIN_DISABLED_FAMILIES:
        die(f"only {len(out)} disabled families parsed (expected >= {MIN_DISABLED_FAMILIES})")
    return out


class Layouts:
    """Blockdata + behaviour lookup for every layout, loaded lazily and cached."""

    def __init__(self, tileset_files, tileset_widths):
        raw = json.load(open(os.path.join(ROOT, "data/layouts/layouts.json"), encoding="utf-8"))
        self.by_id = {l["id"]: l for l in raw["layouts"]}
        self.tileset_files = tileset_files
        self.tileset_widths = tileset_widths
        self._grids = {}
        self._behaviors = {}
        self._attrs = {}
        # Layouts whose behaviours could not be resolved at all (a tileset this script cannot see,
        # e.g. layouts.json's one `"secondary_tileset": "0"`). Width mismatches used to land here
        # too; they cannot happen now that C and this script derive the width from the same blob.
        self.untrusted_layouts = set()

    def _attr_table(self, symbol):
        """-> ([attribute values], behaviour mask), decoded at the BLOB's own width.

        This mirrors `GetTilesetMetatileAttribute`: `hasFrlgAttributes` is a property of the tileset,
        so a "johto" layout borrowing a Kanto tileset reads that tileset's u32 attributes as u32,
        and a johto primary paired with a Kanto secondary uses a different width for each half.
        """
        if symbol in self._attrs:
            return self._attrs[symbol]
        width = self.tileset_widths.get(symbol)
        if width is None:
            die(f"tileset {symbol} has no TILESET_METATILES entry")
        rel = self.tileset_files[symbol][0]
        blob = open(os.path.join(ROOT, rel), "rb").read()
        fmt = "I" if width == 4 else "H"
        mask = METATILE_ATTR_BEHAVIOR_MASK_FRLG if width == 4 else METATILE_ATTR_BEHAVIOR_MASK
        self._attrs[symbol] = (list(struct.unpack(f"<{len(blob)//width}{fmt}", blob)), mask)
        return self._attrs[symbol]

    def behaviors(self, layout_id):
        """metatile id -> behaviour, honouring the layout's primary size and each tileset's width."""
        if layout_id in self._behaviors:
            return self._behaviors[layout_id]
        lay = self.by_id[layout_id]
        version = lay.get("layout_version", "emerald")
        num_primary = (NUM_METATILES_IN_PRIMARY_FRLG if version in ("frlg", "johto")
                       else NUM_METATILES_IN_PRIMARY)
        halves = []
        for role in ("primary_tileset", "secondary_tileset"):
            symbol = lay[role]
            if symbol not in self.tileset_widths:
                self.untrusted_layouts.add(layout_id)
                halves.append(([], METATILE_ATTR_BEHAVIOR_MASK))
                continue
            halves.append(self._attr_table(symbol))
        (prim, prim_mask), (sec, sec_mask) = halves
        table = {}
        for mid in range(NUM_METATILES_TOTAL):
            vals, mask, idx = ((prim, prim_mask, mid) if mid < num_primary
                               else (sec, sec_mask, mid - num_primary))
            table[mid] = (vals[idx] & mask) if idx < len(vals) else None
        self._behaviors[layout_id] = table
        return table

    def grid(self, layout_id):
        """-> (width, height, [u16 blocks])"""
        if layout_id in self._grids:
            return self._grids[layout_id]
        lay = self.by_id[layout_id]
        path = os.path.join(ROOT, lay["blockdata_filepath"])
        if not os.path.exists(path):
            die(f"blockdata missing for {layout_id}: {lay['blockdata_filepath']}")
        blob = open(path, "rb").read()
        w, h = lay["width"], lay["height"]
        blocks = list(struct.unpack(f"<{len(blob)//2}H", blob[:len(blob)//2*2]))
        if len(blocks) < w * h:
            die(f"{layout_id}: blockdata holds {len(blocks)} blocks, layout is {w}x{h}")
        self._grids[layout_id] = (w, h, blocks)
        return self._grids[layout_id]

    def tile(self, layout_id, x, y):
        """-> dict(metatile, collision, elevation, behavior) or None when out of the layout."""
        w, h, blocks = self.grid(layout_id)
        if not (0 <= x < w and 0 <= y < h):
            return None
        block = blocks[y * w + x]
        mid = block & MAPGRID_METATILE_ID_MASK
        return {
            "metatile": mid,
            "collision": (block & MAPGRID_COLLISION_MASK) >> MAPGRID_COLLISION_SHIFT,
            "elevation": (block & MAPGRID_ELEVATION_MASK) >> MAPGRID_ELEVATION_SHIFT,
            "behavior": self.behaviors(layout_id)[mid],
        }


def load_relocations(map_name):
    """localId -> (x, y) from the map's own scripts.inc `setobjectxyperm` calls.

    `.set LOCALID_FOO, n` lines give the symbolic ids; a literal id is accepted too. When a
    localId is relocated more than once the LAST call wins, matching script order.
    """
    path = os.path.join(ROOT, "data/maps", map_name, "scripts.inc")
    if not os.path.exists(path):
        return {}
    src = open(path, encoding="utf-8", errors="replace").read()
    consts = {m.group(1): int(m.group(2), 0)
              for m in re.finditer(r"^\s*\.set\s+(LOCALID_\w+)\s*,\s*(\w+)", src, re.M)}
    out = {}
    for m in re.finditer(r"^\s*setobjectxyperm\s+(\w+)\s*,\s*(-?\w+)\s*,\s*(-?\w+)", src, re.M):
        tok = m.group(1)
        lid = consts.get(tok)
        if lid is None:
            try:
                lid = int(tok, 0)
            except ValueError:
                continue  # a var/constant we cannot resolve statically
        try:
            out[lid] = (int(m.group(2), 0), int(m.group(3), 0))
        except ValueError:
            continue
    return out


SCRIPT_DRIVERS = ("applymovement", "applymovement2", "waitmovement", "removeobject", "addobject",
                  "setobjectxyperm", "setobjectmovementtype", "turnobject", "showobjectat",
                  "hideobjectat", "copyobjectxytoperm", "setobjectsubpriority")


def script_driven_localids(map_name):
    """localIds this map's scripts move, spawn, or despawn.

    Such an object is a cutscene actor, not a companion the player walks up to - Lance's Dragonite
    in the Rocket hideout is `applymovement`ed across three rooms and then `removeobject`ed, and his
    three Electrode are removed outright. Giving those a talk script would be wrong, so they are
    exempt from the indoor-mons-are-scripted rule.
    """
    path = os.path.join(ROOT, "data/maps", map_name, "scripts.inc")
    if not os.path.exists(path):
        return set()
    src = open(path, encoding="utf-8", errors="replace").read()
    consts = {m.group(1): int(m.group(2), 0)
              for m in re.finditer(r"^\s*\.set\s+(LOCALID_\w+)\s*,\s*(\w+)", src, re.M)}
    out = set()
    for m in re.finditer(r"^\s*(%s)\s+(\w+)" % "|".join(SCRIPT_DRIVERS), src, re.M):
        tok = m.group(2)
        if tok in consts:
            out.add(consts[tok])
        else:
            try:
                out.add(int(tok, 0))
            except ValueError:
                pass
    return out


def collect_placements(layouts):
    """Every OW-mon object event in the tree, classified. -> list of dicts."""
    rows = []
    for map_json in sorted(glob.glob(os.path.join(ROOT, "data/maps/*/map.json"))):
        data = json.load(open(map_json, encoding="utf-8"))
        objs = data.get("object_events") or []
        if not any(o.get("graphics_id", "").startswith(("OBJ_EVENT_GFX_OW_MON",
                                                        "OBJ_EVENT_GFX_SPECIES"))
                   for o in objs):
            continue
        map_name = os.path.basename(os.path.dirname(map_json))
        layout_id = data["layout"]
        if layout_id not in layouts.by_id:
            die(f"{map_name}: unknown layout {layout_id}")
        relocations = load_relocations(map_name)
        driven = script_driven_localids(map_name)
        for i, o in enumerate(objs):
            gfx = o.get("graphics_id", "")
            if not gfx.startswith(("OBJ_EVENT_GFX_OW_MON", "OBJ_EVENT_GFX_SPECIES")):
                continue
            local_id = o.get("local_id", i + 1)
            moved = relocations.get(local_id)
            rx, ry = moved if moved else (o["x"], o["y"])
            tile = layouts.tile(layout_id, rx, ry)
            neighbours = [layouts.tile(layout_id, rx + dx, ry + dy)
                          for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0))]
            species = None
            m = SPECIES_GFX.match(gfx)
            if m:
                species = m.group(1)
            rows.append({
                "map": map_name,
                "map_type": data.get("map_type", ""),
                "layout": layout_id,
                "index": i,
                "local_id": local_id,
                "gfx": gfx,
                "species": species,
                "x": o["x"], "y": o["y"],
                "runtime_x": rx, "runtime_y": ry,
                "relocated": bool(moved),
                "elevation": o.get("elevation", 0),
                "flag": str(o.get("flag", "0")),
                "script": str(o.get("script", "NULL")),
                "movement_type": o.get("movement_type", ""),
                "script_driven": local_id in driven,
                "tile": tile,
                "behavior_trusted": layout_id not in layouts.untrusted_layouts,
                "reachable": (tile is not None
                              and (tile["collision"] == 0
                                   or any(n is not None and n["collision"] == 0
                                          for n in neighbours))),
            })
    if len(rows) < MIN_PLACEMENTS:
        die(f"only {len(rows)} OW-mon placements found (expected >= {MIN_PLACEMENTS}) - "
            f"the glob or the graphics_id match drifted, so every rule below would pass vacuously")
    return rows


# ---------------------------------------------------------------------------
# Rules
# ---------------------------------------------------------------------------

def validate(rows, encounter_behaviors, have_overworld, species_family, disabled_families):
    v = []

    def add(row, rule, msg):
        v.append(f"{row['map']} object {row['index'] + 1} "
                 f"({row['gfx']} @ {row['x']},{row['y']}): [{rule}] {msg}")

    # 1. The placeholder id renders as garbage - it must not exist anywhere.
    for r in rows:
        if r["gfx"] == "OBJ_EVENT_GFX_OW_MON":
            add(r, "placeholder-gfx",
                "OBJ_EVENT_GFX_OW_MON has no OBJ_EVENT_MON bit, so it draws "
                "gObjectEventGraphicsInfo_Follower with no tiles or palette loaded. Use "
                "OBJ_EVENT_GFX_SPECIES(<SPECIES>).")
            continue

        # 2. A species with no OVERWORLD() silently renders as a Substitute doll
        #    (OW_SUBSTITUTE_PLACEHOLDER == TRUE), and a disabled family is a Gen 1-3 keep-rule break.
        sid = f"SPECIES_{r['species']}"
        if sid not in have_overworld:
            add(r, "no-overworld-gfx",
                f"{sid} has no OVERWORLD(...) entry - renders as a Substitute doll.")
        fam = species_family.get(sid)
        if fam is None:
            add(r, "unknown-species", f"{sid} is not defined in gen_*_families.h.")
        elif fam in disabled_families:
            add(r, "disabled-family", f"{sid} belongs to {fam}, which is FALSE.")

        # 3. In bounds at the RUNTIME position.
        if r["tile"] is None:
            where = "runtime position" if r["relocated"] else "map.json position"
            add(r, "out-of-layout",
                f"({r['runtime_x']},{r['runtime_y']}) is outside {r['layout']} ({where}).")
            continue

        # 4. Reachable: collision 0, or at least one orthogonal collision-0 neighbour.
        if not r["reachable"]:
            add(r, "unreachable",
                f"({r['runtime_x']},{r['runtime_y']}) is collision "
                f"{r['tile']['collision']} with no walkable orthogonal neighbour - the player can "
                f"never face it.")

        # 5. Elevation must match the tile it stands on. ELEVATION_TRANSITION (0) is what the
        #    fork's own generated spawner refuses outright (wild_encounter_ow.c:1203).
        if r["elevation"] != r["tile"]["elevation"]:
            add(r, "elevation",
                f"elevation {r['elevation']} but tile ({r['runtime_x']},{r['runtime_y']}) is "
                f"elevation {r['tile']['elevation']}.")

        # 6. Indoors, a mon is a companion the player walks up to, so it needs a script. Outdoors
        #    (routes, caves, cities - MAP_TYPE_UNDERGROUND counts as outdoor) they are scenery and
        #    script: NULL is correct. Cutscene actors are exempt: they are driven, not talked to.
        if (r["map_type"] == "MAP_TYPE_INDOOR" and r["script"] in ("NULL", "0x0")
                and not r["script_driven"]):
            add(r, "indoor-unscripted",
                "an indoor overworld Pokemon needs a script - it is a companion the player will "
                "walk up to, not route scenery. Cutscene actors are exempt.")

    # 7. No two simultaneously-visible mons on one tile. A {DAY, NIGHT} pair is fine: exactly one
    #    side is ever visible.
    by_tile = {}
    for r in rows:
        if r["tile"] is None:
            continue
        by_tile.setdefault((r["map"], r["runtime_x"], r["runtime_y"]), []).append(r)
    for (map_name, x, y), group in sorted(by_tile.items()):
        if len(group) < 2:
            continue
        flags = {g["flag"] for g in group}
        if len(group) == 2 and flags == DAY_NIGHT:
            continue
        ids = ", ".join(str(g["index"] + 1) for g in group)
        v.append(f"{map_name} tile ({x},{y}): [stacked] {len(group)} overworld Pokemon share it "
                 f"(objects {ids}; flags {sorted(flags)}). Only a "
                 f"{{FLAG_DAY_POKEMON, FLAG_NIGHT_POKEMON}} pair may overlap.")
    return v


def report(rows, encounter_behaviors, behavior_names):
    by_value = {}
    for name, val in behavior_names.items():
        by_value.setdefault(val, name)
    cols = ["map", "map_type", "index", "local_id", "gfx", "x", "y", "runtime_x", "runtime_y",
            "relocated", "elevation", "tile_elevation", "collision", "behavior", "encounter_tile",
            "behavior_trusted", "reachable", "script_driven", "flag", "script"]
    print(",".join(cols))
    for r in rows:
        t = r["tile"]
        print(",".join(str(c) for c in [
            r["map"], r["map_type"], r["index"] + 1, r["local_id"], r["gfx"], r["x"], r["y"],
            r["runtime_x"], r["runtime_y"], int(r["relocated"]), r["elevation"],
            t["elevation"] if t else -1, t["collision"] if t else -1,
            by_value.get(t["behavior"], t["behavior"]) if t else "OUT_OF_BOUNDS",
            int(t["behavior"] in encounter_behaviors) if t else -1,
            int(r["behavior_trusted"]), int(r["reachable"]), int(r["script_driven"]),
            r["flag"], r["script"],
        ]))


def main():
    behavior_names = load_behavior_names()
    encounter_behaviors = load_encounter_behaviors(behavior_names)
    have_overworld, species_family = load_overworld_species()
    disabled_families = load_disabled_families()
    tileset_files = load_tileset_attributes()
    tileset_widths = check_attribute_widths(tileset_files)
    layouts = Layouts(tileset_files, tileset_widths)
    rows = collect_placements(layouts)

    if layouts.untrusted_layouts:
        print("FAIL - metatile behaviours could not be resolved for "
              f"{len(layouts.untrusted_layouts)} layout(s): "
              f"{', '.join(sorted(layouts.untrusted_layouts))}")
        return 1

    if "--report" in sys.argv:
        report(rows, encounter_behaviors, behavior_names)
        return 0

    violations = validate(rows, encounter_behaviors, have_overworld, species_family,
                          disabled_families)
    if violations:
        print(f"FAIL - {len(violations)} overworld-Pokemon placement violation(s) "
              f"across {len({v.split()[0] for v in violations})} map(s):")
        for line in violations:
            print(f"  {line}")
        return 1
    maps = len({r["map"] for r in rows})
    print(f"OK - {len(rows)} overworld Pokemon across {maps} maps: real species graphics, "
          f"in bounds, reachable, elevation matches the tile, indoor ones scripted, none stacked.")
    # Print the census rather than just "widths ok": a count is the only thing that distinguishes a
    # real pass from a parse that found nothing, and TILESET_METATILES makes these the widths the
    # ROM will actually read at.
    u32 = sum(1 for w in tileset_widths.values() if w == 4)
    print(f"OK - {len(tileset_widths)} tilesets declare a derivable attribute width "
          f"({u32} FRLG u32, {len(tileset_widths) - u32} Emerald u16), all via TILESET_METATILES.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
