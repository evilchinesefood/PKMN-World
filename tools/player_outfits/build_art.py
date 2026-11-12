#!/usr/bin/env python3
from PIL import Image, ImageDraw
from pathlib import Path
R = Path(__file__).resolve().parents[2]
OUT = R / 'graphics/player_outfits'

def front(actor, style):
    im = Image.open(R / f'graphics/trainers/front_pics/{actor}.png').copy()
    p = im.load()
    if actor == 'brendan':
        for y in range(25, 39):
            for x in range(23, 37):
                if p[x, y] in (5, 6, 8, 10, 11, 12, 13):
                    if style == 'kanto':
                        p[x, y] = 9 if 28 <= x <= 31 else 12 if x < 31 else 13
                    elif style == 'johto':
                        p[x, y] = 9 if y <= 29 and (x < 28 or x > 32) else 12 if x < 31 else 13
                    else:
                        p[x, y] = 12 if x < 31 else 13
        d = ImageDraw.Draw(im)
        if style == 'kanto':
            d.line([(27, 27), (27, 36)], fill=15)
            d.line([(32, 27), (33, 37)], fill=15)
            d.line([(26, 38), (34, 38)], fill=8)
            for y in range(52, 57):
                for x in range(20, 39):
                    if p[x, y] not in (0, 15):
                        p[x, y] = 6 if x < 30 else 8
        elif style == 'johto':
            d.line([(30, 26), (31, 37)], fill=9)
            d.point((30, 26), fill=15)
            d.line([(25, 37), (35, 37)], fill=9)
            for y in range(31, 35):
                for x in range(18, 42):
                    if p[x, y] in (1, 2, 3, 4):
                        p[x, y] = 12 if x < 30 else 13
        else:
            d.line([(26, 25), (29, 28), (31, 26), (34, 28)], fill=9)
            d.rectangle((25, 30, 28, 33), fill=13)
            d.line([(25, 30), (28, 30)], fill=9)
            d.rectangle((32, 31, 34, 34), fill=13)
            d.line([(32, 31), (34, 31)], fill=9)
            d.line([(30, 29), (31, 37)], fill=8)
            d.line([(24, 38), (35, 38)], fill=8)
            for y in range(51, 57):
                for x in range(20, 39):
                    if p[x, y] not in (0, 15):
                        p[x, y] = 6 if x < 30 else 8
    elif actor == 'may':
        for y in range(25, 40):
            for x in range(23, 36):
                if p[x, y] in (5, 6, 9, 10, 11, 12, 13):
                    if style == 'kanto':
                        p[x, y] = 9 if 28 <= x <= 30 else 12 if x < 30 else 13
                    elif style == 'johto':
                        p[x, y] = 9 if y < 29 else 12 if x < 30 else 13
                    else:
                        p[x, y] = 12 if x < 30 else 13
        d = ImageDraw.Draw(im)
        if style == 'kanto':
            d.line([(27, 26), (27, 33)], fill=15)
            d.line([(31, 26), (32, 33)], fill=15)
            d.polygon([(24, 35), (33, 35), (37, 42), (23, 43)], fill=6, outline=15)
            for x in [26, 30, 34]:
                d.line([(x, 38), (x - 1, 42)], fill=5)
            for y in range(27, 31):
                for x in range(20, 36):
                    if p[x, y] in (1, 2, 3):
                        p[x, y] = 12 if x < 30 else 13
        elif style == 'johto':
            d.line([(26, 25), (26, 33)], fill=13, width=2)
            d.line([(32, 26), (32, 33)], fill=13, width=2)
            d.rectangle((27, 29, 31, 33), fill=12)
            d.line([(27, 29), (31, 29)], fill=15)
            d.point((27, 28), fill=14)
            d.point((32, 29), fill=14)
            d.polygon([(25, 35), (33, 35), (36, 43), (23, 43)], fill=13, outline=15)
            d.line([(26, 39), (32, 39)], fill=12)
            for y in range(44, 54):
                for x in range(20, 39):
                    if p[x, y] in (1, 2, 3, 4):
                        p[x, y] = 6 if x < 30 else 8
        else:
            d.polygon([(25, 25), (32, 25), (35, 29), (37, 38), (40, 42), (22, 42), (23, 31)], fill=13, outline=15)
            d.polygon([(26, 26), (30, 26), (30, 40), (24, 40)], fill=12)
            d.line([(26, 25), (29, 29), (32, 25)], fill=9)
            d.line([(30, 29), (31, 39)], fill=9)
            d.line([(33, 30), (36, 39)], fill=8)
            d.line([(25, 32), (24, 39)], fill=13)
            d.line([(23, 41), (38, 41)], fill=8)
    return im

def walking(actor, style):
    im = Image.open(R / f'graphics/object_events/pics/people/{actor}/walking.png').copy()
    p = im.load()
    patterns = {('brendan', 'kanto'): [['cc99dd', 'cf99fd', 'cf99fd', '8ffff8'], ['ccccdd', 'ccccdd', 'ccdddd', '8ffff8'], ['c9df', 'c9df', 'dddf', 'ffff']], ('brendan', 'johto'): [['99cc99', 'ccccdd', 'cc9cdd', '999999'], ['99cc99', 'ccccdd', 'ccccdd', '999999'], ['9cdf', 'ccdf', 'c9df', '99ff']], ('brendan', 'hoenn'): [['9cccc9', 'cc8c8d', 'cddcdd', 'ccccdd', '888888'], ['9cccc9', 'ccccdd', 'ccccdd', 'ccdddd', '888888'], ['9cdf', 'c8df', 'ccdf', 'dddf', '88ff']], ('may', 'kanto'): [['cc99dd', 'cc99dd', '888888', '856568', '855568'], ['ccccdd', 'ccccdd', '888888', '856568', '855568'], ['c9df', 'c9df', '888f', '856f', '856f']], ('may', 'johto'): [['9c99d9', '9cccc9', 'ccccdd', 'ccccdd', '8cccc8'], ['9c99d9', '9cccc9', 'ccccdd', 'ccccdd', '8cccc8'], ['9cdf', 'ccdf', 'ccdf', 'dddf', '8ddf']], ('may', 'hoenn'): [['9cccc9', 'cc9cdd', 'cc9cdd', 'ccccdd', '8cccc8'], ['ccccdd', 'ccccdd', 'ccccdd', 'ccccdd', '8cccc8'], ['9cdf', 'ccdf', 'ccdf', 'dddf', '8ddf']]}
    for i in range(9):
        direction = [0, 1, 2, 0, 0, 1, 1, 2, 2][i]
        dy = [0, 0, 0, 1, 1, 1, 1, 1, 1][i]
        pat = patterns[actor, style][direction]
        x0 = i * 16 + (5 if direction == 2 else 5)
        y0 = 23 + dy
        for yy, row in enumerate(pat):
            for xx, c in enumerate(row):
                x, y = (x0 + xx, y0 + yy)
                if y < 31:
                    p[x, y] = int(c, 16)
    return im

def body_pattern(actor, style, direction):
    source = walking(actor, style)
    x = direction * 16 + 5
    return source.crop((x, 23, x + (4 if direction == 2 else 6), 28 if style == 'hoenn' or actor == 'may' else 27))

def cap_anchor(frame):
    points = {(x, y) for y in range(32) for x in range(frame.width) if frame.getpixel((x, y)) in (9, 14)}
    groups = []
    while points:
        todo = [points.pop()]
        group = []
        while todo:
            x, y = todo.pop()
            group.append((x, y))
            for q in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]:
                if q in points:
                    points.remove(q)
                    todo.append(q)
        groups.append(group)
    cap = max(groups, key=len)
    return min((y for x, y in cap)) + 12

def row_center(frame, y):
    runs = []
    run = []
    for x in range(frame.width):
        if frame.getpixel((x, y)):
            run.append(x)
        elif run:
            runs.append(run)
            run = []
    if run:
        runs.append(run)
    run = max(runs, key=len)
    return round((run[0] + run[-1]) / 2)
DIRECTIONS = {'walking': [0, 1, 2, 0, 0, 1, 1, 2, 2], 'running': [0, 1, 2, 0, 0, 1, 1, 2, 2], 'mach_bike': [0, 1, 2, 0, 0, 1, 1, 2, 2], 'acro_bike': [0, 1, 2, 0, 0, 1, 1, 2, 2, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 0, 0, 1, 1, 2, 2], 'surfing': [0, 0, 1, 1, 2, 2], 'fishing': [2, 2, 2, 2, 1, 1, 1, 1, 0, 0, 0, 0], 'watering': [0, 0, 1, 1, 2, 2], 'field_move': [0, 0, 0, 0, 0], 'decorating': [2], 'underwater': [0, 1, 2, 2]}

def overworld(actor, style, pose):
    source = Image.open(R / f'graphics/object_events/pics/people/{actor}/{pose}.png')
    if pose == 'walking':
        return (walking(actor, style), [])
    im = source.copy()
    fw = 16 if pose in ('running', 'decorating') else 32
    male = Image.open(R / f'graphics/object_events/pics/people/brendan/{pose}.png')
    placements = []
    for idx in range(im.width // fw):
        f = source.crop((idx * fw, 0, (idx + 1) * fw, 32))
        mf = male.crop((idx * fw, 0, (idx + 1) * fw, 32))
        direction = DIRECTIONS[pose][idx]
        y = 18 if pose == 'underwater' else cap_anchor(mf)
        cx = row_center(f, y - 4)
        pat = body_pattern(actor, style, direction)
        x = cx - pat.width // 2
        if direction == 2:
            x -= 1
        if pose == 'decorating':
            y = 24
        if pose == 'underwater':
            y = 18
            cx = 16
            x = 13 if direction != 2 else 14
        if pose in ('mach_bike', 'acro_bike', 'surfing', 'underwater'):
            pat = pat.crop((0, 0, pat.width, min(4, pat.height)))
        p = im.load()
        for yy in range(pat.height):
            for xx in range(pat.width):
                px, py = (idx * fw + x + xx, y + yy)
                if idx * fw <= px < (idx + 1) * fw and 0 <= py < 31:
                    old = source.getpixel((px, py))
                    if old not in (1, 2, 3, 4, 7):
                        p[px, py] = pat.getpixel((xx, yy))
        placements.append({'frame': idx, 'direction': direction, 'x': x, 'y': y, 'width': pat.width, 'height': pat.height})
    return (im, placements)
BACK_BODIES = {'brendan': [(24, 42, 46, 64), (22, 44, 46, 64), (10, 44, 30, 64), (28, 42, 49, 64)], 'may': [(23, 44, 39, 64), (25, 44, 42, 64), (14, 44, 28, 64), (24, 43, 39, 64)]}

def back(actor, style):
    im = Image.open(R / f'graphics/trainers/back_pics/{actor}.png').copy()
    p = im.load()
    for f, (left, top, right, bottom) in enumerate(BACK_BODIES[actor]):
        mid = (left + right) // 2
        if actor == 'brendan':
            for y in range(39, 64):
                for x in range(64):
                    if p[x, y + f * 64] in (5, 6):
                        p[x, y + f * 64] = (9 if p[x, y + f * 64] == 6 else 14) if style == 'kanto' else 13 if p[x, y + f * 64] == 6 else 12
        for y in range(top, bottom):
            for x in range(left, right):
                old = p[x, y + f * 64]
                if old in (5, 6, 10, 11, 12, 13):
                    color = 12 if x < mid else 13
                    if style == 'kanto' and (x < left + 3 or x >= right - 3):
                        color = 9
                    if style == 'johto' and y < top + 5:
                        color = 9
                    if actor == 'may' and style == 'johto' and (y < top + 8) and (x in (left + 4, right - 4)):
                        color = 13
                    if style == 'johto' and x == mid:
                        color = 8
                    if style == 'hoenn' and (y == top + 3 or x == mid + 2):
                        color = 8
                    p[x, y + f * 64] = color
        if actor == 'may' and style in ('kanto', 'johto'):
            for y in range(top + 2, min(top + 7, 64)):
                for x in range(max(0, left - 4), min(64, right + 4)):
                    if (x < left + 1 or x > right - 2) and p[x, y + f * 64] in (1, 2, 3, 4):
                        p[x, y + f * 64] = 13 if style == 'kanto' else 9
        if actor == 'may' and style == 'hoenn':
            for y in range(top + 3, bottom):
                spread = min(5, (y - top) // 4)
                for x in range(left - spread, right + spread):
                    if 0 <= x < 64 and p[x, y + f * 64] in (0, 5, 6, 10, 11, 12, 13):
                        p[x, y + f * 64] = 15 if x in (left - spread, right + spread - 1) else 12 if x < mid else 13
            for y in range(top + 7, bottom):
                x = mid + 3 + (y - top) // 9
                if p[x, y + f * 64] in (12, 13):
                    p[x, y + f * 64] = 8
    return im

def palette(path):
    rows = [tuple(map(int, line.split())) for line in path.read_text().splitlines()[3:19]]
    return [c for row in rows for c in row] + [0] * (768 - 48)

def cabinet():
    rows = ['0000000000000000', '0000000000000000', '000fffffffffff00', '00fbbbbbbbbbbbf0', '00fb999999999bf0', '00fb9ddddddd9bf0', '00fb9dfffffd9bf0', '00fb9dfe9efd9bf0', '00fb9df9e9fd9bf0', '00fb9dfffffd9bf0', '00fb9ddddddd9bf0', '00fbbbbbbbbbbbf0', '00fb666f66666bf0', '00fb655f65556bf0', '00fb655f65556bf0', '00fb655f65556bf0', '00fb655f65556bf0', '00fb655f65556bf0', '00fb65ef6e556bf0', '00fb65af6a556bf0', '00fb655f65556bf0', '00fb655f65556bf0', '00fb655f65556bf0', '00fb655f65556bf0', '00fb655f65556bf0', '00fb666f66666bf0', '00fbbbbbbbbbbbf0', '00fbbbbbbbbbbbf0', '000ff000000ff000', '000ff000000ff000', '0000000000000000', '0000000000000000']
    pal = [(115, 197, 164), (255, 222, 205), (222, 164, 148), (205, 131, 115), (123, 90, 82), (164, 98, 57), (106, 57, 41), (49, 65, 106), (24, 41, 82), (238, 222, 180), (255, 197, 90), (74, 41, 32), (255, 98, 90), (57, 90, 115), (255, 255, 255), (0, 0, 0)]
    im = Image.new('P', (16, 32))
    im.putpalette([c for row in pal for c in row] + [0] * 720)
    im.putdata([int(c, 16) for row in rows for c in row])
    im.save(OUT / 'wardrobe.png', bits=4)
    (OUT / 'wardrobe.pal').write_text('JASC-PAL\n0100\n16\n' + '\n'.join((' '.join(map(str, row)) for row in pal)) + '\n')

def main():
    import hashlib, json, shutil
    manifest = json.loads((OUT / 'manifest.json').read_text())
    for entry in manifest['styles']:
        actor, style = (entry['character'], entry['style'])
        directory = OUT / style / actor
        directory.mkdir(parents=True, exist_ok=True)
        for kind, src in [('ow', f'graphics/object_events/palettes/{actor}.pal'), ('trainer', f'graphics/trainers/palettes/{actor}.pal')]:
            shutil.copyfile(R / src, directory / f'{kind}.pal')
        entry['palette_contract'] = {'overworld': {'main': [13, 12], 'accent': [11, 10], 'protected': [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 14, 15]}, 'trainer': {'main': [13, 12], 'trousers': [6, 5], 'accent': [11, 10], 'protected': [0, 1, 2, 3, 4, 7, 8, 9, 14, 15]}, 'nonred_male_trainer': 'Use original male primary ramp row[0:2] at indices13,12. Original male trim ramp is not used for new main garments. All three new designs deliberately share this native palette layout.'}
        for record in entry['poses']:
            pose = record['pose']
            anchors = []
            if pose == 'front':
                im = front(actor, style)
            elif pose == 'back':
                im = back(actor, style)
            else:
                im, anchors = overworld(actor, style, pose)
            im.putpalette(palette(directory / ('trainer.pal' if pose in ('front', 'back') else 'ow.pal')))
            path = directory / f'{pose}.png'
            im.save(path, bits=4)
            record['sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
            record['anchors'] = anchors
            original = Image.open(R / record['source'])
            record['changed_pixels'] = sum((a != b for a, b in zip(im.get_flattened_data(), original.get_flattened_data())))
            assert record['changed_pixels'] > 0 and im.size == original.size
            assert max(im.get_flattened_data()) < 16
    manifest['production_status'] = 'native-art-review'
    manifest['concepts'] = 'review/concepts.png'
    manifest['underwater_contract'] = 'New styles use the normal protagonist palette and authored visible garment panels over the dedicated submerged silhouette. Original style retains its original underwater palette and pixels.'
    (OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    cabinet()
    print('Generated 72 indexed character sheets and one wardrobe cabinet.')
if __name__ == '__main__':
    main()
