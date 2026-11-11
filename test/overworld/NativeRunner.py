#!/usr/bin/env python3
"""Immutable native inputs and one verdict boundary for every Lua caller."""
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

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
RESERVED = {'PW_SUITE', 'PW_ROM_NAME', 'PW_ROM_HASH', 'PW_OUT', 'PW_SAVE', 'PW_SYMBOLS'}
# These exact historical saves test refusal; their sector layout predates SavePatch's ABI.
LEGACY_FIXTURES = {
    'v3.srm': '47c07cdae410569cb8b1df6dbd5d8c0936649b6a12666b5df878af3d2a3fa178',
    'v4.srm': '818c00af0e485f62a068732d13eaf81be821181cbd86867edf6df42a85029ab1',
    'v5.srm': 'd2c302a29bb150a1b5c68a5e783219c4012e7aee8abbe00a21f2d4b6fbf67e5e',
}


def digest(path, algorithm='sha256'):
    return hashlib.new(algorithm, Path(path).read_bytes()).hexdigest()


def arm_tool(name):
    override = os.environ.get('ARM_' + name.upper())
    if override:
        candidates = [override]
    else:
        candidates = [str(Path(os.environ.get('DEVKITARM', '/opt/devkitpro/devkitARM')) / 'bin' / ('arm-none-eabi-' + name)), 'arm-none-eabi-' + name]
    for candidate in candidates:
        found = shutil.which(candidate)
        if found:
            return found
    raise ValueError('ARM ' + name + ' not found; set ARM_' + name.upper() + ' or DEVKITARM')


def symbol_content(text):
    text = re.sub(r'--[^\n]*', '', text)
    text = re.sub(r'romName\s*=\s*"[^"]*"', 'romName=""', text)
    return re.sub(r'\s+', '', text)


def make_bundle(rom, elf, out, symbols=None):
    out = Path(out)
    out.mkdir(parents=True, exist_ok=False)
    for source, name in ((rom, 'pokemonworld.gba'), (elf, 'pokemonworld.elf')):
        if not Path(source).is_file():
            raise ValueError(f'missing input: {source}')
        shutil.copyfile(source, out / name)
    reconstructed = out / 'reconstructed.gba'
    subprocess.run([arm_tool('objcopy'), '-O', 'binary', str(out / 'pokemonworld.elf'), str(reconstructed)], check=True)
    fix = ROOT / 'tools/gbafix/gbafix'
    if not fix.is_file():
        raise ValueError('gbafix is missing; build the default configuration first')
    subprocess.run([str(fix), str(reconstructed), '-p', '--silent'], check=True)
    if digest(reconstructed) != digest(out / 'pokemonworld.gba'):
        raise ValueError('ROM/ELF mismatch: reconstructing the selected ELF produced different ROM bytes')
    reconstructed.unlink()
    result = subprocess.run([sys.executable, str(HERE / 'GenLuaSymbols.py'), str(out / 'pokemonworld.elf'), arm_tool('nm'), '--rom', str(out / 'pokemonworld.gba')], check=True, capture_output=True, text=True)
    if symbols and symbol_content(Path(symbols).read_text()) != symbol_content(result.stdout):
        raise ValueError('symbols do not match the selected ROM/ELF')
    (out / 'symbols.lua').write_text(result.stdout)
    hashes = {name: digest(out / name) for name in ('pokemonworld.gba', 'pokemonworld.elf', 'symbols.lua')}
    (out / 'bundle.json').write_text(json.dumps({'format': 1, 'sha256': hashes}, indent=2) + '\n')
    for path in out.iterdir():
        path.chmod(0o444)
    return out


def check_bundle(bundle):
    bundle = Path(bundle).resolve()
    record = json.loads((bundle / 'bundle.json').read_text())
    names = {'pokemonworld.gba', 'pokemonworld.elf', 'symbols.lua'}
    if record.get('format') != 1 or set(record.get('sha256', {})) != names:
        raise ValueError('invalid native bundle record')
    for name in names:
        if digest(bundle / name) != record['sha256'][name]:
            raise ValueError(f'changed immutable bundle input: {name}')
    return bundle


def check_fixture(path):
    import SavePatch
    if Path(path).stat().st_size != SavePatch.FLASH_SIZE:
        raise ValueError(f'fixture must be a raw {SavePatch.FLASH_SIZE}-byte flash image: {path}')
    if digest(path) in LEGACY_FIXTURES.values():
        return
    save = SavePatch.Save(path)
    SavePatch.require_intact_slot(save)
    if len(save.flash) != SavePatch.FLASH_SIZE:
        raise ValueError(f'invalid fixture size: {path}')


def audit(out, name, rom_md5):
    out = Path(out)
    if list(out.glob('*.FAIL')):
        raise ValueError('case wrote a FAIL sentinel')
    sentinels = list(out.glob('*.PASS'))
    expected = out / (name + '.PASS')
    if sentinels != [expected]:
        raise ValueError(f'expected exactly {name}.PASS; found {[p.name for p in sentinels]}')
    text = expected.read_text().strip()
    match = re.fullmatch(r'PASS (\d+)/(\d+) rom=([0-9A-Fa-f]{32}) at=\S+ suite=(\S+)', text)
    if not match or match[4] != name or match[3].upper() != rom_md5.upper():
        raise ValueError('malformed, wrong-case or wrong-ROM PASS sentinel')
    passed, total = int(match[1]), int(match[2])
    if total == 0 or passed != total:
        raise ValueError('PASS must contain positive, equal assertion counts')
    return total


def source_identity():
    metadata = ROOT / '.verification-source.json'
    if metadata.is_file():
        return json.loads(metadata.read_text())
    try:
        top = subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', '--show-toplevel'], text=True, stderr=subprocess.DEVNULL).strip()
        if Path(top).resolve() != ROOT:
            return {'commit': 'unknown'}
        return {'commit': subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip(),
                'dirty': bool(subprocess.check_output(['git', '-C', str(ROOT), 'status', '--porcelain']))}
    except subprocess.SubprocessError:
        return {'commit': 'unknown'}


def run_case(args):
    suite = Path(args.suite).resolve()
    if not suite.is_file():
        raise ValueError(f'missing suite: {suite}')
    name = args.case_name or suite.stem
    if not re.fullmatch(r'[A-Za-z0-9_-]+', name):
        raise ValueError('case name must contain letters, digits, underscore or hyphen')
    if os.environ.get('CI') and (name == 'VerifyOwnerSave' or suite.stem == 'VerifyOwnerSave'):
        raise ValueError('personal-save coverage is not permitted in CI')
    parent = Path(args.out).resolve()
    parent.mkdir(parents=True, exist_ok=True)
    case = Path(tempfile.mkdtemp(prefix=name + '-', dir=parent))
    print(f'case-dir: {case}', flush=True)
    start = time.monotonic()
    record = {'source': source_identity(), 'case': name, 'suite': str(suite), 'status': 'failed', 'assertions': 0, 'command': sys.argv, 'fixture': None}
    try:
        bundle = check_bundle(args.bundle) if args.bundle else make_bundle(args.rom, args.elf or Path(args.rom).with_suffix('.elf'), case / 'bundle', args.symbols)
        if args.bundle and digest(args.rom) != digest(bundle / 'pokemonworld.gba'):
            raise ValueError('ROM does not match the selected bundle')
        if args.bundle and args.symbols and symbol_content(Path(args.symbols).read_text()) != symbol_content((bundle / 'symbols.lua').read_text()):
            raise ValueError('symbols do not match the selected bundle')
        if args.bundle and args.elf and digest(args.elf) != digest(bundle / 'pokemonworld.elf'):
            raise ValueError('ELF does not match the selected bundle')
        work, out = case / 'emulator', case / 'evidence'
        work.mkdir(); out.mkdir()
        rom = work / 'Verify1.gba'
        shutil.copyfile(bundle / 'pokemonworld.gba', rom)
        if digest(rom) != digest(bundle / 'pokemonworld.gba'):
            raise ValueError('ROM changed while being copied')
        symbols = work / 'symbols.lua'
        shutil.copyfile(bundle / 'symbols.lua', symbols)
        if args.save:
            check_fixture(args.save)
            shutil.copyfile(args.save, work / 'Verify1.sav')
            check_fixture(work / 'Verify1.sav')
            record['fixture'] = {'path': str(Path(args.save).resolve()), 'sha256': digest(work / 'Verify1.sav'), 'validation': 'pinned legacy SHA256' if digest(work / 'Verify1.sav') in LEGACY_FIXTURES.values() else 'sector checksums'}
        env = {key: value for key, value in os.environ.items() if not key.startswith('PW_')}
        for setting in args.env:
            key, sep, value = setting.partition('=')
            if not sep or not re.fullmatch(r'PW_[A-Z0-9_]+', key) or key in RESERVED:
                raise ValueError(f'invalid or reserved case setting: {key}')
            env[key] = value
        rom_md5 = digest(rom, 'md5').upper()
        env.update(PW_SUITE=str(suite), PW_ROM_NAME='Verify1', PW_ROM_HASH=rom_md5, PW_OUT=str(out) + '/', PW_SYMBOLS=str(symbols))
        emulator = args.emulator or os.environ.get('MGBA_HEADLESS') or shutil.which('mgba-headless')
        if not emulator:
            raise ValueError('mgba-headless not found; use the documented pinned bootstrap')
        version = subprocess.run([emulator, '--version', 'unused.gba'], capture_output=True, text=True, timeout=15, env={k: v for k, v in env.items() if not k.startswith('PW_')})
        record['emulator_version'] = version.stdout.strip() if version.returncode == 0 else 'unavailable'
        command = [emulator, '-l', '0', '--rtc', str(args.rtc), '--script', str(HERE / 'lua/mgba_shim.lua'), str(rom)]
        record.update(rom_md5=rom_md5, inputs=json.loads((bundle / 'bundle.json').read_text())['sha256'], emulator=str(emulator), rtc=args.rtc, settings={k: v for k, v in env.items() if k.startswith('PW_')})
        print(f'case: {name}\nrom: {rom_md5}\nfixture: {record["fixture"]}\ntimeout: {args.timeout}s', flush=True)
        with (case / 'emulator.log').open('w') as log:
            try:
                completed = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=args.timeout)
            except subprocess.TimeoutExpired:
                raise ValueError(f'emulator timed out after {args.timeout}s') from None
        sys.stdout.write((case / 'emulator.log').read_text(errors='replace'))
        if completed.returncode != 0:
            raise ValueError(f'emulator exited {completed.returncode}')
        record['assertions'] = audit(out, name, rom_md5)
        record['status'] = 'passed'
        return 0
    except (ValueError, OSError, subprocess.SubprocessError, SystemExit) as exc:
        record['reason'] = str(exc)
        print(f'CASE FAILED: {exc}', file=sys.stderr)
        return 1
    finally:
        record['elapsed_seconds'] = round(time.monotonic() - start, 3)
        (case / 'result.json').write_text(json.dumps(record, indent=2) + '\n')
        print(f'case-result: {record["status"]} {name} assertions={record["assertions"]} elapsed={record["elapsed_seconds"]}s', flush=True)


def read_inventory():
    rows = list(csv.DictReader((HERE / 'cases.tsv').open(), delimiter='\t'))
    names = [row['name'] for row in rows]
    suites = [row['suite'] for row in rows]
    if len(names) != len(set(names)) or len(suites) != len(set(suites)) or not names:
        raise ValueError('canonical case names and suite paths must be nonempty and unique')
    helpers = {'lib.lua', 'mgba_shim.lua', 'symbols.lua', 'SaveHarvest.lua'}
    discovered = {'lua/' + p.name for p in (HERE / 'lua').glob('*.lua') if p.name not in helpers}
    if set(suites) != discovered:
        raise ValueError(f'canonical inventory mismatch: unclassified={sorted(discovered - set(suites))}; missing={sorted(set(suites) - discovered)}')
    if any(r['scope'] not in {'required', 'manual'} or r['smoke'] not in {'0', '1'} for r in rows):
        raise ValueError('invalid canonical scope or smoke membership')
    required_smoke = {'SmokeBoot', 'WorldTitle', 'StoryProgress', 'RegionalTravelMigration'}
    if {r['name'] for r in rows if r['smoke'] == '1' and r['scope'] == 'required'} != required_smoke:
        raise ValueError('canonical smoke selection changed')
    fixtures = {
        'RegionalTravelMigration': 'lua/fixtures/v10regionaldirty.srm',
        'VerifyV7Migrate': 'lua/fixtures/v7dirty.srm',
        'MigrateFixtures': 'lua/fixtures/v3.srm',
        'VerifyMapRenumber': 'lua/fixtures/v7renumber.srm',
        'FamilyOptionsMigration': 'generated:family-options/v11-hard.srm',
    }
    by_name = {r['name']: r for r in rows}
    for name, fixture in fixtures.items():
        if name not in by_name or by_name[name]['scope'] != 'required' or by_name[name]['fixture'] != fixture:
            raise ValueError(f'required fixture mapping changed: {name} -> {fixture}')
    return rows


def inventory(profile, out, excluded=False):
    rows = read_inventory()
    selected = [r for r in rows if r['scope'] == 'required' and (profile == 'full' or r['smoke'] == '1')]
    if excluded:
        print(','.join(r['name'] for r in rows if r not in selected))
        return
    generated = Path(out) / 'family-options'
    if any(r['fixture'].startswith('generated:') for r in selected):
        subprocess.run([sys.executable, str(HERE / 'MakeFamilyOptionsFixtures.py'), '--output', str(generated)], check=True, stdout=sys.stderr)
    for row in selected:
        suite = HERE / row['suite']
        if not suite.is_file() or row['name'] == 'VerifyOwnerSave':
            raise ValueError(f'invalid canonical suite: {row["name"]}')
        fixture = row['fixture']
        if fixture == 'fresh':
            path = '-'
        elif fixture == 'generated:family-options/v11-hard.srm':
            path = generated / 'v11-hard.srm'
        elif fixture.startswith('generated:'):
            raise ValueError(f'unknown fixture generator: {fixture}')
        else:
            path = HERE / fixture
        if path != '-':
            check_fixture(path)
        print(f'{row["name"]}\t{suite}\t{path}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    bundle = commands.add_parser('bundle')
    bundle.add_argument('--rom', required=True); bundle.add_argument('--elf', required=True)
    bundle.add_argument('--symbols'); bundle.add_argument('--out', required=True)
    inv = commands.add_parser('inventory')
    inv.add_argument('--profile', choices=('smoke', 'full'), default='full'); inv.add_argument('--out', required=True)
    inv.add_argument('--excluded', action='store_true')
    run = commands.add_parser('run')
    run.add_argument('suite'); run.add_argument('rom', nargs='?', default=str(ROOT / 'pokemonworld.gba')); run.add_argument('save', nargs='?')
    run.add_argument('--elf', default=os.environ.get('PW_ELF')); run.add_argument('--symbols', default=os.environ.get('PW_SYMBOLS'))
    run.add_argument('--bundle'); run.add_argument('--out', default=os.environ.get('PW_OUT', str(ROOT / '_pwtest')))
    run.add_argument('--timeout', type=float, default=300); run.add_argument('--rtc', type=int, default=1704110400)
    run.add_argument('--case-name'); run.add_argument('--env', action='append', default=[]); run.add_argument('--emulator')
    args = parser.parse_args()
    try:
        if args.command == 'bundle':
            make_bundle(args.rom, args.elf, args.out, args.symbols)
        elif args.command == 'inventory':
            inventory(args.profile, args.out, args.excluded)
        else:
            if args.timeout <= 0:
                raise ValueError('timeout must be positive')
            return run_case(args)
        return 0
    except (ValueError, OSError, subprocess.SubprocessError) as exc:
        print(f'SETUP FAILED: {exc}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
