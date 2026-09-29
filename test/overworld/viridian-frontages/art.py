#!/usr/bin/env python3
"""Author and audit #348 from immutable Git blobs; render existing source art."""
import argparse
from collections import deque
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import sys

from PIL import Image, ImageChops, ImageDraw

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(REPO/'test/overworld/night-lighting'))
from assets import Assets
import panes

PLAN = json.loads((HERE/'plan.json').read_text())
BASE = PLAN['baseline']
MAP = 'data/layouts/ViridianCity_Frlg/map.bin'
META = 'data/tilesets/secondary/viridian_city_frlg/metatiles.bin'
ATTR = 'data/tilesets/secondary/viridian_city_frlg/metatile_attributes.bin'
PRIMARY = 'data/tilesets/primary/general_frlg/night_metatiles.bin'
PRIMARY_ATTR = 'data/tilesets/primary/general_frlg/metatile_attributes.bin'
LAWN = {0x001, 0x004, 0x008, 0x009, 0x010, 0x011}
LAYER_MASK = 0x60000000


def git(*args):
    return subprocess.check_output(['git', '-C', str(REPO), *args])


def original(path):
    return git('show', BASE+':'+path)


def words(blob):
    return [x[0] for x in struct.iter_unpack('<H', blob)]


def expected():
    before = words(original(MAP))
    after = before.copy()
    seen = set()
    for edit in PLAN['edits']:
        x, y = edit['x'], edit['y']
        x0, y0, x1, y1 = PLAN['zones'][edit['zone']]
        assert x0 <= x <= x1 and y0 <= y <= y1
        assert (x, y) not in seen
        seen.add((x, y))
        i = y*48+x
        assert before[i] & 1023 == edit['old']
        assert 0 <= edit['new'] < 640+len(original(META))//16, 'use existing pieces only'
        after[i] = (before[i] & ~1023) | edit['new']
    generated = {MAP: struct.pack('<1920H', *after), META: original(META), ATTR: original(ATTR)}
    manifest = dict(issue=348, baseline=BASE, edits=PLAN['edits'], composites=[],
                    assets={p: dict(before_sha256=hashlib.sha256(original(p)).hexdigest(),
                                    after_sha256=hashlib.sha256(b).hexdigest())
                            for p, b in generated.items()})
    return generated, manifest


def render(assets, layout, cells):
    width, height = layout['width'], layout['height']
    im = Image.new('RGB', (width*16, height*16))
    cache = {mid: assets.render(layout, mid) for mid in {v & 1023 for v in cells}}
    for i, word in enumerate(cells):
        im.paste(cache[word & 1023], (i % width*16, i//width*16))
    return im


def check(out):
    generated, manifest = expected()
    for path, blob in generated.items():
        assert (REPO/path).read_bytes() == blob, ('author output differs', path)
    assert json.loads((HERE/'edits.json').read_text()) == manifest
    # Scope is part of the proof: source tiles, palettes, map events, scripts,
    # headers and every other layout must still be the immutable baseline.
    production = [p for p in git('diff', '--name-only', BASE, '--').decode().splitlines()
                  if not p.startswith('test/overworld/viridian-frontages/')]
    assert set(production) == {MAP}, production
    untracked = git('ls-files', '--others', '--exclude-standard').decode().splitlines()
    assert all(p.startswith('test/overworld/viridian-frontages/') for p in untracked), untracked
    for path in (META, ATTR):
        assert generated[path].startswith(original(path)), path
    before, after = words(original(MAP)), words(generated[MAP])
    pa = list(struct.unpack('<'+'I'*(len(original(PRIMARY_ATTR))//4), original(PRIMARY_ATTR)))
    sa0 = list(struct.unpack('<'+'I'*(len(original(ATTR))//4), original(ATTR)))
    sa1 = list(struct.unpack('<'+'I'*(len(generated[ATTR])//4), generated[ATTR]))

    def attribute(word, secondary):
        mid = word & 1023
        return pa[mid] if mid < 640 else secondary[mid-640]

    for i, (old, new) in enumerate(zip(before, after)):
        assert old & ~1023 == new & ~1023, ('collision/elevation', i)
        assert attribute(old, sa0) & ~LAYER_MASK == attribute(new, sa1) & ~LAYER_MASK, ('gameplay attribute', i)
    map_data = json.loads(original('data/maps/ViridianCity_Frlg/map.json'))
    protected = {(event['x'], event['y']) for kind in ('warp_events', 'coord_events', 'bg_events', 'object_events')
                 for event in map_data[kind]}
    protected.update((x, y) for y in range(6, 13) for x in range(19, 23))
    protected.update((36, y) for y in range(10, 14))
    for event in map_data['object_events']:
        if 'WANDER' in event['movement_type']:
            protected.update((x, y) for y in range(event['y']-event['movement_range_y'], event['y']+event['movement_range_y']+1)
                             for x in range(event['x']-event['movement_range_x'], event['x']+event['movement_range_x']+1))
    stage1 = json.loads(original('test/overworld/viridian-art/plan.json'))
    gardens = set()
    for bed in stage1['beds'] + [stage1['verge']]:
        x0, y0, x1, y1 = bed['bounds']
        gardens.update((x, y) for x in range(x0, x1+1) for y in range(y0, y1+1))
    protected.update(gardens)
    paths = {(e['x'], e['y']) for e in json.loads(original('test/overworld/viridian-transitions/edits.json'))['edits']}
    protected.update(paths)
    protected.update((x, y) for x in range(48) for y in range(40) if x in (0,47) or y in (0,39))
    protected.update((e['x'], e['y']+1) for e in map_data['warp_events'])
    for x, y in protected:
        assert before[y*48+x] == after[y*48+x], ('protected gameplay cell', x, y)

    # The cell-level semantic equality above covers all movement mechanics.
    # Also compare conservative, four-direction walking components at every
    # doorway and connection. Surf and ledge rules are not simulated here.
    def walk_component(cells, secondary, seeds):
        def walkable(x, y):
            if not (0 <= x < 48 and 0 <= y < 40):
                return False
            word = cells[y*48+x]
            return (word >> 10) & 3 == 0 and attribute(word, secondary) & 511 == 0
        reached = {p for p in seeds if walkable(*p)}
        queue = deque(reached)
        while queue:
            x, y = queue.popleft()
            elevation = cells[y*48+x] >> 12
            for dx, dy in ((0, 1), (1, 0), (0, -1), (-1, 0)):
                p = x+dx, y+dy
                if p not in reached and walkable(*p):
                    other = cells[p[1]*48+p[0]] >> 12
                    if elevation in (0, 15) or other in (0, 15) or elevation == other:
                        reached.add(p)
                        queue.append(p)
        return reached
    entries = {f'door_{e["x"]}_{e["y"]}': [(e['x'], e['y']+1)] for e in map_data['warp_events']}
    entries.update(route1=[(23, 39)], route2=[(21, 0)], route22=[(0, 18)])
    reachable = {}
    for name, seeds in entries.items():
        old = walk_component(before, sa0, seeds)
        new = walk_component(after, sa1, seeds)
        assert old and old == new, ('walk component changed', name)
        reachable[name] = len(new)

    a, b = Assets(REPO), Assets(REPO)
    a.sets['gTileset_ViridianCity']['meta'] = list(struct.iter_unpack('<8H', original(META)))
    out.mkdir(parents=True, exist_ok=True)
    layout = b.towns[PLAN['map']]
    masks = panes.source_masks(b, layout, PLAN['scenes'], before, after)
    render(a, layout, before).save(out/'source-before.png')
    render(b, layout, after).save(out/'source-after.png')
    # Review-only source overlays: red protected cells, yellow authored cells.
    scope = render(b, layout, after).resize((1536,1280), Image.Resampling.NEAREST)
    drawing = ImageDraw.Draw(scope)
    for x, y in protected:
        drawing.rectangle((x*32,y*32,x*32+31,y*32+31), outline='#ff5060', width=2)
    for edit in manifest['edits']:
        x,y=edit['x'],edit['y']
        drawing.rectangle((x*32,y*32,x*32+31,y*32+31), outline='#ffff00', width=3)
    drawing.rectangle((0,0,740,30),fill='black')
    drawing.text((8,8),'Source map: RED = protected / YELLOW = changed / coordinates are zero-based',fill='white')
    scope.save(out/'scope.png')
    ids=sorted({e[k] for e in manifest['edits'] for k in ('old','new')})
    atlas=Image.new('RGB',(8*88,((len(ids)+7)//8)*88),'#202828')
    drawing=ImageDraw.Draw(atlas)
    for i,mid in enumerate(ids):
        x,y=i%8*88,i//8*88
        atlas.paste(b.render(layout,mid).resize((64,64),Image.Resampling.NEAREST),(x,y))
        drawing.text((x,y+66),f'0x{mid:03X}',fill='white')
    atlas.save(out/'atlas.png')
    routes = []
    for row in b.layouts.values():
        if row['secondary_tileset'] == 'gTileset_ViridianCity' and row['id'] != layout['id']:
            cells = b.words(row)
            assert ImageChops.difference(render(a, row, cells), render(b, row, cells)).getbbox() is None, row['name']
            routes.append(row['name'])
    assert len(routes) == 4
    audit = dict(baseline=BASE, changed_cells=len(manifest['edits']), appended_metatiles=len(manifest['composites']),
                 collision_elevation_cells_verified=len(after), nonvisual_attributes_verified=len(after),
                 protected_cells_verified=len(protected), garden_cells_verified=len(gardens), path_cells_verified=len(paths), unchanged_glass_pixels={k: len(v) for k,v in masks.items()}, walking_components=reachable,
                 unchanged_shared_routes=routes, append_only=True, source_art_and_palettes_unchanged=True)
    (out/'audit.json').write_text(json.dumps(audit, indent=2)+'\n')
    print(json.dumps(audit, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=('author', 'check'))
    parser.add_argument('--out', type=Path, default=HERE/'evidence')
    args = parser.parse_args()
    if args.command == 'author':
        generated, manifest = expected()
        for path, blob in generated.items():
            assert (REPO/path).read_bytes() in (original(path), blob), ('refusing to replace unrelated edits', path)
        for path, blob in generated.items():
            (REPO/path).write_bytes(blob)
        (HERE/'edits.json').write_text(json.dumps(manifest, indent=2)+'\n')
        print(f'Authored {len(manifest["edits"])} cells and {len(manifest["composites"])} local compositions.')
    else:
        check(args.out)


if __name__ == '__main__':
    main()
