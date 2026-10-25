#!/usr/bin/env python3
"""Run #357 against the built production ROM with isolated saves and fresh evidence."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[3]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--out', type=Path, default=ROOT / '_pwtest/357-final')
a = p.parse_args()
out = a.out.resolve()
out.mkdir(parents=True, exist_ok=True)
controls = out / 'controls'
(controls / 'lua').mkdir(parents=True, exist_ok=True)
subprocess.run(['python3', str(ROOT / 'test/overworld/bw-battle-ui/export_symbols.py'),
                str(ROOT / 'pokemonworld.elf'), str(controls)], check=True)
rom = ROOT / 'pokemonworld.gba'
rom_md5 = hashlib.md5(rom.read_bytes()).hexdigest().upper()
results = []
for suite, gender in [('playthrough', None), ('nickname', None), ('mom', 0), ('mom', 1), ('defeat', 0), ('defeat', 1)]:
    name = suite if gender is None else f'{suite}-gender{gender}'
    dest = out / name
    dest.mkdir(exist_ok=True)
    for pattern in ('*.PASS', '*.FAIL'):
        for stale in dest.glob(pattern):
            stale.unlink()
    env = os.environ.copy()
    env.update(PW_OUT=str(dest), PW_357_SYMBOLS=str(controls / 'lua/bw_symbols.lua'))
    if gender is not None:
        env['PW_357_GENDER'] = str(gender)
    with (dest / 'runner.log').open('w') as log:
        result = subprocess.run([str(ROOT / 'test/overworld/mgba-run.sh'),
                                 str(Path(__file__).with_name(suite + '.lua'))],
                                cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
    sentinels = list(dest.glob('*.PASS'))
    fresh = (len(sentinels) == 1 and f'rom={rom_md5}' in sentinels[0].read_text()
             and not list(dest.glob('*.FAIL')))
    passed = result.returncode == 0 and fresh
    print(f'{name}: {"PASS" if passed else "FAIL"}', flush=True)
    results.append({'suite': name, 'passed': passed, 'exit_code': result.returncode,
                    'matching_rom_sentinel': fresh})

# The wider core loop seeds a party/balls in a disposable copy; the production
# ROM remains untouched. Its distinct ROM hash must stamp its own sentinel.
fixture = out / 'battle-fixture'
dest = out / 'core-loop'
dest.mkdir(exist_ok=True)
for pattern in ('*.PASS', '*.FAIL'):
    for stale in dest.glob(pattern):
        stale.unlink()
commands = [
    ['python3', str(ROOT / 'test/overworld/visual-features/build_fixture.py'),
     '--repo', str(ROOT), '--rom', str(rom), '--elf', str(ROOT / 'pokemonworld.elf'),
     '--out', str(fixture), '--source', str(ROOT / 'test/overworld/bw-battle-ui/fixture.c')],
    ['python3', str(ROOT / 'test/overworld/bw-battle-ui/export_symbols.py'),
     str(ROOT / 'pokemonworld.elf'), str(fixture)],
    ['python3', str(ROOT / 'test/overworld/visual-features/run_fixture.py'),
     '--repo', str(ROOT), '--fixture', str(fixture),
     '--suite', str(Path(__file__).with_name('core-loop.lua')), '--out', str(dest)],
]
with (dest / 'command.log').open('w') as log:
    for command in commands:
        result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
        if result.returncode:
            break
fixture_rom = fixture / 'VerifyFeatures.gba'
fixture_md5 = hashlib.md5(fixture_rom.read_bytes()).hexdigest().upper() if fixture_rom.exists() else ''
sentinels = list(dest.glob('*.PASS'))
fresh = (len(sentinels) == 1 and f'rom={fixture_md5}' in sentinels[0].read_text()
         and not list(dest.glob('*.FAIL')))
passed = result.returncode == 0 and fresh
print(f'core-loop: {"PASS" if passed else "FAIL"}', flush=True)
results.append({'suite': 'core-loop', 'passed': passed, 'exit_code': result.returncode,
                'matching_rom_sentinel': fresh, 'fixture_md5': fixture_md5})
report = {'base_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
          'rom_md5': rom_md5, 'rom_sha256': hashlib.sha256(rom.read_bytes()).hexdigest(),
          'heal_source_sha256': hashlib.sha256((ROOT / 'src/heal_location.c').read_bytes()).hexdigest(),
          'suites': results}
(out / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
raise SystemExit(0 if all(r['passed'] for r in results) else 1)
