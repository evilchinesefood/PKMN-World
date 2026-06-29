#include "global.h"
#include "battle.h"
#include "event_data.h"
#include "caps.h"
#include "pokemon.h"


u32 GetCurrentLevelCap(void)
{
    // Region merge: caps follow the CURRENT region's badge progression (per-region bank).
    static const u32 sLevelCapPerBadge[NUM_BADGES] = { 15, 19, 24, 29, 31, 33, 42, 46 };

    u32 i;

    if (B_LEVEL_CAP_TYPE == LEVEL_CAP_FLAG_LIST)
    {
        for (i = 0; i < NUM_BADGES; i++)
        {
            if (!HasCurrentRegionBadge(i))
                return sLevelCapPerBadge[i];
        }
        if (!FlagGet(FLAG_IS_CHAMPION))
            return 58;
    }
    else if (B_LEVEL_CAP_TYPE == LEVEL_CAP_VARIABLE)
    {
        return VarGet(B_LEVEL_CAP_VARIABLE);
    }

    return MAX_LEVEL;
}

u32 GetSoftLevelCapExpValue(u32 level, u32 expValue)
{
    static const u32 sExpScalingDown[5] = { 4, 8, 16, 32, 64 };
    static const u32 sExpScalingUp[5]   = { 16, 8, 4, 2, 1 };

    u32 levelDifference;
    u32 currentLevelCap = GetCurrentLevelCap();

    if (B_EXP_CAP_TYPE == EXP_CAP_NONE)
        return expValue;

    if (level < currentLevelCap)
    {
        if (B_LEVEL_CAP_EXP_UP)
        {
            levelDifference = currentLevelCap - level;
            if (levelDifference > ARRAY_COUNT(sExpScalingUp) - 1)
                return expValue + (expValue / sExpScalingUp[ARRAY_COUNT(sExpScalingUp) - 1]);
            else
                return expValue + (expValue / sExpScalingUp[levelDifference]);
        }
        else
        {
            return expValue;
        }
    }
    else if (B_EXP_CAP_TYPE == EXP_CAP_HARD)
    {
        return 0;
    }
    else if (B_EXP_CAP_TYPE == EXP_CAP_SOFT)
    {
        levelDifference = level - currentLevelCap;
        if (levelDifference > ARRAY_COUNT(sExpScalingDown) - 1)
            return expValue / sExpScalingDown[ARRAY_COUNT(sExpScalingDown) - 1];
        else
            return expValue / sExpScalingDown[levelDifference];
    }
    else
    {
       return expValue;
    }
}

u32 GetCurrentEVCap(void)
{
    // Region merge: EV caps follow the CURRENT region's badge progression (per-region bank).
    static const u16 sEvCapPerBadge[NUM_BADGES] = {
        MAX_TOTAL_EVS *  1 / 17, MAX_TOTAL_EVS *  3 / 17, MAX_TOTAL_EVS *  5 / 17,
        MAX_TOTAL_EVS *  7 / 17, MAX_TOTAL_EVS *  9 / 17, MAX_TOTAL_EVS * 11 / 17,
        MAX_TOTAL_EVS * 13 / 17, MAX_TOTAL_EVS * 15 / 17,
    };

    if (B_EV_CAP_TYPE == EV_CAP_FLAG_LIST)
    {
        for (u32 evCap = 0; evCap < NUM_BADGES; evCap++)
        {
            if (!HasCurrentRegionBadge(evCap))
                return sEvCapPerBadge[evCap];
        }
        if (!FlagGet(FLAG_IS_CHAMPION))
            return MAX_TOTAL_EVS;
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
