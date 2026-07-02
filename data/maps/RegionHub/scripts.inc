RegionHub_MapScripts::
	map_script MAP_SCRIPT_ON_TRANSITION, RegionHub_OnTransition
	.byte 0

@ World Transit hub - region-switch terminal rebuilt in the Indigo Plateau Pokemon Center
@ style (LAYOUT_REGION_HUB, an edited copy of the FRLG Indigo Plateau lobby). Travel is by
@ TALKING to a platform attendant and confirming; the old walk-on gate pads are gone. Each
@ region attendant sets the active region and boxes the carried party ONLY when crossing
@ regions (callnative RegionHub_ScrEnterRegion), then warps to the region's start town on a
@ first visit or to its World Transit access point on a return (RegionHub_ScrTargetIntroDone,
@ D5). The Frontier attendant blocks the old league door, is region-agnostic and never boxes
@ the party. Also here: the healing nurse (FRLG pattern + HEAL_LOCATION_REGION_HUB respawn),
@ a storage PC (MB_PC metatile at (17,9)), the front-desk mart (Indigo clerk inventory), six
@ department-store vendors (Lilycove 2F/3F/4F inventories) behind the east counter, and the
@ read-only world-tour scoreboard (R8) by the door. Arrivals land on the floor crest at
@ (11,14) = warp 0 (never triggers - plain floor tile, anchor only).

RegionHub_OnTransition::
	setrespawn HEAL_LOCATION_REGION_HUB
	end

RegionHub_EventScript_Nurse::
	lock
	faceplayer
	call EventScript_PkmnCenterNurse_Frlg
	release
	end

RegionHub_EventScript_AttendantKanto::
	lock
	faceplayer
	msgbox RegionHub_Text_TravelKanto, MSGBOX_YESNO
	goto_if_eq VAR_RESULT, NO, RegionHub_EventScript_TravelDeclined
	setvar VAR_RESULT, 0
	callnative RegionHub_ScrEnterRegion
	callnative RegionHub_ScrTargetIntroDone
	closemessage
	goto_if_eq VAR_RESULT, 1, RegionHub_EventScript_ReturnKanto
	warp MAP_PALLET_TOWN, 0
	waitstate
	release
	end

@ D5 resume: on a return visit (intro-done set) land at the region's World Transit access
@ point instead of the start town, so progress + team resume where the player left off.
RegionHub_EventScript_ReturnKanto::
	warp MAP_VERMILION_CITY, 0
	waitstate
	release
	end

RegionHub_EventScript_AttendantJohto::
	lock
	faceplayer
	msgbox RegionHub_Text_TravelJohto, MSGBOX_YESNO
	goto_if_eq VAR_RESULT, NO, RegionHub_EventScript_TravelDeclined
	setvar VAR_RESULT, 1
	callnative RegionHub_ScrEnterRegion
	callnative RegionHub_ScrTargetIntroDone
	closemessage
	goto_if_eq VAR_RESULT, 1, RegionHub_EventScript_ReturnJohto
	warp MAP_NEW_BARK_TOWN, 1
	waitstate
	release
	end

RegionHub_EventScript_ReturnJohto::
	warp MAP_GOLDENROD_CITY_TRAIN_STATION, 0
	waitstate
	release
	end

RegionHub_EventScript_AttendantHoenn::
	lock
	faceplayer
	msgbox RegionHub_Text_TravelHoenn, MSGBOX_YESNO
	goto_if_eq VAR_RESULT, NO, RegionHub_EventScript_TravelDeclined
	setvar VAR_RESULT, 2
	callnative RegionHub_ScrEnterRegion
	callnative RegionHub_ScrTargetIntroDone
	closemessage
	goto_if_eq VAR_RESULT, 1, RegionHub_EventScript_ReturnHoenn
	warp MAP_LITTLEROOT_TOWN, 1
	waitstate
	release
	end

RegionHub_EventScript_ReturnHoenn::
	warp MAP_SLATEPORT_CITY_HARBOR, 0
	waitstate
	release
	end

@ Battle Frontier capstone - region-agnostic (no SetCurrentRegion; the destination MAPSEC
@ self-derives the region) and does NOT box the party. Gated OPEN for now; two-tier unlock TBD.
RegionHub_EventScript_AttendantFrontier::
	lock
	faceplayer
	msgbox RegionHub_Text_TravelFrontier, MSGBOX_YESNO
	goto_if_eq VAR_RESULT, NO, RegionHub_EventScript_TravelDeclined
	closemessage
	warp MAP_BATTLE_FRONTIER_OUTSIDE_WEST, 9
	waitstate
	release
	end

RegionHub_EventScript_TravelDeclined::
	closemessage
	release
	end

RegionHub_Text_TravelKanto:
	.string "This platform is bound for KANTO.\p"
	.string "Travel to KANTO?\p"
	.string "Your current team will be sent to\n"
	.string "the PC BOXES when you switch\l"
	.string "regions.$"

RegionHub_Text_TravelJohto:
	.string "This platform is bound for JOHTO.\p"
	.string "Travel to JOHTO?\p"
	.string "Your current team will be sent to\n"
	.string "the PC BOXES when you switch\l"
	.string "regions.$"

RegionHub_Text_TravelHoenn:
	.string "This platform is bound for HOENN.\p"
	.string "Travel to HOENN?\p"
	.string "Your current team will be sent to\n"
	.string "the PC BOXES when you switch\l"
	.string "regions.$"

RegionHub_Text_TravelFrontier:
	.string "Beyond this gate lies the\n"
	.string "BATTLE FRONTIER.\p"
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
