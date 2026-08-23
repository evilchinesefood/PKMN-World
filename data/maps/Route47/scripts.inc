@ Local ids are (index in map.json's object_events array) + 1 - this map declares no explicit
@ "local_id" keys, so array order is the id. The SAGE is the 7th entry.
.set LOCALID_ROUTE47_SAGE, 7

Route47_MapScripts::
	.byte 0


Route47_EventScript_Hiker::
	trainerbattle_single TRAINER_DEVIN, Route47_Text_HikerSeen, Route47_Text_HikerBeaten
	msgbox Route47_Text_HikerAfter, MSGBOX_AUTOCLOSE
	end

Route47_Text_HikerSeen::
	.string "Longing for others is…\n"
	.string "what it is.\p"
	.string "But battles are battles,\n"
	.string "so let's go!$"

Route47_Text_HikerBeaten::
	.string "Wahaha!$"

Route47_Text_HikerAfter::
	.string "After a battle you should always leave\n"
	.string "with a parting laugh!$"

Route47_EventScript_Camper::
	trainerbattle_single TRAINER_GRANT, Route47_Text_CamperSeen, Route47_Text_CamperBeaten
	msgbox Route47_Text_CamperAfter, MSGBOX_AUTOCLOSE
	end

Route47_Text_CamperSeen::
	.string "I'm not good with large crowds, so\n"
	.string "I'm camping out here with my\l"
	.string "POKéMON!$"

Route47_Text_CamperBeaten::
	.string "I should be headed deeper into the\n"
	.string "mountain I guess…$"

Route47_Text_CamperAfter::
	.string "See ya!$"

Route47_EventScript_Thom::
	trainerbattle_double TRAINER_THOM_AND_KAE, Route47_Text_Couple1Seen, Route47_Text_Couple1Beaten, Route104_Text_GinaNotEnoughMons
	special GetPlayerBigGuyGirlString
	msgbox Route47_Text_Couple1After1, MSGBOX_AUTOCLOSE
	end

Route47_EventScript_Kae::
	trainerbattle_double TRAINER_THOM_AND_KAE, Route47_Text_Couple1Seen, Route47_Text_Couple1Beaten, Route104_Text_GinaNotEnoughMons
	special GetPlayerBigGuyGirlString
	msgbox Route47_Text_Couple1After2, MSGBOX_AUTOCLOSE
	end

Route47_Text_Couple1Seen::
	.string "THOM: One plus one is two. But the\n"
	.string "two of us together is much\l"
	.string "stronger!\p"
	.string "KAE: The two of us aren't just some\n"
	.string "boring pair!$"

Route47_Text_Couple1Beaten::
	.string "THOM: That wasn't what I expected.\l"
	.string "KAE: You're unusual too!$"

Route47_Text_Couple1After1::
	.string "THOM: It seems your power is\n"
	.string "impossible to predict!$"

Route47_Text_Couple1After2::
	.string "KAE: I figured you were an ordinary\n"
	.string "lone trainer. Boy was I wrong!$"

Route47_EventScript_Duff::
	trainerbattle_double TRAINER_DUFF_AND_EDA, Route47_Text_Couple2Seen, Route47_Text_Couple2Beaten, Route104_Text_GinaNotEnoughMons
	special GetPlayerBigGuyGirlString
	msgbox Route47_Text_Couple2After1, MSGBOX_AUTOCLOSE
	end

Route47_EventScript_Eda::
	trainerbattle_double TRAINER_DUFF_AND_EDA, Route47_Text_Couple2Seen, Route47_Text_Couple2Beaten, Route104_Text_GinaNotEnoughMons
	msgbox Route47_Text_Couple2After2, MSGBOX_AUTOCLOSE
	end

Route47_Text_Couple2Seen::
	.string "DUFF: Watching over my girlfriend\n"
	.string "makes my heart soar!\p"
	.string "EDA: My heart's feelings for my\n"
	.string "boyfriend are as wide and deep\l"
	.string "the ocean!$"

Route47_Text_Couple2Beaten::
	.string "DUFF: I was no match for you…\l"
	.string "EDA: You are really something…$"

Route47_Text_Couple2After1::
	.string "DUFF: Thank you for the awe-\n"
	.string "inspiring battle! Bye!$"

Route47_Text_Couple2After2::
	.string "EDA: You should really find a\n"
	.string "wonderful partner, too!$"

Route47_EventScript_Sage::
	lock
	faceplayer
	msgbox EmbeddedTower_Text_OldManIntro, MSGBOX_DEFAULT
	goto_if_unset FLAG_JOHTO_CHAMPION, Route47_EventScript_SageWarnsOff
	closemessage
	release
	end

@ Talk-to half of the EMBEDDED TOWER gate, so the condition is discoverable without
@ walking into the trigger tile. Same shape as the Route 23 badge guards, which pair a
@ talk-to script with a step-on trigger over one check.
Route47_EventScript_SageWarnsOff::
	msgbox Route47_Text_SageWontLetYouIn, MSGBOX_DEFAULT
	closemessage
	release
	end

@ === EMBEDDED TOWER post-game gate (issue #127) ===
@
@ Three level-70 legendaries stand in MAP_EMBEDDED_TOWER. Access to them is gated here, at
@ the cave mouth, and NOT by FLAG_HIDE_RAYQUAZA / _GROUDON / _KYOGRE: those three belong to
@ the tower's own encounter scripts (which SET them on capture) and to the Hall of Fame
@ respawn block, whose header says outright that respawns are for UNRESOLVED encounters only.
@ Touching them here would either resurrect a caught legendary or delete an uncaught one.
@
@ Geometry: the tower warp is Route47 (40,44). Its only walkable neighbour is (40,45) - the
@ three other neighbours are collision-1 cliff - so (40,45) is a true one-tile chokepoint and
@ one coord event covers every approach. The gate sits on the approach tile rather than on
@ (40,44) itself: TryStartCoordEventScript runs before TryStartWarpEventScript, so a trigger
@ on the warp tile would swallow the warp, and the push-back would have to start from inside
@ the doorway.
@
@ The trigger is armed by FLAG_JOHTO_CHAMPION being CLEAR (map.json "var" is a flag, not a
@ var - ShouldTriggerScriptRun falls back to FlagGet for non-var ids; RegionHub's intro-tour
@ triggers use the same form). It therefore disarms itself the moment the player is crowned,
@ and costs a champion nothing.
Route47_EventScript_EmbeddedTowerGate::
	@ Fail-safe. The map.json trigger already restricts this to pre-championship saves; the
	@ check is repeated here so that a champion can never be shut out of the tower even if
	@ the trigger were ever rearmed. Runs before any lock, so a champion sees no hitch.
	goto_if_set FLAG_JOHTO_CHAMPION, Route47_EventScript_EmbeddedTowerGateOpen
	lockall
	playse SE_PIN
	@ Deliberately no waitmovement on the SAGE: his object carries a hide flag this commit
	@ does not own, so a missing object must not be able to hang the script.
	applymovement LOCALID_ROUTE47_SAGE, Common_Movement_ExclamationMark
	delay 20
	applymovement OBJ_EVENT_ID_PLAYER, Common_Movement_WalkInPlaceFasterLeft
	waitmovement 0
	msgbox Route47_Text_EmbeddedTowerSealed, MSGBOX_DEFAULT
	closemessage
	@ (40,46) is collision 0, elevation 5 and holds no object event, so the bounce always
	@ lands the player on a walkable tile facing away from the door. Bouncing south is
	@ correct from all three approaches - (39,45) is the SAGE, and the other two are
	@ (41,45) and (40,46) itself.
	applymovement OBJ_EVENT_ID_PLAYER, Route47_Movement_ForcePlayerFromEmbeddedTower
	waitmovement 0
	releaseall
	end

@ Never locked, so there is nothing to release; the player's step continues into the warp.
Route47_EventScript_EmbeddedTowerGateOpen::
	end

Route47_Movement_ForcePlayerFromEmbeddedTower:
	walk_down
	step_end

Route47_Text_EmbeddedTowerSealed:
	.string "Hold on there!\p"
	.string "What sleeps beneath this hole once\n"
	.string "stirred the sky, the land and the\l"
	.string "sea all at once.\p"
	.string "Come back when JOHTO calls you its\n"
	.string "CHAMPION. Not one day sooner.$"

Route47_Text_SageWontLetYouIn:
	.string "The way down is not for you.\n"
	.string "Not yet.\p"
	.string "Become the CHAMPION of JOHTO, and\n"
	.string "I will trouble you no further.$"

EmbeddedTower_Text_OldManIntro:
	.string "Well, hello!\p"
	.string "It's said that past this hole used to\n"
	.string "be a huge tower reaching far into\l"
	.string "the sky.\p"
	.string "They say that it was a rather strange\n"
	.string "tower with half of it embedded\l"
	.string "in the cliff.\p"
	.string "It was not just a tall tower reaching\n"
	.string "up to the sky, but also reaching deep\l"
	.string "down underground!\p"
	.string "It is rumored that it even reached\n"
	.string "the bottom of the ocean!\p"
	.string "In short, the ruins used to connect\n"
	.string "the sky, the land, and the sea to\l"
	.string "each other…\p"
	.string "Most of the tower is now crumbled,\n"
	.string "and the only things that remain are\l"
	.string "the entrance and its interior, where\l"
	.string "you'll see strange patterns.$"

Route47_EventScript_Item_Pearl::
    finditem ITEM_PEARL
    end

Route47_EventScript_Item_Revive::
    finditem ITEM_REVIVE
    end

Route47_EventScript_Item_WhiteFlute::
    finditem ITEM_WHITE_FLUTE
    end

Route47_EventScript_Item_Stardust::
	finditem ITEM_STARDUST
	end

Route47_EventScript_Item_LuckyPunch::
	finditem ITEM_LUCKY_PUNCH
	end

Route47_EventScript_Chinchou::
	lock
	faceplayer
	waitse
	playmoncry SPECIES_CHINCHOU, CRY_MODE_NORMAL
	msgbox Route47_Text_Chinchou, MSGBOX_DEFAULT
	waitmoncry
	release
	end

Route47_Text_Chinchou:
	.string "CHINCHOU: Chou!$"
