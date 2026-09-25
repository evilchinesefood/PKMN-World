#!/usr/bin/env python3
"""Source-derived Fuchsia comparison; never modifies game data. Requires Pillow.

Pinned donor files are fetched into a separate cache by fetch_donor.py.
This renderer reads indexed PNGs, GBA palettes, 16-bit tile descriptors, and
per-tileset 16/32-bit attributes. No screenshot manipulation or AI art.
"""
from __future__ import annotations
import argparse, collections, hashlib, json, pathlib, re, struct
from PIL import Image, ImageDraw, ImageFont

class Source:
    def __init__(self, root):
        self.root=pathlib.Path(root)
        self.headers=(self.root/'src/data/tilesets/headers.h').read_text()
        self.graphics=(self.root/'src/data/tilesets/graphics.h').read_text()+'\n'+(self.root/'src/graphics.c').read_text()
        self.metafile=(self.root/'src/data/tilesets/metatiles.h').read_text()
        self.paths=dict(re.findall(r'const u(?:16|32)\s+(\w+)\[\]\s*=\s*INCBIN_U(?:16|32)\("([^"]+)"\)',self.metafile))
        self.layouts=json.loads((self.root/'data/layouts/layouts.json').read_text())['layouts']
    def read16(self,path):
        b=(self.root/path).read_bytes();return list(struct.unpack('<'+'H'*(len(b)//2),b))
    def palette(self,path):
        lines=(self.root/path).read_text().splitlines()
        return [[round((int(v)>>3)*255/31) for v in line.split()] for line in lines[3:19]]
    def indices(self,path):
        im=Image.open(self.root/path);assert im.mode=='P',path
        return [im.getpixel((tx+x,ty+y)) for ty in range(0,im.height,8) for tx in range(0,im.width,8) for y in range(8) for x in range(8)]
    def tileset(self,symbol):
        hdr=re.search(r'const struct Tileset '+symbol+r'\s*=\s*\{(.*?)\};',self.headers,re.S).group(1)
        ts=re.search(r'\.tiles\s*=\s*(\w+)',hdr).group(1);ps=re.search(r'\.palettes\s*=\s*(\w+)',hdr).group(1)
        path=re.search(r'const u32 '+ts+r'\[\]\s*=\s*INC(?:GFX|BIN)_U32\("([^"]+)"',self.graphics).group(1)
        path=re.sub(r'\.4bpp(?:\.\w+)?$','.png',path)
        pals=re.search(ps+r'\[[^\]]*\]\[16\]\s*=\s*\{(.*?)\};',self.graphics,re.S).group(1)
        palpaths=[p.replace('.gbapal','.pal') for p in re.findall(r'INC(?:GFX|BIN)_U16\("([^"]+)"',pals)]
        macro=re.search(r'TILESET_METATILES\((\w+),\s*(\w+)\)',hdr)
        if macro:ms,ats=macro.groups()
        else:ms=re.search(r'\.metatiles\s*=\s*(\w+)',hdr).group(1);ats=re.search(r'\.metatileAttributes\s*=\s*(\w+)',hdr).group(1)
        words=self.read16(self.paths[ms]);mts=[words[i:i+8] for i in range(0,len(words),8)]
        raw=(self.root/self.paths[ats]).read_bytes();size=len(raw)//len(mts)
        assert size in [2,4],(symbol,size)
        attrs=list(struct.unpack('<'+('H' if size==2 else 'I')*len(mts),raw))
        return dict(symbol=symbol,imagePath=path,metatilePath=self.paths[ms],attributePath=self.paths[ats],palettePaths=palpaths,palettes=[self.palette(p) for p in palpaths],indices=self.indices(path),metatiles=mts,attributes=attrs,attributeBytes=size,callback=re.search(r'\.callback\s*=\s*(\w+)',hdr).group(1))
    def map(self,name):
        meta=json.loads((self.root/'data/maps'/name/'map.json').read_text());layout=next(x for x in self.layouts if x['id']==meta['layout'])
        p,s=[self.tileset(layout[x]) for x in ['primary_tileset','secondary_tileset']]
        version=layout.get('layout_version','emerald');split=512 if version=='emerald' else 640;psplit=6 if split==512 else 7
        raw=p['indices'][:split*64]+[0]*max(0,split*64-len(p['indices']))+s['indices']
        mts=p['metatiles'][:split]+[[0]*8 for _ in range(max(0,split-len(p['metatiles'])))]+s['metatiles']
        attrs=p['attributes'][:split]+[0]*max(0,split-len(p['attributes']))+s['attributes']
        layers=[(a>>12)&15 if (p['attributeBytes'] if i<split else s['attributeBytes'])==2 else (a>>29)&3 for i,a in enumerate(attrs)]
        return dict(name=name,width=layout['width'],height=layout['height'],layout=layout,primary=p,secondary=s,indices=raw,metatiles=mts,layers=layers,blocks=self.read16(layout['blockdata_filepath']),palettes=p['palettes'][:psplit]+s['palettes'][psplit:13],events=meta)

def tile_image(m,index):
    out=Image.new('RGB',(16,16),tuple(m['palettes'][0][0]));px=out.load()
    descriptors=([0x3014]*4 if m['layers'][index]==0 else [])+m['metatiles'][index]
    for q,d in enumerate(descriptors):
        t=d&1023;flipx=d&1024;flipy=d&2048;bank=d>>12
        if bank>=len(m['palettes']):continue
        for y in range(8):
            for x in range(8):
                ci=m['indices'][t*64+(7-y if flipy else y)*8+(7-x if flipx else x)]
                if ci: px[q%2*8+x,(q%4//2)*8+y]=tuple(m['palettes'][bank][ci])
    return out

def render(m,replacements=None):
    cache={};out=Image.new('RGB',(m['width']*16,m['height']*16))
    for i,b in enumerate(m['blocks']):
        idx=b&1023
        if idx not in cache:cache[idx]=(replacements or {}).get(idx) or tile_image(m,idx)
        out.paste(cache[idx],(i%m['width']*16,i//m['width']*16))
    return out

def atlas(m,ids,path,cols=16,scale=3):
    cell=16*scale+4;row=16*scale+16;out=Image.new('RGB',(cols*cell,((len(ids)+cols-1)//cols)*row),'#1c2028');d=ImageDraw.Draw(out)
    for j,idx in enumerate(ids):
        x=j%cols*cell;y=j//cols*row;out.paste(tile_image(m,idx).resize((16*scale,16*scale),Image.Resampling.NEAREST),(x,y));d.text((x,y+16*scale+1),f'{idx:03X}',fill='white')
    out.save(path)

def apply_animation_frame(m,source,donor=False):
    if donor:
        folder='data/tilesets/primary/johto_general_hns/anim'
    else:folder='data/tilesets/primary/general_frlg/anim'
    # Callback source: World 1314/1321; donor 1634/1640/1648.
    # HnS land-water queue is intentionally empty; its base art remains loaded.
    edits=[('sandwatersedge',416,18,0),('water_current_landwatersedge',450,12,34),('flower',508,4,0)] if donor else [('water_current_landwatersedge',416,48,0),('sandwatersedge',464,18,0),('flower',508,4,0)]
    for name,start,count,source_start in edits:
        indices=source.indices(f'{folder}/{name}/0.png');assert len(indices)>=(source_start+count)*64
        m['indices'][start*64:(start+count)*64]=indices[source_start*64:(source_start+count)*64]

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--world',type=pathlib.Path,default=pathlib.Path(__file__).resolve().parents[3]);ap.add_argument('--donor',type=pathlib.Path,required=True);ap.add_argument('--scratch',type=pathlib.Path,required=True);args=ap.parse_args();args.scratch.mkdir(parents=True,exist_ok=True)
    ws,ds=Source(args.world),Source(args.donor);w,d=ws.map('FuchsiaCity_Frlg'),ds.map('FuchsiaCity_hns')
    apply_animation_frame(w,ws);apply_animation_frame(d,ds,True)
    render(w).save(args.scratch/'current-overview.png');render(d).save(args.scratch/'donor-own-layout-reference.png')
    atlas(w,sorted(set(b&1023 for b in w['blocks'])),args.scratch/'world-used-metatiles.png')
    atlas(d,list(range(len(d['metatiles']))),args.scratch/'donor-all-metatiles.png')
    print(json.dumps({'world':{'metatiles':len(w['metatiles']),'primaryPixels':len(w['primary']['indices']),'secondaryPixels':len(w['secondary']['indices'])},'donor':{'metatiles':len(d['metatiles']),'primaryPixels':len(d['primary']['indices']),'secondaryPixels':len(d['secondary']['indices']),'primaryAttributeBytes':d['primary']['attributeBytes'],'secondaryAttributeBytes':d['secondary']['attributeBytes']}}))

# The build_comparison.py entry point produces the durable comparison.
# Atlas/debug files from this module's direct CLI remain in the scratch cache.
def build_deliverables(world_root, donor_root, output):
    output=pathlib.Path(output);images=output/'images';images.mkdir(parents=True,exist_ok=True)
    ws,ds=Source(world_root),Source(donor_root);w,d=ws.map('FuchsiaCity_Frlg'),ds.map('FuchsiaCity_hns')
    apply_animation_frame(w,ws);apply_animation_frame(d,ds,True)
    specification=json.loads((pathlib.Path(__file__).parent/'mapping.json').read_text());rows={int(r['worldMetatile'],16):r for r in specification['rows']}
    assert set(rows)==set(b&1023 for b in w['blocks']), 'Every used metatile requires an explicit art mapping'
    before=render(w);after=Image.new('RGB',before.size);cache={};cells=[];used_ids={'world':set(),'donor':set()};exception_count=0
    for pos,b in enumerate(w['blocks']):
        x,y=pos%w['width'],pos//w['width'];mid=b&1023;r=rows[mid];source=r['source'];target=int(r['donorMetatile'],16) if source=='donor' else mid
        exception=next((z for z in specification['cellRetainRegions'] if z['x0']<=x<=z['x1'] and z['y0']<=y<=z['y1']),None)
        if exception:source='world';target=mid;exception_count+=1
        key=(source,target)
        if key not in cache:cache[key]=tile_image(d if source=='donor' else w,target)
        after.paste(cache[key],(x*16,y*16));used_ids[source].add(target);cells.append({'x':x,'y':y,'source':source,'metatile':target,'worldMetatile':mid,'role':r['role']})
    before.save(images/'current-overview.png');after.save(images/'donor-concept-overview.png')
    cameras=[{'id':'01-pokemon-center','label':'Pokémon Center approach','x':288,'y':400}, {'id':'02-zoo-path','label':'Zoo-facing path','x':112,'y':240}, {'id':'03-residential-edge','label':'Residential boundary','x':496,'y':400}]
    for camera in cameras:
        x,y=camera['x'],camera['y'];box=(x,y,x+240,y+160)
        before.crop(box).save(images/(camera['id']+'-current.png'));after.crop(box).save(images/(camera['id']+'-donor.png'))
    sheet=Image.new('RGB',(988,3*356+52),'#151e24');draw=ImageDraw.Draw(sheet);font=ImageFont.load_default(size=15);draw.text((12,12),'CURRENT WORLD',fill='white',font=font);draw.text((500,12),'HnS CONCEPT - SAME WORLD LAYOUT',fill='white',font=font)
    for i,camera in enumerate(cameras):
        yy=45+i*356;draw.text((12,yy),camera['label'].replace('é','e')+' | static source render; actors omitted',fill='#d5e7e7',font=font)
        for x,suffix in [(12,'current'),(500,'donor')]:
            im=Image.open(images/(camera['id']+'-'+suffix+'.png'));sheet.paste(im.resize((480,320),Image.Resampling.NEAREST),(x,yy+22))
    sheet.save(images/'comparison-sheet.png')
    delta_pixels=sum(a!=b for a,b in zip(before.getdata(),after.getdata()));diffcells=sum(c['source']=='donor' and tile_image(w,c['worldMetatile']).tobytes()!=cache[('donor',c['metatile'])].tobytes() for c in cells)
    def inventory(m,ids):
        tiles=set();banks=set();descriptors=set()
        for mid in ids:
            for desc in ([0x3014]*4 if m['layers'][mid]==0 else [])+m['metatiles'][mid]:
                tile=desc&1023
                if any(m['indices'][tile*64:(tile+1)*64]):tiles.add(tile);banks.add(desc>>12);descriptors.add(desc)
        return {'metatiles':len(ids),'tileIds':sorted(tiles),'paletteBanks':sorted(banks),'descriptors':sorted(descriptors)}
    inventories={name:inventory(m,used_ids[name]) for name,m in [('world',w),('donor',d)]}
    unique_tiles=set();unique_palettes={};palette_origins=collections.defaultdict(list)
    for name,m in [('world',w),('donor',d)]:
        for tile in inventories[name]['tileIds']:unique_tiles.add(bytes(m['indices'][tile*64:(tile+1)*64]))
        for bank in inventories[name]['paletteBanks']:
            key=tuple(tuple(c) for c in m['palettes'][bank][1:]);unique_palettes[key]=True;palette_origins[str(bank)+':'+name]=m['palettes'][bank]
    counts=collections.Counter(c['source'] for c in cells)
    report={'worldCommit':'45e1bf82ca5c2728910127863b926e627d4f18fc','donorCommit':'167aa6d537b109bb229c231ddce4616974c4da71','layoutSize':[w['width'],w['height']],'worldLayoutSha256':hashlib.sha256((pathlib.Path(world_root)/w['layout']['blockdata_filepath']).read_bytes()).hexdigest(),'cameras':cameras,'mappedMetatileRoles':len(rows),'cellCountByArtSource':dict(counts),'retainedContextExceptionCells':exception_count,'visuallyChangedCells':diffcells,'visuallyChangedPixels':delta_pixels,'totalPixels':before.width*before.height,'sourceInventories':inventories,'sourceFormatInventory':{name:{'primaryTiles':len(m['primary']['indices'])//64,'secondaryTiles':len(m['secondary']['indices'])//64,'primaryMetatiles':len(m['primary']['metatiles']),'secondaryMetatiles':len(m['secondary']['metatiles']),'primaryAttributeBytes':m['primary']['attributeBytes'],'secondaryAttributeBytes':m['secondary']['attributeBytes'],'primaryPaletteBanks':7,'secondaryPaletteBanks':6} for name,m in [('world',w),('donor',d)]},'worldLayoutsSharingPrimary':sum(z['primary_tileset']==w['primary']['symbol'] for z in ws.layouts),'distinctIndexed8x8BitmapsBeforeRemapping':len(unique_tiles),'unmergedDistinctRGBPaletteRows':len(unique_palettes),'notes':['Both renders use the identical World map blocks. Cell art selection does not import donor map coordinates, collisions or scripts.','Tile/palette counts are inventories, not proof of an optimized VRAM packing: a ROM port also needs animation residency, light flags, palette remapping, doors and connection boundaries.','Current and donor use the actual source callback frame-0 assignments; donor land-water queue is disabled in its source.']}
    (output/'measurements.json').write_text(json.dumps(report,indent=2));(output/'cell-mapping.json').write_text(json.dumps(cells,separators=(',',':')))
    print(json.dumps({k:v for k,v in report.items() if k not in ['sourceInventories','notes']},indent=2))
