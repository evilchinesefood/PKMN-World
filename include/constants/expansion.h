#ifndef GUARD_CONSTANTS_EXPANSION_H
#define GUARD_CONSTANTS_EXPANSION_H

// Last version: 1.16.3
#define EXPANSION_VERSION_MAJOR 1
#define EXPANSION_VERSION_MINOR 16
#define EXPANSION_VERSION_PATCH 4

// FALSE if this this version of Expansion is not a tagged commit, i.e.
// it contains unreleased changes.
#define EXPANSION_TAGGED_RELEASE FALSE

// Issue #120. This tree is NOT at a tagged release, and the numbers above alone cannot say where
// it actually sits -- which was the whole complaint: the previous header read "1.16.2 /
// TAGGED_RELEASE FALSE / last version 1.16.1" while the real base was upstream master from
// 2026-06-25, ~17 commits BEFORE 1.16.2 was tagged, with ~20 PRs hand-replayed on top.
//
// So, precisely:
//
//   Base before this merge : 4d19ec397ccfe7d7d4fdcd51aa32222539834e9d (2026-06-25)
//                            "fix(sprite): handle weather blending for BLEND_IMMUNE_FLAG (#10322)"
//                            established by exact blob match, not inference -- 5 of 5 probe files
//                            identical, and it is fce6ae04b^, the parent of the #10332 fix whose
//                            pre-fix side our src/trainer_pools.c matched.
//   Merged up to           : 82598c4d88c9a141d350061575fe3c6810743d4b (2026-08-23)
//                            "Fix AI not calcing crit when high enough crit stage (#10700)"
//                            i.e. rh-hideout/pokeemerald-expansion master, 193 commits on,
//                            which is PAST expansion/1.16.3 (c828d12721).
//
// Anyone bisecting against upstream should diff against that second SHA, not against 1.16.4.

#endif
