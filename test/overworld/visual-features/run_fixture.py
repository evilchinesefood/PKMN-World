#!/usr/bin/env python3
"""Run an intentionally patched fixture with immutable symbols and a fresh verdict."""
import argparse
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

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from NativeRunner import audit


def claim_output(out):
    out.mkdir(parents=True, exist_ok=True)
    if any(out.iterdir()):
        raise ValueError(f'output must be fresh and empty: {out}')
    with (out / '.run-owner').open('x') as claim:
        claim.write(str(os.getpid()) + '\n')


def case_name(suite, settings):
    text = suite.read_text()
    match = re.search(r"(?:\.new\(\s*(?:S\s*,\s*)?|require\(['\"][^'\"]+helpers['\"]\)\()['\"]([A-Za-z0-9_]+)['\"]\s*(?:\.\.\s*(\w+))?\s*\)", text)
    if not match:
        raise ValueError(f'cannot infer verdict name for {suite}; pass --case-name')
    name, variable = match.groups()
    if variable:
        selected = re.search(r'local\s+' + re.escape(variable) + r'''\s*=\s*tonumber\(os.getenv\(['"](PW_\w+)['"]\)\s*or\s*['"]([^'"]+)['"]\)''', text)
        if not selected:
            raise ValueError(f'dynamic verdict name needs --case-name: {suite}')
        name += settings.get(selected[1], selected[2])
    return name


def settings_from_args(values):
    settings = {}
    reserved = {'PW_SUITE', 'PW_OUT', 'PW_ROM_NAME', 'PW_ROM_HASH', 'PW_SYMBOLS', 'PW_FEATURE_LIB', 'PW_SAVE'}
    for setting in values:
        key, sep, value = setting.partition('=')
        if not sep or not re.fullmatch(r'PW_[A-Z0-9_]+', key) or key in reserved:
            raise ValueError(f'invalid fixture setting: {key}')
        settings[key] = value
    return settings


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--repo', type=Path, required=True)
    p.add_argument('--fixture', type=Path, required=True)
    p.add_argument('--suite', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--case-name')
    p.add_argument('--env', action='append', default=[])
    p.add_argument('--timeout', type=float, default=600)
    a = p.parse_args()
    out = a.out.resolve()
    settings = settings_from_args(a.env)
    name = a.case_name or case_name(a.suite, settings)
    if not re.fullmatch(r'[A-Za-z0-9_-]+', name) or a.timeout <= 0:
        raise ValueError('case name and timeout must be valid')
    claim_output(out)
    start = time.monotonic()
    record = {'case': name, 'status': 'failed', 'assertions': 0, 'settings': settings}
    try:
        manifest = json.loads((a.fixture / 'manifest.json').read_text())
        with tempfile.TemporaryDirectory(prefix='pw-visual-fixture-') as tmp:
            work = Path(tmp)
            rom = work / 'VerifyFeatures.gba'
            shutil.copy2(a.fixture / 'VerifyFeatures.gba', rom)
            shutil.copytree(a.fixture / 'lua', work / 'lua')
            sha = hashlib.sha256(rom.read_bytes()).hexdigest()
            symbols = work / 'lua/symbols.lua'
            if sha != manifest['fixture_rom_sha256']:
                raise ValueError('fixture ROM does not match its build manifest')
            if hashlib.sha256(symbols.read_bytes()).hexdigest() != manifest.get('symbols_sha256'):
                raise ValueError('fixture symbols do not match their manifest; rebuild the fixture')
            md5 = hashlib.md5(rom.read_bytes()).hexdigest().upper()
            if not re.search(r'romMD5\s*=\s*"' + md5 + '"', symbols.read_text(), re.I):
                raise ValueError('fixture symbols are bound to another ROM')
            env = {k: v for k, v in os.environ.items() if not k.startswith('PW_')}
            env.update(settings)
            env.update(PW_SUITE=str(a.suite.resolve()), PW_FEATURE_LIB=str(work / 'lua'), PW_SYMBOLS=str(symbols), PW_OUT=str(out), PW_ROM_NAME='VerifyFeatures', PW_ROM_HASH=md5)
            mgba = env.get('MGBA_HEADLESS') or shutil.which('mgba-headless')
            if not mgba:
                raise ValueError('mgba-headless is required')
            record.update(rom_md5=md5, fixture_sha256=sha, symbols_sha256=manifest['symbols_sha256'])
            command = [mgba, '-l', '0', '--rtc', '1704110400', '--script', str(a.repo / 'test/overworld/lua/mgba_shim.lua'), str(rom)]
            with (out / 'runner.log').open('w') as log:
                result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=a.timeout)
            print((out / 'runner.log').read_text(errors='replace'))
            if result.returncode:
                raise ValueError(f'emulator exited {result.returncode}')
            record['assertions'] = audit(out, name, md5)
            if rom.with_suffix('.sav').exists():
                save = rom.with_suffix('.sav').read_bytes()
                if len(save) not in (131072, 131088):
                    raise ValueError('unexpected synthetic save size')
                (out / 'VisualReview.sav').write_bytes(save[:131072])
            record['status'] = 'passed'
        return 0
    except (ValueError, OSError, subprocess.SubprocessError) as exc:
        record['reason'] = str(exc)
        print(f'FIXTURE FAILED: {exc}', file=sys.stderr)
        return 1
    finally:
        record['elapsed_seconds'] = round(time.monotonic() - start, 3)
        (out / 'result.json').write_text(json.dumps(record, indent=2) + '\n')


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (ValueError, OSError) as exc:
        raise SystemExit(str(exc))
