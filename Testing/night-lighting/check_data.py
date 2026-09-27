#!/usr/bin/env python3
"""Check daylight preservation, lighting coverage, and lamp placement safety."""
import argparse
import collections
import json
from pathlib import Path
import struct

from PIL import ImageChops
from assets import Assets

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--base',type=Path,required=True)
p.add_argument('--repo',type=Path,required=True)
p.add_argument('--out',type=Path,required=True)
a=p.parse_args();before=Assets(a.base);after=Assets(a.repo);a.out.mkdir(parents=True,exist_ok=True)
lamps=json.loads((a.repo/'Testing/night-lighting/lamps.json').read_text())
assert not lamps.get('placement_exceptions')
placements=collections.defaultdict(list)
for item in lamps['placements']:placements[item['town']].append(item)
expected_lamps={'VioletCity','GoldenrodCity','EcruteakCity','OlivineCity','BlackthornCity'}
assert set(placements)|expected_lamps==set(after.towns)

def attr(assets,l,mid):
    split,_=assets.split(l);s=assets.sets[l['primary_tileset' if mid<split else 'secondary_tileset']]
    i=mid if mid<split else mid-split;path=s['attributes'];raw=path.read_bytes()
    # INCBIN_U16 may contain native u32 FRLG attributes. Match TILESET_METATILES,
    # which derives their width from the blob size and metatile count.
    width=len(raw)//len(s['meta'])
    assert width in (2,4) and (i+1)*width<=len(raw),(path,i)
    return int.from_bytes(raw[i*width:(i+1)*width],'little'),width

def rows(assets,l,mid):
    split,_=assets.split(l);s=assets.sets[l['primary_tileset' if mid<split else 'secondary_tileset']]
    return s['meta'][mid if mid<split else mid-split]

# Original map/border placements must render exactly as before in daylight.
# Comparing metatiles independently also covers off-screen neighboring routes.
seen=set();unchanged=0;baseline_invalid=[]
for lid,l in after.layouts.items():
    old=before.layouts[lid]
    if l['primary_tileset'] not in after.sets or l['secondary_tileset'] not in after.sets:continue
    for mid in set(v&1023 for v in before.words(old)+before.words(old,True)):
        key=(l['primary_tileset'],l['secondary_tileset'],mid)
        if key in seen:continue
        seen.add(key)
        try:reference=before.render(old,mid)
        except (IndexError,KeyError):
            baseline_invalid.append([old['name'],mid]);continue
        current=after.render(l,mid)
        assert ImageChops.difference(reference,current).getbbox() is None,(l['name'],hex(mid),'daytime changed')
        assert attr(before,old,mid)==attr(after,l,mid),(l['name'],hex(mid),'original metatile attributes changed')
        unchanged+=1

coverage=[]
for town,l in sorted(after.towns.items()):
    old=before.towns[town];original=before.words(old);current=after.words(l);w=l['width'];allowed={}
    events={(o['x'],o['y']) for key in ('object_events','warp_events','coord_events','bg_events') for o in after.maps[town].get(key,[])}
    for item in placements[town]:
        x,y=item['x'],item['y'];height=item['height'];lit=0
        assert (x,y) not in events,(town,x,y,'event')
        for offset,mid in enumerate(item['metatiles']):
            yy=y-height+1+offset;i=yy*w+x;allowed[i]=mid
            assert mid!=1023,'MAPGRID_UNDEFINED is reserved'
            assert current[i]&1023==mid
            assert original[i]&0xF000==current[i]&0xF000,'elevation changed'
            assert current[i]&0xC00==(0x400 if yy==y else original[i]&0xC00)
            old_attr,old_width=attr(before,old,original[i]&1023);new_attr,new_width=attr(after,l,mid)
            assert old_attr&(0x1FF if old_width==4 else 255)==new_attr&(0x1FF if new_width==4 else 255),'ground behavior changed'
            assert (new_attr>>(29 if new_width==4 else 12))&3==(1 if yy==y else 0),'lamp depth order'
            # Outside the reused foreground art, the ground must be pixel-identical.
            mask=set()
            for k,v in enumerate(rows(after,l,mid)[4:]):
                tile,_,_=after.tile(l,v)
                for py in range(8):
                    for px in range(8):
                        if tile.getpixel((7-px if v&1024 else px,7-py if v&2048 else py)):
                            mask.add((k%2*8+px,k//2*8+py))
            old_im=before.render(old,original[i]&1023);new_im=after.render(l,mid)
            assert all(old_im.getpixel((px,py))==new_im.getpixel((px,py)) for py in range(16) for px in range(16) if (px,py) not in mask),(town,x,yy,'ground erased')
            lit+=sum(c[0]!=0 for c in after.render(l,mid,True).get_flattened_data())
        assert lit>0,(town,x,y,'lamp has no lit bulb')
        # A lamp cannot occupy an NPC's ordinary movement rectangle.
        assert not any(abs(x-o['x'])<=o.get('movement_range_x',0) and abs(y-o['y'])<=o.get('movement_range_y',0) for o in after.maps[town].get('object_events',[])),(town,x,y,'NPC movement')
    assert {i for i,(b,c) in enumerate(zip(original,current)) if b!=c}==set(allowed),(town,'unexpected map edit')
    new_lamp_ids=set(allowed.values())
    windows=sum(bool(after.render(l,v&1023,True).getbbox()) for v in current if v&1023 not in new_lamp_ids)
    assert windows>0,(town,'no existing building lights')
    # Preserve connectivity of every previously walkable component. Water is
    # excluded; directional ledges are outside this conservative grid check.
    walkable=set()
    for i,v in enumerate(original):
        av,aw=attr(before,old,v&1023)
        if not v&0xC00 and (av&(0x1FF if aw==4 else 255)) not in (16,17,18,19,20,21,24,25,26):
            walkable.add(i)
    blocked={item['y']*w+item['x'] for item in placements[town]}
    def connected(start,valid):
        reached={start};queue=[start]
        while queue:
            i=queue.pop();x,y=i%w,i//w
            for xx,yy in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
                j=yy*w+xx
                if 0<=xx<w and 0<=yy<l['height'] and j in valid and j not in reached:
                    reached.add(j);queue.append(j)
        return reached
    remaining=set(walkable)
    while remaining:
        component=connected(next(iter(remaining)),walkable);remaining-=component
        after_component=component-blocked
        if after_component:
            assert connected(next(iter(after_component)),after_component)==after_component,(town,'lamp disconnects walking area')
    coverage.append({'town':town,'building_light_metatiles':windows,'new_lamps':len(placements[town]),'existing_lamps':town in expected_lamps})

# Map structure, scripts, events, and all other collision words stay untouched.
for lid,l in after.layouts.items():
    old=before.layouts[lid]
    if l not in after.towns.values():assert before.words(old)==after.words(l),l['name']
    assert before.words(old,True)==after.words(l,True),l['name']
for name,m in before.maps.items():assert after.maps[name]==m,name
result={'daylight_metatiles_verified':unchanged,'baseline_invalid_metatiles':baseline_invalid,'towns':coverage,'new_lamps':len(lamps['placements'])}
(a.out/'data-audit.json').write_text(json.dumps(result,indent=2)+'\n')
print(f'PASS: {unchanged} original metatile renderings preserved in daylight; {len(coverage)} towns have building lighting.')
print(f'PASS: {len(lamps["placements"])} reused lamps have lit bulbs, correct depth, preserved ground, and no event/NPC overlap.')
print(f'PASS: map edits confined to lamp cells; scripts/events, map borders, elevation, and walking effects retained. {len(baseline_invalid)} pre-existing invalid references recorded.')
