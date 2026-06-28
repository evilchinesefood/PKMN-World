JohtoVictoryRoad_B2F_MapScripts::
	map_script MAP_SCRIPT_ON_RESUME, JohtoVictoryRoad_B2F_OnResume
	map_script MAP_SCRIPT_ON_TRANSITION, JohtoVictoryRoad_B2F_OnTransition
	.byte 0

JohtoVictoryRoad_B2F_OnResume:
	callnative SetTimeBasedEncounters
	end

JohtoVictoryRoad_B2F_OnTransition:
	callnative SetTimeBasedEncounters
	goto_if_set FLAG_UNLOCK_BIRDS, JohtoVictoryRoad_B2F_SwitchToModern
	end

JohtoVictoryRoad_B2F_SwitchToModern::
	setmaplayoutindex LAYOUT_JOHTO_VICTORY_ROAD_B2F
	end

JohtoVictoryRoad_B2F_EventScript_Vito::
	trainerbattle_single TRAINER_VITO, JohtoVictoryRoad_B2F_Text_VitoIntro, JohtoVictoryRoad_B2F_Text_VitoDefeat
	msgbox JohtoVictoryRoad_B2F_Text_VitoPostBattle, MSGBOX_AUTOCLOSE
	end

JohtoVictoryRoad_B2F_EventScript_Owen::
	trainerbattle_single TRAINER_OWEN, JohtoVictoryRoad_B2F_Text_OwenIntro, JohtoVictoryRoad_B2F_Text_OwenDefeat
	msgbox JohtoVictoryRoad_B2F_Text_OwenPostBattle, MSGBOX_AUTOCLOSE
	end

JohtoVictoryRoad_B2F_EventScript_Caroline::
	trainerbattle_single TRAINER_CAROLINE, JohtoVictoryRoad_B2F_Text_CarolineIntro, JohtoVictoryRoad_B2F_Text_CarolineDefeat
	msgbox JohtoVictoryRoad_B2F_Text_CarolinePostBattle, MSGBOX_AUTOCLOSE
	end

JohtoVictoryRoad_B2F_EventScript_Julie::
	trainerbattle_single TRAINER_JULIE, JohtoVictoryRoad_B2F_Text_JulieIntro, JohtoVictoryRoad_B2F_Text_JulieDefeat
	msgbox JohtoVictoryRoad_B2F_Text_JuliePostBattle, MSGBOX_AUTOCLOSE
	end

JohtoVictoryRoad_B2F_EventScript_Felix::
	trainerbattle_single TRAINER_NORMAN, JohtoVictoryRoad_B2F_Text_FelixIntro, JohtoVictoryRoad_B2F_Text_FelixDefeat
	msgbox JohtoVictoryRoad_B2F_Text_FelixPostBattle, MSGBOX_AUTOCLOSE
	end

JohtoVictoryRoad_B2F_EventScript_Dianne::
	trainerbattle_single TRAINER_KENJI, JohtoVictoryRoad_B2F_Text_DianneIntro, JohtoVictoryRoad_B2F_Text_DianneDefeat
	msgbox JohtoVictoryRoad_B2F_Text_DiannePostBattle, MSGBOX_AUTOCLOSE
	end

JohtoVictoryRoad_B2F_Text_VitoIntro:
	.string "I trained together with my whole family,\n"
	.string "every one of us!\l"
	.string "I'm not losing to anyone!$"

JohtoVictoryRoad_B2F_Text_VitoDefeat:
	.string "Better than my family?!\n"
	.string "Is that possible?!$"

JohtoVictoryRoad_B2F_Text_VitoPostBattle:
	.string "I was better than everyone in my\n"
	.string "family. I've never lost before…\p"
	.string "I've lost my confidence…\n"
	.string "Maybe I'll go home…$"

JohtoVictoryRoad_B2F_Text_OwenIntro:
	.string "I'd heard that there was a tough\n"
	.string "little kid around. Do they mean you?$"

JohtoVictoryRoad_B2F_Text_OwenDefeat:
	.string "The little shrimp is tough!$"

JohtoVictoryRoad_B2F_Text_OwenPostBattle:
	.string "The rumors I heard, that tough little\n"
	.string "kid is from PETALBURG CITY.$"

JohtoVictoryRoad_B2F_Text_CarolineIntro:
	.string "You must be getting a little tired.$"

JohtoVictoryRoad_B2F_Text_CarolineDefeat:
	.string "No signs of tiring at all!$"

JohtoVictoryRoad_B2F_Text_CarolinePostBattle:
	.string "VICTORY ROAD and the POKéMON LEAGUE\n"
	.string "are long and grueling challenges.\l"
	.string "Beware of fatigue!$"

JohtoVictoryRoad_B2F_Text_JulieIntro:
	.string "You shouldn't get complacent just\n"
	.string "because you have a lot of GYM BADGES.\p"
	.string "There's always going to be someone\n"
	.string "who's better than you!$"

JohtoVictoryRoad_B2F_Text_JulieDefeat:
	.string "You're better than me!$"

JohtoVictoryRoad_B2F_Text_JuliePostBattle:
	.string "Gaze on your collected BADGES and\n"
	.string "remember the TRAINERS you've faced.$"

JohtoVictoryRoad_B2F_Text_FelixIntro:
	.string "I've come this far, but the tension's\n"
	.string "giving me awful stomach pain…$"

JohtoVictoryRoad_B2F_Text_FelixDefeat:
	.string "Ooh…\n"
	.string "It hurts…$"

JohtoVictoryRoad_B2F_Text_FelixPostBattle:
	.string "I can't help getting all tense knowing\n"
	.string "that I'm nearing the POKéMON LEAGUE.\p"
	.string "It's all I can do to feign calm.$"

JohtoVictoryRoad_B2F_Text_DianneIntro:
	.string "The elite among the elite gather in\n"
	.string "this cave.\p"
	.string "How are you finding it?$"

JohtoVictoryRoad_B2F_Text_DianneDefeat:
	.string "Not rattled in the least bit!$"

JohtoVictoryRoad_B2F_Text_DiannePostBattle:
	.string "You do have guts! I like that!\n"
	.string "Keep it going!$"

JohtoVictoryRoad_B2F_EventScript_ItemFullHeal::
	finditem ITEM_FULL_HEAL
	end
