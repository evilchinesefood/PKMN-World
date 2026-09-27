#!/usr/bin/env python3
"""Record source/ROM identity at execution time, never at publication time."""
import argparse
import hashlib
import json
from pathlib import Path
import os
import subprocess
import sys


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify_run(out, suite, rom):
    record = json.loads((out/'run-provenance.json').read_text())
    assert record == dict(suite_sha256=digest(suite), rom_sha256=digest(rom), returncode=0), \
        ('stale or failed suite evidence', out)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--repo', type=Path, required=True)
    p.add_argument('--suite', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    group = p.add_mutually_exclusive_group(required=True)
    group.add_argument('--fixture', type=Path)
    group.add_argument('--rom', type=Path)
    p.add_argument('--save', type=Path)
    a = p.parse_args()
    a.out.mkdir(parents=True, exist_ok=True)
    proof = a.out/'run-provenance.json'
    proof.unlink(missing_ok=True)
    # Old success markers cannot satisfy a subsequent failed or interrupted run.
    for suffix in ('*.PASS', '*.FAIL', '*.log'):
        for old in a.out.glob(suffix):
            old.unlink()
    rom = a.fixture/'VerifyFeatures.gba' if a.fixture else a.rom
    record = dict(suite_sha256=digest(a.suite), rom_sha256=digest(rom))
    if a.fixture:
        assert a.save is None, 'fixture runner creates its own synthetic profile'
        cmd = [sys.executable, str(a.repo/'Testing/visual-features/run_fixture.py'),
               '--repo', str(a.repo), '--fixture', str(a.fixture),
               '--suite', str(a.suite), '--out', str(a.out)]
    else:
        cmd = [str(a.repo/'Testing/mgba-run.sh'), str(a.suite), str(a.rom)]
        if a.save:
            cmd.append(str(a.save))
    result = subprocess.run(cmd, env={**os.environ, 'PW_OUT': str(a.out.resolve())})
    assert record == dict(suite_sha256=digest(a.suite), rom_sha256=digest(rom)), \
        'suite or ROM changed during execution'
    record['returncode'] = result.returncode
    proof.write_text(json.dumps(record, indent=2)+'\n')
    raise SystemExit(result.returncode)


if __name__ == '__main__':
    main()
