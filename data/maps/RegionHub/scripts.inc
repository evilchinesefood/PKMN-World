RegionHub_MapScripts::
	.byte 0

RegionHub_EventScript_TransitClerk::
	lock
	faceplayer
	msgbox RegionHub_Text_ClerkWelcome, MSGBOX_DEFAULT
	closemessage
	multichoice 0, 0, MULTI_REGION_HUB, FALSE
	switch VAR_RESULT
	case 0, RegionHub_EventScript_TravelKanto
	case 1, RegionHub_EventScript_TravelJohto
	case 2, RegionHub_EventScript_TravelHoenn
	case 3, RegionHub_EventScript_TravelCancel
	case MULTI_B_PRESSED, RegionHub_EventScript_TravelCancel
	end

@ Each destination sets the active region (callnative reads VAR_RESULT) then warps to that
@ region's start town. This is the RESUME path. STUB: the first-visit ARRIVAL QUEST path
@ (box the carried party -> region start -> regional starter -> set the intro-done bit) is
@ NOT built here - see .plans/features/03b-RegionSwitchDesignSpec.md G4/Section 5.
RegionHub_EventScript_TravelKanto::
	callnative RegionHub_ScrSetCurrentRegion
	closemessage
	warp MAP_PALLET_TOWN, 0
	waitstate
	release
	end

RegionHub_EventScript_TravelJohto::
	callnative RegionHub_ScrSetCurrentRegion
	closemessage
	warp MAP_NEW_BARK_TOWN, 1
	waitstate
	release
	end

RegionHub_EventScript_TravelHoenn::
	callnative RegionHub_ScrSetCurrentRegion
	closemessage
	warp MAP_LITTLEROOT_TOWN, 1
	waitstate
	release
	end

RegionHub_EventScript_TravelCancel::
	closemessage
	release
	end

RegionHub_Text_ClerkWelcome:
	.string "Welcome to the WORLD TRANSIT\n"
	.string "TERMINAL!\p"
	.string "Where would you like to travel?$"
