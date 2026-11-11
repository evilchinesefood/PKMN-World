#!/usr/bin/env python3
"""Explicit Build, Smoke and Full verification of an isolated source snapshot."""
import argparse
import csv
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
FLAGS = (
    ('POKEVIAL_FEATURE', 'include/config/pokevial.h'),
    ('QOL_FIELD_MOVES_ITEM_GATE', 'include/config/qol_field_moves.h'),
    ('PW_GRAPHICAL_START_MENU', 'include/config/start_menu.h'),
)
LOSSES = (('kanto', 'rival_lab'), ('johto', 'rival_and_police'), ('hoenn', 'route103'))


def plan(mode):
    stages = ['build-default']
    if mode != 'build':
        stages += ['bootstrap', 'bind-inputs', 'lua-' + mode]
    if mode == 'full':
        stages += ['runner-boundaries']
        stages += ['loss-' + region for region, _ in LOSSES]
        stages += ['host-validation', 'save-abi', 'palette-dependencies', 'battle-checks']
        stages += ['flag-' + flag for flag, _ in FLAGS]
    return stages


def clean_environment():
    allowed = {'PATH', 'HOME', 'TMPDIR', 'TMP', 'TEMP', 'LANG', 'TERM', 'CI', 'DEVKITARM', 'DEVKITPRO', 'CC', 'CXX', 'SDKROOT', 'MACOSX_DEPLOYMENT_TARGET', 'SYSTEMROOT', 'PKG_CONFIG_PATH', 'PKG_CONFIG_LIBDIR', 'PKG_CONFIG_SYSROOT_DIR'}
    return {key: value for key, value in os.environ.items() if key in allowed or key.startswith(('LC_', 'ARM_'))}


def source_snapshot(destination):
    def git(*args):
        return subprocess.check_output(['git', '-C', str(ROOT), *args])
    commit = git('rev-parse', 'HEAD').decode().strip()
    version = re.sub('[^A-Za-z0-9.-]', '', git('describe', '--tags', '--always', '--dirty').decode())
    tracked = set(git('ls-files', '-z').decode().split('\0')) - {''}
    untracked = set(git('ls-files', '--others', '--exclude-standard', '-z').decode().split('\0')) - {''}
    names = sorted(tracked | untracked)
    tree = hashlib.sha256()
    missing = []
    destination.mkdir()
    for name in names:
        source = ROOT / name
        tree.update(name.encode() + b'\0')
        if not source.exists():
            missing.append(name)
            tree.update(b'deleted\0')
            continue
        if source.is_symlink():
            raise ValueError(f'source snapshot refuses symbolic link: {name}')
        data = source.read_bytes()
        tree.update(hashlib.sha256(data).digest())
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        shutil.copymode(source, target)
    (destination / '.histignore').touch()
    dirty = bool(git('status', '--porcelain', '--untracked-files=normal'))
    if untracked and not version.endswith('-dirty'):
        version += '-dirty'
    return {'commit': commit, 'version': version, 'dirty': dirty, 'source_sha256': tree.hexdigest(), 'untracked_included': sorted(untracked), 'deleted_tracked': missing}


def flip_flag(root, flag, filename):
    path = root / filename
    content, count = re.subn(r'(?m)^(#define\s+' + re.escape(flag) + r'\s+)TRUE(?=\s|$)', r'\1FALSE', path.read_text())
    if count != 1:
        raise ValueError(f'{flag}: expected exactly one TRUE definition; found {count}')
    path.write_text(content)


def execute(args):
    parent = args.out.resolve()
    parent.mkdir(parents=True, exist_ok=True)
    run = Path(tempfile.mkdtemp(prefix=args.mode + '-', dir=parent))
    print(f'verification-dir: {run}', flush=True)
    start = time.monotonic()
    record = {'mode': args.mode, 'configuration': 'default shipping/dev; RELEASE=0 LTO=0', 'command': [sys.executable, str(Path(__file__).resolve()), args.mode, '--jobs', str(args.jobs), '--out', str(parent), '--cache', str(args.cache.resolve())], 'stages': {name: {'status': 'not-run'} for name in plan(args.mode)}, 'excluded': ['complete campaigns', 'natural-team balance', 'all campaign permutations']}
    environment = clean_environment()
    make = shutil.which('gmake') or shutil.which('make')
    if not make:
        raise ValueError('GNU make is required')

    def stage(name, argv, cwd, timeout=7200, capture=False):
        print(f'RUN {name}', flush=True)
        stamp = time.monotonic()
        entry = record['stages'][name]
        entry.update(status='failed', command=argv)
        log = run / (name + '.log')
        try:
            with log.open('w') as output:
                result = subprocess.run(argv, cwd=cwd, env=environment, stdout=subprocess.PIPE if capture else output, stderr=output if capture else subprocess.STDOUT, timeout=timeout, text=capture)
            if result.returncode:
                print(log.read_text(errors='replace')[-6000:], file=sys.stderr)
                raise ValueError(f'{name} exited {result.returncode}; see {log}')
            entry['status'] = 'passed'
            return result.stdout if capture else None
        finally:
            entry['elapsed_seconds'] = round(time.monotonic() - stamp, 3)
            entry['log'] = str(log)
            print(f'{entry["status"].upper()} {name} {entry["elapsed_seconds"]}s', flush=True)

    try:
        source = run / 'source'
        identity = source_snapshot(source)
        record.update(identity)
        (source / '.verification-source.json').write_text(json.dumps(identity, indent=2) + '\n')
        print(f'commit: {record["commit"]}\nsource: {record["source_sha256"]}\nversion: {record["version"]}\nmode: {args.mode}', flush=True)
        default = run / 'default'
        shutil.copytree(source, default)
        base_args = [make, f'-j{args.jobs}', 'GAME_VERSION=EMERALD', 'ALL_REGIONS=1', 'RELEASE=0', 'LTO=0', 'PW_VERSION=' + record['version']]
        stage('build-default', base_args + ['TEST=0', 'modern'], default)
        record['build_inputs'] = {name: hashlib.sha256((default / name).read_bytes()).hexdigest() for name in ('pokemonworld.gba', 'pokemonworld.elf')}
        if args.mode == 'build':
            record['excluded'] += ['Lua cases', 'battle checks', 'feature-off builds', 'emulator bootstrap']
            return 0
        with (default / 'test/overworld/cases.tsv').open() as inventory:
            record['excluded'] += [row['name'] for row in csv.DictReader(inventory, delimiter='\t') if row['scope'] != 'required' or (args.mode == 'smoke' and row['smoke'] != '1')]
        emulator = stage('bootstrap', ['bash', str(default / 'test/overworld/mgba/bootstrap.sh'), '--prefix', str(args.cache.resolve()), '--jobs', str(args.jobs)], default, capture=True).strip()
        if not Path(emulator).is_file():
            raise ValueError('bootstrap did not return one emulator executable path')
        environment['MGBA_HEADLESS'] = emulator
        record['emulator'] = subprocess.check_output([emulator, '--version', 'unused.gba'], text=True).strip()
        record['bootstrap_key'] = Path(emulator).parents[2].name if (Path(emulator).parents[2] / 'complete.json').is_file() else 'unknown'
        record['emulator_sha256'] = hashlib.sha256(Path(emulator).read_bytes()).hexdigest()
        bundle = run / 'bundle'
        stage('bind-inputs', [sys.executable, str(default / 'test/overworld/NativeRunner.py'), 'bundle', '--rom', str(default / 'pokemonworld.gba'), '--elf', str(default / 'pokemonworld.elf'), '--out', str(bundle)], default)
        record['bundle'] = json.loads((bundle / 'bundle.json').read_text())
        cases = run / 'cases'
        stage('lua-' + args.mode, ['bash', str(default / 'test/overworld/run-all.sh'), str(bundle / 'pokemonworld.gba'), '--bundle', str(bundle), '--profile', args.mode, '--out', str(cases)], default, timeout=21600)
        if args.mode == 'smoke':
            record['excluded'] += ['remaining canonical Lua cases', 'early forced losses', 'battle checks', 'feature-off builds']
            return 0
        stage('runner-boundaries', [sys.executable, str(default / 'test/overworld/TestNativeRunner.py'), '--rom', str(bundle / 'pokemonworld.gba'), '--elf', str(bundle / 'pokemonworld.elf'), '--out', str(run / 'boundary-checks')], default)
        for region, beat in LOSSES:
            stage('loss-' + region, [sys.executable, str(default / 'test/overworld/johto-playthrough/run.py'), '--campaign', region, '--to', beat, '--lose', beat + ':trainer', '--no-retry', '--rom', str(bundle / 'pokemonworld.gba'), '--elf', str(bundle / 'pokemonworld.elf'), '--symbols', str(bundle / 'symbols.lua'), '--out', str(cases / ('loss-' + region))], default, timeout=1800)
        stage('host-validation', [sys.executable, 'test/validate-host.py'], default)
        stage('save-abi', [sys.executable, 'test/overworld/SavePatch.py', '--probe'], default)
        stage('palette-dependencies', [sys.executable, 'test/overworld/TestPaletteDependencies.py'], default)
        battle = run / 'battle'
        shutil.copytree(source, battle)
        stage('battle-checks', base_args + ['TEST=1', 'check'], battle, timeout=19800)
        for flag, filename in FLAGS:
            configuration = run / ('flag-' + flag)
            shutil.copytree(source, configuration)
            flip_flag(configuration, flag, filename)
            stage('flag-' + flag, base_args + ['TEST=0', 'modern'], configuration)
        return 0
    except (ValueError, OSError, subprocess.SubprocessError) as exc:
        record['failure'] = str(exc)
        print(f'VERIFICATION FAILED: {exc}', file=sys.stderr)
        return 1
    finally:
        record['elapsed_seconds'] = round(time.monotonic() - start, 3)
        record['cases'] = [json.loads(path.read_text()) for path in sorted((run / 'cases').rglob('result.json'))] if (run / 'cases').exists() else []
        record['status'] = 'passed' if record['stages'] and all(step['status'] == 'passed' for step in record['stages'].values()) else 'failed'
        (run / 'summary.json').write_text(json.dumps(record, indent=2) + '\n')
        lines = [f'{key}: {record.get(key)}' for key in ('status', 'commit', 'source_sha256', 'dirty', 'version', 'mode', 'configuration', 'emulator', 'elapsed_seconds')]
        hashes = record.get('bundle', {}).get('sha256', record.get('build_inputs', {}))
        lines += [f'sha256 {name}: {value}' for name, value in hashes.items()]
        if 'emulator_sha256' in record:
            lines += [f'bootstrap_key: {record["bootstrap_key"]}', f'emulator_sha256: {record["emulator_sha256"]}']
        lines += [f'{name}: {entry["status"]} {entry.get("elapsed_seconds", 0)}s' for name, entry in record['stages'].items()]
        lines += [f'case {case["case"]}: {case["status"]} assertions={case["assertions"]} fixture={case.get("fixture")}' for case in record['cases']]
        lines += ['excluded: ' + ', '.join(record['excluded']), 'reproduce: ' + __import__('shlex').join(record['command']), 'details: ' + str(run / 'summary.json')]
        (run / 'summary.txt').write_text('\n'.join(lines) + '\n')
        print('\n'.join(lines), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', nargs='?', choices=('build', 'smoke', 'full'), default='smoke')
    parser.add_argument('--jobs', type=int, default=min(os.cpu_count() or 2, 8))
    parser.add_argument('--out', type=Path, default=ROOT / '_pwtest/verification')
    parser.add_argument('--cache', type=Path, default=ROOT / '.cache/verification-tools')
    args = parser.parse_args()
    if args.jobs < 1:
        parser.error('--jobs must be positive')
    return execute(args)


if __name__ == '__main__':
    sys.exit(main())
