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

// === Azalea area: more HnS Johto trainers (real parties land in trainers stage) ===
#define TRAINER_AL             TRAINER_JOEY
#define TRAINER_AMY_AND_MAY    TRAINER_JOEY
#define TRAINER_BILL           TRAINER_JOEY
#define TRAINER_BUGSY_1        TRAINER_JOEY
#define TRAINER_CALVIN         TRAINER_JOEY
#define TRAINER_DANIEL         TRAINER_JOEY
#define TRAINER_EMMA           TRAINER_JOEY
#define TRAINER_ETO            TRAINER_JOEY
#define TRAINER_GINA           TRAINER_JOEY
#define TRAINER_GRUNT_21       TRAINER_JOEY
#define TRAINER_GRUNT_22       TRAINER_JOEY
#define TRAINER_IAN            TRAINER_JOEY
#define TRAINER_JENN           TRAINER_JOEY
#define TRAINER_KATE           TRAINER_JOEY
#define TRAINER_KEITH          TRAINER_JOEY
#define TRAINER_NICK           TRAINER_JOEY
#define TRAINER_PROTON_1       TRAINER_JOEY
#define TRAINER_RAY            TRAINER_JOEY
#define TRAINER_RIVAL_CHIKORITA_2 TRAINER_JOEY
#define TRAINER_RIVAL_CYNDAQUIL_2 TRAINER_JOEY
#define TRAINER_RIVAL_TOTODILE_2 TRAINER_JOEY
#define TRAINER_RUSSELL        TRAINER_JOEY
#define TRAINER_TODD           TRAINER_JOEY

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
#define TRAINER_ANN_AND_ANNE       TRAINER_JOEY
#define TRAINER_ARCHER             TRAINER_JOEY
#define TRAINER_ARIANA_2           TRAINER_JOEY
#define TRAINER_ARNIE              TRAINER_JOEY
#define TRAINER_BROOKE             TRAINER_JOEY
#define TRAINER_CARRIE             TRAINER_JOEY
#define TRAINER_DIRK               TRAINER_JOEY
#define TRAINER_ELLIOT             TRAINER_JOEY
#define TRAINER_ETO_3              TRAINER_JOEY
#define TRAINER_GRUNT_10           TRAINER_JOEY
#define TRAINER_GRUNT_11           TRAINER_JOEY
#define TRAINER_GRUNT_12           TRAINER_JOEY
#define TRAINER_GRUNT_19           TRAINER_JOEY
#define TRAINER_GRUNT_2            TRAINER_JOEY
#define TRAINER_GRUNT_20           TRAINER_JOEY
#define TRAINER_GRUNT_26           TRAINER_JOEY
#define TRAINER_GRUNT_27           TRAINER_JOEY
#define TRAINER_GRUNT_28           TRAINER_JOEY
#define TRAINER_GRUNT_3            TRAINER_JOEY
#define TRAINER_GRUNT_4            TRAINER_JOEY
#define TRAINER_GRUNT_5            TRAINER_JOEY
#define TRAINER_GRUNT_6            TRAINER_JOEY
#define TRAINER_GRUNT_7            TRAINER_JOEY
#define TRAINER_GRUNT_8            TRAINER_JOEY
#define TRAINER_GRUNT_9            TRAINER_JOEY
#define TRAINER_IRWIN              TRAINER_JOEY
#define TRAINER_ISSAC              TRAINER_JOEY
#define TRAINER_KIM                TRAINER_JOEY
#define TRAINER_KRISE              TRAINER_JOEY
#define TRAINER_PETREL_2           TRAINER_JOEY
#define TRAINER_PROTON_2           TRAINER_JOEY
#define TRAINER_RICH               TRAINER_JOEY
#define TRAINER_RIVAL_CHIKORITA_4  TRAINER_JOEY
#define TRAINER_RIVAL_CYNDAQUIL_4  TRAINER_JOEY
#define TRAINER_RIVAL_TOTODILE_4   TRAINER_JOEY
#define TRAINER_TERU               TRAINER_JOEY
#define TRAINER_WALT               TRAINER_JOEY
#define TRAINER_WHITNEY_1          TRAINER_JOEY

// === Ecruteak area: HnS Johto trainers (real parties land in the trainers stage) ===
#define TRAINER_EUGENE             TRAINER_JOEY
#define TRAINER_GRUNT_33           TRAINER_JOEY
#define TRAINER_HARRY              TRAINER_JOEY
#define TRAINER_JAMIE              TRAINER_JOEY
#define TRAINER_JEFFREY            TRAINER_JOEY
#define TRAINER_KUNI               TRAINER_JOEY
#define TRAINER_MIKI               TRAINER_JOEY
#define TRAINER_MORTY_1            TRAINER_JOEY
#define TRAINER_NAOKO              TRAINER_JOEY
#define TRAINER_NARD               TRAINER_JOEY
#define TRAINER_NORMAN             TRAINER_JOEY
#define TRAINER_PING               TRAINER_JOEY
#define TRAINER_RICHARDO           TRAINER_JOEY
#define TRAINER_RIVAL_CHIKORITA_3  TRAINER_JOEY
#define TRAINER_RIVAL_CYNDAQUIL_3  TRAINER_JOEY
#define TRAINER_RIVAL_TOTODILE_3   TRAINER_JOEY
#define TRAINER_RUTH               TRAINER_JOEY
#define TRAINER_SAYO               TRAINER_JOEY
#define TRAINER_TOBY               TRAINER_JOEY
#define TRAINER_VALERIE            TRAINER_JOEY
#define TRAINER_ZUKI               TRAINER_JOEY

// Ecruteak-area Johto-only key items (Ho-Oh / Lugia bells) -> no target item yet
#define ITEM_CLEAR_BELL        ITEM_NONE
#define ITEM_TIDAL_BELL        ITEM_NONE


// === Olivine area: HnS Johto trainers (real parties land in the trainers stage) ===
#define TRAINER_ALFRED             TRAINER_JOEY
#define TRAINER_DENIS              TRAINER_JOEY
#define TRAINER_ELAINE             TRAINER_JOEY
#define TRAINER_ERNEST             TRAINER_JOEY
#define TRAINER_JASMINE_1          TRAINER_JOEY
#define TRAINER_JASMINE_1_2        TRAINER_JOEY
#define TRAINER_JASMINE_1_3        TRAINER_JOEY
#define TRAINER_MATHEW             TRAINER_JOEY
#define TRAINER_TERRELL            TRAINER_JOEY
#define TRAINER_THEO               TRAINER_JOEY

// Olivine-area items: HnS TM/HM-by-move -> Gen-3 numbered ids; SecretPotion key item stub
#define ITEM_HM_STRENGTH       ITEM_HM04
#define ITEM_TM_BULK_UP        ITEM_TM08
#define ITEM_TM_IRON_TAIL      ITEM_TM23
#define ITEM_TM_SHOCK_WAVE     ITEM_TM34
#define ITEM_SECRET_POTION     ITEM_NONE

#endif // GUARD_CONSTANTS_JOHTO_COMPAT_IDS_H
