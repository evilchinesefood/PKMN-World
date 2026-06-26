#ifndef GUARD_CONSTANTS_JOHTO_VARS_H
#define GUARD_CONSTANTS_JOHTO_VARS_H

#include "constants/region_vars.h"

// Johto story vars (region merge, always-on). These live in the per-region var
// pool (VAR_JOHTO_BASE = 0xA080), stored in SaveBlock3.regionVars[] via
// GetVarPointer()'s region branch, so Johto progress is isolated from Hoenn/Kanto.
// Starting-area slice subset; append as later Johto maps are ported (128 slots).
#define VAR_JOHTO_SLICE(n)            (VAR_JOHTO_BASE + (n))

#define VAR_NEWBARK_TOWN_STATE        VAR_JOHTO_SLICE(0x00)
#define VAR_NEWBARKTOWN_LABSTATE      VAR_JOHTO_SLICE(0x01)
#define VAR_CHERRYGROVE_CITY_STATE    VAR_JOHTO_SLICE(0x02)
#define VAR_GOLDENROD_CITY_STATE      VAR_JOHTO_SLICE(0x03)
#define VAR_ECRUTEAK_CITY_THEATER     VAR_JOHTO_SLICE(0x04)

#endif // GUARD_CONSTANTS_JOHTO_VARS_H
