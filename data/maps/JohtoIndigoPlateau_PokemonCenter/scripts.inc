.set LOCALID_NURSE, 1
.set LOCALID_INDIGOPLATEAU_ABRA, 6

JohtoIndigoPlateau_PokemonCenter_MapScripts::
	map_script MAP_SCRIPT_ON_FRAME_TABLE, JohtoIndigoPlateau_PokemonCenter_OnFrame 
	map_script MAP_SCRIPT_ON_TRANSITION, JohtoIndigoPlateau_Pokecenter_OnTransition
	.byte 0

JohtoIndigoPlateau_PokemonCenter_OnFrame::
	map_script_2 VAR_LEAGUE_STATE, 0, JohtoIndigoPlateau_PokemonCenter_Enter
	map_script_2 VAR_LEAGUE_STATE, 2, JohtoIndigoPlateau_PokemonCenter_Enter
	map_script_2 VAR_LEAGUE_STATE, 3, JohtoIndigoPlateau_PokemonCenter_Enter
	map_script_2 VAR_LEAGUE_STATE, 4, JohtoIndigoPlateau_PokemonCenter_Enter
	map_script_2 VAR_LEAGUE_STATE, 5, JohtoIndigoPlateau_PokemonCenter_Enter
	map_script_2 VAR_LEAGUE_STATE, 6, JohtoIndigoPlateau_PokemonCenter_Enter
	.2byte 0

JohtoIndigoPlateau_PokemonCenter_Enter::
	setflag FLAG_VISITED_INDIGO_PLATEAU
	setvar VAR_LEAGUE_STATE, 1
	end

JohtoIndigoPlateau_Pokecenter_OnTransition::
	setrespawn HEAL_LOCATION_INDIGO_PLATEAU
	end


JohtoIndigoPlateau_EventScript_Cooltrainer::
	msgbox JohtoIndigoPlateau_Text_CooltrainerM, MSGBOX_NPC
	end

JohtoIndigoPlateau_EventScript_BlackBelt::
	msgbox JohtoIndigoPlateau_Text_Blackbelt, MSGBOX_NPC
	end

JohtoIndigoPlateau_EventScript_ShigyNinja::
	msgbox JohtoIndigoPlateau_Text_ShigyNinja, MSGBOX_NPC
	end

JohtoIndigoPlateau_Text_ShigyNinja:
	.string "Congrats on making it here!\p"
	.string "I've seen tons of trainers come\n"
	.string "through here over the years, and\l"
	.string "all of them are wonderfully unique.\p"
	.string "You should be proud of yourself\n"
	.string "for getting this far!\p"
	.string "Now, go get 'em!$"

JohtoIndigoPlateau_Text_Blackbelt:
	.string "The POKéMON LEAGUE is not taking\n"
	.string "new challengers at the moment.\p"
	.string "Please check back later.$"

JohtoIndigoPlateau_Text_CooltrainerM:
    .string "At the POKéMON LEAGUE, you'll get\n"
    .string "tested by the ELITE FOUR.\p"
    .string "You have to beat them all. If you\n"
    .string "lose, you have to start all over!$"

JohtoIndigoPlateau_EventScript_Silver::
	lock
	faceplayer 
	goto_if_set FLAG_DAILY_BEAT_SILVER, JohtoIndigoPlateau_EventScript_SilverBeat
	msgbox JohtoIndigoPlateau_Text_RivalEntrance1, MSGBOX_DEFAULT
	call_if_eq VAR_STARTER_MON, 0, JohtoIndigoPlateau_Silver_Battle_Cyndaquil
	call_if_eq VAR_STARTER_MON, 1, JohtoIndigoPlateau_Silver_Battle_Totodile
	call_if_eq VAR_STARTER_MON, 2, JohtoIndigoPlateau_Silver_Battle_Chikorita
	msgbox JohtoIndigoPlateau_Text_RivalAfter, MSGBOX_DEFAULT
	setflag FLAG_DAILY_BEAT_SILVER
	release
	end

JohtoIndigoPlateau_EventScript_SilverBeat::
	msgbox JohtoIndigoPlateau_Text_RivalAfter, MSGBOX_DEFAULT
	closemessage
	release
	end

JohtoIndigoPlateau_Silver_Battle_Cyndaquil::
	trainerbattle_no_intro TRAINER_RIVAL_CYNDAQUIL_7, JohtoIndigoPlateau_Text_RivalWin
	return

JohtoIndigoPlateau_Silver_Battle_Totodile::
	trainerbattle_no_intro TRAINER_RIVAL_TOTODILE_7, JohtoIndigoPlateau_Text_RivalWin
	return

JohtoIndigoPlateau_Silver_Battle_Chikorita::
	trainerbattle_no_intro TRAINER_RIVAL_CHIKORITA_7, JohtoIndigoPlateau_Text_RivalWin
	return

JohtoIndigoPlateau_Text_RivalEntrance1:
    .string "Hold it.\p"
    .string "You're going to take the POKéMON\n"
    .string "LEAGUE challenge now?\p"
    .string "That's not going to happen.\p"
    .string "My super-well-trained POKéMON\n"
    .string "are going to pound you.\p"
    .string "{PLAYER}!\n"
    .string "I challenge you!$"

JohtoIndigoPlateau_Text_RivalWin:
    .string "…\p"
    .string "OK--I lost…$"

JohtoIndigoPlateau_Text_RivalAfter:
    .string "…Darn… I still can't win…\p"
    .string "I… I have to think more about my\n"
    .string "POKéMON…\p"
    .string "Humph! Try not to lose!$"

JohtoIndigoPlateau_EventScript_Psychic::
	lock
	faceplayer
	msgbox JohtoIndigoPlateau_Text_TeleportGuy1, MSGBOX_YESNO
	goto_if_eq VAR_RESULT, TRUE, JohtoIndigoPlateau_EventScript_PsychicTeleport
	msgbox JohtoIndigoPlateau_Text_TeleportGuyNo, MSGBOX_DEFAULT
	closemessage
	release
	end

JohtoIndigoPlateau_EventScript_PsychicTeleport::
	msgbox JohtoIndigoPlateau_Text_TeleportGuyYes, MSGBOX_DEFAULT
	closemessage
	turnobject OBJ_EVENT_ID_PLAYER, DIR_SOUTH
	playbgm MUS_LITTLEROOT, TRUE
	delay 60
	playmoncry SPECIES_ABRA, CRY_MODE_NORMAL
	applymovement2 LOCALID_INDIGOPLATEAU_ABRA, JohtoIndigoPLateau_Movement_Abra
	waitmovement 0
	fadescreen FADE_TO_WHITE
	warpteleport MAP_NEW_BARK_TOWN, 20, 12
	release
	end
	
JohtoIndigoPLateau_Movement_Abra:
	jump_in_place_right
	jump_in_place_right
	step_end

JohtoIndigoPlateau_EventScript_Abra::
	lock
	faceplayer
	waitse
	playmoncry SPECIES_ABRA, CRY_MODE_NORMAL
	msgbox JohtoIndigoPlateau_Text_Abra, MSGBOX_DEFAULT
	waitmoncry
	release
	end

JohtoIndigoPlateau_Text_TeleportGuy1:
    .string "Ah! You're challenging the ELITE\n"
    .string "FOUR? Are you sure you're ready?\p"
    .string "If you need to train some more,\n"
    .string "my ABRA can help you.\p"
    .string "It can TELEPORT you home.\p"
    .string "Would you like to go home now?$"

JohtoIndigoPlateau_Text_TeleportGuyYes:
    .string "OK, OK. Picture your house in your\n"
    .string "mind…$"

JohtoIndigoPlateau_Text_TeleportGuyNo:
    .string "OK, OK. The best of luck to you!$"

JohtoIndigoPlateau_Text_Abra:
    .string "ABRA: Aabra…$"
