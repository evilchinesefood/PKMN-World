#!/usr/bin/env python3
"""The Route 40 sea crossing must land on surfable water (issue #289)."""
import json
import re
from pathlib import Path
import ValidateOwMonPlacements as maps

root = Path(maps.ROOT)
files = maps.load_tileset_attributes()
layouts = maps.Layouts(files, maps.check_attribute_widths(files))
names = maps.load_behavior_names()
source = (root / 'src/metatile_behavior.c').read_text()
surfable = {names[m[1]] for m in re.finditer(r'\[(MB_\w+)\]\s*=\s*([^,\n]+)', source)
            if 'TILE_FLAG_SURFABLE' in m[2]}
route40 = json.loads((root / 'data/maps/Route40/map.json').read_text())
route41 = json.loads((root / 'data/maps/Route41/map.json').read_text())
arrivals = [route41['warp_events'][int(w['dest_warp_id'])]
            for w in route40['warp_events'] if w['dest_map'] == route41['id']]
assert len(arrivals) == 9, 'expected the nine sea-crossing warps'
errors = []
for warp in arrivals:
    for y in (warp['y'] - 1, warp['y']):
        tile = layouts.tile(route41['layout'], warp['x'], y)
        if tile['behavior'] not in surfable:
            errors.append(f"({warp['x']}, {y}): metatile {tile['metatile']} is not surfable")
assert not errors, '\n'.join(errors)
print('PASS: all nine Route 40 arrivals and their north neighbours are surfable')
