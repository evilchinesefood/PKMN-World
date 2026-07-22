#ifndef GUARD_BATTLE_NET_H
#define GUARD_BATTLE_NET_H

// Battle Net (issue #5) Mega Economy specials, called from data/scripts/battle_net.inc.
void TryBattleNetRematchReward(void);
void ClaimBattleNetStone(void);

// P2 flagship floor (RegionHub_2F). Pure data only -- the menus are script-level
// `multichoice`, since a menu opened from a special is asynchronous.
void BattleNetStarterStoneFromChoice(void);
void BattleNetVendorStoneFromChoice(void);
void BattleNetShardColorFromChoice(void);
void GetBattleNetShardCount(void);
void DeductBattleNetShards(void);
void TryBuyBattleNetShard(void);
void BufferBattleNetRecords(void);

// P3 battle modes (Scaling Type Trainer / Tower Streak / ruleset rooms) plus
// the Leader Sim's BP payout. Modes are BNET_MODE_* (constants/battle_net.h).
void DoBattleNetSimBattle(void);
void CheckBattleNetRuleParty(void);
void AddBattleNetPoints(void);
void GiveBattleNetRandomShard(void);
void UpdateBattleNetStreak(void);
void BufferBattleNetStreak(void);

#endif // GUARD_BATTLE_NET_H
