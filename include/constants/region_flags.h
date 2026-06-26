#ifndef GUARD_CONSTANTS_REGION_FLAGS_H
#define GUARD_CONSTANTS_REGION_FLAGS_H

#include "constants/regions.h"

// Per-region FLAG banks (region merge, always-on).
//
// Each campaign region keeps its own story/badge flags so progress is independent.
//
// Kanto bank (PHASE 1, already live): FLAG_KANTO_BASE = 0x960, generated into
// include/constants/flags.h by ~/python/RegionMerge/GenKantoFlagBank.py. The FRLG
// flag namespace is rebased into 0x960..0xE1C and stored inline in SaveBlock1.flags[]
// (alongside Hoenn 0x0..0x95F and the relocated hidden items at 0xE20+). FLAGS_COUNT
// = 0xF50. See .superpowers/reports/region-phase1-flagbank.md.
//
// Johto bank (RESERVED here; populated during the Johto port): the Kanto scheme
// filled SaveBlock1.flags[] up to its 4-sector budget, so the Johto bank canNOT grow
// SaveBlock1. Instead it gets its own storage array (johtoFlags[]) in SaveBlock3,
// reached by a dedicated branch in GetFlagPointer(). Johto flag IDs live at 0x6000,
// clear of the Hoenn/Kanto range (0..0xF4F), the EWRAM special flags (0x4000..0x407F)
// and the testing flags (0x5000+).
#define FLAG_KANTO_BASE            0x960  // documented; defined by the generated flags.h block

#define FLAG_JOHTO_BASE            0x6000
#define JOHTO_FLAG_BANK_SIZE       0x400  // 1024 reserved Johto flags -> johtoFlags[128] in SaveBlock3
#define FLAG_JOHTO_END             (FLAG_JOHTO_BASE + JOHTO_FLAG_BANK_SIZE - 1) // 0x63FF
#define NUM_JOHTO_FLAG_BYTES       (JOHTO_FLAG_BANK_SIZE / 8) // 128

#endif // GUARD_CONSTANTS_REGION_FLAGS_H
