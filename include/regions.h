#ifndef GUARD_REGIONS_H
#define GUARD_REGIONS_H

#include "global.h"
#include "constants/regions.h"

enum KantoSubRegion GetKantoSubregion(u32 mapSecId);

static inline enum Region GetRegionForSectionId(u32 sectionId)
{
    // MAPSEC_SPECIAL_AREA is deliberately EXCLUDED from Kanto here — it tags only the
    // region-agnostic FRLG link rooms. (KANTO_MAPSEC_END is defined INCLUSIVE of it for the
    // map-name-popup discard range; the two intentionally differ.) Never assign a Kanto
    // single-player map to MAPSEC_SPECIAL_AREA, or it will misclassify as REGION_HOENN.
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
void SyncDifficultyForRegion(enum Region region);
bool8 IsRegionChampion(enum Region region);
// Re-seed the volatile EWRAM gCurrentRegion from the current map on field load (skips the hub).
void ResyncCurrentRegionFromMap(void);

#if ALL_REGIONS
// The active-campaign region: the region whose badges/obedience govern the traveling party.
// This is the persisted SaveBlock2.currentRegion (mirrored at runtime by gCurrentRegion),
// set at each hub gate-cross and restored on load. It is DISTINCT from GetCurrentRegion()
// above, which derives the region of the map you are currently standing on (the two differ
// only inside the hub). Prefer this accessor for "which campaign am I in" reads.
static inline enum Region GetActiveRegion(void)
{
    return gCurrentRegion;
}
#endif // ALL_REGIONS

#endif // GUARD_REGIONS_H
