.set LOCALID_GOLDENROD_CITY_TRAIN_STATION_ATTENDANT, 1
.set LOCALID_GOLDENROD_CITY_TRAIN_STATION_TRAIN, 7

GoldenrodCity_TrainStation_MapScripts::
	map_script MAP_SCRIPT_ON_FRAME_TABLE, GoldenrodCity_TrainStation_OnFrame
	.byte 0

GoldenrodCity_TrainStation_OnFrame::
	map_script_2 VAR_TRAIN, 1, GoldenrodCity_TrainStation_EventScript_ExitTrain
	.2byte 0

GoldenrodCity_TrainStation_EventScript_Attendant::
	lock
	faceplayer
	checkitem ITEM_PASS
	goto_if_eq VAR_RESULT, TRUE, GoldenrodCity_TrainStation_EventScript_BoardTrain
	@ A1: the machine-part quest was never ported (FLAG_RETURNED_MACHINE_PART is
	@ only ever cleared), so the train runs once the Radio Tower is retaken.
	goto_if_ge VAR_GOLDENROD_CITY_STATE, 10, GoldenrodCity_TrainStation_EventScript_Attendant2
	msgbox GoldenrodMagnetTrainStation_Text_OfficerTrainHasntComeIn, MSGBOX_DEFAULT
	closemessage
	release
	end

GoldenrodCity_TrainStation_EventScript_Attendant2::
	msgbox GoldenrodMagnetTrainStation_Text_OfficerNoRailPass, MSGBOX_DEFAULT
	closemessage
	release
	end


GoldenrodCity_TrainStation_EventScript_BoardTrain::
	msgbox GoldenrodMagnetTrainStation_Text_OfficerRightThisWay, MSGBOX_DEFAULT
	closemessage
	applymovement LOCALID_GOLDENROD_CITY_TRAIN_STATION_ATTENDANT, GoldenrodCity_TrainStation_Movement_Attendant_Move_Up
	waitmovement 0
	applymovement OBJ_EVENT_ID_PLAYER, GoldenrodCity_TrainStation_Movement_WalktoTrain
	waitmovement 0
	special SpawnCameraObject
	applymovement OBJ_EVENT_ID_PLAYER, Common_Movement_WalkUp1
	waitmovement 0
	playse SE_EXIT
	waitse
	fadescreen FADE_TO_BLACK

	applymovement OBJ_EVENT_ID_CAMERA, GoldenrodCity_TrainStation_Movement_CameraPanUp
	waitmovement 0
	applymovement OBJ_EVENT_ID_CAMERA, GoldenrodCity_TrainStation_Movement_CameraPanLeft
	waitmovement 0
	delay 60

	applymovement LOCALID_GOLDENROD_CITY_TRAIN_STATION_TRAIN, GoldenrodCity_TrainStation_Movement_SlideRight
	applymovement OBJ_EVENT_ID_CAMERA, GoldenrodCity_TrainStation_Movement_SlideRight
	fadescreen FADE_FROM_BLACK
	playse SE_TRUCK_MOVE
	delay 220
	playse SE_TRUCK_STOP
	applymovement LOCALID_GOLDENROD_CITY_TRAIN_STATION_TRAIN, GoldenrodCity_TrainStation_Movement_SlideRight
	applymovement OBJ_EVENT_ID_CAMERA, GoldenrodCity_TrainStation_Movement_SlideRight
	fadescreen FADE_TO_BLACK
	waitse
	special RemoveCameraObject
	@ region merge (D4): the Magnet Train is Johto's World Transit access point -> the hub.
	callnative RegionHub_ScrSetHubAccess
	delay 60
	warp MAP_REGION_HUB, 0
	waitstate
	end

GoldenrodCity_TrainStation_EventScript_ExitTrain::
	lock
	applymovement LOCALID_GOLDENROD_CITY_TRAIN_STATION_ATTENDANT, GoldenrodCity_TrainStation_Movement_Attendant_Move_Up
	applymovement OBJ_EVENT_ID_PLAYER, GoldenrodCity_TrainStation_Movement_ExitTrain
	waitmovement 0
	waitmovement 0
	setvar VAR_TRAIN, 0
	applymovement LOCALID_GOLDENROD_CITY_TRAIN_STATION_ATTENDANT, GoldenrodCity_TrainStation_Movement_Attendant_Move_Down
	waitmovement 0
	release
	end

@ A1 (P0): the rail PASS had no giver. HnS's Copycat-doll chain isn't in the
@ port, so the station PRESIDENT hands it out once the Radio Tower is retaken
@ (VAR_GOLDENROD_CITY_STATE >= 10) - Johto's World Transit unlock beat, in line
@ with Kanto's and Hoenn's mid-game access points. checkitem is the cross-
@ region-safe re-give guard.
GoldenrodCity_TrainStation_EventScript_Gent::
	lock
	faceplayer
	goto_if_lt VAR_GOLDENROD_CITY_STATE, 10, GoldenrodCity_TrainStation_EventScript_GentDream
	checkitem ITEM_PASS
	goto_if_eq VAR_RESULT, TRUE, GoldenrodCity_TrainStation_EventScript_GentHasPass
	msgbox GoldenrodMagnetTrainStation_Text_PresidentGivePass, MSGBOX_DEFAULT
	giveitem ITEM_PASS
	msgbox GoldenrodMagnetTrainStation_Text_PresidentRideAnytime, MSGBOX_DEFAULT
	closemessage
	release
	end

GoldenrodCity_TrainStation_EventScript_GentDream::
	msgbox GoldenrodMagnetTrainStation_Text_GentlemanPresident, MSGBOX_DEFAULT
	closemessage
	release
	end

GoldenrodCity_TrainStation_EventScript_GentHasPass::
	msgbox GoldenrodMagnetTrainStation_Text_PresidentRideAnytime, MSGBOX_DEFAULT
	closemessage
	release
	end

GoldenrodCity_TrainStation_EventScript_Boy::
	lock
	msgbox GoldenrodCity_TrainStation_Text_Boy, MSGBOX_DEFAULT
	closemessage
	release
	end

GoldenrodCity_TrainStation_EventScript_Psychic::
	lock
	msgbox GoldenrodCity_TrainStation_Text_Psychic, MSGBOX_DEFAULT
	closemessage
	release
	end

GoldenrodCity_TrainStation_Movement_ExitTrain:
	walk_down
	walk_left
	walk_left
	walk_left
	walk_down
	walk_down
	walk_down
	step_end

GoldenrodCity_TrainStation_Movement_Attendant_Move_Up:
	face_up
	walk_up
	walk_left
	face_right
	step_end

GoldenrodCity_TrainStation_Movement_Attendant_Move_Down:
	walk_right
	walk_down
	step_end

GoldenrodCity_TrainStation_Movement_WalktoTrain:
	walk_up
	walk_up
	walk_up
	walk_right
	walk_right
	walk_right
	walk_up
	walk_up
	step_end

GoldenrodCity_TrainStation_Movement_CameraPanUp:
	slide_up
	slide_up
	slide_up
	slide_up
	slide_up
	slide_up
	slide_up
	slide_up
	slide_up
	slide_up
	slide_up
	step_end

GoldenrodCity_TrainStation_Movement_CameraPanLeft:
	slide_left
	slide_left
	slide_left
	slide_left
	slide_left
	slide_left
	slide_left
	slide_left
	slide_left
	slide_left
	slide_left
	step_end

GoldenrodCity_TrainStation_Movement_SlideRight:
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	slide_right
	step_end

GoldenrodMagnetTrainStation_Text_OfficerTrainHasntComeIn:
    .string "The train hasn't come in…\p"
    .string "I know! I'll carry the passengers\n"
    .string "on my back!\p"
    .string "That won't work.$"

GoldenrodMagnetTrainStation_Text_OfficerRightThisWay:
    .string "May I see your rail PASS, please?\p"
    .string "OK. Right this way, please.$"

GoldenrodMagnetTrainStation_Text_OfficerNoRailPass:
    .string "Sorry. You don't have a rail PASS.\p"
    .string "The PRESIDENT over there has been\n"
    .string "handing them out.$"

GoldenrodMagnetTrainStation_Text_GentlemanPresident:
    .string "I'm the PRESIDENT.\p"
    .string "My dream was to build a train that\n"
    .string "is faster than any POKéMON.\p"
    .string "It really brings JOHTO much closer\n"
    .string "to KANTO.$"

GoldenrodMagnetTrainStation_Text_PresidentGivePass:
    .string "I'm the PRESIDENT.\p"
    .string "You're the TRAINER who drove\n"
    .string "TEAM ROCKET from the RADIO TOWER!\p"
    .string "Splendid! The MAGNET TRAIN can\n"
    .string "run without any worries.\p"
    .string "Please, take this rail PASS.$"

GoldenrodMagnetTrainStation_Text_PresidentRideAnytime:
    .string "With that PASS, you may ride my\n"
    .string "MAGNET TRAIN anytime!$"

GoldenrodCity_TrainStation_Text_Boy:
	.string "You brought the MAGNET TRAIN PASS,\n"
	.string "right?$"

GoldenrodCity_TrainStation_Text_Psychic:
	.string "I thought you had it!$"
