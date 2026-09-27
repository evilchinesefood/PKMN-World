#!/usr/bin/env python3
"""Read source tilesets and render their visible, indexed metatile pixels."""
import json
from pathlib import Path
import re
import struct

from PIL import Image


def read_palette(path):
    lines = path.read_text().splitlines()
    assert lines[:2] == ['JASC-PAL', '0100'], path
    colors = [tuple(map(int, line.split())) for line in lines[3:19]]
    return colors + [(0, 0, 0)] * (16-len(colors))


class Assets:
    def __init__(self, root):
        self.root = Path(root)
        self.headers = (self.root/'src/data/tilesets/headers.h').read_text()
        graphics = ''.join((self.root/p).read_text() for p in
                           ['src/data/tilesets/graphics.h', 'src/graphics.c'])
        metatiles = (self.root/'src/data/tilesets/metatiles.h').read_text()
        folders = {m[1]: self.root/m[2] for m in re.finditer(
            r'const u32 (\w+)\[\] = INCGFX_U32\("([^\"]+)/tiles.png', graphics)}
        meta_paths = {m[1]: self.root/m[2] for m in re.finditer(
            r'const u16 (\w+)\[\] = INCBIN_U16\("([^\"]+metatiles.bin)', metatiles)}
        attributes = {m[2]: self.root/m[3] for m in re.finditer(
            r'const u(16|32) (\w+)\[\] = INCBIN_U(?:16|32)\("([^\"]+metatile_attributes.bin)', metatiles)}
        self.sets = {}
        for name, body in re.findall(r'const struct Tileset (\w+)\s*=\s*\{(.*?)\};', self.headers, re.S):
            tile = re.search(r'\.tiles\s*=\s*(\w+)', body)
            meta = re.search(r'TILESET_METATILES\((\w+),\s*(\w+)\)', body)
            if not tile or tile[1] not in folders or not meta or meta[1] not in meta_paths:
                continue
            folder = folders[tile[1]]
            palettes = {int(p.stem): read_palette(p) for p in (folder/'palettes').glob('*.pal')
                        if p.stem.isdigit()}
            masks = {int(p.stem): {int(x) for x in p.read_text().splitlines()
                                  if x.strip() and not x.lstrip().startswith('#')}
                     for p in (folder/'palettes').glob('*.pla') if p.stem.isdigit()}
            self.sets[name] = dict(folder=folder, palettes=palettes, masks=masks,
                                   image=Image.open(folder/'tiles.png'), body=body,
                                   meta_path=meta_paths[meta[1]],
                                   attributes=attributes[meta[2]],
                                   meta=list(struct.iter_unpack('<8H', meta_paths[meta[1]].read_bytes())))
        self.layouts = {l['id']: l for l in json.loads((self.root/'data/layouts/layouts.json').read_text())['layouts']}
        self.maps = {p.parent.name: json.loads(p.read_text()) for p in (self.root/'data/maps').glob('*/map.json')}
        self.towns = {name: self.layouts[m['layout']] for name, m in self.maps.items()
                      if m.get('map_type') in ('MAP_TYPE_CITY', 'MAP_TYPE_TOWN')}

    @staticmethod
    def split(layout):
        return (512, 6) if layout['layout_version'] == 'emerald' else (640, 7)

    def tile(self, layout, word):
        split, pal_split = self.split(layout)
        tid, bank = word & 1023, word >> 12
        owner = self.sets[layout['primary_tileset' if tid < split else 'secondary_tileset']]
        index = tid if tid < split else tid-split
        sheet = owner['image']
        cols = sheet.width//8
        # Some baseline truck metatiles reference tiles populated by runtime code.
        # PIL pads unloaded source-sheet areas with transparent zero for the static audit.
        tile = sheet.crop((index % cols*8, index//cols*8, index % cols*8+8, index//cols*8+8))
        pal = self.sets[layout['primary_tileset' if bank < pal_split else 'secondary_tileset']]
        return tile, pal['palettes'][bank], pal['masks'].get(bank, set())

    def render(self, layout, mid, lit_only=False):
        split, _ = self.split(layout)
        owner = self.sets[layout['primary_tileset' if mid < split else 'secondary_tileset']]
        cells = owner['meta'][mid if mid < split else mid-split]
        image = Image.new('RGB', (16, 16))
        for k, word in enumerate(cells):
            tile, palette, flags = self.tile(layout, word)
            for py in range(8):
                for px in range(8):
                    c = tile.getpixel((7-px if word & 1024 else px, 7-py if word & 2048 else py))
                    if k < 4 or c:
                        rgb = palette[c] if not lit_only else ((255, 255, 255) if c and c in flags else (0, 0, 0))
                        image.putpixel((k % 2*8+px, (k % 4)//2*8+py), rgb)
        return image

    def words(self, layout, border=False):
        path = layout['border_filepath' if border else 'blockdata_filepath']
        return [x[0] for x in struct.iter_unpack('<H', (self.root/path).read_bytes())]
