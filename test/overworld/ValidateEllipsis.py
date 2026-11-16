#!/usr/bin/env python3
"""Script text writes an ellipsis as the … character, never as ASCII dots.

GSC, FRLG and Emerald all print "…"; a run of ASCII periods in a .string line is a transcription
slip (pokemonHnS carried a few into the Johto maps). With --fix, each run of n >= 3 dots becomes
round(n / 3) ellipses, which is never wider: "." is 3 px and "…" 6 px in FONT_NORMAL.
"""
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parent.parent.parent
STRING = re.compile(r'^(\s*\.string\s+")(.*)("\s*)$')
DOTS = re.compile(r'\.{3,}')


def ellipses(match):
    return '…' * max(1, round(len(match.group(0)) / 3))


def main():
    fix = '--fix' in sys.argv
    found = []
    for path in sorted(root.glob('data/**/*.inc')):
        lines = path.read_text(encoding='utf-8').splitlines(keepends=True)
        changed = False
        for i, line in enumerate(lines):
            m = STRING.match(line.rstrip('\n'))
            if not m or not DOTS.search(m.group(2)):
                continue
            found.append(f'{path.relative_to(root)}:{i + 1}: {m.group(2)}')
            if fix:
                lines[i] = m.group(1) + DOTS.sub(ellipses, m.group(2)) + m.group(3) + '\n'
                changed = True
        if changed:
            path.write_text(''.join(lines), encoding='utf-8')
    for f in found:
        print(f)
    if found and not fix:
        print(f'FAIL: {len(found)} script text lines write an ellipsis as ASCII dots')
        return 1
    print(f'{"FIXED" if fix else "PASS"}: {len(found)} lines with ASCII dots')
    return 0


if __name__ == '__main__':
    sys.exit(main())
