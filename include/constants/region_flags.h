#ifndef GUARD_CONSTANTS_REGION_FLAGS_H
#define GUARD_CONSTANTS_REGION_FLAGS_H

#include "constants/regions.h"

// Per-region FLAG banks (region merge, always-on).
//
// Each campaign region keeps its own story/badge flags so progress is independent.
//
// Kanto bank: FLAG_KANTO_BASE = 0xA40, generated into include/constants/flags.h by
// ~/python/RegionMerge/GenKantoFlagBank.py. The FRLG flag namespace is rebased into the
// bank (first real FRLG flag at 0xA40+0x28) and stored inline in SaveBlock1.flags[]
// (alongside Hoenn, the expanded trainer/system flags, and the relocated hidden items at
// 0xF00+). FLAGS_COUNT = 0x1030. The base moved 0x960->0xA40 when the Johto trainer port
// grew MAX_TRAINERS_COUNT (S4-T); KEEP THIS IN SYNC with GenKantoFlagBank.py's KANTO_BASE.
// See .superpowers/reports/region-phase1-flagbank.md.
//
// Johto bank (RESERVED here; populated during the Johto port): the Kanto scheme
// filled SaveBlock1.flags[] up to its 4-sector budget, so the Johto bank canNOT grow
// SaveBlock1. Instead it gets its own storage array (johtoFlags[]) in SaveBlock3,
// reached by a dedicated branch in GetFlagPointer(). Johto flag IDs live at 0x6000,
// clear of the Hoenn/Kanto range (0..0xF4F), the EWRAM special flags (0x4000..0x407F)
// and the testing flags (0x5000+).
#define FLAG_KANTO_BASE            0xA40  // must match GenKantoFlagBank.py KANTO_BASE / flags.h block

#define FLAG_JOHTO_BASE            0x6000
#define JOHTO_FLAG_BANK_SIZE       0x400  // 1024 reserved Johto flags -> johtoFlags[128] in SaveBlock3
#define FLAG_JOHTO_END             (FLAG_JOHTO_BASE + JOHTO_FLAG_BANK_SIZE - 1) // 0x63FF
#define NUM_JOHTO_FLAG_BYTES       (JOHTO_FLAG_BANK_SIZE / 8) // 128

// Per-region gym badges (8 each). Hoenn keeps the native FLAG_BADGE01..08_GET system flags.
// Kanto and Johto reserve the first 8 localIds (0..7) of their bank as the canonical badge
// slots, so the multi-page Trainer Card (RG2) and the per-region obedience cap / HM gate
// (K9 / RG3) all read one place: GetRegionFlagBase(region) + badgeIndex. The Kanto slots sit
// in the reserved head gap of the rebased FRLG bank (0xA40..0xA47, SaveBlock1.flags[]; the
// first real FRLG flag is at 0xA40+0x28); the Johto slots sit at the head of johtoFlags[]
// (0x6000..0x6007, SaveBlock3). Gym scripts set these per-region (K9).
#define FLAG_KANTO_BADGE(i)        (FLAG_KANTO_BASE + (i))   // i = 0..7 (C use)
#define FLAG_JOHTO_BADGE(i)        (FLAG_JOHTO_BASE + (i))   // i = 0..7 (C use)

// Object-like per-badge flags for SCRIPTS (.inc). Function-like macros do not reliably
// expand in the GAS .include path the scripts assemble through, so map/gym scripts use
// these explicit names (1-indexed, matching the gym order) instead of FLAG_*_BADGE(i).
#define FLAG_KANTO_BADGE_1         (FLAG_KANTO_BASE + 0)
#define FLAG_KANTO_BADGE_2         (FLAG_KANTO_BASE + 1)
#define FLAG_KANTO_BADGE_3         (FLAG_KANTO_BASE + 2)
#define FLAG_KANTO_BADGE_4         (FLAG_KANTO_BASE + 3)
#define FLAG_KANTO_BADGE_5         (FLAG_KANTO_BASE + 4)
#define FLAG_KANTO_BADGE_6         (FLAG_KANTO_BASE + 5)
#define FLAG_KANTO_BADGE_7         (FLAG_KANTO_BASE + 6)
#define FLAG_KANTO_BADGE_8         (FLAG_KANTO_BASE + 7)
#define FLAG_JOHTO_BADGE_1         (FLAG_JOHTO_BASE + 0)
#define FLAG_JOHTO_BADGE_2         (FLAG_JOHTO_BASE + 1)
#define FLAG_JOHTO_BADGE_3         (FLAG_JOHTO_BASE + 2)
#define FLAG_JOHTO_BADGE_4         (FLAG_JOHTO_BASE + 3)
#define FLAG_JOHTO_BADGE_5         (FLAG_JOHTO_BASE + 4)
#define FLAG_JOHTO_BADGE_6         (FLAG_JOHTO_BASE + 5)
#define FLAG_JOHTO_BADGE_7         (FLAG_JOHTO_BASE + 6)
#define FLAG_JOHTO_BADGE_8         (FLAG_JOHTO_BASE + 7)

#endif // GUARD_CONSTANTS_REGION_FLAGS_H
