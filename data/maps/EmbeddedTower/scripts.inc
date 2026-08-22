@ Local ids are (index in map.json's object_events array) + 1 - this map declares no explicit
@ "local_id" keys, so order is the id. All three were 1 while only Rayquaza existed, which meant
@ the Groudon/Kyogre scripts' `removeobject` would have deleted RAYQUAZA had they ever run
@ (issue #127); they never did, because neither object existed.
.set LOCALID_EMBEDDEDRAYQUAZA, 1
.set LOCALID_EMBEDDEDGROUDON, 2
.set LOCALID_EMBEDDEDKYOGRE, 3

EmbeddedTower_MapScripts::
	.byte 0

EmbeddedTower_EventScript_Groudon::
	lock
	faceplayer
	playmoncry SPECIES_GROUDON, CRY_MODE_ENCOUNTER
	waitmoncry
	seteventmon SPECIES_GROUDON, 70
	special BattleSetup_StartLegendaryBattle
waitstate
	specialvar VAR_RESULT, GetBattleOutcome
	goto_if_eq VAR_RESULT, B_OUTCOME_RAN, EmbeddedTower_EventScript_GroudonRan
	@ Dig/Teleport out of a legendary battle reports PLAYER_TELEPORTED, not RAN. Without this
	@ guard the fall-through removes the object and sets the hide flag, deleting the encounter
	@ for good. Matches SkyPillar_Top / TerraCave_End / MarineCave_End.
	goto_if_eq VAR_RESULT, B_OUTCOME_PLAYER_TELEPORTED, EmbeddedTower_EventScript_GroudonRan
	fadescreenswapbuffers FADE_TO_BLACK
	removeobject LOCALID_EMBEDDEDGROUDON
	setflag FLAG_HIDE_GROUDON
	fadescreenswapbuffers FADE_FROM_BLACK
	release
	end

EmbeddedTower_EventScript_GroudonRan::
	release
	end

EmbeddedTower_EventScript_Kyogre::
	lock
	faceplayer
	playmoncry SPECIES_KYOGRE, CRY_MODE_ENCOUNTER
	waitmoncry
	seteventmon SPECIES_KYOGRE, 70
	special BattleSetup_StartLegendaryBattle
waitstate
	specialvar VAR_RESULT, GetBattleOutcome
	goto_if_eq VAR_RESULT, B_OUTCOME_RAN, EmbeddedTower_EventScript_KyogreRan
	goto_if_eq VAR_RESULT, B_OUTCOME_PLAYER_TELEPORTED, EmbeddedTower_EventScript_KyogreRan
	fadescreenswapbuffers FADE_TO_BLACK
	removeobject LOCALID_EMBEDDEDKYOGRE
	setflag FLAG_HIDE_KYOGRE
	fadescreenswapbuffers FADE_FROM_BLACK
	release
	end

EmbeddedTower_EventScript_KyogreRan::
	release
	end


EmbeddedTower_EventScript_Rayquaza::
	lock
	faceplayer
	playmoncry SPECIES_RAYQUAZA, CRY_MODE_ENCOUNTER
	waitmoncry
	seteventmon SPECIES_RAYQUAZA, 70
	special BattleSetup_StartLegendaryBattle
waitstate
	specialvar VAR_RESULT, GetBattleOutcome
	goto_if_eq VAR_RESULT, B_OUTCOME_RAN, EmbeddedTower_EventScript_RayquazaRan
	goto_if_eq VAR_RESULT, B_OUTCOME_PLAYER_TELEPORTED, EmbeddedTower_EventScript_RayquazaRan
	fadescreenswapbuffers FADE_TO_BLACK
	removeobject LOCALID_EMBEDDEDRAYQUAZA
	setflag FLAG_HIDE_RAYQUAZA
	fadescreenswapbuffers FADE_FROM_BLACK
	release
	end

EmbeddedTower_EventScript_RayquazaRan::
	release
	end
