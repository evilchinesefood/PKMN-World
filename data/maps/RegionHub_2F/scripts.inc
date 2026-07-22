@ Battle Net flagship floor (issue #5 P2) — the hub's PC 2F. Entered from the RegionHub
@ back-counter console (bg event at (20,12) -> warp anchor (20,13)); exit = stairs tile (1,6).
@ The old (20,9)/(20,10) pair was impassable-but-UNREACHABLE (sealed counter pocket), which made
@ this whole floor dead content — see the reachability note in data/scripts/battle_net.inc.
@ Specials live in src/battle_net.c (P2 section). Gate: IsNRegionChampion(1) at the hub console.
RegionHub_2F_MapScripts::
	.byte 0

@ ---------- Director: free Mega Ring + one starter-line stone, first visit as a champion ----------
BattleNet_EventScript_Director::
	lock
	faceplayer
	goto_if_set FLAG_BNET_DIRECTOR_INTRO, BattleNet_EventScript_DirectorRepeat
	msgbox BattleNet_Text_DirectorIntro, MSGBOX_DEFAULT
	@ The MEGA RING is POCKET_KEY_ITEMS and this is its ONLY source in the ROM, so a silent
	@ giveitem failure would kill Mega Evolution permanently. Check space before giving.
	checkitemspace ITEM_MEGA_RING, 1
	goto_if_eq VAR_RESULT, FALSE, BattleNet_EventScript_DirectorBagFull
	giveitem ITEM_MEGA_RING
	msgbox BattleNet_Text_DirectorStoneOffer, MSGBOX_DEFAULT
	@ Script-level multichoice, NOT a special: a menu opened from a special is asynchronous,
	@ so the script would read VAR_RESULT before the player picked. multichoice blocks.
	multichoice 0, 0, MULTI_BNET_STARTER_STONE, FALSE
	special BattleNetStarterStoneFromChoice  @ VAR_RESULT index -> VAR_0x8008 item, VAR_RESULT 1/0
	goto_if_eq VAR_RESULT, 0, BattleNet_EventScript_DirectorStoneLater
	giveitem VAR_0x8008
	goto_if_eq VAR_RESULT, FALSE, BattleNet_EventScript_DirectorBagFull
	setflag FLAG_BNET_DIRECTOR_INTRO
	msgbox BattleNet_Text_DirectorDone, MSGBOX_DEFAULT
	release
	end
BattleNet_EventScript_DirectorStoneLater::
	msgbox BattleNet_Text_DirectorStoneLater, MSGBOX_DEFAULT
	release
	end
BattleNet_EventScript_DirectorBagFull::
	msgbox BattleNet_Text_DirectorBagFull, MSGBOX_DEFAULT
	release
	end
BattleNet_EventScript_DirectorRepeat::
	@ Self-heal: a save from before the checkitemspace guard above could have had the ring
	@ silently eaten while the intro flag was still set. Re-give it if it is missing.
	checkitem ITEM_MEGA_RING, 1
	goto_if_eq VAR_RESULT, FALSE, BattleNet_EventScript_DirectorRegiveRing
	msgbox BattleNet_Text_DirectorRepeat, MSGBOX_DEFAULT
	release
	end

BattleNet_EventScript_DirectorRegiveRing::
	checkitemspace ITEM_MEGA_RING, 1
	goto_if_eq VAR_RESULT, FALSE, BattleNet_EventScript_DirectorBagFull
	giveitem ITEM_MEGA_RING
	msgbox BattleNet_Text_DirectorRepeat, MSGBOX_DEFAULT
	release
	end

@ ---------- Stone vendor: the 10 non-drop stones for shards (any color mix) ----------
BattleNet_EventScript_StoneVendor::
	lock
	faceplayer
	msgbox BattleNet_Text_VendorIntro, MSGBOX_DEFAULT
@ Two pages: a single 11-row list rendered 22 tile rows tall on a 20-row screen. In each list
@ index 5 is the page toggle and index 6 is EXIT (and MULTI_B_PRESSED = 127 also lands >= 6),
@ so both must be handled HERE -- index 6 is a valid sVendorStones[] index and would silently
@ sell the wrong stone if it reached the special. Page 2 rebases onto indices 5..9.
BattleNet_EventScript_VendorLoop::
	multichoice 0, 0, MULTI_BNET_VENDOR_STONE, FALSE
	goto_if_eq VAR_RESULT, 5, BattleNet_EventScript_VendorPage2
	goto_if_ge VAR_RESULT, 6, BattleNet_EventScript_VendorDone
	goto BattleNet_EventScript_VendorBuy

BattleNet_EventScript_VendorPage2::
	multichoice 0, 0, MULTI_BNET_VENDOR_STONE_2, FALSE
	goto_if_eq VAR_RESULT, 5, BattleNet_EventScript_VendorLoop
	goto_if_ge VAR_RESULT, 6, BattleNet_EventScript_VendorDone
	addvar VAR_RESULT, 5

BattleNet_EventScript_VendorBuy::
	special BattleNetVendorStoneFromChoice  @ index -> VAR_0x8008 item, VAR_0x8009 price, VAR_RESULT 1/0
	goto_if_eq VAR_RESULT, 0, BattleNet_EventScript_VendorDone
	special GetBattleNetShardCount          @ -> VAR_RESULT total shards across the 4 colors
	goto_if_lt VAR_RESULT, VAR_0x8009, BattleNet_EventScript_VendorPoor
	checkitemspace VAR_0x8008, 1
	goto_if_eq VAR_RESULT, FALSE, BattleNet_EventScript_VendorBagFull
	special DeductBattleNetShards           @ removes VAR_0x8009 shards, greedy across colors
	giveitem VAR_0x8008
	msgbox BattleNet_Text_VendorAnother, MSGBOX_YESNO
	goto_if_eq VAR_RESULT, YES, BattleNet_EventScript_VendorLoop
BattleNet_EventScript_VendorDone::
	msgbox BattleNet_Text_VendorBye, MSGBOX_DEFAULT
	release
	end
BattleNet_EventScript_VendorPoor::
	msgbox BattleNet_Text_VendorPoor, MSGBOX_DEFAULT
	release
	end
BattleNet_EventScript_VendorBagFull::
	msgbox BattleNet_Text_VendorBagFull, MSGBOX_DEFAULT
	release
	end

@ ---------- BP clerk: 1 shard = 4 BP, pick the color ----------
BattleNet_EventScript_BpClerk::
	lock
	faceplayer
	msgbox BattleNet_Text_BpClerkIntro, MSGBOX_DEFAULT
BattleNet_EventScript_BpClerkLoop::
	multichoice 0, 0, MULTI_BNET_SHARD_COLOR, FALSE
	special BattleNetShardColorFromChoice   @ index -> VAR_0x8008 shard item, VAR_RESULT 1/0
	goto_if_eq VAR_RESULT, 0, BattleNet_EventScript_BpClerkBye
	@ Check bag space BEFORE spending BP, the same order the stone vendor above uses.
	@ TryBuyBattleNetShard deducts immediately, so a failed giveitem would destroy the payment.
	checkitemspace VAR_0x8008, 1
	goto_if_eq VAR_RESULT, FALSE, BattleNet_EventScript_BpClerkBagFull
	special TryBuyBattleNetShard            @ battlePoints >= 4? deduct 4 -> VAR_RESULT 1, else 0
	goto_if_eq VAR_RESULT, 0, BattleNet_EventScript_BpClerkPoor
	giveitem VAR_0x8008
	msgbox BattleNet_Text_BpClerkAnother, MSGBOX_YESNO
	goto_if_eq VAR_RESULT, YES, BattleNet_EventScript_BpClerkLoop
BattleNet_EventScript_BpClerkBye::
	msgbox BattleNet_Text_BpClerkBye, MSGBOX_DEFAULT
	release
	end
BattleNet_EventScript_BpClerkPoor::
	msgbox BattleNet_Text_BpClerkPoor, MSGBOX_DEFAULT
	release
	end

BattleNet_EventScript_BpClerkBagFull::
	msgbox BattleNet_Text_VendorBagFull, MSGBOX_DEFAULT
	release
	end

@ ---------- Records board ----------
BattleNet_EventScript_RecordsBoard::
	lockall
	special BufferBattleNetRecords          @ STR_VAR_1 = HARD wins, STR_VAR_2 = leaders beaten /39, STR_VAR_3 = stones claimed /30
	msgbox BattleNet_Text_Records, MSGBOX_DEFAULT
	special BufferBattleNetStreak           @ STR_VAR_1 = best Tower Streak
	msgbox BattleNet_Text_Records2, MSGBOX_DEFAULT
	releaseall
	end

@ ---------- Streak attendant (P3): Tower Streak + the three ruleset rooms ----------
@ Sim battles only (Battle Tower type): no exp/money/whiteout, party healed around every
@ round. Streak: up to 7 straight scaling battles vs random types; 1 BP per win paid at
@ the end, +BNET_STREAK_BONUS for a perfect run; best run sits on the records board.
@ Rooms: one battle under a party rule (checked by CheckBattleNetRuleParty), win = 2 BP.
BattleNet_EventScript_StreakAttendant::
	lock
	faceplayer
	msgbox BattleNet_Text_StreakIntro, MSGBOX_DEFAULT
BattleNet_EventScript_StreakMenu:
	multichoice 0, 0, MULTI_BNET_STREAK_MENU, FALSE
	switch VAR_RESULT
	case 0, BattleNet_EventScript_StreakRun
	case 1, BattleNet_EventScript_RoomLv50
	case 2, BattleNet_EventScript_RoomMonotype
	case 3, BattleNet_EventScript_RoomLc
BattleNet_EventScript_StreakBye::
	msgbox BattleNet_Text_StreakByeMsg, MSGBOX_DEFAULT
	release
	end

BattleNet_EventScript_StreakRun::
	msgbox BattleNet_Text_StreakConfirm, MSGBOX_YESNO
	goto_if_eq VAR_RESULT, NO, BattleNet_EventScript_StreakMenu
	setvar VAR_TEMP_2, 0
BattleNet_EventScript_StreakLoop:
	special HealPlayerParty
	setvar VAR_0x8004, BNET_MODE_STREAK
	setvar VAR_0x8005, 0
	special DoBattleNetSimBattle
	goto_if_eq VAR_RESULT, 0, BattleNet_EventScript_StreakCantStart
	waitstate
	specialvar VAR_RESULT, GetBattleOutcome
	goto_if_ne VAR_RESULT, B_OUTCOME_WON, BattleNet_EventScript_StreakOver
	addvar VAR_TEMP_2, 1
	buffernumberstring 0, VAR_TEMP_2
	msgbox BattleNet_Text_StreakWinN, MSGBOX_DEFAULT
	goto_if_ne VAR_TEMP_2, BNET_STREAK_ROUNDS, BattleNet_EventScript_StreakLoop
BattleNet_EventScript_StreakOver:
	special HealPlayerParty
	copyvar VAR_0x8005, VAR_TEMP_2
	special UpdateBattleNetStreak
	special AddBattleNetPoints              @ 1 BP per win (0 wins pays nothing)
	buffernumberstring 0, VAR_TEMP_2
	goto_if_eq VAR_TEMP_2, BNET_STREAK_ROUNDS, BattleNet_EventScript_StreakCleared
	msgbox BattleNet_Text_StreakEnded, MSGBOX_DEFAULT
	goto BattleNet_EventScript_StreakMenu
BattleNet_EventScript_StreakCleared:
	setvar VAR_0x8005, BNET_STREAK_BONUS
	special AddBattleNetPoints
	msgbox BattleNet_Text_StreakPerfect, MSGBOX_DEFAULT
	goto BattleNet_EventScript_StreakMenu
BattleNet_EventScript_StreakCantStart:
	msgbox BattleNet_Text_StreakNoParty, MSGBOX_DEFAULT
	release
	end

BattleNet_EventScript_RoomLv50::
	setvar VAR_0x8004, BNET_MODE_LV50
	setvar VAR_0x8005, 0
	goto BattleNet_EventScript_RoomCommon
BattleNet_EventScript_RoomMonotype::
	call BattleNet_EventScript_PickType
	goto_if_eq VAR_RESULT, 0, BattleNet_EventScript_StreakMenu
	setvar VAR_0x8004, BNET_MODE_MONOTYPE
	goto BattleNet_EventScript_RoomCommon
BattleNet_EventScript_RoomLc::
	setvar VAR_0x8004, BNET_MODE_LC
	setvar VAR_0x8005, 0
BattleNet_EventScript_RoomCommon:
	special CheckBattleNetRuleParty
	goto_if_eq VAR_RESULT, 0, BattleNet_EventScript_RoomRuleFail
	special HealPlayerParty
	special DoBattleNetSimBattle
	goto_if_eq VAR_RESULT, 0, BattleNet_EventScript_StreakCantStart
	waitstate
	special HealPlayerParty
	specialvar VAR_RESULT, GetBattleOutcome
	goto_if_ne VAR_RESULT, B_OUTCOME_WON, BattleNet_EventScript_RoomLost
	setvar VAR_0x8005, 2
	special AddBattleNetPoints
	msgbox BattleNet_Text_RoomWon, MSGBOX_DEFAULT
	goto BattleNet_EventScript_StreakMenu
BattleNet_EventScript_RoomLost:
	msgbox BattleNet_Text_RoomLost, MSGBOX_DEFAULT
	goto BattleNet_EventScript_StreakMenu
BattleNet_EventScript_RoomRuleFail:
	goto_if_eq VAR_0x8004, BNET_MODE_LV50, BattleNet_EventScript_RuleFailLv50
	goto_if_eq VAR_0x8004, BNET_MODE_MONOTYPE, BattleNet_EventScript_RuleFailMono
	msgbox BattleNet_Text_RuleLc, MSGBOX_DEFAULT
	goto BattleNet_EventScript_StreakMenu
BattleNet_EventScript_RuleFailLv50:
	msgbox BattleNet_Text_RuleLv50, MSGBOX_DEFAULT
	goto BattleNet_EventScript_StreakMenu
BattleNet_EventScript_RuleFailMono:
	msgbox BattleNet_Text_RuleMono, MSGBOX_DEFAULT
	goto BattleNet_EventScript_StreakMenu

@ ---------- Sim terminal (P3): Scaling Type Trainer + Leader Sim ----------
BattleNet_EventScript_SimTerminal::
	goto BattleNet_EventScript_TerminalAttendant

@ ---------- Texts ----------
BattleNet_Text_DirectorIntro:
	.string "Welcome to the BATTLE NET!\p"
	.string "This floor's old link hardware now runs\n"
	.string "a battle simulation network.\p"
	.string "A Champion like you deserves the full\n"
	.string "toolkit. Take this MEGA RING!$"
BattleNet_Text_DirectorStoneOffer:
	.string "A ring needs a stone.\p"
	.string "Pick one MEGA STONE for a starter\n"
	.string "POKéMON line - on the house!$"
BattleNet_Text_DirectorDone:
	.string "Shards buy the rest at our vendor.\n"
	.string "Leaders on HARD rematches drop their\l"
	.string "signature stones - go collect them all!$"
BattleNet_Text_DirectorStoneLater:
	.string "Changed your mind? Come back anytime\n"
	.string "for your free starter stone.$"
BattleNet_Text_DirectorBagFull:
	.string "Your BAG is full! Make room and\n"
	.string "come back for your free stone.$"
BattleNet_Text_DirectorRepeat:
	.string "How's the MEGA RING treating you?\p"
	.string "HARD rematch wins pay shards, and\n"
	.string "each leader's first drops a stone.$"
BattleNet_Text_VendorIntro:
	.string "MEGA STONES for SHARDS - any color\n"
	.string "spends the same here.$"
BattleNet_Text_VendorPoor:
	.string "Not enough SHARDS, sorry.\p"
	.string "HARD rematches, the sim terminals,\n"
	.string "and cave corners all pay out.$"
BattleNet_Text_VendorBagFull:
	.string "No BAG space for it!$"
BattleNet_Text_VendorAnother:
	.string "Anything else?$"
BattleNet_Text_VendorBye:
	.string "Go mega-size something!$"
BattleNet_Text_BpClerkIntro:
	.string "I exchange BATTLE POINTS for SHARDS.\n"
	.string "4 BP per SHARD, any color.$"
BattleNet_Text_BpClerkPoor:
	.string "You need at least 4 BP.$"
BattleNet_Text_BpClerkAnother:
	.string "Another SHARD?$"
BattleNet_Text_BpClerkBye:
	.string "Spend them well!$"
BattleNet_Text_Records:
	.string "BATTLE NET RECORDS\p"
	.string "HARD rematch wins: {STR_VAR_1}\n"
	.string "Leaders bested: {STR_VAR_2}/39\l"
	.string "Signature stones claimed: {STR_VAR_3}/30$"
BattleNet_Text_Records2:
	.string "Best TOWER STREAK: {STR_VAR_1}/7$"
BattleNet_Text_StreakIntro:
	.string "Welcome to the deep sims!\p"
	.string "TOWER STREAK chains up to 7 wins.\n"
	.string "The ruleset ROOMS demand a matching\l"
	.string "party and pay 2 BP a win.$"
BattleNet_Text_StreakByeMsg:
	.string "Come test your streak again!$"
BattleNet_Text_StreakConfirm:
	.string "TOWER STREAK: up to 7 sims in a row\n"
	.string "vs random types.\p"
	.string "1 BP per win, +5 BP for a perfect run.\n"
	.string "A loss ends the run. Begin?$"
BattleNet_Text_StreakWinN:
	.string "Win {STR_VAR_1} of 7!$"
BattleNet_Text_StreakEnded:
	.string "Run over - {STR_VAR_1} straight wins.\n"
	.string "1 BP paid per win.$"
BattleNet_Text_StreakPerfect:
	.string "A PERFECT 7!\p"
	.string "7 BP for the wins plus a 5 BP bonus.\n"
	.string "The records board will remember this.$"
BattleNet_Text_StreakNoParty:
	.string "ERROR: no battle-ready POKéMON\n"
	.string "detected in your party.$"
BattleNet_Text_RoomWon:
	.string "RULESET CLEARED - you win!\n"
	.string "2 BATTLE POINTS awarded.$"
BattleNet_Text_RoomLost:
	.string "The room's champion sim holds.\n"
	.string "No BP this time.$"
BattleNet_Text_RuleLv50:
	.string "LV50 ROOM RULE:\n"
	.string "every party POKéMON must be Lv50\l"
	.string "or below.$"
BattleNet_Text_RuleMono:
	.string "MONOTYPE ROOM RULE:\n"
	.string "every party POKéMON must share the\l"
	.string "chosen type.$"
BattleNet_Text_RuleLc:
	.string "LITTLE CUP RULE:\n"
	.string "only Lv5 POKéMON that have not\l"
	.string "evolved but still can.$"
