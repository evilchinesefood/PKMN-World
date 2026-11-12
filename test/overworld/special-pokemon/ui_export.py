#!/usr/bin/env python3
"""Bind the focused UI checks to the input ELF and compiler-derived view offsets."""
import argparse
from pathlib import Path
import re
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
PREFIX = '/opt/devkitpro/devkitARM/bin/arm-none-eabi-'


def export(elf, output):
    symbols = {}
    for line in subprocess.check_output([PREFIX + 'nm', '-S', str(elf)], text=True).splitlines():
        fields = line.split()
        if len(fields) == 4:
            symbols[fields[3]] = int(fields[0], 16)
    names = (
        'sPokedexView', 'sSpecialPokemonMenu', 'sLastSelectedPokemon',
        'Task_HandlePokedexInput', 'Task_HandlePokedexStartMenuInput',
        'Task_HandleInfoScreenInput', 'Task_HandleEvolutionScreenInput',
        'Task_HandleFormsScreenInput', 'HandleCollectionInput',
        'sPikachuFormSpeciesIdTable', 'sUnownFormSpeciesIdTable',
    )
    values = {name: symbols[name] for name in names}
    dex = (ROOT / 'src/pokedex_plus_hgss.c').read_text()
    structs = dex[dex.index('struct PokedexListItem\n{'):dex.index('static void ResetPokedexView(')]
    maximum = re.search(r'^#define MAX_MONS_ON_SCREEN .+$', dex, re.M).group()
    menu = (ROOT / 'src/special_pokemon_menu.c').read_text()
    menu_struct = menu[menu.index('#define COLLECTION_ROWS'):menu.index('static EWRAM_DATA')]
    fields = {
        'formView': 'offsetof(struct PokedexView, sFormScreenData)',
        'formSpecies': 'offsetof(struct PokedexView, formSpecies)',
        'dexSelection': 'offsetof(struct PokedexView, selectedPokemon)',
        'formCount': 'offsetof(struct FormScreenData, numForms)',
        'formSelection': 'offsetof(struct FormScreenData, menuPos)',
        'formPage': 'offsetof(struct FormScreenData, pageStart)',
        'formIcons': 'offsetof(struct FormScreenData, iconSpriteIds)',
        'formBaseIcon': 'offsetof(struct FormScreenData, baseIconSpriteId)',
        'formArrow': 'offsetof(struct FormScreenData, arrowSpriteId)',
        'formSubmenu': 'offsetof(struct FormScreenData, inSubmenu)',
        'collectionSelection': 'offsetof(struct SpecialPokemonMenu, selected)',
        'collectionDetail': 'offsetof(struct SpecialPokemonMenu, detail)',
    }
    with tempfile.TemporaryDirectory() as temporary:
        work = Path(temporary)
        source = '#include "global.h"\n#include "main.h"\n#include "pokemon.h"\n#include "bg.h"\n'
        source += maximum + '\n' + structs + '\n' + menu_struct
        source += 'const u32 offsets[] = {' + ','.join(fields.values()) + '};\n'
        (work / 'offsets.c').write_text(source)
        subprocess.run([PREFIX + 'gcc', '-std=gnu17', '-mthumb', '-march=armv4t',
                        '-mabi=apcs-gnu', '-DMODERN=1', '-DEMERALD', '-DALL_REGIONS=1',
                        '-iquote', str(ROOT / 'include'), '-c', str(work / 'offsets.c'),
                        '-o', str(work / 'offsets.o')], check=True)
        subprocess.run([PREFIX + 'objcopy', '-O', 'binary', '-j', '.rodata',
                        str(work / 'offsets.o'), str(work / 'offsets.bin')], check=True)
        offsets = struct.unpack('<' + 'I' * len(fields), (work / 'offsets.bin').read_bytes())
        values.update(zip(fields, offsets))
    output.write_text('return {' + ','.join(f'{key}=0x{value:X}' for key, value in values.items()) + '}\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('elf', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    export(args.elf, args.output)
