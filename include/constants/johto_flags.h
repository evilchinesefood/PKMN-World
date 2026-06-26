#ifndef GUARD_CONSTANTS_JOHTO_FLAGS_H
#define GUARD_CONSTANTS_JOHTO_FLAGS_H

#include "constants/region_flags.h"

// Johto story/hide flags (region merge, always-on). These live in the reserved
// Johto flag bank (FLAG_JOHTO_BASE = 0x6000), stored in SaveBlock3.johtoFlags[]
// via GetFlagPointer()'s Johto branch, so they are isolated from Hoenn/Kanto.
// Populated during the Johto port; this header holds the starting-area slice
// (New Bark Town + Route 29 + Cherrygrove City + interiors). Append new Johto
// flags here as later maps are ported.
#define FLAG_JOHTO_SLICE(n)                  (FLAG_JOHTO_BASE + (n))

// --- Hide flags (object-event visibility) ---
#define FLAG_HIDE_SILVER_NEWBARKTOWN         FLAG_JOHTO_SLICE(0x00)
#define FLAG_HIDE_NEWBARKTOWN_LAB_AIDE       FLAG_JOHTO_SLICE(0x01)
#define FLAG_HIDE_CHIKORITABALL              FLAG_JOHTO_SLICE(0x02)
#define FLAG_HIDE_CYNDAQUILBALL              FLAG_JOHTO_SLICE(0x03)
#define FLAG_HIDE_TOTODILEBALL               FLAG_JOHTO_SLICE(0x04)
#define FLAG_HIDE_LAB_POLICEMAN              FLAG_JOHTO_SLICE(0x05)
#define FLAG_HIDE_MOMS_FRIEND                FLAG_JOHTO_SLICE(0x06)
#define FLAG_HIDE_MOMS_FRIEND2               FLAG_JOHTO_SLICE(0x07)
#define FLAG_HIDE_GUIDE_GENT_CHERRYGROVE     FLAG_JOHTO_SLICE(0x08)
#define FLAG_HIDE_SILVER_CHERRYGROVE         FLAG_JOHTO_SLICE(0x09)
#define FLAG_HIDE_CHERRYGROVE_GUIDE_GENT_HOUSE FLAG_JOHTO_SLICE(0x0A)
#define FLAG_HIDE_ROUTE_30_NPCS              FLAG_JOHTO_SLICE(0x0B)
#define FLAG_HIDE_ECRUTEAK_SILVER            FLAG_JOHTO_SLICE(0x0C)
#define FLAG_HIDE_ECRUTEAK_CITY_THEATER_NPCS FLAG_JOHTO_SLICE(0x0D)
#define FLAG_HIDE_ECRUTEAK_CITY_THEATER_KIMONOS FLAG_JOHTO_SLICE(0x0E)
#define FLAG_HIDE_OLIVINE_PORT_OAK           FLAG_JOHTO_SLICE(0x0F)
#define FLAG_HIDE_SSAQUA_1F_GRANDPA          FLAG_JOHTO_SLICE(0x10)

// --- Story progress flags ---
#define FLAG_ADVENTURE_STARTED               FLAG_JOHTO_SLICE(0x20)
#define FLAG_RECEIVED_FIRST_POTION           FLAG_JOHTO_SLICE(0x21)
#define FLAG_RECEIVED_FIRST_BALLS            FLAG_JOHTO_SLICE(0x22)
#define FLAG_SHOWN_ELM_TOGEPI                FLAG_JOHTO_SLICE(0x23)
#define FLAG_MOM_VISITED                     FLAG_JOHTO_SLICE(0x24)
#define FLAG_VISITED_NEWBARK_TOWN            FLAG_JOHTO_SLICE(0x25)
#define FLAG_VISITED_CHERRYGROVE_CITY        FLAG_JOHTO_SLICE(0x26)
#define FLAG_GOT_MYSTICWATER                 FLAG_JOHTO_SLICE(0x27)
#define FLAG_GOT_SILK_SCARF                  FLAG_JOHTO_SLICE(0x28)
#define FLAG_COMPLETED_HOOH_PUZZLE           FLAG_JOHTO_SLICE(0x29)
#define FLAG_COMPLETED_AERODACTYL_PUZZLE     FLAG_JOHTO_SLICE(0x2A)
#define FLAG_COMPLETED_KABUTO_PUZZLE         FLAG_JOHTO_SLICE(0x2B)
#define FLAG_COMPLETED_OMANYTE_PUZZLE        FLAG_JOHTO_SLICE(0x2C)

// --- Encounter / item / misc flags used by slice maps ---
#define FLAG_DAY_POKEMON                     FLAG_JOHTO_SLICE(0x40)
#define FLAG_NIGHT_POKEMON                   FLAG_JOHTO_SLICE(0x41)
#define FLAG_ITEM_ROUTE_29_POTION            FLAG_JOHTO_SLICE(0x42)

// HnS feature toggle: Exp Share global on/off (story sets it during the lab event).
// Slice maps it into the Johto bank; a later pass can promote it to a global toggle.
#define FLAG_EXP_SHARE                       FLAG_JOHTO_SLICE(0x43)

#endif // GUARD_CONSTANTS_JOHTO_FLAGS_H
