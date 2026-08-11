SlowpokeWell_B1F_MapScripts::
	map_script MAP_SCRIPT_ON_TRANSITION, SlowpokeWell_B1F_HideStandingKurt
	map_script MAP_SCRIPT_ON_LOAD, SlowpokeWell_B1F_HideStandingKurt
	.byte 0

@ The standing Kurt exists only between the Proton cutscene's addobject and the
@ warp that ends it, so nothing should ever spawn him from his template. Saves
@ written before he was given his own hide flag (#87) have that flag clear, so
@ every map load parks him back on his template tile -- which used to be (17,8),
@ the single square joining Proton's chamber to the rest of the well. He walled
@ the player into a 22-tile dead end whose only other exit is a STRENGTH boulder.
@ Re-set the flag on both entry paths. ON_LOAD is not redundant: a plain Continue
@ reaches InitMapFromSavedGame(), which runs RunOnLoadMapScript() and never
@ RunOnTransitionMapScript() -- see the note above InitMapFromSavedGame in
@ overworld.c -- so a player who saved down here would otherwise stay walled in.
SlowpokeWell_B1F_HideStandingKurt::
	setflag FLAG_HIDE_SLOWPOKE_WELL_KURT_STANDING
	end

SlowpokeWell_B1F_EventScript_Item_Super_Potion_1::
	finditem ITEM_SUPER_POTION
	end

SlowpokeWell_B1F_EventScript_Item_Super_Potion_2::
	finditem ITEM_SUPER_POTION
	end

SlowpokeWell_B1F_EventScript_Item_Great_Ball::
	finditem ITEM_GREAT_BALL
	end

SlowpokeWell_B1F_EventScript_Item_Full_Heal::
	finditem ITEM_FULL_HEAL
	end

SlowpokeWell_B1F_EventScript_Kurt::
	lock
	faceplayer
	msgbox SlowpokeWell_B1F_Text_KurtIntro, MSGBOX_DEFAULT
	closemessage
	release
	end

@ Kurt once he is back on his feet. He only says one thing -- "Let's get out of
@ here" -- so he has to actually do it. #87 gave him this script to stop him
@ being a mute NPC, but it ended on release, which left the line as a promise the
@ game never kept: a player sealed into Proton's chamber by a stale hide flag
@ could talk to him forever and never leave. Talking to him now finishes the
@ scene the same way the Proton cutscene does.
@
@ The story bookkeeping is guarded, because this is a rescue and not a rerun:
@ VAR_AZALEA_TOWN_STATE climbs to 10 through Kurt's house and Ilex Forest, so
@ replaying the tail unconditionally would rewind a player who is already past
@ Azalea, and clearing FLAG_HIDE_KURT_2 again would put a second Kurt in his
@ house. Past state 3 he only walks the player home.
SlowpokeWell_B1F_EventScript_KurtStanding::
	lock
	faceplayer
	msgbox SlowpokeWell_B1F_Text_KurtAfter, MSGBOX_DEFAULT
	closemessage
	fadescreen FADE_TO_BLACK
	setflag FLAG_HIDE_SLOWPOKE_WELL_KURT_STANDING
	goto_if_ge VAR_AZALEA_TOWN_STATE, 3, SlowpokeWell_B1F_EventScript_KurtStandingLeave
	setflag FLAG_HIDE_AZALEA_TOWN_ROCKETS
	setflag FLAG_HIDE_SLOWPOKE_WELL_KURT
	setflag FLAG_HIDE_KURT_1
	clearflag FLAG_HIDE_KURT_2
	clearflag FLAG_HIDE_AZALEA_TOWN_SLOWPOKE
	setvar VAR_AZALEA_TOWN_STATE, 3
SlowpokeWell_B1F_EventScript_KurtStandingLeave::
	warp MAP_AZALEA_TOWN_KURTS_HOUSE, 15, 4
	release
	end

SlowpokeWell_B1F_EventScript_Grunt21::
	trainerbattle_single TRAINER_GRUNT_21, SlowpokeWell_B1F_Text_GruntM29Seen, SlowpokeWell_B1F_Text_GruntM29Beaten
	msgbox SlowpokeWell_B1F_Text_GruntM29After, MSGBOX_AUTOCLOSE
	end

SlowpokeWell_B1F_EventScript_Grunt22F::
	trainerbattle_single TRAINER_GRUNT_22, SlowpokeWell_B1F_Text_GruntF1Seen, SlowpokeWell_B1F_Text_GruntF1Beaten
	msgbox SlowpokeWell_B1F_Text_GruntF1After, MSGBOX_AUTOCLOSE
	end

SlowpokeWell_B1F_EventScript_Eto::
	trainerbattle_single TRAINER_ETO, SlowpokeWell_B1F_Text_GruntM2Seen, SlowpokeWell_B1F_Text_GruntM2Beaten
	msgbox SlowpokeWell_B1F_Text_GruntM2After, MSGBOX_AUTOCLOSE
	end

SlowpokeWell_B1F_EventScript_Proton::
	lock
	faceplayer
	msgbox SlowpokeWell_B1F_Text_ProtonSeen, MSGBOX_DEFAULT
	closemessage
	trainerbattle_no_intro TRAINER_PROTON_1, SlowpokeWell_B1F_Text_ProtonBeaten
	msgbox SlowpokeWell_B1F_Text_ProtonAfter, MSGBOX_AUTOCLOSE
	closemessage
	fadescreen FADE_TO_BLACK
	setflag FLAG_HIDE_AZALEA_TOWN_ROCKETS
	setflag FLAG_HIDE_SLOWPOKE_WELL_KURT
	@ No clearflag: addobject goes through TrySpawnObjectEventTemplate, which never
	@ reads the hide flag, and clearing it here would only race the map scripts that
	@ keep him from spawning on his own.
	addobject LOCALID_SLOWPOKE_WELL_KURT
	removeobject LOCALID_SLOWPOKE_WELL_KURT_LYING
	removeobject LOCALID_SLOWPOKE_WELL_GRUNT_21
	removeobject LOCALID_SLOWPOKE_WELL_GRUNT_22
	removeobject LOCALID_SLOWPOKE_WELL_ETO
	removeobject LOCALID_SLOWPOKE_WELL_PROTON
	delay 120
	fadescreen FADE_FROM_BLACK
	special DrawWholeMapView
	turnobject OBJ_EVENT_ID_PLAYER, DIR_SOUTH
	applymovement LOCALID_SLOWPOKE_WELL_KURT, SlowpokeWell_B1F_Movement_Kurt
	waitmovement 0
	msgbox SlowpokeWell_B1F_Text_KurtAfter, MSGBOX_DEFAULT
	closemessage
	fadescreen FADE_TO_BLACK
	setflag FLAG_HIDE_SLOWPOKE_WELL_KURT_STANDING
	setflag FLAG_HIDE_KURT_1
	clearflag FLAG_HIDE_KURT_2
	clearflag FLAG_HIDE_AZALEA_TOWN_SLOWPOKE
	setvar VAR_AZALEA_TOWN_STATE, 3
	warp MAP_AZALEA_TOWN_KURTS_HOUSE, 15, 4
	release
	end

@ Kurt is revealed under the fade at (14,8) and walks up to the player, who is
@ standing where they fought PROTON. He used to be staged at (17,8) and walk three
@ tiles left first, but (17,8), (16,8) and (15,8) are each a one-tile door into
@ this chamber, so addobject sealed it for as long as the scene ran. (14,8) is the
@ nearest tile that is not a cut vertex -- row 7 bypasses it via (15,7) -- and the
@ walk still ends on (14,5), facing the player.
SlowpokeWell_B1F_Movement_Kurt:
	walk_up
	walk_up
	walk_up
	step_end

SlowpokeWell_B1F_Text_KurtIntro:
	.string "KURT: Hey there, {PLAYER}!\p"
	.string "The guard up top took off when\n"
	.string "I shouted at him.\p"
	.string "But then I took a tumble down\n"
	.string "the WELL.\p"
	.string "I slammed down hard on my back,\n"
	.string "so I can't move.\p"
	.string "Rats! If I were fit, my POKéMON\n"
	.string "would've punished them…\p"
	.string "Ah, it can't be helped.\p"
	.string "{PLAYER}, show them how gutsy\n"
	.string "you are in my place!$"

SlowpokeWell_B1F_Text_KurtAfter:
	.string "KURT: Way to go, {PLAYER}!\p"
	.string "TEAM ROCKET has taken off.\p"
	.string "My back's better too.\n"
	.string "Let's get out of here.$"

SlowpokeWell_B1F_Text_GruntM29Seen:
	.string "Darn! I was standing guard up\n"
	.string "top when some old coot yelled\l"
	.string "at me.\p"
	.string "He startled me so much that\n"
	.string "I fell down here.\p"
	.string "I think I'll vent my anger by\n"
	.string "taking it out on you!$"

SlowpokeWell_B1F_Text_GruntM29Beaten:
	.string "Arrgh! This is NOT my day!$"

SlowpokeWell_B1F_Text_GruntM29After:
	.string "Sure, we've been hacking the\n"
	.string "tails off SLOWPOKE and selling\l"
	.string "them.\p"
	.string "Everything we do is for profit.\p"
	.string "That's right! We're TEAM ROCKET,\n"
	.string "and we'll do anything for money!$"

SlowpokeWell_B1F_Text_ProtonSeen:
	.string "What do you want?\p"
	.string "If you interrupt our work,\n"
	.string "don't expect any mercy!$"

SlowpokeWell_B1F_Text_ProtonBeaten:
	.string "You did OK today,\n"
	.string "but wait till next time!$"

SlowpokeWell_B1F_Text_ProtonAfter:
	.string "Yeah, TEAM ROCKET was broken up\n"
	.string "three years ago.\p"
	.string "The boss went into hiding.\p"
	.string "But we continued our activities\n"
	.string "underground!\p"
	.string "A small obstacle like you won't be\n"
	.string "much of a problem for our mission.\p"
	.string "I advise you to be very afraid of\n"
	.string "what is to come!$"

SlowpokeWell_B1F_Text_GruntM2Seen:
	.string "Hyuck-hyuck-hyuck!\n"
	.string "Quit taking SLOWPOKETAILS?\p"
	.string "You're nuts!\n"
	.string "If we obeyed you, TEAM ROCKET's\l"
	.string "rep would be ruined!$"

SlowpokeWell_B1F_Text_GruntM2Beaten:
	.string "Hyuck…\n"
	.string "Too strong…$"

SlowpokeWell_B1F_Text_GruntM2After:
	.string "We need the money,\n"
	.string "but selling SLOWPOKETAILS?\p"
	.string "It's tough being a ROCKET GRUNT!$"

SlowpokeWell_B1F_Text_GruntF1Seen:
	.string "Stop taking TAILS?\p"
	.string "Yeah, just try to defeat all\n"
	.string "of us!$"

SlowpokeWell_B1F_Text_GruntF1Beaten:
	.string "You rotten brat!$"

SlowpokeWell_B1F_Text_GruntF1After:
	.string "SLOWPOKETAILS grow back fast!\p"
	.string "What's wrong with selling them?$"

SlowpokeWell_B1F_Text_SlowpokeWithMail:
	.string "A SLOWPOKE with its TAIL cut off…\p"
	.string "Huh? It has MAIL.\n"
	.string "Read it?$"

SlowpokeWell_B1F_Text_SlowpokeMail:
	.string "{PLAYER} read the MAIL.\p"
	.string "Be good and look after the\n"
	.string "house with Grandpa and SLOWPOKE.\p"
	.string "Love, Dad$"

SlowpokeWell_B1F_Text_TaillessSlowpoke:
	.string "A SLOWPOKE with its TAIL cut off…$"

@ JESSIE and JAMES block the row-2 corridor, the last stretch before the player
@ drops south toward PROTON. They used to stand at (19,17)/(20,17), which is a
@ south-western branch the route to PROTON never touches -- 45 steps from the
@ entrance to his chamber and not one of them within sight of that corridor -- so
@ the ambush was missable by simply walking the obvious way. (20,2)/(21,2) is a
@ cut: with them standing there PROTON cannot be reached at all.
@
@ Blocking a corridor is only safe because this pair is a gate rather than a wall.
@ Both halves of the map keep a tile adjacent to them -- (22,2) to the east and
@ (19,2) to the west -- so the battle can be started from whichever side the
@ player is on, and beating it removes both objects for good. That matters for
@ anyone who saved on B2F, which is behind this gate: they come up the ladder on
@ the far side and can still fight their way out. TRAINER_BATTLE_TWO_TRAINERS_NO_INTRO
@ also goes straight to dotrainerbattle with no HasEnoughMonsForDoubleBattle
@ branch, so a short party cannot refuse the fight and strand itself either.
SlowpokeWell_B1F_EventScript_JessieJames::
	lock
	faceplayer
	msgbox SlowpokeWell_B1F_Text_JessieJamesMotto, MSGBOX_DEFAULT
	trainerbattle_two_trainers TRAINER_ROCKET_JESSIE, SlowpokeWell_B1F_Text_JessieDefeat, TRAINER_ROCKET_JAMES, SlowpokeWell_B1F_Text_JamesDefeat
	msgbox SlowpokeWell_B1F_Text_JessieJamesBlastOff, MSGBOX_AUTOCLOSE
	setflag FLAG_HIDE_JESSIE_JAMES_SLOWPOKE_WELL
	removeobject LOCALID_SLOWPOKE_WELL_JESSIE
	removeobject LOCALID_SLOWPOKE_WELL_JAMES
	release
	end

SlowpokeWell_B1F_Text_JessieJamesMotto:
	.string "Prepare for trouble… and make it\n"
	.string "double!\p"
	.string "It's TEAM ROCKET! Hand over your\n"
	.string "POKéMON, you little twerp!$"

SlowpokeWell_B1F_Text_JessieDefeat:
	.string "JESSIE: How dare you!$"

SlowpokeWell_B1F_Text_JamesDefeat:
	.string "JAMES: It's not fair!$"

SlowpokeWell_B1F_Text_JessieJamesBlastOff:
	.string "JESSIE & JAMES: We're blasting off\n"
	.string "agaaain!$"
