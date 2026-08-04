NavelRock_Harbor_MapScripts::
	.byte 0

NavelRock_Harbor_EventScript_Sailor::
	lock
	faceplayer
	msgbox NavelRock_Harbor_Text_SailorReturn, MSGBOX_YESNO
	goto_if_eq VAR_RESULT, NO, NavelRock_Harbor_EventScript_AsYouLike
	msgbox EventTicket_Text_SailHome, MSGBOX_DEFAULT
	closemessage
	applymovement VAR_LAST_TALKED, Common_Movement_WalkInPlaceFasterDown
	waitmovement 0
	delay 30
	hideobjectat LOCALID_NAVEL_ROCK_SAILOR, MAP_NAVEL_ROCK_HARBOR
	setvar VAR_0x8004, LOCALID_NAVEL_ROCK_SS_TIDAL
	call Common_EventScript_FerryDepartIsland
	@ Home is OLIVINE if the trip was booked there, VERMILION if it was booked in KANTO
	@ (issue #69) - see the region note on Common_EventScript_FerrySailHomeFromIsland in
	@ data/event_scripts.s. This map is the HOENN Navel Rock harbour, reachable only from
	@ LILYCOVE, so in practice the shared script still lands every real trip back at LILYCOVE;
	@ KANTO's MYSTIC TICKET run goes to MAP_NAVEL_ROCK_HARBOR_FRLG instead, which has its own
	@ sailor home to VERMILION. This is here so all four event islands share one way home
	@ rather than three sharing one and this one carrying a private copy that would have to be
	@ remembered separately the next time a harbour is added.
	goto Common_EventScript_FerrySailHomeFromIsland
	end

NavelRock_Harbor_EventScript_AsYouLike::
	msgbox EventTicket_Text_AsYouLike, MSGBOX_DEFAULT
	release
	end

