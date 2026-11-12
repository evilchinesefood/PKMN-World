#!/usr/bin/env python3
"""Render every native collection frame at integer scale for review."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[2]
ASSETS=ROOT/'graphics/pokemon/special_collection'
LABELS=('Classic cap','Surfboard','Balloons','Squad shades','Firefighter','Flower crown','Pirate')


def font(size):
    for path in ('/System/Library/Fonts/Supplemental/Arial.ttf','/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'):
        if Path(path).exists():return ImageFont.truetype(path,size)
    return ImageFont.load_default()


def main():
    entries=json.loads((ASSETS/'manifest.json').read_text())
    out=Image.new('RGB',(1260,100+len(entries)*160),(188,204,214));d=ImageDraw.Draw(out)
    ink=(27,42,53)
    d.text((22,16),'SPECIAL POKÉMON — REVISED ASSET SHEET',font=font(23),fill=ink)
    d.text((22,48),'7 shared appearances · native pixels at 2× · awaiting owner review',font=font(15),fill=ink)
    for x,title in ((160,'Battle front · 2 poses'),(426,'Battle back'),(564,'Party / PC'),(702,'Follower · idle / step by direction')):
        d.text((x,80),title,font=font(13),fill=ink)
    for row,entry in enumerate(entries):
        y=100+row*160
        if row%2==0:d.rectangle((0,y,1259,y+159),fill=(200,214,222))
        d.text((18,y+42),entry['base'].capitalize(),font=font(17),fill=ink)
        d.text((18,y+66),LABELS[row],font=font(14),fill=ink)
        x=160
        for name in ('anim_front','back','icon','overworld'):
            im=Image.open(ASSETS/entry['key']/f'{name}.png').convert('RGBA')
            if name=='anim_front':
                flat=Image.new('RGBA',(128,64));flat.alpha_composite(im.crop((0,0,64,64)));flat.alpha_composite(im.crop((0,64,64,128)),(64,0));im=flat
            if name=='icon':
                flat=Image.new('RGBA',(64,32));flat.alpha_composite(im.crop((0,0,32,32)));flat.alpha_composite(im.crop((0,32,32,64)),(32,0));im=flat
            view=im.resize((im.width*2,im.height*2),Image.Resampling.NEAREST)
            offset=24 if name in ('icon','overworld') else 0
            out.paste(view,(x,y+12+offset),view);x+=view.width+10
    path=ASSETS/'review.png';out.save(path);print(path)


if __name__=='__main__':main()
