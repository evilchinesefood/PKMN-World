#!/usr/bin/env python3
"""Run collection behavior checks against a fixture linked to the input ROM."""
import argparse
from pathlib import Path
import shutil
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
        '--rom', args.rom, '--elf', args.elf, '--source', HERE / 'mechanics_fixture.c', '--out', fixture)
    nm = shutil.which('arm-none-eabi-nm') or '/opt/devkitpro/devkitARM/bin/arm-none-eabi-nm'
    symbols = {}
    for line in subprocess.check_output([nm, '-S', str(args.elf)], text=True).splitlines():
        fields = line.split()
        if len(fields) == 4:
            symbols[fields[3]] = int(fields[0], 16)
    names = ('gSpecialVar_0x8006', 'gSpecialVar_0x8007', 'GetRelearnerLevelUpMoves')
    (fixture / 'lua/mechanics_symbols.lua').write_text('return {' + ','.join(
        f'{name}=0x{symbols[name]:X}' for name in names) + '}\n')
    run('python3', HERE / '../visual-features/run_fixture.py', '--repo', ROOT,
        '--fixture', fixture, '--suite', HERE / 'mechanics.lua', '--out', args.out / 'run',
        '--case-name', 'SpecialPokemonMechanics')


if __name__ == '__main__':
    main()
