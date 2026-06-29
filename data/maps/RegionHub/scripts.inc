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
	case 3, RegionHub_EventScript_TravelFrontier
	case 4, RegionHub_EventScript_TravelCancel
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

@ Super-endgame gate: the Hoenn Battle Frontier, repurposed as the unified capstone arena
@ reached from the hub (.plans/features/03b-RegionSwitchDesignSpec.md "Super-endgame" section).
@ It is region-agnostic, so unlike the region cases it does NOT set gCurrentRegion - the
@ destination map's MAPSEC self-derives the region. Warps to OutsideWest warp 9, the plaza
@ side of the south gate (sensible Frontier entrance spawn).
@ TODO(Frontier): two-tier unlock - 1-champion opens, capstone top tier. Gated OPEN for now.
RegionHub_EventScript_TravelFrontier::
	closemessage
	warp MAP_BATTLE_FRONTIER_OUTSIDE_WEST, 9
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

@ World-tour board (R8): reads the three per-region badge banks (K9) and shows the running
@ 24-badge count + per-region breakdown. The grand 24-badge tournament is a future item;
@ this only reports progress. See .plans/features/03a Lane R R8.
RegionHub_EventScript_WorldTourBoard::
	lockall
	callnative RegionHub_ScrCountWorldTourBadges
	buffernumberstring 0, VAR_0x8000
	msgbox RegionHub_Text_WorldTourTotal, MSGBOX_DEFAULT
	buffernumberstring 0, VAR_0x8001
	buffernumberstring 1, VAR_0x8002
	buffernumberstring 2, VAR_0x8003
	msgbox RegionHub_Text_WorldTourBreakdown, MSGBOX_DEFAULT
	releaseall
	end

RegionHub_Text_WorldTourTotal:
	.string "WORLD TOUR BOARD\p"
	.string "GYM BADGES gathered across the\n"
	.string "three regions: {STR_VAR_1}/24!$"

RegionHub_Text_WorldTourBreakdown:
	.string "HOENN: {STR_VAR_1}/8\n"
	.string "KANTO: {STR_VAR_2}/8\l"
	.string "JOHTO: {STR_VAR_3}/8\p"
	.string "Earn all 24 to prove yourself the\n"
	.string "ultimate TRAINER!$"
