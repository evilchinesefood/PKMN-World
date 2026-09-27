"""Audit existing facade glass as palette/index pixels, then as native RGB pixels."""
import json
from pathlib import Path
import struct

from PIL import Image


def visible_indices(assets, layout, mid):
    split, _ = assets.split(layout)
    owner = assets.sets[layout['primary_tileset' if mid < split else 'secondary_tileset']]
    words = owner['meta'][mid if mid < split else mid-split]
    pixels = [0]*256
    for k, word in enumerate(words):
        tile, _, _ = assets.tile(layout, word)
        for y in range(8):
            for x in range(8):
                c = tile.getpixel((7-x if word & 1024 else x, 7-y if word & 2048 else y))
                if k < 4 or c:
                    px, py = k % 2*8+x, (k % 4)//2*8+y
                    pixels[py*16+px] = (word >> 12)*16+c
    return pixels


def glass(assets, layout, scene, cells):
    # FRLG house/school blue panes retain palette 3 (including their existing
    # ordinary night tint). Shared warm glass was isolated into palette 7 by #345.
    # This pass preserves both; it does not silently opt unlit panes into lighting.
    colors = {3*16+i for i in (10,11,12)}
    colors.update(7*16+i for i in assets.sets[layout['secondary_tileset']]['masks'][7])
    x0,y0,x1,y1 = scene['facade']
    found = {}
    for y in range(y0,y1+1):
        for x in range(x0,x1+1):
            for i, color in enumerate(visible_indices(assets, layout, cells[y*48+x] & 1023)):
                if color in colors:
                    found[(x*16+i%16,y*16+i//16)] = color
    assert found, ('empty facade-glass mask', scene['name'])
    return found


def source_masks(assets, layout, scenes, before, after):
    masks = {}
    for scene in scenes:
        old = glass(assets, layout, scene, before)
        new = glass(assets, layout, scene, after)
        assert old == new, ('glass position, palette ownership or visibility changed', scene['name'])
        masks[scene['name']] = old
    return masks


def verify_native(scenes, masks, before, after):
    evidence = []
    for i, scene in enumerate(scenes):
        mask = masks[scene['name']]
        projected = {(x-scene['x']*16+112,y-scene['y']*16+72): c for (x,y),c in mask.items()}
        assert all(0 <= x < 240 and 0 <= y < 160 for x,y in projected), ('pane outside camera',scene['name'])
        for t, time in enumerate(('noon','dusk','night')):
            prefix = f'ViridianFrontagesCapture_{i*3+t+1:02}_{scene["name"]}_{time}'
            images = [Image.open(directory/(prefix+'.png')).convert('RGB') for directory in (before,after)]
            palettes = [(directory/f'{scene["name"]}_{time}.pal.bin').read_bytes() for directory in (before,after)]
            assert palettes[0] == palettes[1] and len(palettes[0]) == 512
            palette = struct.unpack('<256H',palettes[0])
            for (x,y), color in projected.items():
                value = palette[color]
                channels = [(value >> shift) & 31 for shift in (0,5,10)]
                expected = tuple((v << 3) | (v >> 2) for v in channels)
                actual = [image.getpixel((x,y)) for image in images]
                assert actual == [expected,expected], ('pane RGB/visibility', scene['name'],time,x,y,color,actual,expected)
            evidence.append(dict(scene=scene['name'],time=time,verified_pixels=len(projected)))
    return evidence
