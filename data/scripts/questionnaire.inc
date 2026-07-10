EventScript_Questionnaire::
	lockall
	msgbox Questionnaire_Text_FillOut, MSGBOX_YESNO
	goto_if_eq VAR_RESULT, NO, Questionnaire_EventScript_Release
	setvar VAR_0x8004, EASY_CHAT_TYPE_QUESTIONNAIRE
	call Common_ShowEasyChatScreen
	lock
	faceplayer
	specialvar VAR_0x8008, GetMartEmployeeObjectEventId
	goto_if_eq VAR_0x8004, 1, Questionnaire_EventScript_PlayerInputMysteryEventPhrase
	goto_if_eq VAR_0x8004, 2, Questionnaire_EventScript_PlayerInputMysteryGiftPhrase
	goto_if_eq VAR_RESULT, 0, Questionnaire_EventScript_Release
	goto_if_eq VAR_RESULT, 1, Questionnaire_EventScript_ThankYou
	end

@ region merge (D6): Mystery Gift/Event link services are dead surfaces in the merged
@ single-player game — magic phrases no longer set the enable flags, just a thank-you.
Questionnaire_EventScript_PlayerInputMysteryEventPhrase::
	goto Questionnaire_EventScript_ThankYou
	end

Questionnaire_EventScript_PlayerInputMysteryGiftPhrase::
	goto Questionnaire_EventScript_ThankYou
	end

Questionnaire_EventScript_Release::
	releaseall
	end

Questionnaire_EventScript_ThankYou::
	applymovement VAR_0x8008, Common_Movement_FaceDown
	waitmovement 0
	msgbox Questionnaire_Text_ThankYou, MSGBOX_DEFAULT
	releaseall
	end
