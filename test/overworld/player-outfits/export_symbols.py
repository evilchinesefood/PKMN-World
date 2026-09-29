#!/usr/bin/env python3
"""Export additional addresses from the exact input ELF, never fixed addresses."""
import argparse
from pathlib import Path
import subprocess
import re

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('elf', type=Path)
p.add_argument('out', type=Path)
a = p.parse_args()
symbols = {}
ranges = []
for line in a.elf.with_suffix('.map').read_text().splitlines():
    m = re.match(r'\s+\.\S+\s+(0x[0-9a-f]+)\s+(0x[0-9a-f]+)\s+src/battle_controller_player\.o$', line)
    if m:
        start, size = int(m[1], 16), int(m[2], 16)
        ranges.append((start, start+size))
for line in subprocess.check_output(['/opt/devkitpro/devkitARM/bin/arm-none-eabi-nm', '-S', a.elf], text=True).splitlines():
    fields = line.split()
    if len(fields) == 4:
        if fields[3] == 'HandleInputChooseAction' and not any(lo <= int(fields[0],16) < hi for lo,hi in ranges):
            continue
        symbols[fields[3]] = int(fields[0], 16)
names = ('UpdateObjectReflectionSprite', 'sOakSpeechResources', 'gBattlerSpriteIds',
         'gBattlerControllerFuncs', 'HandleInputChooseAction', 'BattleMainCB2')
a.out.parent.mkdir(parents=True, exist_ok=True)
a.out.write_text('return {' + ','.join(f'{n}=0x{symbols[n]:X}' for n in names) + '}\n')
