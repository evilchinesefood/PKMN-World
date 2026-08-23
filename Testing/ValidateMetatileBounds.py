#!/usr/bin/env python3
"""Metatile-bounds ratchet for map blockdata (issue #93).

Why this exists
---------------
`DrawMetatileAt` (src/field_camera.c) is the only thing that stands between a bad id in
`map.bin` and the tile that gets drawn, and its single guard is:

    if (metatileId > NUM_METATILES_TOTAL)   // 1024
        metatileId = 0;
    if (metatileId < GetNumMetatilesInPrimary(mapLayout))
        metatiles = mapLayout->primaryTileset->metatiles;
    else
        metatiles = mapLayout->secondaryTileset->metatiles, metatileId -= ...;
    DrawMetatile(..., metatiles + metatileId * NUM_TILES_PER_METATILE, offset);

Note what is NOT checked: the tileset's own length. `metatiles` is a plain `const u16 *` into
`.rodata`, so any id that survives the `> 1024` test indexes it unconditionally. An id that is
in range for the *split* but past the end of the tileset reads whatever symbol the linker put
next and draws it. That is not theoretical here -- issue #93 traced Johto Victory Road to
`gMetatiles_General` being followed immediately by `gMetatiles_SecretBaseSecondary`, so three
cave floors drew Secret Base blocks. 1989 of 1F's 2070 tiles were affected and the game never
complained once.

Nothing else in the tree can see this. It builds, links and boots; the map just looks wrong,
and only if you walk to it. `ValidateDoorAnims.py`'s unresolved-warp count is a partial proxy
and its own comment says so: it sees a bad id only when that id happens to land on a warp tile.

What this checks
----------------
Two conditions, per layout, over BOTH `map.bin` and `border.bin` (the border is drawn by
`GetBorderBlockAt` through the same `DrawMetatileAt`, so a bad id there is the same defect):

  OOB     - the id resolves past the end of the tileset it lands in. Reads `.rodata`. ERROR.
  BLANK   - the id resolves in bounds to a metatile whose 16 bytes are all zero. Draws nothing.
            REVIEW (see the severity note below).

Resolution mirrors the C exactly:

  split          = 512 for `layout_version: "emerald"`, else 640. `GetNumMetatilesInPrimary`
                   returns NUM_METATILES_IN_PRIMARY_FRLG (640) when `isFrlg || isJohto`, so
                   both the "frlg" and "johto" tags take the 640 path and only "emerald" is 512.
                   Those three are the only values that appear in layouts.json, and an unknown
                   fourth is a hard failure rather than a silent default.
  id             = halfword & MAPGRID_METATILE_ID_MASK (0x03FF); the top 6 bits are collision
                   and elevation.
  capacity       = filesize(metatiles.bin) // 16.
  id  < split    -> primary local id `id`,          out of bounds if id >= primary capacity
  id >= split    -> secondary local id `id - split`, out of bounds if that >= secondary capacity

Tileset symbol -> file is resolved in two hops, `src/data/tilesets/headers.h` (which names the
symbols) then `src/data/tilesets/metatiles.h` (which maps symbols to files), the same way
`ValidateOwMonPlacements.py` does it. Deriving the directory from the symbol name by
case-splitting silently mis-resolves the tilesets whose names already contain underscores
(`gTileset_Johto_General`, `gTileset_Cave_Ice`, ...), and a wrong file means a wrong capacity,
which means a wrong verdict in the safe-looking direction.

Why blank references are REVIEW and not an error
------------------------------------------------
Because well-formed vanilla maps use them constantly, and the numbers say so:

  * `gTileset_General` metatile 0 is all-zero, and dozens of layouts reference it -- the
    `UNUSED_CAVE*` and `UNUSED_CONTEST_ROOM*` rooms each place exactly one.
  * `gTileset_BuildingFrlg` has 201 blank metatiles in its 640 (a padded-out tileset), and the
    interior rooms built on it fill the dead space around the room with them. Mossdeep's
    e-Reader Trainer House 2F places 102 and Safari Zone Rest House 66 -- these are rectangles
    much bigger than the room drawn inside them, and the blank metatile IS the empty space.

So "references a blank metatile" is a smell, not a defect, and a gate nobody can get to zero
gets deleted. But it is a load-bearing smell: it is what actually caught #131. Mahogany Gym
placed local 0 of `gTileset_SootopolisGym` 250 times -- the entire gym floor -- for 285 blank
references against a repo-wide runner-up of 102, while vanilla Sootopolis Gym on the same
tileset has zero. A pure bounds check sees only 12 bad blocks there and would go green over a
39.6%-broken mandatory gym.

Hence the two-tier convention `ValidateMapEvents.py` established: errors are pinned at the
count the tree is at, reviews are pinned at the count the tree is at, and growth fails either
way. The difference is what an existing finding means, not how tightly it is held.

The ratchet, in both directions
-------------------------------
Both tables pin EXACT per-layout counts, and both directions of drift are reported:

  count > pinned   FAIL. A regression, or a new defect in a map that already had one.
  count < pinned   the fix landed. OOB fails (ratchet the number down in the same commit);
                   BLANK prints a non-failing STALE line, since it is progress and blank
                   counts move whenever anyone re-draws a room.
  count == 0       FAIL for both. A clean map with an entry is a permanent hole in the gate
                   that no longer costs anything to keep, which is exactly how stale
                   exemptions accumulate -- see `Testing/run-all.sh`'s header for the same
                   failure with `.PASS` sentinels.
  not in table     FAIL. This is the case the whole script is for.

Run from the repo root:  python3 Testing/ValidateMetatileBounds.py   (0 = clean, 1 = violations)
or `make validate`. Also run by Check.yml.

  --report   print the full census: every layout with any finding and the ids behind it, the
             tileset capacity table, and the aggregate totals. Fails nothing extra; this is
             the mode for triaging a new hit or re-deriving a baseline.
  --strict   promote the REVIEW tier to failures.
"""
import collections
import json
import os
import re
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

LAYOUTS_JSON = "data/layouts/layouts.json"
TILESET_HEADERS = "src/data/tilesets/headers.h"
TILESET_METATILES = "src/data/tilesets/metatiles.h"

METATILE_SIZE_BYTES = 16          # NUM_TILES_PER_METATILE (8) * sizeof(u16)
METATILE_ID_MASK = 0x03FF         # MAPGRID_METATILE_ID_MASK, include/global.fieldmap.h
NUM_METATILES_IN_PRIMARY = 512    # include/fieldmap.h
NUM_METATILES_IN_PRIMARY_FRLG = 640

# GetNumMetatilesInPrimary: `(isFrlg || isJohto) ? ..._FRLG : ...`. mapjson.cpp emits isFrlg for
# "frlg" and isJohto for "johto", so both take the 640 path and only "emerald" splits at 512.
SPLIT_BY_VERSION = {
    "emerald": NUM_METATILES_IN_PRIMARY,
    "frlg": NUM_METATILES_IN_PRIMARY_FRLG,
    "johto": NUM_METATILES_IN_PRIMARY_FRLG,
}

# A parse that finds nothing must fail rather than pass: every check below is a comparison that
# succeeds vacuously against empty tables, so a moved file or a drifted regex would turn this
# script into a no-op that still prints OK. Floors are set well under the real counts.
MIN_LAYOUTS = 900
MIN_TILESETS = 150
MIN_BLOCKS = 500000

# ------------------------------------------------------------------ OOB allowlist (ERROR tier)
#
# Every entry is a map that draws out of its tileset TODAY. The count is the gate: it must match
# exactly. Raising one needs a reason in the commit message; lowering one is the point.
#
# Format: layout id -> (exact count, issue, one-line reason)
OOB_ALLOWLIST = {
    # Untracked, found by sweeping every layout in layouts.json. Same wrong-tileset shape as
    # #125. All four are orphans -- no map.json references them -- which is why nothing has
    # ever surfaced them, and also why they are not urgent.
    "LAYOUT_RS_SAFARI_ZONE_SOUTHEAST": (74, "untracked",
                                        "gTileset_CinnabarIsland is 64; local ids reach 196"),
    "LAYOUT_RS_SAFARI_ZONE_ENTRANCE": (13, "untracked",
                                       "gTileset_Mart is 67; local ids reach 84"),
    "LAYOUT_RS_SAFARI_ZONE_NORTHEAST": (10, "untracked",
                                        "gTileset_CinnabarIsland is 64; local ids reach 167"),
    "LAYOUT_RS_SAFARI_ZONE_SOUTHWEST": (2, "untracked",
                                        "gTileset_CinnabarIsland is 64; local ids reach 153"),

    # Vanilla orphan. Its secondary_tileset is the literal string "0" -- a NULL pointer -- so
    # every id at or above the 512 split dereferences NULL, which is why the count is the whole
    # upper half of the map. Referenced by no map.json and never loaded. Kept as an allowlist
    # entry rather than a special case in the code because it is exactly the defect this script
    # describes, and if anything ever wires a map to this layout it should fail loudly.
    "LAYOUT_UNUSED_OUTDOOR_AREA": (1512, "untracked",
                                   "secondary_tileset is \"0\" (NULL); unreferenced vanilla orphan"),
}

# ------------------------------------------------------------- blank baseline (REVIEW tier)
#
# Counts of in-bounds references to an all-zero metatile. Most of these are legitimate empty
# space (see the module docstring) and are pinned only so the number cannot grow unnoticed.
# The one that is not legitimate is Mahogany.
BLANK_BASELINE = {
    # Interior rooms drawn on gTileset_BuildingFrlg, which has 201 blank metatiles in its 640.
    # The layout rectangle is much larger than the room inside it and the blank metatile is the
    # dead space around it. Legitimate.
    "LAYOUT_MOSSDEEP_CITY_EREADER_TRAINER_HOUSE_2F": 102,
    "LAYOUT_MOSSDEEP_CITY_EREADER_TRAINER_HOUSE_1F": 70,
    "LAYOUT_RS_SAFARI_ZONE_REST_HOUSE": 66,
    "LAYOUT_RS_BATTLE_TOWER": 22,
    "LAYOUT_JOHTO_POKEMON_LEAGUE_CHAMPIONS_ROOM": 15,

    # The four RS Safari Zone orphans, which are mis-wired on the OOB side as well.
    "LAYOUT_RS_SAFARI_ZONE_NORTHEAST": 12,
    "LAYOUT_RS_SAFARI_ZONE_ENTRANCE": 11,
    "LAYOUT_RS_SAFARI_ZONE_SOUTHWEST": 3,
    "LAYOUT_RS_SAFARI_ZONE_SOUTHEAST": 2,

    # Single-blank rooms: one placement of an all-zero metatile, almost always local 0, which is
    # blank in gTileset_General, gTileset_Building and most secondaries. Unused/debug layouts
    # and one corner tile each, except the two named below.
    "LAYOUT_BATTLE_FRONTIER_BATTLE_PIKE_ROOM_UNUSED": 2,
    "LAYOUT_UNUSED_CONTEST_ROOM1": 1,
    "LAYOUT_UNUSED_CONTEST_ROOM2": 1,
    "LAYOUT_UNUSED_CONTEST_ROOM3": 1,
    "LAYOUT_UNUSED_CAVE1": 1,
    "LAYOUT_UNUSED_CAVE2": 1,
    "LAYOUT_UNUSED_CAVE3": 1,
    "LAYOUT_UNUSED_CAVE4": 1,
    "LAYOUT_UNUSED_CAVE5": 1,
    "LAYOUT_UNUSED_CAVE6": 1,
    "LAYOUT_UNUSED_CAVE7": 1,
    "LAYOUT_UNUSED_CAVE8": 1,
    "LAYOUT_UNUSED_CAVE9": 1,
    "LAYOUT_UNUSED_CAVE10": 1,
    "LAYOUT_UNUSED_CAVE11": 1,
    "LAYOUT_UNUSED_CAVE12": 1,
    "LAYOUT_UNUSED_CAVE13": 1,
    "LAYOUT_UNUSED_CAVE14": 1,
    "LAYOUT_CAVE_OF_ORIGIN_UNUSED_B4F_LAVA": 1,

    # These two are live maps rather than unused ones, and both are a single tile: Birch's lab
    # variant places gTileset_Building local 0, and the Johto Hall of Fame places local 55 of
    # gTileset_HallOfFame. One blank tile is a cosmetic hole at worst, but they are pinned so
    # that a mis-wired tileset on either -- which is what one blank turning into hundreds looks
    # like -- cannot land quietly.
    "LAYOUT_LITTLEROOT_TOWN_PROFESSOR_BIRCHS_LAB_WITH_TABLE": 1,
    "LAYOUT_JOHTO_POKEMON_LEAGUE_HALL_OF_FAME": 1,
}


def die(msg):
    print(f"FAIL - {msg}")
    sys.exit(1)


def read(rel):
    path = os.path.join(ROOT, rel)
    if not os.path.exists(path):
        die(f"{rel} is missing -- has it moved?")
    with open(path, encoding="utf-8") as fh:
        return fh.read()


# ---------------------------------------------------------------- loading

def load_tileset_metatiles():
    """gTileset_X -> metatiles.bin path, via headers.h then metatiles.h.

    Both hops are required. headers.h names the SYMBOL each tileset draws from; only metatiles.h
    knows which file that symbol is INCBIN'd from, and the directory is not derivable from the
    symbol name -- `gMetatiles_SecretBasePrimary` lives in `primary/secret_base/`, and the
    tilesets whose names already contain underscores break any case-splitting rule outright.
    """
    symbol_to_file = {}
    for m in re.finditer(r"const\s+u(?:16|32)\s+(gMetatiles?_\w+)\[\]\s*=\s*"
                         r"INCBIN_U(?:16|32)\(\"([^\"]+)\"\)", read(TILESET_METATILES)):
        symbol_to_file[m.group(1)] = m.group(2)
    if not symbol_to_file:
        die(f"no gMetatiles_* INCBIN rows parsed from {TILESET_METATILES}")

    out = {}
    for m in re.finditer(r"const\s+struct\s+Tileset\s+(gTileset_\w+)\s*=\s*\{(.*?)\n\};",
                         read(TILESET_HEADERS), re.S):
        name, body = m.group(1), m.group(2)
        pair = re.search(r"TILESET_METATILES\(\s*(gMetatiles_\w+)\s*,", body)
        if not pair:
            bare = re.search(r"\.metatiles\s*=\s*(gMetatiles_\w+)", body)
            if not bare:
                continue
            pair = bare
        symbol = pair.group(1)
        if symbol not in symbol_to_file:
            die(f"{name} draws from {symbol}, which {TILESET_METATILES} does not define")
        out[name] = symbol_to_file[symbol]
    if len(out) < MIN_TILESETS:
        die(f"parsed only {len(out)} tilesets from {TILESET_HEADERS} (expected >= "
            f"{MIN_TILESETS}) -- every bounds test below would pass vacuously")
    return out


class Tilesets:
    """Capacity and blank-metatile set per tileset, read once from the .bin files.

    A tileset named "0" in layouts.json is a NULL pointer in the generated layout struct, not a
    tileset: capacity 0, so every id that resolves into it is out of bounds. That is the correct
    answer -- the hardware would dereference NULL -- and it keeps the NULL case inside the same
    rule instead of an exception nobody reads.
    """

    def __init__(self, files):
        self.files = files
        self.cache = {}

    def get(self, name):
        if name in self.cache:
            return self.cache[name]
        if name in ("0", "NULL", ""):
            self.cache[name] = (0, frozenset())
            return self.cache[name]
        rel = self.files.get(name)
        if rel is None:
            die(f"layouts.json names tileset {name}, which {TILESET_HEADERS} does not define")
        path = os.path.join(ROOT, rel)
        if not os.path.exists(path):
            die(f"metatiles blob missing: {rel} (for {name})")
        with open(path, "rb") as fh:
            blob = fh.read()
        if not blob or len(blob) % METATILE_SIZE_BYTES:
            die(f"{rel} ({name}) is {len(blob)} bytes, not a non-zero multiple of "
                f"{METATILE_SIZE_BYTES} -- its metatile count is not well defined")
        count = len(blob) // METATILE_SIZE_BYTES
        zero = b"\0" * METATILE_SIZE_BYTES
        blank = frozenset(i for i in range(count)
                          if blob[i * METATILE_SIZE_BYTES:(i + 1) * METATILE_SIZE_BYTES] == zero)
        self.cache[name] = (count, blank)
        return self.cache[name]


def load_layouts():
    data = json.loads(read(LAYOUTS_JSON))
    layouts = data.get("layouts")
    if not isinstance(layouts, list) or len(layouts) < MIN_LAYOUTS:
        die(f"parsed only {len(layouts or [])} layouts from {LAYOUTS_JSON} (expected >= "
            f"{MIN_LAYOUTS})")
    return layouts


# ---------------------------------------------------------------- the scan

class Finding:
    __slots__ = ("layout", "version", "split", "primary", "primary_cap", "secondary",
                 "secondary_cap", "oob", "blank", "blocks")

    def __init__(self, **kw):
        for k, v in kw.items():
            setattr(self, k, v)

    @property
    def oob_count(self):
        return sum(self.oob.values())

    @property
    def blank_count(self):
        return sum(self.blank.values())

    def tilesets(self):
        return (f"{self.primary}({self.primary_cap}) + {self.secondary}({self.secondary_cap}) "
                f"@ split {self.split}")

    def ids(self, counter, limit=8):
        """`id -> local id in the tileset it lands in` x N placements, worst first."""
        parts = []
        for mid, n in sorted(counter.items(), key=lambda kv: (-kv[1], kv[0]))[:limit]:
            where = "P" if mid < self.split else "S"
            local = mid if mid < self.split else mid - self.split
            parts.append(f"{mid}={where}[{local}]x{n}")
        if len(counter) > limit:
            parts.append(f"+{len(counter) - limit} more")
        return " ".join(parts)


def scan(layouts, tilesets):
    """Decode every layout's blockdata and border against its own two tilesets."""
    findings, blocks, files = [], 0, 0
    for layout in layouts:
        lid = layout.get("id")
        version = layout.get("layout_version")
        if version not in SPLIT_BY_VERSION:
            die(f"{lid} has layout_version {version!r}, which this script has no split for. "
                f"GetNumMetatilesInPrimary keys off isFrlg/isJohto; add the mapping to "
                f"SPLIT_BY_VERSION after checking which of those mapjson.cpp emits for it.")
        split = SPLIT_BY_VERSION[version]
        primary, secondary = layout["primary_tileset"], layout["secondary_tileset"]
        primary_cap, primary_blank = tilesets.get(primary)
        secondary_cap, secondary_blank = tilesets.get(secondary)

        oob, blank, seen = collections.Counter(), collections.Counter(), 0
        for key in ("blockdata_filepath", "border_filepath"):
            rel = layout.get(key)
            if not rel:
                die(f"{lid} has no {key} -- half of its drawn tiles would go unchecked")
            path = os.path.join(ROOT, rel)
            if not os.path.exists(path):
                die(f"{lid}: {rel} is missing")
            with open(path, "rb") as fh:
                data = fh.read()
            if len(data) % 2:
                die(f"{lid}: {rel} is {len(data)} bytes, not a whole number of u16 blocks")
            files += 1
            for (word,) in struct.iter_unpack("<H", data):
                seen += 1
                mid = word & METATILE_ID_MASK
                if mid < split:
                    if mid >= primary_cap:
                        oob[mid] += 1
                    elif mid in primary_blank:
                        blank[mid] += 1
                else:
                    local = mid - split
                    if local >= secondary_cap:
                        oob[mid] += 1
                    elif local in secondary_blank:
                        blank[mid] += 1
        blocks += seen
        if oob or blank:
            findings.append(Finding(layout=lid, version=version, split=split, primary=primary,
                                    primary_cap=primary_cap, secondary=secondary,
                                    secondary_cap=secondary_cap, oob=oob, blank=blank,
                                    blocks=seen))
    if blocks < MIN_BLOCKS:
        die(f"decoded only {blocks} blocks from {files} files (expected >= {MIN_BLOCKS}) -- "
            f"the blockdata paths in {LAYOUTS_JSON} are not resolving")
    return findings, blocks, files


# ---------------------------------------------------------------- gates

def gate(findings, table, attr, tier, what):
    """Compare each layout's count against its pinned count. Returns (failures, notices).

    Both directions matter. Over the pin is a regression. Under it is either a fix that needs
    the number ratcheted (OOB, hard) or ordinary map churn (BLANK, soft). At zero the entry is a
    hole in the gate that costs nothing to keep, so it always fails -- that is how stale
    exemptions survive, and this repo has been bitten by exactly that with .PASS sentinels.
    """
    failures, notices = [], []
    counts = {}
    for f in findings:
        counter = getattr(f, attr)
        if counter:
            counts[f.layout] = (sum(counter.values()), f, counter)

    for lid, (n, f, counter) in sorted(counts.items(), key=lambda kv: -kv[1][0]):
        entry = table.get(lid)
        pinned = entry[0] if isinstance(entry, tuple) else entry
        detail = f"{f.tilesets()}  ids: {f.ids(counter)}"
        if pinned is None:
            failures.append(f"{lid}: {n} {what} reference(s), not in the table. {detail}")
        elif n > pinned:
            failures.append(f"{lid}: {n} {what} reference(s), pinned at {pinned} "
                            f"(+{n - pinned}). {detail}")
        elif n < pinned:
            msg = (f"{lid}: {n} {what} reference(s), pinned at {pinned} -- {pinned - n} fixed. "
                   f"Ratchet the number down to {n}.")
            (failures if tier == "ERROR" else notices).append(msg)

    for lid, entry in sorted(table.items()):
        if lid not in counts:
            pinned = entry[0] if isinstance(entry, tuple) else entry
            failures.append(f"{lid}: pinned at {pinned} {what} reference(s) but is now CLEAN. "
                            f"Delete this entry -- an exemption for a map that no longer needs "
                            f"one is a permanent hole in this gate.")
    return failures, notices


# ---------------------------------------------------------------- main

def main():
    report = "--report" in sys.argv
    strict = "--strict" in sys.argv

    layouts = load_layouts()
    tilesets = Tilesets(load_tileset_metatiles())
    findings, blocks, files = scan(layouts, tilesets)

    oob_fail, _ = gate(findings, OOB_ALLOWLIST, "oob", "ERROR", "out-of-bounds")
    blank_fail, blank_notice = gate(findings, BLANK_BASELINE, "blank", "REVIEW", "blank")

    if report:
        oob_total = sum(f.oob_count for f in findings)
        blank_total = sum(f.blank_count for f in findings)
        print(f"-- census: {len(layouts)} layouts, {files} blockdata/border files, {blocks} "
              f"blocks decoded, {len(tilesets.files)} tilesets resolved")
        print(f"-- {len(findings)} layout(s) carry a finding: {oob_total} out-of-bounds and "
              f"{blank_total} blank reference(s) in total")
        print(f"-- {sum(1 for f in findings if f.oob_count)} with OOB, "
              f"{sum(1 for f in findings if f.blank_count)} with blank")
        by_version = collections.Counter(l["layout_version"] for l in layouts)
        print("-- splits: " + ", ".join(f"{v}={by_version[v]} layouts @ {SPLIT_BY_VERSION[v]}"
                                        for v in sorted(by_version)))
        print(f"\n{'layout':47s} {'ver':8s} {'OOB':>5s} {'pin':>5s} {'BLANK':>6s} {'pin':>5s}  "
              f"tilesets")
        for f in sorted(findings, key=lambda f: (-f.oob_count, -f.blank_count)):
            oe = OOB_ALLOWLIST.get(f.layout)
            op = str(oe[0]) if oe else "-"
            bp = str(BLANK_BASELINE.get(f.layout, "-"))
            print(f"{f.layout:47s} {f.version:8s} {f.oob_count:5d} {op:>5s} "
                  f"{f.blank_count:6d} {bp:>5s}  {f.tilesets()}")
            if f.oob_count:
                print(f"{'':47s} OOB   ids: {f.ids(f.oob, 12)}")
            if f.blank_count:
                print(f"{'':47s} BLANK ids: {f.ids(f.blank, 12)}")
        print("\n-- tileset capacities referenced by a layout with a finding:")
        used = sorted({t for f in findings for t in (f.primary, f.secondary)})
        for name in used:
            cap, blank = tilesets.get(name)
            print(f"     {name:34s} {cap:4d} metatiles, {len(blank):4d} blank")
        print()

    failed = 0
    if oob_fail:
        failed += len(oob_fail)
        print(f"FAIL - OUT-OF-BOUNDS: {len(oob_fail)} layout(s) disagree with OOB_ALLOWLIST")
        for line in oob_fail:
            print(f"    {line}")

    review_failed = 0
    if blank_fail:
        review_failed += len(blank_fail)
        print(f"FAIL - BLANK-METATILE: {len(blank_fail)} layout(s) disagree with BLANK_BASELINE")
        for line in blank_fail:
            print(f"    {line}")
    if blank_notice:
        print(f"{'FAIL' if strict else 'REVIEW'} - BLANK-METATILE: {len(blank_notice)} baseline(s) "
              f"now stale in the good direction")
        for line in blank_notice:
            print(f"    {line}")
        if strict:
            review_failed += len(blank_notice)

    if failed or review_failed:
        print(f"\nFAIL - {failed} out-of-bounds violation(s) and {review_failed} blank-reference "
              f"violation(s) against the pinned counts.")
        return 1

    allow_oob = sum(e[0] for e in OOB_ALLOWLIST.values())
    allow_blank = sum(BLANK_BASELINE.values())
    print(f"OK - {blocks} blocks across {len(layouts)} layouts decoded against their own "
          f"tilesets: every metatile id resolves inside the tileset it lands in, except the "
          f"{allow_oob} placement(s) in {len(OOB_ALLOWLIST)} allowlisted layout(s).")
    print(f"REVIEW - {allow_blank} blank-metatile reference(s) across {len(BLANK_BASELINE)} "
          f"layout(s), all at baseline (--report to list, --strict to fail on them).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
