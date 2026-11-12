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
objcopy = '/opt/devkitpro/devkitARM/bin/arm-none-eabi-objcopy'
raw = a.out/'production-unpadded.bin'
subprocess.run([objcopy, '-O', 'binary', str(elf_path), str(raw)], check=True)
raw_size = raw.stat().st_size
fixture_rom = (a.out/'VerifyFeatures.gba').read_bytes()
fixture_end = 0x1F00000 + (a.out/'fixture.bin').stat().st_size
extension = a.out/'fixture-extension.bin'
extension.write_bytes(fixture_rom[raw_size:fixture_end])
fixture_elf = a.out/'VerifyFeatures.elf'
subprocess.run([objcopy, '--add-section', '.story_fixture='+str(extension),
                '--set-section-flags', '.story_fixture=alloc,load,readonly,data,contents',
                '--change-section-address', '.story_fixture='+hex(0x08000000+raw_size),
                str(elf_path), str(fixture_elf)], check=True)
reconstructed = a.out/'reconstructed.gba'
subprocess.run([objcopy, '-O', 'binary', str(fixture_elf), str(reconstructed)], check=True)
subprocess.run([str(root/'tools/gbafix/gbafix'), str(reconstructed), '-p', '--silent'], check=True)
assert reconstructed.read_bytes() == fixture_rom, 'capture ROM and ELF differ'
for temporary in (raw, extension, reconstructed):
    temporary.unlink()
symbols = {}
for line in subprocess.check_output([nm, '-S', str(elf_path)], text=True).splitlines():
    fields = line.split()
    if len(fields) == 4:
        symbols[fields[3]] = (int(fields[0], 16), int(fields[1], 16))
names = ['CB2_Story', 'sStoryRegion', 'sStoryPage', 'sStoryDetail', 'sStoryProgress',
         'sNumStartMenuActions', 'sStartMenuCursorPos', 'sStartMenuScrollOffset',
         'sCurrentStartMenuActions', 'sStartMenuWindowId',
         'sUsmMemory', 'sStoryWindows', 'sWarpDestination', 'sSpriteTileAllocBitmap', 'sSpritePaletteTags',
         'sDetailControls', 'sMapControls', 'sInfoControls', 'sBackControls', 'sAccess', 'sStoryDestinationMap', 'CB2_StoryDestinationMap',
         'sFieldRegionMapHandler', 'sPokedexAreaScreen', 'Task_HandlePokedexAreaScreenInput',
         'sRegionMap_MapSectionLayout', 'sRegionMapSections_Kanto', 'sRegionMapSections_Sevii123',
         'sRegionMapSections_Sevii45', 'sRegionMapSections_Sevii67', 'sRegionMapSections_Johto', 'gSpecialVar_0x8005', 'gSpecialVar_0x8008', 'gSpecialVar_0x8009']
fixture = subprocess.check_output([nm, str(a.out/'fixture.elf')], text=True)
hook = int(next(l.split()[0] for l in fixture.splitlines() if l.endswith(' VisualFeatureFixture')), 16) | 1
lua = 'return {hook=0x%X,' % hook
lua += ','.join(f'{name}=0x{symbols[name][0]:X}' for name in names)
lua += ',spriteAllocSize='+str(symbols['sSpriteTileAllocBitmap'][1])
lua += ',spritePaletteSize='+str(symbols['sSpritePaletteTags'][1])
lua += '}\n'
(a.out/'lua/story_symbols.lua').write_text(lua)
rom = rom_path.read_bytes()
layout_names = ['sRegionMap_MapSectionLayout', 'sRegionMapSections_Kanto', 'sRegionMapSections_Sevii123',
                'sRegionMapSections_Sevii45', 'sRegionMapSections_Sevii67', 'sRegionMapSections_Johto']
layout_sections = []
for name in layout_names:
    address, size = symbols[name]
    assert size == 28*15*2, (name, size)
    start = address - 0x08000000
    layout_sections.append({int.from_bytes(rom[i:i+2], 'little') for i in range(start, start+size, 2)})
objectives = []
sources = [root/'src/story_progress.c', *sorted((root/'src/data/story_progress').glob('*.inc'))]
for source in sources:
    for name in re.findall(r'STORY_OBJECTIVE\(\s*(s\w+)', source.read_text()):
        addr, size = symbols[name]
        assert size == 28, (name, size)
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
        kind = int.from_bytes(rom[offset+24:offset+26], 'little')
        section = int.from_bytes(rom[offset+26:offset+28], 'little')
        layouts = [i for i, sections in enumerate(layout_sections) if section in sections]
        if kind == 0:
            assert len(layouts) == 1, (objective_id, 'pin must occur in exactly one layout', layouts)
        objectives.append({'id': objective_id, 'address': addr, 'texts': texts, 'kind': kind,
                           'section': section, 'mapType': layouts[0] if kind == 0 else -1})
(a.out/'objectives.json').write_text(json.dumps(objectives, indent=2)+'\n')
(a.out/'lua/story_texts.lua').write_text('return {' + ','.join(
    '{id='+json.dumps(o['id'])+',address='+hex(o['address'])+',kind='+str(o['kind'])+',section='+str(o['section'])+',mapType='+str(o['mapType'])+',texts={'+','.join(hex(x) for x in o['texts'])+'}}' for o in objectives) + '}\n')
print(f'{len(objectives)} compiled objectives ready for font/layout checks')
manifest_path = a.out/'manifest.json'
manifest = json.loads(manifest_path.read_text())
production = [root/'include/story_progress.h', *sources,
              root/'src/story_progress_menu.c', root/'src/story_destination_map.c',
              root/'src/region_map.c', root/'include/region_map.h', root/'src/start_menu.c',
              root/'src/unbound_start_menu.c']
manifest['production_sources_sha256'] = {
    str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest()
    for path in production
}
manifest['input_elf_sha256'] = hashlib.sha256(elf_path.read_bytes()).hexdigest()
manifest['fixture_elf_sha256'] = hashlib.sha256(fixture_elf.read_bytes()).hexdigest()
manifest['capture_suite_sha256'] = hashlib.sha256((here/'capture.lua').read_bytes()).hexdigest()
manifest['objective_count'] = len(objectives)
manifest['text_field_count'] = len(objectives) * 5
manifest_path.write_text(json.dumps(manifest, indent=2)+'\n')
