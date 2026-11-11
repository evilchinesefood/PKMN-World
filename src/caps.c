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
    static const u16 sEvCapPerBadge[NUM_BADGES] = {
        MAX_TOTAL_EVS *  1 / 17, MAX_TOTAL_EVS *  3 / 17, MAX_TOTAL_EVS *  5 / 17,
        MAX_TOTAL_EVS *  7 / 17, MAX_TOTAL_EVS *  9 / 17, MAX_TOTAL_EVS * 11 / 17,
        MAX_TOTAL_EVS * 13 / 17, MAX_TOTAL_EVS * 15 / 17,
    };

    if (B_EV_CAP_TYPE == EV_CAP_FLAG_LIST)
    {
        for (u32 evCap = 0; evCap < NUM_BADGES; evCap++)
        {
            if (!HasActiveRegionBadge(evCap))
                return sEvCapPerBadge[evCap];
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
