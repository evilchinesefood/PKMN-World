@ Region merge (Lane-R, issue #65): KANTO's S.S.AQUA terminal - the other end of the Olivine
@ crossing. Same interior as OLIVINE CITY's port (HG/SS builds both ferry terminals from one
@ tileset), so the layout is a copy of LAYOUT_OLIVINE_CITY_PORT_INSIDE: a one-tile berth
@ corridor at x=8 running y=15..17 up into the hall (y=10..14) and out the north door at (8,9).
@
@ The door is the ONLY city-side link and it is one-way: VERMILION CITY is an FRLG map whose
@ harbour is the Seagallop pier, and there is no port-building doorway metatile on it to warp
@ back in through. So departures from KANTO are booked at the pier itself
@ (VermilionCity_EventScript_FerrySailor), and this hall's own sailor covers a passenger who
@ wants to turn straight around without leaving the terminal.
@
@ The two desks are deliberately NOT presented alike. In here there is a berth, a gangway and a
@ boat sprite, so the sailor runs the full walk-aboard cutscene (a mirror of Olivine's). Out on
@ the pier there is no ship object to board, so that desk is a plain warp hop — the same shape
@ as the WORLD TRANSIT ferry offered by the very same sailor one line above it.

VermilionCity_PortInside_MapScripts::
	map_script MAP_SCRIPT_ON_FRAME_TABLE, VermilionCity_PortInside_OnFrame
	.byte 0

@ VAR_SSAQUA_STATE 6 = "the S.S.AQUA has docked in VERMILION and the player has stepped off".
@ SSAqua_1F_EventScript_LeaveBoat warps here with the var still at 6, so this fires exactly
@ once - on the maiden voyage's arrival - and advances it to 7. 7 is the permanent
@ "has crossed to KANTO" state that opens OlivinePort_EventScript_Sailor_AfterKanto's
@ destination menu; every later crossing is a direct ferry hop and skips this scene.
@ The 5 row is belt-and-braces, and the two gates are why. The door sailor admits >= 5
@ (SSAqua_1F/scripts.inc), but map_script_2 is an EXACT match — so a disembark at 5 would land
@ here, never fire this scene, never reach 7, and shut BOTH >= 7 gates (the Olivine board and
@ the Vermilion pier's return offer) for good. It cannot happen today: 5 is only written in
@ SSAqua_RoomSSE, and every route back to the door sailor crosses SSAqua_1F, whose own ON_FRAME
@ bumps 5 -> 6 first. Covering it here means the two gates can be changed independently.
VermilionCity_PortInside_OnFrame::
	map_script_2 VAR_SSAQUA_STATE, 5, VermilionCity_PortInside_EventScript_Arrived
	map_script_2 VAR_SSAQUA_STATE, 6, VermilionCity_PortInside_EventScript_Arrived
	.2byte 0

VermilionCity_PortInside_EventScript_Arrived::
	lockall
	delay 20
	applymovement OBJ_EVENT_ID_PLAYER, VermilionPort_Movement_StepAshore
	waitmovement 0
	playse SE_DING_DONG
	msgbox VermilionPort_Text_ArrivedInVermilion, MSGBOX_DEFAULT
	closemessage
	setvar VAR_SSAQUA_STATE, 7
	releaseall
	end

VermilionPort_EventScript_Sailor::
	lock
	faceplayer
	msgbox VermilionPort_Text_AskBoardForOlivine, MSGBOX_YESNO
	goto_if_eq VAR_RESULT, NO, VermilionPort_EventScript_ComeAgain
	call VermilionPort_EventScript_EnterShip
	call VermilionPort_EventScript_EnterJohtoRegion
	warpsilent MAP_OLIVINE_CITY_PORT_INSIDE, 8, 9
	waitstate
	release
	end

VermilionPort_EventScript_ComeAgain::
	msgbox VermilionPort_Text_ComeAgain, MSGBOX_DEFAULT
	closemessage
	release
	end

@ Cross-region arrival (src/region_switch.c INVARIANT): the S.S.AQUA is normal in-world travel,
@ not a hub gate, so it sets the active region WITHOUT boxing the party - HG/SS treats Johto
@ and Kanto as one continuous campaign with one team. Skipping this would carry KANTO's
@ VAR_DIFFICULTY tier into JOHTO. RegionHub_ScrSetCurrentRegion also arms the target region's
@ START-TOWN respawn, so the setrespawn after it re-points the whiteout at the harbour the
@ player actually lands in. Shared with the VERMILION pier sailor
@ (VermilionCity_EventScript_FerryToOlivine), which is the city-side booking desk for this run.
VermilionPort_EventScript_EnterJohtoRegion::
	setvar VAR_RESULT, 1 @ 1 = REGION_JOHTO
	callnative RegionHub_ScrSetCurrentRegion
	setrespawn HEAL_LOCATION_OLIVINE_CITY
	return

@ Mirror of OlivinePort_EventScript_EnterShip: the sailor walks down onto the gangway, the
@ player follows, then the camera object holds the shot while the boat pulls out to the east.
VermilionPort_EventScript_EnterShip::
	msgbox VermilionPort_Text_GetOnBoard, MSGBOX_DEFAULT
	closemessage
	delay 20
	applymovement LOCALID_VERMILION_PORT_SAILOR, VermilionPort_Movement_SailorEnterBoat
	waitmovement 0
	playse SE_EXIT
	applymovement OBJ_EVENT_ID_PLAYER, VermilionPort_Movement_PlayerEnterBoat
	waitmovement 0
	special SpawnCameraObject
	playse SE_EXIT
	removeobject OBJ_EVENT_ID_PLAYER
	delay 60
	applymovement LOCALID_VERMILION_PORT_SAILOR, VermilionPort_Movement_BoatLeave
	applymovement LOCALID_VERMILION_PORT_BOAT, VermilionPort_Movement_BoatLeave
	waitmovement LOCALID_VERMILION_PORT_BOAT
	return

VermilionPort_EventScript_DockWorker::
	msgbox VermilionPort_Text_DockWorker, MSGBOX_NPC
	end

VermilionPort_EventScript_Traveller::
	msgbox VermilionPort_Text_Traveller, MSGBOX_NPC
	end

VermilionPort_Movement_StepAshore:
	walk_up
	step_end

VermilionPort_Movement_SailorEnterBoat:
	walk_down
	walk_down
	step_end

VermilionPort_Movement_PlayerEnterBoat:
	walk_down
	walk_down
	walk_in_place_down
	step_end

VermilionPort_Movement_BoatLeave:
	walk_right
	walk_right
	walk_right
	walk_right
	walk_right
	step_end

VermilionPort_Text_ArrivedInVermilion:
	.string "FAST SHIP S.S.AQUA has arrived in\n"
	.string "VERMILION CITY.\p"
	.string "We hope you enjoyed the voyage.\n"
	.string "Please watch your step!$"

VermilionPort_Text_AskBoardForOlivine:
	.string "FAST SHIP S.S.AQUA sails for\n"
	.string "OLIVINE CITY.\p"
	.string "Will you be boarding today?$"

VermilionPort_Text_GetOnBoard:
	.string "We're departing soon.\n"
	.string "Please get on board.$"

VermilionPort_Text_ComeAgain:
	.string "We hope to see you again!$"

VermilionPort_Text_DockWorker:
	.string "The S.S.AQUA runs between here and\n"
	.string "OLIVINE CITY in JOHTO.\p"
	.string "She skims the waves on jets, so the\n"
	.string "crossing is over in no time!$"

VermilionPort_Text_Traveller:
	.string "I'm off to JOHTO to see the\n"
	.string "TIN TOWER in ECRUTEAK CITY.\p"
	.string "They say a rainbow POKéMON nested\n"
	.string "on it, long ago…$"
