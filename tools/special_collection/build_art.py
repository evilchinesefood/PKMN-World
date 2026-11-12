#!/usr/bin/env python3
"""Build the seven collection sprite sets from native indexed source frames."""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw, ImageOps

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'graphics/pokemon/special_collection'
ROWS = (
    ('classic_cap', 'ClassicCap', 'pikachu', 0, False, False),
    ('surfboard', 'Surfboard', 'pikachu', 2, False, False),
    ('balloons', 'Balloons', 'pikachu', 0, False, False),
    ('squad', 'Squad', 'squirtle', 0, False, False),
    ('firefighter', 'Firefighter', 'squirtle', 0, False, False),
    ('flower_crown', 'FlowerCrown', 'eevee', 2, False, False),
    ('pirate', 'Pirate', 'totodile', 0, False, True),
)
INK=(32,32,40,255)
RED=(208,48,48,255)
DARK_RED=(128,32,40,255)
LIGHT_RED=(248,112,96,255)
WHITE=(248,240,208,255)
GOLD=(248,192,56,255)
BROWN=(152,88,40,255)
TAN=(216,160,80,255)
BLUE=(48,144,216,255)
GREEN=(64,160,88,255)
PINK=(248,136,184,255)


def palette(path):
    return [tuple(map(int,row.split())) for row in path.read_text().splitlines()[3:19]]


def load(species, filename, pal=None):
    path=ROOT/'graphics/pokemon'/species/filename
    im=Image.open(path).copy()
    colors=palette(ROOT/'graphics/pokemon'/species/(pal or ('overworld_normal.pal' if filename.startswith('overworld') else 'normal.pal')))
    im.putpalette([v for color in colors for v in color]+[0]*720)
    im.info['transparency']=0
    return im.convert('RGBA')


def icon(species, female, index):
    folder=ROOT/'graphics/pokemon'/species
    path=folder/('iconf.png' if female and (folder/'iconf.png').exists() else 'icon.png')
    im=Image.open(path).copy(); source_index={'pikachu':2,'eevee':2,'squirtle':0,'totodile':0,'pikachu/original':0}[species]
    colors=palette(ROOT/f'graphics/pokemon/icon_palettes/pal{source_index}.pal')
    im.putpalette([v for c in colors for v in c]+[0]*720); im.info['transparency']=0
    return im.convert('RGBA')


def shifted(im, dy):
    out=Image.new('RGBA',im.size); out.alpha_composite(im,(0,dy)); return out


def cap(d,cx,cy,s=1,back=False,side=False):
    # This cap is only used on followers; battle/icon art retains the original cap.
    if side:
        d.polygon([(cx-4,cy),(cx-3,cy-4),(cx,cy-6),(cx+4,cy-5),(cx+6,cy-2),(cx+5,cy+1)],fill=RED,outline=INK)
        d.line([(cx,cy-4),(cx+3,cy-4),(cx+4,cy-2)],fill=LIGHT_RED)
        d.polygon([(cx-4,cy-1),(cx-3,cy-4),(cx-1,cy-5),(cx,cy),(cx-4,cy+1)],fill=WHITE)
        d.point((cx-2,cy-2),fill=GREEN)
        d.polygon([(cx-4,cy),(cx+1,cy),(cx-2,cy+2),(cx-7,cy+2),(cx-8,cy+1)],fill=DARK_RED,outline=INK)
        d.line((cx-6,cy+1,cx-2,cy+1),fill=RED)
    else:
        d.polygon([(cx-6,cy),(cx-5,cy-4),(cx-2,cy-6),(cx+2,cy-6),(cx+5,cy-4),(cx+6,cy)],fill=RED,outline=INK)
        d.line((cx-3,cy-4,cx+2,cy-4),fill=LIGHT_RED)
        if back:
            d.line((cx,cy-4,cx,cy-1),fill=DARK_RED)
            d.rectangle((cx-2,cy-1,cx+2,cy+1),fill=INK)
            d.line((cx-1,cy+1,cx+1,cy+1),fill=WHITE)
            d.line((cx-5,cy,cx-3,cy),fill=DARK_RED)
            d.line((cx+3,cy,cx+5,cy),fill=DARK_RED)
        else:
            d.polygon([(cx-3,cy-4),(cx,cy-5),(cx+2,cy-3),(cx+2,cy),(cx-4,cy)],fill=WHITE)
            d.line([(cx-2,cy-2),(cx,cy-3),(cx+1,cy-2),(cx-1,cy-1)],fill=GREEN)
            d.polygon([(cx-6,cy),(cx+5,cy),(cx+7,cy+1),(cx+5,cy+2),(cx-4,cy+2)],fill=DARK_RED,outline=INK)
            d.line((cx-3,cy+1,cx+4,cy+1),fill=RED)


def helmet(d,cx,cy,small,back=False,side=False):
    if small:
        d.polygon([(cx-5,cy),(cx-5,cy-2),(cx-3,cy-5),(cx+2,cy-5),(cx+5,cy-2),(cx+5,cy)],fill=RED,outline=INK)
        d.line((cx-2,cy-4,cx+1,cy-4),fill=LIGHT_RED)
        d.line((cx+2,cy-3,cx+3,cy-1),fill=DARK_RED)
        d.polygon([(cx-7,cy),(cx+6,cy),(cx+7,cy+1),(cx+4,cy+2),(cx-5,cy+2)],fill=DARK_RED,outline=INK)
        d.line((cx-5,cy,cx+4,cy),fill=GOLD)
        if back:
            d.line((cx-3,cy+1,cx-1,cy+1),fill=WHITE)
            d.line((cx+1,cy+1,cx+3,cy+1),fill=WHITE)
        else:
            x=cx-2 if side else cx-1
            d.polygon([(x-1,cy-4),(x+2,cy-4),(x+2,cy-1),(x,cy),(x-1,cy-1)],fill=GOLD)
            d.line((x,cy-3,x,cy-1),fill=WHITE)
        return
    # Closed shell, raised center ridge, a complete brim and a rear neck guard.
    d.polygon([(cx-11,cy),(cx-10,cy-5),(cx-7,cy-8),(cx-3,cy-10),(cx+2,cy-10),(cx+7,cy-8),(cx+10,cy-5),(cx+11,cy)],fill=RED,outline=INK)
    d.polygon([(cx+3,cy-9),(cx+7,cy-7),(cx+9,cy-4),(cx+10,cy),(cx+4,cy-1)],fill=DARK_RED)
    d.polygon([(cx-8,cy-5),(cx-6,cy-7),(cx-3,cy-8),(cx-3,cy-5),(cx-7,cy-3)],fill=LIGHT_RED)
    d.line([(cx-1,cy-9),(cx-1,cy-2)],fill=DARK_RED,width=3)
    d.line([(cx,cy-9),(cx,cy-2)],fill=LIGHT_RED)
    if back:
        d.polygon([(cx-10,cy-1),(cx+7,cy-1),(cx+8,cy+3),(cx+4,cy+5),(cx-7,cy+4),(cx-11,cy+2)],fill=DARK_RED,outline=INK)
        d.line((cx-7,cy+2,cx+4,cy+3),fill=RED)
    d.polygon([(cx-13,cy),(cx-8,cy-1),(cx+8,cy-1),(cx+13,cy+1),(cx+11,cy+3),(cx-10,cy+3),(cx-13,cy+1)],fill=DARK_RED,outline=INK)
    d.line([(cx-11,cy),(cx-7,cy),(cx+7,cy),(cx+11,cy+1)],fill=GOLD)
    d.line((cx-9,cy+2,cx+9,cy+2),fill=RED)
    if back:
        d.line((cx-7,cy+1,cx-3,cy+1),fill=WHITE)
        d.line((cx+3,cy+1,cx+7,cy+1),fill=WHITE)
        d.line((cx-6,cy-3,cx-4,cy-3),fill=DARK_RED)
        d.line((cx+4,cy-3,cx+6,cy-3),fill=INK)
    else:
        x=cx-2
        d.polygon([(x-4,cy-7),(x+3,cy-7),(x+4,cy-4),(x+3,cy),(x,cy+2),(x-3,cy),(x-4,cy-4)],fill=INK)
        d.polygon([(x-3,cy-6),(x+2,cy-6),(x+3,cy-4),(x+2,cy-1),(x,cy+1),(x-2,cy-1)],fill=GOLD)
        d.line((x-1,cy-5,x-1,cy-1),fill=WHITE)
        d.line((x-1,cy-5,x+1,cy-5),fill=WHITE)
        d.line((x-1,cy-3,x,cy-3),fill=WHITE)


def glasses(d,cx,cy,small,back=False,side=False):
    glint=(112,160,184,255)
    if back:
        if small:
            d.point((cx-5,cy),fill=INK);d.point((cx+5,cy),fill=INK)
        else:
            # Short temple arm only; the back of the skull remains uncovered.
            d.line((45,19,48,20),fill=INK)
            d.polygon([(47,19),(52,15),(51,22),(48,25)],fill=INK)
            d.point((49,20),fill=glint)
    elif small:
        if side:
            d.polygon([(cx-6,cy-4),(cx+2,cy-1),(cx,cy+3),(cx-3,cy+1)],fill=INK)
            d.line((cx+2,cy-1,cx+4,cy-1),fill=INK);d.point((cx-2,cy-1),fill=glint)
        else:
            d.polygon([(cx-7,cy-4),(cx-1,cy-1),(cx-2,cy+2),(cx-5,cy)],fill=INK)
            d.polygon([(cx+1,cy-1),(cx+7,cy-4),(cx+5,cy),(cx+2,cy+2)],fill=INK)
            d.line((cx-1,cy,cx+1,cy),fill=INK)
            d.point((cx-3,cy-1),fill=glint);d.point((cx+3,cy-1),fill=glint)
    else:
        d.polygon([(13,16),(23,21),(21,27),(17,23)],fill=INK)
        d.polygon([(25,21),(38,15),(33,26),(28,28)],fill=INK)
        d.line((23,22,25,22),fill=INK)
        d.line((18,21,20,22),fill=glint)
        d.line((28,22,30,21),fill=glint)


def flower(d,cx,cy,small,color):
    if small:
        d.line((cx-1,cy,cx+1,cy),fill=color);d.line((cx,cy-1,cx,cy+1),fill=color);d.point((cx,cy),fill=GOLD)
    else:
        shade=(184,72,112,255) if color==PINK else (184,152,96,255)
        d.line((cx-2,cy+1,cx+2,cy+1),fill=shade)
        d.line((cx,cy-2,cx,cy+2),fill=shade,width=2)
        for dx,dy in ((-2,0),(2,0),(0,-2),(0,2)):
            d.point((cx+dx,cy+dy),fill=color)
            d.point((cx+dx-(1 if dx>0 else -1 if dx<0 else 0),cy+dy),fill=color)
        d.point((cx,cy),fill=GOLD)


def crown(d,cx,cy,small,back=False,side=False):
    leaf=(40,104,56,255)
    if small:
        points=[(cx-4,cy+1),(cx,cy),(cx+4,cy-1)]
        if back:points=[(cx-4,cy),(cx,cy+1),(cx+4,cy)]
        if side:points=[(cx-4,cy+1),(cx-1,cy),(cx+2,cy-2)]
        d.line(points,fill=leaf)
        for x,y in (points[0],points[-1]):d.point((x,y+1),fill=GREEN)
        for (x,y),c in zip(points,(PINK,WHITE,PINK)):flower(d,x,y,True,c)
    else:
        points=[(31,27),(37,27),(43,26)] if back else [(21,27),(27,26),(32,25)]
        d.line([(x,y+1) for x,y in points],fill=leaf,width=2)
        for x,y in ((27,27),(47,25)) if back else ((19,27),(35,24)):
            d.line((x-1,y+1,x+1,y-1),fill=leaf);d.point((x,y),fill=GREEN)
        for (x,y),c in zip(points,(PINK,WHITE,PINK)):flower(d,x,y,False,c)


def pirate(d,cx,cy,small,back=False,side=False,east=False):
    r,h=(5,4) if small else (10 if back else 7,6 if back else 3)
    d.polygon([(cx-r,cy),(cx-r+1,cy-h+2),(cx-2,cy-h),(cx+r-3,cy-h+1),(cx+r,cy-2),(cx+r,cy+2),(cx-r,cy+1)],fill=RED,outline=INK)
    d.line([(cx-r+2,cy-h+2),(cx,cy-h+1),(cx+r-3,cy-h+2)],fill=LIGHT_RED)
    d.line((cx-r+1,cy+1,cx+r-1,cy+1),fill=DARK_RED)
    knot=cx-r if back or east else cx+r
    d.polygon([(knot,cy),(knot+3,cy+1),(knot+2,cy+5),(knot,cy+3),(knot-2,cy+6),(knot-2,cy+2)],fill=DARK_RED,outline=INK)
    d.point((knot+1,cy+2),fill=LIGHT_RED)
    if not small:
        d.line((cx-r+3,cy,cx+r-2,cy),fill=DARK_RED)
        for dx in (-4,1,6):d.point((cx+dx,cy-2),fill=WHITE)
    if back:
        d.line([(cx-r,cy+4),(cx-2,cy+5)],fill=INK,width=1 if small else 2)
        return
    # The covered eye stays on the same anatomical side in the east-facing art.
    if east:return
    eye=(cx-1 if side else cx-3) if small else cx;ey=cy+4 if small else cy+6
    if small:
        d.line([(cx-r,cy+1),(eye,cy+2),(eye,ey)],fill=INK)
    else:d.line((cx-r,cy+2,cx+r,ey+1),fill=INK,width=1)
    if small:
        d.rectangle((eye-1,ey-1,eye+1,ey+1),fill=INK);d.point((eye-1,ey-1),fill=(72,80,88,255))
    else:
        d.polygon([(eye-4,ey-3),(eye+3,ey-3),(eye+3,ey+1),(eye,ey+4),(eye-3,ey+2)],fill=INK)
        d.line((eye-2,ey-2,eye+1,ey-2),fill=(72,80,88,255))


def pirate_icon(d):
    d.polygon([(10,13),(11,10),(14,9),(17,10),(19,12),(19,14)],fill=RED,outline=INK)
    d.line((12,11,16,11),fill=LIGHT_RED);d.point((14,12),fill=WHITE)
    d.polygon([(19,12),(21,14),(20,17),(18,15)],fill=DARK_RED,outline=INK)
    d.line((12,13,18,16),fill=INK)
    d.polygon([(14,14),(16,14),(16,16),(15,17),(14,16)],fill=INK)
    d.point((14,14),fill=(80,88,96,255))


def black_ear_tips(im,key,view,index):
    if key=='classic_cap':
        boxes=((17,14,24,22),(41,35,47,43)) if view=='back' else ((36,14,46,21),(13,29,18,36))
        shades={(16,16,16),(41,41,41),(82,82,90)}
    else:
        boxes=((38,5,45,17),(17,14,24,22)) if view=='back' else (
            ((17,9,22,19),(36,14,46,21)) if index==0 else ((8,20,13,28),(32,26,39,32)))
        shades={(0,0,0),(64,64,72),(41,41,41)}
    out=im.copy()
    for x1,y1,x2,y2 in boxes:
        for y in range(y1,y2):
            for x in range(x1,x2):
                pixel=out.getpixel((x,y))
                if pixel[3] and pixel[:3] in shades:out.putpixel((x,y),(16,16,16,255))
    return out


def surf_wave(im,small,direction,index,foreground=False):
    wave=Image.new('RGBA',im.size);d=ImageDraw.Draw(wave)
    deep=(24,80,144,255);water=(48,144,216,255);light=(104,208,240,255);foam=(232,248,255,255)
    if small:
        if foreground:
            d.line([(4,29),(7,30),(14,30),(17,31),(24,30),(28,30)],fill=foam)
            d.point((10+index%2,29),fill=light)
        else:
            d.polygon([(1,28),(2,25),(4,22),(7,21),(10,22),(12,24),(11,26),(8,27),(7,25),(6,25),(5,27),(8,29),(17,29),(25,27),(29,28),(31,30),(28,31),(5,31),(1,30)],fill=water,outline=deep)
            d.line([(2,27),(4,24),(6,23),(9,23),(10,24)],fill=foam)
            d.line([(4,28),(8,30),(16,30),(23,29),(28,29)],fill=light)
            d.point((8,25),fill=foam)
        if direction=='w':wave=ImageOps.mirror(wave)
    else:
        if foreground:
            d.line([(3,60),(8,61),(15,62),(27,62),(33,61),(41,62),(50,61),(59,60)],fill=foam)
            d.line((16,60,24,60),fill=light)
            d.point((6,59),fill=foam);d.point((54,59),fill=foam)
        else:
            d.polygon([(0,58),(1,54),(3,50),(6,47),(10,45),(14,46),(17,48),(18,51),(16,54),(13,55),(11,53),(12,51),(10,50),(8,52),(7,55),(11,58),(26,59),(43,57),(56,56),(62,58),(63,60),(61,62),(50,63),(10,63),(3,62),(0,60)],fill=water,outline=deep)
            d.polygon([(2,56),(4,51),(8,48),(12,47),(15,48),(16,50),(14,52),(13,50),(10,49),(7,51),(5,55),(8,59),(18,61),(12,62),(5,60)],fill=light)
            d.line([(2,55),(4,51),(7,48),(11,46),(14,47),(16,49),(16,51),(14,53)],fill=foam,width=2)
            d.line([(3,58),(7,60),(14,61)],fill=foam)
            d.line([(30,61),(43,59),(53,58),(59,59)],fill=light)
            d.point((19,53),fill=foam);d.point((3,47),fill=light)
    im.alpha_composite(wave)
    return im


def board(im,small,direction):
    d=ImageDraw.Draw(im)
    if small and direction in ('s','n'):
        d.polygon([(15,21),(19,22),(24,26),(24,28),(21,31),(12,31),(8,28),(9,25)],fill=BROWN,outline=INK)
        d.polygon([(15,22),(19,23),(23,26),(22,28),(19,30),(12,29),(9,27),(11,24)],fill=TAN)
        d.line([(14,23),(11,26),(14,29),(19,30)],fill=WHITE)
        d.line([(17,23),(19,25),(20,28)],fill=BLUE)
    elif small:
        d.polygon([(1,27),(5,25),(25,25),(30,27),(26,30),(5,30)],fill=BROWN,outline=INK)
        d.polygon([(3,27),(7,26),(25,26),(28,27),(24,29),(6,29)],fill=TAN)
        d.line((6,27,25,27),fill=WHITE);d.line((8,29,23,29),fill=BLUE)
    else:
        d.polygon([(5,55),(13,52),(45,51),(59,53),(60,55),(52,58),(16,59),(7,57)],fill=BROWN,outline=INK)
        d.polygon([(7,54),(15,53),(45,52),(58,53),(52,56),(17,57),(9,56)],fill=TAN)
        d.line([(10,55),(16,54),(45,53),(55,54)],fill=WHITE)
        d.line([(16,56),(48,55),(53,54)],fill=BLUE,width=2)
        d.line((21,57,43,56),fill=WHITE)
    return im


def balloons(im,small,direction,view,index):
    d=ImageDraw.Draw(im)
    dx,dy=(-1,1) if view=='icon' and index else (0,0)
    if small:
        tie=(19,23) if direction=='w' else (16,23)
        configs=[(2,1,9,9,RED,DARK_RED),(23,2,30,10,BLUE,(24,80,152,255)),(12,0,19,7,GREEN,(32,104,64,255))]
        if view=='icon':
            configs=[(x1,y1,x2,y2,c,shade) for (x1,y1,x2,y2,_,_),c,shade in zip(configs,((213,98,65,255),(164,197,255,255),(106,172,156,255)),((139,72,64,255),(139,123,255,255),(65,98,90,255)))]
    else:
        tie=(36,40) if direction=='back' else (34,40 if index==0 else 43)
        configs=[(1,2,14,20,RED,DARK_RED),(49,2,62,20,BLUE,(24,80,152,255)),(25,0,36,15,GREEN,(32,104,64,255))]
    for x1,y1,x2,y2,c,shade in configs:
        x1+=dx;x2+=dx;y1+=dy;y2+=dy;middle=(x1+x2)//2
        d.line((middle,y2+1,tie[0]+dx,tie[1]+dy),fill=INK)
        d.ellipse((x1,y1,x2,y2),fill=c,outline=INK)
        d.arc((x1+1,y1+1,x2-1,y2-1),0,100,fill=shade,width=1 if small else 2)
        light=tuple(min(248,((v+64)//8)*8) for v in c[:3])+(255,)
        if small:
            d.point((x1+2,y1+2),fill=light)
        else:
            d.polygon([(x1+3,y1+3),(x1+5,y1+2),(x1+6,y1+3),(x1+5,y1+5),(x1+3,y1+6)],fill=light)
            d.arc((x1+2,y1+2,x2-2,y2-2),10,100,fill=shade,width=2)
        d.polygon([(middle,y2),(middle-1,y2+2),(middle+1,y2+2)],fill=shade)
    return im


def decorate(im,key,view,index):
    small=im.width==32; direction=['s','s','n','n','w','w','e','e'][index] if view=='overworld' else 'back' if view=='back' else 's'
    back=direction in ('n','back'); side=direction in ('w','e'); east=direction=='e'
    if key=='surfboard':
        if view in ('front','back'):im=black_ear_tips(im,key,view,index)
        bottom=im.getchannel('A').getbbox()[3]
        has_wave=view!='icon'
        base=shifted(im,(25 if small and has_wave else 28 if small else 54)-bottom)
        out=Image.new('RGBA',im.size)
        if has_wave:surf_wave(out,small,direction,index)
        deck=Image.new('RGBA',im.size);board(deck,small,direction)
        out.alpha_composite(shifted(deck,-3) if small and has_wave else deck)
        out.alpha_composite(base)
        if has_wave:surf_wave(out,small,direction,index,True)
        return out
    if key=='balloons':
        if view in ('front','back'):im=black_ear_tips(im,key,view,index)
        out=Image.new('RGBA',im.size);balloons(out,small,direction,view,index);out.alpha_composite(im);return out
    out=Image.new('RGBA',im.size);d=ImageDraw.Draw(out)
    if view=='overworld':
        cx,cy=16,18
        if side:cx=15;cy=18
        if key=='classic_cap':cap(d,cx,17 if not side else 16,1,back,side)
        elif key=='squad':glasses(d,cx,22 if not back else 21,True,back,side)
        elif key=='firefighter':helmet(d,cx,18,True,back,side)
        elif key=='flower_crown':crown(d,cx,18 if not side else 17,True,back,side)
        elif key=='pirate':pirate(d,cx,16,True,back,side,east)
    elif view=='icon':
        bob=0 if index==0 else 0
        cx=16;cy=16+bob
        if key=='classic_cap':cap(d,cx,cy,1,False)
        elif key=='squad':glasses(d,12,18,True,False,True)
        elif key=='firefighter':helmet(d,12,15,True,side=True)
        elif key=='flower_crown':crown(d,13,18,True,side=True)
        elif key=='pirate':pirate_icon(d)
    else:
        if key=='classic_cap':cap(d,35 if back else 29,22 if back else 21,2,back)
        elif key=='squad':glasses(d,39 if back else 24,22 if back else 23,False,back)
        elif key=='firefighter':helmet(d,39 if back else 26,16 if back else 17,False,back)
        elif key=='flower_crown':crown(d,37 if back else 25,26 if back else 24,False,back)
        elif key=='pirate':pirate(d,34 if back else 29,15 if back else 16,False,back)
    offsets={
        'squad': {'front': ((0,0),(-1,-2)), 'icon': ((0,0),(0,1))},
        'firefighter': {'front': ((0,0),(-1,-2)), 'icon': ((0,0),(0,1))},
        'flower_crown': {'front': ((0,0),(0,1)), 'icon': ((0,0),(0,1))},
        'pirate': {'front': ((0,0),(2,-1)), 'icon': ((0,0),(0,1))},
    }
    poses=offsets.get(key,{}).get(view)
    dx,dy=poses[index] if poses else (0,0)
    if key=='pirate':
        # Keep the uncovered eye and its native outline completely free of accessories.
        eye_box=(35,13,44,25) if view=='back' else (
            {'s':(17,17,22,23),'e':(16,18,20,23)}.get(direction) if view=='overworld' else None)
        if eye_box:
            x1,y1,x2,y2=eye_box
            ImageDraw.Draw(out).rectangle((x1,y1,x2-1,y2-1),fill=(0,0,0,0))
    result=im.copy();result.alpha_composite(out,(dx,dy))
    if key=='classic_cap' and view=='overworld':
        # Ears emerge in front of the cap, rather than disappearing behind its dome.
        boxes=((18,8,24,16),) if side else ((7,9,12,17),(21,9,25,17))
        for box in boxes:result.alpha_composite(im.crop(box),box[:2])
    return result


def colors_for(images):
    pixels=[p[:3] for im in images for p in list(im.getdata()) if p[3]]
    sample=Image.new('RGB',(len(pixels),1));sample.putdata(pixels)
    q=sample.quantize(colors=15,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE);p=q.getpalette()
    colors=[tuple(p[i:i+3]) for i in range(0,len(p),3)]
    return [(0,0,0)]+(colors+[(0,0,0)]*15)[:15]


def indexed(im,colors):
    out=Image.new('P',im.size);out.putpalette([v for c in colors for v in c]+[0]*720)
    cache={};indices=[]
    for pixel in im.getdata():
        if pixel[3]==0:indices.append(0);continue
        color=pixel[:3]
        if color not in cache:cache[color]=min(range(1,16),key=lambda i:sum((color[j]-colors[i][j])**2 for j in range(3)))
        indices.append(cache[color])
    out.putdata(indices);out.info['transparency']=0;return out


def stack(frames,horizontal=False):
    w,h=frames[0].size;out=Image.new('RGBA',(w*len(frames),h) if horizontal else (w,h*len(frames)))
    for i,frame in enumerate(frames):out.alpha_composite(frame,(i*w,0) if horizontal else (0,i*h))
    return out


def build(row):
    key,suffix,species,icon_index,female,asym=row
    assert not female, 'Collection variants share one appearance across genders'
    frames={}
    for view in ('anim_front','back','overworld','icon'):
        im=icon(species,False,icon_index) if view=='icon' else load(species,view+'.png')
        horizontal=view=='overworld';size=32 if view in ('icon','overworld') else 64
        count=im.width//size if horizontal else im.height//size
        cells=[im.crop((i*size,0,(i+1)*size,size) if horizontal else (0,i*size,size,(i+1)*size)) for i in range(count)]
        if asym and view=='overworld':cells += [ImageOps.mirror(c) for c in cells[4:6]]
        if key=='classic_cap' and view in ('anim_front','back','icon'):
            original='front.png' if view=='anim_front' else view+'.png'
            base=icon('pikachu/original',False,icon_index) if view=='icon' else load('pikachu/original',original)
            cells=[base.crop((0,i*size,size,(i+1)*size)) for i in range(base.height//size)]
            if view=='anim_front':cells*=2
            if view!='icon':cells=[black_ear_tips(c,key,'back' if view=='back' else 'front',i) for i,c in enumerate(cells)]
        else:cells=[decorate(c,key,'front' if view=='anim_front' else view,i) for i,c in enumerate(cells)]
        frames[view]=cells
    battle=palette(ROOT/'graphics/pokemon/pikachu/original/normal.pal') if key=='classic_cap' else colors_for(frames['anim_front']+frames['back'])
    if key=='surfboard':
        battle=[(0,0,0),(16,16,16),(255,246,164),(246,230,82),(246,189,32),(222,148,0),
                (156,82,0),(98,49,8),(197,32,24),(230,90,65),TAN[:3],(232,248,255),
                (104,208,240),BLUE[:3],(24,80,144),BROWN[:3]]
    elif key=='firefighter':
        battle=[(0,0,0),(16,16,16),(176,224,232),(136,192,200),(88,152,160),(40,112,128),
                (255,230,156),(230,172,90),(189,106,0),(98,41,0),LIGHT_RED[:3],RED[:3],DARK_RED[:3],GOLD[:3],WHITE[:3],(176,112,32)]
    elif key=='balloons':
        battle=[(0,0,0),(16,16,16),(246,230,82),(246,189,32),(222,148,0),(156,82,0),
                DARK_RED[:3],RED[:3],(248,112,112),(32,104,64),GREEN[:3],(128,224,152),
                (24,80,152),BLUE[:3],(112,208,248),WHITE[:3]]
    ow=battle if key=='surfboard' else colors_for(frames['overworld']);ic=palette(ROOT/f'graphics/pokemon/icon_palettes/pal{icon_index}.pal')
    folder=OUT/key;folder.mkdir(parents=True,exist_ok=True)
    for name,cells in frames.items():
        colors=ow if name=='overworld' else ic if name=='icon' else battle
        indexed(stack(cells,name=='overworld'),colors).save(folder/f'{name}.png',bits=4,transparency=0)
    for name,colors in [('normal.pal',battle),('overworld_normal.pal',ow)]:
        (folder/name).write_text('JASC-PAL\n0100\n16\n'+''.join(' '.join(map(str,c))+'\n' for c in colors))
    return dict(key=key,symbol=suffix,base=species,icon_palette=icon_index,female=False,asymmetric=asym,follower_frames=8 if asym else 6)


def declarations(entries):
    graphics=[];tables=[]
    for e in entries:
        path='graphics/pokemon/special_collection/'+e['key'];suffix=e['symbol']
        for f,end in [('', '')]+([('f','Female')] if e['female'] else []):
            sym='Special'+suffix+end
            for c,p,n,ext in [('u32','gMonFrontPic_','anim_front','.4bpp.smol'),('u32','gMonBackPic_','back','.4bpp.smol'),('u8','gMonIcon_','icon','.4bpp')]:
                graphics.append(f'const {c} {p}{sym}[] = INCGFX_{c.upper()}("{path}/{n}{f}.png", "{ext}");')
            graphics.append(f'const u32 gObjectEventPic_{sym}[] = INCGFX_COMP("{path}/overworld{f}.png", ".4bpp", "-mwidth 4 -mheight 4");')
            tables.append(f'static const struct SpriteFrameImage sPicTable_{sym}[] = {{\n    overworld_ascending_frames(gObjectEventPic_{sym}, 4, 4),\n}};')
        graphics.append(f'const u16 gMonPalette_Special{suffix}[] = INCGFX_U16("{path}/normal.pal", ".gbapal");')
        graphics.append(f'const u16 gOverworldPalette_Special{suffix}[] = INCGFX_U16("{path}/overworld_normal.pal", ".gbapal");')
    (ROOT/'src/data/graphics/special_collection.h').write_text('\n'.join(graphics)+'\n')
    (ROOT/'src/data/object_events/special_collection_pic_tables.h').write_text('\n'.join(tables)+'\n')


def main():
    OUT.mkdir(parents=True,exist_ok=True);entries=[build(row) for row in ROWS];declarations(entries)
    for e in entries:
        e['files']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((OUT/e['key']).iterdir()) if p.suffix in ('.png','.pal')}
    (OUT/'manifest.json').write_text(json.dumps(entries,indent=2)+'\n')
    print('Built all seven native collection sprite sets.')


if __name__=='__main__':main()
