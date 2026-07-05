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
@ a storage PC (MB_PC metatile at (17,9)), the front-desk mart (Indigo clerk inventory plus
@ the TOWN MAP - hub-local list, see RegionHub_Items), six department-store vendors (Lilycove
@ 2F/3F/4F inventories) behind the east counter, and the read-only world-tour scoreboard (R8)
@ by the Frontier gate. Key-item givers (KeyItemAvailabilityAudit S3): the Sky Charm keeper
@ (F1), the Harbor Master in the south hall (championship-gated event tickets + enable-ship
@ flags) and the Charm Curator north of the east counter (badge-tiered charms). The four gates line the NORTH
@ DEPARTURE CONCOURSE (west->east: Frontier at the old league door, then Kanto/Johto/Hoenn
@ league-style doors), each blocked by its attendant. Arrivals land on the concourse crest
@ at (16,4) = warp 0 (never triggers - plain floor tile, anchor only).

@ Task 5a: the hub no longer arms itself as the whiteout respawn. Its PokeCenter is the most
@ OAM-starved map (15 object events since the Harbor Master + Charm Curator were added -
@ playtest for sprite drop-out) and the heal animation can exhaust sprites there, so a
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
@ self-derives the region) and does NOT box the party. Gated OPEN for now; two-tier unlock TBD.
RegionHub_EventScript_AttendantFrontier::
	lock
	faceplayer
	msgbox RegionHub_Text_TravelFrontier, MSGBOX_YESNO
	goto_if_eq VAR_RESULT, NO, RegionHub_EventScript_TravelDeclined
	closemessage
	warp MAP_BATTLE_FRONTIER_RECEPTION_GATE, 0
	waitstate
	release
	end

RegionHub_EventScript_TravelDeclined::
	closemessage
	release
	end

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

RegionHub_Text_TravelFrontier:
	.string "Beyond this gate lies the\n"
	.string "BATTLE FRONTIER.\p"
	.string "Head to the BATTLE FRONTIER?$"

@ F1: Sky Charm giver. Hands out the overworld free-flight key item once the player
@ has earned at least ONE badge in ANY region (reuses the world-tour badge counter,
@ which reads all three per-region badge banks). checkitem is the one-time gate:
@ key items can't be tossed, so no dedicated flag is needed.
RegionHub_EventScript_SkyCharmKeeper::
	lock
	faceplayer
	checkitem ITEM_SKY_CHARM
	goto_if_eq VAR_RESULT, TRUE, RegionHub_EventScript_SkyCharmAlreadyGiven
	callnative RegionHub_ScrCountWorldTourBadges
	goto_if_eq VAR_0x8000, 0, RegionHub_EventScript_SkyCharmNoBadge
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
	.string "Well now! I can tell by your eyes-\n"
	.string "you've earned a GYM BADGE!\p"
	.string "A TRAINER the wild flyers respect\n"
	.string "deserves this.$"

RegionHub_Text_SkyCharmExplain:
	.string "That's the SKY CHARM.\p"
	.string "Use it under the open sky and a\n"
	.string "wild POKéMON will carry you over\l"
	.string "anything-once you hold the local\l"
	.string "BADGE that commands the skies.\p"
	.string "Use it again on solid ground\n"
	.string "to land.$"

RegionHub_Text_SkyCharmComeBack:
	.string "The wild flyers only answer to\n"
	.string "TRAINERS who've proven themselves.\p"
	.string "Come back once you've earned a\n"
	.string "GYM BADGE-any region will do.$"

RegionHub_Text_SkyCharmEnjoy:
	.string "How's the view from up there?\p"
	.string "Remember-the flyers won't carry\n"
	.string "you where you haven't won the\l"
	.string "BADGE that commands the skies.$"

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

@ Hub front-desk mart: the Indigo Plateau inventory plus the TOWN MAP (key item, price 0 ->
@ rings up free; the shop lists it SOLD OUT once owned, so it is one-per-save). Hub-local
@ copy of the list so the real Indigo Plateau clerk stays untouched (KeyItemAudit S3c).
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
	.2byte ITEM_ULTRA_BALL
	.2byte ITEM_GREAT_BALL
	.2byte ITEM_FULL_RESTORE
	.2byte ITEM_MAX_POTION
	.2byte ITEM_REVIVE
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
	.string "But rules are rules-only a\n"
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
	.string "true master of the world tour-\l"
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
	checkitem ITEM_POKEMON_BOX_LINK
	goto_if_eq VAR_RESULT, FALSE, RegionHub_EventScript_CuratorTryBoxLink
	checkitem ITEM_SHINY_CHARM
	goto_if_eq VAR_RESULT, FALSE, RegionHub_EventScript_CuratorTryShiny
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

RegionHub_EventScript_CuratorTryBoxLink::
	goto_if_ge VAR_0x8000, 16, RegionHub_EventScript_CuratorGiveBoxLink
	msgbox RegionHub_Text_CuratorNeed16, MSGBOX_DEFAULT
	release
	end

RegionHub_EventScript_CuratorGiveBoxLink::
	msgbox RegionHub_Text_CuratorGiveBoxLink, MSGBOX_DEFAULT
	giveitem ITEM_POKEMON_BOX_LINK
	goto_if_eq VAR_RESULT, FALSE, Common_EventScript_ShowBagIsFull
	msgbox RegionHub_Text_CuratorBoxLinkExplain, MSGBOX_DEFAULT
	closemessage
	release
	end

RegionHub_EventScript_CuratorTryShiny::
	goto_if_ge VAR_0x8000, 24, RegionHub_EventScript_CuratorGiveShiny
	msgbox RegionHub_Text_CuratorNeed24, MSGBOX_DEFAULT
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

RegionHub_Text_CuratorGivePokevial:
	.string "Oh, new around here? Then first,\n"
	.string "every traveler gets one of\l"
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
	.string "8 BADGES-splendid!\n"
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
	.string "My next treasure waits for a\n"
	.string "TRAINER holding 16 GYM BADGES.$"

RegionHub_Text_CuratorGiveBoxLink:
	.string "16 BADGES-two full regions'\n"
	.string "worth! This is for you.$"

RegionHub_Text_CuratorBoxLinkExplain:
	.string "That's the POKéMON BOX LINK.\p"
	.string "It opens your storage BOXES\n"
	.string "from the BAG, wherever you are.$"

RegionHub_Text_CuratorNeed24:
	.string "One charm remains-my life's\n"
	.string "prize.\p"
	.string "Bring me all 24 GYM BADGES and\n"
	.string "it's yours.$"

RegionHub_Text_CuratorGiveShiny:
	.string "All 24 GYM BADGES…\n"
	.string "You are the world's finest!\p"
	.string "My greatest treasure is yours.$"

RegionHub_Text_CuratorShinyExplain:
	.string "That's the SHINY CHARM.\p"
	.string "With it, you're far more likely\n"
	.string "to meet POKéMON of rare color.$"

RegionHub_Text_CuratorAllGiven:
	.string "My whole collection is in your\n"
	.string "hands.\p"
	.string "Wear those charms proudly!$"
