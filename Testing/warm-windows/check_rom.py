#!/usr/bin/env python3
"""Prove the compiled change stays within two masks, two palettes and the stamp."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--before', type=Path, required=True)
p.add_argument('--after', type=Path, required=True)
p.add_argument('--out', type=Path, required=True)
a = p.parse_args()


def symbols(root):
    output = subprocess.check_output(['/opt/devkitpro/devkitARM/bin/arm-none-eabi-nm',
                                      '-S', str(root/'pokemonworld.elf')], text=True)
    return {v[3]: (int(v[0],16)-0x08000000, int(v[1],16))
            for line in output.splitlines() if len(v := line.split()) == 4}


before, after = [(r/'pokemonworld.gba').read_bytes() for r in (a.before,a.after)]
assert len(before) == len(after)
old, new = symbols(a.before), symbols(a.after)
ranges = {}
for name in ('gTileset_NewBarkTown', 'gTileset_CherrygroveCity',
             'gTilesetPalettes_NewBarkTown', 'gTilesetPalettes_CherrygroveCity', 'sText_BuildStamp'):
    assert old[name] == new[name], f'{name}: symbol moved; perform a fresh structural comparison'
    offset, size = new[name]
    if name.startswith('gTilesetPalettes_'):
        offset, size = offset+32, 32  # alternate row 01 only
    ranges[name] = (offset, offset+size)
changes = [i for i,(x,y) in enumerate(zip(before,after)) if x != y]
assert changes and all(any(lo<=i<hi for lo,hi in ranges.values()) for i in changes)
result = {'before_sha256':hashlib.sha256(before).hexdigest(),
          'after_sha256':hashlib.sha256(after).hexdigest(),
          'changed_bytes':len(changes), 'changes_by_symbol':{
              name:sum(lo<=i<hi for i in changes) for name,(lo,hi) in ranges.items()}}
a.out.write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
