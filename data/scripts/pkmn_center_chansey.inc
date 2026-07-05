EventScript_PkmnCenterChansey::
	lock
	faceplayer
	playmoncry SPECIES_CHANSEY, CRY_MODE_NORMAL
	msgbox Text_PkmnCenterChansey_Cry, MSGBOX_DEFAULT
	delay 40
	waitmoncry
	closemessage
	release
	end

Text_PkmnCenterChansey_Cry:
	.string "CHANSEY: Chaan! Sii!$"
