#!/usr/bin/env python3
"""Build the identical capture fixture against a matching baseline/current pair."""
import argparse
from pathlib import Path
import subprocess

p = argparse.ArgumentParser()
p.add_argument('--repo', type=Path, required=True)
p.add_argument('--rom', type=Path, required=True)
p.add_argument('--elf', type=Path, required=True)
p.add_argument('--out', type=Path, required=True)
a = p.parse_args()
root = Path(__file__).resolve().parent
subprocess.run(['python3', str(root.parent/'visual-features/build_fixture.py'),
                '--repo', str(a.repo), '--rom', str(a.rom), '--elf', str(a.elf),
                '--source', str(root/'fixture.c'), '--out', str(a.out)], check=True)
subprocess.run(['python3', str(root.parent/'bw-battle-ui/export_symbols.py'), str(a.elf), str(a.out)], check=True)
names = set('gPlttBufferUnfaded gTimeBlend gFieldStatuses gBattleEnvironment gBattleEnvironmentPalette_Plain sBattlePresentation sBattlePresentationCaptured'.split())
syms = {}
for line in subprocess.check_output(['/opt/devkitpro/devkitARM/bin/arm-none-eabi-nm', '-S', str(a.elf)], text=True).splitlines():
    m = line.split()
    if len(m) == 4 and m[3] in names:
        assert m[3] not in syms, m[3]
        syms[m[3]] = int(m[0], 16)
assert names - {'sBattlePresentation', 'sBattlePresentationCaptured'} <= syms.keys()
(a.out/'lua/palette_symbols.lua').write_text('return {' + ','.join(f'{n}=0x{v:X}' for n, v in sorted(syms.items())) + '}\n')
