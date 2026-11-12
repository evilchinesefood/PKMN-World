#!/usr/bin/env python3
"""Check collection-source placement and script state transitions on the host."""
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'test/overworld'))
import ValidateOwMonPlacements as placement

source = (ROOT / 'data/scripts/special_pokemon.inc').read_text()
commands, labels = [], {}
for raw in source.splitlines():
    line = raw.strip()
    if line.endswith(':'):
        labels[line.rstrip(':')] = len(commands)
    elif line and not line.startswith(('.', '@')):
        parts = line.split(None, 1)
        commands.append((parts[0], [s.strip() for s in parts[1].split(',')] if len(parts) > 1 else []))

assert not re.search(r'\b(?:setflag|clearflag) FLAG_SPECIAL_COLLECTED_', source)
assert not re.search(r'\b(?:clearflag) FLAG_SPECIAL_UNLOCKED_', source)
assert 'setflag FLAG_SYS_CTRL_OBJ_DELETE' not in source
assert 'removeobject' not in source

class Script:
    def __init__(self):
        self.flags = {'FLAG_SYS_POKEMON_GET'}
        self.vars = {}
        self.gifts = []
        self.battles = []
        self.messages = []
        self.answer = 'YES'
        self.delivery = 'MON_GIVEN_TO_PARTY'
        self.healthy = 1

    def value(self, value):
        if value in ('NO', 'FALSE'):
            return 0
        if value in ('YES', 'TRUE'):
            return 1
        if value == 'PARTY_SIZE':
            return 6
        if value.isdecimal():
            return int(value)
        return self.vars.get(value, value)

    def talk(self, suffix):
        label = 'SpecialPokemon_EventScript_' + suffix
        pc = labels[label]
        self.messages = []
        for _ in range(200):
            op, args = commands[pc]
            pc += 1
            if op == 'end':
                return
            if op == 'setflag':
                self.flags.add(args[0])
            elif op == 'clearflag':
                self.flags.discard(args[0])
            elif op in ('setvar', 'copyvar'):
                self.vars[args[0]] = self.value(args[1])
            elif op == 'goto':
                pc = labels[args[0]]
            elif op in ('goto_if_set', 'goto_if_unset'):
                if (args[0] in self.flags) == (op == 'goto_if_set'):
                    pc = labels[args[1]]
            elif op == 'goto_if_eq':
                if self.value(args[0]) == self.value(args[1]):
                    if args[2] == 'Common_EventScript_NoMoreRoomForPokemon':
                        self.messages.append('gText_NoMoreRoomForPokemon')
                        return
                    pc = labels[args[2]]
            elif op == 'msgbox':
                self.messages.append(args[0])
                if args[-1] == 'MSGBOX_YESNO':
                    self.vars['VAR_RESULT'] = self.value(self.answer)
            elif op == 'special':
                key = self.vars['VAR_0x8004']
                if args[0] == 'SpecialPokemon_Give':
                    self.vars['VAR_RESULT'] = self.delivery
                    if self.delivery != 'MON_CANT_GIVE':
                        self.gifts.append(key)
                elif args[0] == 'SpecialPokemon_CreateEncounter':
                    self.vars['VAR_RESULT'] = 1
                else:
                    raise AssertionError(args)
            elif op == 'specialvar':
                assert args[1] == 'CountPartyAliveNonEggMons_IgnoreVar0x8004Slot'
                assert self.vars['VAR_0x8004'] == 6
                self.vars[args[0]] = self.healthy
            elif op == 'dowildbattle':
                self.battles.append(self.vars['VAR_0x8004'])
            elif op not in ('lock', 'lockall', 'faceplayer', 'release', 'releaseall', 'playfanfare',
                            'waitfanfare', 'call_if_eq', 'callnative', 'playmoncry', 'waitmoncry',
                            'addobject', 'closemessage'):
                raise AssertionError((op, args))
        raise AssertionError('script does not terminate: ' + suffix)

for entry, key in [('ClassicCapTrainer', 'CLASSIC_CAP'), ('BalloonSeller', 'BALLOONS')]:
    s = Script()
    s.flags.clear()
    s.talk(entry)
    assert not s.gifts and 'FLAG_SPECIAL_UNLOCKED_' + key not in s.flags
    s.flags.add('FLAG_SYS_POKEMON_GET')
    s.answer = 'NO'
    s.talk(entry)
    assert not s.gifts and 'FLAG_SPECIAL_UNLOCKED_' + key in s.flags
    s.answer = 'YES'
    s.delivery = 'MON_CANT_GIVE'
    s.talk(entry)
    assert s.messages[-1] == 'gText_NoMoreRoomForPokemon' and not s.gifts
    s.delivery = 'MON_GIVEN_TO_PC'
    s.talk(entry)
    s.talk(entry)
    assert s.gifts == ['SPECIAL_POKEMON_' + key] * 2

for organizer, helpers, key in [
    ('SquadOrganizer', ['SquadOne', 'SquadTwo'], 'SQUAD'),
    ('KilnHelper', ['WellHelper'], 'FIREFIGHTER'),
    ('Florist', ['FlowerResidentOne', 'FlowerResidentTwo'], 'FLOWER_CROWN'),
]:
    s = Script()
    for helper in helpers:
        s.talk(helper)
    s.talk(organizer)
    assert not s.gifts and 'FLAG_SPECIAL_UNLOCKED_' + key not in s.flags
    for i, helper in enumerate(helpers):
        if i:
            s.talk(organizer)
            assert not s.gifts
        s.talk(helper)
    s.delivery = 'MON_CANT_GIVE'
    s.talk(organizer)
    assert 'FLAG_SPECIAL_UNLOCKED_' + key in s.flags and not s.gifts
    assert s.messages[-1] == 'gText_NoMoreRoomForPokemon'
    s.delivery = 'MON_GIVEN_TO_PARTY'
    s.talk(organizer)
    s.talk(organizer)
    assert s.gifts == ['SPECIAL_POKEMON_' + key] * 2

for target, introducer, key in [('Surfboard', 'Surfer', 'SURFBOARD'), ('Pirate', 'PirateSailor', 'PIRATE')]:
    s = Script()
    s.talk(introducer)
    s.answer = 'NO'
    s.talk(target)
    assert not s.battles
    s.answer = 'YES'
    s.healthy = 0
    s.talk(target)
    assert not s.battles
    s.healthy = 1
    s.talk(target)
    s.talk(target)
    assert s.battles == ['SPECIAL_POKEMON_' + key] * 2
    assert 'FLAG_SPECIAL_UNLOCKED_' + key in s.flags

rows = json.loads((ROOT / 'test/overworld/special-pokemon/sources.json').read_text())
files = placement.load_tileset_attributes()
layouts = placement.Layouts(files, placement.check_attribute_widths(files))
for row in rows:
    name, x, y = row['map'], row['x'], row['y']
    relative = f'data/maps/{name}/map.json'
    current = json.loads((ROOT / relative).read_text())
    obj = current['object_events'][row['local_id'] - 1]
    assert re.fullmatch(r'[A-Z_]+', obj['local_id']), row
    assert (obj['x'], obj['y'], obj['script']) == (x, y, 'SpecialPokemon_EventScript_' + row['entry'])
    t = layouts.tile(current['layout'], x, y)
    assert t['collision'] == 0 and t['elevation'] == row['elevation'], row
    occupied = {(o['x'], o['y']) for o in current['object_events']}
    for group in ('warp_events', 'coord_events', 'bg_events'):
        assert all((x, y) != (o['x'], o['y']) for o in current[group]), row
    assert any((x+dx, y+dy) not in occupied
               and (n := layouts.tile(current['layout'], x+dx, y+dy))
               and n['collision'] == 0 and n['elevation'] in (0, t['elevation'])
               for dx,dy in ((0,1),(0,-1),(1,0),(-1,0))), row
print(f'PASS: all seven source flows, three task gates, retries, storage refusal, and {len(rows)} source placements')
print('Host script interpretation and tile checks only. Emulator behavior is separate evidence.')
