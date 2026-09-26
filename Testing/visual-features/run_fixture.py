#!/usr/bin/env python3
"""Run only a disposable feature fixture; optionally retain its synthetic save."""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

p = argparse.ArgumentParser()
p.add_argument('--repo', type=Path, required=True)
p.add_argument('--fixture', type=Path, required=True)
p.add_argument('--suite', type=Path, required=True)
p.add_argument('--out', type=Path, required=True)
a = p.parse_args()
a.out.mkdir(parents=True, exist_ok=True)
rom = a.fixture / 'VerifyFeatures.gba'
env = os.environ.copy()
env.update(PW_SUITE=str(a.suite.resolve()), PW_FEATURE_LIB=str((a.fixture/'lua').resolve()),
           PW_OUT=str(a.out.resolve()), PW_ROM_NAME='VerifyFeatures',
           PW_ROM_HASH=hashlib.md5(rom.read_bytes()).hexdigest().upper())
mgba = env.get('MGBA_HEADLESS') or shutil.which('mgba-headless')
assert mgba, 'mgba-headless is required'
with tempfile.TemporaryDirectory(prefix='pw-visual-fixture-') as tmp:
    isolated = Path(tmp)/'VerifyFeatures.gba'
    shutil.copy2(rom, isolated)
    result = subprocess.run([mgba, '-l', '0', '--rtc', '1704110400', '--script',
                             str(a.repo/'Testing/lua/mgba_shim.lua'), str(isolated)],
                            env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, timeout=600)
    (a.out/'runner.log').write_text(result.stdout)
    print(result.stdout)
    if result.returncode == 0 and isolated.with_suffix('.sav').exists():
        shutil.copy2(isolated.with_suffix('.sav'), a.out/'VisualReview.sav')
raise SystemExit(result.returncode)
