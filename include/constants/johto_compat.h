#ifndef GUARD_CONSTANTS_JOHTO_COMPAT_H
#define GUARD_CONSTANTS_JOHTO_COMPAT_H

// Region merge (Johto port): aliases for HnS symbols the expansion lacks, mapped to
// the nearest target equivalents so Johto scripts link. Cosmetic remaps (movement
// labels, multichoice) — refine in the Stage-4 content pass.
// NOTE: the berry-tree aliases are GONE (issue #163). They mapped BERRY_TREE_<berry>_<n>
// straight onto BERRY_TREE_JOHTO_<berry>_<n>, so a map object naming the short form and
// one naming the long form wrote the SAME berryTrees[] index - two trees, one save slot,
// and harvesting either emptied the other. Every Johto tree now names its own
// BERRY_TREE_JOHTO_* id from constants/berry.h directly. Do not reintroduce a short-form
// alias: one id is one save slot, and the symptom is invisible until someone harvests.
#define Common_Movement_WalkLeft1   Common_Movement_WalkLeft

// === Azalea area aliases ===
#define Common_Movement_WalkRight1  Common_Movement_WalkRight
#define Common_Movement_JumpDown1   Common_Movement_WalkDown
#define Common_Movement_JumpUp1     Common_Movement_WalkUp

#define TUTOR_MOVE_HEADBUTT          MOVE_HEADBUTT

// === Goldenrod area aliases ===

#define Common_Movement_WalkUp1        Common_Movement_WalkUp
#define Common_Movement_WalkDown1      Common_Movement_WalkDown

// === Ecruteak area aliases ===
// Tin Tower legendary beam descent has no target movement type -> stand still for now
#define MOVEMENT_TYPE_TOWER_BEAM    MOVEMENT_TYPE_NONE

// === Olivine area aliases ===

// === Cianwood area aliases ===

// === Mahogany area aliases ===
// Lance vs Ariana+Grunt multi-battle: the HnS special-battle id has no target equivalent, so
// alias it to the engine's generic multi-battle and let MahoganyHideout_B2F's setvar VAR_0x8004 /
// DoSpecialTrainerBattle path link and fire.
//
// WONTFIX (issue #66). This alias is permanent, not a placeholder standing in for a faithful
// version. The HGSS set piece is "Lance as your in-game partner against Ariana and a Grunt", and
// naming those three trainers was the job of the HnS SET_TRAINER_A/B setup ops, which the merge
// dropped with nothing to replace them. The target's SPECIAL_BATTLE_MULTI path (battle_special.c,
// DoSpecialTrainerBattle) instead passes gPartnerTrainerId to FillPartnerParty and leaves the
// TRAINER_BATTLE_PARAM opponent slots for the battle engine to read downstream; MahoganyHideout_B2F
// sets none of the three (it only sets VAR_0x8005 to 0, taking the 2-vs-2 arm) — so what runs is
// whatever the generic multi path produces, not the authored line-up. Restoring the fight as HGSS
// staged it means authoring Ariana's and the Grunt's parties and wiring Lance up as the in-game
// partner: new content, not a rename.
// The dead labels this left behind are documented at MahoganyHideout_B2F/scripts.inc.
#define SPECIAL_BATTLE_LANCE        SPECIAL_BATTLE_MULTI
// Mahogany-area berry trees borrow real suffixed Hoenn slots (own slots in Stage 4).

// === Blackthorn area aliases ===
// Dragon's Den elder quiz: HnS bespoke multichoice sets have no target equivalents;
// (Stage-4) The 5 Dragon's-Den elder quizzes are now REAL 3-option multichoice lists
// (MULTI_ELDERQUIIZ1-5, defined in include/constants/script_menu.h + src/data/script_menu.h).
// The YESNO aliases were removed so Quiz5's correct answer (option 2 = "Both") is reachable
// and the Rising Badge (8th) is obtainable.

// Blackthorn-area berry trees -> Hoenn slots (Stage-4 own slots)

// === removenamedmon result codes ===
// Written to gSpecialVar_Result by ScrCmd_removenamedmon_Compat (src/scrcmd_johto_compat.c) and
// read by data/maps/Route31/scripts.inc (Kenya) and data/maps/CianwoodHouse3/scripts.inc (Shuckie).
//
// 0 and 2 deliberately alias the engine's MON_GIVEN_TO_PARTY / MON_CANT_GIVE so the pre-existing
// `goto_if_eq VAR_RESULT, MON_CANT_GIVE` branches keep meaning "he didn't take it".
//
// 3 is RESERVED, not free: CianwoodHouse3 already branched on a bare `3` (now spelled
// REMOVE_NAMED_MON_KEPT) into CianwoodCity_EventScript_KirkKeepShuckie ("SHUCKLE likes you — keep
// it"), HnS's high-friendship outcome for returning Shuckie. That path is unimplemented here (this
// handler never emits 3 today), but numbering a new reason 3 would silently arm it the moment
// gift 2's return is finished. The new refusals therefore start at 4.
#define REMOVE_NAMED_MON_REMOVED     0
#define REMOVE_NAMED_MON_NOT_FOUND   2
#define REMOVE_NAMED_MON_KEPT        3  // HnS: the NPC lets the player keep the mon (not emitted yet)
#define REMOVE_NAMED_MON_NO_MAIL     4
#define REMOVE_NAMED_MON_WRONG_MAIL  5
#define REMOVE_NAMED_MON_LAST_MON    6

#endif
