SSAqua_PlayersRoom_MapScripts::
	.byte 0

SSAquaRooms_EventScript_Bed::
	setvar VAR_RESULT, FALSE
	lockall
	msgbox SSAquaRooms_Text_TakeRestOnBed, MSGBOX_DEFAULT
	closemessage
	call Common_EventScript_OutOfCenterPartyHeal
	releaseall
	end

SSAquaRooms_Text_TakeRestOnBed:
	.string "There's a bed…\n"
	.string "Let's take a rest.$"
