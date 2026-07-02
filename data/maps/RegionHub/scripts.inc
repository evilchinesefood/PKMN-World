RegionHub_MapScripts::
	.byte 0

@ World Transit hub - region-switch. Three OPEN spatial gates: walk onto a gate tile and
@ confirm to travel into that region; a fourth gate reaches the shared Battle Frontier
@ capstone. The old transit-clerk multichoice was removed (Lane R: pick by walking, not a
@ menu). Each region gate sets the active region and boxes the carried party ONLY when
@ crossing regions (callnative RegionHub_ScrEnterRegion), then warps to that region's start
@ town; the first-visit "Mom moves in" scene vs resume is decided at the start town, keyed
@ on its intro-done bit (D3). Gate tiles + walkability are PLAYTEST items (LAYOUT_HOUSE3).

RegionHub_EventScript_GateKanto::
	lockall
	msgbox RegionHub_Text_TravelKanto, MSGBOX_YESNO
	goto_if_eq VAR_RESULT, NO, RegionHub_EventScript_GateCancel
	setvar VAR_RESULT, 0
	callnative RegionHub_ScrEnterRegion
	callnative RegionHub_ScrTargetIntroDone
	closemessage
	goto_if_eq VAR_RESULT, 1, RegionHub_EventScript_ReturnKanto
	warp MAP_PALLET_TOWN, 0
	waitstate
	releaseall
	end

@ D5 resume: on a return visit (intro-done set) land at the region's World Transit access
@ point instead of the start town, so progress + team resume where the player left off.
RegionHub_EventScript_ReturnKanto::
	warp MAP_VERMILION_CITY, 0
	waitstate
	releaseall
	end

RegionHub_EventScript_GateJohto::
	lockall
	msgbox RegionHub_Text_TravelJohto, MSGBOX_YESNO
	goto_if_eq VAR_RESULT, NO, RegionHub_EventScript_GateCancel
	setvar VAR_RESULT, 1
	callnative RegionHub_ScrEnterRegion
	callnative RegionHub_ScrTargetIntroDone
	closemessage
	goto_if_eq VAR_RESULT, 1, RegionHub_EventScript_ReturnJohto
	warp MAP_NEW_BARK_TOWN, 1
	waitstate
	releaseall
	end

@ D5 resume: on a return visit (intro-done set) land at the region's World Transit access
@ point instead of the start town, so progress + team resume where the player left off.
RegionHub_EventScript_ReturnJohto::
	warp MAP_GOLDENROD_CITY_TRAIN_STATION, 0
	waitstate
	releaseall
	end

RegionHub_EventScript_GateHoenn::
	lockall
	msgbox RegionHub_Text_TravelHoenn, MSGBOX_YESNO
	goto_if_eq VAR_RESULT, NO, RegionHub_EventScript_GateCancel
	setvar VAR_RESULT, 2
	callnative RegionHub_ScrEnterRegion
	callnative RegionHub_ScrTargetIntroDone
	closemessage
	goto_if_eq VAR_RESULT, 1, RegionHub_EventScript_ReturnHoenn
	warp MAP_LITTLEROOT_TOWN, 1
	waitstate
	releaseall
	end

@ D5 resume: on a return visit (intro-done set) land at the region's World Transit access
@ point instead of the start town, so progress + team resume where the player left off.
RegionHub_EventScript_ReturnHoenn::
	warp MAP_SLATEPORT_CITY_HARBOR, 0
	waitstate
	releaseall
	end

@ Battle Frontier capstone - region-agnostic (no SetCurrentRegion; the destination MAPSEC
@ self-derives the region) and does NOT box the party. Gated OPEN for now; two-tier unlock TBD.
RegionHub_EventScript_GateFrontier::
	lockall
	msgbox RegionHub_Text_TravelFrontier, MSGBOX_YESNO
	goto_if_eq VAR_RESULT, NO, RegionHub_EventScript_GateCancel
	closemessage
	warp MAP_BATTLE_FRONTIER_OUTSIDE_WEST, 9
	waitstate
	releaseall
	end

RegionHub_EventScript_GateCancel::
	closemessage
	releaseall
	end

@ Platform attendants (visible NPCs) stand beside each region gate so the depot reads
@ clearly: each names its destination and tells the player the gate is a walk-on pad.
@ These are flavor only; the actual travel stays on the walk-on gate coord_events above.
RegionHub_EventScript_SignKanto::
	msgbox RegionHub_Text_SignKanto, MSGBOX_NPC
	end

RegionHub_EventScript_SignJohto::
	msgbox RegionHub_Text_SignJohto, MSGBOX_NPC
	end

RegionHub_EventScript_SignHoenn::
	msgbox RegionHub_Text_SignHoenn, MSGBOX_NPC
	end

RegionHub_EventScript_SignFrontier::
	msgbox RegionHub_Text_SignFrontier, MSGBOX_NPC
	end

RegionHub_Text_SignKanto:
	.string "This is the platform bound for\n"
	.string "KANTO.\p"
	.string "Step onto the pad beside me to\n"
	.string "travel there!$"

RegionHub_Text_SignJohto:
	.string "This is the platform bound for\n"
	.string "JOHTO.\p"
	.string "Step onto the pad beside me to\n"
	.string "travel there!$"

RegionHub_Text_SignHoenn:
	.string "This is the platform bound for\n"
	.string "HOENN.\p"
	.string "Step onto the pad beside me to\n"
	.string "travel there!$"

RegionHub_Text_SignFrontier:
	.string "This platform heads to the\n"
	.string "BATTLE FRONTIER.\p"
	.string "Step onto the pad beside me to\n"
	.string "travel there!$"

RegionHub_Text_TravelKanto:
	.string "Take the platform bound for KANTO?\p"
	.string "Your current team will be sent to\n"
	.string "the PC BOXES when you switch\l"
	.string "regions.$"

RegionHub_Text_TravelJohto:
	.string "Take the platform bound for JOHTO?\p"
	.string "Your current team will be sent to\n"
	.string "the PC BOXES when you switch\l"
	.string "regions.$"

RegionHub_Text_TravelHoenn:
	.string "Take the platform bound for HOENN?\p"
	.string "Your current team will be sent to\n"
	.string "the PC BOXES when you switch\l"
	.string "regions.$"

RegionHub_Text_TravelFrontier:
	.string "Head to the BATTLE FRONTIER?$"

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
