#ifndef GUARD_CONSTANTS_GLOBAL_H
#define GUARD_CONSTANTS_GLOBAL_H

// Region merge save-format version. Stamped on new games (SaveBlock2.saveVersion).
// The migration ladder is LIVE (MigrateSaveFormatIfNeeded, src/load_save.c) — it has run
// since v2 — with a hard floor at SAVE_FORMAT_LAYOUT_MIN below (older saves are refused).
// v2: SaveBlock3.usmSaved appended (graphical start menu icon order).
// v3: SaveBlock3.kantoTrainerFlags appended (Kanto trainer defeat-flag bank, E5-1).
// v4: SaveBlock3.route5DayCareMon appended (FRLG Route 5 single-mon day care, E7-1).
// v5: SaveBlock3.clearedObstacleCount/clearedObstacles appended (persistent cut trees + smashed rocks).
// v6: FRLG story vars rebased from raw SaveBlock1.vars IDs (0x4025-0x408A, aliasing live Hoenn
//     vars) onto the Kanto regionVars slice (VAR_KANTO_SLICE); old cell values are copied over.
// v7: SaveBlock1 RESHAPED (not appended) — bag Items 30->60, Key Items 30->99, item PC 50->150,
//     funded by FREE_MYSTERY_GIFT + FREE_MYSTERY_EVENT_BUFFERS. Owner decision 2026-07-24:
//     NEW SAVES ONLY, no migration. See SAVE_FORMAT_LAYOUT_MIN below for why that needs an
//     explicit gate rather than relying on the checksum to reject old saves.
// v8: POKéMON CENTER 1F layouts reshaped — Battle Net wall terminal added beside the storage
//     PC, Town Map poster cleared, 2F escalator removed (issue #59). Nothing in SaveBlock1/2/3
//     moves, so v7 saves still LOAD (SAVE_FORMAT_LAYOUT_MIN stays 7); the ladder step only
//     zeroes SaveBlock1.mapView, which would otherwise restore the old poster and staircase
//     over the new layout for a save made standing inside a Center.
// v9: the Johto route/dungeon trainers stopped sharing Hoenn trainer ids (Route 32's
//     "Youngster" ALBERT was Hoenn's Cooltrainer ALBERT, so one party and one defeat flag
//     served both). Their new ids need defeat flags, and the inline window is frozen, so a
//     johtoTrainerFlags[] bank was APPENDED to the end of struct RegionSave. Appending moves
//     no existing bank - every pinned offsetof below is unchanged - so v8 saves still LOAD;
//     the ladder step only has to zero the new bank, whose bytes are uninitialised flash on
//     a v8 save. Without that zeroing a fresh Johto trainer can read as already defeated.
// v10: issue #195. Before dbc1b1aa17 every ALL_REGIONS new game stamped hoennIntroDone = TRUE
//     in NewGameInitData, including Johto/Kanto-first files that had never set foot in Hoenn.
//     The hub's former intro-done predicate therefore took the "returning" branch on their FIRST Hoenn
//     trip and warped them to Slateport Harbor mid-region with an empty party (DepositPartyToPC
//     from REGION_NONE is a no-op) and Oldale still walled off. That commit fixed new games but
//     declared "save format unchanged", so a pre-fix and a post-fix save are BOTH stamped v9 and
//     cannot be told apart by version. This bump is what makes the repair reachable: v9 saves get
//     the one-shot check below, v10 saves never re-enter it. The check is introState == 0 only
//     — a file already dumped in Slateport has currentRegion == REGION_HOENN and must still
//     clear, because the hub first-visit path sets the var to 4 before warping.
#define SAVE_FORMAT_VERSION 10

// The oldest save layout this build can load at all. Distinct from SAVE_FORMAT_VERSION, which
// only says "migrate me forward" — a pre-v7 save cannot be migrated, it must be REFUSED.
//
// Why an explicit gate is required: growing bag/pcItems shifts every later SaveBlock1 field by
// 796 bytes, but bag and pcItems both live inside SaveBlock1 CHUNK 0, and SAVEBLOCK_CHUNK
// (src/save.c) only varies the LAST chunk's size. Chunks 0-2 therefore keep size 3968 and their
// stored checksums still match the unchanged flash bytes, so a legacy save loads "successfully"
// into the shifted layout and only chunk 3 fails validSectorFlags. The result is a HALF-LOADED
// save with silently misaligned flags and vars — strictly worse than a clean rejection. The
// incidental checksum failure is not a gate; this is.
//
// saveVersion itself stays readable across this break: it lives in SaveBlock2 (offset 0x91), and
// nothing in this bump touches SaveBlock2's layout.
#define SAVE_FORMAT_LAYOUT_MIN 7

// Define TRUE/FALSE as cpp integer constants so that #if guards in config headers
// (e.g. #if QUEST_MENU where QUEST_MENU is defined as TRUE or FALSE) evaluate
// correctly during asm preprocessing. global.inc handles the .set conflict via
// #undef before each .set and #define restoration after. In C translation units
// gba/defines.h already defines these; the #ifndef guards prevent redefinition.
#ifndef TRUE
#define TRUE 1
#endif
#ifndef FALSE
#define FALSE 0
#endif

// You can use the ENABLED_ON_RELEASE and DISABLED_ON_RELEASE macros to
// control whether a feature is enabled or disabled when making a release build.
//
// For example, the overworld debug menu is enabled by default, but when using
// `make release`, it will be automatically disabled.
//
// #define DEBUG_OVERWORLD_MENU DISABLED_ON_RELEASE
#ifdef RELEASE
#define ENABLED_ON_RELEASE TRUE
#define DISABLED_ON_RELEASE FALSE
#else
#define ENABLED_ON_RELEASE FALSE
#define DISABLED_ON_RELEASE TRUE
#endif

#include "config/ai.h"
#include "config/battle.h"
#include "config/caps.h"
#include "config/contest.h"
#include "config/debug.h"
#include "config/dexnav.h"
#include "config/follower_npc.h"
#include "config/general.h"
#include "config/item.h"
#include "config/map_preview_screen.h"
#include "config/name_box.h"
#include "config/overworld.h"
#include "config/pokemon.h"
#include "config/pokevial.h"
#include "config/qol_field_moves.h"
#include "config/link.h"
#include "config/quests.h"
#include "config/start_menu.h"
#include "config/summary_screen.h"
#include "config/swsh_item_menu.h"
#include "config/swsh_party_menu.h"
#include "config/wild_encounter.h"

// Invalid Versions show as "----------" in Gen 4 and Gen 5's summary screen.
// In Gens 6 and 7, invalid versions instead show "a distant land" in the summary screen.
// In Gen 4 only, migrated Pokémon with Diamond, Pearl, or Platinum's ID show as "----------".
// Gen 5 and up read Diamond, Pearl, or Platinum's ID as "Sinnoh".
// In Gen 4 and up, migrated Pokémon with HeartGold or SoulSilver's ID show the otherwise unused "Johto" string.
enum __attribute__((packed)) GameVersion
{
    VERSION_SAPPHIRE = 1,
    VERSION_RUBY = 2,
    VERSION_EMERALD = 3,
    VERSION_FIRE_RED = 4,
    VERSION_LEAF_GREEN = 5,
    VERSION_HEART_GOLD = 7,
    VERSION_SOUL_SILVER = 8,
    VERSION_DIAMOND = 10,
    VERSION_PEARL = 11,
    VERSION_PLATINUM = 12,
    VERSION_GAMECUBE = 15,
    NUM_VERSIONS = VERSION_GAMECUBE,
};

enum Language
{
    LANGUAGE_JAPANESE = 1,
    LANGUAGE_ENGLISH = 2,
    LANGUAGE_FRENCH = 3,
    LANGUAGE_ITALIAN = 4,
    LANGUAGE_GERMAN = 5,
    LANGUAGE_KOREAN = 6, // 6 goes unused but the theory is it was meant to be Korean,
    LANGUAGE_SPANISH = 7,
    NUM_LANGUAGES = LANGUAGE_SPANISH,
};

#ifdef FIRERED
    #define GAME_VERSION (VERSION_FIRE_RED)
    #define IS_FRLG 1
#else
    #ifdef LEAFGREEN
    #define GAME_VERSION (VERSION_LEAF_GREEN)
    #define IS_FRLG 1
    #else
    #define GAME_VERSION (VERSION_EMERALD)
    #define IS_FRLG 0
    #endif
#endif
#define GAME_LANGUAGE (LANGUAGE_ENGLISH)

// party sizes
#define PARTY_SIZE 6
#define MULTI_PARTY_SIZE (PARTY_SIZE / 2)
#define FRONTIER_PARTY_SIZE         3
#define FRONTIER_DOUBLES_PARTY_SIZE 4
#define FRONTIER_MULTI_PARTY_SIZE   2
#define MAX_FRONTIER_PARTY_SIZE    (max(FRONTIER_PARTY_SIZE,        \
                                    max(FRONTIER_DOUBLES_PARTY_SIZE,\
                                        FRONTIER_MULTI_PARTY_SIZE)))
#define UNION_ROOM_PARTY_SIZE       2

// capacities of various saveblock objects
#define DAYCARE_MON_COUNT 2
#define POKEBLOCKS_COUNT 40
#define OBJECT_EVENTS_COUNT 16
#define MAIL_COUNT (10 + PARTY_SIZE)
#define SECRET_BASES_COUNT 20
#define POKE_NEWS_COUNT 16
// 150, up from vanilla 50 (save format v7). Hard wall is 254: the page counters in
// include/player_pc.h, the 0xFF swap sentinel in src/player_pc.c, and .pcItemsCount being a u8
// in the ROM header (src/rom_header_gf.c) all break above that.
#define PC_ITEMS_COUNT 150
#define OBJECT_EVENT_TEMPLATES_COUNT 64
#define DECOR_MAX_SECRET_BASE 16
#define DECOR_MAX_PLAYERS_HOUSE 12
#define APPRENTICE_COUNT 4
#define APPRENTICE_MAX_QUESTIONS 9
#define MAX_REMATCH_ENTRIES 100 // only REMATCH_TABLE_ENTRIES (78) are used
#define MAX_REGISTERED_ITEMS I_MAX_REGISTERED_ITEMS // items registerable to SELECT (key item wheel)
#define NUM_CONTEST_WINNERS 13
#define UNION_ROOM_KB_ROW_COUNT 10
#define SAVED_TRENDS_COUNT 5
#define PYRAMID_BAG_ITEMS_COUNT 10
#define ROAMER_COUNT 2 // Number of maximum concurrent active roamers (Johto Entei + Raikou roam together)

// Bag constants — resized for a three-region game (save format v7). Vanilla was 30/30, sized for
// a single-region Emerald; this game defines 99 key items (three regions of HMs, bikes, rods,
// passes, tickets, plus the Mega Ring and the key-item wheel) against 30 slots, and the debug
// pocket-filler already overflowed it before reaching ITEM_MEGA_RING.
//
// Ceilings, do not exceed without the extra work named:
//  - Items must stay <= 65. CountTotalItemQuantityInBag returns u16 (src/item.c) and a stack can
//    spill into a second slot, so slots x 999 must stay under 65536. Above 65 needs a u32 return.
//  - Any pocket at 256+ HANGS: IsBagPocketNonEmpty loops with a u8 index against capacity
//    (src/item.c). The practical ceiling is 255, from the u8 UI counters in include/item_menu.h.
//  - struct Bag stays 4-byte aligned (it holds u32 slots). ClearBag uses memset — do NOT
//    revert it to CpuFastFill unless sizeof(struct Bag) is a multiple of 32 bytes: CpuFastSet
//    moves 8-word blocks and rounds UP, overfilling into pokeblocks[].
#define BAG_ITEMS_COUNT 60
#define BAG_KEYITEMS_COUNT 99
#define BAG_POKEBALLS_COUNT 16
#define BAG_TMHM_COUNT 64
#define BAG_BERRIES_COUNT 46

// Number of facilities for Ranking Hall.
// 7 facilities for single mode + tower double mode + tower multi mode.
// Excludes link modes. See RANKING_HALL_* in include/constants/battle_frontier.h
#define HALL_FACILITIES_COUNT 9
// Received via record mixing, 1 for each player other than yourself
#define HALL_RECORDS_COUNT 3

// Battle Frontier level modes.
enum FrontierLevelMode
{
    FRONTIER_LVL_50,
    FRONTIER_LVL_OPEN,
    FRONTIER_LVL_TENT, // Special usage for indicating Battle Tent
    FRONTIER_LVL_MODE_COUNT = FRONTIER_LVL_TENT,
};

#define TRAINER_ID_LENGTH 4
#define MAX_MON_MOVES 4
#define ALL_MOVES_MASK ((1 << MAX_MON_MOVES) - 1)

#define CONTESTANT_COUNT 4

enum ContestCategories
{
    CONTEST_CATEGORY_COOL,
    CONTEST_CATEGORY_BEAUTIFUL,
    CONTEST_CATEGORY_BEAUTY = CONTEST_CATEGORY_BEAUTIFUL,
    CONTEST_CATEGORY_CUTE,
    CONTEST_CATEGORY_CLEVER,
    CONTEST_CATEGORY_SMART = CONTEST_CATEGORY_CLEVER,
    CONTEST_CATEGORY_TOUGH,
    CONTEST_CATEGORIES_COUNT
};

// string lengths
#define ITEM_NAME_LENGTH 20
#define ITEM_NAME_PLURAL_LENGTH ITEM_NAME_LENGTH + 2 // 2 is used for the instance where a word's suffix becomes y->ies
#define POKEMON_NAME_LENGTH 12
#define VANILLA_POKEMON_NAME_LENGTH 10
#define POKEMON_NAME_BUFFER_SIZE max(20, POKEMON_NAME_LENGTH + 1) // Frequently used buffer size. Larger than necessary
#define PLAYER_NAME_LENGTH 7
#define MAIL_WORDS_COUNT 9
#define EASY_CHAT_BATTLE_WORDS_COUNT 6
#define MOVE_NAME_LENGTH 16
#define NUM_QUESTIONNAIRE_WORDS 4
#define QUIZ_QUESTION_LEN 9
#define WONDER_CARD_TEXT_LENGTH 40
#define WONDER_NEWS_TEXT_LENGTH 40
#define WONDER_CARD_BODY_TEXT_LINES 4
#define WONDER_NEWS_BODY_TEXT_LINES 10
#define TYPE_NAME_LENGTH 8
#define ABILITY_NAME_LENGTH 16
#define TRAINER_NAME_LENGTH 10
#define CODE_NAME_LENGTH 11

#define MAX_STAMP_CARD_STAMPS 7

enum Gender
{
    MALE,
    FEMALE,
    GENDER_COUNT,
};

#define NUM_BARD_SONG_WORDS    6
#define NUM_STORYTELLER_TALES  4
#define NUM_TRADER_ITEMS       4
#define GIDDY_MAX_TALES       10
#define GIDDY_MAX_QUESTIONS    8

#define OPTIONS_BUTTON_MODE_NORMAL 0
#define OPTIONS_BUTTON_MODE_LR 1
#define OPTIONS_BUTTON_MODE_L_EQUALS_A 2

#define OPTIONS_TEXT_SPEED_SLOW 0
#define OPTIONS_TEXT_SPEED_MID 1
#define OPTIONS_TEXT_SPEED_FAST 2
#define OPTIONS_TEXT_SPEED_INSTANT 3

#define OPTIONS_SOUND_MONO 0
#define OPTIONS_SOUND_STEREO 1

#define OPTIONS_BATTLE_STYLE_SHIFT 0
#define OPTIONS_BATTLE_STYLE_SET 1

// QoL #12: B-button behavior on the battle action menu (wild battles).
// Save-compat: 0 = CURSOR so pre-option saves keep the already-shipped
// move-cursor-to-Run behavior. Menu shows OFF/CURSOR/INSTANT.
#define OPTIONS_RUN_SHORTCUT_CURSOR 0
#define OPTIONS_RUN_SHORTCUT_OFF 1
#define OPTIONS_RUN_SHORTCUT_INSTANT 2

// QoL #15: battle EXP multiplier. Save-compat: 0 = 1x so pre-option saves
// (and zeroed battle-test saves) stay vanilla. Menu shows 0.5x/1x/1.5x/2x.
#define OPTIONS_EXP_MULT_1X 0
#define OPTIONS_EXP_MULT_0_5X 1
#define OPTIONS_EXP_MULT_1_5X 2
#define OPTIONS_EXP_MULT_2X 3

// QoL #15: catch-rate multiplier (0 = 1x, matches menu order 1x/1.5x/2x).
#define OPTIONS_CATCH_MULT_1X 0
#define OPTIONS_CATCH_MULT_1_5X 1
#define OPTIONS_CATCH_MULT_2X 2
#define OPTIONS_CATCH_MULT_0_5X 3 // added last to preserve old-save values (0/1/2 unchanged)

// QoL #8: nickname prompt on catch / egg hatch. Save-compat: 0 = ON (prompts
// shown, vanilla) so pre-option/zeroed saves keep asking; 1 = OFF skips the
// prompt and keeps the default species name. Menu shows ON/OFF (ON = index 0).
#define OPTIONS_NICKNAMES_ON 0
#define OPTIONS_NICKNAMES_OFF 1

enum __attribute__((packed)) Direction
{
    DIR_NONE,
    DIR_SOUTH,
    DIR_NORTH,
    DIR_WEST,
    DIR_EAST,
    CARDINAL_DIRECTION_COUNT,
    DIR_SOUTHWEST = CARDINAL_DIRECTION_COUNT,
    DIR_SOUTHEAST,
    DIR_NORTHWEST,
    DIR_NORTHEAST,
};

enum Connection
{
    CONNECTION_INVALID = -1,
    CONNECTION_NONE,
    CONNECTION_SOUTH,
    CONNECTION_NORTH,
    CONNECTION_WEST,
    CONNECTION_EAST,
    CONNECTION_DIVE,
    CONNECTION_EMERGE
};

#if TESTING
#include "config/test.h"
#endif

#endif // GUARD_CONSTANTS_GLOBAL_H
