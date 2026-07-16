@ Battle Net victory hook (issue #4 -> #5).
@ Every leader/E4/champion REMATCH victory calls this with VAR_0x8004 = the trainer ID
@ that was just defeated (set by each call site; do NOT rely on post-battle globals --
@ ResetTrainerOpponentIds() makes VAR_TRAINER_BATTLE_OPPONENT_A's lifetime untrustworthy).
@
@ Issue #5 (Battle Net + Mega Economy P1) attaches rewards HERE, not in the 41 call sites:
@   - replace the body with a special (e.g. TryLeaderRematchReward) reading gSpecialVar_0x8004
@   - the special must self-gate on GetCurrentDifficultyLevel() == DIFFICULTY_HARD
@     (the Hoenn E4/Champion sites below also run on FIRST clears)
@   - shard payout per win (leaders 1 shard of their color, E4 2) + ONE-TIME signature
@     stone per leader behind a per-leader guard flag from the free 0xD7C..0xEEF window;
@     the 3 TRAINER_CHAMPION_REMATCH_* IDs map to ONE leader/flag (the Kanto rival)
@   - one-time give idiom = the World Championship Gold Bottle Cap pattern
@     (BattleFrontier_BattleDomeLobby/scripts.inc: skip if guard flag set; giveitem;
@      VAR_RESULT FALSE -> leave flag unset so the prize is reclaimable; else setflag)
@ Note: the NORMAL _2 league parties stay as data: intentionally unreachable post-champion
@ (VAR_DIFFICULTY resyncs HARD on region entry) -- harmless zero-risk fallback.
BattleNet_EventScript_OnLeaderRematchWin::
	return
