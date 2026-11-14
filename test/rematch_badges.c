#include "global.h"
#include "battle_setup.h"
#include "event_data.h"
#include "fieldmap.h"
#include "load_save.h"
#include "main.h"
#include "regions.h"
#include "vs_seeker.h"
#include "test/test.h"
#include "constants/opponents.h"
#include "constants/region_map_sections.h"

// HasEnoughBadgesForRematch reads the Hoenn badge bank, unlike the battle code that follows the
// campaign region. It gates only the Hoenn Match Call step ticker; the Kanto VS Seeker stages its
// rematches by Kanto badges and Johto has no rematches. These pin that split.

static void ResetRematchSave(u32 mapsec)
{
    memset(gSaveBlock1Ptr, 0, sizeof(*gSaveBlock1Ptr));
    memset(gSaveBlock2Ptr, 0, sizeof(*gSaveBlock2Ptr));
    memset(gSaveBlock3Ptr, 0, sizeof(*gSaveBlock3Ptr));
    gMapHeader.regionMapSectionId = mapsec;
}

static void GiveBadges(enum Region region, u32 count)
{
    for (u32 i = 0; i < count; i++)
        FlagSet(GetBadgeFlag(region, i));
}

TEST("Hoenn Match Call rematch steps count Hoenn badges, not Kanto or Johto ones")
{
    u32 region = 0, count = 0, steps = 0;
    PARAMETRIZE { region = REGION_KANTO; count = 8; steps = 0; }
    PARAMETRIZE { region = REGION_JOHTO; count = 8; steps = 0; }
    PARAMETRIZE { region = REGION_HOENN; count = 4; steps = 0; }
    PARAMETRIZE { region = REGION_HOENN; count = 5; steps = 3; }
    ResetRematchSave(MAPSEC_ROUTE_101);
    GiveBadges(region, count);
    for (u32 i = 0; i < 3; i++)
        IncrementRematchStepCounter();
    EXPECT_EQ(gSaveBlock1Ptr->trainerRematchStepCounter & 0xFF, steps);
}

TEST("Kanto VS Seeker rematch stage counts Kanto badges, not Hoenn ones")
{
    u32 region = 0, count = 0, expected = 0;
    PARAMETRIZE { region = REGION_HOENN; count = 8; expected = TRAINER_YOUNGSTER_BEN; }
    PARAMETRIZE { region = REGION_KANTO; count = 3; expected = TRAINER_YOUNGSTER_BEN_2; }
    ResetRematchSave(MAPSEC_PALLET_TOWN);
    GiveBadges(region, count);
    SetTrainerFlag(TRAINER_YOUNGSTER_BEN);
    EXPECT_EQ(GetRematchTrainerIdVSSeeker(TRAINER_YOUNGSTER_BEN), expected);
}
