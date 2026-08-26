CeladonCity_Condominiums_1F_Frlg_MapScripts::
	.byte 0

@ #206: FLAG_SYS_GAME_CLEAR, not FLAG_KANTO_CHAMPION. The DAISY line is Kanto trivia -- a one-off
@ flavour beat plus a Fame Checker unlock (FAMECHECKER_DAISY, 4) -- not Kanto story, so it reads
@ the any-region first Hall of Fame like every other convenience. b3397bf44a swept it onto
@ FLAG_KANTO_CHAMPION with the genuine Kanto postgame; the owner's split on #206 puts it back.
@
@ The order below is load-bearing in BOTH directions, and it also repairs already-broken saves.
@ TEA is the sole key to SAFFRON: FLAG_GOT_TEA is set HERE and nowhere else in the tree, and all
@ four gate guards hard-block without it (Route5_SouthEntrance_Frlg/scripts.inc:30 and its three
@ siblings push the player back out). SAFFRON has no other entrance, and Fly needs a prior visit.
@
@ The shipped order before b3397bf44a tested FLAG_SYS_GAME_CLEAR ABOVE FLAG_GOT_TEA, so a Hoenn or
@ Johto champion -- who reaches CELADON with that any-region bit already set -- took MentionDaisy on
@ their FIRST conversation. That sets FLAG_TALKED_TO_TEA_LADY_AFTER_HOF, which the old first line
@ latched on permanently. One conversation cost them the TEA, and with it SAFFRON, gym 6 and
@ SILPH CO, for good. b3397bf44a masked this by moving to FLAG_KANTO_CHAMPION (unreachable: a
@ Kanto champion has already been through SAFFRON); #206's split moves the flag back, so the
@ ordering has to carry the weight instead.
@
@ FLAG_GOT_TEA is therefore tested FIRST, above the AFTER_HOF latch. That is deliberate and is what
@ makes this self-repairing: a live save already stranded (latch set, TEA never taken) walks into
@ the hand-out on its next conversation instead of the dead end, so no migration step is needed.
@ FLAG_TALKED_TO_TEA_LADY_AFTER_HOF is read nowhere else in the tree, so nothing else observes it.
@ Never move the AFTER_HOF or FLAG_SYS_GAME_CLEAR checks above the FLAG_GOT_TEA check.
CeladonCity_Condominiums_1F_EventScript_TeaWoman::
	lock
	faceplayer
	goto_if_unset FLAG_GOT_TEA, CeladonCity_Condominiums_1F_EventScript_TeaWomanGiveTea
	goto_if_set FLAG_TALKED_TO_TEA_LADY_AFTER_HOF, CeladonCity_Condominiums_1F_EventScript_TeaWomanAfterTea
	goto_if_set FLAG_SYS_GAME_CLEAR, CeladonCity_Condominiums_1F_EventScript_TeaWomanMentionDaisy
	goto CeladonCity_Condominiums_1F_EventScript_TeaWomanAfterTea
	end

CeladonCity_Condominiums_1F_EventScript_TeaWomanGiveTea::
	msgbox CeladonCity_Condominiums_1F_Text_TryThisDrinkInstead
	giveitem ITEM_TEA
	goto_if_eq VAR_RESULT, FALSE, EventScript_BagIsFull
	setflag FLAG_GOT_TEA
	msgbox CeladonCity_Condominiums_1F_Text_NothingBeatsThirstLikeTea
	release
	end

CeladonCity_Condominiums_1F_EventScript_TeaWomanAfterTea::
	msgbox CeladonCity_Condominiums_1F_Text_MyDearMonsKeepMeCompany
	release
	end

CeladonCity_Condominiums_1F_EventScript_TeaWomanMentionDaisy::
	famechecker FAMECHECKER_DAISY, 4
	setflag FLAG_TALKED_TO_TEA_LADY_AFTER_HOF
	msgbox CeladonCity_Condominiums_1F_Text_DaisyComesToBuyTea
	release
	end

CeladonCity_Condominiums_1F_EventScript_Meowth::
	lock
	faceplayer
	waitse
	playmoncry SPECIES_MEOWTH, CRY_MODE_NORMAL
	msgbox CeladonCity_Condominiums_1F_Text_Meowth
	waitmoncry
	release
	end

CeladonCity_Condominiums_1F_EventScript_Clefairy::
	lock
	faceplayer
	waitse
	playmoncry SPECIES_CLEFAIRY, CRY_MODE_NORMAL
	msgbox CeladonCity_Condominiums_1F_Text_Clefairy
	waitmoncry
	release
	end

CeladonCity_Condominiums_1F_EventScript_Nidoran::
	lock
	faceplayer
	waitse
	playmoncry SPECIES_NIDORAN_F, CRY_MODE_NORMAL
	msgbox CeladonCity_Condominiums_1F_Text_Nidoran
	waitmoncry
	release
	end

CeladonCity_Condominiums_1F_EventScript_SuiteSign::
	msgbox CeladonCity_Condominiums_1F_Text_ManagersSuite, MSGBOX_SIGN
	end

CeladonCity_Condominiums_1F_Text_Meowth::
	.string "MEOWTH: Meow!$"

CeladonCity_Condominiums_1F_Text_TryThisDrinkInstead::
	.string "You shouldn't spend all your money\n"
	.string "on drinks.\p"
	.string "Try this instead.$"

CeladonCity_Condominiums_1F_Text_NothingBeatsThirstLikeTea::
	.string "Nothing beats thirst like some hot\n"
	.string "TEA.\p"
	.string "It really is the best.$"

CeladonCity_Condominiums_1F_Text_MyDearMonsKeepMeCompany::
	.string "My dear POKéMON keep me company.\n"
	.string "MEOWTH even brings money home!$"

CeladonCity_Condominiums_1F_Text_DaisyComesToBuyTea::
	.string "Oh, hello, dearie.\n"
	.string "Did you enjoy my TEA?\p"
	.string "By the way, dear. Are you, by any\n"
	.string "chance, from PALLET TOWN?\p"
	.string "A girl from PALLET TOWN, DAISY,\n"
	.string "she enjoys TEA every day.\p"
	.string "She visits the CELADON DEPT. STORE\n"
	.string "to buy some TEA.$"

CeladonCity_Condominiums_1F_Text_Clefairy::
	.string "CLEFAIRY: Pi pippippi!$"

CeladonCity_Condominiums_1F_Text_Nidoran::
	.string "NIDORAN♀: Kya kyaoo!$"

CeladonCity_Condominiums_1F_Text_ManagersSuite::
	.string "CELADON MANSION\n"
	.string "Manager's Suite$"

