#!/usr/bin/env python3
"""Check window lighting while preserving every map cell and original attribute."""
import argparse
import json
from pathlib import Path

from PIL import ImageChops
from assets import Assets

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--base',type=Path,required=True)
p.add_argument('--repo',type=Path,required=True)
p.add_argument('--out',type=Path,required=True)
a=p.parse_args();before=Assets(a.base);after=Assets(a.repo);a.out.mkdir(parents=True,exist_ok=True)
# Window lighting must not change map geometry or collision behavior.
for path in (a.repo/'data/tilesets').rglob('metatile_attributes.bin'):
    relative=path.relative_to(a.repo)
    assert path.read_bytes()==(a.base/relative).read_bytes(),relative

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
        unchanged+=1

coverage=[]
for town,l in sorted(after.towns.items()):
    words=after.words(l)
    windows=sum(bool(after.render(l,v&1023,True).getbbox()) for v in words)
    assert windows>0,(town,'no existing building lights')
    coverage.append({'town':town,'building_light_metatiles':windows})

# Map structure, scripts, events, and all other collision words stay untouched.
for lid,l in after.layouts.items():
    old=before.layouts[lid]
    assert before.words(old)==after.words(l),l['name']
    assert before.words(old,True)==after.words(l,True),l['name']
for name,m in before.maps.items():assert after.maps[name]==m,name
result={'daylight_metatiles_verified':unchanged,'baseline_invalid_metatiles':baseline_invalid,'towns':coverage,'new_lamps':0,'all_map_cells_unchanged':True,'all_metatile_attributes_unchanged':True}
(a.out/'data-audit.json').write_text(json.dumps(result,indent=2)+'\n')
print(f'PASS: {unchanged} original metatile renderings preserved in daylight; {len(coverage)} towns have building lighting.')
print('PASS: no added lamps; all map cells, borders, events, and metatile attributes match baseline.')
print(f'PASS: {len(baseline_invalid)} pre-existing invalid references recorded.')
