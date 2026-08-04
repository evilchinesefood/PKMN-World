.set LOCALID_OLIVINEPORT_SAILOR, 1
.set LOCALID_OLIVINEPORT_BOAT, 6
.set LOCALID_OLIVINEPORT_OAK, 7

OlivineCity_PortInside_MapScripts::
	.byte 0


OlivineCity_PortInside_EventScript_Oak::
	lock
	playbgm MUS_HG_OAK, TRUE
	playse SE_PIN
	applymovement2 LOCALID_OLIVINEPORT_OAK, Common_Movement_ExclamationMark
	delay 60
	turnobject LOCALID_OLIVINEPORT_OAK, DIR_NORTH
	msgbox OlivineCity_PortInside_Text_Nationaldex1, MSGBOX_DEFAULT
	closemessage
	applymovement2 LOCALID_OLIVINEPORT_OAK, OlivineCity_PortInside_Movement_OakFixDex
	waitmovement 0
	delay 30
	setflag FLAG_SYS_NATIONAL_DEX
	special EnableNationalPokedex
	playfanfare MUS_OBTAIN_ITEM
	message OlivineCity_PortInside_Text_Nationaldex2
	waitfanfare
	delay 50
	msgbox OlivineCity_PortInside_Text_Nationaldex3, MSGBOX_DEFAULT
	closemessage
	playse SE_PIN
	applymovement2 LOCALID_OLIVINEPORT_OAK, Common_Movement_ExclamationMark
	delay 60
	msgbox OlivineCity_PortInside_Text_Nationaldex4, MSGBOX_DEFAULT
	closemessage
	applymovement OBJ_EVENT_ID_PLAYER, OlivineCity_PortInside_Movement_PlayerMoveOver
	waitmovement 0
	applymovement LOCALID_OLIVINEPORT_OAK, OlivineCity_PortInside_Movement_OakLeave
	waitmovement 0
	setflag FLAG_HIDE_OLIVINE_PORT_OAK
	playse SE_EXIT
	removeobject LOCALID_OLIVINEPORT_OAK
	fadedefaultbgm
	waitse
	release
	end

OlivineCity_PortInside_Movement_OakFixDex:
	walk_in_place_up
	walk_in_place_up
	step_end

OlivineCity_PortInside_Movement_PlayerMoveOver:
	walk_up
	walk_left
	face_right
	step_end

OlivineCity_PortInside_Movement_OakLeave:
	walk_up
	walk_up
	walk_up
	walk_up
	walk_up
	walk_up
	walk_up
	step_end

OlivineCity_PortInside_Text_Nationaldex1:
	.string "PROF.OAK: Hello!\n"
	.string "You are starting to have the\l"
	.string "attitude of a CHAMPION, {PLAYER}!\p"
	.string "It's time for your POKéDEX to\n"
	.string "match who you are.\p"
	.string "Let me see your POKéDEX for a\n"
	.string "second.\p"
	.string "I'll upgrade your POKéDEX with the\n"
	.string "NATIONAL MODE.$"
OlivineCity_PortInside_Text_Nationaldex2:
	.string "{PLAYER}'s POKéDEX was upgraded\n"
	.string "with the NATIONAL MODE!$"
OlivineCity_PortInside_Text_Nationaldex3:
	.string "PROF.OAK: It won't be easy to\n"
	.string "complete the NATIONAL POKéDEX…\p"
	.string "However, I'm sure you will make\n"
	.string "honest attempt on our behalf!$"
OlivineCity_PortInside_Text_Nationaldex4:
	.string "Oh, time flies!\p"
	.string "I have a radio show to record at\n"
	.string "GOLDENROD RADIO TOWER.\p"
	.string "You must be heading for KANTO.\p"
	.string "If you come near PALLET TOWN, do\n"
	.string "drop by my POKéMON RESEARCH LAB!$"

OlivinePort_EventScript_CooltrainerF::
	msgbox OlivinePort_Text_CooltrainerF, MSGBOX_NPC
	end

OlivinePort_EventScript_Fisher1::
	msgbox OlivinePort_Text_FishingGuru1, MSGBOX_NPC
	end

OlivinePort_EventScript_Fisher2::
	msgbox OlivinePort_Text_FishingGuru2, MSGBOX_NPC
	end

OlivinePort_EventScript_Youngster::
	msgbox OlivinePort_Text_Youngster, MSGBOX_NPC
	end

OlivinePort_EventScript_Sailor::
	lock
	faceplayer
	goto_if_ge VAR_SSAQUA_STATE, 7, OlivinePort_EventScript_Sailor_AfterKanto
	@ A1 gate policy: the maiden voyage is Johto's post-League beat (Elm's
	@ S.S.TICKET). Norman's Hoenn ticket must not launch it mid-Johto.
	goto_if_lt VAR_NEWBARKTOWN_LABSTATE, 11, OlivinePort_EventScript_Sailor_NotSailingYet
	msgbox OlivinePort_Text_AskBoard, MSGBOX_YESNO
	goto_if_eq VAR_RESULT, FALSE, OlivinePort_EventScript_Sailor_Refused
	checkitem ITEM_SS_TICKET
	goto_if_eq VAR_RESULT, TRUE, OlivinePort_EventScript_Sailor_MaidenVoyage
	msgbox OlivinePort_Text_NoTicket, MSGBOX_DEFAULT
	closemessage
	release
	end

OlivinePort_EventScript_Sailor_NotSailingYet::
	msgbox OlivinePort_Text_NotSailingYet, MSGBOX_DEFAULT
	closemessage
	release
	end

@ Every `warpsilent` below is followed by an explicit `waitstate`. warpsilent runs DoDiveWarp(),
@ which spawns Task_WarpAndLoadMap, and StopScript() asserts if a script ends while that task is
@ live ("Leaving script while a warp is in progress", src/script.c). That assert is compiled into
@ the shipped ROM, so it is a blue-screen, not a debug nicety. All six warps in this file were
@ missing it — five of them harmlessly, because this menu was unreachable, but the SIXTH is
@ OlivinePort_EventScript_Sailor_MaidenVoyage, on the live post-League path. Do not drop them.
OlivinePort_EventScript_Sailor_AfterKanto::
	message OlivinePort_Text_WhereSail
	@ `message` starts the typewriter and returns immediately; without this the destination
	@ window opened on top of a still-typing "Where would you like to sail?". Harmless while
	@ this branch was dead code - it is on screen every post-crossing visit now.
	waitmessage
	multichoice 1, 0, MULTI_OLIVINE_HARBOR, FALSE
	switch VAR_RESULT
	case 0, OlivinePort_EventScript_ChoseVermilion
	case 1, OlivinePort_EventScript_ChoseSouthernIsland
	case 2, OlivinePort_EventScript_ChoseBirthIsland
	case 3, OlivinePort_EventScript_ChoseFarawayIsland
	case 4, OlivinePort_EventScript_ChoseBattleFrontier
	case 5, OlivinePort_EventScript_Sailor_Refused
	case MULTI_B_PRESSED, OlivinePort_EventScript_Sailor_Refused
	release
	end

@ Lane-R (issue #65): the KANTO run. The MAIDEN voyage is the full cabin ride (states 1..6,
@ MAP_SSAQUA_1F); every crossing after it is a direct hop, the same shape as the four
@ event-ticket runs below. Cross-region arrival is handled exactly as on the maiden voyage's
@ disembark — see the INVARIANT note in SSAqua_1F_EventScript_LeaveBoat. The setrespawn has
@ to come AFTER both OlivinePort_EventScript_EnterShip (which arms OLIVINE) and
@ RegionHub_ScrSetCurrentRegion (which arms KANTO's start town), or it loses to them.
OlivinePort_EventScript_ChoseVermilion::
	closemessage
	delay 20
	call OlivinePort_EventScript_EnterShip
	setvar VAR_RESULT, 0 @ 0 = REGION_KANTO
	callnative RegionHub_ScrSetCurrentRegion
	setrespawn HEAL_LOCATION_VERMILION_CITY
	warpsilent MAP_VERMILION_CITY_PORT_INSIDE, 8, 16
	waitstate
	release
	end

OlivinePort_EventScript_ChoseSouthernIsland::
	closemessage
	delay 20
	checkitem ITEM_EON_TICKET
	bufferitemname STR_VAR_1, ITEM_EON_TICKET
	goto_if_unset FLAG_ENABLE_SHIP_SOUTHERN_ISLAND, OlivinePort_EventScript_Sailor_NoCredentials
	goto_if_eq VAR_RESULT, FALSE, OlivinePort_EventScript_Sailor_NoCredentials
	call OlivinePort_EventScript_EnterShip
	warpsilent MAP_SOUTHERN_ISLAND_EXTERIOR, 13, 22
	waitstate
	release
	end

OlivinePort_EventScript_ChoseBirthIsland::
	closemessage
	delay 20
	checkitem ITEM_AURORA_TICKET
	bufferitemname STR_VAR_1, ITEM_AURORA_TICKET
	goto_if_unset FLAG_ENABLE_SHIP_BIRTH_ISLAND, OlivinePort_EventScript_Sailor_NoCredentials
	goto_if_eq VAR_RESULT, FALSE, OlivinePort_EventScript_Sailor_NoCredentials
	call OlivinePort_EventScript_EnterShip
	@ The HARBOR, not the exterior: (13,23) on MAP_BIRTH_ISLAND_EXTERIOR is an impassable
	@ tile with no sailor on the map to sail home from. MAP_LILYCOVE_CITY_HARBOR's identical
	@ AURORA TICKET run is the reference destination. Latent until this menu became
	@ reachable (issue #65).
	warpsilent MAP_BIRTH_ISLAND_HARBOR, 8, 4
	waitstate
	release
	end

OlivinePort_EventScript_ChoseFarawayIsland::
	closemessage
	delay 20
	checkitem ITEM_OLD_SEA_MAP
	bufferitemname STR_VAR_1, ITEM_OLD_SEA_MAP
	goto_if_unset FLAG_ENABLE_SHIP_FARAWAY_ISLAND, OlivinePort_EventScript_Sailor_NoCredentials
	goto_if_eq VAR_RESULT, FALSE, OlivinePort_EventScript_Sailor_NoCredentials
	call OlivinePort_EventScript_EnterShip
	warpsilent MAP_FARAWAY_ISLAND_ENTRANCE, 13, 38
	waitstate
	release
	end	

@ Issue #69, decided and left alone: this row does NOT round-trip, and that is the intended
@ behaviour, not an omission. The four rows above it warp onto region-agnostic event ISLANDS and
@ claim nothing, so their sailors can read the active region as a departure record and bring a
@ Johto player back to this hall. The BATTLE FRONTIER is a destination, not an island: its own
@ dock ferry (BattleFrontier_OutsideWest_EventScript_ChooseFerryDestination) offers SLATEPORT and
@ LILYCOVE only, and both of those legs claim REGION_HOENN before they warp - so Olivine ->
@ Frontier -> Slateport is an honest one-way journey INTO Hoenn rather than the trap #65 closed.
@
@ What makes it not-a-trap is the second exit: BattleFrontier_OutsideWest_EventScript_HubShuttle
@ stands on the same dock and rides back to the World Transit hub. A player who did not want
@ Hoenn is never stuck; they pay the hub's party-boxing, which is the ordinary price of a region
@ cross and is exactly what the hub is for. Round-tripping this row would need a conditional
@ OLIVINE entry in the Frontier's explicit multichoice (or a pre-offer gated on the active
@ region), NOT the shared island script - so it is a behaviour change with a design decision in
@ front of it, and the decision recorded here is "leave it".
@
@ FLAGGED, deliberately NOT fixed here (wants its own issue): this row has no credential gate at
@ all. Every sibling row does `checkitem` + `goto_if_unset FLAG_ENABLE_SHIP_*`, and the Hoenn-side
@ analogue BattleFrontier_OutsideWest_EventScript_FerryAttendant requires FLAG_SYS_GAME_CLEAR AND
@ ITEM_SS_TICKET. Adding one would change player-facing behaviour without an owner decision, so
@ it is named rather than done.
OlivinePort_EventScript_ChoseBattleFrontier::
	closemessage
	delay 20
	call OlivinePort_EventScript_EnterShip
	warpsilent MAP_BATTLE_FRONTIER_OUTSIDE_WEST, 20, 67
	waitstate
	release
	end	

OlivinePort_EventScript_Sailor_MaidenVoyage::
	msgbox OlivinePort_Text_FlashTicket, MSGBOX_DEFAULT
	call OlivinePort_EventScript_EnterShip
	setvar VAR_SSAQUA_STATE, 1
	clearflag FLAG_HIDE_SSAQUA_1F_GRANDPA
	setflag FLAG_HIDE_SSAQUA_ROOM_SSE_GRANDDAUGHTER

	clearflag FLAG_HIDE_SSAQUA_SAILOR
	clearflag FLAG_HIDE_SSAQUA_CAPTAINS_ROOM_GRANDDAUGHTER

	@ Region merge (SS Aqua port): SS Aqua boarding warp re-stitched (was stubbed to
	@ MAP_OLIVINE_CITY, 15, 44 when Olivine shipped; original dest restored).
	warpsilent MAP_SSAQUA_1F, 29, 3
	waitstate
	release
	end

OlivinePort_EventScript_EnterShip::
	msgbox OlivinePort_Text_SailorGetOnBoard, MSGBOX_DEFAULT
	closemessage
	delay 20
	applymovement LOCALID_OLIVINEPORT_SAILOR, OlivinePort_Movement_SailorEnterBoat
	waitmovement 0
	playse SE_EXIT
	applymovement OBJ_EVENT_ID_PLAYER, OlivinePort_Movement_PlayerEnterBoat
	waitmovement 0
	special SpawnCameraObject
	playse SE_EXIT
	removeobject OBJ_EVENT_ID_PLAYER
	delay 60
	applymovement LOCALID_OLIVINEPORT_SAILOR, OlivinePort_Movement_BoatLeave
	applymovement LOCALID_OLIVINEPORT_BOAT, OlivinePort_Movement_BoatLeave
	waitmovement LOCALID_OLIVINEPORT_BOAT
	setrespawn HEAL_LOCATION_OLIVINE_CITY
	return

OlivinePort_EventScript_Sailor_Refused::
	msgbox OlivinePort_Text_ComeAgain, MSGBOX_DEFAULT
	closemessage
	release
	end

OlivinePort_EventScript_Sailor_NoCredentials::
	msgbox OlivinePort_Text_NoPass, MSGBOX_DEFAULT
	closemessage
	release
	end

OlivinePort_Movement_SailorEnterBoat:
	walk_down
	walk_down
	step_end

OlivinePort_Movement_PlayerEnterBoat:
	walk_down
	walk_down
	walk_in_place_down
	step_end

OlivinePort_Movement_BoatLeave:
	walk_right
	walk_right
	walk_right
	walk_right
	walk_right
	step_end

OlivinePort_Text_NoPass:
    .string "{PLAYER} tried to show the\n"
    .string "{STR_VAR_1}…\p"
    .string "…But no {STR_VAR_1}!\p"
    .string "Sorry!\n"
    .string "You may board only if you have an\l"
    .string "{STR_VAR_1}.$"

OlivinePort_Text_SailorGetOnBoard:
    .string "We're departing soon.\n"
    .string "Please get on board.$"

OlivinePort_Text_CantBoard:
    .string "Sorry. You can't board now.$"

OlivinePort_Text_WhereSail:
    .string "Where would you like to sail?$"

OlivinePort_Text_AskBoard:
    .string "Welcome to FAST SHIP S.S.AQUA.\p"
    .string "Will you be boarding today?$"

OlivinePort_Text_AskTicket:
    .string "May I see your S.S.TICKET?$"

OlivinePort_Text_ComeAgain:
    .string "We hope to see you again!$"

OlivinePort_Text_FlashTicket:
    .string "{PLAYER} flashed the S.S.TICKET.\p"
    .string "That's it. Thank you!$"

OlivinePort_Text_NotSailingYet:
    .string "The S.S. AQUA is still being\n"
    .string "readied for her maiden voyage.\p"
    .string "Please come back later!$"

OlivinePort_Text_NoTicket:
    .string "{PLAYER} tried to show the\n"
    .string "S.S.TICKET…\p"
    .string "…But no TICKET!\p"
    .string "Sorry!\n"
    .string "You may board only\l"
    .string "if you have an S.S.TICKET.$"

OlivinePort_Text_FishingGuru1:
    .string "SHELLDER are easy to catch here.\p"
    .string "They're kind of rare elsewhere.$"

OlivinePort_Text_FishingGuru2:
    .string "How many RODS do you have?\p"
    .string "Different RODS catch different\n"
    .string "POKéMON.$"

OlivinePort_Text_Youngster:
    .string "S.S.AQUA uses jets to skim\n"
    .string "over the waves!$"

OlivinePort_Text_CooltrainerF:
    .string "There are lots of POKéMON in KANTO.\p"
    .string "I wish I could go…$"

OlivinePort_Text_SailorBeforeHOF:
    .string "We don't want you to fall into the\n"
    .string "sea, so you're not allowed in.$"
