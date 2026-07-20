@ Battle Net victory hook (issue #4 -> #5). Every leader / Elite Four / Champion REMATCH victory
@ calls this with VAR_0x8004 = the trainer id that was just defeated (set by each of the 41 call
@ sites; do NOT rely on post-battle globals -- ResetTrainerOpponentIds() makes them unreliable).
@
@ Issue #5 (Battle Net + Mega Economy P1) attaches the rewards HERE, not at the 41 sites:
@   - TryBattleNetRematchReward self-gates on DIFFICULTY_HARD (the 5 Hoenn league sites also fire
@     on FIRST clears) and looks the trainer up in sBattleNetRewards (src/battle_net.c).
@   - Shards pay out on every qualifying win: VAR_0x8006 = shard item, VAR_0x8007 = count.
@   - A signature mega stone drops once per leader: VAR_0x8008 (and VAR_0x8009 for the Kanto
@     champion trio's Mewtwonite X/Y). The guard flag is set via ClaimBattleNetStone only AFTER a
@     confirmed give, so a full bag leaves it reclaimable (the World Championship Cap idiom).
@ Stays a call-safe subroutine ending in return; a no-op on the Hoenn first-clear paths.
BattleNet_EventScript_OnLeaderRematchWin::
	special TryBattleNetRematchReward
	goto_if_eq VAR_RESULT, 0, BattleNet_EventScript_RewardDone
	giveitem VAR_0x8006, VAR_0x8007
	compare VAR_0x8008, ITEM_NONE
	goto_if_eq BattleNet_EventScript_TryStone2
	giveitem VAR_0x8008
	goto_if_eq VAR_RESULT, FALSE, BattleNet_EventScript_StonePending
	setvar VAR_0x8005, 1
	special ClaimBattleNetStone
BattleNet_EventScript_TryStone2:
	compare VAR_0x8009, ITEM_NONE
	goto_if_eq BattleNet_EventScript_RewardDone
	giveitem VAR_0x8009
	goto_if_eq VAR_RESULT, FALSE, BattleNet_EventScript_StonePending
	setvar VAR_0x8005, 2
	special ClaimBattleNetStone
BattleNet_EventScript_RewardDone:
	return

BattleNet_EventScript_StonePending:
	msgbox BattleNet_Text_StonePending, MSGBOX_DEFAULT
	return

BattleNet_Text_StonePending:
	.string "The Battle Net is holding a MEGA STONE\n"
	.string "for you, but your BAG is full.\p"
	.string "Make room and win here again to claim it.$"

@ ---------- Hub console: entry to the Battle Net flagship floor (issue #5 P2) ----------
@ bg_event sign at RegionHub (20,9). That tile is BLOCKED (verified against
@ data/layouts/RegionHub/map.bin) -- a sign on a WALKABLE tile never fires. The player reads
@ it from (20,10), which is also warp 1, the arrival anchor coming back down from 2F.
@ Gate is the same one the frontier attendant uses: champion of at least one region.
BattleNet_EventScript_HubConsole::
	lockall
	callnative RegionHub_ScrIsAnyRegionChampion
	goto_if_eq VAR_RESULT, FALSE, BattleNet_EventScript_HubConsoleLocked
	msgbox BattleNet_Text_HubConsoleAsk, MSGBOX_YESNO
	goto_if_eq VAR_RESULT, NO, BattleNet_EventScript_HubConsoleEnd
	closemessage
	warp MAP_REGION_HUB_2F, 0
	waitstate
	releaseall
	end

BattleNet_EventScript_HubConsoleEnd::
	releaseall
	end

BattleNet_EventScript_HubConsoleLocked::
	msgbox BattleNet_Text_HubConsoleLocked, MSGBOX_DEFAULT
	releaseall
	end

BattleNet_Text_HubConsoleAsk:
	.string "BATTLE NET TERMINAL\p"
	.string "The old link floor upstairs now runs a\n"
	.string "battle simulation network.\p"
	.string "Go up?$"

BattleNet_Text_HubConsoleLocked:
	.string "BATTLE NET TERMINAL\p"
	.string "ACCESS DENIED.\n"
	.string "Conquer at least one region's POKéMON\l"
	.string "LEAGUE first.$"
