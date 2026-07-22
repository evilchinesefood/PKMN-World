#ifndef GUARD_CONFIG_QUESTS_H
#define GUARD_CONFIG_QUESTS_H

// When TRUE: adds a Quest menu (mission log) to the Start menu and enables the
// quest scripting commands. SCHEMA-CRITICAL: enabling this grows SaveBlock3.
//
// DORMANT BY DECISION (issue #12, 2026-07-21): the menu ships compiled-in but unreachable --
// all sSideQuests content is placeholder and FLAG_SYS_QUEST_MENU_GET is never set, so the
// Start-menu entry never appears. Kept TRUE because questData is frozen into SAVE FORMAT v6;
// flipping this OFF is a save-format break for no player benefit. To activate later: author
// real quests, set the flag where earned, add questmenu/subquestmenu unlock scripts.
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
