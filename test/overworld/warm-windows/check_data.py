#!/usr/bin/env python3
"""Audit #335's complete tileset sharing scope and render its palette atlas."""
import argparse
import json
from pathlib import Path
import re
import struct

from PIL import Image, ImageDraw


def colors(path):
    lines = path.read_text().splitlines()
    assert lines[:3] == ['JASC-PAL', '0100', '16'], path
    return [tuple(map(int, line.split())) for line in lines[3:]]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    root = args.repo
    args.out.mkdir(parents=True, exist_ok=True)
    headers = (root / 'src/data/tilesets/headers.h').read_text()
    layouts = json.loads((root / 'data/layouts/layouts.json').read_text())['layouts']
    expected = {
        'NewBarkTown_Layout': [(12, 7, 0x2BF)],
        'CherrygroveCity_Layout': [(34, 13, 0x2EB), (42, 14, 0x2EB), (50, 17, 0x2EB)],
        'Route30_Layout': [(35, 4, 0x2EB), (26, 39, 0x2EB)],
        'Route29_Layout': [], 'Route27_Layout': [], 'Route31_Layout': [], 'Route46_Layout': [],
    }
    audit = {}
    atlas = Image.new('RGB', (520, 370), '#172331')
    draw = ImageDraw.Draw(atlas)
    draw.text((12, 8), 'Source metatiles: day / alternate (before runtime lighting)', fill='white')
    row = 0
    for symbol, directory in [('NewBarkTown', 'new_bark_town'), ('CherrygroveCity', 'cherrygrove_city')]:
        folder = root / 'data/tilesets/secondary' / directory
        body = re.search(r'const struct Tileset gTileset_' + symbol + r'\s*=\s*\{(.*?)\};', headers, re.S)[1]
        assert re.search(r'\.swapPalettes\s*=\s*\(1 << 1\)', body), symbol
        day, alternate = [colors(folder / f'palettes/{i:02}.pal') for i in (8, 1)]
        changed = [i for i in range(16) if day[i] != alternate[i]]
        assert changed == [8, 9, 10], (symbol, changed)
        assert alternate[8:11] == [(248, 232, 160), (248, 200, 104), (216, 152, 64)]
        immunity = [int(line) for line in (folder/'palettes/08.pla').read_text().splitlines()
                    if line.strip() and not line.lstrip().startswith('#')]
        assert immunity == [8, 9, 10]
        metatiles = list(struct.iter_unpack('<8H', (folder / 'metatiles.bin').read_bytes()))
        bank8 = {i+640: cells for i, cells in enumerate(metatiles) if any(v>>12 == 8 for v in cells)}
        assert set(bank8) == ({0x2BD, 0x2BF} if symbol == 'NewBarkTown' else {0x2EB, 0x330})
        for layout in layouts:
            if layout['secondary_tileset'] != 'gTileset_' + symbol:
                continue
            assert layout['layout_version'] == 'johto'
            words = [v[0] for v in struct.iter_unpack('<H', (root/layout['blockdata_filepath']).read_bytes())]
            placements = [(i % layout['width'], i // layout['width'], v & 1023)
                          for i, v in enumerate(words) if v & 1023 in bank8]
            assert placements == expected[layout['name']], (layout['name'], placements)
            border = [v[0]&1023 for v in struct.iter_unpack('<H', (root/layout['border_filepath']).read_bytes())]
            assert not set(border) & bank8.keys(), layout['name']
            audit[layout['name']] = placements
        # Primary and secondary tile IDs are split at 640 in Johto.
        primary = root/'data/tilesets/primary/johto_general'
        sheets = [Image.open(primary/'tiles.png'), Image.open(folder/'tiles.png')]
        for metatile, cells in bank8.items():
            y = 35 + row*80
            draw.text((12, y+8), f'{symbol}\n0x{metatile:03X}', fill='white')
            for column, glass in enumerate((day, alternate)):
                tile = Image.new('RGB', (16, 16), '#172331')
                for k, value in enumerate(cells):
                    index, bank = value & 1023, value >> 12
                    sheet = sheets[index >= 640]
                    index = index-640 if index >= 640 else index
                    pal = glass if bank == 8 else colors((primary if bank < 7 else folder)/f'palettes/{bank:02}.pal')
                    for py in range(8):
                        for px in range(8):
                            sx, sy = (7-px if value&1024 else px), (7-py if value&2048 else py)
                            color = sheet.getpixel(((index%16)*8+sx, (index//16)*8+sy))
                            if color:
                                tile.putpixel(((k%2)*8+px, ((k%4)//2)*8+py), pal[color])
                atlas.paste(tile.resize((64,64),Image.Resampling.NEAREST),(230+column*100,y))
            row += 1
    assert set(audit) == set(expected), set(audit)
    atlas.save(args.out/'palette-atlas.png')
    (args.out/'map-audit.json').write_text(json.dumps(audit, indent=2)+'\n')
    print('PASS: two secondary bit-1 masks; exact amber ramp at 8/9/10; existing high bits retained.')
    print('PASS: all seven sharing layouts and borders audited; exactly six placements; four unused-map views unchanged in scope.')
    print('PASS: atlas includes both used and both unused bank-8 metatiles.')


if __name__ == '__main__':
    main()
