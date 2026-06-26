#ifndef GUARD_REGIONS_H
#define GUARD_REGIONS_H

#include "global.h"
#include "constants/regions.h"

enum KantoSubRegion GetKantoSubregion(u32 mapSecId);

static inline enum Region GetRegionForSectionId(u32 sectionId)
{
    if (sectionId >= KANTO_MAPSEC_START && sectionId < MAPSEC_SPECIAL_AREA)
        return REGION_KANTO;
    // Region merge (Johto port): Johto MAPSEC block sits at the enum tail.
    if (sectionId >= JOHTO_MAPSEC_START && sectionId <= JOHTO_MAPSEC_END)
        return REGION_JOHTO;
    return REGION_HOENN;
}

static inline enum Region GetCurrentRegion(void)
{
    return GetRegionForSectionId(gMapHeader.regionMapSectionId);
}

#if ALL_REGIONS
static inline enum Region GetStartRegion(void)
{
    return gSaveBlock2Ptr->startRegion ? gSaveBlock2Ptr->startRegion : REGION_HOENN;
}

static inline void SetStartRegion(enum Region r)
{
    gSaveBlock2Ptr->startRegion = r;
}
#endif // ALL_REGIONS

#endif // GUARD_REGIONS_H
