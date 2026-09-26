#!/usr/bin/env python3
"""Attach the same test-only entry point to a matching ROM/ELF in a scratch folder."""
import argparse,hashlib,json,re,shutil,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--repo',type=Path,required=True);p.add_argument('--rom',type=Path,required=True);p.add_argument('--elf',type=Path,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--source',type=Path);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
root=Path(__file__).resolve().parent;prefix='/opt/devkitpro/devkitARM/bin/arm-none-eabi-'
source=a.source or root/'fixture.c'
def run(c):return subprocess.check_output(list(map(str,c)),text=True)
syms={m[3]:(int(m[0],16),int(m[1],16)) for l in run([prefix+'nm','-S',a.elf]).splitlines() if len(m:=l.split())==4}
rom=bytearray(a.rom.read_bytes());before=hashlib.sha256(rom).hexdigest();addr=0x09F00000
obj=a.out/'fixture.o';elf=a.out/'fixture.elf';binary=a.out/'fixture.bin'
run([prefix+'gcc','-mthumb','-mthumb-interwork','-mlong-calls','-march=armv4t','-mabi=apcs-gnu','-O2','-std=gnu17','-Wall','-Werror','-DMODERN=1','-DTESTING=0','-DEMERALD','-DALL_REGIONS=1','-iquote',a.repo/'include','-c',source,'-o',obj])
run([prefix+'ld','--just-symbols='+str(a.elf),'-Ttext='+hex(addr),'-e','VisualFeatureFixture','-o',elf,obj]);run([prefix+'objcopy','-O','binary',elf,binary])
blob=binary.read_bytes();off=addr-0x08000000;assert len(blob)<0x10000 and rom[off:off+len(blob)]==b'\xff'*len(blob)
rom[off:off+len(blob)]=blob;(a.out/'VerifyFeatures.gba').write_bytes(rom)
entry=int(next(l.split()[0] for l in run([prefix+'nm',elf]).splitlines() if l.endswith(' VisualFeatureFixture')),16)|1
lib=a.out/'lua';lib.mkdir(exist_ok=True)
for f in (a.repo/'Testing/lua').glob('*.lua'):
 if f.name!='symbols.lua':shutil.copy2(f,lib/f.name)
s=run(['python3',a.repo/'Testing/GenLuaSymbols.py',a.elf,prefix+'nm'])
s=re.sub(r'(romMD5\s*=\s*")[^"]+',r'\g<1>'+hashlib.md5(rom).hexdigest().upper(),s)
s=re.sub(r'(romSHA1\s*=\s*")[^"]+',r'\g<1>'+hashlib.sha1(rom).hexdigest().upper(),s);(lib/'symbols.lua').write_text(s)
needed=['gSpecialVar_0x8005','sFieldRegionMapHandler','sPokedexView','SpriteCB_AmbientRipple','sAmbientRippleTemplate','gTextWindowFrame1_Pal','gTextWindowFrame1_Gfx','sSpriteTileAllocBitmap','sSpritePaletteTags','gHeap','gBattleMons','gBattleOutcome']
x={n:syms[n][0] for n in needed if n in syms};x['hook']=entry
(lib/'feature_symbols.lua').write_text('return {'+','.join(f'{n}=0x{v:X}' for n,v in x.items())+'}\n')
versioned=(a.repo/'.git').exists()
shutil.copy2(source,a.out/'capture_fixture.c')
manifest={'input_rom_sha256':before,'fixture_rom_sha256':hashlib.sha256(rom).hexdigest(),'fixture_bytes':len(blob),'fixture_source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'entry':hex(entry),'base_commit':run(['git','-C',a.repo,'rev-parse','HEAD']).strip() if versioned else 'isolated configuration copy','working_diff_sha256':hashlib.sha256(run(['git','-C',a.repo,'diff']).encode()).hexdigest() if versioned else None,'configuration':{str(p):hashlib.sha256((a.repo/p).read_bytes()).hexdigest() for p in ('include/config/name_box.h','include/config/pokedex_plus_hgss.h','include/config/overworld.h')}}
(a.out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print(json.dumps(manifest))
