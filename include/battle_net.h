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

#endif // GUARD_BATTLE_NET_H
