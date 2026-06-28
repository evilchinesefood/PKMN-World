.set LOCALID_WALLY_ENTRANCE, 4

JohtoVictoryRoad_1F_MapScripts::
	map_script MAP_SCRIPT_ON_TRANSITION, JohtoVictoryRoad_1F_OnTransition
	map_script MAP_SCRIPT_ON_RESUME, SetTimeEncounters
	.byte 0

JohtoVictoryRoad_1F_OnTransition:
	callnative SetTimeBasedEncounters
	call_if_eq VAR_VICTORY_ROAD_1F_STATE, 1, JohtoVictoryRoad_1F_EventScript_SetEntranceWallyPos1
	call_if_eq VAR_VICTORY_ROAD_1F_STATE, 2, JohtoVictoryRoad_1F_EventScript_SetEntranceWallyPos2
	end

JohtoVictoryRoad_1F_EventScript_SetEntranceWallyPos1::
	setobjectxyperm LOCALID_WALLY_ENTRANCE, 2, 24
	setobjectmovementtype LOCALID_WALLY_ENTRANCE, MOVEMENT_TYPE_FACE_DOWN
	return

JohtoVictoryRoad_1F_EventScript_SetEntranceWallyPos2::
	setobjectxyperm LOCALID_WALLY_ENTRANCE, 3, 24
	setobjectmovementtype LOCALID_WALLY_ENTRANCE, MOVEMENT_TYPE_FACE_DOWN
	return

JohtoVictoryRoad_1F_EventScript_WallyBattleTrigger1::
	lockall
	setvar VAR_0x8008, 1
	addobject LOCALID_WALLY_ENTRANCE
	applymovement LOCALID_WALLY_ENTRANCE, JohtoVictoryRoad_1F_Movement_WallyApproachPlayer1
	waitmovement 0
	goto JohtoVictoryRoad_1F_EventScript_WallyEntranceBattle
	end

JohtoVictoryRoad_1F_EventScript_WallyBattleTrigger2::
	lockall
	setvar VAR_0x8008, 2
	addobject LOCALID_WALLY_ENTRANCE
	applymovement LOCALID_WALLY_ENTRANCE, JohtoVictoryRoad_1F_Movement_WallyApproachPlayer2
	waitmovement 0
	goto JohtoVictoryRoad_1F_EventScript_WallyEntranceBattle
	end

JohtoVictoryRoad_1F_EventScript_WallyEntranceBattle::
	applymovement OBJ_EVENT_ID_PLAYER, Common_Movement_WalkInPlaceFasterDown
	waitmovement 0
	msgbox JohtoVictoryRoad_1F_Text_WallyNotGoingToLoseAnymore, MSGBOX_DEFAULT
	trainerbattle_no_intro TRAINER_WALLY_VR_1, JohtoVictoryRoad_1F_Text_WallyEntranceDefeat
	msgbox JohtoVictoryRoad_1F_Text_WallyPostEntranceBattle, MSGBOX_DEFAULT
	clearflag FLAG_GARBAGEFLAG
	copyobjectxytoperm LOCALID_WALLY_ENTRANCE
	setflag FLAG_DEFEATED_WALLY_VICTORY_ROAD
	copyvar VAR_VICTORY_ROAD_1F_STATE, VAR_0x8008
	releaseall
	end

JohtoVictoryRoad_1F_Movement_WallyApproachPlayer1:
	walk_left
	walk_left
	walk_left
	walk_left
	walk_left
	walk_left
	walk_left
	walk_left
	walk_left
	walk_left
	walk_up
	step_end

JohtoVictoryRoad_1F_Movement_WallyApproachPlayer2:
	walk_left
	walk_left
	walk_left
	walk_left
	walk_left
	walk_left
	walk_left
	walk_left
	walk_left
	walk_up
	step_end

@ This Wally appears near the entrance once his battle is triggered and remains there until the Hall of Fame is entered
JohtoVictoryRoad_1F_EventScript_EntranceWally::
	msgbox JohtoVictoryRoad_1F_Text_WallyPostEntranceBattle, MSGBOX_NPC
	end

@ This Wally appears and remains at the exit after the Hall of Fame is entered
JohtoVictoryRoad_1F_EventScript_ExitWally::
	trainerbattle_single TRAINER_WALLY_VR_2, JohtoVictoryRoad_1F_Text_WallyIntro, JohtoVictoryRoad_1F_Text_WallyDefeat
	specialvar VAR_RESULT, ShouldTryRematchBattle
	goto_if_eq VAR_RESULT, TRUE, JohtoVictoryRoad_1F_EventScript_RematchWally
	msgbox JohtoVictoryRoad_1F_Text_WallyPostBattle, MSGBOX_AUTOCLOSE
	end

JohtoVictoryRoad_1F_EventScript_RematchWally::
	trainerbattle_rematch TRAINER_WALLY_VR_2, JohtoVictoryRoad_1F_Text_WallyIntro, JohtoVictoryRoad_1F_Text_WallyDefeat
	msgbox JohtoVictoryRoad_1F_Text_WallyPostBattle, MSGBOX_AUTOCLOSE
	end

JohtoVictoryRoad_1F_EventScript_Edgar::
	trainerbattle_single TRAINER_EDGAR, JohtoVictoryRoad_1F_Text_EdgarIntro, JohtoVictoryRoad_1F_Text_EdgarDefeat
	msgbox JohtoVictoryRoad_1F_Text_EdgarPostBattle, MSGBOX_AUTOCLOSE
	end

JohtoVictoryRoad_1F_EventScript_Albert::
	trainerbattle_single TRAINER_ALBERT, JohtoVictoryRoad_1F_Text_AlbertIntro, JohtoVictoryRoad_1F_Text_AlbertDefeat
	msgbox JohtoVictoryRoad_1F_Text_AlbertPostBattle, MSGBOX_AUTOCLOSE
	end

JohtoVictoryRoad_1F_EventScript_Hope::
	trainerbattle_single TRAINER_HOPE, JohtoVictoryRoad_1F_Text_HopeIntro, JohtoVictoryRoad_1F_Text_HopeDefeat
	msgbox JohtoVictoryRoad_1F_Text_HopePostBattle, MSGBOX_AUTOCLOSE
	end

JohtoVictoryRoad_1F_EventScript_Quincy::
	trainerbattle_single TRAINER_QUINCY, JohtoVictoryRoad_1F_Text_QuincyIntro, JohtoVictoryRoad_1F_Text_QuincyDefeat
	msgbox JohtoVictoryRoad_1F_Text_QuincyPostBattle, MSGBOX_AUTOCLOSE
	end

JohtoVictoryRoad_1F_EventScript_Katelynn::
	trainerbattle_single TRAINER_KATELYNN, JohtoVictoryRoad_1F_Text_KatelynnIntro, JohtoVictoryRoad_1F_Text_KatelynnDefeat
	msgbox JohtoVictoryRoad_1F_Text_KatelynnPostBattle, MSGBOX_AUTOCLOSE
	end

JohtoVictoryRoad_1F_Text_WallyNotGoingToLoseAnymore:
	.string "WALLY: Hi! {PLAYER}!\p"
	.string "I bet you're surprised to see me here!\p"
	.string "I made it all the way here, and it's\n"
	.string "all thanks to you!\p"
	.string "{PLAYER}, losing to you that time\n"
	.string "made me stronger!\p"
	.string "But I'm not going to lose anymore!\p"
	.string "I'm going to win! For the POKéMON who\n"
	.string "gave me courage and strength!\p"
	.string "Okay… Here I come!$"

JohtoVictoryRoad_1F_Text_WallyEntranceDefeat:
	.string "Wow!\n"
	.string "{PLAYER}, you are strong, after all!$"

JohtoVictoryRoad_1F_Text_WallyPostEntranceBattle:
	.string "WALLY: I couldn't beat you today,\n"
	.string "{PLAYER}, but one of these days, I'll\l"
	.string "catch up to you!$"

JohtoVictoryRoad_1F_Text_WallyIntro:
	.string "WALLY: Hi! {PLAYER}!\p"
	.string "I've gotten stronger since that last\n"
	.string "time! I wanted to show you, {PLAYER}!\p"
	.string "Okay… Here I come!$"

JohtoVictoryRoad_1F_Text_WallyDefeat:
	.string "Wow!\n"
	.string "{PLAYER}, you are strong, after all!$"

JohtoVictoryRoad_1F_Text_WallyPostBattle:
	.string "WALLY: I couldn't beat you this time,\n"
	.string "too… But one of these days, {PLAYER},\l"
	.string "I'm going to catch up to you…\p"
	.string "And challenge the POKéMON LEAGUE!$"

JohtoVictoryRoad_1F_Text_EdgarIntro:
	.string "I've made it this far a couple times,\n"
	.string "but the last stretch is so long…$"

JohtoVictoryRoad_1F_Text_EdgarDefeat:
	.string "My dream ends here again…$"

JohtoVictoryRoad_1F_Text_EdgarPostBattle:
	.string "You've made it this far. Keep the\n"
	.string "momentum going and become the\l"
	.string "CHAMPION! If anyone can, it's you!$"

JohtoVictoryRoad_1F_Text_AlbertIntro:
	.string "I didn't come all this way to lose now.\n"
	.string "That possibility doesn't exist!$"

JohtoVictoryRoad_1F_Text_AlbertDefeat:
	.string "Impossible…\n"
	.string "I lost?$"

JohtoVictoryRoad_1F_Text_AlbertPostBattle:
	.string "I lost here…\p"
	.string "That means I lack the qualifications\n"
	.string "to become the CHAMPION…$"

JohtoVictoryRoad_1F_Text_HopeIntro:
	.string "This seemingly infinite and harsh road\n"
	.string "lives up to its name of VICTORY.$"

JohtoVictoryRoad_1F_Text_HopeDefeat:
	.string "Your battle style is fantastic…$"

JohtoVictoryRoad_1F_Text_HopePostBattle:
	.string "You seem to have the potential for\n"
	.string "becoming the CHAMPION.$"

JohtoVictoryRoad_1F_Text_QuincyIntro:
	.string "What is the VICTORY ROAD?\n"
	.string "I'll tell you if you win!$"

JohtoVictoryRoad_1F_Text_QuincyDefeat:
	.string "Okay!\n"
	.string "Well done!$"

JohtoVictoryRoad_1F_Text_QuincyPostBattle:
	.string "Getting through here safely--that's\n"
	.string "the final test for any TRAINER aiming\l"
	.string "to become the POKéMON CHAMPION.\p"
	.string "That's why it's called the VICTORY\n"
	.string "ROAD.$"

JohtoVictoryRoad_1F_Text_KatelynnIntro:
	.string "I have nothing to say to anyone\n"
	.string "that's come this far. Come on!$"

JohtoVictoryRoad_1F_Text_KatelynnDefeat:
	.string "This is a disgrace…$"

JohtoVictoryRoad_1F_Text_KatelynnPostBattle:
	.string "Humph, go right on ahead.\n"
	.string "See if I care.$"

JohtoVictoryRoad_1F_EventScript_ItemMaxElixir::
	finditem ITEM_MAX_ELIXIR
	end

JohtoVictoryRoad_1F_EventScript_ItemPPUp::
	finditem ITEM_PP_UP
	end
