.set LOCALID_MTSILVER_MOLTRES, 1

MtSilver_1F_MoltresRoom_MapScripts::
	map_script MAP_SCRIPT_ON_TRANSITION, MtSilver_1F_MoltresRoom_OnTransition
	map_script MAP_SCRIPT_ON_RESUME, SetTimeEncounters
	.byte 0

MtSilver_1F_MoltresRoom_OnTransition: 
	callnative SetTimeBasedEncounters
	end


MtSilver_1F_MoltresRoom_EventScript_Moltres::
	lock
	faceplayer
	playmoncry SPECIES_MOLTRES, CRY_MODE_ENCOUNTER
	msgbox MtSilver_1F_MoltresRoom_Text_Moltres
	delay 40
	waitmoncry
	seteventmon SPECIES_MOLTRES, 50
	special BattleSetup_StartLegendaryBattle
	waitstate
	specialvar VAR_RESULT, GetBattleOutcome
	goto_if_eq VAR_RESULT, B_OUTCOME_RAN, MtSilver_1F_MoltresRoom_EventScript_MoltresRan
	fadescreenswapbuffers FADE_TO_BLACK
	removeobject LOCALID_MTSILVER_MOLTRES
	setflag FLAG_HIDE_MOLTRES
	setflag FLAG_FOUGHT_MOLTRES @ shared with Mt Ember - without it the other site re-shows a duplicate
	fadescreenswapbuffers FADE_FROM_BLACK
	release
	end

MtSilver_1F_MoltresRoom_EventScript_MoltresRan::
	release
	end

@ Region merge (Johto port): HnS pointed this msgbox at the FRLG Seafoam Articuno
@ encounter text, whose symbol the target lacks (FRLG Seafoam maps are *_Frlg here).
@ Local Moltres screech keeps the legendary encounter intact.
MtSilver_1F_MoltresRoom_Text_Moltres:
	.string "GYAOOOOO!$"
