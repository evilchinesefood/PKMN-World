#!/usr/bin/env python3
import argparse
import re
import subprocess
from pathlib import Path
p=argparse.ArgumentParser()
p.add_argument('--fixture',type=Path,required=True)
p.add_argument('--elf',type=Path,required=True)
p.add_argument('--out',type=Path,required=True)
a=p.parse_args()
symbols={}
for name in ('symbols.lua','feature_symbols.lua','bw_symbols.lua'):
    symbols.update({n:int(v,16) for n,v in re.findall(r'(\w+)\s*=\s*(0x[0-9A-Fa-f]+)',(a.fixture/'lua'/name).read_text())})
for line in subprocess.check_output(['/opt/devkitpro/devkitARM/bin/arm-none-eabi-nm','-S',str(a.elf)],text=True).splitlines():
    v=line.split()
    if len(v)==4 and v[3] in ('sLinkErrorBuffer','gLinkStatus','gReceivedRemoteLinkPlayers'):
        assert v[3] not in symbols, 'ambiguous symbol: '+v[3]
        symbols[v[3]]=int(v[0],16)
names='gMain CB2_Overworld gSpecialVar_0x8004 gSpecialVar_0x8005 hook BattleMainCB2 HandleInputChooseAction HandleInputChooseMove gBattlerControllerFuncs gBattleOutcome gActionSelectionCursor gBattleMons sLinkErrorBuffer gLinkStatus gReceivedRemoteLinkPlayers'.split()
a.out.write_text(''.join(f'#define PW_{n} 0x{symbols[n]:X}\n' for n in names))
