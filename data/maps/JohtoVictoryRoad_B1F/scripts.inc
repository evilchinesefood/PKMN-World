JohtoVictoryRoad_B1F_MapScripts::
	map_script MAP_SCRIPT_ON_RESUME, SetTimeEncounters
	map_script MAP_SCRIPT_ON_TRANSITION, SetTimeEncounters
	.byte 0

JohtoVictoryRoad_B1F_EventScript_Samuel::
	trainerbattle_single TRAINER_SAMUEL, JohtoVictoryRoad_B1F_Text_SamuelIntro, JohtoVictoryRoad_B1F_Text_SamuelDefeat
	msgbox JohtoVictoryRoad_B1F_Text_SamuelPostBattle, MSGBOX_AUTOCLOSE
	end

JohtoVictoryRoad_B1F_EventScript_Shannon::
	trainerbattle_single TRAINER_SHANNON, JohtoVictoryRoad_B1F_Text_ShannonIntro, JohtoVictoryRoad_B1F_Text_ShannonDefeat
	msgbox JohtoVictoryRoad_B1F_Text_ShannonPostBattle, MSGBOX_AUTOCLOSE
	end

JohtoVictoryRoad_B1F_EventScript_Michelle::
	trainerbattle_single TRAINER_MICHELLE, JohtoVictoryRoad_B1F_Text_MichelleIntro, JohtoVictoryRoad_B1F_Text_MichelleDefeat
	msgbox JohtoVictoryRoad_B1F_Text_MichellePostBattle, MSGBOX_AUTOCLOSE
	end

JohtoVictoryRoad_B1F_EventScript_Mitchell::
	trainerbattle_single TRAINER_MITCHELL, JohtoVictoryRoad_B1F_Text_MitchellIntro, JohtoVictoryRoad_B1F_Text_MitchellDefeat
	msgbox JohtoVictoryRoad_B1F_Text_MitchellPostBattle, MSGBOX_AUTOCLOSE
	end

JohtoVictoryRoad_B1F_EventScript_Halle::
	trainerbattle_single TRAINER_PRYCE_1, JohtoVictoryRoad_B1F_Text_HalleIntro, JohtoVictoryRoad_B1F_Text_HalleDefeat
	msgbox JohtoVictoryRoad_B1F_Text_HallePostBattle, MSGBOX_AUTOCLOSE
	end

JohtoVictoryRoad_B1F_Text_SamuelIntro:
	.string "The thought that I'm getting closer to\n"
	.string "the POKéMON LEAGUE…\p"
	.string "I'm getting stage fright…$"

JohtoVictoryRoad_B1F_Text_SamuelDefeat:
	.string "I couldn't do a thing…$"

JohtoVictoryRoad_B1F_Text_SamuelPostBattle:
	.string "The POKéMON LEAGUE became distant\n"
	.string "again… What a letdown…$"

JohtoVictoryRoad_B1F_Text_ShannonIntro:
	.string "To win your way through the POKéMON\n"
	.string "LEAGUE, you need the trust of your\l"
	.string "POKéMON.$"

JohtoVictoryRoad_B1F_Text_ShannonDefeat:
	.string "Your relationship is based on\n"
	.string "solid trust.$"

JohtoVictoryRoad_B1F_Text_ShannonPostBattle:
	.string "By being together all the time, trust\n"
	.string "grows between POKéMON and TRAINERS.$"

JohtoVictoryRoad_B1F_Text_MichelleIntro:
	.string "This isn't the goal. It's only a place\n"
	.string "on the way to the POKéMON LEAGUE.$"

JohtoVictoryRoad_B1F_Text_MichelleDefeat:
	.string "That's the way!$"

JohtoVictoryRoad_B1F_Text_MichellePostBattle:
	.string "You'll do fine, for sure!\n"
	.string "Your POKéMON are all eager to go!$"

JohtoVictoryRoad_B1F_Text_MitchellIntro:
	.string "My POKéMON are cosmically\n"
	.string "awe inspiring!$"

JohtoVictoryRoad_B1F_Text_MitchellDefeat:
	.string "I've never met anyone like you before.$"

JohtoVictoryRoad_B1F_Text_MitchellPostBattle:
	.string "Even outside of battle, I sense\n"
	.string "incredible power emanating from you\l"
	.string "and your POKéMON.$"

JohtoVictoryRoad_B1F_Text_HalleIntro:
	.string "Okay, no need to get your back up!\n"
	.string "Relax, let's take it easy!$"

JohtoVictoryRoad_B1F_Text_HalleDefeat:
	.string "Whoa!\n"
	.string "Wonderful!$"

JohtoVictoryRoad_B1F_Text_HallePostBattle:
	.string "Sure, this is VICTORY ROAD.\p"
	.string "But it's not all that different from\n"
	.string "the path you've taken so far.\p"
	.string "Try to enjoy things the rest of\n"
	.string "the way!$"

JohtoVictoryRoad_B1F_EventScript_ItemTMPsychic::
	finditem ITEM_TM29
	end

JohtoVictoryRoad_B1F_EventScript_ItemFullRestore::
	finditem ITEM_FULL_RESTORE
	end
