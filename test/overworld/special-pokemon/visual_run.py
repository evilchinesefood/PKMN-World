#!/usr/bin/env python3
"""Capture collection art through production screens on an isolated test ROM."""
import argparse
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent


def run(*args):
    subprocess.run([str(arg) for arg in args], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rom', type=Path, required=True)
    parser.add_argument('--elf', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    fixture = args.out / 'fixture'
    run('python3', HERE / '../visual-features/build_fixture.py', '--repo', ROOT,
        '--rom', args.rom, '--elf', args.elf, '--source', HERE / 'visual_fixture.c', '--out', fixture)
    ranges = []
    for line in args.elf.with_suffix('.map').read_text().splitlines():
        match = re.match(r'\s+\.\S+\s+(0x[0-9a-f]+)\s+(0x[0-9a-f]+)\s+src/battle_controller_player\.o$', line)
        if match:
            start, size = (int(value, 16) for value in match.groups())
            ranges.append((start, start + size))
    symbols = {}
    for line in subprocess.check_output(['/opt/devkitpro/devkitARM/bin/arm-none-eabi-nm', '-S', args.elf], text=True).splitlines():
        fields = line.split()
        if len(fields) != 4:
            continue
        address = int(fields[0], 16)
        if fields[3] == 'HandleInputChooseAction' and not any(lo <= address < hi for lo, hi in ranges):
            continue
        symbols[fields[3]] = address
    names = ('gBattlerSpriteIds', 'gBattlerControllerFuncs', 'HandleInputChooseAction', 'BattleMainCB2')
    (fixture / 'lua/visual_symbols.lua').write_text('return {' + ','.join(
        f'{name}=0x{symbols[name]:X}' for name in names) + '}\n')
    run('python3', HERE / '../visual-features/run_fixture.py', '--repo', ROOT,
        '--fixture', fixture, '--suite', HERE / 'visual.lua', '--out', args.out / 'run',
        '--case-name', 'SpecialPokemonVisuals', '--timeout', '900')


if __name__ == '__main__':
    main()
