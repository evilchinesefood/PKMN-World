#!/usr/bin/env python3
"""Verify offline v11 migration preserves existing data and rejects damaged Pokemon."""
from pathlib import Path
import struct
import unittest

import SavePatch as SP

FIXTURES = Path(__file__).resolve().parent / 'lua/fixtures'


class RegionalTravelMigration(unittest.TestCase):
    def test_dirty_fixture_preserves_pokemon_and_old_banks(self):
        clean = SP.Save(FIXTURES / 'v10regional.srm')
        dirty = SP.Save(FIXTURES / 'v10regionaldirty.srm')
        SP.migrate(dirty)
        self.assertEqual(dirty.sb1, clean.sb1)
        self.assertEqual(dirty.pk, clean.pk)
        start = SP.SB3_REGION_OFF + SP.V['RS.regionalTravel']
        self.assertEqual(dirty.sb3[:start], clean.sb3[:start])
        self.assertEqual(dirty.sb3[start:], struct.pack('<I', 1) + bytes(164))
        expected = bytearray(clean.sb2)
        expected[SP.V['SB2.saveVersion']] = 11
        struct.pack_into('<H', expected, SP.V['SB2.regionChecksum'], dirty.region_checksum())
        self.assertEqual(dirty.sb2, expected)
        dirty.writeback()
        self.assertTrue(all(SP.Sector(dirty.flash, p).valid() for p in dirty.holder.values()))

    def test_every_persisted_owner_has_identity_cleared(self):
        clean = SP.Save(FIXTURES / 'v10regional.srm')
        save = SP.Save(FIXTURES / 'v10regionaldirty.srm')
        party = SP.V['SB1.playerParty']
        old_mon = bytes(clean.sb1[party:party + 80])
        dirty_mon = bytes(save.sb1[party:party + 80])
        owners = ((save.sb1, party, 6, 100),
                  (save.sb1, SP.V['SB1.daycareMons'], 2, SP.V['DaycareMon.size']),
                  (save.sb3, SP.SB3_REGION_OFF + SP.V['RS.route5DayCareMon'], 1, 140),
                  (save.pk, SP.V['PK.boxes'], 420, 80),
                  (save.pk, SP.V['PK.fusions'], 4, 100))
        for buf, start, count, stride in owners:
            for i in range(count):
                buf[start + i * stride:start + i * stride + 80] = dirty_mon
        SP.migrate(save)
        for buf, start, count, stride in owners:
            for i in range(count):
                self.assertEqual(buf[start + i * stride:start + i * stride + 80], old_mon)

    def test_all_twenty_four_substructure_orders(self):
        clean = SP.Save(FIXTURES / 'v10regional.srm')
        dirty = SP.Save(FIXTURES / 'v10regionaldirty.srm')
        start = SP.V['SB1.playerParty']
        bodies = []
        for source in (clean.sb1, dirty.sb1):
            mon = source[start:start + 80]
            personality, trainer = struct.unpack_from('<II', mon)
            key = personality ^ trainer
            payload = struct.pack('<12I', *(x ^ key for x in struct.unpack_from('<12I', mon, 32)))
            bodies.append((mon, [payload[SP.SUBSTRUCT_OFFSETS[k][personality % 24] * 12:
                                        SP.SUBSTRUCT_OFFSETS[k][personality % 24] * 12 + 12]
                                 for k in range(4)]))
        for order in range(24):
            with self.subTest(order=order):
                variants = []
                for mon, logical in bodies:
                    result = bytearray(mon)
                    struct.pack_into('<I', result, 0, order)
                    payload = bytearray(48)
                    for k, block in enumerate(logical):
                        off = SP.SUBSTRUCT_OFFSETS[k][order] * 12
                        payload[off:off + 12] = block
                    key = order ^ trainer
                    struct.pack_into('<12I', result, 32,
                                     *(x ^ key for x in struct.unpack('<12I', payload)))
                    variants.append(result)
                SP.clear_regional_identity(variants[1], 0)
                self.assertEqual(variants[1], variants[0])

    def test_repeated_migration_does_not_erase_current_history(self):
        save = SP.Save(FIXTURES / 'v10regionaldirty.srm')
        SP.migrate(save)
        start = SP.SB3_REGION_OFF + SP.V['RS.regionalTravel']
        save.sb3[start:start + 168] = bytes(range(168))
        SP.migrate(save)
        before = tuple(bytes(b) for b in (save.sb1, save.sb2, save.sb3, save.pk))
        SP.migrate(save)
        self.assertEqual(tuple(bytes(b) for b in (save.sb1, save.sb2, save.sb3, save.pk)), before)
        self.assertEqual(save.sb3[start:start + 168], bytes(range(168)))

    def test_bad_checksum_is_refused_without_rewriting_the_pokemon(self):
        save = SP.Save(FIXTURES / 'v10regionaldirty.srm')
        start = SP.V['SB1.playerParty']
        mon = bytearray(save.sb1[start:start + 80])
        mon[32] ^= 1
        before = bytes(mon)
        with self.assertRaises(SystemExit):
            SP.clear_regional_identity(mon, 0)
        self.assertEqual(mon, before)


if __name__ == '__main__':
    unittest.main()
