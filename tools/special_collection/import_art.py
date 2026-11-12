#!/usr/bin/env python3
"""Import reviewed, uniformly gridded generation sheets into native GBA formats."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / 'graphics/pokemon/special_collection'
VARIANTS = (
    ('classic_cap', 'ClassicCap', False, False),
    ('surfboard', 'Surfboard', False, False),
    ('balloons', 'Balloons', False, False),
    ('squad', 'Squad', False, False),
    ('firefighter', 'Firefighter', False, False),
    ('flower_crown', 'FlowerCrown', False, False),
    ('pirate', 'Pirate', False, True),
)


def palette_file(path):
    return [tuple(map(int, row.split())) for row in path.read_text().splitlines()[3:19]]


def save_palette(path, colors):
    path.write_text('JASC-PAL\n0100\n16\n' + ''.join(' '.join(map(str, c)) + '\n' for c in colors))


def fit_cell(sheet, row, col, rows, size):
    cell = sheet.crop((round(col * sheet.width / 4), round(row * sheet.height / rows),
                       round((col + 1) * sheet.width / 4), round((row + 1) * sheet.height / rows)))
    alpha = cell.getchannel('A').point(lambda value: 255 if value >= 128 else 0)
    cell.putalpha(alpha)
    bounds = alpha.getbbox()
    if bounds is None:
        raise ValueError(f'Empty source cell {row}, {col}')
    cell = cell.crop(bounds)
    limit = size - (8 if size == 64 else 4)
    scale = min(limit / cell.width, limit / cell.height)
    cell = cell.resize((max(1, round(cell.width * scale)), max(1, round(cell.height * scale))), Image.Resampling.NEAREST)
    result = Image.new('RGBA', (size, size))
    result.alpha_composite(cell, ((size - cell.width) // 2, size - 2 - cell.height))
    return result


def colors_for(images):
    pixels = [pixel[:3] for image in images for pixel in image.getdata() if pixel[3] >= 128]
    sample = Image.new('RGB', (len(pixels), 1))
    sample.putdata(pixels)
    quantized = sample.quantize(colors=15, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    palette = quantized.getpalette()
    colors = [tuple(palette[i:i + 3]) for i in range(0, 45, 3)]
    return [(0, 0, 0)] + colors


def indexed(image, colors):
    palette = Image.new('P', (1, 1))
    palette.putpalette([value for color in colors for value in color] + [0] * (768 - 48))
    result = Image.new('P', image.size)
    result.putpalette(palette.getpalette())
    cache = {}
    data = []
    for pixel in image.getdata():
        if pixel[3] < 128:
            data.append(0)
            continue
        rgb = pixel[:3]
        if rgb not in cache:
            cache[rgb] = min(range(1, 16), key=lambda i: sum((rgb[c] - colors[i][c]) ** 2 for c in range(3)))
        data.append(cache[rgb])
    result.putdata(data)
    result.info['transparency'] = 0
    return result


def stack(images, horizontal=False):
    size = images[0].width
    result = Image.new('RGBA', (size * len(images), size) if horizontal else (size, size * len(images)))
    for index, image in enumerate(images):
        result.alpha_composite(image, (size * index, 0) if horizontal else (0, size * index))
    return result


def best_icon_palette(images):
    palettes = [palette_file(ROOT / f'graphics/pokemon/icon_palettes/pal{i}.pal') for i in range(6)]
    pixels = {pixel[:3] for image in images for pixel in image.getdata() if pixel[3] >= 128}
    def error(colors):
        return sum(min(sum((rgb[c] - color[c]) ** 2 for c in range(3)) for color in colors[1:]) for rgb in pixels)
    index = min(range(6), key=lambda i: error(palettes[i]))
    return index, palettes[index]


def import_variant(key, symbol, female, asymmetric):
    source = ASSETS / 'source' / f'{key}.png'
    sheet = Image.open(source).convert('RGBA')
    if sheet.getextrema()[3][0] == 255:
        raise ValueError(f'{source}: source must have transparency')
    rows = 6 if female else 3
    frames = {}
    for gender, offset in [('', 0)] + ([('f', 3)] if female else []):
        frames['anim_front' + gender] = [fit_cell(sheet, offset, c, rows, 64) for c in (0, 1)]
        frames['back' + gender] = [fit_cell(sheet, offset, 2, rows, 64)]
        icon = fit_cell(sheet, offset, 3, rows, 32)
        frames['icon' + gender] = [icon, icon.copy()]
        positions = [(offset + 1, c) for c in range(4)] + [(offset + 2, c) for c in range(4 if asymmetric else 2)]
        frames['overworld' + gender] = [fit_cell(sheet, row, col, rows, 32) for row, col in positions]
    battle = colors_for([image for name, images in frames.items() if name.startswith(('anim_', 'back')) for image in images])
    overworld = colors_for([image for name, images in frames.items() if name.startswith('overworld') for image in images])
    icon_index, icon_colors = best_icon_palette([image for name, images in frames.items() if name.startswith('icon') for image in images])
    target = ASSETS / key
    target.mkdir(parents=True, exist_ok=True)
    for name, images in frames.items():
        colors = overworld if name.startswith('overworld') else icon_colors if name.startswith('icon') else battle
        indexed(stack(images, name.startswith('overworld')), colors).save(target / f'{name}.png', bits=4, transparency=0)
    save_palette(target / 'normal.pal', battle)
    save_palette(target / 'overworld_normal.pal', overworld)
    return {'key': key, 'symbol': symbol, 'female': female, 'asymmetric': asymmetric, 'icon_palette': icon_index,
            'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(), 'follower_frames': 8 if asymmetric else 6}


def declarations(entries):
    graphics, tables = [], []
    for entry in entries:
        key, suffix = entry['key'], entry['symbol']
        path = f'graphics/pokemon/special_collection/{key}'
        for gender, end in [('', '')] + ([('f', 'Female')] if entry['female'] else []):
            symbol = 'Special' + suffix + end
            for ctype, prefix, filename, extension in [('u32', 'gMonFrontPic_', 'anim_front', '.4bpp.smol'),
                  ('u32', 'gMonBackPic_', 'back', '.4bpp.smol'), ('u8', 'gMonIcon_', 'icon', '.4bpp')]:
                graphics.append(f'const {ctype} {prefix}{symbol}[] = INCGFX_{ctype.upper()}("{path}/{filename}{gender}.png", "{extension}");')
            graphics.append(f'const u32 gObjectEventPic_{symbol}[] = INCGFX_COMP("{path}/overworld{gender}.png", ".4bpp", "-mwidth 4 -mheight 4");')
            tables.append(f'static const struct SpriteFrameImage sPicTable_{symbol}[] = {{\n    overworld_ascending_frames(gObjectEventPic_{symbol}, 4, 4),\n}};')
        graphics.append(f'const u16 gMonPalette_Special{suffix}[] = INCGFX_U16("{path}/normal.pal", ".gbapal");')
        graphics.append(f'const u16 gOverworldPalette_Special{suffix}[] = INCGFX_U16("{path}/overworld_normal.pal", ".gbapal");')
    (ROOT / 'src/data/graphics/special_collection.h').write_text('\n'.join(graphics) + '\n')
    (ROOT / 'src/data/object_events/special_collection_pic_tables.h').write_text('\n'.join(tables) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--key', choices=[v[0] for v in VARIANTS])
    args = parser.parse_args()
    entries = []
    for variant in VARIANTS:
        if args.key is None or variant[0] == args.key:
            entries.append(import_variant(*variant))
    if args.key is None:
        declarations(entries)
        (ASSETS / 'manifest.json').write_text(json.dumps(entries, indent=2) + '\n')
    else:
        print(json.dumps(entries, indent=2))


if __name__ == '__main__':
    main()
