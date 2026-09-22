"""Conservative map reachability for ambient placement checks.

Walk, Surf and ledge jumps only. Warp/connection entries seed the search;
objects and story gates are ignored. Ice, holes, Rock Climb and Strength are
not simulated, so unresolved maps have a reviewed per-map baseline.
"""
import json
import re
from collections import deque
from pathlib import Path

DIRECTIONS = ((0, -1, 'NORTH'), (0, 1, 'SOUTH'), (-1, 0, 'WEST'), (1, 0, 'EAST'))
# Explicit habitat policy, not all Water types: amphibious species may use land.
WATER_ONLY = set('TENTACOOL TENTACRUEL HORSEA SEADRA KINGDRA MAGIKARP GYARADOS '
                 'GOLDEEN SEAKING SHELLDER CLOYSTER STARYU STARMIE CHINCHOU LANTURN '
                 'REMORAID OCTILLERY MANTINE MANTYKE CORSOLA CARVANHA SHARPEDO '
                 'WAILMER WAILORD CLAMPERL HUNTAIL GOREBYSS LUVDISC FEEBAS MILOTIC'.split())


def surfable_behaviors(root, names):
    source = (Path(root) / 'src/metatile_behavior.c').read_text()
    return {names[m[1]] for m in re.finditer(r'\[(MB_\w+)\]\s*=\s*([^,\n]+)', source)
            if 'TILE_FLAG_SURFABLE' in m[2]}


def ambient(row):
    return (row['map_type'] != 'MAP_TYPE_INDOOR' and row['script'] in ('NULL', '0x0')
            and not row['script_driven'])


def flood(layouts, data, names, water, all_maps, map_names):
    lid = data['layout']
    width, height, _ = layouts.grid(lid)
    tiles = {(x, y): layouts.tile(lid, x, y) for y in range(height) for x in range(width)}
    def walkable(p):
        t = tiles.get(p)
        return t is not None and t['collision'] == 0 and t['behavior'] is not None
    seeds = {(w['x'], w['y']) for w in data.get('warp_events', [])}
    # Door arrivals step out of the doorway. A solid door must not make the
    # entire town appear inaccessible; seed its walkable adjacent approach.
    for warp in data.get('warp_events', []):
        p = (warp['x'], warp['y'])
        if not walkable(p):
            seeds.update((p[0] + dx, p[1] + dy) for dx, dy, _ in DIRECTIONS)
    for connection in data.get('connections') or []:
        direction = connection['direction']
        # Restrict to the actual overlap with the connected map, not the whole edge.
        other = all_maps[map_names[connection['map']]]
        ow, oh, _ = layouts.grid(other['layout'])
        offset = int(connection['offset'])
        if direction in ('north', 'south'):
            seeds.update((x, 0 if direction == 'north' else height - 1)
                         for x in range(max(0, offset), min(width, offset + ow)))
        elif direction in ('west', 'east'):
            seeds.update((0 if direction == 'west' else width - 1, y)
                         for y in range(max(0, offset), min(height, offset + oh)))
    reached = {p for p in seeds if walkable(p)}
    queue = deque(reached)
    while queue:
        p = queue.popleft(); a = tiles[p]
        for dx, dy, direction in DIRECTIONS:
            q = (p[0] + dx, p[1] + dy)
            b = tiles.get(q)
            if b is None: continue
            if b['behavior'] == names.get('MB_JUMP_' + direction):
                q = (q[0] + dx, q[1] + dy); b = tiles.get(q)
            if not walkable(q) or q in reached: continue
            # Surf bridges elevation 3 shore and elevation 1 water. Ordinary
            # transitions and multilevel tiles follow IsElevationMismatchAt.
            compatible = (a['elevation'] in (0, 15) or b['elevation'] in (0, 15)
                          or a['elevation'] == b['elevation']
                          or (a['behavior'] in water and b['behavior'] not in water
                              and b['elevation'] == 3)
                          or (a['behavior'] not in water and b['behavior'] in water
                              and a['elevation'] == 3))
            if compatible:
                reached.add(q); queue.append(q)
    total = sum(walkable(p) for p in tiles)
    return reached, tiles, len(reached) / max(1, total)


def approachable(row, reached, tiles):
    x, y = row['runtime_x'], row['runtime_y']
    return any((x + dx, y + dy) in reached
               and (row['elevation'] == 0 or tiles[(x + dx, y + dy)]['elevation'] in (0, row['elevation']))
               for dx, dy, _ in DIRECTIONS)


def census(root, layouts, rows, names):
    all_maps = {p.parent.name: json.loads(p.read_text()) for p in (Path(root) / 'data/maps').glob('*/map.json')}
    map_names = {data['id']: name for name, data in all_maps.items()}
    water = surfable_behaviors(root, names)
    cache = {}
    unreachable, dry = {}, []
    for row in rows:
        if not ambient(row): continue
        name = row['map']
        if name not in cache: cache[name] = flood(layouts, all_maps[name], names, water, all_maps, map_names)
        reached, tiles, _ = cache[name]
        if not approachable(row, reached, tiles): unreachable.setdefault(name, []).append(row)
        if row['species'] in WATER_ONLY and row['tile'] and row['tile']['behavior'] not in water:
            dry.append(row)
    return unreachable, dry, cache, water


def validate(root, layouts, rows, names):
    unreachable, dry, _, _ = census(root, layouts, rows, names)
    baseline = json.loads((Path(root) / 'Testing/OwMonReachabilityBaseline.json').read_text())
    errors = []
    for name in sorted(unreachable.keys() | baseline.keys()):
        actual, allowed = len(unreachable.get(name, [])), baseline.get(name, 0)
        if actual != allowed:
            errors.append(f'{name}: [walk-reachability] {actual} unresolved, baseline {allowed}; '
                          'fix new placements or lower the baseline when resolving existing ones')
    for row in dry:
        errors.append(f"{row['map']} object {row['index'] + 1}: [water-habitat] {row['species']} stands on dry land")
    return errors
