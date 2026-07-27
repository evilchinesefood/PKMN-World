#ifndef GUARD_CONFIG_QUESTS_H
#define GUARD_CONFIG_QUESTS_H

// When TRUE: adds a Quest menu (mission log) to the Start menu and enables the
// quest scripting commands. SCHEMA-CRITICAL: enabling this grows SaveBlock3.
//
// DORMANT BY DECISION (issue #12, 2026-07-21): the menu ships compiled-in but unreachable --
// all 30 sSideQuests entries are placeholder ("Side Quest 1".."Side Quest 30", src/strings.c)
// and FLAG_SYS_QUEST_MENU_GET is never set, so the Start-menu entry never appears. To activate
// later: author real quests, set the flag where earned, add questmenu/subquestmenu unlock
// scripts.
//
// Measured cost of leaving it on: questData is QUEST_FLAGS_COUNT(4) * QUEST_STATES(5) = 20 bytes
// of SaveBlock3 (392 B free at v7), and src/quests.o contributes ~26 KB of ROM (~0.4% of the
// cart, which sits at 59.5%). Small, but not zero.
//
// ⚠ The original note justified keeping this TRUE because questData was "frozen into SAVE FORMAT
// v6", making an OFF flip a save break for no player benefit. THAT REASON EXPIRED on 2026-07-24:
// v7 is a hard break that refuses every pre-v7 save outright, so v7 was the free window to drop
// this and it was missed. It is still not worth flipping now -- v1.4 shipped v7 to players, and a
// second forced-new-game to reclaim 20 bytes and 26 KB is a bad trade. Revisit only if a future
// save-format bump happens for its own reasons; then this rides along for free.
#define QUEST_MENU                  TRUE

// When TRUE: favorited quests can be pinned to the top of the list.
#define QUEST_MENU_ALLOW_FAVORITES  TRUE

// When TRUE: shows the completion percentage in the quest menu header.
#define QUEST_MENU_SHOW_PERCENTAGE  TRUE

// When TRUE: a quest's description/location/icon can vary by a game VAR
// (per-quest branching). Reads ordinary game VARs, so it does NOT grow SaveBlock3.
#define OW_QUEST_BRANCHING          TRUE

// How many branch states a complex quest may have. Forced to 1 when branching is
// OFF so the per-state arrays in sSideQuests stay single-element (no ROM growth).
#if OW_QUEST_BRANCHING
#define OW_QUEST_MAX_STATES         50
#else
#define OW_QUEST_MAX_STATES         1
#endif

#endif // GUARD_CONFIG_QUESTS_H
