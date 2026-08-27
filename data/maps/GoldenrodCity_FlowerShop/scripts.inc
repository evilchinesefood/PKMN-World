GoldenrodCity_FlowerShop_MapScripts::
	.byte 0

@ #208: the mint clerk is ungated. She was a Johto_EventScript_Nop stub from the Goldenrod port
@ (53f21e0fff) -- visible post-Game-Clear but mute, because the HGSS seller script was never
@ ported. Mints are commodity items already sold at the hub vitamin vendor, Goldenrod Dept 4F,
@ Celadon Dept 5F and Lilycove Dept 4F, so a champion gate on a fifth vendor guarded nothing.
@ Her object_event "flag" is now 0 rather than FLAG_MINTS_CLERK. The old OnTransition ran
@ setflag FLAG_MINTS_CLERK (set = hidden) in the branch taken when the gate FAILED, so the bit is
@ SET on a save whose most recent entry to this shop predates Game Clear. It is CLEAR on a save
@ that has come in since (the postgame arm ran clearflag) and on one that never came in at all.
@ Keeping the flag field would leave her hidden on that first group. Flag id 0 is unconditional
@ spawn by construction: GetFlagPointer returns NULL for id 0
@ (src/event_data.c:273), so it can never be read or written.
@ One transient, not worth a migration: objectEventTemplates[] is persisted, and Continue refreshes
@ only .script, not .flagId (src/overworld.c:596). A save made INSIDE this shop keeps the stale
@ flagId for that one session; she appears on the next re-entry. Self-healing.
@
@ Both flags stay defined in johto_flags.h, but for DIFFERENT reasons -- do not collapse them:
@   FLAG_MINTS_CLERK (0xE4) is genuinely dirty. Live saves carry it SET (above), so handing 0xE4
@     to a future flag would inherit a pre-set garbage bit. Reserved.
@   FLAG_MINTS_ENABLED (0xE5) is provably CLEAR on every save that has ever existed: it has had no
@     writer at any point in this repo's history (git log -S finds none), which is why the old
@     call_if_set arm was dead code. Reusing 0xE5 would in fact be safe; it is kept only so the
@     pair stays legible next to its sibling.
@ Neither is kept to avoid renumbering -- the bank assigns literal slices and already has a hole
@ at 0xD6, so deleting a define shifts nothing.
GoldenrodCity_FlowerShop_EventScript_MintClerk::
	lock
	faceplayer
	msgbox GoldenrodCity_FlowerShop_Text_MintClerkIntro, MSGBOX_DEFAULT
	message gText_HowMayIServeYou
	waitmessage
	pokemart GoldenrodCity_FlowerShop_Pokemart_Mints
	msgbox gText_PleaseComeAgain, MSGBOX_DEFAULT
	release
	end

	.align 2
GoldenrodCity_FlowerShop_Pokemart_Mints::
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

GoldenrodCity_FlowerShop_Text_MintClerkIntro:
	.string "Our mints are grown right here in\n"
	.string "GOLDENROD.\p"
	.string "One will coax a POKéMON's nature\n"
	.string "toward a new temperament - though it\l"
	.string "never forgets the one it was born with.$"

GoldenrodCity_FlowerShop_EventScript_Owner::
	lock
	faceplayer
	goto_if_set FLAG_HIDE_SUDOWOODO, GoldenrodCity_FlowerShop_EventScript_Normal
	goto_if_set FLAG_RECEIVED_SQUIRTBOTTLE, GoldenrodCity_FlowerShop_EventScript_GotSquirtBottle
	goto_if_set FLAG_JOHTO_BADGE_3, GoldenrodCity_FlowerShop_EventScript_GiveSquirtBottle
	msgbox GoldenrodCity_FlowerShop_Text_Owner1, MSGBOX_DEFAULT
	closemessage
	release
	end

GoldenrodCity_FlowerShop_EventScript_GiveSquirtBottle::
	lock
	faceplayer
	msgbox GoldenrodCity_FlowerShop_Text_Owner2, MSGBOX_DEFAULT
	giveitem ITEM_SQUIRT_BOTTLE
	goto_if_eq VAR_RESULT, FALSE, Common_EventScript_ShowBagIsFull
	setflag FLAG_RECEIVED_SQUIRTBOTTLE
	closemessage
	release
	end

GoldenrodCity_FlowerShop_EventScript_GotSquirtBottle::
	lock
	faceplayer
	checkitem ITEM_WAILMER_PAIL
	goto_if_eq VAR_RESULT, FALSE, GoldenrodCity_FlowerShop_EventScript_GiveWailmerPail
	msgbox GoldenrodCity_FlowerShop_Text_Owner3, MSGBOX_DEFAULT
	closemessage
	release
	end

GoldenrodCity_FlowerShop_EventScript_Normal::
	lock
	faceplayer
	checkitem ITEM_WAILMER_PAIL
	goto_if_eq VAR_RESULT, FALSE, GoldenrodCity_FlowerShop_EventScript_GiveWailmerPail
	msgbox GoldenrodCity_FlowerShop_Text_Owner4, MSGBOX_DEFAULT
	closemessage
	release
	end

@ KeyItemAudit S3d: Johto-side WAILMER PAIL so the region's 16 berry-tree maps are
@ farmable without visiting Hoenn (Route 104 keeps its giver; the checkitem guard above
@ plus the engine key-item dedup make a second giver safe). Offered by the shop owner
@ once the SQUIRTBOTTLE beat is done (post-Whitney story states only).
GoldenrodCity_FlowerShop_EventScript_GiveWailmerPail::
	msgbox GoldenrodCity_FlowerShop_Text_WailmerPail1, MSGBOX_DEFAULT
	giveitem ITEM_WAILMER_PAIL
	goto_if_eq VAR_RESULT, FALSE, Common_EventScript_ShowBagIsFull
	msgbox GoldenrodCity_FlowerShop_Text_WailmerPail2, MSGBOX_DEFAULT
	closemessage
	release
	end

GoldenrodCity_FlowerShop_EventScript_Floria1::
	lock
	faceplayer
	goto_if_set FLAG_HIDE_SUDOWOODO, GoldenrodCity_FlowerShop_EventScript_Floria3
	goto_if_set FLAG_JOHTO_BADGE_3, GoldenrodCity_FlowerShop_EventScript_Floria2
	msgbox GoldenrodCity_FlowerShop_Text_Floria, MSGBOX_DEFAULT
	closemessage
	release
	end
	
GoldenrodCity_FlowerShop_EventScript_Floria2::
	msgbox GoldenrodCity_FlowerShop_Text_FloriaYouBeatWhitney, MSGBOX_DEFAULT
	closemessage
	release
	end

GoldenrodCity_FlowerShop_EventScript_Floria3::
	msgbox GoldenrodCity_FlowerShop_Text_FloriaItWasAMon, MSGBOX_DEFAULT
	closemessage
	release
	end

GoldenrodCity_FlowerShop_Text_Floria:
	.string "When I told my sis about the jiggly\n"
	.string "tree, she said it's dangerous.\p"
	.string "If I beat WHITNEY, I wonder if\n"
	.string "she'll lend me her water bottle…$"

GoldenrodCity_FlowerShop_Text_Owner1:
.string "Apparently, there is an odd tree\n"
.string "on ROUTE 36.\p"
.string "They say it dances when you water\n"
.string "it…\p"
.string "Oh, of course not!\p"
.string "This is a flower shop, so we do\n"
.string "have watering cans…\p"
.string "But I cannot let you have one!\n"
.string "It's too dangerous!\p"
.string "Well, maybe if you manage to\n"
.string "defeat gym leader WHITNEY, it\l"
.string "might be okay.$"

GoldenrodCity_FlowerShop_Text_Owner2:
.string "Apparently, there is an odd tree\n"
.string "on ROUTE 36.\p"
.string "They say it dances when you water\n"
.string "it…\p"
.string "Oh, that's a PLAINBADGE from\n"
.string "The GOLDENROD GYM!\p"
.string "Did you defeat WHITNEY?!\p"
.string "Well, then there's nothing to worry\n"
.string "about, is there?\p"
.string "I'll let you use this SQUIRTBOTTLE\n"
.string "for a while then.\l"
.string "…\p"
.string "Oh, never mind. Keep it!$"

GoldenrodCity_FlowerShop_Text_Owner3:
.string "The odd tree is on ROUTE 36.\n"
.string "Please be careful!$"

GoldenrodCity_FlowerShop_Text_Owner4:
    .string "Lalala lalalala. Have plenty of\n"
    .string "water, my lovely!$"

GoldenrodCity_FlowerShop_Text_FloriaYouBeatWhitney:
    .string "Wow, you beat WHITNEY? Cool!$"

GoldenrodCity_FlowerShop_Text_FloriaItWasAMon:
    .string "So it really was a POKéMON!$"

GoldenrodCity_FlowerShop_Text_WailmerPail1:
	.string "Growing BERRIES, are you?\p"
	.string "JOHTO's soil is wonderful for\n"
	.string "them, but they wilt without\l"
	.string "water.\p"
	.string "Here, take this WAILMER PAIL!$"

GoldenrodCity_FlowerShop_Text_WailmerPail2:
	.string "Sprinkle your BERRY patches\n"
	.string "every day and they'll grow up\l"
	.string "big and healthy!$"
