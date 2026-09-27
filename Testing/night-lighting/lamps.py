#!/usr/bin/env python3
"""Place reused lamp art on audited clear ground, with a small footprint per town."""
import argparse
import collections
import json
from pathlib import Path
import struct
import re

from PIL import Image
from assets import Assets

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--base',type=Path,required=True)
p.add_argument('--out',type=Path,required=True)
args=p.parse_args()
assert args.base.resolve()!=args.out.resolve(),'Use a separate, unchanged baseline checkout'
a=Assets(args.out);base=Assets(args.base)
report={'donors':{'modern':['OlivineCity','348','350 top','358 bottom'],'lantern':['BlackthornCity','298','2A0']},'placements':[],'modified_paths':[],'tiles':{},'metatiles':[]}
modified=set()
labels=(args.base/'include/constants/metatile_labels.h').read_text()
script_numbers=set()
for path in (args.base/'data').rglob('*.inc'):
    for m in re.finditer(r'\bsetmetatile\s+[^,]+,[^,]+,\s*(0x[0-9A-Fa-f]+|[0-9]+)\s*,',path.read_text(errors='replace')):
        script_numbers.add(int(m[1],0))
def save(path,data):
    path.write_bytes(data);modified.add(str(path.relative_to(args.out)))
def attributes(s):
    path=s['folder']/'metatile_attributes.bin';data=path.read_bytes();width=len(data)//len(s['meta'])
    assert width in (2,4),(path,width)
    return path,width,[x[0] for x in struct.iter_unpack('<H' if width==2 else '<I',data)]
def owner(l,mid):
    split,_=a.split(l);return a.sets[l['primary_tileset' if mid<split else 'secondary_tileset']],mid if mid<split else mid-split

def ground(layout,row):
    result=[]
    for low,high in zip(row[:4],row[4:]):
        tile,_,_=a.tile(layout,high)
        pixels=list(tile.get_flattened_data())
        if not any(pixels):result.append(low)
        elif all(pixels):result.append(high)
        else:return None
    return result

donors={}
for style,town,mids in [('modern','OlivineCity',[0x348,0x358]),('lantern','BlackthornCity',[0x298,0x2A0])]:
    l=base.towns[town];s=base.sets[l['secondary_tileset']];pixels=[]
    for mid in mids:
        row=[]
        donor_cells=s['meta'][mid-640][4:]
        if style=='modern' and mid==0x358:
            donor_cells=s['meta'][0x350-640][4:6]+s['meta'][0x358-640][6:8]
        for v in donor_cells:
            tile,pal,flags=base.tile(l,v)
            data=[]
            for y in range(8):
                for x in range(8):
                    c=tile.getpixel((7-x if v&1024 else x,7-y if v&2048 else y))
                    data.append((pal[c],c in flags) if c else None)
            row.append(data)
        pixels.append(row)
    donors[style]=pixels

# Allocate shared art once in each primary. Never use animation DMA destinations.
primaries={l['primary_tileset'] for l in a.towns.values()}
for name in sorted(primaries):
    s=a.sets[name];l=next(l for l in a.towns.values() if l['primary_tileset']==name)
    split,ps=a.split(l);johto=l['layout_version']=='johto';bank=3 if johto else (12 if ps==6 else 7)
    palowner=s if johto else a.sets[l['secondary_tileset']]
    pal=palowner['palettes'][bank];flags=palowner['masks'].get(bank,set());assert flags
    # Include every secondary paired with this graphics sheet, including the unlit variant.
    sharing={n for n,t in a.sets.items() if t['folder']==s['folder']}
    secondaries={ll['secondary_tileset'] for ll in a.layouts.values() if ll['primary_tileset'] in sharing}
    used={v&1023 for n in sharing|secondaries if n in a.sets for row in a.sets[n]['meta'] for v in row}
    animated=(set(range(432,462))|set(range(464,474))|set(range(480,490))|set(range(496,502))|set(range(508,512))) if ps==6 else ((set(range(416,434))|set(range(450,462))|set(range(508,512))) if johto else (set(range(416,482))|set(range(508,512))))
    free=[i for i in range(1,split) if i not in used and i not in animated]
    style='lantern' if johto else 'modern'
    needed=sum(bool(any(data)) for row in donors[style] for data in row)
    assert len(free)>=needed,(name,len(free),needed)
    sheet=s['image'].copy();cells=[]
    for row in donors[style]:
        words=[]
        for data in row:
            if not any(data):words.append(0);continue
            tid=free.pop(0);tile=Image.new('P',(8,8));tile.putpalette(sheet.getpalette())
            values=[]
            for item in data:
                if item is None:values.append(0);continue
                rgb,lit=item
                candidates=[i for i in range(1,16) if (i in flags)==lit]
                assert candidates
                values.append(min(candidates,key=lambda i:sum((pal[i][c]-rgb[c])**2 for c in range(3))))
            tile.putdata(values);sheet.paste(tile,(tid%16*8,tid//16*8));words.append(bank<<12|tid)
        cells.append(words)
    sheet.save(s['folder']/'tiles.png',optimize=True);modified.add(str((s['folder']/'tiles.png').relative_to(args.out)))
    report['tiles'][name]={'palette':bank,'style':style,'cells':cells}

# Existing Johto lamp/lantern networks stay in place. Add two fixtures in gaps.
existing={'VioletCity','GoldenrodCity','EcruteakCity','OlivineCity','BlackthornCity'}
allocated={};meta_cache={};attrs_cache={};pending_maps={}
for town,l in sorted(a.towns.items()):
    if town in existing:continue
    compact=town=='PacifidlogTown'
    s=a.sets[l['secondary_tileset']];name=l['secondary_tileset'];split,_=a.split(l)
    if name not in meta_cache:
        meta_cache[name]=list(s['meta']);attrs_cache[name]=attributes(s)
    ap,width,attrs=attrs_cache[name];rows=meta_cache[name]
    words=a.words(l);w,h=l['width'],l['height'];m=a.maps[town]
    events={(o['x'],o['y']) for key in ('object_events','warp_events','coord_events','bg_events') for o in m.get(key,[])}
    def eligible(x,y):
        if not (3<=x<w-3 and 3<=y<h-3):return False
        if any(abs(x-ex)<=2 and abs(y-ey)<=2 for ex,ey in events):return False
        if any(abs(x-o['x'])<=o.get('movement_range_x',0)+2 and abs(y-o['y'])<=o.get('movement_range_y',0)+2 for o in m.get('object_events',[])):return False
        level=words[y*w+x]&0xF000
        for dy in (-1,0,1):
            for dx in (-1,0,1):
                v=words[(y+dy)*w+x+dx]
                if v&0xC00 or v&0xF000!=level:return False
                os,oi=owner(l,v&1023);_,ow,oa=attributes(os)
                if oi>=len(oa) or (oa[oi]&(0x1FF if ow==4 else 0xFF)) not in (0,7,10,33,37):return False
        for yy in [y-1,y]:
            os,oi=owner(l,words[yy*w+x]&1023)
            # Keep the existing ground layer. Never erase a foreground decoration.
            if ground(l,os['meta'][oi]) is None:return False
        return True
    lights=[]
    cache={}
    for i,v in enumerate(words):
        mid=v&1023
        if mid not in cache:cache[mid]=bool(a.render(l,mid,True).getbbox())
        if cache[mid]:lights.append((i%w,i//w))
    candidates=[]
    for y in range(3,h-3):
        for x in range(3,w-3):
            if not eligible(x,y):continue
            distance=min((abs(x-lx)+abs(y-ly) for lx,ly in lights if ly<=y-2),default=100)
            if distance>10:continue
            # Close to buildings, with enough room for a clear approach.
            score=abs(distance-5)*4+(abs(x-w//2)+abs(y-h//2))//4
            candidates.append((score,x,y))
    sites=[]
    for _,x,y in sorted(candidates):
        if all(abs(x-px)+abs(y-py)>=8 for px,py in sites):sites.append((x,y))
        if len(sites)==2:break
    overrides=json.loads(Path(__file__).with_name('placement_overrides.json').read_text())
    if town in overrides:
        sites=[tuple(site) for site in overrides[town]]
        for x,y in sites:
            for yy in ((y,) if compact else (y-1,y)):
                v=words[yy*w+x]
                assert not v&0xC00,(town,x,yy,'collision')
                os,oi=owner(l,v&1023)
                assert ground(l,os['meta'][oi]) is not None,(town,x,yy,'foreground')
                _,ow,oa=attributes(os)
                allowed=(0,7,10,33,37,21) if yy==y-1 else (0,7,10,33,37)
                assert (oa[oi]&(0x1FF if ow==4 else 255)) in allowed,(town,x,yy,'behavior')
            assert (x,y) not in events,(town,x,y,'event')
            assert not any(abs(x-o['x'])<=o.get('movement_range_x',0) and abs(y-o['y'])<=o.get('movement_range_y',0) for o in m.get('object_events',[])),(town,x,y,'NPC range')
    if not sites:
        report.setdefault('placement_exceptions',[]).append(town);continue
    for x,y in sites:
        ids=[]
        for half,yy in ([(2,y)] if compact else list(enumerate([y-1,y]))):
            original=words[yy*w+x];os,oi=owner(l,original&1023)
            bottom=ground(l,os['meta'][oi]);assert bottom is not None
            fixture=report['tiles'][l['primary_tileset']]['cells']
            lamp=(fixture[0][2:]+fixture[1][:2]) if compact else fixture[half]
            row=tuple(bottom)+tuple(lamp)
            key=(name,row)
            if key not in allocated:
                if len(rows)<1023-split:
                    index=len(rows);rows.append(row);attrs.append(0)
                else:
                    used={v&1023 for ll in a.layouts.values() if ll['secondary_tileset']==name for v in a.words(ll)+a.words(ll,True)}
                    reserved={int(m[1],16) for m in re.finditer(r'#define METATILE_'+re.escape(name.removeprefix('gTileset_'))+r'_\w+\s+0x([0-9A-Fa-f]+)',labels)}|script_numbers|{1023}
                    counts=collections.Counter(tuple(r) for r in rows)
                    free=[i for i,r in reversed(list(enumerate(rows))) if split+i not in used|reserved and counts[tuple(r)]>1 and attrs[i]==0 and split+i not in {mid for (n,_),mid in allocated.items() if n==name}]
                    if not free:
                        free=[i for i,r in reversed(list(enumerate(rows))) if split+i not in used|reserved and attrs[i]==0 and split+i not in {mid for (n,_),mid in allocated.items() if n==name}]
                    assert free,('no safe metatile slot',town)
                    index=free[0];rows[index]=row
                # Preserve walking effects (sand, short grass, and dock no-running).
                _,ow,oa=attributes(os)
                layer=1 if half in (1,2) else 0
                attrs[index]=(oa[oi]&(0x1FF if ow==4 else 0xFF))|(layer<<(29 if width==4 else 12))
                allocated[key]=split+index
                report['metatiles'].append({'tileset':name,'id':split+index,'source':original&1023,'half':half})
            mid=allocated[key];ids.append(mid)
            words[yy*w+x]=(original&0xF000)|mid|(0x400 if half in (1,2) else 0)
        report['placements'].append({'town':town,'x':x,'y':y,'metatiles':ids,'height':1 if compact else 2})
    pending_maps[args.out/l['blockdata_filepath']]=struct.pack('<'+'H'*len(words),*words)
for name,rows in meta_cache.items():
    if rows==a.sets[name]['meta']:continue
    save(a.sets[name]['meta_path'],b''.join(struct.pack('<8H',*r) for r in rows))
    ap,width,attrs=attrs_cache[name];save(ap,struct.pack('<'+('H' if width==2 else 'I')*len(attrs),*attrs))
for path,data in pending_maps.items():save(path,data)
report['modified_paths']=sorted(modified)
(args.out/'Testing/night-lighting/lamps.json').write_text(json.dumps(report,indent=2)+'\n')
print(f'{len(report["placements"])} reused lamps placed; exceptions: {report.get("placement_exceptions",[])}')
