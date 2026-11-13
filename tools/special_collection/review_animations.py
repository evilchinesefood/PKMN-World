#!/usr/bin/env python3
"""Preview current native sprite frames without inventing engine battle effects."""
from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageOps
from review_art import font,LABELS

ROOT=Path(__file__).resolve().parents[2]
ART=ROOT/'graphics/pokemon/special_collection'
OUT=ROOT/'_pwtest/special-collection/animation-preview'
WIDTH=1340
HEADER=104
ROW=214
COLUMNS=((170,'Front poses'),(380,'Back (static)'),(590,'Party icon'),(740,'South'),(890,'North'),(1040,'West'),(1190,'East'))


def cell(entry,name,index):
    im=Image.open(ART/entry['key']/(name+'.png')).convert('RGBA')
    size=32 if name in ('icon','overworld') else 64
    if name=='overworld':
        if index>=6 and not entry['asymmetric']:
            index-=2
            return ImageOps.mirror(im.crop((index*32,0,index*32+32,32)))
        return im.crop((index*32,0,index*32+32,32))
    return im.crop((0,index*size,size,(index+1)*size))


def render(entries,step,labels):
    out=Image.new('RGB',(WIDTH,HEADER+len(entries)*ROW),(188,204,214));d=ImageDraw.Draw(out);ink=(25,40,50)
    d.text((18,14),'SPECIAL POKÉMON | ANIMATION PREVIEW',font=font(23),fill=ink)
    d.text((18,48),'Existing sprite frames looped for review. Engine battle effects are not included.',font=font(16),fill=ink)
    for x,title in COLUMNS:d.text((x,80),title,font=font(15),fill=ink)
    walk=(0,1,1,0)[step]
    pose=step//2
    for row,(entry,label) in enumerate(zip(entries,labels)):
        y=HEADER+row*ROW
        if row%2==0:d.rectangle((0,y,WIDTH-1,y+ROW-1),fill=(200,214,222))
        d.text((14,y+68),entry['base'].capitalize(),font=font(17),fill=ink)
        d.text((14,y+92),label,font=font(15),fill=ink)
        images=[cell(entry,'anim_front',pose),cell(entry,'back',0),cell(entry,'icon',walk)]
        images.extend(cell(entry,'overworld',direction+walk) for direction in (0,2,4,6))
        for (x,_),im in zip(COLUMNS,images):
            scale=3 if im.width==64 else 4
            view=im.resize((im.width*scale,im.height*scale),Image.Resampling.NEAREST)
            out.paste(view,(x,y+8+(28 if im.width==32 else 0)),view)
    return out


def save(frames,path):
    # Use one palette for the whole loop to prevent frame-to-frame color flicker.
    sample=Image.new('RGB',(WIDTH,sum(frame.height for frame in frames)))
    y=0
    for frame in frames:sample.paste(frame,(0,y));y+=frame.height
    palette=sample.quantize(colors=256,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE)
    encoded=[frame.quantize(palette=palette,dither=Image.Dither.NONE) for frame in frames]
    encoded[0].save(path,save_all=True,append_images=encoded[1:],duration=200,loop=0,optimize=False,disposal=2)
    check=Image.open(path)
    assert check.n_frames>=2 and check.info.get('loop')==0,path
    elapsed=0
    for index in range(check.n_frames):
        check.seek(index);elapsed+=check.info['duration']
    assert elapsed==800,(path,elapsed)


def main():
    entries=json.loads((ART/'manifest.json').read_text());OUT.mkdir(parents=True,exist_ok=True)
    all_frames=[render(entries,step,LABELS) for step in range(4)]
    save(all_frames,OUT/'all-seven.gif')
    all_frames[0].save(OUT/'frame-0.png');all_frames[2].save(OUT/'frame-2.png')
    for entry,label in zip(entries,LABELS):
        save([render([entry],step,[label]) for step in range(4)],OUT/(entry['key']+'.gif'))
    (OUT/'README.md').write_text('''# Current seven-variant animation previews

Generated from the current indexed asset PNGs. Four review frames,200ms each,loop indefinitely. Followers use source order0,1,1,0; east is mirrored from west except Pirate, which uses its dedicated east art. Front poses and icon frames loop alongside the walking frames at a readable preview speed. This does not reproduce engine affine motion, battle entrance timing, or world movement.

Classic Cap has two identical front frames, so its front stays still here. Each back has one source frame and remains still. No motion or extra artwork was invented to hide those limits. Production assets were not edited.

Rerun: `python3 tools/special_collection/review_animations.py`.
''')
    print(OUT/'all-seven.gif')


if __name__=='__main__':main()
