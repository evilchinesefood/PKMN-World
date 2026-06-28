#ifndef GUARD_CONSTANTS_JOHTO_COMPAT_IDS_H
#define GUARD_CONSTANTS_JOHTO_COMPAT_IDS_H

// Region merge (Johto port): compatibility aliases for HnS item/trainer ids whose
// names differ from (or don't exist in) the target. Included from data/event_scripts.s
// so transformed Johto map scripts assemble unchanged.
//
// HnS names TMs/HMs by move; the target uses the numbered Gen-3 ids. Map each to its
// Gen-3 number. ITEM_EXP_SHARE_SMALL -> the target's single Exp Share. ITEM_GS_BALL is
// now a real key item (see include/constants/items.h + src/data/items.h), so the Kurt ->
// Ilex Forest shrine -> Celebi chain works; no alias needed.

#define ITEM_TM_DOUBLE_TEAM   ITEM_TM32   // Gen 3 TM32 = Double Team
#define ITEM_TM_ROAR          ITEM_TM05   // Gen 3 TM05 = Roar
#define ITEM_TM_TORMENT       ITEM_TM41   // Gen 3 TM41 = Torment
#define ITEM_HM_FLASH         ITEM_HM05   // Gen 3 HM05 = Flash
#define ITEM_EXP_SHARE_SMALL  ITEM_EXP_SHARE

// HnS Johto trainers not yet ported (real parties land in the trainers stage). Remap
// to an existing placeholder so the battles still fire. See brief: stub, don't block.

// === Azalea area: more HnS Johto trainers (real parties land in trainers stage) ===

// Azalea-area HnS TM/HM items -> Gen-3 numbered ids
#define ITEM_HM_SURF           ITEM_HM03
#define ITEM_TM_BULLET_SEED    ITEM_TM09
#define ITEM_TM_RAIN_DANCE     ITEM_TM18
#define ITEM_TM_SECRET_POWER   ITEM_TM43
#define ITEM_TM_SUNNY_DAY      ITEM_TM11

// === Goldenrod area: items, trainers, trade (region merge) ===
#define ITEM_TM_ATTRACT        ITEM_TM45
#define ITEM_TM_CALM_MIND      ITEM_TM04
#define ITEM_TM_DIG            ITEM_TM28
#define ITEM_TM_FRUSTRATION    ITEM_TM21
#define ITEM_TM_RETURN         ITEM_TM27
#define ITEM_TM_ROCK_TOMB      ITEM_TM39
#define ITEM_TM_SKILL_SWAP     ITEM_TM48
#define ITEM_HM_ROCK_SMASH     ITEM_HM06
#define ITEM_PASS              ITEM_NONE
#define ITEM_RADIO             ITEM_NONE
#define ITEM_RAINBOW_WING      ITEM_NONE
#define ITEM_SILVER_WING       ITEM_NONE
#define ITEM_SQUIRT_BOTTLE     ITEM_NONE
#define INGAME_TRADE_MACHOP    0
#define INGAME_TRADE_VOLTORB   0
#define MON_UNSATISFACTORY   1
#define MON_SATISFACTORY     2

// === Ecruteak area: HnS Johto trainers (real parties land in the trainers stage) ===

// Ecruteak-area Johto-only key items (Ho-Oh / Lugia bells) -> no target item yet
#define ITEM_CLEAR_BELL        ITEM_NONE
#define ITEM_TIDAL_BELL        ITEM_NONE


// === Olivine area: HnS Johto trainers (real parties land in the trainers stage) ===

// Olivine-area items: HnS TM/HM-by-move -> Gen-3 numbered ids; SecretPotion key item stub
#define ITEM_HM_STRENGTH       ITEM_HM04
#define ITEM_TM_BULK_UP        ITEM_TM08
#define ITEM_TM_IRON_TAIL      ITEM_TM23
#define ITEM_TM_SHOCK_WAVE     ITEM_TM34
#define ITEM_SECRET_POTION     ITEM_NONE


// === Cianwood area: HnS Johto trainers (real parties land in the trainers stage) ===
// TRAINER_LUNG collides with an existing target enum, so it is script-edited to
// TRAINER_JOEY in CianwoodGym/scripts.inc instead of aliased here.

// Cianwood-area item: HnS HM-by-move -> Gen-3 numbered id (Fly = HM02)
#define ITEM_HM_FLY            ITEM_HM02

// === Mahogany area: HnS Johto trainers (real parties land in the trainers stage) ===
// None collide with an existing target enum (verified), so all are aliased here.

// Mahogany-area items: HnS TM/HM-by-move -> Gen-3 numbered ids; key items -> ITEM_NONE.
// Whirlpool has no Gen-3 HM slot; stub to ITEM_HM08 so the giveitem resolves.
#define ITEM_HM_WHIRLPOOL      ITEM_HM08
#define ITEM_RED_SCALE         ITEM_NONE
#define ITEM_TM_HAIL           ITEM_TM07
#define ITEM_TM_HIDDEN_POWER   ITEM_TM10
#define ITEM_TM_SLUDGE_BOMB    ITEM_TM36
#define ITEM_TM_THIEF          ITEM_TM46

// === Blackthorn area: HnS Johto trainers (real parties land in the trainers stage) ===
// None collide with an existing target enum (verified) except PAUL/TED which are
// edited in-script to TRAINER_JOEY; all others are aliased here.

// === SS Aqua area: HnS Johto trainers (real parties land in the trainers stage) ===
// 10 SS Aqua trainers collide with an existing target enum (CAROL, COLIN, DEBRA,
// EDWARD, JEFF, JONAH, LYLE, NATE, NOLAND, SHIRLEY) and are edited in-script to
// TRAINER_JOEY in their map scripts.inc instead of aliased here; all others below.
// TRAINER_MEG_AND_PEG is a trainerbattle_double; aliasing to single-mon TRAINER_JOEY
// builds fine (correct double-battle party lands in the trainers stage).

// === Mt Silver area: endgame Red battle (real party lands in the trainers stage) ===

// === Final Johto batch: Route 26/27 + Tohjo Falls trainers (real parties land in the trainers
// stage). BETH/RICHARD/BLAKE/GILBERT/JOSE collide with existing target enums and are edited
// in-script to TRAINER_JOEY instead; all others (incl. GIOVANNI) aliased here.

#endif // GUARD_CONSTANTS_JOHTO_COMPAT_IDS_H
