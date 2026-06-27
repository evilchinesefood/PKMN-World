#ifndef GUARD_CONSTANTS_JOHTO_COMPAT_H
#define GUARD_CONSTANTS_JOHTO_COMPAT_H

// Region merge (Johto port): aliases for HnS symbols the expansion lacks, mapped to
// the nearest target equivalents so Johto scripts link. Cosmetic remaps (HG music,
// movement labels, multichoice, berry-tree slots) — refine in the Stage-4 content pass.
// NOTE: berry-tree aliases share state with the Hoenn trees they point at (acceptable
// for now; give Johto trees their own slots in Stage 4).
#define MUS_HG_ENCOUNTER_RIVAL      MUS_ENCOUNTER_BRENDAN
#define MUS_HG_KIMONO_GIRL          MUS_ENCOUNTER_GIRL
#define MUS_HG_FOLLOW_ME_1          MUS_ENCOUNTER_FEMALE
#define Common_Movement_WalkLeft1   Common_Movement_WalkLeft
#define MULTI_DAYS_OF_WEEK          MULTI_YESNO
#define BERRY_TREE_CHERI_1          BERRY_TREE_ROUTE_102_PECHA
#define BERRY_TREE_CHERI_2          BERRY_TREE_ROUTE_102_ORAN

// === Azalea area aliases ===
#define MUS_HG_RIVAL_EXIT           MUS_ENCOUNTER_BRENDAN
#define MULTI_KURT_BALLS            MULTI_YESNO
#define Common_Movement_WalkRight1  Common_Movement_WalkRight
#define Common_Movement_JumpDown1   Common_Movement_WalkDown
#define Common_Movement_JumpUp1     Common_Movement_WalkUp

#define TUTOR_MOVE_HEADBUTT          MOVE_HEADBUTT

// === Goldenrod area aliases ===
#define MUS_HG_GOLDENROD            MUS_RUSTBORO
#define MUS_HG_ROCKET_TAKEOVER      MUS_MT_PYRE_EXTERIOR
#define MULTI_5FLOORS               MULTI_YESNO
#define MULTI_7FLOORS               MULTI_YESNO
#define MULTI_PRIZE_MONS            MULTI_YESNO

#define Common_Movement_WalkUp1        Common_Movement_WalkUp
#define Common_Movement_WalkDown1      Common_Movement_WalkDown

// === Ecruteak area aliases ===
#define MUS_HG_KIMONO_GIRL_DANCE    MUS_ENCOUNTER_GIRL
#define MUS_HG_POKEGEAR_REGISTERED  MUS_REGISTER_MATCH_CALL
#define MUS_HG_VS_HO_OH             MUS_RG_VS_LEGEND
#define MULTI_GOLDSILVER            MULTI_YESNO
// Tin Tower legendary beam descent has no target movement type -> stand still for now
#define MOVEMENT_TYPE_TOWER_BEAM    MOVEMENT_TYPE_NONE
// Ecruteak berry trees borrow Hoenn slots (own slots in Stage 4)
#define BERRY_TREE_RAWST_1          BERRY_TREE_ROUTE_103_CHERI_1
#define BERRY_TREE_RAWST_2          BERRY_TREE_ROUTE_103_LEPPA


// === Olivine area aliases ===
#define MUS_HG_OAK                  MUS_RG_FOLLOW_ME
#define MUS_HG_VS_LUGIA             MUS_RG_VS_LEGEND
#define MULTI_OLIVINE_HARBOR        MULTI_YESNO

#endif
