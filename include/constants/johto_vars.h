#ifndef GUARD_CONSTANTS_JOHTO_VARS_H
#define GUARD_CONSTANTS_JOHTO_VARS_H

#include "constants/region_vars.h"

// Johto story vars (region merge, always-on). These live in the per-region var
// pool (VAR_JOHTO_BASE = 0xA080), stored in SaveBlock3.regionVars[] via
// GetVarPointer()'s region branch, so Johto progress is isolated from Hoenn/Kanto.
// Starting-area slice subset; append as later Johto maps are ported (128 slots).
#define VAR_JOHTO_SLICE(n)            (VAR_JOHTO_BASE + (n))

#define VAR_NEWBARK_TOWN_STATE        VAR_JOHTO_SLICE(0x00)
#define VAR_NEWBARKTOWN_LABSTATE      VAR_JOHTO_SLICE(0x01)
#define VAR_CHERRYGROVE_CITY_STATE    VAR_JOHTO_SLICE(0x02)
#define VAR_GOLDENROD_CITY_STATE      VAR_JOHTO_SLICE(0x03)
#define VAR_ECRUTEAK_CITY_THEATER     VAR_JOHTO_SLICE(0x04)

// === Violet City area ===
#define VAR_VIOLET_CITY_STATE         VAR_JOHTO_SLICE(0x05)
#define VAR_SPROUT_TOWER              VAR_JOHTO_SLICE(0x06)
#define VAR_RUINSOFALPH_STATE         VAR_JOHTO_SLICE(0x07)
#define VAR_VIOLET_CITY_KIMONO_GIRL   VAR_JOHTO_SLICE(0x08)
#define VAR_KENYA                     VAR_JOHTO_SLICE(0x09)
#define VAR_SLOWPOKE_TAIL             VAR_JOHTO_SLICE(0x0A)
#define VAR_NUM_BADGES                VAR_JOHTO_SLICE(0x0B)

// === Azalea area ===
#define VAR_AZALEA_TOWN_STATE         VAR_JOHTO_SLICE(0x0C)
#define VAR_ILEX_FOREST_FARFETCHD     VAR_JOHTO_SLICE(0x0D)

// === Goldenrod area ===
#define VAR_BUG_CONTEST_STATE          VAR_JOHTO_SLICE(0x0E)
#define VAR_ELEVATOR                   VAR_JOHTO_SLICE(0x0F)
#define VAR_LUGIA_OR_HOOH              VAR_JOHTO_SLICE(0x10)
#define VAR_MAHOGANY_TOWN_STATE        VAR_JOHTO_SLICE(0x11)
#define VAR_TRAIN                      VAR_JOHTO_SLICE(0x12)

#define VAR_ECRUTEAK_CITY_STATE       VAR_JOHTO_SLICE(0x20)

// === Ecruteak area ===
#define VAR_COMPLETED_HO_OH           VAR_JOHTO_SLICE(0x21)
#define VAR_COMPLETED_LUGIA           VAR_JOHTO_SLICE(0x22)
#define VAR_ROUTE39_BARN              VAR_JOHTO_SLICE(0x23)
#define VAR_OLIVINE_CITY_STATE        VAR_JOHTO_SLICE(0x24)


// === Olivine area ===
#define VAR_CIANWOOD_CITY_STATE       VAR_JOHTO_SLICE(0x25)
#define VAR_GETFLY                    VAR_JOHTO_SLICE(0x26)
#define VAR_SAFARI_ZONE_GATE_STATE    VAR_JOHTO_SLICE(0x27)
#define VAR_SSAQUA_STATE              VAR_JOHTO_SLICE(0x28)
#define VAR_SUICUNE_ENCOUNTERS        VAR_JOHTO_SLICE(0x29)

// === Cianwood area ===
#define VAR_SHUCKIE                   VAR_JOHTO_SLICE(0x2A)


// === Mahogany area (region merge) — cross-area story state (Routes/Lake/Rocket HQ/Mt Mortar) ===
// Johto var pool, above Cianwood's highest (0x2A).
#define VAR_BLACKTHORN_CITY_STATE   VAR_JOHTO_SLICE(0x2B)
#define VAR_BLACKTHORN_GYM_STATE    VAR_JOHTO_SLICE(0x2C)
#define VAR_DRAGONS_DEN_QUIZ        VAR_JOHTO_SLICE(0x2D)
#define VAR_ELECTRODES_FAINTED      VAR_JOHTO_SLICE(0x2E)
#define VAR_ICE_PATH_STATE          VAR_JOHTO_SLICE(0x2F)
#define VAR_LAKE_OF_RAGE_FISHERMAN  VAR_JOHTO_SLICE(0x30)
#define VAR_ROCKET_HIDEOUT_STATUE_1 VAR_JOHTO_SLICE(0x31)
#define VAR_ROCKET_HIDEOUT_STATUE_2 VAR_JOHTO_SLICE(0x32)
#define VAR_ROCKET_HIDEOUT_STATUE_3 VAR_JOHTO_SLICE(0x33)
#define VAR_ROCKET_HIDEOUT_STATUE_4 VAR_JOHTO_SLICE(0x34)
#define VAR_ROCKET_HIDEOUT_STATUE_5 VAR_JOHTO_SLICE(0x35)
#define VAR_ROCKET_PASSWORD         VAR_JOHTO_SLICE(0x36)
#define VAR_ROUTE27_BAOBA_CALL      VAR_JOHTO_SLICE(0x37)

// === Safari Zone area (region merge) — Baoba custom-area quest state ===
#define VAR_BAOBA_QUEST_STATE       VAR_JOHTO_SLICE(0x38)

#endif // GUARD_CONSTANTS_JOHTO_VARS_H
