#!/usr/bin/env python3
"""Run the Johto playthrough against the built ROM.

    run.py [--campaign johto|hoenn] [--from BEAT] [--to BEAT] [--out DIR] [--timeout SECONDS]

Exports symbols/constants from the matching ELF, then runs play.lua under mgba-headless. Beats
checkpoint into --out, so --from resumes after a named beat. A full evidence run omits --from.
"""
import argparse
import hashlib
import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--campaign', default='johto', help='beats from test/overworld/<campaign>-playthrough/')
p.add_argument('--from', dest='frm')
p.add_argument('--to')
p.add_argument('--out', type=Path)
p.add_argument('--timeout', type=int, default=3600)
p.add_argument('--suite', help='run another script in this directory (no checkpoints)')
a = p.parse_args()
out = (a.out or ROOT / f'_pwtest/{a.campaign}-play').resolve()
lua = out / 'lua'
subprocess.run(['python3', str(HERE / 'export.py'), str(lua)], check=True)
env = os.environ.copy()
env.update(PW_OUT=str(out), PW_PLAY_LUA=str(lua), PW_CAMPAIGN=a.campaign, PW_TIMEOUT=str(a.timeout), PW_MAX_FRAMES='60000000')
if a.frm:
    env['PW_FROM'] = a.frm
if a.to:
    env['PW_TO'] = a.to
rom = ROOT / 'pokemonworld.gba'
print('rom md5', hashlib.md5(rom.read_bytes()).hexdigest().upper())
r = subprocess.run([str(ROOT / 'test/overworld/mgba-run.sh'), str(HERE / (a.suite or 'play.lua'))], cwd=ROOT, env=env)
raise SystemExit(r.returncode)
