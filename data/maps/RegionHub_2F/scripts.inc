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
	releaseall
	end

@ ---------- Streak attendant (P3 fills the battle flow; P2 ships a teaser) ----------
BattleNet_EventScript_StreakAttendant::
	msgbox BattleNet_Text_StreakSoon, MSGBOX_NPC
	end

@ ---------- Sim terminal (P3 fills Scaling Type Trainer + Leader Sim; P2 ships a teaser) ----------
BattleNet_EventScript_SimTerminal::
	msgbox BattleNet_Text_SimSoon, MSGBOX_NPC
	end

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
BattleNet_Text_StreakSoon:
	.string "The STREAK and RULESET sim pods are\n"
	.string "still calibrating. Check back soon!$"
BattleNet_Text_SimSoon:
	.string "The TYPE TRAINER and LEADER SIM pods\n"
	.string "are still calibrating. Check back soon!$"
