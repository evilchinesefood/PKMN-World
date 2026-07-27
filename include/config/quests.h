#ifndef GUARD_CONFIG_QUESTS_H
#define GUARD_CONFIG_QUESTS_H

// When TRUE: adds a Quest menu (mission log) to the Start menu and enables the
// quest scripting commands.
//
// REMOVED (2026-07-27). It was never usable: all 30 sSideQuests entries were placeholder
// ("Side Quest 1".."Side Quest 30", "Description 1"..., "Map 1"...) and FLAG_SYS_QUEST_MENU_GET
// was never set anywhere, so the Start-menu entry could not appear. Nothing was ever authored for
// this game -- the 30 entries are the upstream demo fixture that shipped with the port
// (PokemonSanFran/pokeemerald, see CREDITS.md), there to exercise the UI's sort/favorite/subquest/
// branching paths. Turning it off costs no content because there was none.
//
// Reclaims ~26 KB of ROM: src/quests.c is wrapped in `#if QUEST_MENU` end to end, so it now
// compiles to nothing.
//
// ⚠ THIS FLAG NO LONGER MOVES THE SAVE LAYOUT. questData/subQuests used to sit inside
// `#if QUEST_MENU` in SaveBlock3, ahead of `struct RegionSave region` — so flipping this would
// have shifted `region` off its pinned 0x20 and misread every existing v7 save. Those 24 bytes are
// now an unconditional `reservedQuestData[24]` in global.h, so the layout is identical with the
// flag either way and v1.4 saves keep loading. Reclaiming that space is a save-format v8; see the
// comment there before trying.
//
// To bring quests back: set this TRUE, author real sSideQuests entries, set
// FLAG_SYS_QUEST_MENU_GET where earned, and add questmenu/subquestmenu unlock scripts. The UI,
// script commands and save schema all still work — only the content was ever missing.
#define QUEST_MENU                  FALSE

// When TRUE: favorited quests can be pinned to the top of the list.
#define QUEST_MENU_ALLOW_FAVORITES  TRUE

// When TRUE: shows the completion percentage in the quest menu header.
#define QUEST_MENU_SHOW_PERCENTAGE  TRUE

// When TRUE: a quest's description/location/icon can vary by a game VAR
// (per-quest branching). Reads ordinary game VARs, so it does NOT grow SaveBlock3.
//
// FALSE because it is a sub-feature of the quest menu and cannot outlive it: ScrCmd_updatequest
// is defined in scrcmd.c inside `#if QUEST_MENU` *and then* `#if OW_QUEST_BRANCHING`, but
// script_cmd_table.inc:290 picks its handler on OW_QUEST_BRANCHING alone. Leaving this TRUE with
// QUEST_MENU FALSE therefore points opcode 0xeb at a symbol that was never compiled. The
// #error below turns that combination into a clear message instead of a bare undefined reference.
#define OW_QUEST_BRANCHING          FALSE

#if OW_QUEST_BRANCHING && !QUEST_MENU
#error "OW_QUEST_BRANCHING requires QUEST_MENU: ScrCmd_updatequest is compiled only inside QUEST_MENU, but script_cmd_table.inc selects it on OW_QUEST_BRANCHING alone."
#endif

// How many branch states a complex quest may have. Forced to 1 when branching is
// OFF so the per-state arrays in sSideQuests stay single-element (no ROM growth).
#if OW_QUEST_BRANCHING
#define OW_QUEST_MAX_STATES         50
#else
#define OW_QUEST_MAX_STATES         1
#endif

#endif // GUARD_CONFIG_QUESTS_H
