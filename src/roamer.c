#include "global.h"
#include "event_data.h"
#include "ow_abilities.h"
#include "pokemon.h"
#include "pokedex.h"
#include "random.h"
#include "roamer.h"

// Region-merge: the roamer can be in ANY map group. Its region is derived from its
// species — the three Johto legendary beasts (Entei/Raikou/Suicune) roam the Johto
// routes (which span several map groups in this merged build), while every other
// roamer (Hoenn's Latios/Latias) uses the Hoenn table (all in map group 0). The
// location tables store full MAP_* ids (group<<8 | num); for group-0 Hoenn maps the
// full id equals the bare map number, so Hoenn behavior is byte-identical to before.

enum
{
    MAP_GRP, // map group
    MAP_NUM, // map number
};

#define ROAMER(index) (&gSaveBlock1Ptr->roamer[index])
EWRAM_DATA static u8 sLocationHistory[ROAMER_COUNT][3][2] = {0};
EWRAM_DATA static u8 sRoamerLocation[ROAMER_COUNT][2] = {0};
EWRAM_DATA u8 gEncounteredRoamerIndex = 0;

#define ___ MAP_UNDEFINED // For empty spots in the location table

// Note: There are two potential softlocks that can occur with this table if its maps are
//       changed in particular ways. They can be avoided by ensuring the following:
//       - There must be at least 2 location sets that start with a different map,
//         i.e. every location set cannot start with the same map. This is because of
//         the while loop in RoamerMoveToOtherLocationSet.
//       - Each location set must have at least 3 unique maps. This is because of
//         the while loop in RoamerMove. In this loop the first map in the set is
//         ignored, and an additional map is ignored if the roamer was there recently.
//       - Additionally, while not a softlock, it's worth noting that if for any
//         map in the location table there is not a location set that starts with
//         that map then the roamer will be significantly less likely to move away
//         from that map when it lands there.
// Entries are full MAP_* ids (group<<8 | num) so a roamer can span multiple map groups.
static const u16 sRoamerLocationsHoenn[][6] =
{
    { MAP_ROUTE110, MAP_ROUTE111, MAP_ROUTE117, MAP_ROUTE118, MAP_ROUTE134, ___ },
    { MAP_ROUTE111, MAP_ROUTE110, MAP_ROUTE117, MAP_ROUTE118, ___, ___ },
    { MAP_ROUTE117, MAP_ROUTE111, MAP_ROUTE110, MAP_ROUTE118, ___, ___ },
    { MAP_ROUTE118, MAP_ROUTE117, MAP_ROUTE110, MAP_ROUTE111, MAP_ROUTE119, MAP_ROUTE123 },
    { MAP_ROUTE119, MAP_ROUTE118, MAP_ROUTE120, ___, ___, ___ },
    { MAP_ROUTE120, MAP_ROUTE119, MAP_ROUTE121, ___, ___, ___ },
    { MAP_ROUTE121, MAP_ROUTE120, MAP_ROUTE122, MAP_ROUTE123, ___, ___ },
    { MAP_ROUTE122, MAP_ROUTE121, MAP_ROUTE123, ___, ___, ___ },
    { MAP_ROUTE123, MAP_ROUTE122, MAP_ROUTE118, ___, ___, ___ },
    { MAP_ROUTE124, MAP_ROUTE121, MAP_ROUTE125, MAP_ROUTE126, ___, ___ },
    { MAP_ROUTE125, MAP_ROUTE124, MAP_ROUTE127, ___, ___, ___ },
    { MAP_ROUTE126, MAP_ROUTE124, MAP_ROUTE127, ___, ___, ___ },
    { MAP_ROUTE127, MAP_ROUTE125, MAP_ROUTE126, MAP_ROUTE128, ___, ___ },
    { MAP_ROUTE128, MAP_ROUTE127, MAP_ROUTE129, ___, ___, ___ },
    { MAP_ROUTE129, MAP_ROUTE128, MAP_ROUTE130, ___, ___, ___ },
    { MAP_ROUTE130, MAP_ROUTE129, MAP_ROUTE131, ___, ___, ___ },
    { MAP_ROUTE131, MAP_ROUTE130, MAP_ROUTE132, ___, ___, ___ },
    { MAP_ROUTE132, MAP_ROUTE131, MAP_ROUTE133, ___, ___, ___ },
    { MAP_ROUTE133, MAP_ROUTE132, MAP_ROUTE134, ___, ___, ___ },
    { MAP_ROUTE134, MAP_ROUTE133, MAP_ROUTE110, ___, ___, ___ },
    { ___, ___, ___, ___, ___, ___ },
};

// Johto legendary-beast roam table (Entei/Raikou/Suicune), ported from HnS. Johto routes
// are spread across several map groups in this build, so the full-id form is essential.
static const u16 sRoamerLocationsJohto[][6] =
{
    { MAP_ROUTE29, MAP_ROUTE30, MAP_ROUTE46, ___, ___, ___ },
    { MAP_ROUTE30, MAP_ROUTE29, MAP_ROUTE31, ___, ___, ___ },
    { MAP_ROUTE31, MAP_ROUTE30, MAP_ROUTE29, ___, ___, ___ },
    { MAP_ROUTE32, MAP_ROUTE31, MAP_ROUTE33, ___, ___, ___ },
    { MAP_ROUTE33, MAP_ROUTE32, MAP_ROUTE34, ___, ___, ___ },
    { MAP_ROUTE34, MAP_ROUTE33, MAP_ROUTE35, ___, ___, ___ },
    { MAP_ROUTE35, MAP_ROUTE34, MAP_ROUTE36, ___, ___, ___ },
    { MAP_ROUTE36, MAP_ROUTE31, MAP_ROUTE32, MAP_ROUTE35, MAP_ROUTE37, ___ },
    { MAP_ROUTE37, MAP_ROUTE36, MAP_ROUTE38, MAP_ROUTE42, ___, ___ },
    { MAP_ROUTE38, MAP_ROUTE37, MAP_ROUTE39, ___, ___, ___ },
    { MAP_ROUTE39, MAP_ROUTE48, MAP_ROUTE35, ___, ___, ___ },
    { MAP_ROUTE42, MAP_ROUTE37, MAP_ROUTE38, MAP_ROUTE43, MAP_ROUTE44, ___ },
    { MAP_ROUTE43, MAP_ROUTE42, MAP_ROUTE44, ___, ___, ___ },
    { MAP_ROUTE44, MAP_ROUTE42, MAP_ROUTE45, ___, ___, ___ },
    { MAP_ROUTE45, MAP_ROUTE44, MAP_ROUTE46, ___, ___, ___ },
    { MAP_ROUTE46, MAP_ROUTE45, MAP_ROUTE29, ___, ___, ___ },
    { ___, ___, ___, ___, ___, ___ },
};

#undef ___
#define NUM_LOCATION_SETS_HOENN (ARRAY_COUNT(sRoamerLocationsHoenn) - 1)
#define NUM_LOCATION_SETS_JOHTO (ARRAY_COUNT(sRoamerLocationsJohto) - 1)
#define NUM_LOCATIONS_PER_SET (ARRAY_COUNT(sRoamerLocationsHoenn[0]))

static bool8 IsJohtoRoamerSpecies(u16 species)
{
    return species == SPECIES_ENTEI || species == SPECIES_RAIKOU || species == SPECIES_SUICUNE;
}

// Picks the location table for this roamer (by species) and writes its set count.
static const u16 (*GetRoamerLocations(u32 roamerIndex, u8 *numSets))[6]
{
    if (IsJohtoRoamerSpecies(ROAMER(roamerIndex)->species))
    {
        *numSets = NUM_LOCATION_SETS_JOHTO;
        return sRoamerLocationsJohto;
    }
    *numSets = NUM_LOCATION_SETS_HOENN;
    return sRoamerLocationsHoenn;
}

// sRoamerLocation/sLocationHistory store group & num as two bytes; these helpers pack/
// unpack them as a full MAP_* id so the location tables can be compared directly.
#define CUR_LOC_ID(idx)     (((u16)sRoamerLocation[idx][MAP_GRP] << 8) | sRoamerLocation[idx][MAP_NUM])
#define HIST_LOC_ID(idx, h) (((u16)sLocationHistory[idx][h][MAP_GRP] << 8) | sLocationHistory[idx][h][MAP_NUM])

static void SetRoamerLocationById(u32 idx, u16 mapId)
{
    sRoamerLocation[idx][MAP_GRP] = mapId >> 8;
    sRoamerLocation[idx][MAP_NUM] = mapId & 0xFF;
}

void DeactivateAllRoamers(void)
{
    u32 i;

    for (i = 0; i < ROAMER_COUNT; i++)
        SetRoamerInactive(i);
}

static void ClearRoamerLocationHistory(u32 roamerIndex)
{
    u32 i;

    for (i = 0; i < ARRAY_COUNT(sLocationHistory[roamerIndex]); i++)
    {
        sLocationHistory[roamerIndex][i][MAP_GRP] = 0;
        sLocationHistory[roamerIndex][i][MAP_NUM] = 0;
    }
}

void MoveAllRoamersToOtherLocationSets(void)
{
    u32 i;

    for (i = 0; i < ROAMER_COUNT; i++)
        RoamerMoveToOtherLocationSet(i);
}

void MoveAllRoamers(void)
{
    u32 i;

    for (i = 0; i < ROAMER_COUNT; i++)
        RoamerMove(i);
}

static void CreateInitialRoamerMon(u8 index, enum Species species, u8 level)
{
    ClearRoamerLocationHistory(index);
    u32 personality = GetMonPersonality(species,
        GetSynchronizedGender(ROAMER_ORIGIN, species),
        GetSynchronizedNature(ROAMER_ORIGIN, species),
        RANDOM_UNOWN_LETTER);
    CreateMonWithIVs(&gParties[B_TRAINER_OPPONENT_A][0], species, level, personality, OTID_STRUCT_PLAYER_ID, USE_RANDOM_IVS);
    GiveMonInitialMoveset(&gParties[B_TRAINER_OPPONENT_A][0]);
    ROAMER(index)->ivs = GetMonData(&gParties[B_TRAINER_OPPONENT_A][0], MON_DATA_IVS);
    ROAMER(index)->personality = GetMonData(&gParties[B_TRAINER_OPPONENT_A][0], MON_DATA_PERSONALITY);
    ROAMER(index)->species = species;
    ROAMER(index)->level = level;
    ROAMER(index)->statusA = 0;
    ROAMER(index)->statusB = 0;
    ROAMER(index)->hp = GetMonData(&gParties[B_TRAINER_OPPONENT_A][0], MON_DATA_MAX_HP);
    ROAMER(index)->cool = GetMonData(&gParties[B_TRAINER_OPPONENT_A][0], MON_DATA_COOL);
    ROAMER(index)->beauty = GetMonData(&gParties[B_TRAINER_OPPONENT_A][0], MON_DATA_BEAUTY);
    ROAMER(index)->cute = GetMonData(&gParties[B_TRAINER_OPPONENT_A][0], MON_DATA_CUTE);
    ROAMER(index)->smart = GetMonData(&gParties[B_TRAINER_OPPONENT_A][0], MON_DATA_SMART);
    ROAMER(index)->tough = GetMonData(&gParties[B_TRAINER_OPPONENT_A][0], MON_DATA_TOUGH);
    ROAMER(index)->shiny = GetMonData(&gParties[B_TRAINER_OPPONENT_A][0], MON_DATA_IS_SHINY);
    ROAMER(index)->active = TRUE;
    {
        u8 numSets;
        const u16 (*table)[6] = GetRoamerLocations(index, &numSets);
        SetRoamerLocationById(index, table[Random() % numSets][0]);
    }
}

static u8 GetFirstInactiveRoamerIndex(void)
{
    u32 i;

    for (i = 0; i < ROAMER_COUNT; i++)
    {
        if (!ROAMER(i)->active)
            return i;
    }
    return ROAMER_COUNT;
}

bool8 TryAddRoamer(enum Species species, u8 level)
{
    u8 index = GetFirstInactiveRoamerIndex();

    if (index < ROAMER_COUNT)
    {
        // Create the roamer and stop searching
        CreateInitialRoamerMon(index, species, level);
        return TRUE;
    }

    // Maximum active roamers found: do nothing and let the calling function know
    return FALSE;
}

// gSpecialVar_0x8004 here corresponds to the options in the multichoice MULTI_TV_LATI (0 for 'Red', 1 for 'Blue')
void InitRoamer(void)
{
    if (gSpecialVar_0x8004 == 0) // Red
        TryAddRoamer(SPECIES_LATIAS, 40);
    else
        TryAddRoamer(SPECIES_LATIOS, 40);
}

// Johto legendary-beast roamer (Burned Tower beast-release). gSpecialVar_0x8004: 0 = Raikou,
// otherwise Entei. Mirrors HnS InitRoamer: marks all three beasts as seen, then starts the
// chosen beast roaming the Johto routes. With ROAMER_COUNT == 1 the beast takes the single
// roamer slot, so any active Hoenn roamer is cleared first (the two regions' post-games never
// roam simultaneously in practice).
void InitJohtoRoamer(void)
{
    enum Species species = (gSpecialVar_0x8004 == 0) ? SPECIES_RAIKOU : SPECIES_ENTEI;

    GetSetPokedexFlag(SpeciesToNationalPokedexNum(SPECIES_ENTEI), FLAG_SET_SEEN);
    GetSetPokedexFlag(SpeciesToNationalPokedexNum(SPECIES_RAIKOU), FLAG_SET_SEEN);
    GetSetPokedexFlag(SpeciesToNationalPokedexNum(SPECIES_SUICUNE), FLAG_SET_SEEN);
    DeactivateAllRoamers();
    TryAddRoamer(species, 40);
}

void UpdateLocationHistoryForRoamer(void)
{
    u32 i;

    for (i = 0; i < ROAMER_COUNT; i++)
    {
        sLocationHistory[i][2][MAP_GRP] = sLocationHistory[i][1][MAP_GRP];
        sLocationHistory[i][2][MAP_NUM] = sLocationHistory[i][1][MAP_NUM];

        sLocationHistory[i][1][MAP_GRP] = sLocationHistory[i][0][MAP_GRP];
        sLocationHistory[i][1][MAP_NUM] = sLocationHistory[i][0][MAP_NUM];

        sLocationHistory[i][0][MAP_GRP] = gSaveBlock1Ptr->location.mapGroup;
        sLocationHistory[i][0][MAP_NUM] = gSaveBlock1Ptr->location.mapNum;
    }
}

void RoamerMoveToOtherLocationSet(u32 roamerIndex)
{
    u16 mapId = 0;
    u8 numSets;
    const u16 (*table)[6];

    if (!ROAMER(roamerIndex)->active)
        return;

    table = GetRoamerLocations(roamerIndex, &numSets);

    // Choose a location set that starts with a map
    // different from the roamer's current map
    do
    {
        mapId = table[Random() % numSets][0];
        if (CUR_LOC_ID(roamerIndex) != mapId)
        {
            SetRoamerLocationById(roamerIndex, mapId);
            return;
        }
    } while (CUR_LOC_ID(roamerIndex) == mapId);
    SetRoamerLocationById(roamerIndex, mapId);
}

void RoamerMove(u32 roamerIndex)
{
    u8 locSet = 0;
    u8 numSets;
    const u16 (*table)[6];

    if ((Random() % 16) == 0)
    {
        RoamerMoveToOtherLocationSet(roamerIndex);
    }
    else
    {
        if (!ROAMER(roamerIndex)->active)
            return;

        table = GetRoamerLocations(roamerIndex, &numSets);

        while (locSet < numSets)
        {
            // Find the location set that starts with the roamer's current map
            if (CUR_LOC_ID(roamerIndex) == table[locSet][0])
            {
                u16 mapId;
                // Choose a new map (excluding the first) within this set
                // Also exclude a map if the roamer was there 2 moves ago
                do
                {
                    mapId = table[locSet][(Random() % (NUM_LOCATIONS_PER_SET - 1)) + 1];
                } while (HIST_LOC_ID(roamerIndex, 2) == mapId || mapId == MAP_UNDEFINED);
                SetRoamerLocationById(roamerIndex, mapId);
                return;
            }
            locSet++;
        }
    }
}

bool8 IsRoamerAt(u32 roamerIndex, u8 mapGroup, u8 mapNum)
{
    if (ROAMER(roamerIndex)->active && mapGroup == sRoamerLocation[roamerIndex][MAP_GRP] && mapNum == sRoamerLocation[roamerIndex][MAP_NUM])
        return TRUE;
    else
        return FALSE;
}

void CreateRoamerMonInstance(u32 roamerIndex)
{
    u32 status = ROAMER(roamerIndex)->statusA + (ROAMER(roamerIndex)->statusB << 8);
    struct Pokemon *mon = &gParties[B_TRAINER_OPPONENT_A][0];
    ZeroEnemyPartyMons();
    CreateMonWithIVsPersonality(mon, ROAMER(roamerIndex)->species, ROAMER(roamerIndex)->level, ROAMER(roamerIndex)->ivs, ROAMER(roamerIndex)->personality);
    SetMonData(mon, MON_DATA_STATUS, &status);
    SetMonData(mon, MON_DATA_HP, &ROAMER(roamerIndex)->hp);
    SetMonData(mon, MON_DATA_COOL, &ROAMER(roamerIndex)->cool);
    SetMonData(mon, MON_DATA_BEAUTY, &ROAMER(roamerIndex)->beauty);
    SetMonData(mon, MON_DATA_CUTE, &ROAMER(roamerIndex)->cute);
    SetMonData(mon, MON_DATA_SMART, &ROAMER(roamerIndex)->smart);
    SetMonData(mon, MON_DATA_TOUGH, &ROAMER(roamerIndex)->tough);
    SetMonData(mon, MON_DATA_IS_SHINY, &ROAMER(roamerIndex)->shiny);
}

bool8 TryStartRoamerEncounter(void)
{
    u32 i;

    for (i = 0; i < ROAMER_COUNT; i++)
    {
        if (IsRoamerAt(i, gSaveBlock1Ptr->location.mapGroup, gSaveBlock1Ptr->location.mapNum) == TRUE && (Random() % 4) == 0)
        {
            CreateRoamerMonInstance(i);
            gEncounteredRoamerIndex = i;
            return TRUE;
        }
    }
    return FALSE;
}

void UpdateRoamerHPStatus(struct Pokemon *mon)
{
    u32 status = GetMonData(mon, MON_DATA_STATUS);

    ROAMER(gEncounteredRoamerIndex)->hp = GetMonData(mon, MON_DATA_HP);
    ROAMER(gEncounteredRoamerIndex)->statusA = status;
    ROAMER(gEncounteredRoamerIndex)->statusB = status >> 8;

    RoamerMoveToOtherLocationSet(gEncounteredRoamerIndex);
}

void SetRoamerInactive(u32 roamerIndex)
{
    ROAMER(roamerIndex)->active = FALSE;
}

void GetRoamerLocation(u32 roamerIndex, u8 *mapGroup, u8 *mapNum)
{
    *mapGroup = sRoamerLocation[roamerIndex][MAP_GRP];
    *mapNum = sRoamerLocation[roamerIndex][MAP_NUM];
}
