#!/usr/bin/env python3
"""Pixel-diff two TextWidthTour runs (or any two directories of same-named screenshots).

Usage: python3 test/overworld/TextWidthDiff.py <before_dir> <after_dir> [--out <dir>] [--prefix TextWidthTour_]

Each run directory is searched recursively for <prefix>*.png. For every name present in both runs
the script prints SAME or DIFF with the count of differing pixels and their bounding box; for each
DIFF it writes <out>/<name>: before, after and a red change mask side by side at 3x. Names present
in only one run are listed, since a scene that diverged is itself a finding. Exit code 0 means every
shared pair is identical and no name is missing.
"""
import argparse
import sys
from pathlib import Path

from PIL import Image, ImageChops

SCALE = 3


def collect(root, prefix):
    found = {}
    for path in sorted(Path(root).rglob(prefix + '*.png')):
        found.setdefault(path.name, path)
    return found


def compare(before, after):
    a = Image.open(before).convert('RGB')
    b = Image.open(after).convert('RGB')
    if a.size != b.size:
        return None, a, b, None
    diff = ImageChops.difference(a, b).convert('L').point(lambda v: 255 if v else 0)
    box = diff.getbbox()
    count = sum(1 for v in diff.getdata() if v)
    return (count, box), a, b, diff


def sheet(a, b, diff, out):
    w, h = a.size
    canvas = Image.new('RGB', (w * 3 + 8, h), (255, 0, 255))
    mask = Image.new('RGB', (w, h), (0, 0, 0))
    mask.paste((255, 0, 0), mask=diff)
    canvas.paste(a, (0, 0))
    canvas.paste(b, (w + 4, 0))
    canvas.paste(Image.blend(b, mask, 0.6), (2 * w + 8, 0))
    canvas.resize((canvas.width * SCALE, canvas.height * SCALE), Image.NEAREST).save(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('before')
    ap.add_argument('after')
    ap.add_argument('--out', default=None)
    ap.add_argument('--prefix', default='TextWidthTour_')
    args = ap.parse_args()
    left, right = collect(args.before, args.prefix), collect(args.after, args.prefix)
    out = Path(args.out) if args.out else None
    if out:
        out.mkdir(parents=True, exist_ok=True)
    same = diff_count = 0
    for name in sorted(set(left) & set(right)):
        result, a, b, mask = compare(left[name], right[name])
        if result is None:
            print(f'DIFF {name}: size {a.size} vs {b.size}')
            diff_count += 1
            continue
        count, box = result
        if count == 0:
            same += 1
            continue
        diff_count += 1
        print(f'DIFF {name}: {count} px in box {box}')
        if out:
            sheet(a, b, mask, out / name)
    only_left = sorted(set(left) - set(right))
    only_right = sorted(set(right) - set(left))
    for name in only_left:
        print(f'ONLY-BEFORE {name}')
    for name in only_right:
        print(f'ONLY-AFTER {name}')
    print(f'pairs={same + diff_count} same={same} diff={diff_count} '
          f'only_before={len(only_left)} only_after={len(only_right)}')
    return 0 if diff_count == 0 and not only_left and not only_right else 1


if __name__ == '__main__':
    sys.exit(main())
