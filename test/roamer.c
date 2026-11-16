#include "global.h"
#include "event_data.h"
#include "pokedex.h"
#include "roamer.h"
#include "constants/flags.h"
#include "test/test.h"

static u32 ActiveCount(enum Species species)
{
    u32 i, n = 0;

    for (i = 0; i < ROAMER_COUNT; i++)
    {
        if (gSaveBlock1Ptr->roamer[i].active && gSaveBlock1Ptr->roamer[i].species == species)
            n++;
    }
    return n;
}

static s32 SlotOf(enum Species species)
{
    u32 i;

    for (i = 0; i < ROAMER_COUNT; i++)
    {
        if (gSaveBlock1Ptr->roamer[i].active && gSaveBlock1Ptr->roamer[i].species == species)
            return i;
    }
    return -1;
}

static void ResetRoamerState(void)
{
    DeactivateAllRoamers();
    FlagClear(FLAG_LATI_ROAMER_PENDING);
    FlagClear(FLAG_ENTEI_ROAMER_PENDING);
    FlagClear(FLAG_RAIKOU_ROAMER_PENDING);
    FlagClear(FLAG_CAUGHT_ENTEI);
    FlagClear(FLAG_CAUGHT_RAIKOU);
    GetSetPokedexFlag(SpeciesToNationalPokedexNum(SPECIES_ENTEI), FLAG_SET_SEEN);
    GetSetPokedexFlag(SpeciesToNationalPokedexNum(SPECIES_RAIKOU), FLAG_SET_SEEN);
}

TEST("Burned Tower with a Lati roaming parks Raikou, and a defeated Entei does not take its slot")
{
    ResetRoamerState();
    gSpecialVar_0x8004 = 0;
    InitRoamer();
    InitJohtoBeastRoamers();
    EXPECT_EQ(ActiveCount(SPECIES_LATIAS), 1);
    EXPECT_EQ(ActiveCount(SPECIES_ENTEI), 1);
    EXPECT_EQ(ActiveCount(SPECIES_RAIKOU), 0);
    EXPECT(FlagGet(FLAG_RAIKOU_ROAMER_PENDING));
    EXPECT(!FlagGet(FLAG_ENTEI_ROAMER_PENDING));

    // Entei defeated (not caught): the battle deactivates its slot.
    SetRoamerInactive(SlotOf(SPECIES_ENTEI));
    MoveAllRoamersToOtherLocationSets();
    EXPECT_EQ(ActiveCount(SPECIES_RAIKOU), 1);
    EXPECT_EQ(ActiveCount(SPECIES_ENTEI), 0);
    EXPECT_EQ(ActiveCount(SPECIES_LATIAS), 1);
    EXPECT(!FlagGet(FLAG_RAIKOU_ROAMER_PENDING));
}

TEST("A Johto League respawn with no free slot parks the beast until one frees")
{
    ResetRoamerState();
    gSpecialVar_0x8004 = 1;
    InitRoamer();
    InitJohtoBeastRoamers();
    // Raikou released once Entei is defeated, then the League respawns Entei with no slot.
    SetRoamerInactive(SlotOf(SPECIES_ENTEI));
    MoveAllRoamersToOtherLocationSets();
    RespawnJohtoBeastRoamers();
    EXPECT_EQ(ActiveCount(SPECIES_ENTEI), 0);
    EXPECT(FlagGet(FLAG_ENTEI_ROAMER_PENDING));

    // A caught Latios frees its slot: the parked Entei takes it, once.
    SetRoamerInactive(SlotOf(SPECIES_LATIOS));
    MoveAllRoamersToOtherLocationSets();
    MoveAllRoamersToOtherLocationSets();
    EXPECT_EQ(ActiveCount(SPECIES_ENTEI), 1);
    EXPECT_EQ(ActiveCount(SPECIES_RAIKOU), 1);
    EXPECT(!FlagGet(FLAG_ENTEI_ROAMER_PENDING));
}

TEST("A parked beast already caught is dropped rather than duplicated")
{
    ResetRoamerState();
    gSpecialVar_0x8004 = 0;
    InitRoamer();
    InitJohtoBeastRoamers();
    FlagSet(FLAG_CAUGHT_RAIKOU);
    SetRoamerInactive(SlotOf(SPECIES_LATIAS));
    MoveAllRoamersToOtherLocationSets();
    EXPECT_EQ(ActiveCount(SPECIES_RAIKOU), 0);
    EXPECT(!FlagGet(FLAG_RAIKOU_ROAMER_PENDING));
}
