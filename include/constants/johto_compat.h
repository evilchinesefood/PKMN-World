#ifndef GUARD_CONSTANTS_JOHTO_COMPAT_H
#define GUARD_CONSTANTS_JOHTO_COMPAT_H

// Region merge (Johto port): aliases for HnS symbols the expansion lacks, mapped to
// the nearest target equivalents so Johto scripts link. Cosmetic remaps (HG music,
// movement labels, multichoice, berry-tree slots) — refine in the Stage-4 content pass.
// NOTE: the berry-tree aliases below now map to dedicated Johto slots (BERRY_TREE_JOHTO_*,
// defined in constants/berry.h), so they no longer share state with the Hoenn trees.
#define MUS_HG_ENCOUNTER_RIVAL      MUS_ENCOUNTER_BRENDAN
#define MUS_HG_KIMONO_GIRL          MUS_ENCOUNTER_GIRL
#define MUS_HG_FOLLOW_ME_1          MUS_ENCOUNTER_FEMALE
#define Common_Movement_WalkLeft1   Common_Movement_WalkLeft
#define BERRY_TREE_CHERI_1          BERRY_TREE_JOHTO_CHERI_1
#define BERRY_TREE_CHERI_2          BERRY_TREE_JOHTO_CHERI_2

// === Azalea area aliases ===
#define MUS_HG_RIVAL_EXIT           MUS_ENCOUNTER_BRENDAN
#define Common_Movement_WalkRight1  Common_Movement_WalkRight
#define Common_Movement_JumpDown1   Common_Movement_WalkDown
#define Common_Movement_JumpUp1     Common_Movement_WalkUp

#define TUTOR_MOVE_HEADBUTT          MOVE_HEADBUTT

// === Goldenrod area aliases ===
#define MUS_HG_GOLDENROD            MUS_RUSTBORO
#define MUS_HG_ROCKET_TAKEOVER      MUS_MT_PYRE_EXTERIOR

#define Common_Movement_WalkUp1        Common_Movement_WalkUp
#define Common_Movement_WalkDown1      Common_Movement_WalkDown

// === Ecruteak area aliases ===
#define MUS_HG_KIMONO_GIRL_DANCE    MUS_ENCOUNTER_GIRL
#define MUS_HG_POKEGEAR_REGISTERED  MUS_REGISTER_MATCH_CALL
#define MUS_HG_VS_HO_OH             MUS_RG_VS_LEGEND
// Tin Tower legendary beam descent has no target movement type -> stand still for now
#define MOVEMENT_TYPE_TOWER_BEAM    MOVEMENT_TYPE_NONE
// Ecruteak berry trees borrow Hoenn slots (own slots in Stage 4)
#define BERRY_TREE_RAWST_1          BERRY_TREE_JOHTO_RAWST_1
#define BERRY_TREE_RAWST_2          BERRY_TREE_JOHTO_RAWST_2


// === Olivine area aliases ===
#define MUS_HG_OAK                  MUS_RG_FOLLOW_ME
#define MUS_HG_VS_LUGIA             MUS_RG_VS_LEGEND

// === Cianwood area aliases ===
// Eusine encounter cue (script playbgm) -> a target character-encounter theme.
#define MUS_HG_EUSINE               MUS_ENCOUNTER_BRENDAN
// Cianwood City Sitrus berry tree borrows a real suffixed Hoenn slot (own slot in Stage 4).
#define BERRY_TREE_SITRUS_1         BERRY_TREE_JOHTO_SITRUS_1

// === Mahogany area aliases ===
// Team Rocket HQ takeover theme (script playbgm + map header) -> target villain-base theme.
#define MUS_HG_TEAM_ROCKET_HQ       MUS_MT_PYRE_EXTERIOR
// Lance vs Ariana+Grunt multi-battle: HnS special-battle id has no target equivalent;
// map to the generic multi-battle so the setvar/DoSpecialTrainerBattle path links.
// The faithful Lance set piece is content-stage work.
#define SPECIAL_BATTLE_LANCE        SPECIAL_BATTLE_MULTI
// Mahogany-area berry trees borrow real suffixed Hoenn slots (own slots in Stage 4).
#define BERRY_TREE_ASPEAR_1         BERRY_TREE_JOHTO_ASPEAR_1
#define BERRY_TREE_CHESTO_2         BERRY_TREE_JOHTO_CHESTO_2
#define BERRY_TREE_LEPPA_1          BERRY_TREE_JOHTO_LEPPA_1
#define BERRY_TREE_LEPPA_2          BERRY_TREE_JOHTO_LEPPA_2

// === Blackthorn area aliases ===
// Dragon's Den elder quiz: HnS bespoke multichoice sets have no target equivalents;
// (Stage-4) The 5 Dragon's-Den elder quizzes are now REAL 3-option multichoice lists
// (MULTI_ELDERQUIIZ1-5, defined in include/constants/script_menu.h + src/data/script_menu.h).
// The YESNO aliases were removed so Quiz5's correct answer (option 2 = "Both") is reachable
// and the Rising Badge (8th) is obtainable.

// Blackthorn-area berry trees -> Hoenn slots (Stage-4 own slots)
#define BERRY_TREE_ASPEAR_2  BERRY_TREE_JOHTO_ASPEAR_2
#define BERRY_TREE_LUM_1     BERRY_TREE_JOHTO_LUM_1

// === Final Johto batch aliases ===
// Tohjo Falls Giovanni cutscene radio theme (script playbgm) -> target villain-base theme.
#define MUS_HG_RADIO_ROCKET         MUS_MT_PYRE_EXTERIOR

#endif
