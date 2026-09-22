#!/usr/bin/env python3
"""Check region-map icon rectangles against the grids used by the cursor.

Non-Johto exceptions preserve upstream icon adjustments. Pin the actual
rectangles, not just a count, so a new mismatch cannot replace an old one.
"""
import json
import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / 'src/data/region_map'
FIELDS = ('x', 'y', 'width', 'height')
# Populated with the existing upstream adjustments; Johto has no exceptions.
EXCEPTIONS = {('region_map_layout.h', 'MAPSEC_MT_CHIMNEY'): ((6, 2, 1, 1), (6, 1, 2, 2)),
 ('region_map_layout.h', 'MAPSEC_ROUTE_106'): ((0, 13, 2, 1), (0, 13, 3, 1)),
 ('region_map_layout_kanto.h', 'MAPSEC_ROUTE_10'): ((18, 3, 1, 3), (18, 4, 1, 2)),
 ('region_map_layout_kanto.h', 'MAPSEC_ROUTE_4'): ((8, 3, 6, 1), (9, 3, 5, 1)),
 ('region_map_layout_sevii123.h', 'MAPSEC_BOND_BRIDGE'): ((13, 12, 4, 1), (14, 12, 4, 1)),
 ('region_map_layout_sevii45.h', 'MAPSEC_FIVE_ISLE_MEADOW'): ((17, 10, 1, 3), (17, 11, 1, 2))}


def footprints(path):
    source = re.sub(r'/\*.*?\*/|//[^\n]*', '', path.read_text(), flags=re.S)
    rows = [re.findall(r'\bMAPSEC_\w+', row) for row in re.findall(r'\{([^{}]+)\}', source)]
    if len(rows) != 15 or any(len(row) != 28 for row in rows):
        raise ValueError(f'{path.name}: expected a 28x15 grid')
    cells = defaultdict(list)
    for y, row in enumerate(rows):
        for x, section in enumerate(row):
            if section != 'MAPSEC_NONE':
                cells[section].append((x, y))
    return {section: (min(x for x, y in points), min(y for x, y in points),
                      max(x for x, y in points) - min(x for x, y in points) + 1,
                      max(y for x, y in points) - min(y for x, y in points) + 1)
            for section, points in cells.items()}


def main():
    entries = {e['id']: e for e in json.loads((DATA / 'region_map_sections.json').read_text())['map_sections']}
    errors = []
    seen = set()
    layouts = sorted(DATA.glob('region_map_layout*.h'))
    if len(layouts) != 6:
        raise ValueError('expected six region layouts')
    for path in layouts:
        count = 0
        for section, expected in footprints(path).items():
            entry = entries.get(section, {})
            actual = tuple(entry.get(f) for f in FIELDS)
            key = (path.name, section)
            if actual != expected:
                count += 1
                if EXCEPTIONS.get(key) == (actual, expected):
                    seen.add(key)
                else:
                    errors.append(f'{path.name}: {section}: icon {actual}, grid {expected}')
        print(f'{path.name}: {count} mismatches')
    errors.extend(f'stale exception: {key}' for key in EXCEPTIONS.keys() - seen)
    for error in errors:
        print(error)
    return bool(errors)


if __name__ == '__main__':
    raise SystemExit(main())
