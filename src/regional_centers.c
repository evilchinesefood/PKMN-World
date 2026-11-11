#include "global.h"
#include "regional_centers.h"
#include "event_data.h"
#include "item.h"
#include "pokemon.h"
#include "party_menu.h"
#include "constants/flags.h"
#include "constants/heal_locations.h"
#include "constants/items.h"
#include "constants/maps.h"
#include "constants/moves.h"
#include "constants/vars.h"

enum CenterAccessRule
{
    OPEN,
    WATER,
    DEWFORD,
    SOOTOPOLIS,
    EVER_GRANDE,
    HOENN_LEAGUE,
    KANTO_LEAGUE,
    JOHTO_LEAGUE,
    MT_SILVER,
    CINNABAR,
    SEVII_FIRST,
    ONE_ISLAND,
    SEVII_LATER,
    SIX_ISLAND,
    FOUR_ISLAND,
    SAFFRON,
};

struct CenterEntry
{
    struct RegionalCenterInfo info;
    enum CenterAccessRule rule;
};

#define CENTER(id, map, campaign, posX, posY, heal, access, label) \
    [id] = { { { MAP_GROUP(map), MAP_NUM(map), WARP_ID_NONE, posX, posY }, heal, campaign, label }, access }

// IDs are saved. Append new rows without changing an existing ID.
static const struct CenterEntry sCenters[] =
{
    CENTER(1, MAP_PETALBURG_CITY_POKEMON_CENTER_1F, REGION_HOENN, 7, 7, HEAL_LOCATION_PETALBURG_CITY, OPEN, COMPOUND_STRING("PETALBURG CITY")),
    CENTER(2, MAP_SLATEPORT_CITY_POKEMON_CENTER_1F, REGION_HOENN, 7, 7, HEAL_LOCATION_SLATEPORT_CITY, OPEN, COMPOUND_STRING("SLATEPORT CITY")),
    CENTER(3, MAP_MAUVILLE_CITY_POKEMON_CENTER_1F, REGION_HOENN, 7, 7, HEAL_LOCATION_MAUVILLE_CITY, OPEN, COMPOUND_STRING("MAUVILLE CITY")),
    CENTER(4, MAP_RUSTBORO_CITY_POKEMON_CENTER_1F, REGION_HOENN, 7, 7, HEAL_LOCATION_RUSTBORO_CITY, OPEN, COMPOUND_STRING("RUSTBORO CITY")),
    CENTER(5, MAP_FORTREE_CITY_POKEMON_CENTER_1F, REGION_HOENN, 7, 7, HEAL_LOCATION_FORTREE_CITY, OPEN, COMPOUND_STRING("FORTREE CITY")),
    CENTER(6, MAP_LILYCOVE_CITY_POKEMON_CENTER_1F, REGION_HOENN, 7, 7, HEAL_LOCATION_LILYCOVE_CITY, OPEN, COMPOUND_STRING("LILYCOVE CITY")),
    CENTER(7, MAP_MOSSDEEP_CITY_POKEMON_CENTER_1F, REGION_HOENN, 7, 7, HEAL_LOCATION_MOSSDEEP_CITY, WATER, COMPOUND_STRING("MOSSDEEP CITY")),
    CENTER(8, MAP_SOOTOPOLIS_CITY_POKEMON_CENTER_1F, REGION_HOENN, 7, 7, HEAL_LOCATION_SOOTOPOLIS_CITY, SOOTOPOLIS, COMPOUND_STRING("SOOTOPOLIS CITY")),
    CENTER(9, MAP_EVER_GRANDE_CITY_POKEMON_CENTER_1F, REGION_HOENN, 7, 7, HEAL_LOCATION_EVER_GRANDE_CITY, EVER_GRANDE, COMPOUND_STRING("EVER GRANDE CITY")),
    CENTER(10, MAP_OLDALE_TOWN_POKEMON_CENTER_1F, REGION_HOENN, 7, 7, HEAL_LOCATION_OLDALE_TOWN, OPEN, COMPOUND_STRING("OLDALE TOWN")),
    CENTER(11, MAP_DEWFORD_TOWN_POKEMON_CENTER_1F, REGION_HOENN, 7, 7, HEAL_LOCATION_DEWFORD_TOWN, DEWFORD, COMPOUND_STRING("DEWFORD TOWN")),
    CENTER(12, MAP_LAVARIDGE_TOWN_POKEMON_CENTER_1F, REGION_HOENN, 7, 7, HEAL_LOCATION_LAVARIDGE_TOWN, OPEN, COMPOUND_STRING("LAVARIDGE TOWN")),
    CENTER(13, MAP_FALLARBOR_TOWN_POKEMON_CENTER_1F, REGION_HOENN, 7, 7, HEAL_LOCATION_FALLARBOR_TOWN, OPEN, COMPOUND_STRING("FALLARBOR TOWN")),
    CENTER(14, MAP_VERDANTURF_TOWN_POKEMON_CENTER_1F, REGION_HOENN, 7, 7, HEAL_LOCATION_VERDANTURF_TOWN, OPEN, COMPOUND_STRING("VERDANTURF TOWN")),
    CENTER(15, MAP_PACIFIDLOG_TOWN_POKEMON_CENTER_1F, REGION_HOENN, 7, 7, HEAL_LOCATION_PACIFIDLOG_TOWN, WATER, COMPOUND_STRING("PACIFIDLOG TOWN")),
    CENTER(16, MAP_EVER_GRANDE_CITY_POKEMON_LEAGUE_1F, REGION_HOENN, 9, 10, HEAL_LOCATION_EVER_GRANDE_CITY_POKEMON_LEAGUE, HOENN_LEAGUE, COMPOUND_STRING("HOENN LEAGUE")),
    CENTER(17, MAP_VIRIDIAN_CITY_POKEMON_CENTER_1F, REGION_KANTO, 6, 7, HEAL_LOCATION_VIRIDIAN_CITY, OPEN, COMPOUND_STRING("VIRIDIAN CITY")),
    CENTER(18, MAP_PEWTER_CITY_POKEMON_CENTER_1F, REGION_KANTO, 6, 7, HEAL_LOCATION_PEWTER_CITY, OPEN, COMPOUND_STRING("PEWTER CITY")),
    CENTER(19, MAP_CERULEAN_CITY_POKEMON_CENTER_1F, REGION_KANTO, 6, 7, HEAL_LOCATION_CERULEAN_CITY, OPEN, COMPOUND_STRING("CERULEAN CITY")),
    CENTER(20, MAP_LAVENDER_TOWN_POKEMON_CENTER_1F, REGION_KANTO, 6, 7, HEAL_LOCATION_LAVENDER_TOWN, OPEN, COMPOUND_STRING("LAVENDER TOWN")),
    CENTER(21, MAP_VERMILION_CITY_POKEMON_CENTER_1F, REGION_KANTO, 6, 7, HEAL_LOCATION_VERMILION_CITY, OPEN, COMPOUND_STRING("VERMILION CITY")),
    CENTER(22, MAP_CELADON_CITY_POKEMON_CENTER_1F, REGION_KANTO, 6, 7, HEAL_LOCATION_CELADON_CITY, OPEN, COMPOUND_STRING("CELADON CITY")),
    CENTER(23, MAP_FUCHSIA_CITY_POKEMON_CENTER_1F, REGION_KANTO, 6, 7, HEAL_LOCATION_FUCHSIA_CITY, OPEN, COMPOUND_STRING("FUCHSIA CITY")),
    CENTER(24, MAP_CINNABAR_ISLAND_POKEMON_CENTER_1F, REGION_KANTO, 7, 7, HEAL_LOCATION_CINNABAR_ISLAND, CINNABAR, COMPOUND_STRING("CINNABAR ISLAND")),
    CENTER(25, MAP_INDIGO_PLATEAU_POKEMON_CENTER_1F, REGION_KANTO, 11, 15, HEAL_LOCATION_INDIGO_PLATEAU, KANTO_LEAGUE, COMPOUND_STRING("KANTO LEAGUE")),
    CENTER(26, MAP_SAFFRON_CITY_POKEMON_CENTER_1F, REGION_KANTO, 6, 7, HEAL_LOCATION_SAFFRON_CITY, SAFFRON, COMPOUND_STRING("SAFFRON CITY")),
    CENTER(27, MAP_ROUTE4_POKEMON_CENTER_1F, REGION_KANTO, 6, 7, HEAL_LOCATION_ROUTE4, OPEN, COMPOUND_STRING("ROUTE 4")),
    CENTER(28, MAP_ROUTE10_POKEMON_CENTER_1F, REGION_KANTO, 6, 7, HEAL_LOCATION_ROUTE10, OPEN, COMPOUND_STRING("ROUTE 10")),
    CENTER(29, MAP_ONE_ISLAND_POKEMON_CENTER_1F, REGION_KANTO, 9, 8, HEAL_LOCATION_ONE_ISLAND, ONE_ISLAND, COMPOUND_STRING("ONE ISLAND")),
    CENTER(30, MAP_TWO_ISLAND_POKEMON_CENTER_1F, REGION_KANTO, 7, 7, HEAL_LOCATION_TWO_ISLAND, SEVII_FIRST, COMPOUND_STRING("TWO ISLAND")),
    CENTER(31, MAP_THREE_ISLAND_POKEMON_CENTER_1F, REGION_KANTO, 7, 7, HEAL_LOCATION_THREE_ISLAND, SEVII_FIRST, COMPOUND_STRING("THREE ISLAND")),
    CENTER(32, MAP_FOUR_ISLAND_POKEMON_CENTER_1F, REGION_KANTO, 7, 7, HEAL_LOCATION_FOUR_ISLAND, FOUR_ISLAND, COMPOUND_STRING("FOUR ISLAND")),
    CENTER(33, MAP_FIVE_ISLAND_POKEMON_CENTER_1F, REGION_KANTO, 7, 7, HEAL_LOCATION_FIVE_ISLAND, SEVII_LATER, COMPOUND_STRING("FIVE ISLAND")),
    CENTER(34, MAP_SEVEN_ISLAND_POKEMON_CENTER_1F, REGION_KANTO, 7, 7, HEAL_LOCATION_SEVEN_ISLAND, SEVII_LATER, COMPOUND_STRING("SEVEN ISLAND")),
    CENTER(35, MAP_SIX_ISLAND_POKEMON_CENTER_1F, REGION_KANTO, 7, 7, HEAL_LOCATION_SIX_ISLAND, SIX_ISLAND, COMPOUND_STRING("SIX ISLAND")),
    CENTER(36, MAP_CHERRYGROVE_CITY_POKEMON_CENTER, REGION_JOHTO, 7, 7, HEAL_LOCATION_CHERRYGROVE_CITY, OPEN, COMPOUND_STRING("CHERRYGROVE CITY")),
    CENTER(37, MAP_VIOLET_CITY_POKEMON_CENTER, REGION_JOHTO, 7, 7, HEAL_LOCATION_VIOLET_CITY, OPEN, COMPOUND_STRING("VIOLET CITY")),
    CENTER(38, MAP_ROUTE32_POKEMON_CENTER, REGION_JOHTO, 7, 7, HEAL_LOCATION_ROUTE_32, OPEN, COMPOUND_STRING("ROUTE 32")),
    CENTER(39, MAP_AZALEA_TOWN_POKEMON_CENTER, REGION_JOHTO, 7, 7, HEAL_LOCATION_AZALEA_TOWN, OPEN, COMPOUND_STRING("AZALEA TOWN")),
    CENTER(40, MAP_GOLDENROD_CITY_POKEMON_CENTER, REGION_JOHTO, 7, 7, HEAL_LOCATION_GOLDENROD_CITY, OPEN, COMPOUND_STRING("GOLDENROD CITY")),
    CENTER(41, MAP_ECRUTEAK_CITY_POKEMON_CENTER, REGION_JOHTO, 7, 7, HEAL_LOCATION_ECRUTEAK_CITY, OPEN, COMPOUND_STRING("ECRUTEAK CITY")),
    CENTER(42, MAP_OLIVINE_CITY_POKEMON_CENTER, REGION_JOHTO, 7, 7, HEAL_LOCATION_OLIVINE_CITY, OPEN, COMPOUND_STRING("OLIVINE CITY")),
    CENTER(43, MAP_CIANWOOD_POKECENTER, REGION_JOHTO, 7, 7, HEAL_LOCATION_CIANWOOD_CITY, WATER, COMPOUND_STRING("CIANWOOD CITY")),
    CENTER(44, MAP_MAHOGANY_TOWN_POKEMON_CENTER, REGION_JOHTO, 7, 7, HEAL_LOCATION_MAHOGANYTOWN, OPEN, COMPOUND_STRING("MAHOGANY TOWN")),
    CENTER(45, MAP_BLACKTHORN_CITY_POKEMON_CENTER, REGION_JOHTO, 7, 7, HEAL_LOCATION_BLACKTHORN_CITY, OPEN, COMPOUND_STRING("BLACKTHORN CITY")),
    CENTER(46, MAP_SAFARI_ZONE_GATE_POKEMON_CENTER, REGION_JOHTO, 7, 7, HEAL_LOCATION_SAFARI_ZONE_GATE, OPEN, COMPOUND_STRING("SAFARI ZONE GATE")),
    CENTER(47, MAP_MT_SILVER_POKEMON_CENTER, REGION_JOHTO, 7, 7, HEAL_LOCATION_MT_SILVER, MT_SILVER, COMPOUND_STRING("MT SILVER")),
    CENTER(48, MAP_JOHTO_INDIGO_PLATEAU_POKEMON_CENTER, REGION_JOHTO, 19, 15, HEAL_LOCATION_JOHTO_INDIGO_PLATEAU, JOHTO_LEAGUE, COMPOUND_STRING("JOHTO LEAGUE")),
};

#undef CENTER

struct PendingCenterExitScene
{
    u16 center;
    u16 var;
    u16 value;
};

// These scenes assume the original door or voyage position when the player exits.
static const struct PendingCenterExitScene sPendingExitScenes[] =
{
    {1, VAR_PETALBURG_CITY_STATE, 2},
    {1, VAR_PETALBURG_CITY_STATE, 4},
    {2, VAR_SLATEPORT_OUTSIDE_MUSEUM_STATE, 1},
    {4, VAR_RUSTBORO_CITY_STATE, 6},
    {12, VAR_LAVARIDGE_TOWN_STATE, 1},
    {21, VAR_MAP_SCENE_VERMILION_CITY, 2},
    {25, VAR_MAP_SCENE_INDIGO_PLATEAU_EXTERIOR, 1},
    {29, VAR_MAP_SCENE_ONE_ISLAND_HARBOR, 2},
    {37, VAR_VIOLET_CITY_KIMONO_GIRL, 1},
    {37, VAR_VIOLET_CITY_STATE, 3},
    {39, VAR_AZALEA_TOWN_STATE, 8},
    {42, VAR_SAFARI_ZONE_GATE_STATE, 1},
    {43, VAR_GETFLY, 1},
    {44, VAR_MAHOGANY_TOWN_STATE, 15},
    {45, VAR_BLACKTHORN_CITY_STATE, 4},
};

static bool32 HasPendingExitScene(u16 id)
{
    u32 i;

    for (i = 0; i < ARRAY_COUNT(sPendingExitScenes); i++)
    {
        if (sPendingExitScenes[i].center == id
         && VarGet(sPendingExitScenes[i].var) == sPendingExitScenes[i].value)
            return TRUE;
    }
    return FALSE;
}

const struct RegionalCenterInfo *RegionalCenter_GetInfo(u16 id)
{
    if (id == 0 || id >= ARRAY_COUNT(sCenters))
        return NULL;
    return &sCenters[id].info;
}

u32 RegionalCenter_Count(void)
{
    return ARRAY_COUNT(sCenters) - 1;
}

u16 RegionalCenter_ForMap(u8 mapGroup, u8 mapNum)
{
    u32 id;

    for (id = 1; id < ARRAY_COUNT(sCenters); id++)
    {
        if (sCenters[id].info.arrival.mapGroup == mapGroup
         && sCenters[id].info.arrival.mapNum == mapNum)
            return id;
    }
    return 0;
}

enum Region RegionalCenter_GetRegion(u16 id)
{
    const struct RegionalCenterInfo *center = RegionalCenter_GetInfo(id);

    return center == NULL ? REGION_NONE : center->region;
}

const u8 *RegionalCenter_GetName(u16 id)
{
    const struct RegionalCenterInfo *center = RegionalCenter_GetInfo(id);

    return center == NULL ? NULL : center->name;
}

bool32 RegionalCenter_GetDestination(u16 id, struct WarpData *warp, u16 *healLocation)
{
    const struct RegionalCenterInfo *center = RegionalCenter_GetInfo(id);

    if (center == NULL)
        return FALSE;
    *warp = center->arrival;
    *healLocation = center->healLocation;
    return TRUE;
}

static bool32 PartyCanUseMove(struct Pokemon *party, u8 count, enum Move move)
{
    u32 i;

    for (i = 0; i < count; i++)
    {
        enum Species species = GetMonData(&party[i], MON_DATA_SPECIES);

        if (species == SPECIES_NONE || GetMonData(&party[i], MON_DATA_IS_EGG))
            continue;
        if (MonKnowsMove(&party[i], move))
            return TRUE;
#if QOL_FIELD_MOVES_NO_TEACH
        if (CanLearnTeachableMove(species, move))
            return TRUE;
#endif
    }
    return FALSE;
}

static bool32 CanSurf(enum Region region, struct Pokemon *party, u8 count)
{
    bool32 unlocked = HasBadge(region, region == REGION_JOHTO ? 3 : 4);

#if QOL_FIELD_MOVES_ITEM_GATE
    unlocked |= CheckBagHasItem(ITEM_SURF_TOOL, 1);
#endif
    return unlocked && PartyCanUseMove(party, count, MOVE_SURF);
}

static bool32 CanFly(enum Region region, struct Pokemon *party, u8 count)
{
    return HasBadge(region, region == REGION_KANTO ? 2 : 5)
        && PartyCanUseMove(party, count, MOVE_FLY);
}

static bool32 CanDive(enum Region region, struct Pokemon *party, u8 count)
{
    bool32 unlocked = HasBadge(region, 6);

#if QOL_FIELD_MOVES_ITEM_GATE
    unlocked |= CheckBagHasItem(ITEM_DIVE_TOOL, 1);
#endif
    return unlocked && PartyCanUseMove(party, count, MOVE_DIVE);
}

static bool32 CanWaterfall(enum Region region, struct Pokemon *party, u8 count)
{
    bool32 unlocked = HasBadge(region, region == REGION_KANTO ? 6 : 7);

#if QOL_FIELD_MOVES_ITEM_GATE
    unlocked |= CheckBagHasItem(ITEM_WATERFALL_TOOL, 1);
#endif
    return unlocked && PartyCanUseMove(party, count, MOVE_WATERFALL);
}

static bool32 HasAllBadges(enum Region region)
{
    u32 i;

    for (i = 0; i < NUM_BADGES; i++)
    {
        if (!HasBadge(region, i))
            return FALSE;
    }
    return TRUE;
}

static bool32 CanUseSeviiFerry(bool32 laterIslands)
{
    u16 networkState = VarGet(VAR_MAP_SCENE_ONE_ISLAND_POKEMON_CENTER_1F);

    if (laterIslands)
        return networkState >= 5;
    return networkState >= 5
        || (networkState >= 1 && VarGet(VAR_MAP_SCENE_CINNABAR_ISLAND) >= 4);
}

bool32 RegionalCenter_IsSafe(u16 id, enum Region destination, struct Pokemon *party, u8 count)
{
    const struct RegionalCenterInfo *center = RegionalCenter_GetInfo(id);
    bool32 canFly;

    if (center == NULL || center->region != destination || party == NULL || count > PARTY_SIZE)
        return FALSE;

    if (HasPendingExitScene(id))
        return FALSE;

    canFly = CanFly(destination, party, count);
    switch (sCenters[id].rule)
    {
    case OPEN:
        return TRUE;
    case WATER:
        return canFly || CanSurf(destination, party, count);
    case DEWFORD:
        return (!FlagGet(FLAG_HIDE_MR_BRINEY_DEWFORD_TOWN)
             && !FlagGet(FLAG_HIDE_MR_BRINEY_BOAT_DEWFORD_TOWN))
            || canFly || CanSurf(destination, party, count);
    case SOOTOPOLIS:
        if ((VarGet(VAR_SOOTOPOLIS_CITY_STATE) > 0 && VarGet(VAR_SOOTOPOLIS_CITY_STATE) < 6)
         || VarGet(VAR_SKY_PILLAR_STATE) == 1)
            return FALSE;
        return canFly || (CanSurf(destination, party, count) && CanDive(destination, party, count));
    case EVER_GRANDE:
        return canFly || (CanSurf(destination, party, count) && CanWaterfall(destination, party, count));
    case HOENN_LEAGUE:
    case KANTO_LEAGUE:
        return HasAllBadges(destination);
    case JOHTO_LEAGUE:
        return HasAllBadges(destination) && VarGet(VAR_ECRUTEAK_CITY_THEATER) >= 8
            && VarGet(VAR_LEAGUE_STATE) == 1;
    case SAFFRON:
        return VarGet(VAR_MAP_SCENE_ROUTE5_ROUTE6_ROUTE7_ROUTE8_GATES) >= 1;
    case MT_SILVER:
        return FlagGet(FLAG_INDIGOJUNCTION_HIDE_SILVER_GUARD);
    case CINNABAR:
        if (VarGet(VAR_MAP_SCENE_CINNABAR_ISLAND) == 1
         || VarGet(VAR_MAP_SCENE_CINNABAR_ISLAND) == 3
         || VarGet(VAR_MAP_SCENE_CINNABAR_ISLAND_2) == 1)
            return FALSE;
        return canFly || CanSurf(destination, party, count);
    case SEVII_FIRST:
        return CanUseSeviiFerry(FALSE);
    case ONE_ISLAND:
        return CanUseSeviiFerry(FALSE)
            && VarGet(VAR_MAP_SCENE_ONE_ISLAND_POKEMON_CENTER_1F) != 6;
    case SEVII_LATER:
        return CanUseSeviiFerry(TRUE);
    case FOUR_ISLAND:
        return CanUseSeviiFerry(TRUE) && VarGet(VAR_MAP_SCENE_FOUR_ISLAND) >= 1;
    case SIX_ISLAND:
        return CanUseSeviiFerry(TRUE)
            && VarGet(VAR_MAP_SCENE_SIX_ISLAND_POKEMON_CENTER_1F) >= 1;
    }
    return FALSE;
}
