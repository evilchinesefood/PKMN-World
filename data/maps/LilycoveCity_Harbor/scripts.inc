LilycoveCity_Harbor_MapScripts::
	map_script MAP_SCRIPT_ON_TRANSITION, LilycoveCity_Harbor_OnTransition
	.byte 0

LilycoveCity_Harbor_OnTransition:
	setescapewarp MAP_LILYCOVE_CITY, 12, 33
	goto LilycoveCity_Harbor_EventScript_ClaimHoennRegion

@ Lane-R (issue #65): this harbor is the HOENN way home from every event-ticket island
@ (SOUTHERN / BIRTH / FARAWAY / NAVEL ROCK), and those islands are now bookable from the
@ OLIVINE harbor as well as this one - so arriving here can be a Johto -> mainland-Hoenn
@ crossing. (It was described here as the SINGLE way home until issue #69; that was already
@ untrue when it was written - the shared return script had had an OLIVINE arm since #65 - and
@ it was the half of a contradiction whose other half sat on that script, claiming NAVEL ROCK
@ was excluded from it. All four islands now route through
@ Common_EventScript_FerrySailHomeFromIsland, which picks this harbor for a HOENN-booked trip.)
@ src/region_switch.c's INVARIANT requires every cross-region entry to set the
@ active region, or a Johto champion carries JOHTO's HARD VAR_DIFFICULTY tier into first-run
@ Hoenn gyms (the leak the Battle Frontier dock ferry already fixes on its own legs). Claiming
@ it at the ARRIVAL map covers all five routes at once, including any added later.
@
@ The "already Hoenn" guard is load-bearing: RegionHub_ScrSetCurrentRegion also re-arms the
@ whiteout respawn at the region's START TOWN, and for a Hoenn player walking in off the
@ Lilycove seafront this is not a crossing at all - their respawn must not jump to LITTLEROOT.
LilycoveCity_Harbor_EventScript_ClaimHoennRegion:
	setvar VAR_0x8008, 2 @ 2 = REGION_HOENN
	callnative RegionHub_ScrTargetIsCurrent
	goto_if_eq VAR_RESULT, TRUE, LilycoveCity_Harbor_EventScript_RegionUnchanged
	setvar VAR_RESULT, 2
	callnative RegionHub_ScrSetCurrentRegion
LilycoveCity_Harbor_EventScript_RegionUnchanged:
	end

LilycoveCity_Harbor_EventScript_FerryAttendant::
	lock
	faceplayer
	goto_if_unset FLAG_HOENN_CHAMPION, LilycoveCity_Harbor_EventScript_FerryUnavailable
	call LilycoveCity_Harbor_EventScript_GetEonTicketState
	call LilycoveCity_Harbor_EventScript_GetAuroraTicketState
	call LilycoveCity_Harbor_EventScript_GetOldSeaMapState
	call LilycoveCity_Harbor_EventScript_GetMysticTicketState
	call LilycoveCity_Harbor_EventScript_GetFirstTimeShowingTicket
	call LilycoveCity_Harbor_EventScript_GetHasTicketsState
	goto_if_eq VAR_TEMP_C, 2, LilycoveCity_Harbor_EventScript_OldSeaMapFirstTime
	goto_if_eq VAR_TEMP_B, 1, LilycoveCity_Harbor_EventScript_EonTicketFirstTime
	goto_if_eq VAR_TEMP_B, 2, LilycoveCity_Harbor_EventScript_AuroraTicketFirstTime
	goto_if_eq VAR_TEMP_B, 4, LilycoveCity_Harbor_EventScript_OldSeaMapFirstTime
	goto_if_eq VAR_TEMP_B, 8, LilycoveCity_Harbor_EventScript_MysticTicketFirstTime
	goto_if_ne VAR_TEMP_B, 0, LilycoveCity_Harbor_EventScript_MultipleEventTicketsFirstTime
	goto LilycoveCity_Harbor_EventScript_NoFirstTimeEventTickets
	end

@ First goto_if_eq is unnecessary; identical scripts
LilycoveCity_Harbor_EventScript_NoFirstTimeEventTickets::
	goto_if_eq VAR_TEMP_A, 0, LilycoveCity_Harbor_EventScript_NoEventTickets
	msgbox LilycoveCity_Harbor_Text_MayISeeYourTicket, MSGBOX_DEFAULT
	message LilycoveCity_Harbor_Text_FlashTicketWhereTo
	waitmessage
	goto LilycoveCity_Harbor_EventScript_FerryRegularLocationSelect
	end

LilycoveCity_Harbor_EventScript_FerryRegularLocationSelect::
	setvar VAR_0x8004, 0
	special ScriptMenu_CreateLilycoveSSTidalMultichoice
	special GetLilycoveSSTidalSelection
	switch VAR_RESULT
	case 0, LilycoveCity_Harbor_EventScript_GoToSlateport
	case 1, LilycoveCity_Harbor_EventScript_GoToBattleFrontier
	case 2, LilycoveCity_Harbor_EventScript_GoToSouthernIsland
	case 3, LilycoveCity_Harbor_EventScript_GoToNavelRock
	case 4, LilycoveCity_Harbor_EventScript_GoToBirthIsland
	case 5, LilycoveCity_Harbor_EventScript_GoToFarawayIsland
	case 6, LilycoveCity_Harbor_EventScript_ExitSailSelect
	case MULTI_B_PRESSED, LilycoveCity_Harbor_EventScript_ExitSailSelect
	end

LilycoveCity_Harbor_EventScript_GoToSouthernIsland::
	call LilycoveCity_Harbor_EventScript_BoardFerry
	warp MAP_SOUTHERN_ISLAND_EXTERIOR, 13, 22
	waitstate
	release
	end

LilycoveCity_Harbor_EventScript_GoToNavelRock::
	call LilycoveCity_Harbor_EventScript_BoardFerry
	warp MAP_NAVEL_ROCK_HARBOR, 8, 4
	waitstate
	release
	end

LilycoveCity_Harbor_EventScript_GoToBirthIsland::
	call LilycoveCity_Harbor_EventScript_BoardFerry
	warp MAP_BIRTH_ISLAND_HARBOR, 8, 4
	waitstate
	release
	end

LilycoveCity_Harbor_EventScript_GoToFarawayIsland::
	call LilycoveCity_Harbor_EventScript_BoardFerry
	warp MAP_FARAWAY_ISLAND_ENTRANCE, 13, 38
	waitstate
	release
	end

LilycoveCity_Harbor_EventScript_GoToSlateport::
	msgbox LilycoveCity_Harbor_Text_SlateportItIs, MSGBOX_YESNO
	goto_if_eq VAR_RESULT, NO, LilycoveCity_Harbor_EventScript_FerryDestinationChangeMind
	setvar VAR_SS_TIDAL_STATE, SS_TIDAL_BOARD_LILYCOVE
	call LilycoveCity_Harbor_EventScript_BoardFerry
	warp MAP_SS_TIDAL_CORRIDOR, 1, 10
	waitstate
	release
	end

LilycoveCity_Harbor_EventScript_GoToBattleFrontier::
	msgbox LilycoveCity_Harbor_Text_BattleFrontierItIs, MSGBOX_YESNO
	goto_if_eq VAR_RESULT, NO, LilycoveCity_Harbor_EventScript_FerryDestinationChangeMind
	call LilycoveCity_Harbor_EventScript_BoardFerry
	warp MAP_BATTLE_FRONTIER_OUTSIDE_WEST, 19, 67
	waitstate
	release
	end

LilycoveCity_Harbor_EventScript_GetEonTicketState::
	setvar VAR_TEMP_E, 0
	goto_if_unset FLAG_ENABLE_SHIP_SOUTHERN_ISLAND, Common_EventScript_NopReturn
	checkitem ITEM_EON_TICKET
	goto_if_eq VAR_RESULT, FALSE, Common_EventScript_NopReturn
	setvar VAR_TEMP_E, 1
	goto_if_set FLAG_SHOWN_EON_TICKET, Common_EventScript_NopReturn
	setvar VAR_TEMP_E, 2
	return

LilycoveCity_Harbor_EventScript_GetAuroraTicketState::
	setvar VAR_TEMP_D, 0
	goto_if_unset FLAG_ENABLE_SHIP_BIRTH_ISLAND, Common_EventScript_NopReturn
	checkitem ITEM_AURORA_TICKET
	goto_if_eq VAR_RESULT, FALSE, Common_EventScript_NopReturn
	setvar VAR_TEMP_D, 1
	goto_if_set FLAG_SHOWN_AURORA_TICKET, Common_EventScript_NopReturn
	setvar VAR_TEMP_D, 2
	return

LilycoveCity_Harbor_EventScript_GetOldSeaMapState::
	setvar VAR_TEMP_C, 0
	goto_if_unset FLAG_ENABLE_SHIP_FARAWAY_ISLAND, Common_EventScript_NopReturn
	checkitem ITEM_OLD_SEA_MAP
	goto_if_eq VAR_RESULT, FALSE, Common_EventScript_NopReturn
	setvar VAR_TEMP_C, 1
	goto_if_set FLAG_SHOWN_OLD_SEA_MAP, Common_EventScript_NopReturn
	setvar VAR_TEMP_C, 2
	return

LilycoveCity_Harbor_EventScript_GetMysticTicketState::
	setvar VAR_TEMP_9, 0
	goto_if_unset FLAG_ENABLE_SHIP_NAVEL_ROCK, Common_EventScript_NopReturn
	checkitem ITEM_MYSTIC_TICKET
	goto_if_eq VAR_RESULT, FALSE, Common_EventScript_NopReturn
	setvar VAR_TEMP_9, 1
	goto_if_set FLAG_SHOWN_MYSTIC_TICKET, Common_EventScript_NopReturn
	setvar VAR_TEMP_9, 2
	return

LilycoveCity_Harbor_EventScript_GetFirstTimeShowingTicket::
	setvar VAR_TEMP_B, 0
	call_if_eq VAR_TEMP_E, 2, LilycoveCity_Harbor_EventScript_SetFirstTimeShowingEonTicket
	call_if_eq VAR_TEMP_D, 2, LilycoveCity_Harbor_EventScript_SetFirstTimeShowingAuroraTicket
	call_if_eq VAR_TEMP_C, 2, LilycoveCity_Harbor_EventScript_SetFirstTimeShowingOldSeaMap
	call_if_eq VAR_TEMP_9, 2, LilycoveCity_Harbor_EventScript_SetFirstTimeShowingMysticTicket
	return

LilycoveCity_Harbor_EventScript_SetFirstTimeShowingEonTicket::
	addvar VAR_TEMP_B, 1
	return

LilycoveCity_Harbor_EventScript_SetFirstTimeShowingAuroraTicket::
	addvar VAR_TEMP_B, 2
	return

LilycoveCity_Harbor_EventScript_SetFirstTimeShowingOldSeaMap::
	addvar VAR_TEMP_B, 4
	return

LilycoveCity_Harbor_EventScript_SetFirstTimeShowingMysticTicket::
	addvar VAR_TEMP_B, 8
	return

LilycoveCity_Harbor_EventScript_GetHasTicketsState::
	setvar VAR_TEMP_A, 0
	call_if_eq VAR_TEMP_E, 1, LilycoveCity_Harbor_EventScript_SetHasEonTicket
	call_if_eq VAR_TEMP_D, 1, LilycoveCity_Harbor_EventScript_SetHasAuroraTicket
	call_if_eq VAR_TEMP_C, 1, LilycoveCity_Harbor_EventScript_SetHasOldSeaMap
	call_if_eq VAR_TEMP_9, 1, LilycoveCity_Harbor_EventScript_SetHasMysticTicket
	return

LilycoveCity_Harbor_EventScript_SetHasEonTicket::
	addvar VAR_TEMP_A, 1
	return

LilycoveCity_Harbor_EventScript_SetHasAuroraTicket::
	addvar VAR_TEMP_A, 2
	return

LilycoveCity_Harbor_EventScript_SetHasOldSeaMap::
	addvar VAR_TEMP_A, 4
	return

LilycoveCity_Harbor_EventScript_SetHasMysticTicket::
	addvar VAR_TEMP_A, 8
	return

LilycoveCity_Harbor_EventScript_EonTicketFirstTime::
	setflag FLAG_SHOWN_EON_TICKET
	msgbox EventTicket_Text_ThatPass, MSGBOX_DEFAULT
	closemessage
	call LilycoveCity_Harbor_EventScript_GetEventTicketSailor
	msgbox EventTicket_Text_ShowEonTicket, MSGBOX_DEFAULT
	goto LilycoveCity_Harbor_EventScript_GoToSouthernIslandFirstTime
	end

LilycoveCity_Harbor_EventScript_GoToSouthernIslandFirstTime::
	closemessage
	call LilycoveCity_Harbor_EventScript_BoardFerryWithSailor
	warp MAP_SOUTHERN_ISLAND_EXTERIOR, 13, 22
	waitstate
	release
	end

LilycoveCity_Harbor_EventScript_AuroraTicketFirstTime::
	setflag FLAG_SHOWN_AURORA_TICKET
	msgbox EventTicket_Text_ThatPass, MSGBOX_DEFAULT
	closemessage
	call LilycoveCity_Harbor_EventScript_GetEventTicketSailor
	msgbox EventTicket_Text_OddTicketGetOnBoard, MSGBOX_DEFAULT
	goto LilycoveCity_Harbor_EventScript_GoToBirthIslandFirstTime
	end

LilycoveCity_Harbor_EventScript_GoToBirthIslandFirstTime::
	closemessage
	call LilycoveCity_Harbor_EventScript_BoardFerryWithSailor
	warp MAP_BIRTH_ISLAND_HARBOR, 8, 4
	waitstate
	release
	end

@ Issue #80, site 3 of 3, and the one that is easy to miss: this row boards INLINE with Briney's
@ cutscene and calls NEITHER LilycoveCity_Harbor_EventScript_BoardFerry NOR ...WithSailor - it
@ runs its own applymovements and goes straight to Common_EventScript_FerryDepart below. Patching
@ only the two named helpers would leave the OLD SEA MAP's first FARAWAY ISLAND trip with no
@ departure record, and that trip's sailor home is the exact script this record is for.
LilycoveCity_Harbor_EventScript_OldSeaMapFirstTime::
	setvar VAR_FERRY_DEPARTURE, FERRY_DEPART_LILYCOVE
	setflag FLAG_SHOWN_OLD_SEA_MAP
	msgbox EventTicket_Text_ShowOldSeaMap, MSGBOX_DEFAULT
	closemessage
	call LilycoveCity_Harbor_EventScript_GetEventTicketSailor
	msgbox EventTicket_Text_OldSeaMapTooFar, MSGBOX_DEFAULT
	closemessage
	applymovement LOCALID_LILYCOVE_HARBOR_FERRY_SAILOR, Common_Movement_WalkInPlaceFasterUp
	waitmovement 0
	playse SE_PIN
	applymovement LOCALID_LILYCOVE_HARBOR_FERRY_SAILOR, Common_Movement_ExclamationMark
	waitmovement 0
	applymovement LOCALID_LILYCOVE_HARBOR_FERRY_SAILOR, Common_Movement_Delay48
	waitmovement 0
	call_if_eq VAR_FACING, DIR_NORTH, LilycoveCity_Harbor_EventScript_MoveSailorOutOfWayNorth
	call_if_eq VAR_FACING, DIR_EAST, LilycoveCity_Harbor_EventScript_MoveSailorOutOfWayEast
	addobject LOCALID_LILYCOVE_HARBOR_BRINEY
	call_if_eq VAR_FACING, DIR_NORTH, LilycoveCity_Harbor_EventScript_BrineyFaceSailorNorth
	call_if_eq VAR_FACING, DIR_EAST, LilycoveCity_Harbor_EventScript_BrineyFaceSailorEast
	msgbox EventTicket_Text_BrineyHoldOnASecond, MSGBOX_DEFAULT
	call_if_eq VAR_FACING, DIR_NORTH, LilycoveCity_Harbor_EventScript_BrineyFacePlayerNorth
	call_if_eq VAR_FACING, DIR_EAST, LilycoveCity_Harbor_EventScript_BrineyFacePlayerEast
	msgbox EventTicket_Text_BrineyLetsSail, MSGBOX_DEFAULT
	closemessage
	call_if_eq VAR_FACING, DIR_NORTH, LilycoveCity_Harbor_EventScript_BoardFerryWithBrineyAndSailorNorth
	call_if_eq VAR_FACING, DIR_EAST, LilycoveCity_Harbor_EventScript_BoardFerryWithBrineyAndSailorEast
	setvar VAR_0x8004, LOCALID_LILYCOVE_HARBOR_SS_TIDAL
	call Common_EventScript_FerryDepart
	warp MAP_FARAWAY_ISLAND_ENTRANCE, 13, 38
	waitstate
	release
	end

LilycoveCity_Harbor_EventScript_GoToFarawayIslandFirstTime::
	closemessage
	call LilycoveCity_Harbor_EventScript_BoardFerryWithSailor
	warp MAP_FARAWAY_ISLAND_ENTRANCE, 13, 38
	waitstate
	release
	end

LilycoveCity_Harbor_EventScript_MysticTicketFirstTime::
	setflag FLAG_SHOWN_MYSTIC_TICKET
	msgbox EventTicket_Text_ThatPass, MSGBOX_DEFAULT
	closemessage
	call LilycoveCity_Harbor_EventScript_GetEventTicketSailor
	msgbox EventTicket_Text_OddTicketGetOnBoard, MSGBOX_DEFAULT
	goto LilycoveCity_Harbor_EventScript_GoToNavelRockFirstTime
	end

LilycoveCity_Harbor_EventScript_GoToNavelRockFirstTime::
	closemessage
	call LilycoveCity_Harbor_EventScript_BoardFerryWithSailor
	warp MAP_NAVEL_ROCK_HARBOR, 8, 4
	waitstate
	release
	end

LilycoveCity_Harbor_EventScript_MultipleEventTicketsFirstTime::
	msgbox EventTicket_Text_ThatPass, MSGBOX_DEFAULT
	closemessage
	call LilycoveCity_Harbor_EventScript_GetEventTicketSailor
	message EventTicket_Text_OddTicketsWhereTo
	waitmessage
	setvar VAR_0x8004, 1
	special ScriptMenu_CreateLilycoveSSTidalMultichoice
	special GetLilycoveSSTidalSelection
	switch VAR_RESULT
	case 2, LilycoveCity_Harbor_EventScript_GoToSouthernIslandFirstTime
	case 3, LilycoveCity_Harbor_EventScript_GoToNavelRockFirstTime
	case 4, LilycoveCity_Harbor_EventScript_GoToBirthIslandFirstTime
	case 5, LilycoveCity_Harbor_EventScript_GoToFarawayIslandFirstTime
	case 6, LilycoveCity_Harbor_EventScript_ExitFirstTimeTicketSailSelect
	case MULTI_B_PRESSED, LilycoveCity_Harbor_EventScript_ExitFirstTimeTicketSailSelect
	release
	end

LilycoveCity_Harbor_EventScript_ExitFirstTimeTicketSailSelect::
	msgbox EventTicket_Text_AsYouLike, MSGBOX_DEFAULT
	closemessage
	applymovement LOCALID_LILYCOVE_HARBOR_FERRY_SAILOR, Common_Movement_WalkInPlaceFasterUp
	waitmovement 0
	delay 30
	removeobject LOCALID_LILYCOVE_HARBOR_FERRY_SAILOR
	delay 30
	applymovement LOCALID_LILYCOVE_HARBOR_ATTENDANT, Common_Movement_WalkInPlaceFasterDown
	waitmovement 0
	showobjectat LOCALID_LILYCOVE_HARBOR_ATTENDANT, MAP_LILYCOVE_CITY_HARBOR
	delay 30
	msgbox LilycoveCity_Harbor_Text_SailAnotherTime, MSGBOX_DEFAULT
	release
	end

LilycoveCity_Harbor_EventScript_GetEventTicketSailor::
	applymovement VAR_LAST_TALKED, Common_Movement_WalkInPlaceFasterUp
	waitmovement 0
	delay 30
	hideobjectat VAR_LAST_TALKED, MAP_LILYCOVE_CITY_HARBOR
	delay 60
	addobject LOCALID_LILYCOVE_HARBOR_FERRY_SAILOR
	delay 30
	applymovement LOCALID_LILYCOVE_HARBOR_FERRY_SAILOR, Common_Movement_FacePlayer
	waitmovement 0
	return

@ Issue #80, site 2 of 3: the FIRST-TIME boarding path, taken once per event ticket while the
@ ticket sailor is on the dock. It is a separate helper from BoardFerry above rather than a
@ wrapper around it, so the record has to be written here too - GoToSouthernIslandFirstTime,
@ GoToBirthIslandFirstTime, GoToFarawayIslandFirstTime and GoToNavelRockFirstTime all reach the
@ islands through this and only this.
LilycoveCity_Harbor_EventScript_BoardFerryWithSailor::
	setvar VAR_FERRY_DEPARTURE, FERRY_DEPART_LILYCOVE
	applymovement LOCALID_LILYCOVE_HARBOR_FERRY_SAILOR, Common_Movement_WalkInPlaceFasterUp
	waitmovement 0
	delay 30
	removeobject LOCALID_LILYCOVE_HARBOR_FERRY_SAILOR
	call_if_eq VAR_FACING, DIR_NORTH, LilycoveCity_Harbor_EventScript_PlayerBoardFerryNorth
	call_if_eq VAR_FACING, DIR_EAST, LilycoveCity_Harbor_EventScript_PlayerBoardFerryEast
	delay 30
	hideplayer
	setvar VAR_0x8004, LOCALID_LILYCOVE_HARBOR_SS_TIDAL
	call Common_EventScript_FerryDepart
	return

LilycoveCity_Harbor_EventScript_FerryUnavailable::
	msgbox LilycoveCity_Harbor_Text_FerryUnavailable, MSGBOX_DEFAULT
	release
	end

LilycoveCity_Harbor_EventScript_NoEventTickets::
	msgbox LilycoveCity_Harbor_Text_MayISeeYourTicket, MSGBOX_DEFAULT
	message LilycoveCity_Harbor_Text_FlashTicketWhereTo
	waitmessage
	goto LilycoveCity_Harbor_EventScript_FerryRegularLocationSelect
	end

@ Unused
LilycoveCity_Harbor_EventScript_NoTicket::
	msgbox LilycoveCity_Harbor_Text_NoTicket, MSGBOX_DEFAULT
	release
	end

@ Unused
LilycoveCity_Harbor_EventScript_GoToSlateportUnused::
	msgbox LilycoveCity_Harbor_Text_SlateportItIs, MSGBOX_YESNO
	goto_if_eq VAR_RESULT, NO, LilycoveCity_Harbor_EventScript_FerryDestinationChangeMind
	setvar VAR_SS_TIDAL_STATE, SS_TIDAL_BOARD_LILYCOVE
	call LilycoveCity_Harbor_EventScript_BoardFerry
	warp MAP_SS_TIDAL_CORRIDOR, 1, 10
	waitstate
	release
	end

@ Unused
LilycoveCity_Harbor_EventScript_GoToBattleFrontierUnused::
	msgbox LilycoveCity_Harbor_Text_BattleFrontierItIs, MSGBOX_YESNO
	goto_if_eq VAR_RESULT, NO, LilycoveCity_Harbor_EventScript_FerryDestinationChangeMind
	call LilycoveCity_Harbor_EventScript_BoardFerry
	warp MAP_BATTLE_FRONTIER_OUTSIDE_WEST, 19, 67
	waitstate
	release
	end

LilycoveCity_Harbor_EventScript_FerryDestinationChangeMind::
	message LilycoveCity_Harbor_Text_WhereWouldYouLikeToGo
	waitmessage
	goto LilycoveCity_Harbor_EventScript_FerryRegularLocationSelect
	end

@ Issue #80, site 1 of 3 in this file: the departure record. This helper is the REPEAT-visit
@ boarding path and carries all four island destinations (SOUTHERN / NAVEL ROCK / BIRTH /
@ FARAWAY) plus SLATEPORT and the BATTLE FRONTIER, so one setvar covers every row of the regular
@ menu. The two non-island rows record a departure nothing reads back; see the note on
@ Common_EventScript_FerrySailHomeFromIsland (data/event_scripts.s) for why that is harmless and
@ why the active region could not serve as this record.
LilycoveCity_Harbor_EventScript_BoardFerry::
	setvar VAR_FERRY_DEPARTURE, FERRY_DEPART_LILYCOVE
	msgbox LilycoveCity_Harbor_Text_PleaseBoard, MSGBOX_DEFAULT
	closemessage
	applymovement VAR_LAST_TALKED, Common_Movement_WalkInPlaceFasterUp
	waitmovement 0
	delay 30
	hideobjectat VAR_LAST_TALKED, MAP_LILYCOVE_CITY_HARBOR
	call_if_eq VAR_FACING, DIR_NORTH, LilycoveCity_Harbor_EventScript_PlayerBoardFerryNorth
	call_if_eq VAR_FACING, DIR_EAST, LilycoveCity_Harbor_EventScript_PlayerBoardFerryEast
	delay 30
	hideplayer
	setvar VAR_0x8004, LOCALID_LILYCOVE_HARBOR_SS_TIDAL
	call Common_EventScript_FerryDepart
	return

LilycoveCity_Harbor_EventScript_PlayerBoardFerryEast::
	applymovement LOCALID_PLAYER, LilycoveCity_Harbor_Movement_PlayerBoardFerryEast
	waitmovement 0
	return

LilycoveCity_Harbor_EventScript_PlayerBoardFerryNorth::
	applymovement LOCALID_PLAYER, LilycoveCity_Harbor_Movement_PlayerBoardFerryNorth
	waitmovement 0
	return

LilycoveCity_Harbor_EventScript_ExitSailSelect::
	msgbox LilycoveCity_Harbor_Text_SailAnotherTime, MSGBOX_DEFAULT
	release
	end

LilycoveCity_Harbor_Movement_PlayerBoardFerryEast:
	walk_right
	walk_in_place_faster_up
	step_end

LilycoveCity_Harbor_Movement_PlayerBoardFerryNorth:
	walk_up
	step_end

LilycoveCity_Harbor_Movement_UnusedBoardFerry:
	walk_up
	step_end

LilycoveCity_Harbor_EventScript_Sailor::
	lock
	faceplayer
	goto_if_set FLAG_HOENN_CHAMPION, LilycoveCity_Harbor_EventScript_SailorFerryAvailable
	msgbox LilycoveCity_Harbor_Text_SailorFerryUnavailable, MSGBOX_DEFAULT
	release
	end

LilycoveCity_Harbor_EventScript_SailorFerryAvailable::
	msgbox LilycoveCity_Harbor_Text_SailorFerryAvailable, MSGBOX_DEFAULT
	release
	end

LilycoveCity_Harbor_EventScript_MoveSailorOutOfWayNorth::
	applymovement LOCALID_LILYCOVE_HARBOR_FERRY_SAILOR, LilycoveCity_Harbor_Movement_SailorOutOfWayNorth
	waitmovement 0
	return

LilycoveCity_Harbor_EventScript_MoveSailorOutOfWayEast::
	applymovement LOCALID_LILYCOVE_HARBOR_FERRY_SAILOR, LilycoveCity_Harbor_Movement_SailorOutOfWayEast
	waitmovement 0
	return

LilycoveCity_Harbor_Movement_SailorOutOfWayNorth:
	walk_in_place_faster_right
	lock_facing_direction
	walk_left
	unlock_facing_direction
	step_end

LilycoveCity_Harbor_Movement_SailorOutOfWayEast:
	lock_facing_direction
	walk_down
	unlock_facing_direction
	step_end

LilycoveCity_Harbor_EventScript_BrineyFaceSailorNorth::
	applymovement LOCALID_LILYCOVE_HARBOR_BRINEY, Common_Movement_WalkInPlaceFasterLeft
	waitmovement 0
	return

LilycoveCity_Harbor_EventScript_BrineyFaceSailorEast::
	applymovement LOCALID_LILYCOVE_HARBOR_BRINEY, Common_Movement_WalkInPlaceFasterDown
	waitmovement 0
	return

LilycoveCity_Harbor_EventScript_BrineyFacePlayerNorth::
	applymovement LOCALID_LILYCOVE_HARBOR_BRINEY, Common_Movement_WalkInPlaceFasterDown
	waitmovement 0
	return

LilycoveCity_Harbor_EventScript_BrineyFacePlayerEast::
	applymovement LOCALID_LILYCOVE_HARBOR_BRINEY, Common_Movement_WalkInPlaceFasterLeft
	waitmovement 0
	return

LilycoveCity_Harbor_EventScript_BoardFerryWithBrineyAndSailorNorth::
	applymovement LOCALID_LILYCOVE_HARBOR_BRINEY, LilycoveCity_Harbor_Movement_BrineyBoardFerry
	applymovement LOCALID_PLAYER, LilycoveCity_Harbor_Movement_PlayerBoardWithBrineyNorth
	applymovement LOCALID_LILYCOVE_HARBOR_FERRY_SAILOR, LilycoveCity_Harbor_Movement_SailorBoardWithBrineyNorth
	waitmovement 0
	return

LilycoveCity_Harbor_EventScript_BoardFerryWithBrineyAndSailorEast::
	applymovement LOCALID_LILYCOVE_HARBOR_BRINEY, LilycoveCity_Harbor_Movement_BrineyBoardFerry
	applymovement LOCALID_PLAYER, LilycoveCity_Harbor_Movement_PlayerBoardWithBrineyEast
	applymovement LOCALID_LILYCOVE_HARBOR_FERRY_SAILOR, LilycoveCity_Harbor_Movement_SailorBoardWithBrineyEast
	waitmovement 0
	return

LilycoveCity_Harbor_Movement_BrineyBoardFerry:
	walk_in_place_faster_up
	delay_8
	set_invisible
	step_end

LilycoveCity_Harbor_Movement_PlayerBoardWithBrineyNorth:
	delay_16
	walk_up
	delay_16
	set_invisible
	step_end

LilycoveCity_Harbor_Movement_SailorBoardWithBrineyNorth:
	delay_16
	delay_16
	delay_16
	walk_right
	walk_in_place_faster_up
	delay_16
	set_invisible
	step_end

LilycoveCity_Harbor_Movement_PlayerBoardWithBrineyEast:
	delay_16
	walk_right
	walk_in_place_faster_up
	delay_16
	set_invisible
	step_end

LilycoveCity_Harbor_Movement_SailorBoardWithBrineyEast:
	delay_16
	delay_16
	delay_16
	walk_up
	delay_16
	set_invisible
	step_end

LilycoveCity_Harbor_Text_FerryUnavailable:
	.string "I beg your pardon?\n"
	.string "You're looking for a ship?\p"
	.string "I'm sorry, the ferry service isn't\n"
	.string "available at present…$"

LilycoveCity_Harbor_Text_MayISeeYourTicket:
	.string "Hello, are you here for the ferry?\n"
	.string "May I see your TICKET?$"

LilycoveCity_Harbor_Text_NoTicket:
	.string "{PLAYER} doesn't have the TICKET…\p"
	.string "I'm terribly sorry.\p"
	.string "You must have a TICKET to board\n"
	.string "the ferry.$"

LilycoveCity_Harbor_Text_FlashTicketWhereTo:
	.string "{PLAYER} flashed the TICKET.\p"
	.string "Perfect! That's all you need!\p"
	.string "And where would you like to go?$"

LilycoveCity_Harbor_Text_SailAnotherTime:
	.string "Please sail with us another time!$"

LilycoveCity_Harbor_Text_SlateportItIs:
	.string "SLATEPORT CITY it is, then!$"

LilycoveCity_Harbor_Text_BattleFrontierItIs:
	.string "BATTLE FRONTIER it is, then!$"

LilycoveCity_Harbor_Text_PleaseBoard:
	.string "Please board the ferry and wait for\n"
	.string "departure.$"

LilycoveCity_Harbor_Text_WhereWouldYouLikeToGo:
	.string "Then, where would you like to go?$"

LilycoveCity_Harbor_Text_SailorFerryUnavailable:
	.string "Until they finish making the ferry,\n"
	.string "we sailors have nothing to do…\p"
	.string "I wish they'd get a move on, the folks\n"
	.string "at the SHIPYARD in SLATEPORT.$"

LilycoveCity_Harbor_Text_SailorFerryAvailable:
	.string "The ferry S.S. TIDAL is finally in\n"
	.string "operation.\p"
	.string "The folks at the SHIPYARD in SLATEPORT\n"
	.string "must've worked extra hard.\p"
	.string "Well, it's my turn to get busy now!$"
