RegionHub_MapScripts::
	map_script MAP_SCRIPT_ON_TRANSITION, RegionHub_OnTransition
	.byte 0

@ World Transit hub - region-switch terminal rebuilt in the Indigo Plateau Pokemon Center
@ style (LAYOUT_REGION_HUB, an edited copy of the FRLG Indigo Plateau lobby). Travel is by
@ TALKING to a platform attendant and confirming; the old walk-on gate pads are gone. Each
@ region attendant sets the active region and boxes the carried party ONLY when crossing
@ regions (callnative RegionHub_ScrEnterRegion), then warps to the player's BEDROOM in that
@ region on a first visit (the region's new-game opening then plays out from home, like a
@ fresh start; Hoenn picks Brendan's/May's house by gender) or to its World Transit access
@ point on a return (RegionHub_ScrTargetIntroDone, D5). The Frontier attendant blocks the
@ old league door, is region-agnostic and never boxes
@ the party. Also here: the healing nurse (FRLG pattern; whiteout respawn is REGIONAL now - see task 5a below),
@ a storage PC (MB_PC metatile at (17,9)), the front-desk GENERAL MART on the west wall (all
@ balls + heals + the one-per-save TOWN MAP, see RegionHub_Items), the east-counter
@ specialist trio - TM vendor / Training vendor (vitamins-PP-feathers-mints) / Battle Depot
@ (evo stones + Linking Cord + held items) -
@ and the read-only world-tour scoreboard (R8) by the Frontier gate. Key-item
@ givers (KeyItemAvailabilityAudit S3): the Sky Charm keeper (F1), the Harbor Master in the
@ south hall (championship-gated event tickets + enable-ship flags) and the Charm Curator
@ north of the east counter (badge-tiered charms). The four gates line the NORTH DEPARTURE
@ CONCOURSE (west->east: Frontier at the old league door, then Kanto/Johto/Hoenn league-style
@ doors), each blocked by its attendant. Arrivals land on the concourse crest at (16,4) =
@ warp 0 (never triggers - plain floor tile, anchor only).
@
@ NOTE: the east-counter pocket (x=19-24, y=10-11) has NO walkable connection to the floor (a
@ BFS reachability trace over the layout's collision blockdata shows it walled on every side:
@ x=18 column, y=9 row, y=12 row) - vendors standing there are talk-across-the-counter only,
@ which is intentional.
@ (2026-07-16 consolidation) Vendors condensed 6 -> 4: the front desk absorbed all balls and
@ became the main general mart; the counter trio is TM (19,11) / Training (COOK, 21,11) /
@ Battle Depot (MART_EMPLOYEE, 23,11); the two south-hall vendors and the standalone
@ feather/mint vendors are GONE (stock covered by Training). 14 object events total, safely
@ under the OBJECT_EVENTS_COUNT=16 spawn cap (player + an active follower always fit).

@ Task 5a: the hub no longer arms itself as the whiteout respawn. Its PokeCenter is one of the
@ most OAM-starved maps (14 object events after the 2026-07-16 vendor consolidation) and the
@ heal animation can exhaust sprites there, so a
@ whiteout must never route back to it. The regional respawn is armed on gate-cross instead
@ (RegionHub_ScrEnterRegion -> SetRegionArrivalRespawn). No wild/trainer battles occur in the
@ hub, so it never needs to be a respawn target itself.
RegionHub_OnTransition::
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
	call RegionHub_EventScript_TryGiveHubPass
	setvar VAR_RESULT, 0
	callnative RegionHub_ScrEnterRegion
	callnative RegionHub_ScrTargetIntroDone
	closemessage
	goto_if_eq VAR_RESULT, 1, RegionHub_EventScript_ReturnKanto
	warp MAP_PALLET_TOWN_PLAYERS_HOUSE_2F, 6, 6
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
	call RegionHub_EventScript_TryGiveHubPass
	setvar VAR_RESULT, 1
	callnative RegionHub_ScrEnterRegion
	callnative RegionHub_ScrTargetIntroDone
	closemessage
	goto_if_eq VAR_RESULT, 1, RegionHub_EventScript_ReturnJohto
	warp MAP_NEW_BARK_TOWN_PLAYERS_HOUSE_2F, 1
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
	call RegionHub_EventScript_TryGiveHubPass
	setvar VAR_RESULT, 2
	callnative RegionHub_ScrEnterRegion
	callnative RegionHub_ScrTargetIntroDone
	closemessage
	goto_if_eq VAR_RESULT, 1, RegionHub_EventScript_ReturnHoenn
	@ The hub path skips the truck intro, whose scripts normally hide both
	@ house trucks - hide them here or two trucks render in Littleroot.
	setflag FLAG_HIDE_LITTLEROOT_TOWN_BRENDANS_HOUSE_TRUCK
	setflag FLAG_HIDE_LITTLEROOT_TOWN_MAYS_HOUSE_TRUCK
	checkplayergender
	goto_if_eq VAR_RESULT, FEMALE, RegionHub_EventScript_FirstVisitHoennFemale
	warp MAP_LITTLEROOT_TOWN_BRENDANS_HOUSE_2F, 4, 4
	waitstate
	release
	end

RegionHub_EventScript_FirstVisitHoennFemale::
	warp MAP_LITTLEROOT_TOWN_MAYS_HOUSE_2F, 4, 4
	waitstate
	release
	end

RegionHub_EventScript_ReturnHoenn::
	warp MAP_SLATEPORT_CITY_HARBOR, 0
	waitstate
	release
	end

@ Battle Frontier capstone - region-agnostic (no SetCurrentRegion; the destination MAPSEC
@ self-derives the region) and does NOT box the party. Gated on having cleared at least ONE
@ region's league (RegionHub_ScrIsAnyRegionChampion -> IsNRegionChampion(1)). The three-region
@ gate is a different thing: it guards the World Championship inside the Battle Dome lobby.
RegionHub_EventScript_AttendantFrontier::
	lock
	faceplayer
	callnative RegionHub_ScrIsAnyRegionChampion
	goto_if_eq VAR_RESULT, FALSE, RegionHub_EventScript_FrontierLocked
	msgbox RegionHub_Text_TravelFrontier, MSGBOX_YESNO
	goto_if_eq VAR_RESULT, NO, RegionHub_EventScript_TravelDeclined
	closemessage
	warp MAP_BATTLE_FRONTIER_RECEPTION_GATE, 0
	waitstate
	release
	end

RegionHub_EventScript_FrontierLocked::
	msgbox RegionHub_Text_FrontierLocked, MSGBOX_DEFAULT
	release
	end

RegionHub_EventScript_TravelDeclined::
	closemessage
	release
	end

@ Issue #22 Part 2: force-give the HUB PASS on any gate-cross confirm, BEFORE the party is
@ boxed (runs ahead of the setvar + RegionHub_ScrEnterRegion because giveitem clobbers
@ VAR_RESULT). checkitem-deduped and self-healing: a full KEY ITEMS pocket just retries on
@ the next cross, and the Charm Curator remains the backup giver. No flag advances on a
@ failed give, so nothing can strand.
RegionHub_EventScript_TryGiveHubPass::
	checkitem ITEM_HUB_RETURN
	goto_if_eq VAR_RESULT, TRUE, RegionHub_EventScript_HubPassDone
	msgbox RegionHub_Text_AttendantGiveHubPass, MSGBOX_DEFAULT
	giveitem ITEM_HUB_RETURN
	goto_if_eq VAR_RESULT, FALSE, RegionHub_EventScript_HubPassBagFull
RegionHub_EventScript_HubPassDone::
	return

RegionHub_EventScript_HubPassBagFull::
	msgbox RegionHub_Text_HubPassBagFull, MSGBOX_DEFAULT
	return

RegionHub_Text_TravelKanto:
	.string "This gate is bound for KANTO.\p"
	.string "Travel to KANTO?\p"
	.string "Your current team will be sent to\n"
	.string "the PC BOXES when you switch\l"
	.string "regions.$"

RegionHub_Text_TravelJohto:
	.string "This gate is bound for JOHTO.\p"
	.string "Travel to JOHTO?\p"
	.string "Your current team will be sent to\n"
	.string "the PC BOXES when you switch\l"
	.string "regions.$"

RegionHub_Text_TravelHoenn:
	.string "This gate is bound for HOENN.\p"
	.string "Travel to HOENN?\p"
	.string "Your current team will be sent to\n"
	.string "the PC BOXES when you switch\l"
	.string "regions.$"

RegionHub_Text_AttendantGiveHubPass:
	.string "First crossing? Then take your\n"
	.string "HUB PASS before you board.\p"
	.string "Use it from your BAG to warp back\n"
	.string "here to WORLD TRANSIT from\l"
	.string "anywhere in the world.$"

RegionHub_Text_HubPassBagFull:
	.string "Hm? Your KEY ITEMS pocket is full,\n"
	.string "so I can't hand you a HUB PASS.\p"
	.string "See the CURATOR by the east counter\n"
	.string "once you've made room.$"

RegionHub_Text_TravelFrontier:
	.string "Beyond this gate lies the\n"
	.string "BATTLE FRONTIER.\p"
	.string "Head to the BATTLE FRONTIER?$"

RegionHub_Text_FrontierLocked:
	.string "The BATTLE FRONTIER opens to TRAINERS\n"
	.string "who've conquered at least one region's\l"
	.string "POKéMON LEAGUE.\p"
	.string "Become a CHAMPION, then return.$"

@ F1: Sky Charm giver. Hands out the overworld free-flight key item once the player
@ can actually FLY -- i.e. holds the Fly HM AND has earned a region's Fly badge
@ (RegionHub_ScrCanFly mirrors the USE gate in field_move.c: IsFieldMoveUnlocked_Fly).
@ checkitem is the one-time gate: key items can't be tossed, so no dedicated flag is
@ needed.
RegionHub_EventScript_SkyCharmKeeper::
	lock
	faceplayer
	checkitem ITEM_SKY_CHARM
	goto_if_eq VAR_RESULT, TRUE, RegionHub_EventScript_SkyCharmAlreadyGiven
	callnative RegionHub_ScrCanFly
	goto_if_eq VAR_RESULT, FALSE, RegionHub_EventScript_SkyCharmNoBadge
	msgbox RegionHub_Text_SkyCharmGive, MSGBOX_DEFAULT
	giveitem ITEM_SKY_CHARM
	goto_if_eq VAR_RESULT, FALSE, Common_EventScript_ShowBagIsFull
	msgbox RegionHub_Text_SkyCharmExplain, MSGBOX_DEFAULT
	closemessage
	release
	end

RegionHub_EventScript_SkyCharmNoBadge::
	msgbox RegionHub_Text_SkyCharmComeBack, MSGBOX_DEFAULT
	release
	end

RegionHub_EventScript_SkyCharmAlreadyGiven::
	msgbox RegionHub_Text_SkyCharmEnjoy, MSGBOX_DEFAULT
	release
	end

RegionHub_Text_SkyCharmGive:
	.string "Well now! I can tell by your eyes -\n"
	.string "you've earned a GYM BADGE!\p"
	.string "A TRAINER the wild flyers respect\n"
	.string "deserves this.$"

RegionHub_Text_SkyCharmExplain:
	.string "That's the SKY CHARM.\p"
	.string "Use it under the open sky and a\n"
	.string "wild POKéMON will carry you over\l"
	.string "anything - once you hold the local\l"
	.string "BADGE that commands the skies.\p"
	.string "Use it again on solid ground\n"
	.string "to land.$"

RegionHub_Text_SkyCharmComeBack:
	.string "The wild flyers won't heed you yet.\p"
	.string "Come back once you've learned to\n"
	.string "FLY and earned the BADGE to\l"
	.string "command it.$"

RegionHub_Text_SkyCharmEnjoy:
	.string "How's the view from up there?\p"
	.string "Remember - the flyers won't carry\n"
	.string "you where you haven't won the\l"
	.string "BADGE that commands the skies.$"

@ World-tour board (R8): reads the three per-region badge banks (K9) and shows the running
@ 24-badge count + per-region breakdown. The grand 24-badge tournament is a future item;
@ this only reports progress. See .plans/features/03a Lane R R8.
@ Deep-review 2026-07-12 (leaderboard "nothing at all", reported x2): ROOT CAUSE was the
@ sign tile itself. The board art spans (2,1) wall-top + (2,2) floor-bottom, but (2,2) was
@ left WALKABLE, so pressing toward it walked the player ONTO it instead of facing it - a
@ sign only fires when faced, so it never triggered. FIX: (2,2) made impassable in
@ data/layouts/RegionHub/map.bin; the player now reads it from (2,3) facing north (event
@ moved to PLAYER_FACING_NORTH). Kept as a bg_event sign (NOT an object) - this map is
@ OAM-starved, and a sign costs no sprite slot. Uses lockall/releaseall + two MSGBOX_DEFAULT
@ (NOT MSGBOX_SIGN, which runs its own lock/release and would free the player mid-readout).
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

@ Hub front-desk GENERAL MART (2026-07-16 consolidation): all balls + top-tier heals + the
@ TOWN MAP (key item, price 0 -> rings up free; the shop lists it SOLD OUT once owned, so it
@ is one-per-save). Hub-local list so the real Indigo Plateau clerk stays untouched.
RegionHub_EventScript_Clerk::
	lock
	faceplayer
	message gText_HowMayIServeYou
	waitmessage
	pokemart RegionHub_Items
	msgbox gText_PleaseComeAgain
	release
	end

	.align 2
RegionHub_Items::
	.2byte ITEM_GREAT_BALL
	.2byte ITEM_ULTRA_BALL
	.2byte ITEM_NEST_BALL
	.2byte ITEM_NET_BALL
	.2byte ITEM_DIVE_BALL
	.2byte ITEM_TIMER_BALL
	.2byte ITEM_REPEAT_BALL
	.2byte ITEM_QUICK_BALL
	.2byte ITEM_DUSK_BALL
	.2byte ITEM_LUXURY_BALL
	.2byte ITEM_HEAL_BALL
	.2byte ITEM_PREMIER_BALL
	.2byte ITEM_FULL_RESTORE
	.2byte ITEM_MAX_POTION
	.2byte ITEM_MAX_REVIVE
	.2byte ITEM_FULL_HEAL
	.2byte ITEM_MAX_REPEL
	.2byte ITEM_TOWN_MAP
	pokemartlistend

@ Harbor Master (KeyItemAudit S3a): championship-gated event tickets. Each give ALSO sets
@ the matching FLAG_ENABLE_SHIP_* so the Lilycove and Vermilion counters honor the ticket,
@ not just Olivine's checkitem-only counter (the Aurora-Ticket bug this batch fixes).
@ Gates - conservative picks where the audit offered a choice:
@   EON TICKET     = champion of any ONE region (picked over "first 8 badges")
@   OLD SEA MAP    = champion of TWO regions (RegionHub_ScrIsTwoRegionChampion native)
@   MYSTIC TICKET  = champion of ALL THREE regions (picked over "24 badges" - consistent
@                    with the championship ladder; Lugia/Ho-Oh copies are endgame-only)
@ One ticket per chat, lowest tier first. checkitem guards + engine key-item dedup backstop.
@ AURORA TICKET stays with the Olivine woman (S2); POKEVIAL now ships from the Charm
@ Curator instead, as his unconditional intro gift (S3b addendum) - not through this desk.
RegionHub_EventScript_HarborMaster::
	lock
	faceplayer
	checkitem ITEM_EON_TICKET
	goto_if_eq VAR_RESULT, FALSE, RegionHub_EventScript_HarborTryEon
	checkitem ITEM_OLD_SEA_MAP
	goto_if_eq VAR_RESULT, FALSE, RegionHub_EventScript_HarborTryOldSeaMap
	checkitem ITEM_MYSTIC_TICKET
	goto_if_eq VAR_RESULT, FALSE, RegionHub_EventScript_HarborTryMystic
	msgbox RegionHub_Text_HarborAllGiven, MSGBOX_DEFAULT
	release
	end

RegionHub_EventScript_HarborTryEon::
	goto_if_set FLAG_KANTO_CHAMPION, RegionHub_EventScript_HarborGiveEon
	goto_if_set FLAG_JOHTO_CHAMPION, RegionHub_EventScript_HarborGiveEon
	goto_if_set FLAG_HOENN_CHAMPION, RegionHub_EventScript_HarborGiveEon
	msgbox RegionHub_Text_HarborNeedOneChamp, MSGBOX_DEFAULT
	release
	end

RegionHub_EventScript_HarborGiveEon::
	msgbox RegionHub_Text_HarborGiveEon, MSGBOX_DEFAULT
	giveitem ITEM_EON_TICKET
	goto_if_eq VAR_RESULT, FALSE, Common_EventScript_ShowBagIsFull
	setflag FLAG_ENABLE_SHIP_SOUTHERN_ISLAND
	msgbox RegionHub_Text_HarborEonExplain, MSGBOX_DEFAULT
	closemessage
	release
	end

RegionHub_EventScript_HarborTryOldSeaMap::
	callnative RegionHub_ScrIsTwoRegionChampion
	goto_if_eq VAR_RESULT, TRUE, RegionHub_EventScript_HarborGiveOldSeaMap
	msgbox RegionHub_Text_HarborNeedTwoChamps, MSGBOX_DEFAULT
	release
	end

RegionHub_EventScript_HarborGiveOldSeaMap::
	msgbox RegionHub_Text_HarborGiveOldSeaMap, MSGBOX_DEFAULT
	giveitem ITEM_OLD_SEA_MAP
	goto_if_eq VAR_RESULT, FALSE, Common_EventScript_ShowBagIsFull
	setflag FLAG_ENABLE_SHIP_FARAWAY_ISLAND
	msgbox RegionHub_Text_HarborOldSeaMapExplain, MSGBOX_DEFAULT
	closemessage
	release
	end

RegionHub_EventScript_HarborTryMystic::
	goto_if_unset FLAG_KANTO_CHAMPION, RegionHub_EventScript_HarborNeedThreeChamps
	goto_if_unset FLAG_JOHTO_CHAMPION, RegionHub_EventScript_HarborNeedThreeChamps
	goto_if_unset FLAG_HOENN_CHAMPION, RegionHub_EventScript_HarborNeedThreeChamps
	msgbox RegionHub_Text_HarborGiveMystic, MSGBOX_DEFAULT
	giveitem ITEM_MYSTIC_TICKET
	goto_if_eq VAR_RESULT, FALSE, Common_EventScript_ShowBagIsFull
	setflag FLAG_ENABLE_SHIP_NAVEL_ROCK
	msgbox RegionHub_Text_HarborMysticExplain, MSGBOX_DEFAULT
	closemessage
	release
	end

RegionHub_EventScript_HarborNeedThreeChamps::
	msgbox RegionHub_Text_HarborNeedThreeChamps, MSGBOX_DEFAULT
	release
	end

RegionHub_Text_HarborNeedOneChamp:
	.string "Welcome to the harbor desk!\p"
	.string "I hold ferry passes for waters\n"
	.string "no regular route serves.\p"
	.string "But rules are rules - only a\n"
	.string "LEAGUE CHAMPION may book one.\p"
	.string "Become the champion of any\n"
	.string "region and come see me!$"

RegionHub_Text_HarborGiveEon:
	.string "You've conquered a POKéMON\n"
	.string "LEAGUE! Then this is yours.$"

RegionHub_Text_HarborEonExplain:
	.string "That's the EON TICKET.\p"
	.string "Show it at the LILYCOVE or\n"
	.string "OLIVINE harbor to sail for the\l"
	.string "SOUTHERN ISLAND.\p"
	.string "They say a pair of legendary\n"
	.string "POKéMON nests there…$"

RegionHub_Text_HarborNeedTwoChamps:
	.string "That EON TICKET suits you!\p"
	.string "I do hold another pass, but it's\n"
	.string "reserved for champions of TWO\l"
	.string "regions.\p"
	.string "Keep your world tour going!$"

RegionHub_Text_HarborGiveOldSeaMap:
	.string "Two LEAGUES conquered! You're\n"
	.string "a true seafarer. Take this.$"

RegionHub_Text_HarborOldSeaMapExplain:
	.string "That's the OLD SEA MAP.\p"
	.string "Show it at the LILYCOVE or\n"
	.string "OLIVINE harbor to sail for\l"
	.string "FARAWAY ISLAND.\p"
	.string "A mythical POKéMON is said to\n"
	.string "wander in its fog…$"

RegionHub_Text_HarborNeedThreeChamps:
	.string "The last pass I keep is for the\n"
	.string "true master of the world tour -\l"
	.string "the champion of KANTO, JOHTO,\l"
	.string "and HOENN alike.$"

RegionHub_Text_HarborGiveMystic:
	.string "Champion of KANTO, JOHTO, and\n"
	.string "HOENN… Incredible!\p"
	.string "My finest pass is yours.$"

RegionHub_Text_HarborMysticExplain:
	.string "That's the MYSTIC TICKET.\p"
	.string "Show it at the LILYCOVE or\n"
	.string "VERMILION harbor to sail for\l"
	.string "NAVEL ROCK.\p"
	.string "Two legendary POKéMON slumber\n"
	.string "at its peak.$"

RegionHub_Text_HarborAllGiven:
	.string "Every special pass I had is in\n"
	.string "your hands.\p"
	.string "Fair winds, champion!$"

@ Charm Curator (KeyItemAudit S3b): badge-tiered charm ladder off the world-tour badge
@ count (all three regions): 4 CATCHING CHARM / 8 EXP. CHARM / 12 OVAL CHARM /
@ 16 POKeMON BOX LINK / 24 SHINY CHARM. Sky-Charm-keeper clone: checkitem one-time gates,
@ one reward per chat, lowest tier first. VAR_0x8000 (badge total) is read before any
@ giveitem, which clobbers VAR_0x8000/0x8001.
@ S3b addendum: ahead of the ladder he also hands out the POKEVIAL, unconditionally (no
@ badge requirement) and only once - checkitem gates it, same one-time pattern as the
@ ladder tiers, and it runs (and can clobber VAR_0x8000/0x8001 via its own giveitem) BEFORE
@ RegionHub_ScrCountWorldTourBadges refreshes those vars for the ladder below, so it can't
@ desync the badge check.
RegionHub_EventScript_CharmCurator::
	lock
	faceplayer
	checkitem ITEM_HUB_RETURN
	goto_if_eq VAR_RESULT, TRUE, RegionHub_EventScript_CuratorCheckPokevial
	msgbox RegionHub_Text_CuratorGiveHubPass, MSGBOX_DEFAULT
	giveitem ITEM_HUB_RETURN
	goto_if_eq VAR_RESULT, FALSE, Common_EventScript_ShowBagIsFull
RegionHub_EventScript_CuratorCheckPokevial::
	checkitem ITEM_POKEVIAL
	goto_if_eq VAR_RESULT, TRUE, RegionHub_EventScript_CuratorLadder
	msgbox RegionHub_Text_CuratorGivePokevial, MSGBOX_DEFAULT
	giveitem ITEM_POKEVIAL
	goto_if_eq VAR_RESULT, FALSE, Common_EventScript_ShowBagIsFull
	msgbox RegionHub_Text_CuratorPokevialExplain, MSGBOX_DEFAULT

RegionHub_EventScript_CuratorLadder::
	callnative RegionHub_ScrCountWorldTourBadges
	checkitem ITEM_CATCHING_CHARM
	goto_if_eq VAR_RESULT, FALSE, RegionHub_EventScript_CuratorTryCatching
	checkitem ITEM_EXP_CHARM
	goto_if_eq VAR_RESULT, FALSE, RegionHub_EventScript_CuratorTryExp
	checkitem ITEM_OVAL_CHARM
	goto_if_eq VAR_RESULT, FALSE, RegionHub_EventScript_CuratorTryOval
	checkitem ITEM_SHINY_CHARM
	goto_if_eq VAR_RESULT, FALSE, RegionHub_EventScript_CuratorTryShiny
	checkitem ITEM_EV_IV_CHANGER
	goto_if_eq VAR_RESULT, FALSE, RegionHub_EventScript_CuratorTryEvIvChanger
	msgbox RegionHub_Text_CuratorAllGiven, MSGBOX_DEFAULT
	release
	end

RegionHub_EventScript_CuratorTryCatching::
	goto_if_ge VAR_0x8000, 4, RegionHub_EventScript_CuratorGiveCatching
	msgbox RegionHub_Text_CuratorNeed4, MSGBOX_DEFAULT
	release
	end

RegionHub_EventScript_CuratorGiveCatching::
	msgbox RegionHub_Text_CuratorGiveCatching, MSGBOX_DEFAULT
	giveitem ITEM_CATCHING_CHARM
	goto_if_eq VAR_RESULT, FALSE, Common_EventScript_ShowBagIsFull
	msgbox RegionHub_Text_CuratorCatchingExplain, MSGBOX_DEFAULT
	closemessage
	release
	end

RegionHub_EventScript_CuratorTryExp::
	goto_if_ge VAR_0x8000, 8, RegionHub_EventScript_CuratorGiveExp
	msgbox RegionHub_Text_CuratorNeed8, MSGBOX_DEFAULT
	release
	end

RegionHub_EventScript_CuratorGiveExp::
	msgbox RegionHub_Text_CuratorGiveExp, MSGBOX_DEFAULT
	giveitem ITEM_EXP_CHARM
	goto_if_eq VAR_RESULT, FALSE, Common_EventScript_ShowBagIsFull
	msgbox RegionHub_Text_CuratorExpExplain, MSGBOX_DEFAULT
	closemessage
	release
	end

RegionHub_EventScript_CuratorTryOval::
	goto_if_ge VAR_0x8000, 12, RegionHub_EventScript_CuratorGiveOval
	msgbox RegionHub_Text_CuratorNeed12, MSGBOX_DEFAULT
	release
	end

RegionHub_EventScript_CuratorGiveOval::
	msgbox RegionHub_Text_CuratorGiveOval, MSGBOX_DEFAULT
	giveitem ITEM_OVAL_CHARM
	goto_if_eq VAR_RESULT, FALSE, Common_EventScript_ShowBagIsFull
	msgbox RegionHub_Text_CuratorOvalExplain, MSGBOX_DEFAULT
	closemessage
	release
	end

RegionHub_EventScript_CuratorTryShiny::
	goto_if_ge VAR_0x8000, 16, RegionHub_EventScript_CuratorGiveShiny
	msgbox RegionHub_Text_CuratorNeed16, MSGBOX_DEFAULT
	release
	end

RegionHub_EventScript_CuratorGiveShiny::
	msgbox RegionHub_Text_CuratorGiveShiny, MSGBOX_DEFAULT
	giveitem ITEM_SHINY_CHARM
	goto_if_eq VAR_RESULT, FALSE, Common_EventScript_ShowBagIsFull
	msgbox RegionHub_Text_CuratorShinyExplain, MSGBOX_DEFAULT
	closemessage
	release
	end

RegionHub_EventScript_CuratorTryEvIvChanger::
	goto_if_ge VAR_0x8000, 24, RegionHub_EventScript_CuratorGiveEvIvChanger
	msgbox RegionHub_Text_CuratorNeed24, MSGBOX_DEFAULT
	release
	end

RegionHub_EventScript_CuratorGiveEvIvChanger::
	msgbox RegionHub_Text_CuratorGiveEvIvChanger, MSGBOX_DEFAULT
	giveitem ITEM_EV_IV_CHANGER
	goto_if_eq VAR_RESULT, FALSE, Common_EventScript_ShowBagIsFull
	msgbox RegionHub_Text_CuratorEvIvChangerExplain, MSGBOX_DEFAULT
	closemessage
	release
	end

RegionHub_Text_CuratorGiveHubPass:
	.string "Oh, new around here? Then first,\n"
	.string "every traveler gets a HUB PASS.\p"
	.string "Use it from your BAG and you'll\n"
	.string "warp right back here to WORLD\l"
	.string "TRANSIT from anywhere in the world.$"

RegionHub_Text_CuratorGivePokevial:
	.string "And take one of these, too.\p"
	.string "Every traveler gets one of\n"
	.string "these from me.$"

RegionHub_Text_CuratorPokevialExplain:
	.string "That's the POKéVIAL.\p"
	.string "Use it from your BAG to heal your\n"
	.string "whole team, anywhere you stand.$"

RegionHub_Text_CuratorNeed4:
	.string "I collect rare charms and award\n"
	.string "them to proven TRAINERS.\p"
	.string "Earn 4 GYM BADGES across the\n"
	.string "world and I'll part with my\l"
	.string "first.$"

RegionHub_Text_CuratorGiveCatching:
	.string "You carry 4 BADGES! As promised,\n"
	.string "my first charm is yours.$"

RegionHub_Text_CuratorCatchingExplain:
	.string "That's the CATCHING CHARM.\p"
	.string "With it in your BAG, the POKé\n"
	.string "BALLS you throw will land\l"
	.string "critical catches more often.$"

RegionHub_Text_CuratorNeed8:
	.string "The next charm calls for 8 GYM\n"
	.string "BADGES. Keep at it!$"

RegionHub_Text_CuratorGiveExp:
	.string "8 BADGES - splendid!\n"
	.string "Take this.$"

RegionHub_Text_CuratorExpExplain:
	.string "That's the EXP. CHARM.\p"
	.string "Your whole team will grow\n"
	.string "faster while it's in your BAG.$"

RegionHub_Text_CuratorNeed12:
	.string "The next charm calls for 12 GYM\n"
	.string "BADGES across the world.$"

RegionHub_Text_CuratorGiveOval:
	.string "12 BADGES! You've more than\n"
	.string "earned this.$"

RegionHub_Text_CuratorOvalExplain:
	.string "That's the OVAL CHARM.\p"
	.string "POKéMON at the DAY CARE will\n"
	.string "discover EGGS more often.$"

RegionHub_Text_CuratorNeed16:
	.string "One charm remains - my life's\n"
	.string "prize.\p"
	.string "Bring me 16 GYM BADGES - two\n"
	.string "regions' worth - and it's yours.$"

RegionHub_Text_CuratorGiveShiny:
	.string "16 GYM BADGES - two regions\n"
	.string "conquered! Magnificent!\p"
	.string "My greatest treasure is yours.$"

RegionHub_Text_CuratorShinyExplain:
	.string "That's the SHINY CHARM.\p"
	.string "With it, you're far more likely\n"
	.string "to meet POKéMON of rare color.$"

RegionHub_Text_CuratorNeed24:
	.string "One gift beyond my charms\n"
	.string "remains.\p"
	.string "Bring me all 24 GYM BADGES\n"
	.string "and it is yours.$"

RegionHub_Text_CuratorGiveEvIvChanger:
	.string "All 24 GYM BADGES! Every\n"
	.string "region bows to you.\p"
	.string "Take this parting gift.$"

RegionHub_Text_CuratorEvIvChangerExplain:
	.string "That's the EV/IV CHANGER.\p"
	.string "Tune any POKéMON's EVs and\n"
	.string "IVs up or down, any time.\p"
	.string "Press R inside its menu to\n"
	.string "flip between EVs and IVs.\p"
	.string "UP/DOWN picks a stat,\n"
	.string "LEFT/RIGHT adjusts it.\p"
	.string "Hold LEFT/RIGHT to change\n"
	.string "it in steps of ten.$"

RegionHub_Text_CuratorAllGiven:
	.string "My whole collection is in your\n"
	.string "hands.\p"
	.string "Wear those charms proudly!$"

@ Dex reward researcher (SCIENTIST_1) at (11,7) on the main hall row. Escalating one-time
@ prizes for caught-species milestones. The count comes from RegionHub_ScrGetCaughtCount
@ (no script special exposes GetNationalPokedexCount); tier 3 uses HasAllMons() - the
@ diploma's own completion test - via RegionHub_ScrHasCompletedDex. VAR_0x8000 holds the
@ preserved count: giveitem clobbers VAR_RESULT and VAR_0x8000/0x8001, so every threshold
@ compare and the number buffer run BEFORE any giveitem. Tiers are checked high->low; each
@ visit awards at most the highest still-unclaimed tier the player qualifies for. The flag
@ is only set after a successful give, so a bag-full player can return to claim.
RegionHub_EventScript_DexReward::
	lock
	faceplayer
	callnative RegionHub_ScrGetCaughtCount
	copyvar VAR_0x8000, VAR_RESULT
	goto_if_set FLAG_DEX_REWARD_3, RegionHub_EventScript_DexRewardTier2
	callnative RegionHub_ScrHasCompletedDex
	goto_if_eq VAR_RESULT, TRUE, RegionHub_EventScript_DexRewardGiveTier3
RegionHub_EventScript_DexRewardTier2::
	goto_if_set FLAG_DEX_REWARD_2, RegionHub_EventScript_DexRewardTier1
	goto_if_ge VAR_0x8000, 300, RegionHub_EventScript_DexRewardGiveTier2
RegionHub_EventScript_DexRewardTier1::
	goto_if_set FLAG_DEX_REWARD_1, RegionHub_EventScript_DexRewardProgress
	goto_if_ge VAR_0x8000, 150, RegionHub_EventScript_DexRewardGiveTier1
RegionHub_EventScript_DexRewardProgress::
	goto_if_unset FLAG_DEX_REWARD_1, RegionHub_EventScript_DexRewardShowCount
	goto_if_unset FLAG_DEX_REWARD_2, RegionHub_EventScript_DexRewardShowCount
	goto_if_unset FLAG_DEX_REWARD_3, RegionHub_EventScript_DexRewardShowCount
	msgbox RegionHub_Text_DexRewardAllDone, MSGBOX_DEFAULT
	release
	end

RegionHub_EventScript_DexRewardShowCount::
	buffernumberstring 0, VAR_0x8000
	msgbox RegionHub_Text_DexRewardProgress, MSGBOX_DEFAULT
	release
	end

RegionHub_EventScript_DexRewardGiveTier1::
	msgbox RegionHub_Text_DexRewardGiveTier1, MSGBOX_DEFAULT
	giveitem ITEM_PP_MAX
	goto_if_eq VAR_RESULT, FALSE, Common_EventScript_ShowBagIsFull
	setflag FLAG_DEX_REWARD_1
	msgbox RegionHub_Text_DexRewardTier1Explain, MSGBOX_DEFAULT
	closemessage
	release
	end

RegionHub_EventScript_DexRewardGiveTier2::
	msgbox RegionHub_Text_DexRewardGiveTier2, MSGBOX_DEFAULT
	giveitem ITEM_MASTER_BALL
	goto_if_eq VAR_RESULT, FALSE, Common_EventScript_ShowBagIsFull
	setflag FLAG_DEX_REWARD_2
	msgbox RegionHub_Text_DexRewardTier2Explain, MSGBOX_DEFAULT
	closemessage
	release
	end

RegionHub_EventScript_DexRewardGiveTier3::
	msgbox RegionHub_Text_DexRewardGiveTier3, MSGBOX_DEFAULT
	giveitem ITEM_RARE_CANDY, 10
	goto_if_eq VAR_RESULT, FALSE, Common_EventScript_ShowBagIsFull
	setflag FLAG_DEX_REWARD_3
	msgbox RegionHub_Text_DexRewardDiploma, MSGBOX_DEFAULT
	closemessage
	release
	end

RegionHub_Text_DexRewardProgress:
	.string "Cataloguing the world's POKéMON,\n"
	.string "are you?\p"
	.string "My records show you've caught\n"
	.string "{STR_VAR_1} so far.\p"
	.string "Milestones at 150, 300, and the\n"
	.string "full POKéDEX earn rewards!$"

RegionHub_Text_DexRewardGiveTier1:
	.string "150 species caught! Marvelous\n"
	.string "field work.\p"
	.string "Take this for your efforts.$"

RegionHub_Text_DexRewardTier1Explain:
	.string "That's a PP MAX - it pushes a move's\n"
	.string "PP to its very limit.\p"
	.string "Now, 300 species is the next\n"
	.string "milestone. Off you go!$"

RegionHub_Text_DexRewardGiveTier2:
	.string "300 species! You've seen more of\n"
	.string "this world than most ever will.\p"
	.string "This belongs with a TRAINER like\n"
	.string "you.$"

RegionHub_Text_DexRewardTier2Explain:
	.string "A MASTER BALL - it catches any\n"
	.string "POKéMON without fail.\p"
	.string "Only one goal remains: complete\n"
	.string "the entire POKéDEX!$"

RegionHub_Text_DexRewardGiveTier3:
	.string "The POKéDEX… complete.\p"
	.string "Every POKéMON in the world,\n"
	.string "recorded by your hand.\p"
	.string "Please, accept this.$"

RegionHub_Text_DexRewardDiploma:
	.string "Those RARE CANDIES are yours,\n"
	.string "and with them, my personal DIPLOMA.\p"
	.string "I hereby certify you the finest\n"
	.string "POKéMON researcher alive.\p"
	.string "Your name will be remembered\n"
	.string "wherever POKéMON are studied!$"

RegionHub_Text_DexRewardAllDone:
	.string "My friend! Every reward I have is\n"
	.string "already yours.\p"
	.string "Thank you - your POKéDEX is the\n"
	.string "finest record I've ever seen.$"

@ QoL 2026-07-12 (mint/feather vendors + TM consolidation, backlog item 6):
@ The old 4F attack/defense TM split-counter pair (x=23/24, y=11) sold TMs from a back-room
@ pocket that a reachability trace (BFS over the layout's own collision data) shows has NO
@ walkable connection to the rest of the map - x=18 walls it off on every side and the pocket
@ never reconnects. That's a pre-existing bug affecting all 6 borrowed department-store
@ clerks parked there, out of scope here and flagged separately. The 2 TM counters are pulled
@ from that dead pocket and merged into ONE vendor here on open, reachable floor, preserving
@ the full 8-TM selection. Mint + feather vendors sit alongside it, same row.
RegionHub_EventScript_TmVendor::
	lock
	faceplayer
	message gText_HowMayIServeYou
	waitmessage
	pokemart RegionHub_Items_Tms
	msgbox gText_PleaseComeAgain
	release
	end

	.align 2
RegionHub_Items_Tms::
	.2byte ITEM_TM_FIRE_BLAST
	.2byte ITEM_TM_THUNDER
	.2byte ITEM_TM_BLIZZARD
	.2byte ITEM_TM_HYPER_BEAM
	.2byte ITEM_TM_PROTECT
	.2byte ITEM_TM_SAFEGUARD
	.2byte ITEM_TM_REFLECT
	.2byte ITEM_TM_LIGHT_SCREEN
	.2byte ITEM_TM_EARTHQUAKE
	.2byte ITEM_TM_ICE_BEAM
	.2byte ITEM_TM_THUNDERBOLT
	.2byte ITEM_TM_FLAMETHROWER
	.2byte ITEM_TM_SHADOW_BALL
	.2byte ITEM_TM_PSYCHIC
	.2byte ITEM_TM_CALM_MIND
	.2byte ITEM_TM_DRAGON_CLAW
	pokemartlistend

@ East-counter Battle Depot (2026-07-16 consolidation): evo stones + Linking Cord + held
@ items. Specialty balls moved to the front-desk general mart.
RegionHub_EventScript_BattleDepot::
	lock
	faceplayer
	message gText_HowMayIServeYou
	waitmessage
	pokemart RegionHub_Items_BattleDepot
	msgbox gText_PleaseComeAgain
	release
	end

	.align 2
RegionHub_Items_BattleDepot::
	.2byte ITEM_FIRE_STONE
	.2byte ITEM_WATER_STONE
	.2byte ITEM_THUNDER_STONE
	.2byte ITEM_LEAF_STONE
	.2byte ITEM_MOON_STONE
	.2byte ITEM_SUN_STONE
	.2byte ITEM_SHINY_STONE
	.2byte ITEM_DUSK_STONE
	.2byte ITEM_DAWN_STONE
	.2byte ITEM_ICE_STONE
	.2byte ITEM_EVERSTONE
	.2byte ITEM_LINKING_CORD
	.2byte ITEM_LEFTOVERS
	.2byte ITEM_CHOICE_BAND
	.2byte ITEM_CHOICE_SPECS
	.2byte ITEM_CHOICE_SCARF
	.2byte ITEM_LIFE_ORB
	.2byte ITEM_FOCUS_SASH
	.2byte ITEM_ASSAULT_VEST
	.2byte ITEM_ROCKY_HELMET
	.2byte ITEM_EVIOLITE
	.2byte ITEM_MENTAL_HERB
	.2byte ITEM_POWER_HERB
	.2byte ITEM_WHITE_HERB
	pokemartlistend

@ East-counter Training vendor: vitamins + PP Up/Max + all feathers + all mints
@ (FLAG_MINTS enable owned by another lane).
RegionHub_EventScript_VitaminVendor::
	lock
	faceplayer
	message gText_HowMayIServeYou
	waitmessage
	pokemart RegionHub_Items_Vitamins
	msgbox gText_PleaseComeAgain
	release
	end

	.align 2
RegionHub_Items_Vitamins::
	.2byte ITEM_HP_UP
	.2byte ITEM_PROTEIN
	.2byte ITEM_IRON
	.2byte ITEM_CALCIUM
	.2byte ITEM_ZINC
	.2byte ITEM_CARBOS
	.2byte ITEM_PP_UP
	.2byte ITEM_PP_MAX
	.2byte ITEM_HEALTH_FEATHER
	.2byte ITEM_MUSCLE_FEATHER
	.2byte ITEM_RESIST_FEATHER
	.2byte ITEM_GENIUS_FEATHER
	.2byte ITEM_CLEVER_FEATHER
	.2byte ITEM_SWIFT_FEATHER
	.2byte ITEM_LONELY_MINT
	.2byte ITEM_ADAMANT_MINT
	.2byte ITEM_NAUGHTY_MINT
	.2byte ITEM_BRAVE_MINT
	.2byte ITEM_BOLD_MINT
	.2byte ITEM_IMPISH_MINT
	.2byte ITEM_LAX_MINT
	.2byte ITEM_RELAXED_MINT
	.2byte ITEM_MODEST_MINT
	.2byte ITEM_MILD_MINT
	.2byte ITEM_RASH_MINT
	.2byte ITEM_QUIET_MINT
	.2byte ITEM_CALM_MINT
	.2byte ITEM_GENTLE_MINT
	.2byte ITEM_CAREFUL_MINT
	.2byte ITEM_SASSY_MINT
	.2byte ITEM_TIMID_MINT
	.2byte ITEM_HASTY_MINT
	.2byte ITEM_JOLLY_MINT
	.2byte ITEM_NAIVE_MINT
	.2byte ITEM_SERIOUS_MINT
	pokemartlistend

