#!/usr/bin/env python3
"""Run every isolated BW integration suite and require fresh, matching-ROM passes."""
import argparse
import concurrent.futures
import hashlib
import json
import re
import subprocess
from pathlib import Path

SUITES = ('capture', 'preview', 'healthbox', 'gimmicks', 'catching', 'bagthrow',
          'shared', 'palettes', 'pressure', 'flows', 'turns', 'regression', 'save', 'motion')
p = argparse.ArgumentParser()
p.add_argument('--repo', type=Path, required=True)
p.add_argument('--fixture', type=Path, required=True)
p.add_argument('--out', type=Path, required=True)
a = p.parse_args()
a.out.mkdir(parents=True, exist_ok=True)
rom_md5 = hashlib.md5((a.fixture / 'VerifyFeatures.gba').read_bytes()).hexdigest().upper()

def run(name):
    dest = a.out / name
    dest.mkdir(exist_ok=True)
    for pattern in ('*.PASS', '*.FAIL'):
        for f in dest.glob(pattern):
            f.unlink()
    result = subprocess.run(['python3', str(a.repo / 'Testing/visual-features/run_fixture.py'),
        '--repo', str(a.repo), '--fixture', str(a.fixture), '--suite',
        str(a.repo / 'Testing/bw-battle-ui' / (name + '.lua')), '--out', str(dest)],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    (dest / 'command.log').write_text(result.stdout)
    matches = re.findall(r'VERDICT \S+: (\d+)/(\d+) (PASS|FAIL)', result.stdout)
    passed, total, verdict = matches[-1] if matches else ('0', '0', 'NO VERDICT')
    sentinels = list(dest.glob('*.PASS'))
    fresh = len(sentinels) == 1 and ('rom=' + rom_md5) in sentinels[0].read_text()
    ok = result.returncode == 0 and verdict == 'PASS' and fresh and not list(dest.glob('*.FAIL'))
    print(f'{name}: {passed}/{total} {"PASS" if ok else "FAIL"}', flush=True)
    return {'suite': name, 'passed': int(passed), 'total': int(total), 'ok': ok,
            'exit_code': result.returncode, 'fresh_matching_sentinel': fresh}

with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
    results = list(pool.map(run, SUITES))
report = {'fixture_md5': rom_md5, 'suites': results,
          'passed': sum(r['passed'] for r in results),
          'total': sum(r['total'] for r in results)}
(a.out / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
raise SystemExit(0 if all(r['ok'] for r in results) else 1)
