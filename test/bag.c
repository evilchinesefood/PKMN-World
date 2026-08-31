#include "global.h"
#include "battle.h"
#include "event_data.h"
#include "item.h"
#include "item_menu.h"
#include "pokemon.h"
#include "pokemon_storage_system.h"
#include "test/overworld_script.h"
#include "test/test.h"

TEST("TMs and HMs are sorted correctly in the bag")
{
    struct BagPocket *pocket = &gBagPockets[POCKET_TM_HM];

    ASSUME(GetItemPocket(ITEM_HM07) == POCKET_TM_HM);
    ASSUME(GetItemPocket(ITEM_TM25) == POCKET_TM_HM);
    ASSUME(GetItemPocket(ITEM_TM14) == POCKET_TM_HM);
    ASSUME(GetItemPocket(ITEM_TM42) == POCKET_TM_HM);
    ASSUME(GetItemPocket(ITEM_HM05) == POCKET_TM_HM);
    ASSUME(GetItemPocket(ITEM_TM05) == POCKET_TM_HM);
    ASSUME(GetItemPocket(ITEM_TM01) == POCKET_TM_HM);
    ASSUME(GetItemPocket(ITEM_HM02) == POCKET_TM_HM);

    /*
     * Note: I would add a test to make sure that TMs are sorted correctly by move name,
     * but downstream users are likely to rearrange TMs so this would just be a nuisance.
     */

    RUN_OVERWORLD_SCRIPT(
        additem ITEM_HM07;
        additem ITEM_TM25;
        additem ITEM_TM14;
        additem ITEM_TM42;
        additem ITEM_HM05;
        additem ITEM_TM05;
        additem ITEM_TM01;
        additem ITEM_HM02;
    );

    SortItemsInBag(&gBagPockets[POCKET_TM_HM], SORT_BY_INDEX);

    EXPECT_EQ(pocket->itemSlots[0].itemId, ITEM_TM01);
    EXPECT_EQ(pocket->itemSlots[1].itemId, ITEM_TM05);
    EXPECT_EQ(pocket->itemSlots[2].itemId, ITEM_TM14);
    EXPECT_EQ(pocket->itemSlots[3].itemId, ITEM_TM25);
    EXPECT_EQ(pocket->itemSlots[4].itemId, ITEM_TM42);
    EXPECT_EQ(pocket->itemSlots[5].itemId, ITEM_HM02);
    EXPECT_EQ(pocket->itemSlots[6].itemId, ITEM_HM05);
    EXPECT_EQ(pocket->itemSlots[7].itemId, ITEM_HM07);
    EXPECT_EQ(pocket->itemSlots[8].itemId, ITEM_NONE);
}

TEST("Berries are sorted correctly in the bag")
{
    struct BagPocket *pocket = &gBagPockets[POCKET_BERRIES];

    ASSUME(GetItemPocket(ITEM_POMEG_BERRY) == POCKET_BERRIES);
    ASSUME(GetItemPocket(ITEM_MAGOST_BERRY) == POCKET_BERRIES);
    ASSUME(GetItemPocket(ITEM_KELPSY_BERRY) == POCKET_BERRIES);
    ASSUME(GetItemPocket(ITEM_MICLE_BERRY) == POCKET_BERRIES);
    ASSUME(GetItemPocket(ITEM_CHARTI_BERRY) == POCKET_BERRIES);
    ASSUME(GetItemPocket(ITEM_GANLON_BERRY) == POCKET_BERRIES);
    ASSUME(GetItemPocket(ITEM_ORAN_BERRY) == POCKET_BERRIES);
    ASSUME(GetItemPocket(ITEM_CHERI_BERRY) == POCKET_BERRIES);

    RUN_OVERWORLD_SCRIPT(
        additem ITEM_POMEG_BERRY;
        additem ITEM_MAGOST_BERRY;
        additem ITEM_KELPSY_BERRY;
        additem ITEM_MICLE_BERRY;
        additem ITEM_CHARTI_BERRY;
        additem ITEM_GANLON_BERRY;
        additem ITEM_ORAN_BERRY;
        additem ITEM_CHERI_BERRY;
    );

    SortItemsInBag(&gBagPockets[POCKET_BERRIES], SORT_BY_INDEX);

    EXPECT_EQ(pocket->itemSlots[0].itemId, ITEM_CHERI_BERRY);
    EXPECT_EQ(pocket->itemSlots[1].itemId, ITEM_ORAN_BERRY);
    EXPECT_EQ(pocket->itemSlots[2].itemId, ITEM_POMEG_BERRY);
    EXPECT_EQ(pocket->itemSlots[3].itemId, ITEM_KELPSY_BERRY);
    EXPECT_EQ(pocket->itemSlots[4].itemId, ITEM_MAGOST_BERRY);
    EXPECT_EQ(pocket->itemSlots[5].itemId, ITEM_CHARTI_BERRY);
    EXPECT_EQ(pocket->itemSlots[6].itemId, ITEM_GANLON_BERRY);
    EXPECT_EQ(pocket->itemSlots[7].itemId, ITEM_MICLE_BERRY);
    EXPECT_EQ(pocket->itemSlots[8].itemId, ITEM_NONE);

    SortItemsInBag(&gBagPockets[POCKET_BERRIES], SORT_ALPHABETICALLY);

    EXPECT_EQ(pocket->itemSlots[0].itemId, ITEM_CHARTI_BERRY);
    EXPECT_EQ(pocket->itemSlots[1].itemId, ITEM_CHERI_BERRY);
    EXPECT_EQ(pocket->itemSlots[2].itemId, ITEM_GANLON_BERRY);
    EXPECT_EQ(pocket->itemSlots[3].itemId, ITEM_KELPSY_BERRY);
    EXPECT_EQ(pocket->itemSlots[4].itemId, ITEM_MAGOST_BERRY);
    EXPECT_EQ(pocket->itemSlots[5].itemId, ITEM_MICLE_BERRY);
    EXPECT_EQ(pocket->itemSlots[6].itemId, ITEM_ORAN_BERRY);
    EXPECT_EQ(pocket->itemSlots[7].itemId, ITEM_POMEG_BERRY);
    EXPECT_EQ(pocket->itemSlots[8].itemId, ITEM_NONE);
}

TEST("Items are correctly sorted and compacted in the bag")
{
    struct BagPocket *pocket = &gBagPockets[POCKET_ITEMS];
    memset(pocket->itemSlots, 0, sizeof(gSaveBlock1Ptr->bag.items));

    ASSUME(GetItemPocket(ITEM_NUGGET) == POCKET_ITEMS);
    ASSUME(GetItemPocket(ITEM_BIG_NUGGET) == POCKET_ITEMS);
    ASSUME(GetItemPocket(ITEM_TINY_MUSHROOM) == POCKET_ITEMS);
    ASSUME(GetItemPocket(ITEM_BIG_MUSHROOM) == POCKET_ITEMS);
    ASSUME(GetItemPocket(ITEM_PEARL) == POCKET_ITEMS);
    ASSUME(GetItemPocket(ITEM_BIG_PEARL) == POCKET_ITEMS);

    RUN_OVERWORLD_SCRIPT(
        additem ITEM_NUGGET;
        additem ITEM_BIG_NUGGET;
        additem ITEM_TINY_MUSHROOM;
        additem ITEM_BIG_MUSHROOM;
        additem ITEM_PEARL;
        additem ITEM_BIG_PEARL;
    );

    EXPECT_EQ(pocket->itemSlots[0].itemId, ITEM_NUGGET);
    EXPECT_EQ(pocket->itemSlots[0].quantity, 1);
    EXPECT_EQ(pocket->itemSlots[1].itemId, ITEM_BIG_NUGGET);
    EXPECT_EQ(pocket->itemSlots[1].quantity, 1);
    EXPECT_EQ(pocket->itemSlots[2].itemId, ITEM_TINY_MUSHROOM);
    EXPECT_EQ(pocket->itemSlots[2].quantity, 1);
    EXPECT_EQ(pocket->itemSlots[3].itemId, ITEM_BIG_MUSHROOM);
    EXPECT_EQ(pocket->itemSlots[3].quantity, 1);
    EXPECT_EQ(pocket->itemSlots[4].itemId, ITEM_PEARL);
    EXPECT_EQ(pocket->itemSlots[4].quantity, 1);
    EXPECT_EQ(pocket->itemSlots[5].itemId, ITEM_BIG_PEARL);
    EXPECT_EQ(pocket->itemSlots[5].quantity, 1);
    EXPECT_EQ(pocket->itemSlots[6].itemId, ITEM_NONE);

    SortItemsInBag(&gBagPockets[POCKET_ITEMS], SORT_ALPHABETICALLY);

    EXPECT_EQ(pocket->itemSlots[0].itemId, ITEM_BIG_MUSHROOM);
    EXPECT_EQ(pocket->itemSlots[1].itemId, ITEM_BIG_NUGGET);
    EXPECT_EQ(pocket->itemSlots[2].itemId, ITEM_BIG_PEARL);
    EXPECT_EQ(pocket->itemSlots[3].itemId, ITEM_NUGGET);
    EXPECT_EQ(pocket->itemSlots[4].itemId, ITEM_PEARL);
    EXPECT_EQ(pocket->itemSlots[5].itemId, ITEM_TINY_MUSHROOM);
    EXPECT_EQ(pocket->itemSlots[6].itemId, ITEM_NONE);

    // Try removing the big items, check that everything is compacted correctly

    RUN_OVERWORLD_SCRIPT(
        removeitem ITEM_BIG_NUGGET;
        removeitem ITEM_BIG_MUSHROOM;
        removeitem ITEM_BIG_PEARL;
    );

    CompactItemsInBagPocket(POCKET_ITEMS);

    EXPECT_EQ(pocket->itemSlots[0].itemId, ITEM_NUGGET);
    EXPECT_EQ(pocket->itemSlots[0].quantity, 1);
    EXPECT_EQ(pocket->itemSlots[1].itemId, ITEM_PEARL);
    EXPECT_EQ(pocket->itemSlots[1].quantity, 1);
    EXPECT_EQ(pocket->itemSlots[2].itemId, ITEM_TINY_MUSHROOM);
    EXPECT_EQ(pocket->itemSlots[2].quantity, 1);
    EXPECT_EQ(pocket->itemSlots[3].itemId, ITEM_NONE);
    EXPECT_EQ(pocket->itemSlots[4].itemId, ITEM_NONE);
    EXPECT_EQ(pocket->itemSlots[5].itemId, ITEM_NONE);
    EXPECT_EQ(pocket->itemSlots[6].itemId, ITEM_NONE);
}

TEST("Removing across two stacks takes the requested total, not that total from each stack")
{
    struct BagPocket *pocket = &gBagPockets[POCKET_ITEMS];
    memset(pocket->itemSlots, 0, sizeof(gSaveBlock1Ptr->bag.items));

    ASSUME(GetItemPocket(ITEM_POTION) == POCKET_ITEMS);

    // Two stacks of one item. additem() would merge them into a single slot, so build
    // the split by hand - it is the state a bag reaches through ordinary stack-limit
    // splitting, and the only state in which this bug is reachable.
    BagPocket_SetSlotItemIdAndCount(pocket, 0, ITEM_POTION, 5);
    BagPocket_SetSlotItemIdAndCount(pocket, 1, ITEM_POTION, 10);
    EXPECT_EQ(CountTotalItemQuantityInBag(ITEM_POTION), 15);

    EXPECT_EQ(RemoveBagItem(ITEM_POTION, 8), TRUE);

    // 15 - 8 = 7. The full `count` used to be charged against every matching slot, so
    // the first stack gave up all 5 AND the second gave up 8 - 13 removed, leaving 2.
    EXPECT_EQ(CountTotalItemQuantityInBag(ITEM_POTION), 7);

    // ...and the emptied first slot must not be left as a hole. The compaction guard
    // used to test `totalQuantity == count`, which is false here (15 != 8), so the
    // pocket kept a gap at slot 0 with the survivors stranded behind it.
    EXPECT_EQ(pocket->itemSlots[0].itemId, ITEM_POTION);
    EXPECT_EQ(pocket->itemSlots[0].quantity, 7);
    EXPECT_EQ(pocket->itemSlots[1].itemId, ITEM_NONE);
}

TEST("CheckPCHasItem sums matching stacks instead of requiring one slot to hold the full count")
{
    struct BagPocket pcPocket = { .id = POCKET_DUMMY, .capacity = PC_ITEMS_COUNT, .itemSlots = gSaveBlock1Ptr->pcItems };

    memset(gSaveBlock1Ptr->pcItems, 0, sizeof(gSaveBlock1Ptr->pcItems));

    ASSUME(GetItemPocket(ITEM_POTION) == POCKET_ITEMS);

    // Two stacks of one item. AddPCItem would merge them into a single slot, so build
    // the split by hand - it is the state the PC reaches through stack-limit splitting
    // or a partial withdraw from one of two stacks.
    BagPocket_SetSlotItemIdAndCount(&pcPocket, 0, ITEM_POTION, 5);
    BagPocket_SetSlotItemIdAndCount(&pcPocket, 1, ITEM_POTION, 10);

    // 5 + 10 = 15. The old check required a single slot >= count, so 12 was FALSE.
    EXPECT_EQ(CheckPCHasItem(ITEM_POTION, 12), TRUE);
    EXPECT_EQ(CheckPCHasItem(ITEM_POTION, 15), TRUE);
    EXPECT_EQ(CheckPCHasItem(ITEM_POTION, 16), FALSE);

    // count 0 is vacuously TRUE, matching BagPocket_CheckHasItem / CheckBagHasItem.
    EXPECT_EQ(CheckPCHasItem(ITEM_POTION, 0), TRUE);
    memset(gSaveBlock1Ptr->pcItems, 0, sizeof(gSaveBlock1Ptr->pcItems));
    EXPECT_EQ(CheckPCHasItem(ITEM_POTION, 0), TRUE);
    EXPECT_EQ(CheckPCHasItem(ITEM_POTION, 1), FALSE);
}

// Region merge (A1): helper for the dedup tests below - wipe every place a copy of an
// item can be "owned" so each assertion starts from a known-empty state.
static void ClearAllItemOwnership(void)
{
    memset(gBagPockets[POCKET_ITEMS].itemSlots, 0, sizeof(gSaveBlock1Ptr->bag.items));
    memset(gBagPockets[POCKET_KEY_ITEMS].itemSlots, 0, sizeof(gSaveBlock1Ptr->bag.keyItems));
    memset(gBagPockets[POCKET_TM_HM].itemSlots, 0, sizeof(gSaveBlock1Ptr->bag.TMsHMs));
    memset(gSaveBlock1Ptr->pcItems, 0, sizeof(gSaveBlock1Ptr->pcItems));

    for (u32 i = 0; i < PARTY_SIZE; i++)
        ZeroMonData(&gParties[B_TRAINER_PLAYER][i]);

    for (u32 boxId = 0; boxId < TOTAL_BOXES_COUNT; boxId++)
    {
        for (u32 boxPosition = 0; boxPosition < IN_BOX_COUNT; boxPosition++)
            ZeroBoxMonAt(boxId, boxPosition);
    }
}

// Puts a Wobbuffet holding itemId into the given party slot.
static void GiveTestMonHeldItem(u32 partySlot, enum Item itemId)
{
    u16 heldItem = itemId;

    CreateMon(&gParties[B_TRAINER_PLAYER][partySlot], SPECIES_WOBBUFFET, 5, 0, OTID_STRUCT_PRESET(0));
    SetMonData(&gParties[B_TRAINER_PLAYER][partySlot], MON_DATA_HELD_ITEM, &heldItem);
}

TEST("Multiple Exp. Shares stay obtainable - it is deliberately not key-class")
{
    // Six scripted sources across three regions hand out an Exp. Share (Devon Corp, Kanto
    // Route 15, Mr. Pokemon's House, the Violet City aide, the Goldenrod basement ball, and
    // either lottery - the lotteries being repeatable). With I_EXP_SHARE_ITEM == GEN_5 the
    // Exp. Share is an ordinary POCKET_ITEMS held item that only boosts the Pokemon carrying
    // it, so owning several is legitimate and every giver must hand over a real copy. This
    // test exists to stop it being re-classified as key-class - see issue #130, where that
    // cap was tried and then deliberately reverted. Note ITEM_EXP_SHARE_SMALL, used by the
    // Johto scripts, is a compat alias for the same id (include/constants/johto_compat_ids.h).
    ASSUME(GetItemPocket(ITEM_EXP_SHARE) == POCKET_ITEMS);
    ClearAllItemOwnership();
    EXPECT_EQ(IsDuplicateKeyClassItem(ITEM_EXP_SHARE), FALSE);

    // A copy in the bag does not block the next give - they stack.
    RUN_OVERWORLD_SCRIPT(
        additem ITEM_EXP_SHARE;
        additem ITEM_EXP_SHARE;
    );
    EXPECT_EQ(CountTotalItemQuantityInBag(ITEM_EXP_SHARE), 2);
    EXPECT_EQ(IsDuplicateKeyClassItem(ITEM_EXP_SHARE), FALSE);

    // Nor does one deposited in the item PC.
    EXPECT_EQ(RemoveBagItem(ITEM_EXP_SHARE, 2), TRUE);
    EXPECT_EQ(AddPCItem(ITEM_EXP_SHARE, 1), TRUE);
    EXPECT_EQ(IsDuplicateKeyClassItem(ITEM_EXP_SHARE), FALSE);
    memset(gSaveBlock1Ptr->pcItems, 0, sizeof(gSaveBlock1Ptr->pcItems));

    // Nor does one already attached to a Pokemon - the point of the item is that several
    // party members can each wear one.
    GiveTestMonHeldItem(PARTY_SIZE - 1, ITEM_EXP_SHARE);
    EXPECT_EQ(IsDuplicateKeyClassItem(ITEM_EXP_SHARE), FALSE);
    RUN_OVERWORLD_SCRIPT(
        additem ITEM_EXP_SHARE;
    );
    EXPECT_EQ(CountTotalItemQuantityInBag(ITEM_EXP_SHARE), 1);

    ClearAllItemOwnership();
}

TEST("Key-class dedup still covers HMs and key items, and leaves ordinary items alone")
{
    ASSUME(GetItemPocket(ITEM_HM01) == POCKET_TM_HM);
    ASSUME(GetItemPocket(ITEM_TM01) == POCKET_TM_HM);
    ASSUME(GetItemPocket(ITEM_LEFTOVERS) == POCKET_ITEMS);
    ASSUME(GetItemPocket(ITEM_SS_TICKET) == POCKET_KEY_ITEMS);
    ClearAllItemOwnership();

    // HMs still dedup...
    RUN_OVERWORLD_SCRIPT(
        additem ITEM_HM01;
        additem ITEM_HM01;
    );
    EXPECT_EQ(CountTotalItemQuantityInBag(ITEM_HM01), 1);

    // ...as do Key Items pocket entries...
    RUN_OVERWORLD_SCRIPT(
        additem ITEM_SS_TICKET;
        additem ITEM_SS_TICKET;
    );
    EXPECT_EQ(CountTotalItemQuantityInBag(ITEM_SS_TICKET), 1);

    // ...while TMs and ordinary held items are still stackable, and a Pokemon holding
    // one does not block a second.
    GiveTestMonHeldItem(0, ITEM_LEFTOVERS);
    EXPECT_EQ(IsDuplicateKeyClassItem(ITEM_LEFTOVERS), FALSE);
    RUN_OVERWORLD_SCRIPT(
        additem ITEM_LEFTOVERS;
        additem ITEM_LEFTOVERS;
        additem ITEM_TM01;
        additem ITEM_TM01;
    );
    EXPECT_EQ(CountTotalItemQuantityInBag(ITEM_LEFTOVERS), 2);
    EXPECT_GE(CountTotalItemQuantityInBag(ITEM_TM01), 1);

    // The Meteorite exemption survives: Cozmo and Two Island each give their own copy.
    RUN_OVERWORLD_SCRIPT(
        additem ITEM_METEORITE;
    );
    EXPECT_EQ(IsDuplicateKeyClassItem(ITEM_METEORITE), FALSE);

    ClearAllItemOwnership();
}

TEST("A key-class item held by a Pokemon still counts as owned")
{
    // Defence in depth for IsItemHeldByPlayerMon(): wearing a copy is owning it, so the
    // second giver must still refuse. No in-game path attaches an HM or a key item to a
    // Pokemon today (the bag's Give flow rejects importance-1 items), so the held item is
    // forced directly here. The guard is what keeps the invariant true if one ever does.
    ASSUME(GetItemPocket(ITEM_HM01) == POCKET_TM_HM);
    ClearAllItemOwnership();

    // Party sweep: use the LAST slot, so the whole party has to be scanned, not just the lead.
    GiveTestMonHeldItem(PARTY_SIZE - 1, ITEM_HM01);
    EXPECT_EQ(IsDuplicateKeyClassItem(ITEM_HM01), TRUE);
    RUN_OVERWORLD_SCRIPT(
        additem ITEM_HM01;
    );
    EXPECT_EQ(CountTotalItemQuantityInBag(ITEM_HM01), 0);

    // Box sweep: boxing the carrier does not launder the copy away.
    *GetBoxedMonPtr(TOTAL_BOXES_COUNT - 1, IN_BOX_COUNT - 1) = gParties[B_TRAINER_PLAYER][PARTY_SIZE - 1].box;
    ZeroMonData(&gParties[B_TRAINER_PLAYER][PARTY_SIZE - 1]);
    EXPECT_EQ(IsDuplicateKeyClassItem(ITEM_HM01), TRUE);

    ClearAllItemOwnership();
    EXPECT_EQ(IsDuplicateKeyClassItem(ITEM_HM01), FALSE);
}
