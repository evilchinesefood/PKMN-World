#!/usr/bin/env python3
"""Check that the offline migration initializes only the new global rate bits."""
from pathlib import Path
import struct
import unittest

import SavePatch as SP

FIXTURE = Path(__file__).resolve().parent / 'lua/fixtures/v10regional.srm'


class FamilyOptionsMigration(unittest.TestCase):
    def test_supported_versions_preserve_adjacent_options_and_pokemon(self):
        for version in range(7, 12):
            for old_hard in (0, 0x10):
                with self.subTest(version=version, old_hard=old_hard):
                    save = SP.Save(FIXTURE)
                    save.sb2[SP.V['SB2.saveVersion']] = version
                    before_word = 0xFFE0 | old_hard | 0x06
                    struct.pack_into('<HH', save.sb2, 0x14, 0xA5A1, before_word)
                    pokemon = bytes(save.sb1[SP.V['SB1.playerParty']:
                                             SP.V['SB1.playerParty'] + 600])
                    SP.migrate(save)
                    self.assertEqual(save.sb2[SP.V['SB2.saveVersion']], 12)
                    self.assertEqual(struct.unpack_from('<H', save.sb2, 0x14)[0], 0xA5A1)
                    self.assertEqual(struct.unpack_from('<H', save.sb2, 0x16)[0],
                                     before_word & 0xFC3F)
                    self.assertEqual(bytes(save.sb1[SP.V['SB1.playerParty']:
                                                   SP.V['SB1.playerParty'] + 600]), pokemon)

    def test_current_version_keeps_every_selected_rate(self):
        for encounter in range(4):
            for money in range(4):
                with self.subTest(encounter=encounter, money=money):
                    save = SP.Save(FIXTURE)
                    SP.migrate(save)
                    word = 0xF03E | encounter << 6 | money << 8
                    struct.pack_into('<H', save.sb2, 0x16, word)
                    before = tuple(bytes(b) for b in (save.sb1, save.sb2, save.sb3, save.pk))
                    SP.migrate(save)
                    SP.migrate(save)
                    self.assertEqual(tuple(bytes(b) for b in (save.sb1, save.sb2, save.sb3, save.pk)), before)

    def test_v11_migration_preserves_region_state(self):
        save = SP.Save(FIXTURE)
        SP.migrate(save)
        save.sb2[SP.V['SB2.saveVersion']] = 11
        start = SP.SB3_REGION_OFF + SP.V['RS.regionalTravel']
        save.sb3[start:start + 168] = bytes(range(168))
        struct.pack_into('<H', save.sb2, 0x16, 0xFFFF)
        SP.migrate(save)
        self.assertEqual(save.sb3[start:start + 168], bytes(range(168)))
        self.assertEqual(struct.unpack_from('<H', save.sb2, 0x16)[0], 0xFC3F)


if __name__ == '__main__':
    unittest.main()
