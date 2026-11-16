@ VAR_0x8004 here is used by ChangePokemonNickname
Common_EventScript_GetGiftMonPartySlot::
	getpartysize
	subvar VAR_RESULT, 1
	copyvar VAR_0x8004, VAR_RESULT
	return

Common_EventScript_NameReceivedBoxMon::
	fadescreen FADE_TO_BLACK
	setvar VAR_0x8004, PC_MON_CHOSEN
	special ChangePokemonNickname
	lock
	faceplayer
	return

Common_EventScript_TransferredToPC::
	bufferboxname STR_VAR_1, VAR_PC_BOX_TO_SEND_MON
	bufferspeciesname STR_VAR_2, VAR_TEMP_TRANSFERRED_SPECIES
	callnative ScrBufferPcTransferredText
	msgbox gStringVar4, MSGBOX_DEFAULT
	return

Common_EventScript_NoMoreRoomForPokemon::
	msgbox gText_NoMoreRoomForPokemon, MSGBOX_DEFAULT
	release
	end

@ givenamedmon puts its Pokemon in the party only, so its MON_CANT_GIVE means a full party,
@ whatever room the boxes have.
Common_EventScript_NoRoomInPartyForPokemon::
	msgbox gText_NoRoomInPartyForPokemon, MSGBOX_DEFAULT
	release
	end
