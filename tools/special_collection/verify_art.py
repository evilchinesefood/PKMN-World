#!/usr/bin/env python3
"""Validate native frame layout, palette ownership and generated artifact hashes."""
from pathlib import Path
import hashlib
import json
import re
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
ASSETS=ROOT/'graphics/pokemon/special_collection'

def colors(path):
    return [int(v) for row in path.read_text().splitlines()[3:19] for v in row.split()]

def main():
    entries=json.loads((ASSETS/'manifest.json').read_text())
    assert len(entries)==7 and len({e['key'] for e in entries})==7
    active={e['key'] for e in entries}
    assert {p.name for p in ASSETS.iterdir() if p.is_dir() and p.name!='source'}==active, 'Uncatalogued art directory'
    species_text=(ROOT/'src/data/pokemon/species_info/special_collection.h').read_text()
    icon_bindings=dict(re.findall(r'SPECIAL_GRAPHICS\((\w+), (\d+)\)',species_text))
    frames=0
    for entry in entries:
        assert not entry['female'], 'All collection appearances are shared across genders'
        assert int(icon_bindings[entry['symbol']])==entry['icon_palette'], (entry['key'], 'runtime icon palette mismatch')
        folder=ASSETS/entry['key']
        for name,digest in entry['files'].items():
            p=folder/name;assert hashlib.sha256(p.read_bytes()).hexdigest()==digest,(p,'manifest is stale')
            if p.suffix!='.png':continue
            im=Image.open(p);assert im.mode=='P' and max(im.getdata())<16,p
            view='overworld' if name.startswith('overworld') else 'icon' if name.startswith('icon') else 'anim_front' if name.startswith('anim_front') else 'back'
            expected={'overworld':(entry['follower_frames']*32,32),'icon':(32,64),'anim_front':(64,128),'back':(64,64)}[view]
            assert im.size==expected,(p,im.size,expected)
            pal=(ROOT/f"graphics/pokemon/icon_palettes/pal{entry['icon_palette']}.pal") if view=='icon' else folder/('overworld_normal.pal' if view=='overworld' else 'normal.pal')
            assert im.getpalette()[:48]==colors(pal),(p,'palette mismatch')
            size=32 if view in ('overworld','icon') else 64
            count=im.width//size if view=='overworld' else im.height//size
            for i in range(count):
                box=(i*size,0,(i+1)*size,size) if view=='overworld' else (0,i*size,size,(i+1)*size)
                assert im.crop(box).getbbox(),(p,'empty frame',i)
                frames+=1
        assert len(list(folder.glob('*f.png')))==(4 if entry['female'] else 0),entry['key']
    print(f'PASS: seven complete indexed sets, {frames} nonempty frames, palette and hash contracts')

if __name__=='__main__':main()
