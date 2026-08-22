@ Local ids are (index in map.json's object_events array) + 1 - this map declares no explicit
@ "local_id" keys, so order is the id. All three were 1 while only Rayquaza existed, which meant
@ the Groudon/Kyogre scripts' `removeobject` would have deleted RAYQUAZA had they ever run
@ (issue #127); they never did, because neither object existed.
.set LOCALID_EMBEDDEDRAYQUAZA, 1
.set LOCALID_EMBEDDEDGROUDON, 2
.set LOCALID_EMBEDDEDKYOGRE, 3

EmbeddedTower_MapScripts::
	map_script MAP_SCRIPT_ON_TRANSITION, EmbeddedTower_OnTransition
	.byte 0

@ All three legendaries here are POST-GAME REMATCH content. The only thing in the tree that
@ clears FLAG_HIDE_RAYQUAZA/GROUDON/KYOGRE is SetGameClearFlags at the Johto Hall of Fame,
@ and that runs on the REMATCH branch only - a first clear takes SetFirstGameClearFlags,
@ which leaves them alone. So "hidden until you beat the league a second time" is the
@ intended gate.
@
@ It was not being enforced. Flags default clear, new_game.c did not register these three
@ (it does now), and this map had no map script at all - so they stood here from the first
@ minute of a fresh save, fightable at level 70 as soon as Route 47 is surfable. Every other
@ legendary map gates its spawn in ON_TRANSITION: CeruleanCave_B1F, PowerPlant,
@ SeafoamIslands_B4F and Route25_Frlg all do exactly this.
@
@ This guard only ever SETS. It cannot resurrect a legendary the player already took, because
@ the tower's own resolution marker IS the hide flag; and it cannot grant one early, because
@ nothing here clears. Post-championship it stops running, leaving the Hall of Fame's clears
@ to stand. Note these are the TOWER's own flags - Hoenn's copies use
@ FLAG_HIDE_SKY_PILLAR_TOP_RAYQUAZA / _TERRA_CAVE_GROUDON / _MARINE_CAVE_KYOGRE, so Sky
@ Pillar, Terra Cave and Marine Cave are untouched by this.
EmbeddedTower_OnTransition::
	call_if_unset FLAG_JOHTO_CHAMPION, EmbeddedTower_EventScript_SealLegendaries
	end

EmbeddedTower_EventScript_SealLegendaries::
	setflag FLAG_HIDE_RAYQUAZA
	setflag FLAG_HIDE_GROUDON
	setflag FLAG_HIDE_KYOGRE
	return

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
