#!/usr/bin/env python3
"""Check selected donor cells for pixel-exact equivalents in existing World art."""
import argparse,pathlib,json,hashlib,collections
from render_study import Source,tile_image,apply_animation_frame
p=argparse.ArgumentParser();p.add_argument('--world',type=pathlib.Path,default=pathlib.Path(__file__).resolve().parents[3]);p.add_argument('--donor',type=pathlib.Path,required=True);p.add_argument('--output',type=pathlib.Path,default=pathlib.Path(__file__).parent/'existing-asset-matches.json');a=p.parse_args();ws,ds=Source(a.world),Source(a.donor);d=ds.map('FuchsiaCity_hns');apply_animation_frame(d,ds,True)
rows=json.loads((pathlib.Path(__file__).parent/'mapping.json').read_text())['rows'];wanted={int(r['donorMetatile'],16) for r in rows if r['source']=='donor'};hashes=collections.defaultdict(list)
for i in wanted:hashes[hashlib.sha256(tile_image(d,i).tobytes()).hexdigest()].append(i)
matches=collections.defaultdict(list)
for name in ['CherrygroveCity','NewBarkTown','VioletCity','GoldenrodCity','NationalPark_Normal']:
 m=ws.map(name)
 for i in range(len(m['metatiles'])):
  for donor_id in hashes.get(hashlib.sha256(tile_image(m,i).tobytes()).hexdigest(),[]):matches[f'0x{donor_id:03X}'].append({'worldMapTilesetReference':name,'metatile':f'0x{i:03X}','tileset':m['primary' if i<640 else 'secondary']['symbol']})
a.output.write_text(json.dumps(dict(sorted(matches.items())),indent=2));print('Exact rendered matches:',len(matches),'of',len(wanted),'selected donor metatiles')
