#!/usr/bin/env python3
"""Negative evidence tests for the lighting publisher's complete run contract."""
from pathlib import Path
import tempfile
import csv
import json
import shutil
import render_review as publisher

MD5 = 'A' * 32

def write(directory, suite, count):
    directory.mkdir(parents=True, exist_ok=True)
    for path in directory.iterdir():
        path.unlink()
    verdict = f'VERDICT {suite}: {count}/{count} PASS\n'
    (directory / (suite + '.log')).write_text(verdict)
    (directory / 'runner.log').write_text(verdict)
    (directory / (suite + '.PASS')).write_text(f'PASS {count}/{count} rom={MD5} at=now suite={suite}\n')

with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    dirs = [root / name for name in ('before', 'after', 'lifecycle', 'delivery')]
    before, after, lifecycle, delivery = dirs
    for path in (before, after):
        write(path / '01-01', 'RegionalLightingCapture', 6)
    write(lifecycle, 'RegionalLightingLifecycle', 48)
    write(delivery, 'RegionalLightingDelivery', 3)
    hashes = dict.fromkeys(('before', 'after', 'lifecycle'), MD5)
    def validate():
        return publisher.validate_feature_runs(*dirs, hashes, MD5, 1)
    assert validate() == {'before': 6, 'after': 6, 'lifecycle': 48, 'delivery': 3}
    for name, path, wrong_suite, wrong_count, proper_suite, proper_count in (
        ('wrong lifecycle suite', lifecycle, 'WrongSuite', 48, 'RegionalLightingLifecycle', 48),
        ('wrong capture suite', before / '01-01', 'WrongSuite', 6, 'RegionalLightingCapture', 6),
        ('partial lifecycle', lifecycle, 'RegionalLightingLifecycle', 1, 'RegionalLightingLifecycle', 48),
        ('partial capture', after / '01-01', 'RegionalLightingCapture', 1, 'RegionalLightingCapture', 6),
        ('partial delivery', delivery, 'RegionalLightingDelivery', 1, 'RegionalLightingDelivery', 3),
    ):
        write(path, wrong_suite, wrong_count)
        try:
            validate()
        except AssertionError:
            print('PASS:', name, 'rejected')
        else:
            raise AssertionError(name + ' was accepted')
        write(path, proper_suite, proper_count)
print('PASS: complete lighting run contract accepted')

with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    catalog = list(csv.DictReader((Path(__file__).resolve().parents[1] / 'cases.tsv').open(), delimiter='\t'))
    names = [row['name'] for row in catalog if row['scope'] == 'required']
    def sweep(rows):
        for path in root.iterdir():
            shutil.rmtree(path) if path.is_dir() else path.unlink()
        (root / 'selected.tsv').write_text(''.join(f'{name}\tsuite.lua\t-\n' for name, _, _ in rows))
        (root / 'summary.txt').write_text(f'selected={len(rows)} passed={len(rows)} failed=0 excluded=VerifyOwnerSave\n')
        for name, label, count in rows:
            case = root / (name + '-case')
            (case / 'evidence').mkdir(parents=True, exist_ok=True)
            (case / 'result.json').write_text(json.dumps({'case': label, 'status': 'passed', 'rom_md5': MD5, 'assertions': count}))
            (root / (name + '.log')).write_text(f'case-dir: {case}\n')
            (case / 'evidence' / (name + '.PASS')).write_text(f'PASS {count}/{count} rom={MD5} at=now suite={label}\n')
    good = [(n, n, 1) for n in names]
    sweep(good)
    assert publisher.validate_sweep(root, MD5) == (len(names), len(names))
    for name, rows in (
        ('duplicate suite', good[:-1] + [good[0]]),
        ('missing canonical suite', good[:-1]),
        ('zero assertions', good[:-1] + [(names[-1], names[-1], 0)]),
        ('wrong verdict label', good[:-1] + [(names[-1], 'WrongSuite', 1)]),
    ):
        sweep(rows)
        try:
            publisher.validate_sweep(root, MD5)
        except (AssertionError, ValueError):
            print('PASS:', name, 'rejected')
        else:
            raise AssertionError(name + ' was accepted')
