#!/usr/bin/env python3
"""Build a disposable capture fixture, then exercise every live outfit surface."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--repo', type=Path, required=True)
p.add_argument('--rom', type=Path, required=True)
p.add_argument('--elf', type=Path, required=True)
p.add_argument('--out', type=Path, required=True)
p.add_argument('--baseline', action='store_true')
a = p.parse_args()
root = Path(__file__).resolve().parent
fixture = a.out/'fixture'
assets = a.out/'assets'
def run(*args, **kwargs):
    subprocess.run([str(x) for x in args], check=True, **kwargs)
run('python3', root/'assets.py', '--repo', a.repo, '--out', assets, *(['--baseline'] if a.baseline else []))
run('python3', root/'../visual-features/build_fixture.py', '--repo', a.repo,
    '--rom', a.rom, '--elf', a.elf, '--source', root/'fixture.c', '--out', fixture)
run('python3', root/'export_symbols.py', a.elf, fixture/'lua/outfit_symbols.lua')
shutil.copy2(assets/'outfit_expected.lua', fixture/'lua/outfit_expected.lua')
for name, suite, gender in [('surfaces','OutfitSurfaces',None),('picker0','OutfitPicker',0),('picker1','OutfitPicker',1)]:
    env = os.environ.copy()
    if gender is not None:
        env['PW_OUTFIT_GENDER'] = str(gender)
    run('python3', root/'../visual-features/run_fixture.py', '--repo', a.repo,
        '--fixture', fixture, '--suite', root/f'{suite}.lua', '--out', a.out/name, env=env)
