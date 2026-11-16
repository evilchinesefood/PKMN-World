#!/usr/bin/env python3
"""Check SavePatch's mirror of the v12 -> v13 cross-region repairs against saves the old game wrote.

The fixtures were made by a pre-fix build driving the old scripts (lua/fixtures/v12xregion.md);
XRegionSaveRepair.lua and XRegionSaveRepairVoyage.lua prove the game's own migration on the same
files. These cases prove the offline patcher agrees, converges, and needs evidence before acting.
"""
from pathlib import Path
import unittest

import SavePatch as SP

HERE = Path(__file__).resolve().parent
DAMAGED = HERE / 'lua/fixtures/v12xregiondamaged.srm'
VOYAGE = HERE / 'lua/fixtures/v12xregionvoyage.srm'
F = SP.V


def blocks(save):
    return tuple(bytes(b) for b in (save.sb1, save.sb2, save.sb3, save.pk))


def cottage_cast(save):
    """Active objects in the saved object list that are Briney or Peeko in the cottage."""
    found = []
    for i in range(F['OBJ.count']):
        o = F['SB1.objectEvents'] + i * F['OBJ.stride']
        if (save.sb1[o] >> SP.OBJ_ACTIVE_BIT) & 1 \
                and (save.sb1[o + F['OBJ.mapGroup']], save.sb1[o + F['OBJ.mapNum']]) \
                == (F['MAP.brineysHouse.group'], F['MAP.brineysHouse.num']) \
                and save.sb1[o + F['OBJ.localId']] in (F['LOCALID_BRINEYS_HOUSE_BRINEY'],
                                                      F['LOCALID_BRINEYS_HOUSE_PEEKO']):
            found.append(save.sb1[o + F['OBJ.localId']])
    return sorted(found)


class XRegionSaveRepair(unittest.TestCase):
    def test_fixtures_hold_the_damage_the_old_scripts_wrote(self):
        damaged = SP.Save(DAMAGED)
        self.assertEqual(damaged.sb2[F['SB2.saveVersion']], 12)
        self.assertFalse(damaged.flag(F['FLAG_RECEIVED_BIKE']))
        self.assertTrue(damaged.holds_key_item(F['ITEM_MACH_BIKE']))
        self.assertTrue(damaged.flag(F['FLAG_RECEIVED_POKENAV']))
        self.assertEqual(damaged.var(F['VAR_DEVON_CORP_3F_STATE']), 0)
        self.assertEqual(damaged.var(F['VAR_BRINEY_LOCATION']), 1)
        self.assertFalse(damaged.flag(F['FLAG_HIDE_BRINEYS_HOUSE_MR_BRINEY']))
        self.assertEqual(cottage_cast(damaged), [1, 2])

        voyage = SP.Save(VOYAGE)
        self.assertEqual(voyage.sb2[F['SB2.saveVersion']], 12)
        self.assertTrue(voyage.flag(F['FLAG_RECEIVED_POKENAV']))
        self.assertTrue(voyage.flag(F['FLAG_VISITED_DEWFORD_TOWN']))
        self.assertFalse(voyage.flag(F['FLAG_RECEIVED_BIKE']))
        self.assertFalse(voyage.holds_key_item(F['ITEM_MACH_BIKE']))
        self.assertFalse(voyage.holds_key_item(F['ITEM_ACRO_BIKE']))

    def test_damaged_save_is_repaired(self):
        save = SP.Save(DAMAGED)
        SP.migrate(save)
        self.assertEqual(save.sb2[F['SB2.saveVersion']], SP.SAVE_FORMAT_VERSION)
        self.assertTrue(save.flag(F['FLAG_RECEIVED_BIKE']))
        self.assertFalse(save.flag(F['FLAG_RECEIVED_POKENAV']))
        self.assertEqual(save.var(F['VAR_BRINEY_LOCATION']), 0)
        self.assertTrue(save.flag(F['FLAG_HIDE_BRINEYS_HOUSE_MR_BRINEY']))
        self.assertTrue(save.flag(F['FLAG_HIDE_BRINEYS_HOUSE_PEEKO']))
        self.assertEqual(cottage_cast(save), [])

    def test_repair_converges(self):
        save = SP.Save(DAMAGED)
        SP.migrate(save)
        once = blocks(save)
        save.sb2[F['SB2.saveVersion']] = 12
        SP.migrate(save)
        self.assertEqual(blocks(save), once)

    def test_voyage_save_keeps_briney_and_the_bike_flag(self):
        save = SP.Save(VOYAGE)
        before_sb1 = bytes(save.sb1)
        SP.migrate(save)
        self.assertEqual(bytes(save.sb1), before_sb1)

    def test_bike_in_the_item_pc_counts(self):
        save = SP.Save(DAMAGED)
        size = F['ItemSlot.size']
        for i in range(F['BAG_KEYITEMS_COUNT']):
            o = F['SB1.bagKeyItems'] + i * size
            if save.u16(save.sb1, o) == F['ITEM_MACH_BIKE']:
                save.sb1[o:o + size] = bytes(size)
        self.assertFalse(save.holds_key_item(F['ITEM_MACH_BIKE']))
        SP.repair_cross_region_flags(save)
        self.assertFalse(save.flag(F['FLAG_RECEIVED_BIKE']), 'no bike anywhere: the flag stays clear')
        pc = F['SB1.pcItems'] + (F['PC_ITEMS_COUNT'] - 1) * size
        save.sb1[pc:pc + size] = F['ITEM_ACRO_BIKE'].to_bytes(2, 'little') + (1).to_bytes(2, 'little')
        SP.repair_cross_region_flags(save)
        self.assertTrue(save.flag(F['FLAG_RECEIVED_BIKE']))

    def test_devon_gift_is_left_alone(self):
        save = SP.Save(DAMAGED)
        save.set_var(F['VAR_DEVON_CORP_3F_STATE'], 1)
        save.set_flag(F['FLAG_RECEIVED_BIKE'], True)
        before = bytes(save.sb1)
        SP.repair_cross_region_flags(save)
        self.assertEqual(bytes(save.sb1), before)


if __name__ == '__main__':
    unittest.main()
