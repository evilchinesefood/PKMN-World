#!/usr/bin/env python3
"""Isolate Fallarbor house glass without illuminating its shared decorative colors."""
import argparse
import json
from pathlib import Path
import struct

from PIL import Image
from assets import Assets
from author import write_palette, warm

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--out',type=Path,required=True)
args=p.parse_args();a=Assets(args.out);l=a.towns['FallarborTown'];s=a.sets[l['secondary_tileset']]
rows=list(s['meta']);sheet=s['image'].copy();bank=12;pal=list(s['palettes'][bank]);flags=set(s['masks'][bank])
slots={9:11,10:12};source=s['palettes'][7]
for c,index in slots.items():
    assert pal[index]==(0,0,0),(index,pal[index])
    pal[index]=source[c];flags.add(index)
used={v&1023 for row in rows for v in row}
free=[512+i for i in range(1,min(sheet.width*sheet.height//64,496)) if 512+i not in used]
changes=[];copies={}
for mid,cells in [(0x29E,[2,3]),(0x2A6,[0,1])]:
    row=list(rows[mid-512])
    for k in cells:
        original=row[k];assert original>>12==7 and row[k+4]&1023==0
        key=original&0xF3FF
        if key not in copies:
            tile,_,_=a.tile(l,original)
            tid=free.pop(0);copy=Image.new('P',(8,8));copy.putpalette(sheet.getpalette())
            copy.putdata([slots.get(c,0) for c in tile.get_flattened_data()])
            sheet.paste(copy,((tid-512)%16*8,(tid-512)//16*8));copies[key]=tid
        row[k+4]=(bank<<12)|copies[key]|(original&0xC00)
        changes.append({'metatile':mid,'cell':k+4,'tile':copies[key]})
    rows[mid-512]=tuple(row)
paths=[]
def recorded(path):paths.append(str(path.relative_to(args.out)));return path
sheet.save(recorded(s['folder']/'tiles.png'),optimize=True)
recorded(s['meta_path']).write_bytes(b''.join(struct.pack('<8H',*row) for row in rows))
for slot,colors in [(12,pal),(5,[warm(c) if i in flags else c for i,c in enumerate(pal)])]:
    write_palette(recorded(s['folder']/f'palettes/{slot:02}.pal'),colors)
    recorded(s['folder']/f'palettes/{slot:02}.pla').write_text(''.join(f'{i}\n' for i in sorted(flags)))
(args.out/'test/overworld/night-lighting/fallarbor_glass.json').write_text(json.dumps({'changes':changes,'modified_paths':paths},indent=2)+'\n')
print('Isolated four Fallarbor glass quadrants; original structural colors unchanged.')
