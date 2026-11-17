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

static void DeactivateJohtoBeastRoamers(void)
{
    u32 i;

    for (i = 0; i < ROAMER_COUNT; i++)
    {
        if (IsJohtoRoamerSpecies(ROAMER(i)->species))
            SetRoamerInactive(i);
    }
}

static void TryReleasePendingRoamers(void);

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

    TryReleasePendingRoamers();
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
// ROAMER_COUNT is 2 and the regions run in either order, so both Johto beasts can hold the slots
// when the Hoenn League TV event fires. The event is one-shot, so a failed add is parked behind
// FLAG_LATI_ROAMER_PENDING (the colour is already in VAR_ROAMER_POKEMON) and released by
// TryReleasePendingRoamers() once a slot frees.
void InitRoamer(void)
{
    enum Species species = (gSpecialVar_0x8004 == 0) ? SPECIES_LATIAS : SPECIES_LATIOS; // Red : Blue

    if (!TryAddRoamer(species, 40))
        FlagSet(FLAG_LATI_ROAMER_PENDING);
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

// Release BOTH roaming beasts at once (Burned Tower beast-release and the post-game respawn).
// Requires ROAMER_COUNT >= 2: Entei and Raikou each take a slot; Suicune stays a static
// encounter. Deactivate any existing roamer once, then add both (a second InitJohtoRoamer
// call would re-deactivate and wipe the first).
void InitJohtoBeastRoamers(void)
{
    GetSetPokedexFlag(SpeciesToNationalPokedexNum(SPECIES_ENTEI), FLAG_SET_SEEN);
    GetSetPokedexFlag(SpeciesToNationalPokedexNum(SPECIES_RAIKOU), FLAG_SET_SEEN);
    GetSetPokedexFlag(SpeciesToNationalPokedexNum(SPECIES_SUICUNE), FLAG_SET_SEEN);
    // Only clear Johto beasts: a Hoenn Latios/Latias roaming when the player reaches Burned
    // Tower (Hoenn first) must survive, as at the Johto League respawn (issue #133). A beast
    // that finds no free slot is parked and released by TryReleasePendingRoamers().
    DeactivateJohtoBeastRoamers();
    FlagClear(FLAG_ENTEI_ROAMER_PENDING);
    FlagClear(FLAG_RAIKOU_ROAMER_PENDING);
    if (!TryAddRoamer(SPECIES_ENTEI, 40))
        FlagSet(FLAG_ENTEI_ROAMER_PENDING);
    if (!TryAddRoamer(SPECIES_RAIKOU, 40))
        FlagSet(FLAG_RAIKOU_ROAMER_PENDING);
}

static bool8 IsRoamerSpeciesActive(enum Species species)
{
    u32 i;

    for (i = 0; i < ROAMER_COUNT; i++)
    {
        if (ROAMER(i)->active && ROAMER(i)->species == species)
            return TRUE;
    }
    return FALSE;
}

// Records that a roaming Pokemon was CAUGHT (as opposed to defeated or fled from), so the
// post-game respawn below can tell a resolved encounter from an unresolved one. Called from
// the roamer battle-outcome path in ReturnFromBattleToOverworld, just before the roamer is
// deactivated (SetRoamerInactive is also used for a defeat, so it cannot mean "caught").
void MarkRoamerCaught(u32 roamerIndex)
{
    switch (ROAMER(roamerIndex)->species)
    {
    case SPECIES_ENTEI:
        FlagSet(FLAG_CAUGHT_ENTEI);
        break;
    case SPECIES_RAIKOU:
        FlagSet(FLAG_CAUGHT_RAIKOU);
        break;
    default:
        break;
    }
}

// Returns FALSE only when the beast is unresolved and found no free slot.
static bool32 TryRespawnJohtoBeast(enum Species species, u16 caughtFlag, u8 level)
{
    // Still roaming: the encounter is unresolved and needs no help. Re-creating it would
    // reroll its personality/IVs/shininess and wipe the damage the player has done to it.
    if (IsRoamerSpeciesActive(species))
        return TRUE;

    // Already caught: resolved, so no respawn - league rematches are unlimited, and an
    // unconditional respawn made the beasts farmable duplicates with a fresh shiny roll.
    // The Pokedex check is the fallback for saves made before MarkRoamerCaught existed
    // (the flag reads clear on those); the beasts have no other source in this build, so
    // owning one means the player caught the roamer.
    if (FlagGet(caughtFlag) || GetSetPokedexFlag(SpeciesToNationalPokedexNum(species), FLAG_GET_CAUGHT))
        return TRUE;

    // Unresolved (fainted, or never released): re-release it into a FREE roamer slot.
    return TryAddRoamer(species, level);
}

// Post-game beast respawn (Johto Hall of Fame rematch). Unlike InitJohtoBeastRoamers this
// resolves Entei and Raikou individually and never deactivates anybody else's roamer slot,
// so an active Hoenn Latios/Latias survives a league rematch (issue #133).
void RespawnJohtoBeastRoamers(void)
{
    GetSetPokedexFlag(SpeciesToNationalPokedexNum(SPECIES_ENTEI), FLAG_SET_SEEN);
    GetSetPokedexFlag(SpeciesToNationalPokedexNum(SPECIES_RAIKOU), FLAG_SET_SEEN);
    GetSetPokedexFlag(SpeciesToNationalPokedexNum(SPECIES_SUICUNE), FLAG_SET_SEEN);
    // A beast with no free slot (a Lati and the other beast roaming) is parked like at the release.
    if (!TryRespawnJohtoBeast(SPECIES_ENTEI, FLAG_CAUGHT_ENTEI, 40))
        FlagSet(FLAG_ENTEI_ROAMER_PENDING);
    if (!TryRespawnJohtoBeast(SPECIES_RAIKOU, FLAG_CAUGHT_RAIKOU, 40))
        FlagSet(FLAG_RAIKOU_ROAMER_PENDING);
}

static bool32 HasFreeRoamerSlot(void)
{
    u32 i;

    for (i = 0; i < ROAMER_COUNT; i++)
    {
        if (!ROAMER(i)->active)
            return TRUE;
    }
    return FALSE;
}

static bool32 IsJohtoBeastResolvedOrRoaming(enum Species species, u16 caughtFlag)
{
    return IsRoamerSpeciesActive(species) || FlagGet(caughtFlag)
        || GetSetPokedexFlag(SpeciesToNationalPokedexNum(species), FLAG_GET_CAUGHT);
}

static void TryReleaseParkedJohtoBeast(enum Species species, u16 caughtFlag, u16 pendingFlag)
{
    if (!FlagGet(pendingFlag))
        return;
    if (HasFreeRoamerSlot())
        TryRespawnJohtoBeast(species, caughtFlag, 40);
    if (IsJohtoBeastResolvedOrRoaming(species, caughtFlag))
        FlagClear(pendingFlag);
}

// Releases a roamer whose one-shot event found both slots taken (see InitRoamer and
// InitJohtoBeastRoamers). Runs on every map load, alongside the roamers' own moves.
static void TryReleasePendingRoamers(void)
{
    if (FlagGet(FLAG_LATI_ROAMER_PENDING) && HasFreeRoamerSlot())
    {
        enum Species species = (VarGet(VAR_ROAMER_POKEMON) == 0) ? SPECIES_LATIAS : SPECIES_LATIOS;

        if (TryAddRoamer(species, 40))
            FlagClear(FLAG_LATI_ROAMER_PENDING);
    }

    // Only the parked beast itself: a beast defeated while the other was parked must not come
    // straight back into the freed slot. Outside a League respawn a defeated beast stays away.
    TryReleaseParkedJohtoBeast(SPECIES_ENTEI, FLAG_CAUGHT_ENTEI, FLAG_ENTEI_ROAMER_PENDING);
    TryReleaseParkedJohtoBeast(SPECIES_RAIKOU, FLAG_CAUGHT_RAIKOU, FLAG_RAIKOU_ROAMER_PENDING);
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

void SetRoamerLocation(u32 roamerIndex, u8 mapGroup, u8 mapNum)
{
    sRoamerLocation[roamerIndex][MAP_GRP] = mapGroup;
    sRoamerLocation[roamerIndex][MAP_NUM] = mapNum;
}

void GetRoamerLocation(u32 roamerIndex, u8 *mapGroup, u8 *mapNum)
{
    *mapGroup = sRoamerLocation[roamerIndex][MAP_GRP];
    *mapNum = sRoamerLocation[roamerIndex][MAP_NUM];
}
