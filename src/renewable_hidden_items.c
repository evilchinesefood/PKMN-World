#include "global.h"
#include "event_data.h"
#include "random.h"
#include "renewable_hidden_items.h"
#include "constants/maps.h"

// FRLG's renewable hidden items (pokefirered src/renewable_hidden_items.c). Once the player has
// walked RENEWABLE_ITEM_STEPS steps, entering one of these maps hides every renewable item and
// then shows one sampled tier on each map.
#define RENEWABLE_ITEM_STEPS 1500
#define MAX_RENEWABLE_ITEMS_PER_TIER 8

enum RenewableTier
{
    RENEWABLE_RARE,     // 10%
    RENEWABLE_UNCOMMON, // 30%
    RENEWABLE_COMMON,   // 60%
    RENEWABLE_TIER_COUNT,
};

struct RenewableHiddenItems
{
    u16 map;
    u16 flags[RENEWABLE_TIER_COUNT][MAX_RENEWABLE_ITEMS_PER_TIER]; // a 0 ends the tier
};

static const struct RenewableHiddenItems sRenewableHiddenItems[] =
{
    {
        .map = MAP_ROUTE20,
        .flags = {
            [RENEWABLE_UNCOMMON] = {
                FLAG_HIDDEN_ITEM_ROUTE20_STARDUST,
            },
        },
    },
    {
        .map = MAP_ROUTE21_NORTH,
        .flags = {
            [RENEWABLE_UNCOMMON] = {
                FLAG_HIDDEN_ITEM_ROUTE21_NORTH_PEARL,
            },
        },
    },
    {
        .map = MAP_UNDERGROUND_PATH_NORTH_SOUTH_TUNNEL,
        .flags = {
            [RENEWABLE_RARE] = {
                FLAG_HIDDEN_ITEM_UNDERGROUND_PATH_NORTH_SOUTH_TUNNEL_ETHER,
            },
            [RENEWABLE_UNCOMMON] = {
                FLAG_HIDDEN_ITEM_UNDERGROUND_PATH_NORTH_SOUTH_TUNNEL_POTION,
                FLAG_HIDDEN_ITEM_UNDERGROUND_PATH_NORTH_SOUTH_TUNNEL_ANTIDOTE,
                FLAG_HIDDEN_ITEM_UNDERGROUND_PATH_NORTH_SOUTH_TUNNEL_PARALYZE_HEAL,
                FLAG_HIDDEN_ITEM_UNDERGROUND_PATH_NORTH_SOUTH_TUNNEL_AWAKENING,
                FLAG_HIDDEN_ITEM_UNDERGROUND_PATH_NORTH_SOUTH_TUNNEL_BURN_HEAL,
                FLAG_HIDDEN_ITEM_UNDERGROUND_PATH_NORTH_SOUTH_TUNNEL_ICE_HEAL,
            },
        },
    },
    {
        .map = MAP_UNDERGROUND_PATH_EAST_WEST_TUNNEL,
        .flags = {
            [RENEWABLE_RARE] = {
                FLAG_HIDDEN_ITEM_UNDERGROUND_PATH_EAST_WEST_TUNNEL_ETHER,
            },
            [RENEWABLE_UNCOMMON] = {
                FLAG_HIDDEN_ITEM_UNDERGROUND_PATH_EAST_WEST_TUNNEL_POTION,
                FLAG_HIDDEN_ITEM_UNDERGROUND_PATH_EAST_WEST_TUNNEL_ANTIDOTE,
                FLAG_HIDDEN_ITEM_UNDERGROUND_PATH_EAST_WEST_TUNNEL_PARALYZE_HEAL,
                FLAG_HIDDEN_ITEM_UNDERGROUND_PATH_EAST_WEST_TUNNEL_AWAKENING,
                FLAG_HIDDEN_ITEM_UNDERGROUND_PATH_EAST_WEST_TUNNEL_BURN_HEAL,
                FLAG_HIDDEN_ITEM_UNDERGROUND_PATH_EAST_WEST_TUNNEL_ICE_HEAL,
            },
        },
    },
    {
        .map = MAP_SEVEN_ISLAND_TANOBY_RUINS,
        .flags = {
            [RENEWABLE_RARE] = {
                FLAG_HIDDEN_ITEM_SEVEN_ISLAND_TANOBY_RUINS_HEART_SCALE_4,
                FLAG_HIDDEN_ITEM_SEVEN_ISLAND_TANOBY_RUINS_HEART_SCALE,
                FLAG_HIDDEN_ITEM_SEVEN_ISLAND_TANOBY_RUINS_HEART_SCALE_2,
                FLAG_HIDDEN_ITEM_SEVEN_ISLAND_TANOBY_RUINS_HEART_SCALE_3,
            },
        },
    },
    {
        .map = MAP_MT_MOON_B1F,
        .flags = {
            [RENEWABLE_RARE] = {
                FLAG_HIDDEN_ITEM_MT_MOON_B1F_TINY_MUSHROOM,
                FLAG_HIDDEN_ITEM_MT_MOON_B1F_TINY_MUSHROOM_2,
                FLAG_HIDDEN_ITEM_MT_MOON_B1F_TINY_MUSHROOM_3,
                FLAG_HIDDEN_ITEM_MT_MOON_B1F_BIG_MUSHROOM,
                FLAG_HIDDEN_ITEM_MT_MOON_B1F_BIG_MUSHROOM_2,
                FLAG_HIDDEN_ITEM_MT_MOON_B1F_BIG_MUSHROOM_3,
            },
            [RENEWABLE_UNCOMMON] = {
                FLAG_HIDDEN_ITEM_MT_MOON_B1F_TINY_MUSHROOM,
                FLAG_HIDDEN_ITEM_MT_MOON_B1F_TINY_MUSHROOM_2,
                FLAG_HIDDEN_ITEM_MT_MOON_B1F_TINY_MUSHROOM_3,
            },
        },
    },
    {
        .map = MAP_THREE_ISLAND_BERRY_FOREST,
        .flags = {
            [RENEWABLE_RARE] = {
                FLAG_HIDDEN_ITEM_THREE_ISLAND_BERRY_FOREST_BLUK_BERRY,
                FLAG_HIDDEN_ITEM_THREE_ISLAND_BERRY_FOREST_WEPEAR_BERRY,
                FLAG_HIDDEN_ITEM_THREE_ISLAND_BERRY_FOREST_ORAN_BERRY,
                FLAG_HIDDEN_ITEM_THREE_ISLAND_BERRY_FOREST_CHERI_BERRY,
                FLAG_HIDDEN_ITEM_THREE_ISLAND_BERRY_FOREST_ASPEAR_BERRY,
                FLAG_HIDDEN_ITEM_THREE_ISLAND_BERRY_FOREST_PERSIM_BERRY,
                FLAG_HIDDEN_ITEM_THREE_ISLAND_BERRY_FOREST_PINAP_BERRY,
                FLAG_HIDDEN_ITEM_THREE_ISLAND_BERRY_FOREST_LUM_BERRY,
            },
            [RENEWABLE_UNCOMMON] = {
                FLAG_HIDDEN_ITEM_THREE_ISLAND_BERRY_FOREST_BLUK_BERRY,
                FLAG_HIDDEN_ITEM_THREE_ISLAND_BERRY_FOREST_WEPEAR_BERRY,
                FLAG_HIDDEN_ITEM_THREE_ISLAND_BERRY_FOREST_ORAN_BERRY,
                FLAG_HIDDEN_ITEM_THREE_ISLAND_BERRY_FOREST_CHERI_BERRY,
                FLAG_HIDDEN_ITEM_THREE_ISLAND_BERRY_FOREST_ASPEAR_BERRY,
                FLAG_HIDDEN_ITEM_THREE_ISLAND_BERRY_FOREST_PERSIM_BERRY,
                FLAG_HIDDEN_ITEM_THREE_ISLAND_BERRY_FOREST_PINAP_BERRY,
            },
            [RENEWABLE_COMMON] = {
                FLAG_HIDDEN_ITEM_THREE_ISLAND_BERRY_FOREST_RAZZ_BERRY,
                FLAG_HIDDEN_ITEM_THREE_ISLAND_BERRY_FOREST_NANAB_BERRY,
                FLAG_HIDDEN_ITEM_THREE_ISLAND_BERRY_FOREST_CHESTO_BERRY,
                FLAG_HIDDEN_ITEM_THREE_ISLAND_BERRY_FOREST_PECHA_BERRY,
                FLAG_HIDDEN_ITEM_THREE_ISLAND_BERRY_FOREST_RAWST_BERRY,
            },
        },
    },
    {
        .map = MAP_ONE_ISLAND_TREASURE_BEACH,
        .flags = {
            [RENEWABLE_RARE] = {
                FLAG_HIDDEN_ITEM_ONE_ISLAND_TREASURE_BEACH_ULTRA_BALL,
                FLAG_HIDDEN_ITEM_ONE_ISLAND_TREASURE_BEACH_ULTRA_BALL_2,
                FLAG_HIDDEN_ITEM_ONE_ISLAND_TREASURE_BEACH_STAR_PIECE,
                FLAG_HIDDEN_ITEM_ONE_ISLAND_TREASURE_BEACH_BIG_PEARL,
            },
            [RENEWABLE_UNCOMMON] = {
                FLAG_HIDDEN_ITEM_ONE_ISLAND_TREASURE_BEACH_STARDUST,
                FLAG_HIDDEN_ITEM_ONE_ISLAND_TREASURE_BEACH_STARDUST_2,
                FLAG_HIDDEN_ITEM_ONE_ISLAND_TREASURE_BEACH_PEARL,
                FLAG_HIDDEN_ITEM_ONE_ISLAND_TREASURE_BEACH_PEARL_2,
                FLAG_HIDDEN_ITEM_ONE_ISLAND_TREASURE_BEACH_ULTRA_BALL,
                FLAG_HIDDEN_ITEM_ONE_ISLAND_TREASURE_BEACH_ULTRA_BALL_2,
            },
            [RENEWABLE_COMMON] = {
                FLAG_HIDDEN_ITEM_ONE_ISLAND_TREASURE_BEACH_ULTRA_BALL,
                FLAG_HIDDEN_ITEM_ONE_ISLAND_TREASURE_BEACH_ULTRA_BALL_2,
            },
        },
    },
    {
        .map = MAP_THREE_ISLAND_BOND_BRIDGE,
        .flags = {
            [RENEWABLE_UNCOMMON] = {
                FLAG_HIDDEN_ITEM_THREE_ISLAND_BOND_BRIDGE_PEARL,
                FLAG_HIDDEN_ITEM_THREE_ISLAND_BOND_BRIDGE_STARDUST,
            },
        },
    },
    {
        .map = MAP_FOUR_ISLAND,
        .flags = {
            [RENEWABLE_UNCOMMON] = {
                FLAG_HIDDEN_ITEM_FOUR_ISLAND_PEARL,
            },
            [RENEWABLE_COMMON] = {
                FLAG_HIDDEN_ITEM_FOUR_ISLAND_ULTRA_BALL,
            },
        },
    },
    {
        .map = MAP_FIVE_ISLAND_MEMORIAL_PILLAR,
        .flags = {
            [RENEWABLE_RARE] = {
                FLAG_HIDDEN_ITEM_FIVE_ISLAND_MEMORIAL_PILLAR_BIG_PEARL,
            },
        },
    },
    {
        .map = MAP_FIVE_ISLAND_RESORT_GORGEOUS,
        .flags = {
            [RENEWABLE_RARE] = {
                FLAG_HIDDEN_ITEM_FIVE_ISLAND_RESORT_GORGEOUS_NEST_BALL,
                FLAG_HIDDEN_ITEM_FIVE_ISLAND_RESORT_GORGEOUS_STAR_PIECE,
            },
            [RENEWABLE_UNCOMMON] = {
                FLAG_HIDDEN_ITEM_FIVE_ISLAND_RESORT_GORGEOUS_STARDUST,
                FLAG_HIDDEN_ITEM_FIVE_ISLAND_RESORT_GORGEOUS_STARDUST_2,
            },
        },
    },
    {
        .map = MAP_SIX_ISLAND_OUTCAST_ISLAND,
        .flags = {
            [RENEWABLE_RARE] = {
                FLAG_HIDDEN_ITEM_SIX_ISLAND_OUTCAST_ISLAND_STAR_PIECE,
                FLAG_HIDDEN_ITEM_SIX_ISLAND_OUTCAST_ISLAND_NET_BALL,
            },
        },
    },
    {
        .map = MAP_SIX_ISLAND_GREEN_PATH,
        .flags = {
            [RENEWABLE_COMMON] = {
                FLAG_HIDDEN_ITEM_SIX_ISLAND_GREEN_PATH_ULTRA_BALL,
            },
        },
    },
    {
        .map = MAP_SEVEN_ISLAND_TRAINER_TOWER,
        .flags = {
            [RENEWABLE_RARE] = {
                FLAG_HIDDEN_ITEM_SEVEN_ISLAND_TRAINER_TOWER_BIG_PEARL,
            },
            [RENEWABLE_UNCOMMON] = {
                FLAG_HIDDEN_ITEM_SEVEN_ISLAND_TRAINER_TOWER_PEARL,
            },
        },
    },
};

static bool32 IsRenewableItemMap(void)
{
    u32 i;

    for (i = 0; i < ARRAY_COUNT(sRenewableHiddenItems); i++)
    {
        if (MAP_GROUP(sRenewableHiddenItems[i].map) == gSaveBlock1Ptr->location.mapGroup
         && MAP_NUM(sRenewableHiddenItems[i].map) == gSaveBlock1Ptr->location.mapNum)
            return TRUE;
    }
    return FALSE;
}

static enum RenewableTier SampleRenewableTier(void)
{
    u32 roll = Random() % 100;

    if (roll >= 90)
        return RENEWABLE_RARE;
    if (roll >= 60)
        return RENEWABLE_UNCOMMON;
    return RENEWABLE_COMMON;
}

void SetAllRenewableItemFlags(void)
{
    u32 i, tier, j;

    for (i = 0; i < ARRAY_COUNT(sRenewableHiddenItems); i++)
    {
        for (tier = 0; tier < RENEWABLE_TIER_COUNT; tier++)
        {
            const u16 *flags = sRenewableHiddenItems[i].flags[tier];
            for (j = 0; j < MAX_RENEWABLE_ITEMS_PER_TIER && flags[j] != 0; j++)
                FlagSet(flags[j]);
        }
    }
}

static void ShowSampledRenewableItems(void)
{
    u32 i, j;

    for (i = 0; i < ARRAY_COUNT(sRenewableHiddenItems); i++)
    {
        const u16 *flags = sRenewableHiddenItems[i].flags[SampleRenewableTier()];
        for (j = 0; j < MAX_RENEWABLE_ITEMS_PER_TIER && flags[j] != 0; j++)
            FlagClear(flags[j]);
    }
}

void IncrementRenewableHiddenItemStepCounter(void)
{
    u16 steps = VarGet(VAR_RENEWABLE_ITEM_STEP_COUNTER);

    if (steps < RENEWABLE_ITEM_STEPS)
        VarSet(VAR_RENEWABLE_ITEM_STEP_COUNTER, steps + 1);
}

void TryRegenerateRenewableHiddenItems(void)
{
    if (IsRenewableItemMap() && VarGet(VAR_RENEWABLE_ITEM_STEP_COUNTER) >= RENEWABLE_ITEM_STEPS)
    {
        VarSet(VAR_RENEWABLE_ITEM_STEP_COUNTER, 0);
        SetAllRenewableItemFlags();
        ShowSampledRenewableItems();
    }
}
