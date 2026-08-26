@ Local ids 4 and 7 held Hoenn's Wally set-piece, removed in favour of Hoenn's own copy.
@ The two object slots are RETAINED, permanently hidden, and must stay at these indices:
@ LoadSaveblockObjEventScripts() (src/overworld.c:596) re-points a resumed save's templates
@ at the ROM table BY INDEX, and a plain Continue reaches neither map loader (see the comment
@ at src/overworld.c:2356), so deleting them outright would hand a save made inside this map
@ the wrong scripts for the item balls, and read past the end of the table for the last two
@ trainers.
.set LOCALID_UNUSED_WALLY_1, 4
.set LOCALID_UNUSED_WALLY_2, 7

JohtoVictoryRoad_1F_MapScripts::
	map_script MAP_SCRIPT_ON_TRANSITION, JohtoVictoryRoad_1F_OnTransition
	map_script MAP_SCRIPT_ON_RESUME, SetTimeEncounters
	map_script MAP_SCRIPT_ON_RETURN_TO_FIELD, JohtoVictoryRoad_1F_OnReturnToField
	.byte 0

@ Keeps both unused slots despawned on every ordinary entry to the map, old saves included --
@ ON_TRANSITION runs after the templates load but before objects spawn.
JohtoVictoryRoad_1F_OnTransition:
	setflag FLAG_GARBAGEFLAG
	end

@ ON_TRANSITION does not run on a plain Continue, so a save made standing on this map needs
@ the flag set here too -- and it must be set UNCONDITIONALLY, not left to removeobject.
@ RemoveObjectEventByLocalIdAndMap() only FlagSets inside its successful-lookup branch
@ (event_object_movement.c:1711), so if neither object is in the camera window at the moment
@ of the resume it is a pure no-op, the flag stays clear, and TrySpawnObjectEvents() spawns
@ the stale object off the SAVED template as soon as the player walks within range of
@ (12,25) or (31,9) -- it gates on nothing but !FlagGet(template->flagId).
@ setflag closes that window; the removeobjects then clear whichever one did spawn.
JohtoVictoryRoad_1F_OnReturnToField:
	setflag FLAG_GARBAGEFLAG
	removeobject LOCALID_UNUSED_WALLY_1
	removeobject LOCALID_UNUSED_WALLY_2
	end

JohtoVictoryRoad_1F_EventScript_Edgar::
	trainerbattle_single TRAINER_EDGAR_VR_JT, JohtoVictoryRoad_1F_Text_EdgarIntro, JohtoVictoryRoad_1F_Text_EdgarDefeat
	msgbox JohtoVictoryRoad_1F_Text_EdgarPostBattle, MSGBOX_AUTOCLOSE
	end

JohtoVictoryRoad_1F_EventScript_Albert::
	trainerbattle_single TRAINER_ALBERT_VR_JT, JohtoVictoryRoad_1F_Text_AlbertIntro, JohtoVictoryRoad_1F_Text_AlbertDefeat
	msgbox JohtoVictoryRoad_1F_Text_AlbertPostBattle, MSGBOX_AUTOCLOSE
	end

JohtoVictoryRoad_1F_EventScript_Hope::
	trainerbattle_single TRAINER_HOPE_JT, JohtoVictoryRoad_1F_Text_HopeIntro, JohtoVictoryRoad_1F_Text_HopeDefeat
	msgbox JohtoVictoryRoad_1F_Text_HopePostBattle, MSGBOX_AUTOCLOSE
	end

JohtoVictoryRoad_1F_EventScript_Quincy::
	trainerbattle_single TRAINER_QUINCY_JT, JohtoVictoryRoad_1F_Text_QuincyIntro, JohtoVictoryRoad_1F_Text_QuincyDefeat
	msgbox JohtoVictoryRoad_1F_Text_QuincyPostBattle, MSGBOX_AUTOCLOSE
	end

JohtoVictoryRoad_1F_EventScript_Katelynn::
	trainerbattle_single TRAINER_KATELYNN_JT, JohtoVictoryRoad_1F_Text_KatelynnIntro, JohtoVictoryRoad_1F_Text_KatelynnDefeat
	msgbox JohtoVictoryRoad_1F_Text_KatelynnPostBattle, MSGBOX_AUTOCLOSE
	end

JohtoVictoryRoad_1F_Text_EdgarIntro:
	.string "I've made it this far a couple times,\n"
	.string "but the last stretch is so long…$"

JohtoVictoryRoad_1F_Text_EdgarDefeat:
	.string "My dream ends here again…$"

JohtoVictoryRoad_1F_Text_EdgarPostBattle:
	.string "You've made it this far. Keep the\n"
	.string "momentum going and become the\l"
	.string "CHAMPION! If anyone can, it's you!$"

JohtoVictoryRoad_1F_Text_AlbertIntro:
	.string "I didn't come all this way to lose now.\n"
	.string "That possibility doesn't exist!$"

JohtoVictoryRoad_1F_Text_AlbertDefeat:
	.string "Impossible…\n"
	.string "I lost?$"

JohtoVictoryRoad_1F_Text_AlbertPostBattle:
	.string "I lost here…\p"
	.string "That means I lack the qualifications\n"
	.string "to become the CHAMPION…$"

JohtoVictoryRoad_1F_Text_HopeIntro:
	.string "This seemingly infinite and harsh road\n"
	.string "lives up to its name of VICTORY.$"

JohtoVictoryRoad_1F_Text_HopeDefeat:
	.string "Your battle style is fantastic…$"

JohtoVictoryRoad_1F_Text_HopePostBattle:
	.string "You seem to have the potential for\n"
	.string "becoming the CHAMPION.$"

JohtoVictoryRoad_1F_Text_QuincyIntro:
	.string "What is the VICTORY ROAD?\n"
	.string "I'll tell you if you win!$"

JohtoVictoryRoad_1F_Text_QuincyDefeat:
	.string "Okay!\n"
	.string "Well done!$"

JohtoVictoryRoad_1F_Text_QuincyPostBattle:
	.string "Getting through here safely--that's\n"
	.string "the final test for any TRAINER aiming\l"
	.string "to become the POKéMON CHAMPION.\p"
	.string "That's why it's called the VICTORY\n"
	.string "ROAD.$"

JohtoVictoryRoad_1F_Text_KatelynnIntro:
	.string "I have nothing to say to anyone\n"
	.string "that's come this far. Come on!$"

JohtoVictoryRoad_1F_Text_KatelynnDefeat:
	.string "This is a disgrace…$"

JohtoVictoryRoad_1F_Text_KatelynnPostBattle:
	.string "Humph, go right on ahead.\n"
	.string "See if I care.$"

JohtoVictoryRoad_1F_EventScript_ItemMaxElixir::
	finditem ITEM_MAX_ELIXIR
	end

JohtoVictoryRoad_1F_EventScript_ItemPPUp::
	finditem ITEM_PP_UP
	end