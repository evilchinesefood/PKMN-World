#!/usr/bin/env python3
"""Build capture fixture and enumerate every compiled objective for layout tests."""
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('--out', type=Path, required=True)
p.add_argument('--rom', type=Path)
p.add_argument('--elf', type=Path)
a = p.parse_args()
root = Path(__file__).resolve().parents[3]
here = Path(__file__).resolve().parent
rom_path = a.rom or root/'pokemonworld.gba'
elf_path = a.elf or root/'pokemonworld.elf'
nm = '/opt/devkitpro/devkitARM/bin/arm-none-eabi-nm'
subprocess.run(['python3', str(root/'test/overworld/visual-features/build_fixture.py'),
                '--repo', str(root), '--rom', str(rom_path),
                '--elf', str(elf_path), '--out', str(a.out),
                '--source', str(here/'fixture.c')], check=True)
symbols = {}
for line in subprocess.check_output([nm, '-S', str(elf_path)], text=True).splitlines():
    fields = line.split()
    if len(fields) == 4:
        symbols[fields[3]] = (int(fields[0], 16), int(fields[1], 16))
names = ['CB2_Story', 'sStoryRegion', 'sStoryPage', 'sStoryDetail', 'sStoryProgress',
         'sNumStartMenuActions', 'sStartMenuCursorPos', 'sStartMenuScrollOffset',
         'sCurrentStartMenuActions', 'sStartMenuWindowId',
         'sUsmMemory', 'sStoryWindows', 'gSpecialVar_0x8005', 'gSpecialVar_0x8008', 'gSpecialVar_0x8009']
fixture = subprocess.check_output([nm, str(a.out/'fixture.elf')], text=True)
hook = int(next(l.split()[0] for l in fixture.splitlines() if l.endswith(' VisualFeatureFixture')), 16) | 1
lua = 'return {hook=0x%X,' % hook
lua += ','.join(f'{name}=0x{symbols[name][0]:X}' for name in names)
lua += '}\n'
(a.out/'lua/story_symbols.lua').write_text(lua)
rom = rom_path.read_bytes()
objectives = []
sources = [root/'src/story_progress.c', *sorted((root/'src/data/story_progress').glob('*.inc'))]
for source in sources:
    for name in re.findall(r'STORY_OBJECTIVE\(\s*(s\w+)', source.read_text()):
        addr, size = symbols[name]
        assert size == 24, (name, size)
        offset = addr - 0x08000000
        pointers = [int.from_bytes(rom[offset+i:offset+i+4], 'little') for i in range(0,24,4)]
        texts = pointers[1:]
        for text in texts:
            end = rom.index(b'\xff', text-0x08000000)
            encoded = rom[text-0x08000000:end]
            assert encoded.count(b'\xfe') <= 2, (name, 'more than three lines')
            assert all(c < 0xf7 or c in (0xf9,0xfe) for c in encoded), (name, 'unexpected dynamic/control text')
        id_offset = pointers[0]-0x08000000
        objective_id = rom[id_offset:rom.index(b'\0', id_offset)].decode()
        objectives.append({'id': objective_id, 'texts': texts})
(a.out/'objectives.json').write_text(json.dumps(objectives, indent=2)+'\n')
(a.out/'lua/story_texts.lua').write_text('return {' + ','.join(
    '{id='+json.dumps(o['id'])+',texts={'+','.join(hex(x) for x in o['texts'])+'}}' for o in objectives) + '}\n')
print(f'{len(objectives)} compiled objectives ready for font/layout checks')
manifest_path = a.out/'manifest.json'
manifest = json.loads(manifest_path.read_text())
production = [root/'include/story_progress.h', *sources,
              root/'src/story_progress_menu.c', root/'src/start_menu.c',
              root/'src/unbound_start_menu.c']
manifest['production_sources_sha256'] = {
    str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest()
    for path in production
}
manifest['input_elf_sha256'] = hashlib.sha256(elf_path.read_bytes()).hexdigest()
manifest['capture_suite_sha256'] = hashlib.sha256((here/'capture.lua').read_bytes()).hexdigest()
manifest['objective_count'] = len(objectives)
manifest['text_field_count'] = len(objectives) * 5
manifest_path.write_text(json.dumps(manifest, indent=2)+'\n')
