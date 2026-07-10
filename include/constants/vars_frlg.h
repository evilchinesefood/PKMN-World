#ifndef GUARD_CONSTANTS_VARS_FRLG_H
#define GUARD_CONSTANTS_VARS_FRLG_H

#include "constants/region_vars.h"

// Kanto var rebase (region merge, 2026-07-10). The FRLG-unique story vars that sat on raw
// IDs 0x4025-0x408A aliased live Hoenn vars in SaveBlock1.vars (e.g. 0x4046 was both
// VAR_TRAINER_CARD_MON_ICON_4 and Hoenn's VAR_NATIONAL_DEX). They now live in the reserved
// Kanto slice of the per-region var pool (VAR_KANTO_BASE = 0xA000), stored in
// SaveBlock3.regionVars[] via GetVarPointer()'s region branch, mirroring VAR_JOHTO_SLICE.
// Macro NAMES are unchanged (all scripts/C reference by name); load_save.c migrates each
// moved var's old shared cell into its new slot (v5 -> v6). Names shared with Hoenn's
// vars.h (VAR_POKELOT_RND2, VAR_LOTAD_SIZE_RECORD) and the 0x4020-0x4024 counters stay
// on their raw IDs (outside the rebase range), as do 0x408B+ (alias only unused Hoenn vars).
#define VAR_KANTO_SLICE(n)          (VAR_KANTO_BASE + (n))

// If nonzero, counts down by one every step.
// When it hits zero, repel's effect wears off.
#define VAR_REPEL_STEP_COUNT_FRLG                0x4020

// Counts up every step. Wraps around at 128.
// When wraparound occurs, the friendship of
// every party poke gets a slight boost.
#define VAR_HAPPINESS_STEP_COUNTER          0x4021

// Counts up every step while a party Pokemon is
// poisoned. Wraps around at 5. When wraparound
// occurs, every party Pokemon with the PSN status
// takes 1 point of damage.
// This is a deviation from the typical rate in
// the series, which is 1 damage every 4 steps.
#define VAR_POISON_STEP_COUNTER_FRLG             0x4022

// Step counter. Caps at 1500. If you enter a map with
// renewable hidden items and this counter is capped,
// the counter resets to 0 and all renewable hidden
// item flags are resampled.
#define VAR_RENEWABLE_ITEM_STEP_COUNTER     0x4023

// Determines which wild encounter set to use in the
// Altering Cave. Incremented by Mystery Event.
// Wraps around at 10.
#define VAR_ALTERING_CAVE_WILD_SET_FRLG          0x4024

// Step counter set to 500 at game start. When you get
// a massage from Daisy, it resets to 0. Caps at 500.
#define VAR_MASSAGE_COOLDOWN_STEP_COUNTER   VAR_KANTO_SLICE(0x00)

// Step counter. Wraps around at 100. Used to
// determine whether the player has reached the
// triangle in time.
#define VAR_DEOXYS_INTERACTION_STEP_COUNTER VAR_KANTO_SLICE(0x01)

// Bits 0-11 are the number of mons in all boxes
// with the species sanity bit set.
// Bits 12-15 are the same for the player's party.
// Used by Quest Log.
#define VAR_QUEST_LOG_MON_COUNTS           VAR_KANTO_SLICE(0x02)
#define VAR_WONDER_NEWS_STEP_COUNTER_FRLG  VAR_KANTO_SLICE(0x03)
#define VAR_0x4029                         VAR_KANTO_SLICE(0x04)
#define VAR_0x402A                         VAR_KANTO_SLICE(0x05)
#define VAR_0x402B                         VAR_KANTO_SLICE(0x06)
#define VAR_DAYS_FRLG                      VAR_KANTO_SLICE(0x07) // was VAR_RESET_RTC_ENABLE
#define VAR_0x402D                         VAR_KANTO_SLICE(0x08)
#define VAR_0x402E                         VAR_KANTO_SLICE(0x09)

#define VAR_0x402F                         VAR_KANTO_SLICE(0x0A)

#define VAR_ICE_STEP_COUNT_FRLG            VAR_KANTO_SLICE(0x0B)
#define VAR_STARTER_MON_FRLG               VAR_KANTO_SLICE(0x0C) // 0: Bulbasaur, 1: Squirtle, 2: Charmander
#define VAR_RESET_RTC_ENABLE_FRLG          VAR_KANTO_SLICE(0x0D)
#define VAR_ENIGMA_BERRY_AVAILABLE_FRLG    VAR_KANTO_SLICE(0x0E)

#define VAR_0x4034                         VAR_KANTO_SLICE(0x0F)
#define VAR_RESORT_GOREGEOUS_STEP_COUNTER  VAR_KANTO_SLICE(0x10)
#define VAR_RESORT_GORGEOUS_REQUESTED_MON  VAR_KANTO_SLICE(0x11)
#define VAR_PC_BOX_TO_SEND_MON_FRLG        VAR_KANTO_SLICE(0x12)
#define VAR_FANCLUB_FAN_COUNTER_FRLG       VAR_KANTO_SLICE(0x13)
#define VAR_FANCLUB_LOSE_FAN_TIMER_FRLG    VAR_KANTO_SLICE(0x14)
#define VAR_ELEVATOR_FLOOR                 VAR_KANTO_SLICE(0x15)
#define VAR_RESORT_GORGEOUS_REWARD         VAR_KANTO_SLICE(0x16)
#define VAR_0x403C                         VAR_KANTO_SLICE(0x17) // Set to 0x0302, never read
#define VAR_HERACROSS_SIZE_RECORD          VAR_KANTO_SLICE(0x18)
#define VAR_DEOXYS_INTERACTION_NUM         VAR_KANTO_SLICE(0x19)
#define VAR_0x403F                         VAR_KANTO_SLICE(0x1A)
#define VAR_MAGIKARP_SIZE_RECORD           VAR_KANTO_SLICE(0x1B)
#define VAR_0x4041                         VAR_KANTO_SLICE(0x1C)
#define VAR_TRAINER_CARD_MON_ICON_TINT_IDX VAR_KANTO_SLICE(0x1D)
#define VAR_TRAINER_CARD_MON_ICON_1        VAR_KANTO_SLICE(0x1E)
#define VAR_TRAINER_CARD_MON_ICON_2        VAR_KANTO_SLICE(0x1F)
#define VAR_TRAINER_CARD_MON_ICON_3        VAR_KANTO_SLICE(0x20)
#define VAR_TRAINER_CARD_MON_ICON_4        VAR_KANTO_SLICE(0x21)
#define VAR_TRAINER_CARD_MON_ICON_5        VAR_KANTO_SLICE(0x22)
#define VAR_TRAINER_CARD_MON_ICON_6        VAR_KANTO_SLICE(0x23)
#define VAR_HOF_BRAG_STATE                 VAR_KANTO_SLICE(0x24)
#define VAR_EGG_BRAG_STATE                 VAR_KANTO_SLICE(0x25)
#define VAR_LINK_WIN_BRAG_STATE            VAR_KANTO_SLICE(0x26)
#define VAR_POKELOT_RND2                   0x404C
#define VAR_QL_ENTRANCE                    VAR_KANTO_SLICE(0x27)
#define VAR_NATIONAL_DEX_FRLG              VAR_KANTO_SLICE(0x28)
#define VAR_LOTAD_SIZE_RECORD              0x404F

// Map Scene
#define VAR_MAP_SCENE_PALLET_TOWN_OAK                                          VAR_KANTO_SLICE(0x29)
#define VAR_MAP_SCENE_VIRIDIAN_CITY_OLD_MAN                                    VAR_KANTO_SLICE(0x2A)
#define VAR_MAP_SCENE_CERULEAN_CITY_RIVAL                                      VAR_KANTO_SLICE(0x2B)
#define VAR_VERMILION_CITY_TICKET_CHECK_TRIGGER                                VAR_KANTO_SLICE(0x2C)
#define VAR_MAP_SCENE_ROUTE22                                                  VAR_KANTO_SLICE(0x2D)
#define VAR_MAP_SCENE_PALLET_TOWN_PROFESSOR_OAKS_LAB                           VAR_KANTO_SLICE(0x2E)
#define VAR_MAP_SCENE_PALLET_TOWN_PLAYERS_HOUSE_2F                             VAR_KANTO_SLICE(0x2F)
#define VAR_MAP_SCENE_VIRIDIAN_CITY_MART                                       VAR_KANTO_SLICE(0x30)
#define VAR_MAP_SCENE_PALLET_TOWN_RIVALS_HOUSE                                 VAR_KANTO_SLICE(0x31)
#define VAR_MAP_SCENE_POKEMON_TOWER_6F                                         VAR_KANTO_SLICE(0x32)
#define VAR_MAP_SCENE_VIRIDIAN_CITY_GYM_DOOR                                   VAR_KANTO_SLICE(0x33)
#define VAR_MAP_SCENE_S_S_ANNE_2F_CORRIDOR                                     VAR_KANTO_SLICE(0x34)
#define VAR_MAP_SCENE_SILPH_CO_7F                                              VAR_KANTO_SLICE(0x35)
#define VAR_MAP_SCENE_POKEMON_TOWER_2F                                         VAR_KANTO_SLICE(0x36)
#define VAR_MAP_SCENE_ROUTE16                                                  VAR_KANTO_SLICE(0x37)
#define VAR_MAP_SCENE_ROUTE23                                                  VAR_KANTO_SLICE(0x38)
#define VAR_MAP_SCENE_SILPH_CO_11F                                             VAR_KANTO_SLICE(0x39)
#define VAR_MAP_SCENE_PEWTER_CITY_MUSEUM_1F                                    VAR_KANTO_SLICE(0x3A)
#define VAR_MAP_SCENE_ROUTE5_ROUTE6_ROUTE7_ROUTE8_GATES                        VAR_KANTO_SLICE(0x3B)
#define VAR_MAP_SCENE_SEAFOAM_ISLANDS_B4F                                      VAR_KANTO_SLICE(0x3C)
#define VAR_MAP_SCENE_VICTORY_ROAD_1F                                          VAR_KANTO_SLICE(0x3D)
#define VAR_MAP_SCENE_VICTORY_ROAD_2F_BOULDER1                                 VAR_KANTO_SLICE(0x3E)
#define VAR_MAP_SCENE_VICTORY_ROAD_2F_BOULDER2                                 VAR_KANTO_SLICE(0x3F)
#define VAR_MAP_SCENE_VICTORY_ROAD_3F                                          VAR_KANTO_SLICE(0x40)
#define VAR_MAP_SCENE_POKEMON_LEAGUE                                           VAR_KANTO_SLICE(0x41)
#define VAR_MAP_SCENE_CINNABAR_ISLAND_POKEMON_LAB_EXPERIMENT_ROOM_WHICH_FOSSIL VAR_KANTO_SLICE(0x42)
#define VAR_MAP_SCENE_CINNABAR_ISLAND_POKEMON_LAB_EXPERIMENT_ROOM_REVIVE_STATE VAR_KANTO_SLICE(0x43)
#define VAR_MAP_SCENE_ROUTE24                                                  VAR_KANTO_SLICE(0x44)
#define VAR_MAP_SCENE_PEWTER_CITY                                              VAR_KANTO_SLICE(0x45)
#define VAR_0x406D                                                             VAR_KANTO_SLICE(0x46)
#define VAR_MAP_SCENE_FUCHSIA_CITY_SAFARI_ZONE_ENTRANCE                        VAR_KANTO_SLICE(0x47)
#define VAR_CABLE_CLUB_STATE_FRLG                                              VAR_KANTO_SLICE(0x48)
#define VAR_MAP_SCENE_PALLET_TOWN_SIGN_LADY                                    VAR_KANTO_SLICE(0x49)
#define VAR_MAP_SCENE_CINNABAR_ISLAND                                          VAR_KANTO_SLICE(0x4A)
#define VAR_0x4072                                                             VAR_KANTO_SLICE(0x4B)
#define VAR_MAP_SCENE_SAFFRON_CITY_POKEMON_TRAINER_FAN_CLUB                    VAR_KANTO_SLICE(0x4C)
#define VAR_MAP_SCENE_SEVEN_ISLAND_HOUSE_ROOM1                                 VAR_KANTO_SLICE(0x4D)
#define VAR_MAP_SCENE_ONE_ISLAND_HARBOR                                        VAR_KANTO_SLICE(0x4E)
#define VAR_MAP_SCENE_ONE_ISLAND_POKEMON_CENTER_1F                             VAR_KANTO_SLICE(0x4F)
#define VAR_0x4077                                                             VAR_KANTO_SLICE(0x50)
#define VAR_MAP_SCENE_TWO_ISLAND                                               VAR_KANTO_SLICE(0x51)
#define VAR_MAP_SCENE_TWO_ISLAND_JOYFUL_GAME_CORNER                            VAR_KANTO_SLICE(0x52)
#define VAR_0x407A                                                             VAR_KANTO_SLICE(0x53)
#define VAR_MAP_SCENE_THREE_ISLAND                                             VAR_KANTO_SLICE(0x54)
#define VAR_MAP_SCENE_POKEMON_CENTER_TEALA                                     VAR_KANTO_SLICE(0x55)
#define VAR_MAP_SCENE_CERULEAN_CITY_ROCKET                                     VAR_KANTO_SLICE(0x56)
#define VAR_MAP_SCENE_VERMILION_CITY                                           VAR_KANTO_SLICE(0x57)
#define VAR_MAP_SCENE_MT_EMBER_EXTERIOR                                        VAR_KANTO_SLICE(0x58)
#define VAR_MAP_SCENE_ICEFALL_CAVE_BACK                                        VAR_KANTO_SLICE(0x59)
#define VAR_MAP_SCENE_SAFFRON_CITY_DOJO                                        VAR_KANTO_SLICE(0x5A)
#define VAR_MAP_SCENE_TRAINER_TOWER                                            VAR_KANTO_SLICE(0x5B)
#define VAR_MAP_SCENE_FIVE_ISLAND_LOST_CAVE_ROOM10                             VAR_KANTO_SLICE(0x5C)
#define VAR_MAP_SCENE_FIVE_ISLAND_RESORT_GORGEOUS                              VAR_KANTO_SLICE(0x5D)
#define VAR_MAP_SCENE_INDIGO_PLATEAU_EXTERIOR                                  VAR_KANTO_SLICE(0x5E)
#define VAR_MAP_SCENE_FOUR_ISLAND                                              VAR_KANTO_SLICE(0x5F)
#define VAR_0x4087                                                             VAR_KANTO_SLICE(0x60)
#define VAR_MAP_SCENE_ROCKET_WAREHOUSE                                         VAR_KANTO_SLICE(0x61)
#define VAR_MAP_SCENE_SIX_ISLAND_POKEMON_CENTER_1F                             VAR_KANTO_SLICE(0x62)
#define VAR_MAP_SCENE_CINNABAR_ISLAND_2                                        VAR_KANTO_SLICE(0x63)
#define VAR_MAP_SCENE_MT_MOON_B2F                                              0x408B


#define VAR_0x408C                 0x408C
#define VAR_0x408D                 0x408D
#define VAR_0x408E                 0x408E
#define VAR_0x408F                 0x408F
#define VAR_0x4090                 0x4090
#define VAR_0x4091                 0x4091
#define VAR_0x4092                 0x4092
#define VAR_0x4093                 0x4093
#define VAR_0x4094                 0x4094
#define VAR_0x4095                 0x4095
#define VAR_0x4096                 0x4096
#define VAR_0x4097                 0x4097
#define VAR_0x4098                 0x4098
#define VAR_0x4099                 0x4099
#define VAR_0x409A                 0x409A
#define VAR_0x409B                 0x409B
#define VAR_0x409C                 0x409C
#define VAR_0x409D                 0x409D
#define VAR_0x409E                 0x409E
#define VAR_0x409F                 0x409F
#define VAR_0x40A0                 0x40A0
#define VAR_0x40A1                 0x40A1
#define VAR_0x40A2                 0x40A2
#define VAR_0x40A3                 0x40A3
#define VAR_0x40A4                 0x40A4
#define VAR_0x40A5                 0x40A5
#define VAR_0x40A6                 0x40A6
#define VAR_0x40A7                 0x40A7
#define VAR_0x40A8                 0x40A8
#define VAR_0x40A9                 0x40A9

#define VAR_QLBAK_TRAINER_REMATCHES 0x40AA // array of 4
#define VAR_QLBAK_MAP_LAYOUT        0x40AE

#define VAR_0x40AF                 0x40AF
#define VAR_0x40B0                 0x40B0
#define VAR_0x40B1                 0x40B1
#define VAR_0x40B2                 0x40B2
#define VAR_0x40B3                 0x40B3
#define VAR_PORTHOLE               0x40B4
#define VAR_EVENT_PICHU_SLOT       0x40B5
#define VAR_MYSTERY_GIFT_1         0x40B6
#define VAR_MYSTERY_GIFT_2         0x40B7
#define VAR_MYSTERY_GIFT_3         0x40B8
#define VAR_MYSTERY_GIFT_4         0x40B9
#define VAR_MYSTERY_GIFT_5         0x40BA
#define VAR_MYSTERY_GIFT_6         0x40BB
#define VAR_MYSTERY_GIFT_7         0x40BC
#define VAR_0x40BD                 0x40BD
#define VAR_0x40BE                 0x40BE
#define VAR_0x40BF                 0x40BF
#define VAR_0x40C0                 0x40C0
#define VAR_0x40C1                 0x40C1
#define VAR_0x40C2                 0x40C2
#define VAR_0x40C3                 0x40C3
#define VAR_0x40C4                 0x40C4
#define VAR_0x40C5                 0x40C5
#define VAR_0x40C6                 0x40C6
#define VAR_0x40C7                 0x40C7
#define VAR_0x40C8                 0x40C8
#define VAR_0x40C9                 0x40C9
#define VAR_0x40CA                 0x40CA
#define VAR_0x40CB                 0x40CB
#define VAR_0x40CC                 0x40CC
#define VAR_0x40CD                 0x40CD
#define VAR_0x40CE                 0x40CE
#define VAR_FRONTIER_FACILITY      0x40CF
#define VAR_0x40D0                 0x40D0
#define VAR_0x40D1                 0x40D1
#define VAR_0x40D2                 0x40D2
#define VAR_0x40D3                 0x40D3
#define VAR_0x40D4                 0x40D4
#define VAR_0x40D5                 0x40D5
#define VAR_0x40D6                 0x40D6
#define VAR_0x40D7                 0x40D7
#define VAR_0x40D8                 0x40D8
#define VAR_0x40D9                 0x40D9
#define VAR_0x40DA                 0x40DA
#define VAR_0x40DB                 0x40DB
#define VAR_0x40DC                 0x40DC
#define VAR_0x40DD                 0x40DD
#define VAR_0x40DE                 0x40DE
#define VAR_0x40DF                 0x40DF
#define VAR_0x40E0                 0x40E0
#define VAR_0x40E1                 0x40E1
#define VAR_0x40E2                 0x40E2
#define VAR_0x40E3                 0x40E3
#define VAR_0x40E4                 0x40E4
#define VAR_0x40E5                 0x40E5
#define VAR_DAILY_SLOTS            0x40E6
#define VAR_DAILY_WILDS            0x40E7
#define VAR_DAILY_BLENDER          0x40E8
#define VAR_DAILY_PLANTED_BERRIES  0x40E9
#define VAR_DAILY_PICKED_BERRIES   0x40EA
#define VAR_DAILY_ROULETTE         0x40EB
#define VAR_0x40EC                 0x40EC
#define VAR_0x40ED                 0x40ED
#define VAR_0x40EE                 0x40EE
#define VAR_0x40EF                 0x40EF
#define VAR_0x40F0                 0x40F0
#define VAR_DAILY_BP               0x40F1
#define VAR_0x40F2                 0x40F2
#define VAR_0x40F3                 0x40F3
#define VAR_0x40F4                 0x40F4
#define VAR_0x40F5                 0x40F5
#define VAR_0x40F6                 0x40F6
#define VAR_0x40F7                 0x40F7
#define VAR_0x40F8                 0x40F8
#define VAR_0x40F9                 0x40F9
#define VAR_0x40FA                 0x40FA
#define VAR_0x40FB                 0x40FB
#define VAR_0x40FC                 0x40FC
#define VAR_0x40FD                 0x40FD
#define VAR_0x40FE                 0x40FE
#define VAR_0x40FF                 0x40FF

#define VARS_END_FRLG              0x40FF
#define VARS_COUNT_FRLG            (VARS_END_FRLG - VARS_START_FRLG + 1)

#define SPECIAL_VARS_START         0x8000

#define VAR_0x8000                 0x8000
#define VAR_0x8001                 0x8001
#define VAR_0x8002                 0x8002
#define VAR_0x8003                 0x8003
#define VAR_0x8004                 0x8004
#define VAR_0x8005                 0x8005
#define VAR_0x8006                 0x8006
#define VAR_0x8007                 0x8007
#define VAR_0x8008                 0x8008
#define VAR_0x8009                 0x8009
#define VAR_0x800A                 0x800A
#define VAR_0x800B                 0x800B
#define VAR_FACING                 0x800C
#define VAR_RESULT                 0x800D
#define VAR_ITEM_ID                0x800E
#define VAR_LAST_TALKED            0x800F
#define VAR_MON_BOX_ID_FRLG        0x8010
#define VAR_MON_BOX_POS_FRLG       0x8011
#define VAR_TEXT_COLOR             0x8012
#define VAR_PREV_TEXT_COLOR        0x8013
#define VAR_0x8014                 0x8014 // Unknown/unused

#define SPECIAL_VARS_END_FRLG      0x8014

// Text color ids for VAR_TEXT_COLOR / VAR_PREV_TEXT_COLOR
#define NPC_TEXT_COLOR_MALE      0 // Blue, for male NPCs
#define NPC_TEXT_COLOR_FEMALE    1 // Red, for female NPCs
#define NPC_TEXT_COLOR_MON       2 // Black, for Pokémon
#define NPC_TEXT_COLOR_NEUTRAL   3 // Black, for inanimate objects and messages from the game
#define NPC_TEXT_COLOR_DEFAULT 255 // If an NPC is selected, use the color specified by GetColorFromTextColorTable, otherwise use Neutral.

#endif // GUARD_CONSTANTS_VARS_FRLG_H
