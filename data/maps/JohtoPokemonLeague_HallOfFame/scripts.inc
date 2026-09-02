.set LOCALID_HALLOFFAME_LANCE, 1

JohtoPokemonLeague_HallOfFame_MapScripts::
	map_script MAP_SCRIPT_ON_FRAME_TABLE, JohtoPokemonLeague_HallOfFame_OnFrame
	.byte 0

JohtoPokemonLeague_HallOfFame_OnFrame::
	map_script_2 VAR_LEAGUE_STATE, 6, JohtoPokemonLeague_HallOfFame_EventScript_Cutscene
	.2byte 0

JohtoPokemonLeague_HallOfFame_EventScript_Cutscene::
	lock
	goto_if_set FLAG_JOHTO_CHAMPION, JohtoPokemonLeague_HallOfFame_EventScript_CutsceneKantoChamp
	applymovement LOCALID_HALLOFFAME_LANCE, JohtoPokemonLeague_HallOfFame_Movement_LanceEnter
	applymovement OBJ_EVENT_ID_PLAYER, JohtoPokemonLeague_HallOfFame_Movement_PlayerEnter
	waitmovement OBJ_EVENT_ID_PLAYER
	waitmovement LOCALID_HALLOFFAME_LANCE
	msgbox JohtoPokemonLeague_HallOfFame_LanceText, MSGBOX_DEFAULT
	closemessage
	applymovement OBJ_EVENT_ID_PLAYER, Common_Movement_WalkInPlaceFasterUp
	waitmovement 0
	delay 20
	dofieldeffect FLDEFF_HALL_OF_FAME_RECORD
	waitfieldeffect FLDEFF_HALL_OF_FAME_RECORD
	delay 40
	setvar VAR_TEMP_1, 1
	call JohtoPokemonLeague_HallOfFame_EventScript_SetFirstGameClearFlags
	setrespawn HEAL_LOCATION_NEW_BARK_TOWN
	fadescreenspeed FADE_TO_BLACK, 24
	special GameClear
	waitstate
	releaseall
	end

JohtoPokemonLeague_HallOfFame_EventScript_CutsceneKantoChamp::
	applymovement LOCALID_HALLOFFAME_LANCE, JohtoPokemonLeague_HallOfFame_Movement_LanceEnter
	applymovement OBJ_EVENT_ID_PLAYER, JohtoPokemonLeague_HallOfFame_Movement_PlayerEnter
	waitmovement OBJ_EVENT_ID_PLAYER
	waitmovement LOCALID_HALLOFFAME_LANCE
	msgbox JohtoPokemonLeague_HallOfFame_Rematch_LanceText, MSGBOX_DEFAULT
	closemessage
	applymovement OBJ_EVENT_ID_PLAYER, Common_Movement_WalkInPlaceFasterUp
	waitmovement 0
	delay 20
	dofieldeffect FLDEFF_HALL_OF_FAME_RECORD
	waitfieldeffect FLDEFF_HALL_OF_FAME_RECORD
	delay 40
	setvar VAR_TEMP_1, 1
	call JohtoPokemonLeague_HallOfFame_EventScript_SetGameClearFlags
	setrespawn HEAL_LOCATION_NEW_BARK_TOWN
	fadescreenspeed FADE_TO_BLACK, 24
	special GameClear
	waitstate
	releaseall
	end

JohtoPokemonLeague_HallOfFame_EventScript_SetFirstGameClearFlags::
	clearflag FLAG_HIDE_LEAGUE_BLACKBELT
	setflag FLAG_INDIGOJUNCTION_HIDE_SILVER_GUARD
	setflag FLAG_INDIGOJUNCTION_HIDE_KANTO_GUARD
	setflag FLAG_IS_CHAMPION
	setflag FLAG_JOHTO_CHAMPION
	setvar VAR_DIFFICULTY, DIFFICULTY_HARD @ Feature C: Johto gym/E4 rematches go HARD
	setflag FLAG_HIDE_BATTLEFRONTIER_ENGINEER
	setvar VAR_LEAGUE_STATE, 1
	setvar VAR_NEWBARK_TOWN_STATE, 6
	setvar VAR_SSAQUA_STATE, 0
	@ Unchosen beast is VAR_COMPLETED_* = 3 (Theater). Without this, first Johto
	@ clear never writes 4, and the chamber ON_TRANSITION re-hides it every entry.
	call_if_unset FLAG_CAUGHT_LUGIA, JohtoHoF_RespawnLugia
	call_if_unset FLAG_CAUGHT_HO_OH, JohtoHoF_RespawnHoOh
	return

JohtoPokemonLeague_HallOfFame_EventScript_SetGameClearFlags::
	@ Respawns are for UNRESOLVED encounters only - unconditional hide-flag clears made
	@ already-caught statics respawn as farmable duplicates.
	call_if_unset FLAG_CAUGHT_LATIAS_OR_LATIOS, JohtoHoF_RespawnLatis
	@ Embedded Tower uses independent hide flags; Hoenn's defeated flags cannot
	@ decide whether these encounters were caught. Each helper checks the Pokédex.
	call JohtoHoF_RespawnRayquaza
	call JohtoHoF_RespawnGroudon
	call JohtoHoF_RespawnKyogre
	call_if_unset FLAG_FOUGHT_MEWTWO, JohtoHoF_RespawnMewtwo
	clearflag FLAG_HIDE_VERMILION_SNORLAX
	call_if_unset FLAG_CAUGHT_UNION_CAVE_LAPRAS, JohtoHoF_RespawnLapras
	clearflag FLAG_HIDE_SUDOWOODO
	call_if_unset FLAG_FOUGHT_ZAPDOS, JohtoHoF_RespawnZapdos
	call_if_unset FLAG_FOUGHT_ARTICUNO, JohtoHoF_RespawnArticuno
	call_if_unset FLAG_FOUGHT_MOLTRES, JohtoHoF_RespawnMoltres
	clearflag FLAG_ITEM_GS_BALL
	setflag FLAG_HIDE_BATTLEFRONTIER_ENGINEER
	setflag FLAG_IS_KANTO_CHAMPION
	@ Region-merge champion flag. Also set on the rematch branch, or a player who became champion
	@ of another region first would clear Johto via this branch and never record it (breaking
	@ IsNRegionChampion and the 2/3-region hub rewards).
	setflag FLAG_JOHTO_CHAMPION
	setvar VAR_DIFFICULTY, DIFFICULTY_HARD @ Feature C: Johto gym/E4 rematches go HARD
	call_if_unset FLAG_CAUGHT_LUGIA, JohtoHoF_RespawnLugia
	call_if_unset FLAG_CAUGHT_HO_OH, JohtoHoF_RespawnHoOh
	call JohtoPokemonLeague_HallOfFame_EventScript_SpawnRoamers
	@ Sightings 4-8 are deliberately CUT, not pending (issue #102, owner call). Upstream's
	@ states 4-8 live on HGSS-styled Kanto maps; ours are VermilionCity_Frlg, Route14_Frlg,
	@ CeruleanCity_Gym_Frlg and Route25_Frlg, so every LOCALID, coord trigger, movement path
	@ and map.json entry would be new authorship rather than a port - ~500 lines. Suicune is
	@ catchable via the static Route25_Frlg spawn below. Producers stop at 3 on purpose;
	@ do not "fix" the ladder. The static encounter uses caught state (not battle outcome)
	@ so a fainted Suicune is restored here on the next Hall of Fame clear.
	@ Celebi's retry must include players who fainted/fled it, not only successful catchers -
	@ hence the state gate rather than a caught-flag gate. It must still exclude players who
	@ DID catch it, or the shrine Celebi plus this one is two Celebi from one playthrough
	@ (and one per championship after that); FLAG_CAUGHT_CELEBI is checked inside.
	call_if_ge VAR_SUICUNE_ENCOUNTERS, 3, JohtoPokemonLeague_HallOfFame_EventScript_SpawnSuicune
	call_if_ge VAR_AZALEA_TOWN_STATE, 10, JohtoPokemonLeague_HallOfFame_EventScript_SpawnSecondCelebi
	@ DEFEATED-only clears, matching Hoenn's hall_of_fame.inc and this script's own header rule
	@ (respawns are for UNRESOLVED encounters only). FLAG_CAUGHT_MEW / FLAG_BATTLED_DEOXYS are
	@ the caught markers (set on the catch fall-through in their event scripts) — clearing them
	@ here made an already-caught Mew/Deoxys respawn as a farmable duplicate.
	clearflag FLAG_DEFEATED_MEW
	clearflag FLAG_DEFEATED_DEOXYS
	clearflag FLAG_SUMMONED_MTMOON_JIRACHI
	setvar VAR_LEAGUE_STATE, 1
	return

JohtoPokemonLeague_HallOfFame_EventScript_SpawnRoamers::
	@ Respawns are for UNRESOLVED encounters only (this script's header rule), so the beasts
	@ are gated in C rather than here - one special has to decide per species. It re-releases
	@ Entei/Raikou only if that beast is neither still roaming nor already caught, and it adds
	@ to a FREE roamer slot. The old `clearflag FLAG_CAUGHT_*` + `special InitJohtoBeastRoamers`
	@ pair cleared markers nothing ever set, rerolled both beasts on every unlimited E4 rematch
	@ (farmable duplicates with a fresh shiny roll) and deactivated every roamer, destroying an
	@ active Latios/Latias each time (issue #133).
	special RespawnJohtoBeastRoamers
	return

JohtoPokemonLeague_HallOfFame_EventScript_SpawnSuicune::
	getcaughtmon SPECIES_SUICUNE
	goto_if_eq VAR_RESULT, TRUE, Common_EventScript_NopReturn
	clearflag FLAG_FOUGHT_SUICUNE
	clearflag FLAG_HIDE_ROUTE25_SUICUNE
	return

JohtoHoF_RespawnLatis::
	clearflag FLAG_HIDE_LATIOS
	clearflag FLAG_HIDE_LATIAS
	return

JohtoHoF_RespawnRayquaza::
	getcaughtmon SPECIES_RAYQUAZA
	goto_if_eq VAR_RESULT, TRUE, Common_EventScript_NopReturn
	clearflag FLAG_HIDE_RAYQUAZA
	return

JohtoHoF_RespawnGroudon::
	getcaughtmon SPECIES_GROUDON
	goto_if_eq VAR_RESULT, TRUE, Common_EventScript_NopReturn
	clearflag FLAG_HIDE_GROUDON
	return

JohtoHoF_RespawnKyogre::
	getcaughtmon SPECIES_KYOGRE
	goto_if_eq VAR_RESULT, TRUE, Common_EventScript_NopReturn
	clearflag FLAG_HIDE_KYOGRE
	return

JohtoHoF_RespawnMewtwo::
	clearflag FLAG_HIDE_MEWTWO
	return

JohtoHoF_RespawnZapdos::
	clearflag FLAG_HIDE_ZAPDOS
	return

JohtoHoF_RespawnArticuno::
	clearflag FLAG_HIDE_ARTICUNO
	return

JohtoHoF_RespawnMoltres::
	clearflag FLAG_HIDE_MOLTRES
	return

JohtoHoF_RespawnLapras::
	clearflag FLAG_HIDE_UNION_CAVE_LAPRAS
	return

JohtoHoF_RespawnLugia::
	setvar VAR_COMPLETED_LUGIA, 4
	clearflag FLAG_HIDE_LUGIA
	return

JohtoHoF_RespawnHoOh::
	setvar VAR_COMPLETED_HO_OH, 4
	clearflag FLAG_HIDE_HO_OH
	return

JohtoPokemonLeague_HallOfFame_EventScript_SpawnSecondCelebi::
	call_if_unset FLAG_CAUGHT_CELEBI, JohtoHoF_RespawnSecondCelebi
	return

JohtoHoF_RespawnSecondCelebi::
	clearflag FLAG_HIDE_ILEX_FOREST_SECOND_CELEBI
	return

JohtoPokemonLeague_HallOfFame_Movement_LanceEnter:
	walk_up
	walk_up
	walk_up
	walk_up
	walk_up
	walk_up
	walk_up
	walk_right
	face_left
	step_end

JohtoPokemonLeague_HallOfFame_Movement_PlayerEnter:
	walk_up
	walk_up
	walk_up
	walk_up
	walk_up
	walk_up
	walk_up
	walk_up
	face_right
	step_end

JohtoPokemonLeague_HallOfFame_LanceText:
    .string "LANCE: It's been a long time since I\n"
    .string "last came here.\p"
    .string "This is where we honor the LEAGUE\n"
    .string "CHAMPIONS for all eternity.\p"
    .string "Their courageous POKéMON are also\n"
    .string "inducted.\p"
    .string "Here today, we witnessed the rise\n"
    .string "of a new LEAGUE CHAMPION--a\p"
    .string "trainer who feels compassion for,\n"
    .string "and trust toward, all POKéMON.\p"
    .string "A trainer who succeeded through\n"
    .string "perseverance and determination.\p"
    .string "The new LEAGUE CHAMPION who has\n"
    .string "all the makings of greatness!\p"
    .string "{PLAYER}, allow me to register you\n"
    .string "and your partners as CHAMPIONS!$"

JohtoPokemonLeague_HallOfFame_Rematch_LanceText:
    .string "LANCE: I remember, it wasn't long ago\n"
    .string "I stood here, welcoming you as\p"
    .string "the CHAMPION of JOHTO.\p"
    .string "And now, here we are again, in this\n"
    .string "sacred place where we honor the very\p"
    .string "best trainers and their POKéMON.\p"
    .string "Today, you've proven yourself\n"
    .string "JOHTO's true CHAMPION once more,\l"
    .string "besting even my strongest team.\p"
    .string "You've shown remarkable compassion\n"
    .string "and trust in your POKéMON,\l"
    .string "a bond that has carried you to\l"
    .string "victory time and again.\p"
    .string "Your journey, marked by\n"
    .string "perseverance and unwavering\l"
    .string "determination,\l"
    .string "speaks to your true spirit as a\l"
    .string "trainer.\p"
    .string "You have all the makings of a true\n"
    .string "great, perhaps even the greatest.\p"
    .string "{PLAYER}, it is my honor to register\n"
    .string "you, and your trusted partners,\l"
    .string "as champions once again.$"
