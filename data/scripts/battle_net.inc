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
	checkitemspace VAR_0x8006, VAR_0x8007
	goto_if_eq VAR_RESULT, FALSE, BattleNet_EventScript_ShardsForfeited
	giveitem VAR_0x8006, VAR_0x8007
BattleNet_EventScript_TryStone:
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

@ Shards are forfeited, not held: owed-count state would need a SaveBlock field and v6 is frozen.
@ The stone give below still runs -- it has its own pending/reclaim path.
BattleNet_EventScript_ShardsForfeited:
	msgbox BattleNet_Text_ShardsForfeited, MSGBOX_DEFAULT
	goto BattleNet_EventScript_TryStone

BattleNet_Text_ShardsForfeited:
	.string "Your BAG is full, so today's SHARD\n"
	.string "payout was forfeited.\p"
	.string "Make room before your next rematch.$"

BattleNet_Text_StonePending:
	.string "The Battle Net is holding a MEGA STONE\n"
	.string "for you, but your BAG is full.\p"
	.string "Make room and win here again to claim it.$"

@ ---------- Hub console: entry to the Battle Net flagship floor (issue #5 P2) ----------
@ bg_event sign at RegionHub (20,12), on the vendor counter row. Two things must hold, and
@ BLOCKED alone is not enough: the sign tile must be impassable (a sign on a WALKABLE tile
@ never fires) AND an adjacent tile must be REACHABLE from the hub arrival warp (16,4).
@ Verified against data/layouts/RegionHub/map.bin: (20,12) is collision 1, and (20,13) is
@ collision 0 and inside the 279-tile region flood-filled from (16,4). The earlier placement
@ at (20,9) was impassable but only readable from (20,10), which sits in the sealed 12-tile
@ counter pocket x=19..24,y=10..11 -- walkable, but unreachable, so the console never fired.
@ Warp 1 is (20,13), the arrival anchor coming back down from 2F; it lands the player facing
@ the console and inside the main floor. bg events get NO counter look-ahead (unlike object
@ events), which is why the vendor NPCs in that pocket work and a sign there would not.
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
