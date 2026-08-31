#include "global.h"
#include "event_data.h"
#include "regions.h"
#include "test/test.h"

TEST("World Transit later arrivals unlock on the target region's first badge only")
{
    static const enum Region sRegions[] =
    {
        REGION_KANTO,
        REGION_JOHTO,
        REGION_HOENN,
    };
    u32 i;

    // These bits only suppress the one-time starting-town narration. Even all three being set
    // must not unlock Vermilion, Goldenrod Station, or Slateport.
    gSaveBlock2Ptr->kantoIntroDone = TRUE;
    gSaveBlock2Ptr->johtoIntroDone = TRUE;
    gSaveBlock2Ptr->hoennIntroDone = TRUE;

    for (i = 0; i < ARRAY_COUNT(sRegions); i++)
    {
        enum Region region = sRegions[i];

        gCurrentRegion = region;
        FlagClear(GetBadgeFlag(region, 0));
        FlagClear(GetBadgeFlag(region, 1));

        gSpecialVar_Result = TRUE;
        RegionHub_ScrTargetHasFirstBadge(NULL);
        EXPECT(!gSpecialVar_Result);

        // A different badge must not accidentally satisfy the exact first-badge predicate.
        FlagSet(GetBadgeFlag(region, 1));
        RegionHub_ScrTargetHasFirstBadge(NULL);
        EXPECT(!gSpecialVar_Result);

        FlagSet(GetBadgeFlag(region, 0));
        RegionHub_ScrTargetHasFirstBadge(NULL);
        EXPECT(gSpecialVar_Result);
    }
}
