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

@ ---------- P3: sim terminal (Scaling Type Trainer + Leader Sim) ----------
@ Shared by the flagship floor's sim pod and every regional POKéMON CENTER terminal (P4).
@ Sim battles are Battle Tower-type: full EXP (issue #15), no money, no whiteout; the party is healed
@ before and after every sim, so the simulation never strands a fainted party.
@ DoBattleNetSimBattle returns VAR_RESULT 0 when it refused to launch (no battle-ready
@ mon / empty pool) -- in that case there is NO battle, so the script must NOT waitstate.
BattleNet_EventScript_Terminal::
	lockall
	goto BattleNet_EventScript_TerminalBody
@ Person-NPC form of the terminal (the P4 center attendants + the flagship pod):
@ same body, but the attendant turns to face the player first.
BattleNet_EventScript_TerminalAttendant::
	lock
	faceplayer
BattleNet_EventScript_TerminalBody::
	msgbox BattleNet_Text_TerminalIntro, MSGBOX_DEFAULT
BattleNet_EventScript_TerminalMenu:
	multichoice 0, 0, MULTI_BNET_SIM_MENU, FALSE
	switch VAR_RESULT
	case 0, BattleNet_EventScript_Scaling
	case 1, BattleNet_EventScript_LeaderSim
BattleNet_EventScript_TerminalBye::
	msgbox BattleNet_Text_TerminalBye, MSGBOX_DEFAULT
	releaseall
	end

@ Type picker subroutine: three 6-type pages in sBnetTypes order (src/battle_net.c).
@ Out: VAR_RESULT = 1 and VAR_0x8005 = type ordinal 0..17, or VAR_RESULT = 0 (cancelled).
@ In each page index 6 turns the page and anything higher (EXIT / B press) cancels.
BattleNet_EventScript_PickType::
	multichoice 0, 0, MULTI_BNET_TYPE_1, FALSE
	goto_if_eq VAR_RESULT, 6, BattleNet_EventScript_PickType2
	goto_if_ge VAR_RESULT, 7, BattleNet_EventScript_PickTypeCancel
	copyvar VAR_0x8005, VAR_RESULT
	setvar VAR_RESULT, 1
	return
BattleNet_EventScript_PickType2:
	multichoice 0, 0, MULTI_BNET_TYPE_2, FALSE
	goto_if_eq VAR_RESULT, 6, BattleNet_EventScript_PickType3
	goto_if_ge VAR_RESULT, 7, BattleNet_EventScript_PickTypeCancel
	copyvar VAR_0x8005, VAR_RESULT
	addvar VAR_0x8005, 6
	setvar VAR_RESULT, 1
	return
BattleNet_EventScript_PickType3:
	multichoice 0, 0, MULTI_BNET_TYPE_3, FALSE
	goto_if_eq VAR_RESULT, 6, BattleNet_EventScript_PickType
	goto_if_ge VAR_RESULT, 7, BattleNet_EventScript_PickTypeCancel
	copyvar VAR_0x8005, VAR_RESULT
	addvar VAR_0x8005, 12
	setvar VAR_RESULT, 1
	return
BattleNet_EventScript_PickTypeCancel:
	setvar VAR_RESULT, 0
	return

@ Scaling Type Trainer: pick a type, fight 2-4 of it a few levels below the party
@ average. Win: 1 BP + a 30% shard drop (checkitemspace-guarded like the rematch payout).
BattleNet_EventScript_Scaling::
	call BattleNet_EventScript_PickType
	goto_if_eq VAR_RESULT, 0, BattleNet_EventScript_TerminalMenu
	setvar VAR_0x8004, BNET_MODE_SCALING
	special HealPlayerParty
	special DoBattleNetSimBattle
	goto_if_eq VAR_RESULT, 0, BattleNet_EventScript_SimCantStart
	waitstate
	special HealPlayerParty
	specialvar VAR_RESULT, GetBattleOutcome
	goto_if_ne VAR_RESULT, B_OUTCOME_WON, BattleNet_EventScript_ScalingLost
	setvar VAR_0x8005, 1
	special AddBattleNetPoints
	msgbox BattleNet_Text_ScalingWon, MSGBOX_DEFAULT
	special GiveBattleNetRandomShard
	compare VAR_0x8008, ITEM_NONE
	goto_if_eq BattleNet_EventScript_ScalingAgain
	checkitemspace VAR_0x8008, 1
	goto_if_eq VAR_RESULT, FALSE, BattleNet_EventScript_ScalingShardForfeit
	giveitem VAR_0x8008
BattleNet_EventScript_ScalingAgain:
	msgbox BattleNet_Text_AnotherMatch, MSGBOX_YESNO
	goto_if_eq VAR_RESULT, YES, BattleNet_EventScript_Scaling
	goto BattleNet_EventScript_TerminalBye
BattleNet_EventScript_ScalingLost:
	msgbox BattleNet_Text_SimBeatYou, MSGBOX_DEFAULT
	goto BattleNet_EventScript_ScalingAgain
BattleNet_EventScript_ScalingShardForfeit:
	msgbox BattleNet_Text_ShardDropForfeited, MSGBOX_DEFAULT
	goto BattleNet_EventScript_ScalingAgain
BattleNet_EventScript_SimCantStart:
	msgbox BattleNet_Text_SimCantStart, MSGBOX_DEFAULT
	releaseall
	end

@ Leader Sim: rerun any gym leader's HARD rematch as a simulation. BP only -- the
@ shard/stone economy stays on the real gym visits (no couch-farming). Gated per
@ region on that region's championship. The 24 per-leader stubs exist because a
@ trainerbattle target is a compile-time constant.
BattleNet_EventScript_LeaderSim::
	setvar VAR_0x8004, BNET_MODE_SCALING
	special CheckBattleNetRuleParty
	goto_if_eq VAR_RESULT, 0, BattleNet_EventScript_SimCantStart
BattleNet_EventScript_LeaderRegion:
	multichoice 0, 0, MULTI_BNET_REGION, FALSE
	switch VAR_RESULT
	case 0, BattleNet_EventScript_LeaderHoenn
	case 1, BattleNet_EventScript_LeaderJohto
	case 2, BattleNet_EventScript_LeaderKanto
	goto BattleNet_EventScript_TerminalBye

BattleNet_EventScript_LeaderHoenn::
	goto_if_unset FLAG_HOENN_CHAMPION, BattleNet_EventScript_LeaderNotChampion
BattleNet_EventScript_LeaderHoenn1:
	multichoice 0, 0, MULTI_BNET_LEADER_H1, FALSE
	switch VAR_RESULT
	case 0, BattleNet_EventScript_SimRoxanne
	case 1, BattleNet_EventScript_SimBrawly
	case 2, BattleNet_EventScript_SimWattson
	case 3, BattleNet_EventScript_SimFlannery
	case 4, BattleNet_EventScript_LeaderHoenn2
	goto BattleNet_EventScript_LeaderRegion
BattleNet_EventScript_LeaderHoenn2:
	multichoice 0, 0, MULTI_BNET_LEADER_H2, FALSE
	switch VAR_RESULT
	case 0, BattleNet_EventScript_SimNorman
	case 1, BattleNet_EventScript_SimWinona
	case 2, BattleNet_EventScript_SimTateLiza
	case 3, BattleNet_EventScript_SimJuan
	case 4, BattleNet_EventScript_LeaderHoenn1
	goto BattleNet_EventScript_LeaderRegion

BattleNet_EventScript_LeaderJohto::
	goto_if_unset FLAG_JOHTO_CHAMPION, BattleNet_EventScript_LeaderNotChampion
BattleNet_EventScript_LeaderJohto1:
	multichoice 0, 0, MULTI_BNET_LEADER_J1, FALSE
	switch VAR_RESULT
	case 0, BattleNet_EventScript_SimFalkner
	case 1, BattleNet_EventScript_SimBugsy
	case 2, BattleNet_EventScript_SimWhitney
	case 3, BattleNet_EventScript_SimMorty
	case 4, BattleNet_EventScript_LeaderJohto2
	goto BattleNet_EventScript_LeaderRegion
BattleNet_EventScript_LeaderJohto2:
	multichoice 0, 0, MULTI_BNET_LEADER_J2, FALSE
	switch VAR_RESULT
	case 0, BattleNet_EventScript_SimChuck
	case 1, BattleNet_EventScript_SimJasmine
	case 2, BattleNet_EventScript_SimPryce
	case 3, BattleNet_EventScript_SimClair
	case 4, BattleNet_EventScript_LeaderJohto1
	goto BattleNet_EventScript_LeaderRegion

BattleNet_EventScript_LeaderKanto::
	goto_if_unset FLAG_KANTO_CHAMPION, BattleNet_EventScript_LeaderNotChampion
BattleNet_EventScript_LeaderKanto1:
	multichoice 0, 0, MULTI_BNET_LEADER_K1, FALSE
	switch VAR_RESULT
	case 0, BattleNet_EventScript_SimBrock
	case 1, BattleNet_EventScript_SimMisty
	case 2, BattleNet_EventScript_SimSurge
	case 3, BattleNet_EventScript_SimErika
	case 4, BattleNet_EventScript_LeaderKanto2
	goto BattleNet_EventScript_LeaderRegion
BattleNet_EventScript_LeaderKanto2:
	multichoice 0, 0, MULTI_BNET_LEADER_K2, FALSE
	switch VAR_RESULT
	case 0, BattleNet_EventScript_SimKoga
	case 1, BattleNet_EventScript_SimBlaine
	case 2, BattleNet_EventScript_SimSabrina
	case 3, BattleNet_EventScript_SimGiovanni
	case 4, BattleNet_EventScript_LeaderKanto1
	goto BattleNet_EventScript_LeaderRegion

BattleNet_EventScript_LeaderNotChampion:
	msgbox BattleNet_Text_LeaderNotChampion, MSGBOX_DEFAULT
	goto BattleNet_EventScript_LeaderRegion

@ Pre-battle setup shared by all 24 stubs. VAR_TEMP_1 holds the difficulty to
@ restore; safe because nothing else runs between setup and SimBattleResult
@ (FLAG_BNET_NO_WHITEOUT keeps a loss from whiting out and reloading the map).
BattleNet_EventScript_SimBattleSetup::
	copyvar VAR_TEMP_1, VAR_DIFFICULTY
	setvar VAR_DIFFICULTY, DIFFICULTY_HARD
	setflag FLAG_BNET_NO_WHITEOUT
	special HealPlayerParty
	return

@ Both win AND loss land here: with FLAG_BNET_NO_WHITEOUT set, a defeat returns to
@ this script instead of whiting out, so the difficulty restore always runs.
BattleNet_EventScript_SimBattleResult::
	copyvar VAR_DIFFICULTY, VAR_TEMP_1
	clearflag FLAG_BNET_NO_WHITEOUT
	special HealPlayerParty
	specialvar VAR_RESULT, GetBattleOutcome
	goto_if_ne VAR_RESULT, B_OUTCOME_WON, BattleNet_EventScript_SimLost
	setvar VAR_0x8005, 2
	special AddBattleNetPoints
	msgbox BattleNet_Text_SimWon, MSGBOX_DEFAULT
	goto BattleNet_EventScript_SimAgain
BattleNet_EventScript_SimLost:
	msgbox BattleNet_Text_SimBeatYou, MSGBOX_DEFAULT
BattleNet_EventScript_SimAgain:
	msgbox BattleNet_Text_AnotherMatch, MSGBOX_YESNO
	goto_if_eq VAR_RESULT, YES, BattleNet_EventScript_LeaderRegion
	goto BattleNet_EventScript_TerminalBye

BattleNet_EventScript_SimRoxanne::
	call BattleNet_EventScript_SimBattleSetup
	trainerbattle_no_intro TRAINER_ROXANNE_1, BattleNet_Text_SimLossQuote
	goto BattleNet_EventScript_SimBattleResult
BattleNet_EventScript_SimBrawly::
	call BattleNet_EventScript_SimBattleSetup
	trainerbattle_no_intro TRAINER_BRAWLY_1, BattleNet_Text_SimLossQuote
	goto BattleNet_EventScript_SimBattleResult
BattleNet_EventScript_SimWattson::
	call BattleNet_EventScript_SimBattleSetup
	trainerbattle_no_intro TRAINER_WATTSON_1, BattleNet_Text_SimLossQuote
	goto BattleNet_EventScript_SimBattleResult
BattleNet_EventScript_SimFlannery::
	call BattleNet_EventScript_SimBattleSetup
	trainerbattle_no_intro TRAINER_FLANNERY_1, BattleNet_Text_SimLossQuote
	goto BattleNet_EventScript_SimBattleResult
BattleNet_EventScript_SimNorman::
	call BattleNet_EventScript_SimBattleSetup
	trainerbattle_no_intro TRAINER_NORMAN_1, BattleNet_Text_SimLossQuote
	goto BattleNet_EventScript_SimBattleResult
BattleNet_EventScript_SimWinona::
	call BattleNet_EventScript_SimBattleSetup
	trainerbattle_no_intro TRAINER_WINONA_1, BattleNet_Text_SimLossQuote
	goto BattleNet_EventScript_SimBattleResult
BattleNet_EventScript_SimTateLiza::
	call BattleNet_EventScript_SimBattleSetup
	trainerbattle_no_intro TRAINER_TATE_AND_LIZA_1, BattleNet_Text_SimLossQuote
	goto BattleNet_EventScript_SimBattleResult
BattleNet_EventScript_SimJuan::
	call BattleNet_EventScript_SimBattleSetup
	trainerbattle_no_intro TRAINER_JUAN_1, BattleNet_Text_SimLossQuote
	goto BattleNet_EventScript_SimBattleResult

BattleNet_EventScript_SimFalkner::
	call BattleNet_EventScript_SimBattleSetup
	trainerbattle_no_intro TRAINER_FALKNER_1, BattleNet_Text_SimLossQuote
	goto BattleNet_EventScript_SimBattleResult
BattleNet_EventScript_SimBugsy::
	call BattleNet_EventScript_SimBattleSetup
	trainerbattle_no_intro TRAINER_BUGSY_1, BattleNet_Text_SimLossQuote
	goto BattleNet_EventScript_SimBattleResult
BattleNet_EventScript_SimWhitney::
	call BattleNet_EventScript_SimBattleSetup
	trainerbattle_no_intro TRAINER_WHITNEY_1, BattleNet_Text_SimLossQuote
	goto BattleNet_EventScript_SimBattleResult
BattleNet_EventScript_SimMorty::
	call BattleNet_EventScript_SimBattleSetup
	trainerbattle_no_intro TRAINER_MORTY_1, BattleNet_Text_SimLossQuote
	goto BattleNet_EventScript_SimBattleResult
BattleNet_EventScript_SimChuck::
	call BattleNet_EventScript_SimBattleSetup
	trainerbattle_no_intro TRAINER_CHUCK_1, BattleNet_Text_SimLossQuote
	goto BattleNet_EventScript_SimBattleResult
BattleNet_EventScript_SimJasmine::
	call BattleNet_EventScript_SimBattleSetup
	trainerbattle_no_intro TRAINER_JASMINE_1, BattleNet_Text_SimLossQuote
	goto BattleNet_EventScript_SimBattleResult
BattleNet_EventScript_SimPryce::
	call BattleNet_EventScript_SimBattleSetup
	trainerbattle_no_intro TRAINER_PRYCE_1, BattleNet_Text_SimLossQuote
	goto BattleNet_EventScript_SimBattleResult
BattleNet_EventScript_SimClair::
	call BattleNet_EventScript_SimBattleSetup
	trainerbattle_no_intro TRAINER_CLAIR_1, BattleNet_Text_SimLossQuote
	goto BattleNet_EventScript_SimBattleResult

BattleNet_EventScript_SimBrock::
	call BattleNet_EventScript_SimBattleSetup
	trainerbattle_no_intro TRAINER_LEADER_BROCK, BattleNet_Text_SimLossQuote
	goto BattleNet_EventScript_SimBattleResult
BattleNet_EventScript_SimMisty::
	call BattleNet_EventScript_SimBattleSetup
	trainerbattle_no_intro TRAINER_LEADER_MISTY, BattleNet_Text_SimLossQuote
	goto BattleNet_EventScript_SimBattleResult
BattleNet_EventScript_SimSurge::
	call BattleNet_EventScript_SimBattleSetup
	trainerbattle_no_intro TRAINER_LEADER_LT_SURGE, BattleNet_Text_SimLossQuote
	goto BattleNet_EventScript_SimBattleResult
BattleNet_EventScript_SimErika::
	call BattleNet_EventScript_SimBattleSetup
	trainerbattle_no_intro TRAINER_LEADER_ERIKA, BattleNet_Text_SimLossQuote
	goto BattleNet_EventScript_SimBattleResult
BattleNet_EventScript_SimKoga::
	call BattleNet_EventScript_SimBattleSetup
	trainerbattle_no_intro TRAINER_LEADER_KOGA, BattleNet_Text_SimLossQuote
	goto BattleNet_EventScript_SimBattleResult
BattleNet_EventScript_SimBlaine::
	call BattleNet_EventScript_SimBattleSetup
	trainerbattle_no_intro TRAINER_LEADER_BLAINE, BattleNet_Text_SimLossQuote
	goto BattleNet_EventScript_SimBattleResult
BattleNet_EventScript_SimSabrina::
	call BattleNet_EventScript_SimBattleSetup
	trainerbattle_no_intro TRAINER_LEADER_SABRINA, BattleNet_Text_SimLossQuote
	goto BattleNet_EventScript_SimBattleResult
BattleNet_EventScript_SimGiovanni::
	call BattleNet_EventScript_SimBattleSetup
	trainerbattle_no_intro TRAINER_LEADER_GIOVANNI, BattleNet_Text_SimLossQuote
	goto BattleNet_EventScript_SimBattleResult

@ ---------- P3 texts ----------
BattleNet_Text_TerminalIntro:
	.string "BATTLE NET TERMINAL\p"
	.string "Sim battles pay full EXP. No money\n"
	.string "at stake, party restored after.$"
BattleNet_Text_TerminalBye:
	.string "LOGGING OFF.\n"
	.string "The BATTLE NET thanks you!$"
BattleNet_Text_SimCantStart:
	.string "ERROR: no battle-ready POKéMON\n"
	.string "detected in your party.$"
BattleNet_Text_ScalingWon:
	.string "SIMULATION COMPLETE - you win!\n"
	.string "1 BATTLE POINT awarded.$"
BattleNet_Text_SimBeatYou:
	.string "SIMULATION COMPLETE - the sim\n"
	.string "takes this one. No BP this time.$"
BattleNet_Text_ShardDropForfeited:
	.string "A bonus SHARD popped out, but your\n"
	.string "BAG is full. It was forfeited.$"
BattleNet_Text_AnotherMatch:
	.string "Run another simulation?$"
BattleNet_Text_LeaderNotChampion:
	.string "Only that region's CHAMPION may run\n"
	.string "its LEADER SIMS.$"
BattleNet_Text_SimWon:
	.string "SIMULATION COMPLETE - you win!\n"
	.string "2 BATTLE POINTS awarded.$"
BattleNet_Text_SimLossQuote:
	.string "The simulation flickers off…\p"
	.string "Better luck next run!$"
