@ Region merge (Lane-R, issue #65): KANTO's S.S.AQUA terminal - the other end of the Olivine
@ crossing. Same interior as OLIVINE CITY's port (HG/SS builds both ferry terminals from one
@ tileset), so the layout is a copy of LAYOUT_OLIVINE_CITY_PORT_INSIDE: a one-tile berth
@ corridor at x=8 running y=15..17 up into the hall (y=10..14) and out the north door at (8,9).
@
@ Issue #68 made that door two-way. It was arrival-only when this map shipped: VERMILION CITY is
@ an FRLG map whose harbour is the Seagallop pier, and there was no port-building doorway
@ metatile placed on it to warp back in through — warp 10 over there was an inert arrival anchor
@ sitting on an ordinary walkable plank, so everyone in this hall was one visit long. #68 built
@ the terminal onto the pier's north edge (data/layouts/VermilionCity_Frlg/map.bin, x=25..28
@ y=26..29 — the standard Vermilion house block, with METATILE_VermilionCity_Door at (26,29))
@ and re-pointed warp 10 at that door. Walking out lands on the apron at (26,30); walking north
@ into the door comes back here.
@
@ That is why this hall's sailor is now the ONLY S.S.AQUA departure desk in Kanto. The return
@ leg used to be duplicated onto the pier sailor (VermilionCity_EventScript_FerrySailor) purely
@ so it stayed reachable, and the two desks could not present alike: in here there is a berth, a
@ gangway and a boat sprite, so the sailor runs the full walk-aboard cutscene (a mirror of
@ Olivine's), while out on the pier there was no ship object to board and the same voyage was a
@ silent warp hop. The pier sailor now points at this door instead of selling the crossing.

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
@
@ Issue #68 gave this map a SECOND entrance (the city-side door), so this scene is no longer
@ reachable only from the ship. It is still safe, but the reason is now the var and not the
@ geography: anyone walking in through the door is at state 7 (this scene set it, and nothing
@ lowers it), so neither map_script_2 matches and StepAshore's hardcoded walk_up — written for a
@ berth arrival at (8,17), not for the door at (8,9) — cannot fire on the wrong tile.
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

@ Issue #68: the >= 7 gate is NEW, and the door is why it has to exist. While this map was
@ arrival-only, "standing in front of this desk" already implied "arrived on the S.S.AQUA", so an
@ ungated offer could not be reached early — the only way in was SSAqua_1F_EventScript_LeaveBoat,
@ which cannot run below VAR_SSAQUA_STATE 5. The city-side door removes that implication: warp 10
@ is unconditional, RegionHub_EventScript_ReturnKanto lands returning visitors on
@ MAP_VERMILION_CITY warp 0 at (22,34), and the pier is a short walk from there, so without this
@ line a first-run Kanto player who has never heard of the S.S.AQUA could stroll in and sail.
@
@ That is not merely out of order, it is one-way. The crossing calls EnterJohtoRegion below, which
@ flips the active region to JOHTO and re-points the whiteout at HEAL_LOCATION_OLIVINE_CITY — and
@ the far shore is gated: OlivinePort_EventScript_Sailor needs VAR_SSAQUA_STATE >= 7 or
@ (VAR_NEWBARKTOWN_LABSTATE >= 11 + ITEM_SS_TICKET), so it would answer NotSailingYet and there
@ would be no ship back. 7 is the right threshold and not merely a copy of Olivine's: it is set by
@ this map's own ON_FRAME arrival scene above, so every legitimate visitor already has it before
@ they can take a step, and it is the same gate VermilionCity_EventScript_FerrySailor uses two
@ tiles outside the door — the desk and the pier now agree instead of contradicting each other.
VermilionPort_EventScript_Sailor::
	lock
	faceplayer
	goto_if_lt VAR_SSAQUA_STATE, 7, VermilionPort_EventScript_NotSailingYet
	msgbox VermilionPort_Text_AskBoardForOlivine, MSGBOX_YESNO
	goto_if_eq VAR_RESULT, NO, VermilionPort_EventScript_ComeAgain
	call VermilionPort_EventScript_EnterShip
	call VermilionPort_EventScript_EnterJohtoRegion
	warpsilent MAP_OLIVINE_CITY_PORT_INSIDE, 8, 9
	waitstate
	release
	end

VermilionPort_EventScript_NotSailingYet::
	msgbox VermilionPort_Text_NotSailingYet, MSGBOX_DEFAULT
	closemessage
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
@ player actually lands in. Issue #68 removed the pier sailor's duplicate of this leg, so the
@ desk above is now the only caller — keep the ordering if that ever changes, because the far
@ shore's OlivinePort_EventScript_ChoseVermilion inlines the same two steps in the same order
@ and for the same reason.
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

VermilionPort_Text_NotSailingYet:
	.string "FAST SHIP S.S.AQUA sails for JOHTO,\n"
	.string "but she has no crossing booked today.\p"
	.string "Do have a look around the terminal!$"

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
