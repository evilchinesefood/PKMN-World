#!/usr/bin/env python3
"""Audit authored RGB5 tables, export runtime expectations, and draw source sheets."""
import argparse
import hashlib
import json
from pathlib import Path
import re

from PIL import Image, ImageDraw

OUTFITS = ('RED', 'BLUE', 'GREEN', 'PURPLE', 'BLACK', 'PINK')
GENDERS = ('Male', 'Female')
SURFACES = ('OW', 'FrontPic', 'BackPic')


def read_tables(root):
    text = (root/'src/data/player_outfit_palettes.h').read_text()
    result = {}
    for gender in GENDERS:
        actor = 'brendan' if gender == 'Male' else 'may'
        for surface in SURFACES:
            key = surface+'_'+gender
            indices = list(map(int, re.search(r's'+surface+'ClothingIdx_'+gender+r'\[\]\s*=\s*\{([^}]+)', text)[1].split(',')))
            body = re.search(r'sOutfit'+key+r'\[NUM_PLAYER_OUTFITS\]\[\d+\]\s*=\s*\{(.*?)\n\};', text, re.S)[1]
            rows = {}
            for name,row in re.findall(r'\[PLAYER_OUTFIT_(\w+)\]\s*=\s*\{([^}]+)',body):
                rows[name] = [tuple(map(int,rgb)) for rgb in re.findall(r'RGB\(\s*(\d+),\s*(\d+),\s*(\d+)\)',row)]
            assert set(rows) == set(OUTFITS)
            assert len(indices) == len(set(indices)) and all(0 < i < 16 for i in indices)
            assert all(len(row)==len(indices) and all(0<=c<=31 for rgb in row for c in rgb) for row in rows.values())
            folder = 'object_events' if surface == 'OW' else 'trainers'
            base = [tuple(int(c)>>3 for c in line.split()) for line in
                    (root/f'graphics/{folder}/palettes/{actor}.pal').read_text().splitlines()[3:]]
            palettes = {}
            for outfit in OUTFITS:
                palette = base.copy()
                if outfit != 'RED':
                    for i,rgb in zip(indices,rows[outfit]): palette[i]=rgb
                palettes[outfit]=palette
            result[key] = {'indices':indices, 'rows':rows, 'base':base, 'palettes':palettes}
    return result


def rgb8(rgb):
    return tuple((c<<3)|(c>>2) for c in rgb)


def render(indexed, palette):
    result = Image.new('RGBA', indexed.size)
    result.putdata([(*rgb8(palette[index]), 255 if index else 0) for index in indexed.getdata()])
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--baseline', action='store_true')
    args = parser.parse_args()
    args.out.mkdir(parents=True,exist_ok=True)
    tables = read_tables(args.repo)
    if not args.baseline:
        for key,table in tables.items():
            expected = {10,11,12,13} if key.startswith('OW_') else {5,6,10,11,12,13}
            assert set(table['indices']) == expected, key
            assert table['rows']['RED'] == [table['base'][i] for i in table['indices']],key
            for outfit,row in table['rows'].items():
                for shadow,light in zip(row[::2],row[1::2]):
                    assert sum(c*w for c,w in zip(shadow,(299,587,114))) < sum(c*w for c,w in zip(light,(299,587,114))), (key,outfit)
                if outfit!='RED':
                    assert table['palettes'][outfit][15] == (0,0,0)
            assert table['rows']['PURPLE'] != table['rows']['PINK']
        # Independently tuned, not one row copied to all surfaces/genders.
        for outfit in OUTFITS[1:]:
            assert len({tuple(t['rows'][outfit]) for t in tables.values()}) == len(tables), outfit
    sheet = Image.new('RGB',(1200,1160),'#1c2b3b')
    draw = ImageDraw.Draw(sheet)
    rows = [('Male','OW'),('Male','FrontPic'),('Male','BackPic'),('Female','OW'),('Female','FrontPic'),('Female','BackPic')]
    sizes = [118,212,212,118,212,212]
    y = 25
    coverage = {}
    for row,(gender,surface) in enumerate(rows):
        actor = 'brendan' if gender=='Male' else 'may'
        folder = 'front_pics' if surface=='FrontPic' else 'back_pics'
        path = args.repo/(f'graphics/object_events/pics/people/{actor}/walking.png' if surface=='OW' else f'graphics/trainers/{folder}/{actor}.png')
        source = Image.open(path)
        visible = source.crop((0,0,48 if surface=='OW' else 64,32 if surface=='OW' else 64))
        key = surface+'_'+gender
        for col,outfit in enumerate(OUTFITS):
            tile = render(visible,tables[key]['palettes'][outfit])
            tile.save(args.out/f'{gender.lower()}_{surface.lower()}_{outfit.lower()}.png')
            tile = tile.resize((tile.width*3,tile.height*3),Image.Resampling.NEAREST)
            draw.text((col*200+4,y),f'{gender} {surface} / {outfit}',fill='white')
            sheet.paste(tile,(col*200+4,y+16),tile)
        y += sizes[row]
        # All indexed animation frames, including the other three back-pic poses.
        paths = sorted((args.repo/f'graphics/object_events/pics/people/{actor}').glob('*.png')) if surface=='OW' else [path]
        for asset in paths:
            if asset.name=='underwater.png':
                continue  # dedicated PLAYER_UNDERWATER palette; never enters this swap
            im=Image.open(asset)
            assert im.mode=='P'
            protected = sorted(set(im.getdata())-set(tables[key]['indices']))
            for outfit,palette in tables[key]['palettes'].items():
                assert all(palette[i]==tables[key]['base'][i] for i in protected),(asset,outfit)
            coverage[str(asset.relative_to(args.repo))]={'sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),
                'size':im.size, 'protected_indices':protected}
    sheet.save(args.out/'colorways.png')
    (args.out/'asset-audit.json').write_text(json.dumps({'tables':tables,'coverage':coverage},indent=2)+'\n')
    lua = ['return {']
    for key,table in tables.items():
        values = []
        for outfit in OUTFITS:
            words = [r|(g<<5)|(b<<10) for r,g,b in table['palettes'][outfit]]
            values.append('{'+','.join(str(v) for v in words)+'}')
        lua.append(key+'={'+','.join(values)+'},')
    lua.append('}')
    (args.out/'outfit_expected.lua').write_text('\n'.join(lua)+'\n')
    print(f'PASS: six surface/gender tables; {len(coverage)} indexed source sheets; all constant indices retained.')


if __name__=='__main__':
    main()
