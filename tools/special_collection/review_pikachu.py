#!/usr/bin/env python3
"""Render the Pikachu views requested in the ear-tip and wave review."""
from pathlib import Path
import shutil
from PIL import Image,ImageDraw
from review_art import font

ART=Path(__file__).resolve().parents[2]/'graphics/pokemon/special_collection'


def main():
    shutil.copy2(ART/'review.png',ART/'review-seven-wave.png')
    out=Image.new('RGB',(1380,800),(188,204,214));draw=ImageDraw.Draw(out);ink=(20,35,45)
    draw.text((16,16),'PIKACHU REVISION',font=font(19),fill=ink)
    for x,title in ((180,'Front poses'),(574,'Back'),(776,'Overworld directions')):
        draw.text((x,50),title,font=font(19),fill=ink)
    for row,(key,label) in enumerate((('classic_cap','Classic cap'),('surfboard','Surfboard + wave'),('balloons','Balloons'))):
        y=80+row*240;draw.text((16,y+72),label,font=font(19),fill=ink);x=180
        for name in ('anim_front','back','overworld'):
            im=Image.open(ART/key/(name+'.png')).convert('RGBA')
            if name=='anim_front':
                flat=Image.new('RGBA',(128,64));flat.alpha_composite(im.crop((0,0,64,64)));flat.alpha_composite(im.crop((0,64,64,128)),(64,0));im=flat
            view=im.resize((im.width*3,im.height*3),Image.Resampling.NEAREST)
            out.paste(view,(x,y+20),view);x+=view.width+10
    out.save(ART/'review-pikachu-wave.png')


if __name__=='__main__':main()
