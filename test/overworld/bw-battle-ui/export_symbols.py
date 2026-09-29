#!/usr/bin/env python3
"""Resolve local UI symbols by their owner's linked sections, never by nm order."""
import argparse
import re
import shutil
import subprocess
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('elf', type=Path)
p.add_argument('fixture', type=Path)
a = p.parse_args()
owners = {
    'battle_controller_player': 'HandleInputChooseAction HandleInputChooseMove HandleInputChooseTarget',
    'gpu_regs': 'sGpuRegBuffer',
    'swsh_summary_screen': 'sMonSummaryScreen',
    'swsh_item_menu': 'Task_BagMenu_HandleInput',
    'swsh_party_menu': 'Task_HandleChooseMonInput',
    'egg_hatch': 'sEggHatchData CB2_EggHatch',
    'trade': 'sTradeAnim CB2_InGameTrade',
}
owner_for = {symbol: owner for owner, names in owners.items() for symbol in names.split()}
names = set(owner_for) | set('gSpecialVar_0x8005 gSpecialVar_0x8006 gSpecialVar_0x8007 gWindows gHeap gBattlerControllerFuncs gPaletteFade gBattle_BG0_Y gLastUsedBallMenuPresent gLastUsedBall gBallToDisplay gBattleStruct gBattleResources gHealthboxSpriteIds BattleMainCB2 gMoveSelectionCursor gRngValue sSpritePaletteTags sSpriteTileAllocBitmap gPartyMenu gMultiUsePlayerCursor gBattleEnvironment'.split())
ranges = {}
for line in a.elf.with_suffix('.map').read_text().splitlines():
    m = re.match(r'\s+\.\S+\s+(0x[0-9a-f]+)\s+(0x[0-9a-f]+)\s+src/(\w+)\.o$', line)
    if m and m[3] in owners:
        start, size = int(m[1], 16), int(m[2], 16)
        if start and size:
            ranges.setdefault(m[3], []).append((start, start + size))
syms = {}
for line in subprocess.check_output(['/opt/devkitpro/devkitARM/bin/arm-none-eabi-nm', '-S', str(a.elf)], text=True).splitlines():
    m = line.split()
    if len(m) != 4 or m[3] not in names:
        continue
    addr, name = int(m[0], 16), m[3]
    if name in owner_for and not any(lo <= addr < hi for lo, hi in ranges[owner_for[name]]):
        continue
    assert name not in syms, 'ambiguous symbol: ' + name
    syms[name] = addr
assert names == syms.keys(), 'missing: ' + ', '.join(sorted(names - syms.keys()))
(a.fixture / 'lua/bw_symbols.lua').write_text('return {' + ','.join(f'{n}=0x{v:X}' for n, v in sorted(syms.items())) + '}\n')
shutil.copy2(Path(__file__).with_name('helpers.lua'), a.fixture / 'lua/bw_helpers.lua')
print('Exported', len(syms), 'owner-verified screen symbols')
