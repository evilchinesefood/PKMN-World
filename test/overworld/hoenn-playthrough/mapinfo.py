#!/usr/bin/env python3
"""Print a map's objects (with local ids), coord triggers, bg events and warps.

    mapinfo.py MapName [MapName...]
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
for m in sys.argv[1:]:
    d = json.loads((ROOT / 'data/maps' / m / 'map.json').read_text())
    print('##', m, d.get('layout'))
    for i, o in enumerate(d['object_events'], 1):
        gfx = o.get('graphics_id', '').replace('OBJ_EVENT_GFX_', '')
        print(f" obj {i} {o.get('local_id') or ''} ({o['x']},{o['y']}) e{o.get('elevation')} {gfx} {o.get('movement_type','').replace('MOVEMENT_TYPE_','')} {o['script']} {o.get('flag')} {o.get('trainer_type','')}")
    for c in d.get('coord_events', []):
        print(f" coord ({c['x']},{c['y']}) {c.get('var')}=={c.get('var_value')} {c.get('script')}")
    for b in d.get('bg_events', []):
        print(f" bg ({b['x']},{b['y']}) {b.get('type')} {b.get('script') or b.get('item') or ''}")
    for w in d.get('warp_events', []):
        print(f" warp ({w['x']},{w['y']}) -> {w['dest_map']} #{w['dest_warp_id']}")
