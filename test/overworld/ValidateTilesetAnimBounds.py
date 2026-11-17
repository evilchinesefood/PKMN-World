#!/usr/bin/env python3
"""Every tileset animation DMA must stay inside the frame it copies from.

src/tileset_anims.c queues each animation frame with
AppendTilesetAnimToBuffer(src, dest, size). Nothing checks `size` against the frame
array, so a copy one tile too long reads whatever the linker placed next. Until
#636 a 15.6 KB zero fill sat after the Battle Pyramid statue-shadow frames, so an
over-read there drew blank tiles; with the fill gone it would draw the next frame
set. This check makes every copy prove it fits.

Each frame is `const u16 NAME[] = INCGFX_U16("x.png", ".4bpp")` (or an INCBIN_U16 of
.4bpp files converted from the PNGs beside them), so its size is the sum of
(width / 8) * (height / 8) * 32 bytes over its PNGs, read from the PNG headers. Each frame table is
`const u16 *const TABLE[] = { NAME, ... }`. Each call site copies `N * TILE_SIZE_4BPP`
bytes either from `TABLE[i]` or from a local pointer set to `TABLE[i] + K * (TILE_SIZE_4BPP / 2)`
and offset again by `M * (TILE_SIZE_4BPP / sizeof(u16))`. Every frame a table can
select must hold offset + size bytes.

Usage: python3 test/overworld/ValidateTilesetAnimBounds.py [--root DIR]
Exits 1 on any over-read or on a call site it cannot parse.
"""

import argparse
import re
import struct
import sys
from pathlib import Path

TILE = 32  # TILE_SIZE_4BPP


def png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path}: not a PNG")
    w, h = struct.unpack(">II", head[16:24])
    return (w // 8) * (h // 8) * TILE


def tiles_expr(expr):
    """Bytes for `N * TILE_SIZE_4BPP` or a bare `TILE_SIZE_4BPP`."""
    expr = expr.strip()
    if expr == "TILE_SIZE_4BPP":
        return TILE
    m = re.fullmatch(r"(\d+)\s*\*\s*TILE_SIZE_4BPP", expr)
    return int(m.group(1)) * TILE if m else None


def offset_expr(expr):
    """Bytes for an optional `+ K * (TILE_SIZE_4BPP / 2)` or `/ sizeof(u16)` u16 offset."""
    if not expr:
        return 0
    m = re.fullmatch(r"\+\s*(\d+)\s*\*\s*\(TILE_SIZE_4BPP\s*/\s*(?:2|sizeof\(u16\))\)", expr.strip())
    return int(m.group(1)) * TILE if m else None


def split_args(s):
    out, depth, cur = [], 0, ""
    for ch in s:
        if ch == "," and depth == 0:
            out.append(cur); cur = ""; continue
        depth += ch == "("
        depth -= ch == ")"
        cur += ch
    out.append(cur)
    return [a.strip() for a in out]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=str(Path(__file__).resolve().parents[2]))
    root = Path(ap.parse_args().root)
    src = (root / "src/tileset_anims.c").read_text()
    code = re.sub(r"//[^\n]*", "", src)

    frames = {name: png_size(root / path) for name, path in re.findall(
        r'const u16 (\w+)\[\]\s*=\s*INCGFX_U16\("([^"]+\.png)",\s*"\.4bpp"\)', code)}
    # INCBIN_U16 concatenates prebuilt .4bpp files, each converted from the PNG beside it.
    for name, paths in re.findall(r"const u16 (\w+)\[\]\s*=\s*INCBIN_U16\(([^)]*)\);", code):
        files = re.findall(r'"([^"]+)\.4bpp"', paths)
        if files:
            frames[name] = sum(png_size(root / (f + ".png")) for f in files)
    tables = {name: [x.strip() for x in body.split(",") if x.strip()] for name, body in re.findall(
        r"const u16 \*const (\w+)\[\w*\]\s*=\s*\{(.*?)\};", code, re.S)}

    problems, sites = [], 0
    for fn_body in re.findall(r"\n(?:static )?void \w+\([^)]*\)\s*\{(.*?)\n\}", code, re.S):
        locals_ = {}
        for var, table, off in re.findall(
                r"const u16 \*(\w+)\s*=\s*(\w+)\[[^\]]*\]\s*(\+[^;]*)?;", fn_body):
            locals_[var] = (table, offset_expr(off))
        for call in re.findall(r"AppendTilesetAnimToBuffer\((.*?)\);", fn_body, re.S):
            args = split_args(call)
            if len(args) != 3:
                continue
            sites += 1
            size = tiles_expr(args[2])
            m = re.fullmatch(r"(\w+)\[[^\]]*\]", args[0])
            if m:
                table, off = m.group(1), 0
            else:
                m = re.fullmatch(r"(\w+)\s*(\+.*)?", args[0], re.S)
                if not m or m.group(1) not in locals_:
                    problems.append(f"unparsed source `{args[0]}`")
                    continue
                table, off = locals_[m.group(1)]
                extra = offset_expr(m.group(2))
                off = None if off is None or extra is None else off + extra
            if size is None or off is None or table not in tables:
                problems.append(f"unparsed call AppendTilesetAnimToBuffer({call.strip()})")
                continue
            for frame in tables[table]:
                have = frames.get(frame)
                if have is None:
                    problems.append(f"{table}: frame {frame} has no .4bpp PNG source")
                elif off + size > have:
                    problems.append(f"{table}: copies bytes {off}..{off + size} of {frame}, "
                                    f"which holds {have}")
    if sites == 0:
        problems.append("found no AppendTilesetAnimToBuffer call sites")
    for p in problems:
        print("TILESET ANIM BOUNDS: " + p)
    print(f"Tileset animation bounds: {sites} call sites, {len(tables)} frame tables, "
          f"{len(frames)} frames, {len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
