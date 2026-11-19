#include "global.h"
#include "battle.h"
#include "event_data.h"
#include "caps.h"
#include "pokemon.h"
#include "regions.h"


u32 GetCurrentLevelCap(void)
{
    return MAX_LEVEL;
}

u32 GetSoftLevelCapExpValue(u32 level, u32 expValue)
{
    return expValue;
}

u32 GetCurrentEVCap(void)
{
    // Region merge: EV caps follow the ACTIVE campaign region's badge progression.
    if (B_EV_CAP_TYPE == EV_CAP_FLAG_LIST)
    {
        for (u32 badge = 0; badge < NUM_BADGES; badge++)
        {
            if (!HasActiveRegionBadge(badge))
                return MAX_TOTAL_EVS * (2 * badge + 1) / (2 * NUM_BADGES + 1);
        }
    }
    else if (B_EV_CAP_TYPE == EV_CAP_VARIABLE)
    {
        return VarGet(B_EV_CAP_VARIABLE);
    }
    else if (B_EV_CAP_TYPE == EV_CAP_NO_GAIN)
    {
        return 0;
    }

    return MAX_TOTAL_EVS;
}

#if B_EV_CAP_TYPE == EV_CAP_VARIABLE
STATIC_ASSERT(B_EV_CAP_VARIABLE >= VARS_START, EvCapVariableIsNotAValidVarId);
#endif
