#!/usr/bin/env python3
"""Verify the 37 imported bitmaps/palettes against the pinned author's commit."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

PIN = 'b798929811ec7d070616c7ef47e46cfc6a7f1501'
p = argparse.ArgumentParser()
p.add_argument('--donor', type=Path, required=True)
p.add_argument('--out', type=Path)
a = p.parse_args()
repo = Path(__file__).resolve().parents[2]
files = sorted((repo / 'graphics/battle_interface/bw').rglob('*'))
files += [repo / ('graphics/fonts/' + name + '.png') for name in
          ('latin_outlined', 'latin_outlined_narrow', 'latin_battle_ui_element')]
results = []
for f in files:
    if not f.is_file() or f.suffix not in ('.png', '.pal', '.bin'):
        continue
    rel = f.relative_to(repo).as_posix()
    expected = subprocess.check_output(['git', '-C', str(a.donor), 'show', PIN + ':' + rel])
    actual = f.read_bytes()
    normalized = (lambda b: b.replace(b'\r\n', b'\n')) if f.suffix == '.pal' else (lambda b: b)
    assert normalized(actual) == normalized(expected), rel + ' differs from pinned donor'
    results.append({'path': rel, 'sha256': hashlib.sha256(actual).hexdigest(),
                    'donor_sha256': hashlib.sha256(expected).hexdigest(),
                    'pal_line_endings_normalized': f.suffix == '.pal'})
assert len(results) == 37, len(results)
report = {'donor': 'mudskipper13/pokeemerald', 'commit': PIN, 'assets': results}
if a.out:
    a.out.write_text(json.dumps(report, indent=2) + '\n')
print('PASS: all 37 BW graphics assets match ' + PIN)
