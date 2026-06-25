#ifndef GUARD_CONFIG_QUESTS_H
#define GUARD_CONFIG_QUESTS_H

// When TRUE: adds a Quest menu (mission log) to the Start menu and enables the
// quest scripting commands. SCHEMA-CRITICAL: enabling this grows SaveBlock3.
#define QUEST_MENU                  FALSE

// When TRUE: favorited quests can be pinned to the top of the list.
#define QUEST_MENU_ALLOW_FAVORITES  TRUE

// When TRUE: shows the completion percentage in the quest menu header.
#define QUEST_MENU_SHOW_PERCENTAGE  TRUE

// When TRUE: a quest's description/location/icon can vary by a game VAR
// (per-quest branching). Reads ordinary game VARs, so it does NOT grow SaveBlock3.
#define OW_QUEST_BRANCHING          FALSE

// How many branch states a complex quest may have. Forced to 1 when branching is
// OFF so the per-state arrays in sSideQuests stay single-element (no ROM growth).
#if OW_QUEST_BRANCHING
#define OW_QUEST_MAX_STATES         50
#else
#define OW_QUEST_MAX_STATES         1
#endif

#endif // GUARD_CONFIG_QUESTS_H
