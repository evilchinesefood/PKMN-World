#!/usr/bin/env python3
"""Build an isolated fixture and navigate the production checklist and Forms UI."""
import argparse
from pathlib import Path
import subprocess
import ui_export

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rom', type=Path, required=True)
    parser.add_argument('--elf', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    fixture = args.out / 'fixture'
    subprocess.run(['python3', str(HERE / '../visual-features/build_fixture.py'),
                    '--repo', str(ROOT), '--rom', str(args.rom), '--elf', str(args.elf),
                    '--source', str(HERE / 'ui_fixture.c'), '--out', str(fixture)], check=True)
    ui_export.export(args.elf, fixture / 'lua/ui_symbols.lua')
    subprocess.run(['python3', str(HERE / '../visual-features/run_fixture.py'),
                    '--repo', str(ROOT), '--fixture', str(fixture), '--suite', str(HERE / 'ui.lua'),
                    '--case-name', 'SpecialPokemonUI', '--out', str(args.out / 'run')], check=True)


if __name__ == '__main__':
    main()
