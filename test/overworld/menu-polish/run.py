#!/usr/bin/env python3
"""Build an isolated synthetic fixture and measure menu transitions/rendering."""
import argparse
import os
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--out', type=Path, required=True)
args = parser.parse_args()
repo = Path(__file__).resolve().parents[3]
fixture = args.out.resolve() / 'fixture'

def run(*command, env=None):
    subprocess.run([str(arg) for arg in command], check=True, env=env)

run('python3', repo / 'test/overworld/visual-features/build_fixture.py',
    '--repo', repo, '--rom', repo / 'pokemonworld.gba', '--elf', repo / 'pokemonworld.elf',
    '--out', fixture, '--source', repo / 'test/overworld/world-menu-theme/fixture.c')
symbols = subprocess.check_output([
    '/opt/devkitpro/devkitARM/bin/arm-none-eabi-nm', str(repo / 'pokemonworld.elf')], text=True)
names = ['gPlttBufferFaded', 'CB2_ContinueSavedGame', 'CB2_NewGameScene', 'CB2_InitOptionMenu']
resolved = {name: next(line.split()[0] for line in symbols.splitlines() if line.endswith(' ' + name))
            for name in names}
(fixture / 'lua/menu_symbols.lua').write_text(
    'return {' + ','.join(f'{name}=0x{address}' for name, address in resolved.items()) + '}\n')
for selection in range(3):
    run('python3', repo / 'test/overworld/visual-features/run_fixture.py', '--repo', repo,
        '--fixture', fixture, '--suite', Path(__file__).with_name('transitions.lua'),
        '--out', args.out / f'selection-{selection}',
        env={**os.environ, 'PW_MENU_SELECTION': str(selection)})
run('python3', repo / 'test/overworld/visual-features/run_fixture.py', '--repo', repo,
    '--fixture', fixture, '--suite', Path(__file__).with_name('visuals.lua'),
    '--out', args.out / 'visuals')
