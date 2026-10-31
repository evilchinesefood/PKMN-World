#!/usr/bin/env python3
"""Export ELF symbols, C constants and map ids for the Johto playthrough harness.

    export.py <out_dir>    -> <out_dir>/pwsym.lua, pwconst.lua, pwmaps.lua

Everything is read from the build being tested (pokemonworld.elf and the headers it was built
from), so no address or constant is copied from another build.
"""
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
NM = '/opt/devkitpro/devkitARM/bin/arm-none-eabi-nm'
out = Path(sys.argv[1]).resolve()
out.mkdir(parents=True, exist_ok=True)

syms = {}
for line in subprocess.check_output([NM, str(ROOT / 'pokemonworld.elf')], text=True).splitlines():
    p = line.split()
    if len(p) == 3 and re.fullmatch(r'[A-Za-z_]\w*', p[2]):
        syms[p[2]] = int(p[0], 16)
(out / 'pwsym.lua').write_text('return {\n' + ''.join(
    f'{k}=0x{v:x},\n' for k, v in sorted(syms.items())) + '}\n')

HEADERS = ['constants/flags.h', 'constants/vars.h', 'constants/items.h', 'constants/species.h',
           'constants/moves.h', 'constants/metatile_behaviors.h', 'constants/opponents.h',
           'constants/event_objects.h', 'constants/battle.h', 'constants/pokemon.h', 'constants/global.h', 'constants/field_specials.h']
PREFIX = r'(?:FLAG|VAR|ITEM|SPECIES|MOVE|MB|TRAINER|OBJ_EVENT_GFX|BATTLE_TYPE|B_OUTCOME|TYPE|PLAYER_AVATAR_FLAG|COLLISION|DIR)_\w+'
names = set()
scan, seen = list(HEADERS), set()
while scan:
    h = scan.pop()
    if h in seen or not (ROOT / 'include' / h).exists():
        continue
    seen.add(h)
    text = (ROOT / 'include' / h).read_text(errors='replace')
    scan += re.findall(r'#include "(constants/\w+\.h)"', text)
    names.update(re.findall(r'^\s*#define\s+(' + PREFIX + r')\b(?!\()', text, re.M))
    names.update(re.findall(r'^\s*(' + PREFIX + r')\s*(?:=|,)', text, re.M))
src = ['#include <stdio.h>', '#include <stdint.h>', '#include <limits.h>', '#include "constants/pokemon.h"', '#include "gba/types.h"', '#include "constants/global.h"'] + [f'#include "{h}"' for h in HEADERS + sorted(seen - set(HEADERS))]
src.append('int main(void){')
src += [f'printf("{n}=%ld\\n",(long)({n}));' for n in sorted(names)]
src.append('return 0;}')
def build(src, td):
    c, exe = Path(td) / 'c.c', Path(td) / 'c'
    c.write_text('\n'.join(src))
    return exe, subprocess.run(['cc', '-w', '-std=gnu17', '-I', str(ROOT / 'include'), '-I', str(ROOT / 'gflib'),
                                '-DALL_REGIONS=1', '-DMODERN=1', '-ferror-limit=0', '-o', str(exe), str(c)],
                               capture_output=True, text=True)


with tempfile.TemporaryDirectory() as td:
    for _ in range(6):
        exe, r = build(src, td)
        if r.returncode == 0:
            break
        # Drop the printf lines the host compiler cannot evaluate (names that are not integer
        # constants on this host), then retry.
        lines = {int(n) for n in re.findall(r'c\.c:(\d+):\d+: error', r.stderr)}
        if not lines:
            sys.exit(r.stderr[:4000])
        src = [l for i, l in enumerate(src, 1) if i not in lines or not l.startswith('printf')]
    else:
        sys.exit(r.stderr[:4000])
    vals = subprocess.check_output([str(exe)], text=True)
(out / 'pwconst.lua').write_text('return {\n' + ''.join(
    f'{l.strip()},\n' for l in vals.splitlines() if l.strip()) + '}\n')

groups = json.loads((ROOT / 'data/maps/map_groups.json').read_text())
rows = []
for gi, g in enumerate(groups['group_order']):
    for mi, name in enumerate(groups[g]):
        rows.append(f'{name}={{g={gi},m={mi}}},')
(out / 'pwmaps.lua').write_text('return {\n' + '\n'.join(rows) + '\n}\n')
print(f'{len(syms)} symbols, {len(vals.splitlines())} constants, {len(rows)} maps -> {out}')

# Struct offsets, compiled with the ROM's own ABI (-mabi=apcs-gnu is load-bearing: without it
# every SaveBlock1 offset comes out 40 bytes low and still looks plausible).
GCC = '/opt/devkitpro/devkitARM/bin/arm-none-eabi-gcc'
with tempfile.TemporaryDirectory() as td:
    obj = Path(td) / 'o.o'
    subprocess.run([GCC, '-c', '-iquote', 'include', '-iquote', 'gflib', '-std=gnu17', '-DMODERN=1', '-DTESTING=0',
                    '-DEMERALD', '-DALL_REGIONS=1', '-Wno-trigraphs', '-mthumb', '-mthumb-interwork', '-O2',
                    '-mabi=apcs-gnu', '-mtune=arm7tdmi', '-march=armv4t', '-o', str(obj),
                    str(Path(__file__).with_name('offsets.c'))], cwd=ROOT, check=True)
    offs = {}
    for line in subprocess.check_output([NM, '-S', str(obj)], text=True).splitlines():
        p = line.split()
        if len(p) == 4 and p[3].startswith('p_'):
            offs[p[3][2:]] = int(p[1], 16) - 1
# Calibrate against the offsets src/load_save.c pins with STATIC_ASSERTs.
assert (offs['sb1_flags'], offs['sb1_vars'], offs['sb1_money']) == (5524, 6042, 1168), offs
(out / 'pwoff.lua').write_text('return {\n' + ''.join(f'{k}={v},\n' for k, v in sorted(offs.items())) + '}\n')
print('offsets:', offs)

# Charmap for decoding on-screen text (gStringVar4) in logs and prompt policies.
chars = {}
for line in (ROOT / 'charmap.txt').read_text(errors='replace').splitlines():
    m = re.match(r"^'(.+?)'\s*=\s*([0-9A-Fa-f]{2})\s*$", line)
    if m:
        ch = m.group(1).replace('\\', '\\\\').replace('"', '\\"')
        chars.setdefault(int(m.group(2), 16), ch)
(out / 'pwchar.lua').write_text('return {\n' + ''.join(
    f'[{k}]="{v}",\n' for k, v in sorted(chars.items())) + '}\n')
