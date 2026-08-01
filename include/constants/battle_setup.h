#ifndef GUARD_CONSTANTS_BATTLE_SETUP_H
#define GUARD_CONSTANTS_BATTLE_SETUP_H

#define TRAINER_BATTLE_SINGLE                           0
#define TRAINER_BATTLE_CONTINUE_SCRIPT_NO_MUSIC         1
#define TRAINER_BATTLE_CONTINUE_SCRIPT                  2
#define TRAINER_BATTLE_SINGLE_NO_INTRO_TEXT             3
#define TRAINER_BATTLE_DOUBLE                           4
#define TRAINER_BATTLE_REMATCH                          5
#define TRAINER_BATTLE_CONTINUE_SCRIPT_DOUBLE           6
#define TRAINER_BATTLE_REMATCH_DOUBLE                   7
#define TRAINER_BATTLE_CONTINUE_SCRIPT_DOUBLE_NO_MUSIC  8
#define TRAINER_BATTLE_TWO_TRAINERS_NO_INTRO            13
#define TRAINER_BATTLE_EARLY_RIVAL                      14
// As SINGLE_NO_INTRO_TEXT, but skips the reveal movement. For battles started
// from a bg_event (a sign), where there is no trainer object to reveal and
// VAR_LAST_TALKED holds either LOCALID_NONE or a stale id from another NPC.
#define TRAINER_BATTLE_SINGLE_NO_INTRO_NO_REVEAL        15

#endif // GUARD_CONSTANTS_BATTLE_SETUP_H
