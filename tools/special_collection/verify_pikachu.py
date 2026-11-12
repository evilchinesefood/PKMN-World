#!/usr/bin/env python3
"""Check the requested ear-tip colors in the final, palette-converted sprites."""
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
ART=ROOT/'graphics/pokemon/special_collection'
CASES=(
    ('classic_cap','pikachu/original/front.png','anim_front.png',0,0,((36,14,46,21),(13,29,18,36)),{6,10,11},62),
    ('classic_cap','pikachu/original/front.png','anim_front.png',0,1,((36,14,46,21),(13,29,18,36)),{6,10,11},62),
    ('classic_cap','pikachu/original/back.png','back.png',0,0,((17,14,24,22),(41,35,47,43)),{6,10,11},66),
    ('balloons','pikachu/anim_front.png','anim_front.png',0,0,((17,9,22,19),(36,14,46,21)),{1,13,14},68),
    ('balloons','pikachu/anim_front.png','anim_front.png',1,1,((8,20,13,28),(32,26,39,32)),{1,13,14},56),
    ('balloons','pikachu/back.png','back.png',0,0,((38,5,45,17),(17,14,24,22)),{1,13,14},86),
)


def main():
    total=0
    for key,source,filename,src_frame,dst_frame,boxes,indices,expected in CASES:
        base=Image.open(ROOT/'graphics/pokemon'/source)
        actual=Image.open(ART/key/filename).convert('RGBA')
        count=0
        for x1,y1,x2,y2 in boxes:
            for y in range(y1,y2):
                for x in range(x1,x2):
                    if base.getpixel((x,y+src_frame*64)) in indices:
                        assert actual.getpixel((x,y+dst_frame*64))==(16,16,16,255),(key,filename,dst_frame,x,y)
                        count+=1
        assert count==expected,(key,filename,count,expected)
        total+=count
    print(f'PASS: {total} ear-tip pixels are opaque black after palette conversion')


if __name__=='__main__':main()
