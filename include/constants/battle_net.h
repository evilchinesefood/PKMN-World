#ifndef GUARD_CONSTANTS_BATTLE_NET_H
#define GUARD_CONSTANTS_BATTLE_NET_H

// Battle Net sim modes (issue #5 P3), passed to DoBattleNetSimBattle /
// CheckBattleNetRuleParty in VAR_0x8004. Scaling/Monotype also take a type
// ordinal (0..17, an index into sBnetTypes in src/battle_net.c) in VAR_0x8005.
#define BNET_MODE_SCALING   0  // player-picked type, 2-4 mons, avg party level - 2..5
#define BNET_MODE_STREAK    1  // random type per round, otherwise like SCALING
#define BNET_MODE_LV50      2  // any type, 3 mons at Lv50; party must all be <= Lv50
#define BNET_MODE_MONOTYPE  3  // picked type, 3 mons; party must all match the type
#define BNET_MODE_LC        4  // Little Cup: 3 base-stage evolvable mons at Lv5

#define BNET_STREAK_ROUNDS  7  // wins needed to clear a Tower Streak run
#define BNET_STREAK_BONUS   5  // extra BP for clearing all rounds (plus 1 BP per win)

#endif // GUARD_CONSTANTS_BATTLE_NET_H
