#!/usr/bin/env python3
"""Verify source identities, semantic exceptions, crops, and reproducibility."""
import argparse
import contextlib
import hashlib
import io
import json
import pathlib
import tempfile

from PIL import Image
from render_study import Source, build_deliverables

HERE = pathlib.Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument('--world', type=pathlib.Path, default=HERE.parents[2])
parser.add_argument('--donor', type=pathlib.Path, required=True)
parser.add_argument('--output', type=pathlib.Path, default=HERE / 'verification.json')
args = parser.parse_args()

verified = {}
for label, root in [('world', args.world), ('donor', args.donor)]:
    name = 'world-input-manifest.json' if label == 'world' else 'donor-manifest.json'
    entries = json.loads((HERE / name).read_text())['files']
    for entry in entries:
        data = (root / entry['path']).read_bytes()
        if entry.get('normalizeCRLF'):
            data = data.replace(b'\r\n', b'\n')
        assert hashlib.sha256(data).hexdigest() == entry['sha256'], entry['path']
        if 'gitBlobSha1' in entry:
            git_hash = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data)
            assert git_hash.hexdigest() == entry['gitBlobSha1'], entry['path']
    verified[label] = len(entries)

world = Source(args.world).map('FuchsiaCity_Frlg')
spec = json.loads((HERE / 'mapping.json').read_text())
rows = {int(row['worldMetatile'], 16): row for row in spec['rows']}
assert set(rows) == {block & 1023 for block in world['blocks']}
cells = json.loads((HERE / 'cell-mapping.json').read_text())
assert len(cells) == world['width'] * world['height'] == 1920
for cell in cells:
    pos = cell['y'] * world['width'] + cell['x']
    assert cell['worldMetatile'] == world['blocks'][pos] & 1023

measurements = json.loads((HERE / 'measurements.json').read_text())
before = Image.open(HERE / 'images/current-overview.png').convert('RGB')
after = Image.open(HERE / 'images/donor-concept-overview.png').convert('RGB')
assert before.size == after.size == (768, 640)
assert before.tobytes() != after.tobytes()
for camera in measurements['cameras']:
    x, y = camera['x'], camera['y']
    for name, overview in [('current', before), ('donor', after)]:
        image = Image.open(HERE / 'images' / f"{camera['id']}-{name}.png").convert('RGB')
        assert image.size == (240, 160)
        assert image.tobytes() == overview.crop((x, y, x + 240, y + 160)).tobytes()

retained_cells = 0
for region in spec['cellRetainRegions']:
    box = (region['x0'] * 16, region['y0'] * 16,
           (region['x1'] + 1) * 16, (region['y1'] + 1) * 16)
    assert before.crop(box).tobytes() == after.crop(box).tobytes(), region['name']
    retained_cells += (region['x1'] - region['x0'] + 1) * (region['y1'] - region['y0'] + 1)
assert retained_cells == measurements['retainedContextExceptionCells'] == 45

with tempfile.TemporaryDirectory(prefix='pkmn-world-hns-verify-') as temporary:
    out = pathlib.Path(temporary)
    with contextlib.redirect_stdout(io.StringIO()):
        build_deliverables(args.world, args.donor, out)
    image_hashes = {}
    for path in sorted((HERE / 'images').glob('*.png')):
        fresh = out / 'images' / path.name
        assert fresh.read_bytes() == path.read_bytes(), path.name
        image_hashes[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
    for name in ['measurements.json', 'cell-mapping.json']:
        assert (HERE / name).read_bytes() == (out / name).read_bytes(), name

result = {
    'status': 'pass',
    'verifiedPinnedInputFiles': verified,
    'explicitMetatileMappings': len(rows),
    'worldCellsPreserved': len(cells),
    'nativeCameraPairs': 3,
    'nativeCameraDimensions': [240, 160],
    'overviewDimensions': [768, 640],
    'contextExceptionCellsVerifiedPixelExact': retained_cells,
    'freshBuildByteIdentical': True,
    'imageSha256': image_hashes,
    'limitations': ['Static source-art validation only; no ROM import or emulator runtime validation.'],
}
args.output.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({key: value for key, value in result.items() if key != 'imageSha256'}, indent=2))
