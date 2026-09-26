#!/usr/bin/env python3
"""Build a scratch fixture and export probe addresses from its matching ELF."""
import argparse
from pathlib import Path
import subprocess

p = argparse.ArgumentParser()
p.add_argument('--repo', type=Path, required=True)
p.add_argument('--out', type=Path, required=True)
a = p.parse_args()
source = Path(__file__).resolve().parent / 'fixture.c'
subprocess.run(['python3', str(a.repo / 'Testing/visual-features/build_fixture.py'),
                '--repo', str(a.repo), '--rom', str(a.repo / 'pokemonworld.gba'),
                '--elf', str(a.repo / 'pokemonworld.elf'), '--source', str(source),
                '--out', str(a.out)], check=True)
rows = subprocess.check_output(['/opt/devkitpro/devkitARM/bin/arm-none-eabi-nm',
                                str(a.repo / 'pokemonworld.elf')], text=True)
names = {f'gSpecialVar_0x800{n:X}' for n in range(3, 12)}
values = {r[2]: int(r[0], 16) for line in rows.splitlines()
          if len(r := line.split()) == 3 and r[2] in names}
assert values.keys() == names
(a.out / 'lua/hub_symbols.lua').write_text('return {' + ','.join(
    f'{k}=0x{v:X}' for k, v in sorted(values.items())) + '}\n')
