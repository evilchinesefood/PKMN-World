#!/usr/bin/env python3
"""Reproducible, isolated study ROMs; never writes the input repository or ROM.
Requires its matching ELF, Pillow, devkitARM, and repo's built gbagfx tool.
"""
import argparse,hashlib,json,re,subprocess
from pathlib import Path
from PIL import Image
p=argparse.ArgumentParser();p.add_argument('--repo',type=Path,required=True);p.add_argument('--rom',type=Path,required=True);p.add_argument('--elf',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
root=Path(__file__).resolve().parent;prefix='/opt/devkitpro/devkitARM/bin/arm-none-eabi-'
def run(c):return subprocess.check_output([str(x) for x in c],text=True)
nm=run([prefix+'nm','-S',a.elf]);syms={m[3]:(int(m[0],16),int(m[1],16)) for l in nm.splitlines() if len(m:=l.split())==4}
rom=a.rom.read_bytes();original=rom
sha=lambda b:hashlib.sha256(b).hexdigest()
manifest={'base_commit':run(['git','-C',a.repo,'rev-parse','HEAD']).strip(),'input_sha256':sha(rom),'glyph_bytes':64,'changes':[],'roms':{}}
fontsrc=(a.repo/'src/fonts.c').read_text()
variants=[('Short','latin_short','latin_frlg_nums'),('ShortNarrow','latin_short_narrow','latin_frlg_nums_narrow'),('ShortNarrower','latin_short_narrower','latin_frlg_nums_narrower')]
fonts=[]
for name,current,donor in variants:
 src=a.repo/f'graphics/fonts/{current}.png';don=a.repo/f'graphics/fonts/{donor}.png'
 for f in [src,don]:
  im=Image.open(f);assert im.mode=='P' and im.size==(256,512)
  # Latfont carries indexed roles, not RGB. The first four roles match exactly.
  assert im.getpalette()[:12]==[144,200,255,56,56,56,216,216,216,255,255,255]
 base=a.out/(current+'.latfont');new=a.out/(donor+'.latfont')
 run([a.repo/'tools/gbagfx/gbagfx',src,base]);run([a.repo/'tools/gbagfx/gbagfx',don,new])
 b,d=base.read_bytes(),new.read_bytes();addr,size=syms[f'gFont{name}LatinGlyphs'];off=addr-0x08000000
 assert len(b)==size==32768 and rom[off:off+size]==b,'Input ROM/ELF/source mismatch'
 widths=list(map(int,re.findall(r'\d+',re.sub(r'//[^\n]*','',re.search(r'gFont'+name+r'LatinGlyphWidths\[\] = \{(.*?)\};',fontsrc,re.S).group(1)))))
 widthaddr,widthsize=syms[f'gFont{name}LatinGlyphWidths'];assert bytes(widths)==rom[widthaddr-0x08000000:widthaddr-0x08000000+widthsize]
 im=Image.open(src);di=Image.open(don)
 records=[]
 for code in list(range(0xA1,0xAB))+[0xAD,0xBA,0xF0]:
  x,y=(code%16)*16,(code//16)*16
  old=im.crop((x,y,x+16,y+16));newim=di.crop((x,y,x+16,y+16))
  def bbox(z):
   coords=[(i%16,i//16) for i,v in enumerate(z.getdata()) if v in (1,2)]
   return [min(i[0] for i in coords),min(i[1] for i in coords),max(i[0] for i in coords)+1,max(i[1] for i in coords)+1] if coords else None
  bb=bbox(newim)
  records.append({'code':hex(code),'advance':widths[code],'current_bbox':bbox(old),'candidate_bbox':bb,'changed_pixels':sum(x!=y for x,y in zip(old.getdata(),newim.getdata())),'overhang':bool(bb and bb[2]>widths[code])})
 manifest['changes'].append({'font':name,'symbol':hex(addr),'current':str(src.relative_to(a.repo)),'donor':str(don.relative_to(a.repo)),'glyphs':records})
 fonts.append((off,b,d))
# Link a fixture callback into FF padding. The exact same hook is in both captures.
obj=a.out/'study_hook.o';exe=a.out/'study_hook.elf';binary=a.out/'study_hook.bin';hookaddr=0x09F00000
run([prefix+'gcc','-mthumb','-mthumb-interwork','-mlong-calls','-march=armv4t','-mabi=apcs-gnu','-O2','-std=gnu17','-DMODERN=1','-DTESTING=0','-DEMERALD','-DALL_REGIONS=1','-iquote',a.repo/'include','-c',root/'study_hook.c','-o',obj])
run([prefix+'ld','--just-symbols='+str(a.elf),'-Ttext='+hex(hookaddr),'-e','DigitsStudyHook','-o',exe,obj])
run([prefix+'objcopy','-O','binary',exe,binary]);hook=binary.read_bytes();off=hookaddr-0x08000000
assert len(hook)<0x10000 and rom[off:off+len(hook)]==b'\xff'*len(hook)
base=bytearray(rom);base[off:off+len(hook)]=hook
hooknm=run([prefix+'nm',exe]);entry=int(next(l.split()[0] for l in hooknm.splitlines() if l.endswith(' DigitsStudyHook')),16)
manifest['fixture']={'address':hex(entry),'size':len(hook),'sha256':sha(hook),'source':'study_hook.c'}
for name,whitelist in [('baseline',[]),('digits',list(range(0xA1,0xAB))),('punctuation',list(range(0xA1,0xAB))+[0xAD,0xBA,0xF0])]:
 data=bytearray(base)
 for off,b,d in fonts:
  for code in whitelist:data[off+code*64:off+(code+1)*64]=d[code*64:(code+1)*64]
 # Verify all changes vs baseline are wholly inside the explicitly whitelisted glyphs.
 allowed={off+code*64+i for off,b,d in fonts for code in whitelist for i in range(64)}
 actual={i for i,(b,c) in enumerate(zip(base,data)) if b!=c};assert actual<=allowed
 (a.out/(name+'.gba')).write_bytes(data)
 manifest['roms'][name]={'sha256':sha(data),'md5':hashlib.md5(data).hexdigest().upper(),'changed_bytes_from_baseline':len(actual)}
 # Suite symbol addresses/struct offsets remain valid; regenerate ONLY recorded hashes.
 s=(a.repo/'Testing/lua/symbols.lua').read_text()
 s=re.sub(r'(romMD5\s*=\s*")[^"]+',r'\g<1>'+hashlib.md5(data).hexdigest().upper(),s)
 s=re.sub(r'(romSHA1\s*=\s*")[^"]+',r'\g<1>'+hashlib.sha1(data).hexdigest().upper(),s)
 dest=a.out/name;dest.mkdir(exist_ok=True);(dest/'symbols.lua').write_text(s)
 (dest/'study_symbols.lua').write_text('return {hook=0x%X,arg=0x%X,storage=0x%X}\n' % (entry|1,syms['gSpecialVar_0x8005'][0],syms['CB2_PokeStorage'][0]))
manifest['non_whitelisted_glyphs_byte_identical']=True
(a.out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps({'fixture':manifest['fixture'],'roms':manifest['roms'],'overhangs':[(c['font'],g['code'],g['advance'],g['candidate_bbox']) for c in manifest['changes'] for g in c['glyphs'] if g['overhang']]},indent=2))
