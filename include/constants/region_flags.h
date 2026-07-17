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

// Kanto trainer defeat-flag bank (E5-1). The Kanto trainer-id block (opponents_frlg.h,
// ids KANTO_TRAINER_ID_OFFSET+1..TRAINERS_COUNT-1) cannot use the inline
// TRAINER_FLAGS_START window without shifting every later SaveBlock1 flag, so its defeat
// flags live in their own SaveBlock3 array (kantoTrainerFlags[]), reached by a dedicated
// branch in GetFlagPointer(). TrainerIdToDefeatFlag() (battle_setup.c) maps trainer id ->
// flag id. 640 flags reserved; used = TRAINERS_COUNT - KANTO_TRAINER_ID_OFFSET = 1727 - 1096 = 631
// -> 9 spare ids for future Kanto-side trainers (bound enforced by the STATIC_ASSERT in
// battle_setup.c; recompute from that formula rather than trusting this figure).
#define FLAG_KANTO_TRAINER_BASE      0x6400 // directly above the Johto bank
#define KANTO_TRAINER_FLAG_BANK_SIZE 0x280  // 640 flags -> kantoTrainerFlags[80] in SaveBlock3
#define FLAG_KANTO_TRAINER_END       (FLAG_KANTO_TRAINER_BASE + KANTO_TRAINER_FLAG_BANK_SIZE - 1) // 0x667F
#define NUM_KANTO_TRAINER_FLAG_BYTES (KANTO_TRAINER_FLAG_BANK_SIZE / 8) // 80

// Per-region gym badges (8 each). Hoenn keeps the native FLAG_BADGE01..08_GET system flags.
// Kanto and Johto store their 8 badges in a FREE slice of their per-region bank; every badge
// consumer goes through GetBadgeFlag()/FLAG_*_BADGE(i), so the exact slice can be anything
// unused. Kanto uses the reserved HEAD gap of the rebased FRLG bank (0xA40..0xA47; the first
// real FRLG flag is at 0xA40+0x28, so 0..0x27 is free). Johto CANNOT use its bank head: the
// HnS port packs FLAG_JOHTO_SLICE story/item flags from offset 0x00 up to ~0x1FD, so the
// badges live at the TOP of the bank (0x3F8..0x3FF), clear of all story/item flags and still
// inside johtoFlags[128]. Gym scripts set these per-region (K9).
#define FLAG_JOHTO_BADGE_OFFSET    0x3F8                       // top 8 of the 0x400 Johto bank
// Kanto badges live in the free Kanto-bank head gap at +0x0B..0x12 (0xA4B..0xA52), ABOVE
// DAILY_FLAGS_END (0xA47). They used to sit at +0x00..0x07 (0xA40..0xA47), but the Johto
// trainer port grew MAX_TRAINERS_COUNT to 1096, which slid DAILY_FLAGS_END up to 0xA47 — so
// the badge byte fell inside the daily-flag range and ClearDailyFlags() wiped all 8 badges on
// every RTC day rollover. Keeping them in the head gap (champions at +0x08..0x0A, first real
// FRLG flag at +0x28) keeps them clear of the daily memset without touching FLAG_KANTO_BASE.
#define FLAG_KANTO_BADGE(i)        (FLAG_KANTO_BASE + 0x0B + (i))                    // i = 0..7
#define FLAG_JOHTO_BADGE(i)        (FLAG_JOHTO_BASE + FLAG_JOHTO_BADGE_OFFSET + (i)) // i = 0..7

// Object-like per-badge flags for SCRIPTS (.inc). Function-like macros do not reliably
// expand in the GAS .include path the scripts assemble through, so map/gym scripts use
// these explicit names (1-indexed, matching the gym order) instead of FLAG_*_BADGE(i).
#define FLAG_KANTO_BADGE_1         (FLAG_KANTO_BASE + 0x0B)
#define FLAG_KANTO_BADGE_2         (FLAG_KANTO_BASE + 0x0C)
#define FLAG_KANTO_BADGE_3         (FLAG_KANTO_BASE + 0x0D)
#define FLAG_KANTO_BADGE_4         (FLAG_KANTO_BASE + 0x0E)
#define FLAG_KANTO_BADGE_5         (FLAG_KANTO_BASE + 0x0F)
#define FLAG_KANTO_BADGE_6         (FLAG_KANTO_BASE + 0x10)
#define FLAG_KANTO_BADGE_7         (FLAG_KANTO_BASE + 0x11)
#define FLAG_KANTO_BADGE_8         (FLAG_KANTO_BASE + 0x12)
#define FLAG_JOHTO_BADGE_1         (FLAG_JOHTO_BASE + FLAG_JOHTO_BADGE_OFFSET + 0)
#define FLAG_JOHTO_BADGE_2         (FLAG_JOHTO_BASE + FLAG_JOHTO_BADGE_OFFSET + 1)
#define FLAG_JOHTO_BADGE_3         (FLAG_JOHTO_BASE + FLAG_JOHTO_BADGE_OFFSET + 2)
#define FLAG_JOHTO_BADGE_4         (FLAG_JOHTO_BASE + FLAG_JOHTO_BADGE_OFFSET + 3)
#define FLAG_JOHTO_BADGE_5         (FLAG_JOHTO_BASE + FLAG_JOHTO_BADGE_OFFSET + 4)
#define FLAG_JOHTO_BADGE_6         (FLAG_JOHTO_BASE + FLAG_JOHTO_BADGE_OFFSET + 5)
#define FLAG_JOHTO_BADGE_7         (FLAG_JOHTO_BASE + FLAG_JOHTO_BADGE_OFFSET + 6)
#define FLAG_JOHTO_BADGE_8         (FLAG_JOHTO_BASE + FLAG_JOHTO_BADGE_OFFSET + 7)

// Per-region champion status (region merge). Source of truth for IsNRegionChampion() and the
// per-region league/HOF gating. They live in the FREE Kanto-bank head gap (0xA48..0xA4A; badges
// relocated to 0xA4B..0xA52, first real FRLG flag at 0xA40+0x28, so 0x13..0x27 remains unused), so
// they are inline in SaveBlock1.flags[] and always readable regardless of the active region.
// Distinct from the global FLAG_IS_CHAMPION (FRLG sets that only post-Sevii) and FLAG_SYS_GAME_CLEAR.
#define FLAG_KANTO_CHAMPION        (FLAG_KANTO_BASE + 0x08)  // 0xA48
#define FLAG_JOHTO_CHAMPION        (FLAG_KANTO_BASE + 0x09)  // 0xA49
#define FLAG_HOENN_CHAMPION        (FLAG_KANTO_BASE + 0x0A)  // 0xA4A

#endif // GUARD_CONSTANTS_REGION_FLAGS_H
