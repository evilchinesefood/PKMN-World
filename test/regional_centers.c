#include "global.h"
#include "battle.h"
#include "event_data.h"
#include "item.h"
#include "pokemon.h"
#include "regional_centers.h"
#include "regions.h"
#include "test/test.h"

static void SetAllRegionalBadges(void)
{
    u32 region, badge;

    for (region = REGION_KANTO; region <= REGION_HOENN; region++)
        for (badge = 0; badge < NUM_BADGES; badge++)
            FlagSet(GetBadgeFlag(region, badge));
}

static void MakeTravelParty(struct Pokemon *party)
{
    CreateMon(&party[0], SPECIES_LAPRAS, 30, 1, OTID_STRUCT_PLAYER_ID);
    SetMonMoveSlot(&party[0], MOVE_SURF, 0);
    SetMonMoveSlot(&party[0], MOVE_DIVE, 1);
    SetMonMoveSlot(&party[0], MOVE_WATERFALL, 2);
    CreateMon(&party[1], SPECIES_CHARIZARD, 36, 2, OTID_STRUCT_PLAYER_ID);
    SetMonMoveSlot(&party[1], MOVE_FLY, 0);
}

TEST("Regional Centers cover all campaign nurse locations with distinct stable identities")
{
    struct Pokemon party[PARTY_SIZE] = {0};
    u32 id, regionCounts[REGIONS_COUNT] = {0};

    SetAllRegionalBadges();
    MakeTravelParty(party);
    VarSet(VAR_MAP_SCENE_ONE_ISLAND_POKEMON_CENTER_1F, 7);
    VarSet(VAR_MAP_SCENE_CINNABAR_ISLAND, 4);
    VarSet(VAR_MAP_SCENE_SIX_ISLAND_POKEMON_CENTER_1F, 1);
    VarSet(VAR_MAP_SCENE_FOUR_ISLAND, 1);
    VarSet(VAR_MAP_SCENE_ROUTE5_ROUTE6_ROUTE7_ROUTE8_GATES, 1);
    VarSet(VAR_ECRUTEAK_CITY_THEATER, 8);
    VarSet(VAR_LEAGUE_STATE, 1);
    FlagSet(FLAG_INDIGOJUNCTION_HIDE_SILVER_GUARD);

    EXPECT_EQ(RegionalCenter_Count(), 48);
    for (id = 1; id <= RegionalCenter_Count(); id++)
    {
        const struct RegionalCenterInfo *center = RegionalCenter_GetInfo(id);
        struct WarpData warp = {0};
        u16 heal = 0;

        EXPECT(center != NULL);
        EXPECT_EQ(RegionalCenter_ForMap(center->arrival.mapGroup, center->arrival.mapNum), id);
        EXPECT(RegionalCenter_GetDestination(id, &warp, &heal));
        EXPECT_EQ(warp.warpId, WARP_ID_NONE);
        EXPECT(heal != 0);
        EXPECT(RegionalCenter_IsSafe(id, center->region, party, 2));
        EXPECT(!RegionalCenter_IsSafe(id, REGION_NONE, party, 2));
        regionCounts[center->region]++;
    }
    EXPECT_EQ(regionCounts[REGION_HOENN], 16);
    EXPECT_EQ(regionCounts[REGION_KANTO], 19);
    EXPECT_EQ(regionCounts[REGION_JOHTO], 13);
    EXPECT_EQ(RegionalCenter_ForMap(MAP_GROUP(MAP_CIANWOOD_POKECENTER), MAP_NUM(MAP_CIANWOOD_POKECENTER)), 43);
    EXPECT_EQ(RegionalCenter_ForMap(MAP_GROUP(MAP_EVER_GRANDE_CITY_POKEMON_LEAGUE_1F), MAP_NUM(MAP_EVER_GRANDE_CITY_POKEMON_LEAGUE_1F)), 16);
    EXPECT_EQ(RegionalCenter_ForMap(MAP_GROUP(MAP_REGION_HUB), MAP_NUM(MAP_REGION_HUB)), 0);
    EXPECT_EQ(RegionalCenter_ForMap(MAP_GROUP(MAP_BATTLE_FRONTIER_POKEMON_CENTER_1F), MAP_NUM(MAP_BATTLE_FRONTIER_POKEMON_CENTER_1F)), 0);
    EXPECT_EQ(RegionalCenter_ForMap(MAP_GROUP(MAP_OLDALE_TOWN_POKEMON_CENTER_2F), MAP_NUM(MAP_OLDALE_TOWN_POKEMON_CENTER_2F)), 0);
}

TEST("Regional Centers reject invalid IDs without changing destination output")
{
    struct WarpData warp = {1, 2, 3, 4, 5};
    struct WarpData before = warp;
    u16 heal = 123;

    EXPECT(!RegionalCenter_GetDestination(0, &warp, &heal));
    EXPECT(!RegionalCenter_GetDestination(65535, &warp, &heal));
    EXPECT_EQ(memcmp(&warp, &before, sizeof(warp)), 0);
    EXPECT_EQ(heal, 123);
    EXPECT_EQ(RegionalCenter_GetRegion(65535), REGION_NONE);
    EXPECT(RegionalCenter_GetName(0) == NULL);
}

TEST("Regional Center water access uses the destination campaign and proposed party")
{
    struct Pokemon proposed[PARTY_SIZE] = {0};
    struct Pokemon before[PARTY_SIZE];
    u16 cianwood = RegionalCenter_ForMap(MAP_GROUP(MAP_CIANWOOD_POKECENTER), MAP_NUM(MAP_CIANWOOD_POKECENTER));
    u32 isEgg = TRUE;

    SetBagItemsPointers();
    ClearBag();
    CreateMon(&proposed[0], SPECIES_SQUIRTLE, 20, 1, OTID_STRUCT_PLAYER_ID);
    SetMonMoveSlot(&proposed[0], MOVE_SURF, 0);
    CreateMon(&gParties[B_TRAINER_PLAYER][0], SPECIES_CATERPIE, 5, 2, OTID_STRUCT_PLAYER_ID);
    gPartiesCount[B_TRAINER_PLAYER] = 1;
    memcpy(before, gParties[B_TRAINER_PLAYER], sizeof(before));
    gCurrentRegion = REGION_HOENN;
    FlagSet(GetBadgeFlag(REGION_HOENN, 4));
    EXPECT(!RegionalCenter_IsSafe(cianwood, REGION_JOHTO, proposed, 1));
    FlagSet(GetBadgeFlag(REGION_JOHTO, 3));
    EXPECT(RegionalCenter_IsSafe(cianwood, REGION_JOHTO, proposed, 1));
    EXPECT(!RegionalCenter_IsSafe(cianwood, REGION_JOHTO, gParties[B_TRAINER_PLAYER], 1));
    EXPECT_EQ(gCurrentRegion, REGION_HOENN);
    EXPECT_EQ(memcmp(before, gParties[B_TRAINER_PLAYER], sizeof(before)), 0);
    EXPECT_EQ(GetMonData(&proposed[0], MON_DATA_MOVE1), MOVE_SURF);
    SetMonData(&proposed[0], MON_DATA_IS_EGG, &isEgg);
    EXPECT(!RegionalCenter_IsSafe(cianwood, REGION_JOHTO, proposed, 1));
}

TEST("Regional Center Surf tools retain the configured party capability rule")
{
    struct Pokemon party[PARTY_SIZE] = {0};
    u16 cianwood = RegionalCenter_ForMap(MAP_GROUP(MAP_CIANWOOD_POKECENTER), MAP_NUM(MAP_CIANWOOD_POKECENTER));

    SetBagItemsPointers();
    ClearBag();
    CreateMon(&party[0], SPECIES_SQUIRTLE, 20, 1, OTID_STRUCT_PLAYER_ID);
    SetMonMoveSlot(&party[0], MOVE_SURF, 0);
    EXPECT(AddBagItem(ITEM_SURF_TOOL, 1));
#if QOL_FIELD_MOVES_ITEM_GATE
    EXPECT(RegionalCenter_IsSafe(cianwood, REGION_JOHTO, party, 1));
#else
    EXPECT(!RegionalCenter_IsSafe(cianwood, REGION_JOHTO, party, 1));
#endif
    CreateMon(&party[0], SPECIES_CATERPIE, 5, 2, OTID_STRUCT_PLAYER_ID);
    EXPECT(!RegionalCenter_IsSafe(cianwood, REGION_JOHTO, party, 1));
}

TEST("Regional Centers reject pending Sevii arrival scenes without advancing them")
{
    struct Pokemon party[PARTY_SIZE] = {0};

    MakeTravelParty(party);
    VarSet(VAR_MAP_SCENE_CINNABAR_ISLAND, 4);
    EXPECT(!RegionalCenter_IsSafe(29, REGION_KANTO, party, 2));
    VarSet(VAR_MAP_SCENE_ONE_ISLAND_POKEMON_CENTER_1F, 1);
    EXPECT(RegionalCenter_IsSafe(29, REGION_KANTO, party, 2));
    EXPECT(RegionalCenter_IsSafe(30, REGION_KANTO, party, 2));
    EXPECT(RegionalCenter_IsSafe(31, REGION_KANTO, party, 2));
    EXPECT(!RegionalCenter_IsSafe(32, REGION_KANTO, party, 2));
    VarSet(VAR_MAP_SCENE_ONE_ISLAND_POKEMON_CENTER_1F, 5);
    EXPECT(!RegionalCenter_IsSafe(32, REGION_KANTO, party, 2));
    EXPECT(RegionalCenter_IsSafe(33, REGION_KANTO, party, 2));
    EXPECT(RegionalCenter_IsSafe(34, REGION_KANTO, party, 2));
    VarSet(VAR_MAP_SCENE_FOUR_ISLAND, 1);
    EXPECT(RegionalCenter_IsSafe(32, REGION_KANTO, party, 2));
    EXPECT(!RegionalCenter_IsSafe(35, REGION_KANTO, party, 2));
    VarSet(VAR_MAP_SCENE_SIX_ISLAND_POKEMON_CENTER_1F, 1);
    EXPECT(RegionalCenter_IsSafe(35, REGION_KANTO, party, 2));
    VarSet(VAR_MAP_SCENE_ONE_ISLAND_POKEMON_CENTER_1F, 6);
    EXPECT(!RegionalCenter_IsSafe(29, REGION_KANTO, party, 2));
    EXPECT_EQ(VarGet(VAR_MAP_SCENE_ONE_ISLAND_POKEMON_CENTER_1F), 6);
}

TEST("Regional Centers preserve League and mountain admission gates")
{
    struct Pokemon party[PARTY_SIZE] = {0};

    MakeTravelParty(party);
    EXPECT(!RegionalCenter_IsSafe(16, REGION_HOENN, party, 2));
    EXPECT(!RegionalCenter_IsSafe(25, REGION_KANTO, party, 2));
    EXPECT(!RegionalCenter_IsSafe(48, REGION_JOHTO, party, 2));
    SetAllRegionalBadges();
    EXPECT(RegionalCenter_IsSafe(16, REGION_HOENN, party, 2));
    EXPECT(RegionalCenter_IsSafe(25, REGION_KANTO, party, 2));
    EXPECT(!RegionalCenter_IsSafe(48, REGION_JOHTO, party, 2));
    VarSet(VAR_ECRUTEAK_CITY_THEATER, 8);
    EXPECT(!RegionalCenter_IsSafe(48, REGION_JOHTO, party, 2));
    VarSet(VAR_LEAGUE_STATE, 1);
    EXPECT(RegionalCenter_IsSafe(48, REGION_JOHTO, party, 2));
    VarSet(VAR_LEAGUE_STATE, 3);
    EXPECT(!RegionalCenter_IsSafe(48, REGION_JOHTO, party, 2));
    EXPECT_EQ(VarGet(VAR_LEAGUE_STATE), 3);
    EXPECT(!RegionalCenter_IsSafe(47, REGION_JOHTO, party, 2));
    FlagSet(FLAG_INDIGOJUNCTION_HIDE_SILVER_GUARD);
    EXPECT(RegionalCenter_IsSafe(47, REGION_JOHTO, party, 2));
    EXPECT(!RegionalCenter_IsSafe(26, REGION_KANTO, party, 2));
    VarSet(VAR_MAP_SCENE_ROUTE5_ROUTE6_ROUTE7_ROUTE8_GATES, 1);
    EXPECT(RegionalCenter_IsSafe(26, REGION_KANTO, party, 2));
}

TEST("Regional Centers refuse an unsafe island exit or active forced voyage")
{
    struct Pokemon party[PARTY_SIZE] = {0};
    u32 state;

    SetBagItemsPointers();
    ClearBag();
    CreateMon(&party[0], SPECIES_CATERPIE, 5, 1, OTID_STRUCT_PLAYER_ID);
    FlagSet(FLAG_HIDE_MR_BRINEY_DEWFORD_TOWN);
    FlagSet(FLAG_HIDE_MR_BRINEY_BOAT_DEWFORD_TOWN);
    EXPECT(!RegionalCenter_IsSafe(11, REGION_HOENN, party, 1));
    FlagClear(FLAG_HIDE_MR_BRINEY_DEWFORD_TOWN);
    FlagClear(FLAG_HIDE_MR_BRINEY_BOAT_DEWFORD_TOWN);
    EXPECT(RegionalCenter_IsSafe(11, REGION_HOENN, party, 1));
    EXPECT(!RegionalCenter_IsSafe(7, REGION_HOENN, party, 1));
    EXPECT(!RegionalCenter_IsSafe(8, REGION_HOENN, party, 1));
    EXPECT(!RegionalCenter_IsSafe(9, REGION_HOENN, party, 1));
    EXPECT(!RegionalCenter_IsSafe(15, REGION_HOENN, party, 1));
    // Safari Zone Gate shares Cianwood's landmass: no way to mainland Johto without Surf or Fly.
    EXPECT(!RegionalCenter_IsSafe(46, REGION_JOHTO, party, 1));
    // The west shore is cut off while Mr. Briney is docked elsewhere and Rusturf Tunnel is shut.
    VarSet(VAR_BRINEY_LOCATION, 1);
    EXPECT(RegionalCenter_IsSafe(1, REGION_HOENN, party, 1));
    EXPECT(RegionalCenter_IsSafe(4, REGION_HOENN, party, 1));
    EXPECT(RegionalCenter_IsSafe(10, REGION_HOENN, party, 1));
    for (state = 2; state <= 3; state++)
    {
        VarSet(VAR_BRINEY_LOCATION, state);
        EXPECT(!RegionalCenter_IsSafe(1, REGION_HOENN, party, 1));
        EXPECT(!RegionalCenter_IsSafe(4, REGION_HOENN, party, 1));
        EXPECT(!RegionalCenter_IsSafe(10, REGION_HOENN, party, 1));
        EXPECT(RegionalCenter_IsSafe(2, REGION_HOENN, party, 1));
    }
    FlagSet(FLAG_RUSTURF_TUNNEL_OPENED);
    EXPECT(RegionalCenter_IsSafe(4, REGION_HOENN, party, 1));
    FlagClear(FLAG_RUSTURF_TUNNEL_OPENED);
    SetAllRegionalBadges();
    MakeTravelParty(party);
    for (state = 1; state < 6; state++)
    {
        VarSet(VAR_SOOTOPOLIS_CITY_STATE, state);
        EXPECT(!RegionalCenter_IsSafe(8, REGION_HOENN, party, 2));
    }
    VarSet(VAR_SOOTOPOLIS_CITY_STATE, 6);
    EXPECT(RegionalCenter_IsSafe(8, REGION_HOENN, party, 2));
    VarSet(VAR_SKY_PILLAR_STATE, 1);
    EXPECT(!RegionalCenter_IsSafe(8, REGION_HOENN, party, 2));
    VarSet(VAR_MAP_SCENE_CINNABAR_ISLAND, 1);
    EXPECT(!RegionalCenter_IsSafe(24, REGION_KANTO, party, 2));
    VarSet(VAR_MAP_SCENE_CINNABAR_ISLAND, 3);
    EXPECT(!RegionalCenter_IsSafe(24, REGION_KANTO, party, 2));
    VarSet(VAR_MAP_SCENE_CINNABAR_ISLAND, 4);
    EXPECT(RegionalCenter_IsSafe(24, REGION_KANTO, party, 2));
    VarSet(VAR_MAP_SCENE_CINNABAR_ISLAND_2, 1);
    EXPECT(!RegionalCenter_IsSafe(24, REGION_KANTO, party, 2));
}

TEST("Regional Centers do not resume into queued exterior story movement")
{
    static const struct
    {
        u16 center, var, value;
        enum Region region;
    } cases[] =
    {
        {1, VAR_PETALBURG_CITY_STATE, 2, REGION_HOENN},
        {1, VAR_PETALBURG_CITY_STATE, 4, REGION_HOENN},
        {2, VAR_SLATEPORT_OUTSIDE_MUSEUM_STATE, 1, REGION_HOENN},
        {4, VAR_RUSTBORO_CITY_STATE, 6, REGION_HOENN},
        {12, VAR_LAVARIDGE_TOWN_STATE, 1, REGION_HOENN},
        {21, VAR_MAP_SCENE_VERMILION_CITY, 2, REGION_KANTO},
        {25, VAR_MAP_SCENE_INDIGO_PLATEAU_EXTERIOR, 1, REGION_KANTO},
        {29, VAR_MAP_SCENE_ONE_ISLAND_HARBOR, 2, REGION_KANTO},
        {37, VAR_VIOLET_CITY_KIMONO_GIRL, 1, REGION_JOHTO},
        {37, VAR_VIOLET_CITY_STATE, 3, REGION_JOHTO},
        {39, VAR_AZALEA_TOWN_STATE, 8, REGION_JOHTO},
        {42, VAR_SAFARI_ZONE_GATE_STATE, 1, REGION_JOHTO},
        {43, VAR_GETFLY, 1, REGION_JOHTO},
        {44, VAR_MAHOGANY_TOWN_STATE, 15, REGION_JOHTO},
        {45, VAR_BLACKTHORN_CITY_STATE, 4, REGION_JOHTO},
    };
    struct Pokemon party[PARTY_SIZE] = {0};
    u32 i;

    MakeTravelParty(party);
    SetAllRegionalBadges();
    VarSet(VAR_MAP_SCENE_ONE_ISLAND_POKEMON_CENTER_1F, 7);
    VarSet(VAR_MAP_SCENE_CINNABAR_ISLAND, 4);
    for (i = 0; i < ARRAY_COUNT(cases); i++)
    {
        VarSet(cases[i].var, 0);
        EXPECT(RegionalCenter_IsSafe(cases[i].center, cases[i].region, party, 2));
        VarSet(cases[i].var, cases[i].value);
        EXPECT(!RegionalCenter_IsSafe(cases[i].center, cases[i].region, party, 2));
        EXPECT_EQ(VarGet(cases[i].var), cases[i].value);
        VarSet(cases[i].var, 0);
    }
}

TEST("Regional Centers north of Route 118's river need Surf or Fly")
{
    struct Pokemon party[PARTY_SIZE] = {0};
    u16 fortree = RegionalCenter_ForMap(MAP_GROUP(MAP_FORTREE_CITY_POKEMON_CENTER_1F), MAP_NUM(MAP_FORTREE_CITY_POKEMON_CENTER_1F));
    u16 lilycove = RegionalCenter_ForMap(MAP_GROUP(MAP_LILYCOVE_CITY_POKEMON_CENTER_1F), MAP_NUM(MAP_LILYCOVE_CITY_POKEMON_CENTER_1F));
    u16 mauville = RegionalCenter_ForMap(MAP_GROUP(MAP_MAUVILLE_CITY_POKEMON_CENTER_1F), MAP_NUM(MAP_MAUVILLE_CITY_POKEMON_CENTER_1F));

    SetBagItemsPointers();
    ClearBag();
    FlagSet(GetBadgeFlag(REGION_HOENN, 4));
    CreateMon(&party[0], SPECIES_CATERPIE, 5, 1, OTID_STRUCT_PLAYER_ID);
    EXPECT(!RegionalCenter_IsSafe(fortree, REGION_HOENN, party, 1));
    EXPECT(!RegionalCenter_IsSafe(lilycove, REGION_HOENN, party, 1));
    EXPECT(RegionalCenter_IsSafe(mauville, REGION_HOENN, party, 1));
    CreateMon(&party[0], SPECIES_SQUIRTLE, 20, 2, OTID_STRUCT_PLAYER_ID);
    SetMonMoveSlot(&party[0], MOVE_SURF, 0);
    EXPECT(RegionalCenter_IsSafe(fortree, REGION_HOENN, party, 1));
    EXPECT(RegionalCenter_IsSafe(lilycove, REGION_HOENN, party, 1));
    CreateMon(&party[0], SPECIES_PIDGEOT, 36, 3, OTID_STRUCT_PLAYER_ID);
    SetMonMoveSlot(&party[0], MOVE_FLY, 0);
    EXPECT(!RegionalCenter_IsSafe(lilycove, REGION_HOENN, party, 1));
    FlagSet(GetBadgeFlag(REGION_HOENN, 5));
    EXPECT(RegionalCenter_IsSafe(lilycove, REGION_HOENN, party, 1));
}

TEST("Regional Center at Lilycove stays open to a Hoenn champion through the harbor ferry")
{
    struct Pokemon party[PARTY_SIZE] = {0};
    u16 fortree = RegionalCenter_ForMap(MAP_GROUP(MAP_FORTREE_CITY_POKEMON_CENTER_1F), MAP_NUM(MAP_FORTREE_CITY_POKEMON_CENTER_1F));
    u16 lilycove = RegionalCenter_ForMap(MAP_GROUP(MAP_LILYCOVE_CITY_POKEMON_CENTER_1F), MAP_NUM(MAP_LILYCOVE_CITY_POKEMON_CENTER_1F));

    SetBagItemsPointers();
    ClearBag();
    SetAllRegionalBadges();
    CreateMon(&party[0], SPECIES_CATERPIE, 5, 1, OTID_STRUCT_PLAYER_ID);
    EXPECT(!RegionalCenter_IsSafe(lilycove, REGION_HOENN, party, 1));
    FlagSet(FLAG_HOENN_CHAMPION);
    EXPECT(RegionalCenter_IsSafe(lilycove, REGION_HOENN, party, 1));
    EXPECT(!RegionalCenter_IsSafe(fortree, REGION_HOENN, party, 1));
}

TEST("Regional Centers west of Rusturf Tunnel are the Hoenn west shore")
{
    EXPECT(RegionalCenter_IsHoennWest(RegionalCenter_ForMap(MAP_GROUP(MAP_PETALBURG_CITY_POKEMON_CENTER_1F), MAP_NUM(MAP_PETALBURG_CITY_POKEMON_CENTER_1F))));
    EXPECT(RegionalCenter_IsHoennWest(RegionalCenter_ForMap(MAP_GROUP(MAP_RUSTBORO_CITY_POKEMON_CENTER_1F), MAP_NUM(MAP_RUSTBORO_CITY_POKEMON_CENTER_1F))));
    EXPECT(RegionalCenter_IsHoennWest(RegionalCenter_ForMap(MAP_GROUP(MAP_OLDALE_TOWN_POKEMON_CENTER_1F), MAP_NUM(MAP_OLDALE_TOWN_POKEMON_CENTER_1F))));
    EXPECT(!RegionalCenter_IsHoennWest(RegionalCenter_ForMap(MAP_GROUP(MAP_SLATEPORT_CITY_POKEMON_CENTER_1F), MAP_NUM(MAP_SLATEPORT_CITY_POKEMON_CENTER_1F))));
    EXPECT(!RegionalCenter_IsHoennWest(RegionalCenter_ForMap(MAP_GROUP(MAP_DEWFORD_TOWN_POKEMON_CENTER_1F), MAP_NUM(MAP_DEWFORD_TOWN_POKEMON_CENTER_1F))));
    EXPECT(!RegionalCenter_IsHoennWest(0));
}
