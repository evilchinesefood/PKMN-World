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

// Region-switch (World Transit hub). gCurrentRegion is the explicit active-campaign
// context the hub sets when travelling; GetCurrentRegion() above stays the map-derived
// source of truth. See src/region_switch.c.
extern enum Region gCurrentRegion;
void SetCurrentRegion(enum Region region);

// Region-switch helpers (defined in src/region_switch.c).
// DepositPartyToPC: box the whole player party to the global PC on a region switch (retrievable).
// IsNRegionChampion: TRUE once the player has cleared at least n regions' leagues.
void DepositPartyToPC(void);
bool8 IsNRegionChampion(u8 n);

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
