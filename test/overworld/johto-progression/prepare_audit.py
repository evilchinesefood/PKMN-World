#!/usr/bin/env python3
"""Export audit data from the matching ELF, map JSON and C constants."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
FIXTURE = Path(sys.argv[1]).resolve()
PREFIX = '/opt/devkitpro/devkitARM/bin/arm-none-eabi-'
os.chdir(ROOT)

GYMS = [
    ('VioletCity_Gym', 'Falkner'), ('AzaleaTown_Gym', 'Bugsy'),
    ('GoldenrodCity_Gym', 'Whitney'), ('EcruteakCity_Gym', 'Morty'),
    ('CianwoodGym', 'Chuck'), ('OlivineCity_Gym', 'Jasmine'),
    ('MahoganyTown_Gym', 'Pryce'), ('BlackthornCity_Gym', 'Clair'),
]
STORY_MAPS = [
    'Route30_MrPokemonsHouse', 'NewBarkTown_Lab', 'SproutTower_3F',
    'VioletCity_PokemonCenter', 'AzaleaTown_KurtsHouse', 'BurnedTower_B1F',
    'EcruteakCity_Theater', 'OlivineCity_Lighthouse', 'DragonsDen_Cavern',
    'DragonsDen_Shrine', 'JohtoPokemonLeague_WillsRoom',
    'JohtoPokemonLeague_KogasRoom', 'JohtoPokemonLeague_BrunosRoom',
    'JohtoPokemonLeague_KarensRoom', 'JohtoPokemonLeague_ChampionsRoom',
    'JohtoPokemonLeague_HallOfFame', 'CianwoodShop',
    'GoldenrodCity_RadioTower_5F', 'GoldenrodCity_UndergroundStorage',
    'MahoganyHideout_B2F', 'GoldenrodCity_RadioTower_3F',
    'GoldenrodCity_FlowerShop', 'Route36', 'IlexForest',
]

def write_lua(name, body):
    (FIXTURE / 'lua' / name).write_text(body + '\n')


def map_data(name):
    return json.loads((ROOT / 'data/maps' / name / 'map.json').read_text())


groups = json.loads((ROOT / 'data/maps/map_groups.json').read_text())
map_ids = {name: (i, j) for i, group in enumerate(groups['group_order'])
           for j, name in enumerate(groups[group])}
symbols = {}
for line in subprocess.check_output([PREFIX + 'nm', 'pokemonworld.elf'], text=True).splitlines():
    parts = line.split()
    if len(parts) == 3:
        symbols[parts[2]] = int(parts[0], 16)
sources = '\n'.join(path.read_text() for path in HERE.glob('audit_*.lua'))
needed = (set(re.findall(r'A\.(\w+)', sources))
          | {f'gSpecialVar_0x800{i}' for i in range(4, 9)}
          | {'Task_HandleMultichoiceInput'})
assert needed <= symbols.keys(), needed - symbols.keys()
write_lua('audit_symbols.lua', 'return {' + ','.join(
    f'[{json.dumps(name)}]=0x{symbols[name]:x}' for name in sorted(needed)) + '}')

constants = (set(re.findall(r'C\.(\w+)', sources))
             | set(re.findall(r"['\"]((?:FLAG|VAR)_\w+)['\"]", sources)))
hoenn_script = (ROOT / 'data/scripts/set_gym_trainers.inc').read_text()
hoenn_labels = ['RustboroCity', 'DewfordTown', 'MauvilleCity', 'LavaridgeTown', 'PetalburgCity', 'FortreeCity', 'MossdeepCity', 'SootopolisCity']
cases = []
for index, (name, leader) in enumerate(GYMS):
    data = map_data(name)
    obj = next(obj for obj in data['object_events'] if obj['script'].endswith('_' + leader))
    group, number = map_ids[name]
    script = (ROOT / 'data/maps' / name / 'scripts.inc').read_text()
    trainers = list(dict.fromkeys(re.findall(r'trainerbattle_(?:single|double) (TRAINER_\w+)', script)))
    constants.update(trainers)
    label = hoenn_labels[index] + '_Gym_SetGymTrainers::'
    block = hoenn_script.split(label, 1)[1].split('return', 1)[0]
    hoenn_trainers = re.findall(r'settrainerflag (TRAINER_\w+)', block)
    assert hoenn_trainers
    constants.update(hoenn_trainers)
    cases.append(f'{{name="{leader}",g={group},m={number},x={obj["x"]},y={obj["y"] + 1},'
                 f'badge=C.FLAG_JOHTO_BADGE_1+{index},trainers={{'
                 + ','.join('C.' + trainer for trainer in trainers) + '},hoenn={'
                 + ','.join('C.' + trainer for trainer in hoenn_trainers) + '}}')
constants.add('FLAG_JOHTO_BADGE_1')
write_lua('gym_cases.lua', 'local C=require("constants");return {' + ','.join(cases) + '}')

# Prefix each key so the C preprocessor expands only its value, not its name.
c_source = ('#include "constants/flags.h"\n#include "constants/vars.h"\n'
            '#include "constants/opponents.h"\n' + ''.join(
                f'PW_VALUE PW_KEY_{name} {name}\n' for name in sorted(constants)))
expanded = subprocess.check_output([
    PREFIX + 'gcc', '-E', '-P', '-x', 'c', '-iquote', 'include',
    '-DALL_REGIONS=1', '-'], input=c_source, text=True)
values = {}
for line in expanded.splitlines():
    if line.startswith('PW_VALUE '):
        _, key, expression = line.split(' ', 2)
        # These are repository-owned integer macros; reject all other syntax.
        assert re.fullmatch(r'[0-9xa-fA-F()+\-*/\s<>|&]+', expression), expression
        values[key.removeprefix('PW_KEY_')] = eval(expression, {'__builtins__': {}}, {})
assert constants == values.keys(), constants - values.keys()
write_lua('constants.lua', 'return {' + ','.join(
    f'{name}={value}' for name, value in sorted(values.items())) + '}')

maps = []
for name in STORY_MAPS:
    data = map_data(name)
    group, number = map_ids[name]
    objects = [f'[{json.dumps(obj["script"])}]={{x={obj["x"]},y={obj["y"] + 1}}}'
               for obj in data['object_events'] if obj['script'] not in ('0', 'NULL')]
    warp = data['warp_events'][0]
    maps.append(f'{name}={{g={group},m={number},x={warp["x"]},y={warp["y"]},objects={{'
                + ','.join(objects) + '}}')
write_lua('story_maps.lua', 'return {' + ','.join(maps) + '}')
