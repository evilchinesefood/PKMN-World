#!/usr/bin/env python3
"""Prove every tileset declares enough palette slots for the code that reads them.

A tileset's palettes are a `const u16 (*)[16]` -- a pointer to rows of 16 colours,
with NO length attached. Nothing in the build knows how many rows are really there:
`gTilesetPalettes_Foo[][16]` decays to a pointer the moment it is stored in a
struct Tileset, so a tileset whose array is one row short compiles, links and boots
exactly like a correct one. The damage shows up as the loader memcpy'ing whatever
.rodata happens to follow the array into the BG palette buffer -- a map whose
colours are subtly (or spectacularly) wrong, on a map you may not visit for hours,
with no crash and no diagnostic to tie it back to the edit that caused it.

So the bound has to be checked in source, which is what this does.

WHERE THE BOUNDS COME FROM (all three readers, in src/, not invented here):

  1. LoadPrimaryTilesetPalette -> LoadTilesetPalette (src/fieldmap.c)
     A PRIMARY is copied as `tileset->palettes` for numPalsInPrimary rows, i.e. it
     reads rows 0 .. numPalsInPrimary-1. GetNumPalsInPrimary(mapLayout) returns
     NUM_PALS_IN_PRIMARY_FRLG for an isFrlg||isJohto layout and NUM_PALS_IN_PRIMARY
     otherwise, so the larger of the two is the bound any primary must satisfy --
     a primary is one layouts.json edit away from being paired with a Johto layout,
     and that edit must not be able to turn into a silent overread.

  2. LoadSecondaryTilesetPalette -> LoadTilesetPalette (src/fieldmap.c)
     A SECONDARY is copied from `tileset->palettes[numPalsInPrimary]` for
     (NUM_PALS_TOTAL - numPalsInPrimary) * PLTT_SIZE_4BPP bytes, i.e. it reads rows
     numPalsInPrimary .. NUM_PALS_TOTAL-1. The START moves with the regime but the
     END does not: the last row touched is NUM_PALS_TOTAL-1 either way, so every
     secondary needs NUM_PALS_TOTAL rows. Note what that means -- the FRLG regime
     reads a NARROWER span (7..12) than Emerald (6..12), not a higher one.

  3. UpdateAltBgPalettes (src/overworld.c)
     This is the only reader that can index ABOVE NUM_PALS_TOTAL. It blends palette
     i against its alternate at row (i + 9) % 16, so it reaches rows 13, 14 and 15 --
     which is why the arrays are declared [][16] in the first place. It is gated:
     a row is only blended if the owning tileset's `swapPalettes` bitmask opts it in
     (primary bits are palette numbers; secondary bits are offset by numPalsInPrimary),
     and PALETTES_MAP ^ (1 << 0) caps the loop at palette 12 and excludes palette 0.
     So a tileset that sets swapPalettes needs however far its own set bits reach,
     and that can be all 16 rows.

WHY IT IS A GATE AND NOT A "PAD EVERYTHING TO 16" CONVENTION:

  Today 52 of the arrays declare exactly NUM_PALS_TOTAL rows and the rest declare 16.
  The 52 are CORRECT, not lagging: none of them sets swapPalettes, so nothing ever
  reads past row 12, and padding them to 16 would add ~5KB of ROM holding colours no
  code path can reach. The invariant is "declare what your readers reach", not
  "declare the maximum" -- and an invariant with a threshold that moves per tileset
  is exactly the kind that rots without a machine checking it.

ISSUE #94, AND WHY ITS PREMISE IS RECORDED HERE AS WRONG:

  #94 reported that the loader "copies slots 7..15", and concluded that the 52
  thirteen-entry arrays were therefore overrun. That premise is wrong. The secondary
  copy is (NUM_PALS_TOTAL - numPalsInPrimary) rows starting at numPalsInPrimary, so
  it copies 7..12 in the FRLG/Johto regime and 6..12 in the Emerald one -- 12 is the
  last row, never 15. The 13-entry arrays are fine and #94's proposed fix (pad them)
  would have been ~5KB of dead ROM chasing a bound that does not exist. Rows 13..15
  exist for UpdateAltBgPalettes' alternate-palette blend alone.

  That correction is the reason this file exists rather than a comment somewhere:
  the real bound was re-derived by hand at least twice and came out wrong once. It
  is cheaper to have it computed from the tree on every push than to re-read three
  loaders each time someone adds a tileset.

Everything this script needs is derived from the tree, never assumed:

  * NUM_PALS_IN_PRIMARY / _FRLG / NUM_PALS_TOTAL, from include/fieldmap.h
  * PALETTES_MAP, from include/palette.h -- it is what caps the blend loop
  * the alternate-palette offset and modulus ((i + 9) % 16), read out of
    UpdateAltBgPalettes in src/overworld.c rather than typed in here
  * every tileset's isSecondary / swapPalettes / palettes symbol, from
    src/data/tilesets/headers.h
  * every palette array's real row count, by counting INCGFX_U16 entries in
    src/data/tilesets/graphics.h and src/graphics.c (gTilesetPalettes_General lives
    in graphics.c, in ALIGNED(4) form, and is counted the same way as the rest)
  * which regime each tileset is actually used in, from the layout_version of the
    layouts in data/layouts/layouts.json that name it

Usage:
    python3 Testing/ValidateTilesetPalettes.py [--root DIR] [--verbose]

Exits 0 when clean, 1 when a tileset is short, 2 when the tree could not be parsed
(which is also a failure -- a parse that finds nothing must never look like a pass).
"""

import argparse
import json
import os
import re
import sys
from collections import defaultdict

BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.S)
LINE_COMMENT = re.compile(r"//[^\n]*")


def strip_c_comments(text):
    return LINE_COMMENT.sub("", BLOCK_COMMENT.sub("", text))


def read_text(path):
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
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
        r"^\s*#define\s+(" + re.escape(prefix) + r"\w*)\s+"
        r"\(?\s*(0[xX][0-9A-Fa-f]+|\d+)\s*\)?\s*$"
    )
    for line in read_text(path).splitlines():
        line = LINE_COMMENT.sub("", line)
        m = pat.match(line)
        if m:
            out[m.group(1)] = int(m.group(2), 0)
    return out


def parse_pal_counts(root):
    """NUM_PALS_IN_PRIMARY / _FRLG / NUM_PALS_TOTAL from include/fieldmap.h."""
    path = os.path.join(root, "include", "fieldmap.h")
    if not os.path.exists(path):
        raise Fatal("missing %s" % path)
    d = parse_define_ints(path, "NUM_PALS_")
    need = ("NUM_PALS_IN_PRIMARY", "NUM_PALS_IN_PRIMARY_FRLG", "NUM_PALS_TOTAL")
    for key in need:
        if key not in d:
            raise Fatal("could not find %s in %s" % (key, path))
    return d["NUM_PALS_IN_PRIMARY"], d["NUM_PALS_IN_PRIMARY_FRLG"], d["NUM_PALS_TOTAL"]


def parse_palettes_map(root):
    """PALETTES_MAP from include/palette.h. UpdateAltBgPalettes ANDs the blend mask
    with `PALETTES_MAP ^ (1 << 0)`, so this is what decides the HIGHEST palette the
    alternate-palette blend can ever touch -- not a hard-coded 12 here."""
    path = os.path.join(root, "include", "palette.h")
    if not os.path.exists(path):
        raise Fatal("missing %s" % path)
    d = parse_define_ints(path, "PALETTES_MAP")
    if "PALETTES_MAP" not in d:
        raise Fatal("could not find PALETTES_MAP in %s" % path)
    return d["PALETTES_MAP"]


def parse_alt_pal_math(root):
    """The `(i + 9) % 16` in UpdateAltBgPalettes (src/overworld.c).

    Read rather than typed in, because the whole point of rows 13..15 is this one
    expression. If someone retunes it to (i + 8) % 16 the required row count for a
    swapPalettes tileset changes, and this script must move with it."""
    path = os.path.join(root, "src", "overworld.c")
    if not os.path.exists(path):
        raise Fatal("missing %s" % path)
    text = strip_c_comments(read_text(path))
    m = re.search(r"void\s+UpdateAltBgPalettes\s*\([^)]*\)\s*\{", text)
    if not m:
        raise Fatal("UpdateAltBgPalettes not found in %s" % path)
    body = text[m.end():m.end() + 4000]
    hits = set(re.findall(r"\(\s*i\s*\+\s*(\d+)\s*\)\s*%\s*(\d+)", body))
    if not hits:
        raise Fatal(
            "could not find the `(i + N) %% M` alternate-palette index in "
            "UpdateAltBgPalettes -- the blend was rewritten and this script's "
            "row bound is no longer derived from it"
        )
    if len(hits) > 1:
        raise Fatal(
            "UpdateAltBgPalettes has more than one `(i + N) %% M` form (%s); "
            "refusing to guess which one bounds the array"
            % ", ".join("(i+%s)%%%s" % h for h in sorted(hits))
        )
    off, mod = hits.pop()
    return int(off), int(mod)


# ---------------------------------------------------------------------------
# 2. The palette arrays themselves
# ---------------------------------------------------------------------------

# `const u16 [ALIGNED(4)] gTilesetPalettes_Foo[][16] = { ... };`
# The second dimension is the ROW WIDTH (16 colours) and is not what we are counting;
# the first dimension is empty and is inferred from the initialiser, which is precisely
# why nothing else in the build can tell you how many rows there are.
ARRAY_DECL = re.compile(
    r"const\s+u16\s+(?:ALIGNED\(\s*\d+\s*\)\s+)?"
    r"(gTilesetPalettes_\w+)\s*\[\s*\]\s*\[\s*(\d+)\s*\]\s*=\s*\{",
    re.S,
)
PAL_ENTRY = re.compile(r"INCGFX_U16\s*\(|INCBIN_U16\s*\(")

PALETTE_ARRAY_FILES = (
    os.path.join("src", "data", "tilesets", "graphics.h"),
    # gTilesetPalettes_General is declared here rather than with its 199 siblings,
    # in ALIGNED(4) form. Counted identically; the alignment attribute is only about
    # CpuFastCopy's word requirement, not about how many rows exist.
    os.path.join("src", "graphics.c"),
)


def parse_palette_arrays(root):
    """symbol -> {rows, width, file, line}. Rows = INCGFX_U16 entries in the brace body."""
    arrays = {}
    for rel in PALETTE_ARRAY_FILES:
        path = os.path.join(root, rel)
        if not os.path.exists(path):
            raise Fatal("missing %s" % path)
        raw = read_text(path)
        text = strip_c_comments(raw)
        for m in ARRAY_DECL.finditer(text):
            name, width = m.group(1), int(m.group(2))
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
                raise Fatal("unterminated initialiser for %s in %s" % (name, rel))
            rows = len(PAL_ENTRY.findall(text[start + 1:end]))
            if name in arrays:
                raise Fatal(
                    "%s is defined twice (%s and %s) -- the linker would pick one and "
                    "this script cannot know which"
                    % (name, arrays[name]["file"], rel)
                )
            arrays[name] = {
                "rows": rows,
                "width": width,
                "file": rel,
                "line": text.count("\n", 0, m.start()) + 1,
            }
    if not arrays:
        raise Fatal("no gTilesetPalettes_* arrays parsed from %s"
                    % ", ".join(PALETTE_ARRAY_FILES))
    return arrays


# ---------------------------------------------------------------------------
# 3. The tilesets that point at them
# ---------------------------------------------------------------------------


def parse_tilesets(root):
    """gTileset_* -> {is_secondary, swap, palettes symbol}.

    Both preprocessor arms of headers.h (#if !IS_FRLG and #if IS_FRLG || ALL_REGIONS)
    are scanned. Only one arm is compiled per configuration, but both are shipped
    configurations, so both are checked."""
    path = os.path.join(root, "src", "data", "tilesets", "headers.h")
    if not os.path.exists(path):
        raise Fatal("missing %s" % path)
    text = strip_c_comments(read_text(path))
    decl = re.compile(r"const\s+struct\s+Tileset\s+(gTileset_\w+)\s*=\s*\{(.*?)\}\s*;", re.S)
    tilesets = {}
    for name, body in decl.findall(text):
        m = re.search(r"\.palettes\s*=\s*(\w+)", body)
        if not m:
            raise Fatal("%s has no .palettes initialiser" % name)
        pal = m.group(1)
        sec = re.search(r"\.isSecondary\s*=\s*(\w+)", body)
        if sec is None:
            # A designated initialiser that omits the field zero-fills it, so an
            # absent .isSecondary is a PRIMARY. Say so rather than skipping.
            is_secondary = False
        else:
            is_secondary = sec.group(1) == "TRUE"
        swp = re.search(r"\.swapPalettes\s*=\s*(0[xX][0-9A-Fa-f]+|\d+)", body)
        swap = int(swp.group(1), 0) if swp else 0
        tilesets[name] = {
            "is_secondary": is_secondary,
            "swap": swap,
            "palettes": pal,
        }
    if not tilesets:
        raise Fatal("no tilesets parsed from %s" % path)
    return tilesets


# ---------------------------------------------------------------------------
# 4. Which regime each tileset is actually used in
# ---------------------------------------------------------------------------

# tools/mapjson/mapjson.cpp: layout_version "frlg" -> isFrlg, "johto" -> isJohto,
# anything else -> neither. src/fieldmap.c GetNumPalsInPrimary():
# (isFrlg || isJohto) ? NUM_PALS_IN_PRIMARY_FRLG : NUM_PALS_IN_PRIMARY.
FRLG_LIKE = {"frlg", "johto"}


def parse_layout_regimes(root):
    """tileset symbol -> set of regime names ("emerald" / "frlg") it is paired into.

    This is what makes check (d) precise instead of conservative: only a secondary
    reached through an EMERALD layout can have its swapPalettes bit 0 land on
    palette NUM_PALS_IN_PRIMARY and blend against row 15."""
    path = os.path.join(root, "data", "layouts", "layouts.json")
    if not os.path.exists(path):
        return None
    data = json.load(open(path, "r", encoding="utf-8"))
    regimes = defaultdict(set)
    for entry in data.get("layouts", []):
        if not entry:
            continue
        version = (entry.get("layout_version") or "emerald").strip()
        regime = "frlg" if version in FRLG_LIKE else "emerald"
        for key in ("primary_tileset", "secondary_tileset"):
            ts = entry.get(key)
            if ts:
                regimes[ts].add(regime)
    return dict(regimes)


# ---------------------------------------------------------------------------
# 5. The bound
# ---------------------------------------------------------------------------


def required_rows(ts, n_prim_em, n_prim_frlg, n_total, top_palette, alt_off, alt_mod,
                  regimes):
    """Highest row index the readers can touch, + 1. Returns (rows, [reasons])."""
    reasons = []

    if ts["is_secondary"]:
        # LoadTilesetPalette copies palettes[numPalsInPrimary] .. palettes[NUM_PALS_TOTAL-1].
        # The end does not move with the regime, so this is flat.
        need = n_total
        reasons.append("secondary loader reads rows %d..%d (NUM_PALS_TOTAL)"
                       % (min(n_prim_em, n_prim_frlg), n_total - 1))
    else:
        # A primary is read as rows 0..numPalsInPrimary-1. Held at the FRLG/Johto count
        # for every primary: pairing a primary into a Johto layout is a one-line
        # layouts.json edit, and that edit must not be able to create an overread.
        need = n_prim_frlg
        reasons.append("primary loader reads rows 0..%d (NUM_PALS_IN_PRIMARY_FRLG)"
                       % (n_prim_frlg - 1))

    swap = ts["swap"]
    if swap:
        # Which regimes can actually reach this tileset. Unknown (not named by any
        # layout) means "assume both" -- the conservative side.
        applicable = regimes.get(ts["name"]) if regimes is not None else None
        if not applicable:
            applicable = {"emerald", "frlg"}
        for regime in sorted(applicable):
            n_prim = n_prim_frlg if regime == "frlg" else n_prim_em
            for bit in range(8):
                if not (swap >> bit) & 1:
                    continue
                # Primary bits ARE palette numbers; secondary bits are shifted up by
                # numPalsInPrimary (see the `secondary->swapPalettes << ...` line).
                pal = bit + (n_prim if ts["is_secondary"] else 0)
                if pal == 0 or pal > top_palette:
                    continue  # masked off by PALETTES_MAP ^ (1 << 0)
                alt = (pal + alt_off) % alt_mod
                want = max(pal, alt) + 1
                if want > need:
                    need = want
                    reasons.append(
                        "swapPalettes bit %d (%s regime) blends palette %d against "
                        "row %d" % (bit, regime, pal, alt))
    return need, reasons


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=None,
                    help="repo root (default: the parent of this script's directory)")
    ap.add_argument("--verbose", action="store_true",
                    help="list every tileset with its required and declared row count")
    args = ap.parse_args(argv)

    root = args.root or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    root = os.path.abspath(root)

    try:
        n_prim_em, n_prim_frlg, n_total = parse_pal_counts(root)
        palettes_map = parse_palettes_map(root)
        alt_off, alt_mod = parse_alt_pal_math(root)
        arrays = parse_palette_arrays(root)
        tilesets = parse_tilesets(root)
        regimes = parse_layout_regimes(root)
    except (Fatal, ValueError) as exc:
        print("FATAL: %s" % exc, file=sys.stderr)
        return 2

    blend_mask = palettes_map ^ (1 << 0)
    top_palette = blend_mask.bit_length() - 1

    print("=" * 78)
    print("TILESET PALETTE ARRAY BOUNDS")
    print("repo root: %s" % root)
    print("=" * 78)
    print()
    print("--- Derived constants (read from the tree, not assumed) ---")
    print("  NUM_PALS_IN_PRIMARY       : %d (Emerald layouts)        include/fieldmap.h"
          % n_prim_em)
    print("  NUM_PALS_IN_PRIMARY_FRLG  : %d (FRLG + Johto layouts)   include/fieldmap.h"
          % n_prim_frlg)
    print("  NUM_PALS_TOTAL            : %d                          include/fieldmap.h"
          % n_total)
    print("  PALETTES_MAP              : 0x%08X                include/palette.h"
          % palettes_map)
    print("  alt-palette index         : (i + %d) %% %d               src/overworld.c "
          "UpdateAltBgPalettes" % (alt_off, alt_mod))
    print("  blend mask after ^(1<<0)  : 0x%08X -> palettes 1..%d may blend"
          % (blend_mask, top_palette))
    print("  primary-count selection   : GetNumPalsInPrimary() = "
          "(isFrlg || isJohto) ? %d : %d" % (n_prim_frlg, n_prim_em))
    print("  layout_version -> regime  : frlg/johto = FRLG regime, everything else "
          "= Emerald (tools/mapjson/mapjson.cpp)")
    print()
    print("--- Bounds these imply ---")
    print("  primary      : >= %d rows -- the loader reads 0..%d. Held at the FRLG/Johto"
          % (n_prim_frlg, n_prim_frlg - 1))
    print("                 count for EVERY primary, because pairing one into a Johto")
    print("                 layout is a one-line layouts.json edit and that edit must")
    print("                 not be able to create a silent overread.")
    print("  secondary    : >= %d rows -- the loader reads %d..%d (Emerald) or %d..%d"
          % (n_total, n_prim_em, n_total - 1, n_prim_frlg, n_total - 1))
    print("                 (FRLG/Johto). The START moves with the regime, the END does")
    print("                 not, so %d is the flat bound. NOT 16, and not row 15." % n_total)
    print("  swapPalettes : whatever (i + %d) %% %d reaches for the bits actually set,"
          % (alt_off, alt_mod))
    print("                 up to all %d rows. %d tileset(s) set it today."
          % (alt_mod, sum(1 for t in tilesets.values() if t["swap"])))
    print()

    # ------------------------------------------------------------ resolve ---
    missing_array = []
    for name, ts in sorted(tilesets.items()):
        ts["name"] = name
        if ts["palettes"] not in arrays:
            missing_array.append((name, ts["palettes"]))
    if missing_array:
        print("--- Tilesets whose .palettes symbol was not found ---")
        for name, sym in missing_array:
            print("  %-38s .palettes = %s" % (name, sym))
        print()
        print("FATAL: %d tileset(s) point at a palette array this script could not "
              "find in %s. That is not a pass -- an unchecked tileset is exactly the "
              "hole this file exists to close."
              % (len(missing_array), " or ".join(PALETTE_ARRAY_FILES)), file=sys.stderr)
        return 2

    failures = []
    notes = []
    rows_hist = defaultdict(int)
    n_primary = n_secondary = n_swap = 0

    for name, ts in sorted(tilesets.items()):
        arr = arrays[ts["palettes"]]
        need, reasons = required_rows(ts, n_prim_em, n_prim_frlg, n_total,
                                      top_palette, alt_off, alt_mod, regimes)
        rows_hist[arr["rows"]] += 1
        if ts["is_secondary"]:
            n_secondary += 1
        else:
            n_primary += 1
        if ts["swap"]:
            n_swap += 1
        if arr["rows"] < need:
            failures.append((name, ts, arr, need, reasons))
        elif ts["swap"] and arr["rows"] < alt_mod:
            # Not a failure under the precise rule, but worth saying out loud: the
            # blanket "swapPalettes means 16 rows" instinct is stricter than the code.
            notes.append((name, ts, arr, need))
        if arr["width"] != alt_mod:
            failures.append((name, ts, arr, need,
                             ["row width is %d, not %d -- the alternate-palette index "
                              "is taken modulo %d and would land outside the row"
                              % (arr["width"], alt_mod, alt_mod)]))

    print("--- Population ---")
    print("  tilesets declared            : %d  (%d primary, %d secondary)"
          % (len(tilesets), n_primary, n_secondary))
    print("  distinct palette arrays      : %d" % len(arrays))
    print("  arrays reached by a tileset  : %d"
          % len({t["palettes"] for t in tilesets.values()}))
    print("  tilesets with swapPalettes!=0: %d" % n_swap)
    for rows in sorted(rows_hist):
        print("  tilesets on a %2d-row array   : %d" % (rows, rows_hist[rows]))
    orphans = sorted(set(arrays) - {t["palettes"] for t in tilesets.values()})
    if orphans:
        print("  arrays no tileset points at  : %d -> %s"
              % (len(orphans), ", ".join(orphans[:5])))
    print()

    if args.verbose:
        print("--- Every tileset ---")
        for name, ts in sorted(tilesets.items()):
            arr = arrays[ts["palettes"]]
            need, _ = required_rows(ts, n_prim_em, n_prim_frlg, n_total,
                                    top_palette, alt_off, alt_mod, regimes)
            print("  %-40s %-9s swap=0x%02X  need %2d  have %2d  %s"
                  % (name, "secondary" if ts["is_secondary"] else "primary",
                     ts["swap"], need, arr["rows"], ts["palettes"]))
        print()

    if notes:
        print("--- Sets swapPalettes on a short array (allowed, but check it) ---")
        for name, ts, arr, need in notes:
            print("  %-40s swap=0x%02X  need %2d  have %2d (%s)"
                  % (name, ts["swap"], need, arr["rows"], ts["palettes"]))
        print("  These are legal: the bits set do not reach a row past the end. If you")
        print("  set MORE bits they will, so re-run this after touching swapPalettes.")
        print()

    print("=" * 78)
    if failures:
        print("SHORT PALETTE ARRAYS: %d" % len(failures))
        print("=" * 78)
        for name, ts, arr, need, reasons in failures:
            print()
            print("  %s  (%s, swapPalettes=0x%02X)"
                  % (name, "secondary" if ts["is_secondary"] else "primary", ts["swap"]))
            print("      array   : %s  -- %s:%d" % (ts["palettes"], arr["file"], arr["line"]))
            print("      declares: %d row(s) of %d" % (arr["rows"], arr["width"]))
            print("      needs   : %d row(s)" % need)
            for reason in reasons:
                print("        because %s" % reason)
        print()
        print("FAIL: %d tileset(s) declare fewer palette rows than the loaders read. "
              "Nothing about this fails the build -- `gTilesetPalettes_Foo[][16]` decays "
              "to a bare pointer, so the copy silently walks into whatever .rodata "
              "follows and paints it onto the map. Add the missing rows (real .pal "
              "files, not a memcpy of a neighbour's), or, if the tileset genuinely "
              "should not be reachable that way, fix the isSecondary/swapPalettes flag "
              "that made it reachable." % len(failures))
        return 1

    print("PASS: all %d tileset(s) declare enough palette rows" % len(tilesets))
    print("=" * 78)
    print("  primaries checked at   >= %d rows : %d ok" % (n_prim_frlg, n_primary))
    print("  secondaries checked at >= %d rows : %d ok" % (n_total, n_secondary))
    print("  swapPalettes arms evaluated       : %d" % n_swap)
    print("  (rows 13..%d exist only for the UpdateAltBgPalettes alternate-palette "
          "blend;\n   the loaders stop at row %d -- see issue #94, whose premise that "
          "they copy\n   7..15 was wrong)" % (alt_mod - 1, n_total - 1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
