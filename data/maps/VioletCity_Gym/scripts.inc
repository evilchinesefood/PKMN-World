VioletCity_Gym_MapScripts::
	.byte 0

VioletCity_Gym_EventScript_GymGuy::
	lock
	faceplayer
	goto_if_set FLAG_DEFEATED_VIOLET_GYM, VioletCity_Gym_EventScript_GymGuy2
	msgbox VioletGym_Text_GymGuide_Intro, MSGBOX_DEFAULT
	closemessage
	release
	end
	
VioletCity_Gym_EventScript_GymGuy2::
	msgbox VioletGym_Text_GymGuide_Win, MSGBOX_DEFAULT
	release
	end	

VioletCity_Gym_EventScript_Rod::
	trainerbattle_single TRAINER_ROD VioletGym_Text_BirdKeeperRod_Seen, VioletGym_Text_BirdKeeperRod_Beaten
	msgbox VioletGym_Text_BirdKeeperRod_After, MSGBOX_AUTOCLOSE
	end

VioletCity_Gym_EventScript_Abe::
	trainerbattle_single TRAINER_ABE VioletGym_Text_BirdKeeperAbe_Seen, VioletGym_Text_BirdKeeperAbe_Beaten
	msgbox VioletGym_Text_BirdKeeperAbe_After, MSGBOX_AUTOCLOSE
	end

VioletCity_Gym_EventScript_Falkner::
	lock
	faceplayer
	goto_if_set FLAG_DEFEATED_VIOLET_GYM, VioletCity_Gym_EventScript_Falkner_Defeated
	msgbox VioletGym_Text_Falkner_Intro, MSGBOX_DEFAULT
	trainerbattle_no_intro TRAINER_FALKNER_1, VioletGym_Text_Falkner_WinLoss
	message VioletGym_Text_ReceivedZephyrBadge
	waitmessage
	call Common_EventScript_PlayGymBadgeFanfare
	msgbox VioletGym_Text_Falkner_BadgeExplain, MSGBOX_DEFAULT
	setflag FLAG_JOHTO_BADGE_1
	setflag FLAG_DEFEATED_VIOLET_GYM
	addvar VAR_NUM_BADGES, 1
	setvar VAR_0x8008, 1
	call Common_EventScript_SetGymTrainers
	setvar VAR_VIOLET_CITY_STATE, 3
	setrespawn HEAL_LOCATION_VIOLET_CITY
	goto VioletCity_Gym_EventScript_GiveTM
	end

VioletCity_Gym_EventScript_GiveTM::
	giveitem ITEM_TM_DOUBLE_TEAM
	goto_if_eq VAR_RESULT, FALSE, Common_EventScript_ShowBagIsFull
	setflag FLAG_GOT_TM_DOUBLE_TEAM
	msgbox VioletGym_Text_Falkner_TMExplain, MSGBOX_DEFAULT
	closemessage
	release
	end

VioletCity_Gym_EventScript_Falkner_Defeated::
	goto_if_unset FLAG_GOT_TM_DOUBLE_TEAM, VioletCity_Gym_EventScript_GiveTM
	goto_if_set FLAG_JOHTO_CHAMPION, VioletCity_Gym_EventScript_OfferRematch
	msgbox VioletGym_Text_Falkner_AfterFight, MSGBOX_DEFAULT
	closemessage
	release
	end

VioletCity_Gym_EventScript_OfferRematch::
	msgbox VioletGym_Text_Falkner_Rematch, MSGBOX_YESNO
	goto_if_eq VAR_RESULT, NO, VioletCity_Gym_EventScript_RematchDecline
	trainerbattle_no_intro TRAINER_FALKNER_1, VioletGym_Text_Falkner_RematchLoss
	msgbox VioletGym_Text_Falkner_RematchPost, MSGBOX_DEFAULT
	closemessage
	release
	end

VioletCity_Gym_EventScript_RematchDecline::
	msgbox VioletGym_Text_Falkner_RematchDecline, MSGBOX_DEFAULT
	closemessage
	release
	end

VioletGym_Text_Falkner_Intro:
	.string "I'm FALKNER, the VIOLET POKéMON\n"
	.string "GYM leader!\p"
	.string "People say you can clip\n"
	.string "FLYING-type POKéMON's wings\p"
	.string "with a jolt of electricity…\n"
	.string "I won't allow such insults to bird\l"
	.string "POKéMON!\p"
	.string "I'll show you the real power\n"
	.string "of the magnificent bird POKéMON!$"

VioletGym_Text_Falkner_WinLoss:
	.string "…Darn! My dad's cherished bird\n"
	.string "POKéMON…\p"
	.string "All right. Take this.\p"
	.string "It's the official POKéMON LEAGUE\n"
	.string "ZEPHYRBADGE.$"

VioletGym_Text_ReceivedZephyrBadge:
	.string "{PLAYER} received ZEPHYRBADGE.$"

VioletGym_Text_Falkner_BadgeExplain:
	.string "ZEPHYRBADGE raises the ATTACK\n"
	.string "power of POKéMON.\p"
	.string "It also enables POKéMON to use\n"
	.string "FLASH, if they can learn it,\l"
	.string "anytime.\p"
	.string "Here--take this too.$"

VioletGym_Text_Falkner_TMExplain:
	.string "By using a TM, a POKéMON will\n"
	.string "instantly learn a new move.\p"
	.string "TM32 contains DOUBLE TEAM.\p"
	.string "It increase a POKéMON's evasion.\p"
	.string "In other words, your POKéMON\n"
	.string "will be harder to hit.$"

VioletGym_Text_Falkner_AfterFight:
	.string "There are POKéMON GYMS in cities\n"
	.string "and towns ahead.\p"
	.string "You should test your skills at\n"
	.string "these GYMS.\p"
	.string "I'm going to train harder to\n"
	.string "become the greatest bird master!$"

VioletGym_Text_Falkner_Rematch:
	.string "Congratulations on defeating\n"
	.string "the ELITE 4!\p"
	.string "I've been training my\n"
	.string "FLYING-type POKéMON even harder.\p"
	.string "Think you can take on the power\n"
	.string "of the skies again?$"

VioletGym_Text_Falkner_RematchLoss:
	.string "Wow… You beat me again.\p"
	.string "I'm going to train harder to\n"
	.string "become the greatest bird master!$"

VioletGym_Text_Falkner_RematchPost:
	.string "My birds and I will keep reaching\n"
	.string "for greater heights. Come test us\l"
	.string "again whenever you like!$"

VioletGym_Text_Falkner_RematchDecline:
	.string "Heh, come back when your team is\n"
	.string "ready to soar with mine.$"

VioletGym_Text_BirdKeeperRod_Seen:
	.string "The keyword is guts!\p"
	.string "Those here are training night and\n"
	.string "day to become bird POKéMON masters.\p"
	.string "Come on!$"

VioletGym_Text_BirdKeeperRod_Beaten:
	.string "Gaaah!$"

VioletGym_Text_BirdKeeperRod_After:
	.string "FALKNER's skills are for real!\p"
	.string "Don't get cocky just because\n"
	.string "you beat me!$"

VioletGym_Text_BirdKeeperAbe_Seen:
	.string "Let me see if you are good\n"
	.string "enough to face FALKNER!$"

VioletGym_Text_BirdKeeperAbe_Beaten:
	.string "This can't be true!$"

VioletGym_Text_BirdKeeperAbe_After:
	.string "This is pathetic, losing to some\n"
	.string "rookie trainer…$"

VioletGym_Text_GymGuide_Intro:
	.string "Hey! What's up? I'm no trainer,\n"
	.string "but I can give some advice!\p"
	.string "Believe me! If you believe, a\n"
	.string "championship dream can come true.\p"
	.string "You believe? Then listen.\p"
	.string "FALKNER's ace is a bulky owl\n"
	.string "that loves to eat BERRIES.\p"
	.string "While it's not the strongest,\n"
	.string "it can take a lot of hits.\p"
	.string "You can hurt it with ELECTRIC\n"
	.string "and ROCK-type moves, but watch out\l"
	.string "for MUD-SLAP!\p"
	.string "If you want more help, go visit the\n"
	.string "POKéMON ACADEMY.\p"
	.string "The students there really know\n"
	.string "their stuff!$"

VioletGym_Text_GymGuide_Win:
	.string "Nice battle! Keep it up,\n"
	.string "and you'll be the CHAMP in no\l"
	.string "time at all!$"

VioletCity_Gym_EventScript_Statue::
	lock
	goto_if_set FLAG_DEFEATED_VIOLET_GYM, VioletCity_Gym_EventScript_Statue2
	msgbox VioletCity_Gym_Text_GymStatue, MSGBOX_DEFAULT
	closemessage
	release
	end

VioletCity_Gym_EventScript_Statue2::
	msgbox VioletCity_Gym_Text_GymStatueCertified, MSGBOX_DEFAULT
	closemessage
	release
	end

VioletCity_Gym_Text_GymStatue:
	.string "VIOLET CITY POKéMON GYM$"

VioletCity_Gym_Text_GymStatueCertified:
	.string "VIOLET CITY POKéMON GYM\p"
	.string "FALKNER'S CERTIFIED TRAINERS:\n"
	.string "{PLAYER}$"
