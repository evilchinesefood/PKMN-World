#include "global.h"
#include "regions.h"
#include "event_data.h"
#include "script.h"
#include "constants/regions.h"
#include "constants/vars.h"

// World Transit hub - region-switch foundation. Pairs with the map-derived
// GetCurrentRegion() in include/regions.h.
//
// gCurrentRegion is the EWRAM-resident "active campaign" context the hub sets when the
// player picks a destination. Per the merge architecture's IWRAM discipline, new resident
// region state lives in EWRAM (never IWRAM) and costs zero SaveBlock growth.
EWRAM_DATA enum Region gCurrentRegion = REGION_NONE;

// Set the active region context for the campaign the player is travelling into.
//
// In this engine most "region context" needs no runtime swap on a region change:
//   - Per-region story FLAGS/VARS use absolute IDs (FLAG_<REGION>_BASE / VAR_<REGION>_BASE)
//     dispatched in GetFlagPointer()/GetVarPointer() - there is no active bank pointer to
//     repoint, so nothing to swap here.
//   - The region map, roamer ownership and GetCurrentRegion() all derive the region from
//     the destination map's MAPSEC / map group, so they self-update once the hub warp lands.
//
// So the routine records the explicit active-region intent (the seam region-aware systems
// and the deferred arrival-quest work hook into) and leaves the rest to the warp.
void SetCurrentRegion(enum Region region)
{
    gCurrentRegion = region;

    // TODO(region-switch follow-up): when per-region heal/fly defaults exist, reset the
    // last-heal location to this region's start here. Deferred with the arrival-quest work
    // (.plans/features/03b-RegionSwitchDesignSpec.md G4/Section 5). The clerk's resume warp
    // already drops the player at the chosen region's start town.
}

// callnative hook used by the hub transit clerk. The clerk's multichoice stores the
// selection in VAR_RESULT (0 = Kanto, 1 = Johto, 2 = Hoenn); map it onto enum Region,
// which is contiguous from REGION_KANTO.
void RegionHub_ScrSetCurrentRegion(struct ScriptContext *ctx)
{
    SetCurrentRegion((enum Region)(REGION_KANTO + VarGet(VAR_RESULT)));
}

// World-tour board (R8). Counts the player's gym badges across all three regions' badge
// banks (8 each, set per-region by K9) and exposes them to the hub board script:
//   VAR_0x8000 = total /24, VAR_0x8001 = Hoenn, VAR_0x8002 = Kanto, VAR_0x8003 = Johto.
// The grand 24-badge tournament is a future item; this is a read-only progress report.
void RegionHub_ScrCountWorldTourBadges(struct ScriptContext *ctx)
{
    u8 i, hoenn = 0, kanto = 0, johto = 0;

    for (i = 0; i < NUM_BADGES; i++)
    {
        if (HasBadge(REGION_HOENN, i))
            hoenn++;
        if (HasBadge(REGION_KANTO, i))
            kanto++;
        if (HasBadge(REGION_JOHTO, i))
            johto++;
    }

    gSpecialVar_0x8000 = hoenn + kanto + johto;
    gSpecialVar_0x8001 = hoenn;
    gSpecialVar_0x8002 = kanto;
    gSpecialVar_0x8003 = johto;
}
