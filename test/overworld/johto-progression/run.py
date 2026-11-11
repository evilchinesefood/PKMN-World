#!/usr/bin/env python3
"""Run #357 against the built production ROM with isolated saves and fresh evidence."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import re
import tempfile

ROOT = Path(__file__).resolve().parents[3]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--out', type=Path, default=ROOT / '_pwtest/357-final')
a = p.parse_args()
a.out.mkdir(parents=True, exist_ok=True)
out = Path(tempfile.mkdtemp(prefix='progression-', dir=a.out.resolve()))
print('progression-dir:', out, flush=True)
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
    case = {'playthrough': 'JohtoProgression357', 'nickname': 'JohtoNicknameAudit',
            'mom': 'JohtoMom357', 'defeat': 'JohtoDefeat357'}[suite]
    command = [str(ROOT / 'test/overworld/mgba-run.sh'),
               str(Path(__file__).with_name(suite + '.lua')), str(rom),
               '--out', str(dest), '--case-name', case,
               '--env', 'PW_357_SYMBOLS=' + str(controls / 'lua/bw_symbols.lua')]
    if gender is not None:
        command += ['--env', 'PW_357_GENDER=' + str(gender)]
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    (out / (name + '.log')).write_text(result.stdout + result.stderr)
    match = re.search(r'^case-dir: (.+)$', result.stdout, re.M)
    record = json.loads((Path(match[1]) / 'result.json').read_text()) if match else {}
    passed = result.returncode == 0 and record.get('status') == 'passed'
    print(f'{name}: {"PASS" if passed else "FAIL"}', flush=True)
    results.append({'suite': name, 'passed': passed, 'exit_code': result.returncode,
                    'case_result': record, 'case_dir': match[1] if match else None})

# The wider core loop seeds a party/balls in a disposable copy; the production
# ROM remains untouched. Its distinct ROM hash must stamp its own sentinel.
fixture = out / 'battle-fixture'
dest = out / 'core-loop'
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
with (out / 'core-loop-command.log').open('w') as log:
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
