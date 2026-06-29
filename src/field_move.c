#include "global.h"
#include "event_data.h"
#include "field_move.h"
#include "fldeff.h"
#include "fldeff_misc.h"
#include "item.h"
#include "party_menu.h"
#include "regions.h"
#include "constants/field_move.h"
#include "constants/items.h"
#include "constants/moves.h"
#include "constants/party_menu.h"

static bool32 IsFieldMoveUnlocked_Cut(void)
{
#if QOL_FIELD_MOVES_ITEM_GATE
    if (CheckBagHasItem(gFieldMoveInfo[FIELD_MOVE_CUT].toolItemId, 1))
        return TRUE;
#endif
    {
        enum Region region = GetCurrentRegion();
        return HasBadge(region, region == REGION_KANTO ? 1 : 0); // Kanto Cascade / else 1st gym
    }
}

static bool32 IsFieldMoveUnlocked_Flash(void)
{
    enum Region region = GetCurrentRegion();
    return HasBadge(region, region == REGION_KANTO ? 0 : 1); // Kanto Boulder / else 2nd gym
}

static bool32 IsFieldMoveUnlocked_RockSmash(void)
{
#if QOL_FIELD_MOVES_ITEM_GATE
    if (CheckBagHasItem(gFieldMoveInfo[FIELD_MOVE_ROCK_SMASH].toolItemId, 1))
        return TRUE;
#endif
    {
        enum Region region = GetCurrentRegion();
        return HasBadge(region, region == REGION_KANTO ? 5 : 2); // Kanto Marsh / else 3rd gym
    }
}

static bool32 IsFieldMoveUnlocked_Strength(void)
{
#if QOL_FIELD_MOVES_ITEM_GATE
    if (CheckBagHasItem(gFieldMoveInfo[FIELD_MOVE_STRENGTH].toolItemId, 1))
        return TRUE;
#endif
    return HasCurrentRegionBadge(3); // 4th gym in every region
}

static bool32 IsFieldMoveUnlocked_Surf(void)
{
#if QOL_FIELD_MOVES_ITEM_GATE
    if (CheckBagHasItem(gFieldMoveInfo[FIELD_MOVE_SURF].toolItemId, 1))
        return TRUE;
#endif
    return HasCurrentRegionBadge(4); // 5th gym in every region
}

static bool32 IsFieldMoveUnlocked_Fly(void)
{
    enum Region region = GetCurrentRegion();
    return HasBadge(region, region == REGION_KANTO ? 2 : 5); // Kanto Thunder / else 6th gym
}

static bool32 IsFieldMoveUnlocked_Dive(void)
{
#if QOL_FIELD_MOVES_ITEM_GATE
    if (CheckBagHasItem(gFieldMoveInfo[FIELD_MOVE_DIVE].toolItemId, 1))
        return TRUE;
#endif
    return HasCurrentRegionBadge(6); // 7th gym (Hoenn Mind Badge); Kanto/Johto unused but consistent
}

static bool32 IsFieldMoveUnlocked_Waterfall(void)
{
#if QOL_FIELD_MOVES_ITEM_GATE
    if (CheckBagHasItem(gFieldMoveInfo[FIELD_MOVE_WATERFALL].toolItemId, 1))
        return TRUE;
#endif
    {
        enum Region region = GetCurrentRegion();
        return HasBadge(region, region == REGION_KANTO ? 6 : 7); // Kanto Volcano / else 8th gym
    }
}

static bool32 IsFieldMoveUnlocked_RockClimb(void)
{
    return OW_ROCK_CLIMB_FIELD_MOVE;
}

static bool32 IsFieldMoveUnlocked_Teleport(void)
{
    return TRUE;
}

static bool32 IsFieldMoveUnlocked_Dig(void)
{
    return TRUE;
}

static bool32 IsFieldMoveUnlocked_SecretPower(void)
{
    return TRUE;
}

static bool32 IsFieldMoveUnlocked_MilkDrink(void)
{
    return TRUE;
}

static bool32 IsFieldMoveUnlocked_SoftBoiled(void)
{
    return TRUE;
}

static bool32 IsFieldMoveUnlocked_SweetScent(void)
{
    return TRUE;
}

static bool32 IsFieldMoveUnlocked_Defog(void)
{
    return OW_DEFOG_FIELD_MOVE;
}

const struct FieldMoveInfo gFieldMoveInfo[FIELD_MOVES_COUNT] =
{
    [FIELD_MOVE_CUT] =
    {
        .fieldMoveFunc = SetUpFieldMove_Cut,
        .isUnlockedFunc = IsFieldMoveUnlocked_Cut,
        .moveID = MOVE_CUT,
        .partyMsgID = PARTY_MSG_NOTHING_TO_CUT,
#if QOL_FIELD_MOVES_ITEM_GATE
        .toolItemId = ITEM_CUT_TOOL,
#endif
    },

    [FIELD_MOVE_FLASH] =
    {
        .fieldMoveFunc = SetUpFieldMove_Flash,
        .isUnlockedFunc = IsFieldMoveUnlocked_Flash,
        .moveID = MOVE_FLASH,
        .partyMsgID = PARTY_MSG_CANT_USE_HERE,
    },

    [FIELD_MOVE_ROCK_SMASH] =
    {
        .fieldMoveFunc = SetUpFieldMove_RockSmash,
        .isUnlockedFunc = IsFieldMoveUnlocked_RockSmash,
        .moveID = MOVE_ROCK_SMASH,
        .partyMsgID = PARTY_MSG_CANT_USE_HERE,
#if QOL_FIELD_MOVES_ITEM_GATE
        .toolItemId = ITEM_ROCK_SMASH_TOOL,
#endif
    },

    [FIELD_MOVE_STRENGTH] =
    {
        .fieldMoveFunc = SetUpFieldMove_Strength,
        .isUnlockedFunc = IsFieldMoveUnlocked_Strength,
        .moveID = MOVE_STRENGTH,
        .partyMsgID = PARTY_MSG_CANT_USE_HERE,
#if QOL_FIELD_MOVES_ITEM_GATE
        .toolItemId = ITEM_STRENGTH_TOOL,
#endif
    },

    [FIELD_MOVE_SURF] =
    {
        .fieldMoveFunc = SetUpFieldMove_Surf,
        .isUnlockedFunc = IsFieldMoveUnlocked_Surf,
        .moveID = MOVE_SURF,
        .partyMsgID = PARTY_MSG_CANT_SURF_HERE,
#if QOL_FIELD_MOVES_ITEM_GATE
        .toolItemId = ITEM_SURF_TOOL,
#endif
    },

    [FIELD_MOVE_FLY] =
    {
        .fieldMoveFunc = SetUpFieldMove_Fly,
        .isUnlockedFunc = IsFieldMoveUnlocked_Fly,
        .moveID = MOVE_FLY,
        .partyMsgID = PARTY_MSG_CANT_USE_HERE,
    },

    [FIELD_MOVE_DIVE] =
    {
        .fieldMoveFunc = SetUpFieldMove_Dive,
        .isUnlockedFunc = IsFieldMoveUnlocked_Dive,
        .moveID = MOVE_DIVE,
        .partyMsgID = PARTY_MSG_CANT_USE_HERE,
#if QOL_FIELD_MOVES_ITEM_GATE
        .toolItemId = ITEM_DIVE_TOOL,
#endif
    },

    [FIELD_MOVE_WATERFALL] =
    {
        .fieldMoveFunc = SetUpFieldMove_Waterfall,
        .isUnlockedFunc = IsFieldMoveUnlocked_Waterfall,
        .moveID = MOVE_WATERFALL,
        .partyMsgID = PARTY_MSG_CANT_USE_HERE,
#if QOL_FIELD_MOVES_ITEM_GATE
        .toolItemId = ITEM_WATERFALL_TOOL,
#endif
    },

    [FIELD_MOVE_TELEPORT] =
    {
        .fieldMoveFunc = SetUpFieldMove_Teleport,
        .isUnlockedFunc = IsFieldMoveUnlocked_Teleport,
        .moveID = MOVE_TELEPORT,
        .partyMsgID = PARTY_MSG_CANT_USE_HERE,
    },

    [FIELD_MOVE_DIG] =
    {
        .fieldMoveFunc = SetUpFieldMove_Dig,
        .isUnlockedFunc = IsFieldMoveUnlocked_Dig,
        .moveID = MOVE_DIG,
        .partyMsgID = PARTY_MSG_CANT_USE_HERE,
    },

    [FIELD_MOVE_SECRET_POWER] =
    {
        .fieldMoveFunc = SetUpFieldMove_SecretPower,
        .isUnlockedFunc = IsFieldMoveUnlocked_SecretPower,
        .moveID = MOVE_SECRET_POWER,
        .partyMsgID = PARTY_MSG_CANT_USE_HERE,
    },

    [FIELD_MOVE_MILK_DRINK] =
    {
        .fieldMoveFunc = SetUpFieldMove_SoftBoiled,
        .isUnlockedFunc = IsFieldMoveUnlocked_MilkDrink,
        .moveID = MOVE_MILK_DRINK,
        .partyMsgID = PARTY_MSG_NOT_ENOUGH_HP,
    },

    [FIELD_MOVE_SOFT_BOILED] =
    {
        .fieldMoveFunc = SetUpFieldMove_SoftBoiled,
        .isUnlockedFunc = IsFieldMoveUnlocked_SoftBoiled,
        .moveID = MOVE_SOFT_BOILED,
        .partyMsgID = PARTY_MSG_NOT_ENOUGH_HP,
    },

    [FIELD_MOVE_SWEET_SCENT] =
    {
        .fieldMoveFunc = SetUpFieldMove_SweetScent,
        .isUnlockedFunc = IsFieldMoveUnlocked_SweetScent,
        .moveID = MOVE_SWEET_SCENT,
        .partyMsgID = PARTY_MSG_CANT_USE_HERE,
    },
    [FIELD_MOVE_ROCK_CLIMB] =
    {
        .fieldMoveFunc = SetUpFieldMove_RockClimb,
        .isUnlockedFunc = IsFieldMoveUnlocked_RockClimb,
        .moveID = MOVE_ROCK_CLIMB,
        .partyMsgID = PARTY_MSG_CANT_USE_HERE,
    },
    [FIELD_MOVE_DEFOG] =
    {
        .fieldMoveFunc = SetUpFieldMove_Defog,
        .isUnlockedFunc = IsFieldMoveUnlocked_Defog,
        .moveID = MOVE_DEFOG,
        .partyMsgID = PARTY_MSG_CANT_USE_HERE,
    },
};
