#!/usr/bin/env python3
"""Record source/ROM identity at execution time, never at publication time."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'visual-features'))
from run_fixture import case_name, claim_output, settings_from_args


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify_run(out, suite, rom):
    record = json.loads((out / 'run-provenance.json').read_text())
    assert record == dict(suite_sha256=digest(suite), rom_sha256=digest(rom), returncode=0), ('stale or failed suite evidence', out)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--repo', type=Path, required=True)
    p.add_argument('--suite', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    group = p.add_mutually_exclusive_group(required=True)
    group.add_argument('--fixture', type=Path)
    group.add_argument('--rom', type=Path)
    p.add_argument('--save', type=Path)
    p.add_argument('--elf', type=Path)
    p.add_argument('--symbols', type=Path)
    p.add_argument('--case-name')
    p.add_argument('--env', action='append', default=[])
    a = p.parse_args()
    out = a.out.resolve()
    claim_output(out)
    rom = a.fixture / 'VerifyFeatures.gba' if a.fixture else a.rom
    record = dict(suite_sha256=digest(a.suite), rom_sha256=digest(rom))
    settings = settings_from_args(a.env) if a.fixture else dict(value.split('=', 1) for value in a.env)
    name = a.case_name or case_name(a.suite, settings)
    if a.fixture:
        assert a.save is None, 'fixture runner creates its own synthetic profile'
        evidence = out / 'fixture-run'
        cmd = [sys.executable, str(a.repo / 'test/overworld/visual-features/run_fixture.py'), '--repo', str(a.repo), '--fixture', str(a.fixture), '--suite', str(a.suite), '--out', str(evidence), '--case-name', name]
    else:
        cmd = [str(a.repo / 'test/overworld/mgba-run.sh'), str(a.suite), str(a.rom)]
        if a.save:
            cmd.append(str(a.save))
        cmd += ['--out', str(out / 'native'), '--case-name', name, '--elf', str(a.elf or a.rom.with_suffix('.elf'))]
        if a.symbols:
            cmd += ['--symbols', str(a.symbols)]
    for setting in a.env:
        cmd += ['--env', setting]
    result = subprocess.run(cmd, capture_output=True, text=True)
    (out / 'runner.log').write_text(result.stdout + result.stderr)
    print(result.stdout, end='')
    print(result.stderr, end='', file=sys.stderr)
    assert record == dict(suite_sha256=digest(a.suite), rom_sha256=digest(rom)), 'suite or ROM changed during execution'
    record['returncode'] = result.returncode
    if result.returncode == 0:
        if not a.fixture:
            match = re.search(r'^case-dir: (.+)$', result.stdout, re.M)
            assert match, 'runner omitted the selected case directory'
            case = Path(match[1]).resolve()
            assert case.is_relative_to(out / 'native'), 'unexpected case directory'
            evidence = case / 'evidence'
            shutil.copy2(case / 'result.json', out / 'result.json')
            (out / 'command-output.txt').write_text(result.stdout + result.stderr)
            shutil.copy2(case / 'emulator.log', out / 'runner.log')
        else:
            shutil.copy2(evidence / 'result.json', out / 'result.json')
            shutil.copy2(evidence / 'runner.log', out / 'runner.log')
        for path in evidence.iterdir():
            if path.is_file() and path.name not in {'.run-owner', 'runner.log', 'result.json'}:
                shutil.copy2(path, out / path.name)
    (out / 'run-provenance.json').write_text(json.dumps(record, indent=2) + '\n')
    return result.returncode


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (ValueError, OSError) as exc:
        raise SystemExit(str(exc))
