#!/usr/bin/env python3
from pathlib import Path
import importlib.util, json
from PIL import Image, ImageDraw
R = Path(__file__).resolve().parents[2]
OUT = R / 'graphics/player_outfits/review'
OUT.mkdir(exist_ok=True)
spec = importlib.util.spec_from_file_location('old_outfits', R / 'test/overworld/player-outfits/assets.py')
old = importlib.util.module_from_spec(spec)
spec.loader.exec_module(old)
tables = old.read_tables(R)
styles = ['original', 'kanto', 'johto', 'hoenn']
actors = ['brendan', 'may']
colors = old.OUTFITS

def load(actor, style, pose):
    path = R / (f'graphics/trainers/{pose}_pics/{actor}.png' if pose in ('front', 'back') else f'graphics/object_events/pics/people/{actor}/{pose}.png') if style == 'original' else R / f'graphics/player_outfits/{style}/{actor}/{pose}.png'
    return Image.open(path)

def colored(im, actor, pose, color, style='original'):
    layout = 'FrontPic' if pose == 'front' else 'BackPic' if pose == 'back' else 'OW'
    table = tables[layout + ('_Male' if actor == 'brendan' else '_Female')]
    pal = list(table['palettes'][color])
    if style != 'original' and actor == 'brendan' and (pose in ('front', 'back')) and (color != 'RED'):
        pal[13] = table['rows'][color][0]
        pal[12] = table['rows'][color][1]
    return old.render(im, pal)
sheet = Image.new('RGB', (1152, 1024), '#dce1e8')
d = ImageDraw.Draw(sheet)
for ai, actor in enumerate(actors):
    for si, style in enumerate(styles):
        for ci, color in enumerate(colors):
            x = ci * 192
            y = (ai * 4 + si) * 128
            d.text((x + 4, y + 2), f'{actor} {style} {color.lower()}', fill='#152739')
            f = colored(load(actor, style, 'front'), actor, 'front', color, style).resize((96, 96), Image.Resampling.NEAREST)
            w = colored(load(actor, style, 'walking').crop((0, 0, 48, 32)), actor, 'walking', color, style).resize((96, 64), Image.Resampling.NEAREST)
            sheet.paste(f, (x, y + 21), f)
            sheet.paste(w, (x + 94, y + 46), w)
sheet.save(OUT / 'catalog.png')
for actor in actors:
    for style in styles[1:]:
        poses = ['walking', 'running', 'mach_bike', 'acro_bike', 'surfing', 'field_move', 'fishing', 'watering', 'underwater', 'decorating', 'back']
        width = 1056
        height = sum(((64 if p == 'back' else 32) * 3 + 24 for p in poses))
        sheet = Image.new('RGB', (width, height), '#dce1e8')
        d = ImageDraw.Draw(sheet)
        y = 0
        for pose in poses:
            d.text((4, y + 2), f'{actor} {style} {pose}', fill='#152739')
            im = load(actor, style, pose)
            if pose == 'back':
                row = Image.new('P', (256, 64))
                row.putpalette(im.getpalette())
                for f in range(4):
                    row.paste(im.crop((0, f * 64, 64, (f + 1) * 64)), (f * 64, 0))
                im = row
            scale = min(3, width // im.width)
            rgba = colored(im, actor, pose, 'RED', style)
            rgba = rgba.resize((im.width * scale, im.height * scale), Image.Resampling.NEAREST)
            sheet.paste(rgba, (0, y + 20), rgba)
            y += rgba.height + 24
        sheet.crop((0, 0, width, y)).save(OUT / f'{actor}-{style}-poses.png')
print(OUT)
