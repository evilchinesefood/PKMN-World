#ifndef GUARD_CONSTANTS_REGION_VARS_H
#define GUARD_CONSTANTS_REGION_VARS_H

#include "constants/regions.h"

// Per-region VAR bank (region merge, always-on).
//
// Mirrors the Phase-1 Kanto FLAG bank (see include/constants/region_flags.h):
// each campaign region gets its own isolated window of story vars so progress in
// Hoenn, Kanto and Johto never aliases. Shared/system vars (TEMP, OBJ_GFX, frontier,
// daily counters, secret base, etc.) stay in the single global SaveBlock1.vars[]
// pool at 0x4000 — only per-region STORY vars live here.
//
// The bank lives at 0xA000, clear of the general pool (0x4000), special vars
// (0x8000) and testing vars (0x9000). Storage is a dedicated regionVars[] array in
// SaveBlock3 (which has ample slack), NOT SaveBlock1 (which is near its 4-sector
// budget), so adding the bank costs SaveBlock1 zero bytes.

#define REGION_VARS_START          0xA000
#define REGION_VAR_BANK_SIZE       0x80   // 128 story vars per region (>= the ~100 each region needs)

// One window per campaign region. REGION_NONE(0) is unused; windows are indexed by
// (enum Region - REGION_KANTO) so the three live banks pack contiguously.
#define VAR_KANTO_BASE             (REGION_VARS_START + 0 * REGION_VAR_BANK_SIZE) // 0xA000..0xA07F
#define VAR_JOHTO_BASE             (REGION_VARS_START + 1 * REGION_VAR_BANK_SIZE) // 0xA080..0xA0FF
#define VAR_HOENN_BASE             (REGION_VARS_START + 2 * REGION_VAR_BANK_SIZE) // 0xA100..0xA17F

#define NUM_REGION_VAR_BANKS       3
#define NUM_REGION_VARS            (NUM_REGION_VAR_BANKS * REGION_VAR_BANK_SIZE)   // 384 vars -> 768 bytes
#define REGION_VARS_END            (REGION_VARS_START + NUM_REGION_VARS - 1)       // 0xA17F

// The reserved global customization vars (VAR_PLAYER_CHARACTER / VAR_PLAYER_PALETTE,
// Lane K) live in the shared SaveBlock1.vars[] pool — see include/constants/vars.h.
// They are global (one chosen character + outfit across every region), so they are
// intentionally NOT in a per-region bank.

#endif // GUARD_CONSTANTS_REGION_VARS_H
