#ifndef GUARD_CONSTANTS_JOHTO_COMPAT_IDS_H
#define GUARD_CONSTANTS_JOHTO_COMPAT_IDS_H

// Region merge (Johto port): compatibility aliases for HnS item/trainer ids whose
// names differ from (or don't exist in) the target. Included from data/event_scripts.s
// so transformed Johto map scripts assemble unchanged.
//
// HnS names TMs/HMs by move; the target uses the numbered Gen-3 ids. Map each to its
// Gen-3 number. ITEM_EXP_SHARE_SMALL -> the target's single Exp Share. ITEM_GS_BALL
// (Johto-only key item) has no target item yet -> ITEM_NONE stub (the GS Ball / Celebi
// event is out of the Violet-area scope; the giveitem becomes a no-op for now).

#define ITEM_TM_DOUBLE_TEAM   ITEM_TM32   // Gen 3 TM32 = Double Team
#define ITEM_TM_ROAR          ITEM_TM05   // Gen 3 TM05 = Roar
#define ITEM_TM_TORMENT       ITEM_TM41   // Gen 3 TM41 = Torment
#define ITEM_HM_FLASH         ITEM_HM05   // Gen 3 HM05 = Flash
#define ITEM_EXP_SHARE_SMALL  ITEM_EXP_SHARE
#define ITEM_GS_BALL          ITEM_NONE

// HnS Johto trainers not yet ported (real parties land in the trainers stage). Remap
// to an existing placeholder so the battles still fire. See brief: stub, don't block.
#define TRAINER_FALKNER_1     TRAINER_JOEY
#define TRAINER_ABE           TRAINER_JOEY
#define TRAINER_CHOW          TRAINER_JOEY
#define TRAINER_GORDON        TRAINER_JOEY
#define TRAINER_JIN           TRAINER_JOEY
#define TRAINER_LI            TRAINER_JOEY
#define TRAINER_LIZ           TRAINER_JOEY
#define TRAINER_NATHAN        TRAINER_JOEY
#define TRAINER_NEAL          TRAINER_JOEY
#define TRAINER_NICO          TRAINER_JOEY
#define TRAINER_PETER         TRAINER_JOEY
#define TRAINER_RALPH         TRAINER_JOEY
#define TRAINER_ROD           TRAINER_JOEY
#define TRAINER_TROY          TRAINER_JOEY

#endif // GUARD_CONSTANTS_JOHTO_COMPAT_IDS_H
