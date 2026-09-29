#!/usr/bin/env python3
"""Negative evidence tests for the lighting publisher's complete run contract."""
from pathlib import Path
import tempfile
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
    names = [f'Suite{i}' for i in range(50)]
    def sweep(rows):
        lines = []
        for name, label, count in rows:
            lines.append(f'{name} rc=0 VERDICT {label}: {count}/{count} PASS')
            (root / (name + '.PASS')).write_text(f'PASS {count}/{count} rom={MD5} at=now suite={label}\n')
        lines.append(f'SWEEP OK - every expected suite produced a fresh PASS stamped rom={MD5}')
        (root / 'sweep.log').write_text('\n'.join(lines) + '\n')
    good = [(n, n, 1) for n in names]
    sweep(good)
    assert publisher.validate_sweep(root, MD5) == (50, 50)
    for name, rows in (
        ('duplicate suite', good[:-1] + [good[0]]),
        ('zero assertions', good[:-1] + [(names[-1], names[-1], 0)]),
        ('wrong verdict label', good[:-1] + [(names[-1], 'WrongSuite', 1)]),
    ):
        sweep(rows)
        try:
            publisher.validate_sweep(root, MD5)
        except AssertionError:
            print('PASS:', name, 'rejected')
        else:
            raise AssertionError(name + ' was accepted')
