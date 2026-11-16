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

@ The receipt a scripted Pokemon gift owes the player: fanfare and "received", a nickname offer,
@ and the PC notice when a full party sent it to a box. Call it right after givemon with
@ STR_VAR_1 and VAR_TEMP_TRANSFERRED_SPECIES naming the species and VAR_RESULT still holding
@ MON_GIVEN_TO_PARTY or MON_GIVEN_TO_PC.
Common_EventScript_ReceivedGiftMon::
	goto_if_eq VAR_RESULT, MON_GIVEN_TO_PC, Common_EventScript_ReceivedGiftMonInBox
	call Common_EventScript_ReceivedNamedGiftMon
	msgbox gText_NicknameThisPokemon, MSGBOX_YESNO
	goto_if_eq VAR_RESULT, NO, Common_EventScript_ReceivedGiftMonDone
	call Common_EventScript_GetGiftMonPartySlot
	call Common_EventScript_NameReceivedPartyMon
Common_EventScript_ReceivedGiftMonDone::
	return

Common_EventScript_ReceivedGiftMonInBox::
	call Common_EventScript_ReceivedNamedGiftMon
	msgbox gText_NicknameThisPokemon, MSGBOX_YESNO
	call_if_eq VAR_RESULT, YES, Common_EventScript_NameReceivedBoxMon
	call Common_EventScript_TransferredToPC
	return

@ The same receipt for a givenamedmon gift, which always lands in the party and keeps the name
@ and trainer its giver gave it.
Common_EventScript_ReceivedNamedGiftMon::
	playfanfare MUS_OBTAIN_ITEM
	message gText_PlayerReceivedGiftMon
	waitmessage
	waitfanfare
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
