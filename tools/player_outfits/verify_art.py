#!/usr/bin/env python3
"""Check the authored wardrobe inventory and native frame invariants."""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
manifest = json.loads((ROOT / 'graphics/player_outfits/manifest.json').read_text())
styles = manifest['styles']
assert {(s['style'], s['character']) for s in styles} == {
    (style, actor) for style in ('kanto', 'johto', 'hoenn') for actor in ('brendan', 'may')
}
poses = {'walking', 'running', 'mach_bike', 'acro_bike', 'surfing', 'field_move',
         'fishing', 'watering', 'underwater', 'decorating', 'front', 'back'}
frames = 0
for design in styles:
    assert design['colors'] == ['Red', 'Blue', 'Green', 'Purple', 'Black', 'Pink']
    assert {p['pose'] for p in design['poses']} == poses
    for record in design['poses']:
        path = ROOT / record['output']
        assert hashlib.sha256(path.read_bytes()).hexdigest() == record['sha256'], path
        art = Image.open(path)
        source = Image.open(ROOT / record['source'])
        assert art.mode == 'P' and art.size == source.size, path
        assert art.size == (record['width'], record['height']), path
        assert set(art.get_flattened_data()) <= set(range(16)), path
        fw, fh = record['frame_width'], record['frame_height']
        assert art.width % fw == art.height % fh == 0, path
        actual_frames = 0
        for y in range(0, art.height, fh):
            for x in range(0, art.width, fw):
                box = (x, y, x + fw, y + fh)
                output_frame = art.crop(box)
                source_frame = source.crop(box)
                assert output_frame.tobytes() != source_frame.tobytes(), (path, actual_frames)
                protected_height = 24 if record['pose'] == 'front' else 39 if record['pose'] == 'back' else 14
                head = (0, 0, fw, protected_height)
                assert output_frame.crop(head).tobytes() == source_frame.crop(head).tobytes(), (path, actual_frames, 'head')
                actual_frames += 1
        assert actual_frames == record['frames'], path
        frames += actual_frames
    for kind, path in design['palette_base'].items():
        rows = (ROOT / path).read_text().splitlines()
        assert rows[:3] == ['JASC-PAL', '0100', '16'], path
        palette = [tuple(map(int, row.split())) for row in rows[3:]]
        assert len(palette) == 16 and all(len(row) == 3 for row in palette), path
        assert all(0 <= c <= 255 for row in palette for c in row), path
        assert palette[15] == (0, 0, 0), path
cabinet = Image.open(ROOT / 'graphics/player_outfits/wardrobe.png')
assert cabinet.mode == 'P' and cabinet.size == (16, 32)
assert set(cabinet.get_flattened_data()) <= set(range(16))
print(f'PASS: 6 designs, 36 new color combinations, 72 indexed sheets, {frames} authored frames, protected heads and cabinet.')
