#!/usr/bin/env python3
"""Run an explicitly selected campaign against a matching ROM/ELF pair."""
import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--campaign', choices=('johto', 'kanto', 'hoenn', 'world'), default='johto')
p.add_argument('--from', dest='frm')
p.add_argument('--to')
p.add_argument('--lose')
p.add_argument('--no-retry', action='store_true')
p.add_argument('--out', type=Path)
p.add_argument('--resume-dir', type=Path, help='read explicitly selected checkpoint from this prior case directory')
p.add_argument('--timeout', type=int, default=3600)
p.add_argument('--rtc', type=int, default=1704110400)
p.add_argument('--rom', type=Path, default=ROOT / 'pokemonworld.gba')
p.add_argument('--elf', type=Path)
p.add_argument('--symbols', type=Path)
p.add_argument('--nm')
p.add_argument('--arm-cc')
p.add_argument('--cc')
p.add_argument('--suite', help='another Lua script in this directory')
p.add_argument('--case-name', help='explicit verdict name for an additional focused suite')
p.add_argument('--natural', action='store_true')
p.add_argument('--natural-trace', action='store_true')
p.add_argument('--natural-attempts', type=int)
p.add_argument('--postgame', action='store_true')
p.add_argument('--world', choices=('A', 'B', 'J'))
p.add_argument('--postgame-only')
p.add_argument('--sevii', action='store_true')
p.add_argument('--route22', type=int, choices=(0, 1, 2))
p.add_argument('--battle-debug', action='store_true')
p.add_argument('--starter', type=int, choices=(0, 1, 2))
p.add_argument('--gender', choices=('M', 'F'))
p.add_argument('--detour')
a = p.parse_args()
if a.frm and not a.resume_dir:
    p.error('--from requires --resume-dir pointing to the previous case directory')
if a.lose is not None and any(not re.fullmatch(r'[A-Za-z0-9_]+(?::(?:trainer|wild|any|TRAINER_\w+|SPECIES_\w+))?', token) for token in a.lose.split(',')):
    p.error('--lose requires beat[:trainer|wild|any|TRAINER_name|SPECIES_name], separated by commas')
if a.lose and a.natural:
    p.error('--lose and --natural are separate verification modes')
if a.timeout <= 0 or (a.natural_attempts is not None and a.natural_attempts <= 0):
    p.error('timeouts and attempt counts must be positive')
suite = (HERE / (a.suite or 'play.lua')).resolve()
if suite.parent != HERE or not suite.is_file():
    p.error('--suite must name a Lua file in the campaign runner directory')
out = (a.out or ROOT / '_pwtest' / (a.campaign + '-play')).resolve()
out.mkdir(parents=True, exist_ok=True)
run = Path(tempfile.mkdtemp(prefix='campaign-', dir=out))
lua = run / 'lua'
selected_rom = a.rom.resolve()
selected_elf = (a.elf or selected_rom.with_suffix('.elf')).resolve()
inputs = run / 'inputs'
inputs.mkdir()
rom, elf = inputs / 'candidate.gba', inputs / 'candidate.elf'
shutil.copy2(selected_rom, rom)
shutil.copy2(selected_elf, elf)
rom.chmod(0o444)
elf.chmod(0o444)
env = {k: v for k, v in os.environ.items() if not k.startswith('PW_')}
if a.nm:
    env['ARM_NM'] = a.nm
if a.arm_cc:
    env['ARM_CC'] = a.arm_cc
export = [sys.executable, str(HERE / 'export.py'), str(lua), '--elf', str(elf)]
for name in ('nm', 'arm_cc', 'cc'):
    if getattr(a, name):
        export += ['--' + name.replace('_', '-'), getattr(a, name)]
subprocess.run(export, check=True, env=env)
settings = {'PW_PLAY_LUA': str(lua), 'PW_CAMPAIGN': a.campaign, 'PW_MAX_FRAMES': '60000000'}
for option, key in (('frm', 'FROM'), ('to', 'TO'), ('lose', 'LOSE'), ('no_retry', 'NO_RETRY'),
                    ('natural', 'NATURAL'), ('natural_trace', 'NATURAL_TRACE'),
                    ('natural_attempts', 'NATURAL_ATTEMPTS'), ('postgame', 'POSTGAME'),
                    ('world', 'WORLD'), ('postgame_only', 'PG_ONLY'), ('sevii', 'SEVII'), ('route22', 'ROUTE22'),
                    ('battle_debug', 'BATTLE_DEBUG'), ('starter', 'STARTER'), ('gender', 'GENDER'), ('detour', 'DETOUR')):
    value = getattr(a, option)
    if value is not None and value is not False:
        settings['PW_' + key] = '1' if value is True else str(value)
if a.resume_dir:
    resume = a.resume_dir.resolve()
    if (resume / 'evidence').is_dir():
        resume = resume / 'evidence'
    if a.frm and not (resume / ('ckpt_' + a.frm + '.ss')).is_file():
        p.error('selected checkpoint is missing from --resume-dir')
    settings['PW_RESUME_DIR'] = str(resume)
case = a.campaign.title() + 'Play' + ('_from_' + a.frm if a.frm else '')
command = [str(ROOT / 'test/overworld/mgba-run.sh'), str(suite), str(rom),
           '--elf', str(elf), '--out', str(run), '--timeout', str(a.timeout), '--rtc', str(a.rtc)]
suite_names = {
    'kurt_fast_ball.lua': 'JohtoKurtFastBall',
    'national_park_soothe_bell.lua': 'NationalParkSootheBell',
    'text_printer_heap.lua': 'TextPrinterHeap',
}
command += ['--case-name', a.case_name or (case if suite.name == 'play.lua' else suite_names.get(suite.name, suite.stem))]
if a.symbols:
    command += ['--symbols', str(a.symbols.resolve())]
for key, value in settings.items():
    command += ['--env', key + '=' + value]
print('campaign exports:', lua, flush=True)
raise SystemExit(subprocess.run(command, cwd=ROOT, env=env).returncode)
