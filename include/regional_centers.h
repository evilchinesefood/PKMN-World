#ifndef GUARD_REGIONAL_CENTERS_H
#define GUARD_REGIONAL_CENTERS_H

#include "global.h"
#include "constants/regions.h"

struct RegionalCenterInfo
{
    struct WarpData arrival;
    u16 healLocation;
    enum Region region;
    const u8 *name;
};

u16 RegionalCenter_ForMap(u8 mapGroup, u8 mapNum);
enum Region RegionalCenter_GetRegion(u16 id);
const u8 *RegionalCenter_GetName(u16 id);
bool32 RegionalCenter_IsHoennWest(u16 id);
bool32 RegionalCenter_IsSafe(u16 id, enum Region destination, struct Pokemon *party, u8 count);
bool32 RegionalCenter_GetDestination(u16 id, struct WarpData *warp, u16 *healLocation);
u32 RegionalCenter_Count(void);
const struct RegionalCenterInfo *RegionalCenter_GetInfo(u16 id);

#endif
