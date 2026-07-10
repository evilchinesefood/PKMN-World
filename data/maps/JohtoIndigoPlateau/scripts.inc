JohtoIndigoPlateau_MapScripts::
	map_script MAP_SCRIPT_ON_TRANSITION, JohtoIndigoPlateau_OnTransition
	.byte 0

JohtoIndigoPlateau_OnTransition::
	setflag FLAG_VISITED_INDIGO_PLATEAU
	end

JohtoIndigoPlateau_Sign::
	msgbox JohtoIndigoPlateau_Text_Sign, MSGBOX_SIGN
	end

JohtoIndigoPlateau_Text_Sign:
	.string "INDIGO PLATEAU\p"
	.string "The Ultimate Goal for Trainers!\p"
	.string "POKéMON LEAGUE HQ$"
