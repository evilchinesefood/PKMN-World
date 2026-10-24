#!/usr/bin/env python3
"""Run staged Johto story and palette regressions on an isolated audit ROM."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--out', type=Path, default=ROOT / '_pwtest/357-audit')
p.add_argument('--suite', choices=['gyms', 'gyms-order2', 'gyms-order3', 'story', 'league', 'reflections'])
a = p.parse_args()
out = a.out.resolve()
fixture = out / 'fixture'
out.mkdir(parents=True, exist_ok=True)
commands = [
    ['python3', str(ROOT / 'test/overworld/visual-features/build_fixture.py'),
     '--repo', str(ROOT), '--rom', str(ROOT / 'pokemonworld.gba'),
     '--elf', str(ROOT / 'pokemonworld.elf'), '--out', str(fixture),
     '--source', str(HERE / 'audit_fixture.c')],
    ['python3', str(ROOT / 'test/overworld/bw-battle-ui/export_symbols.py'),
     str(ROOT / 'pokemonworld.elf'), str(fixture)],
    ['python3', str(HERE / 'prepare_audit.py'), str(fixture)],
]
with (out / 'build.log').open('w') as log:
    for command in commands:
        subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True)
shutil.copy2(HERE / 'audit_helpers.lua', fixture / 'lua/audit_helpers.lua')
rom = fixture / 'VerifyFeatures.gba'
md5 = hashlib.md5(rom.read_bytes()).hexdigest().upper()
results = []
for suite in ([a.suite] if a.suite else ['gyms', 'gyms-order2', 'gyms-order3', 'story', 'league', 'reflections']):
    dest = out / suite
    dest.mkdir(exist_ok=True)
    for pattern in ('*.PASS', '*.FAIL'):
        for stale in dest.glob(pattern):
            stale.unlink()
    env=os.environ.copy()
    if suite.startswith('gyms-order'):
        env['PW_AUDIT_ORDER'] = 'Pryce,Chuck,Jasmine' if suite.endswith('2') else 'Jasmine,Pryce,Chuck'
    script_suite = 'gyms' if suite.startswith('gyms') else suite
    with (dest / 'command.log').open('w') as log:
        result = subprocess.run([
            'python3', str(ROOT / 'test/overworld/visual-features/run_fixture.py'),
            '--repo', str(ROOT), '--fixture', str(fixture),
            '--suite', str(HERE / f'audit_{script_suite}.lua'), '--out', str(dest)],
            cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
    sentinels = list(dest.glob('*.PASS'))
    fresh = (len(sentinels) == 1 and f'rom={md5}' in sentinels[0].read_text()
             and not list(dest.glob('*.FAIL')))
    passed = result.returncode == 0 and fresh
    results.append({'suite': suite, 'passed': passed, 'exit_code': result.returncode,
                    'matching_rom_sentinel': fresh})
    print(f'{suite}: {"PASS" if passed else "FAIL"}', flush=True)
report = {'production_rom_sha256': hashlib.sha256((ROOT / 'pokemonworld.gba').read_bytes()).hexdigest(),
          'fixture_md5': md5, 'fixture_sha256': hashlib.sha256(rom.read_bytes()).hexdigest(),
          'fixture_manifest': json.loads((fixture / 'manifest.json').read_text()),
          'suites': results}
(out / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
raise SystemExit(0 if all(r['passed'] for r in results) else 1)
