CeruleanCity_House1_Frlg_MapScripts::
	.byte 0

CeruleanCity_House1_EventScript_BadgeGuy::
	lock
	faceplayer
	msgbox CeruleanCity_House1_Text_BadgesHaveAmazingSecrets
	goto CeruleanCity_House1_EventScript_DescribeAnotherBadge
	end

CeruleanCity_House1_EventScript_DescribeAnotherBadge::
	message CeruleanCity_House1_Text_DescribeWhichBadge
	waitmessage
	setvar VAR_0x8004, SCROLL_MULTI_BADGES
	special ShowScrollableMultichoice
	switch VAR_RESULT
	case 0, CeruleanCity_House1_EventScript_DescribeBoulderBadge
	case 1, CeruleanCity_House1_EventScript_DescribeCascadeBadge
	case 2, CeruleanCity_House1_EventScript_DescribeThunderBadge
	case 3, CeruleanCity_House1_EventScript_DescribeRainbowBadge
	case 4, CeruleanCity_House1_EventScript_DescribeSoulBadge
	case 5, CeruleanCity_House1_EventScript_DescribeMarshBadge
	case 6, CeruleanCity_House1_EventScript_DescribeVolcanoBadge
	case 7, CeruleanCity_House1_EventScript_DescribeEarthBadge
	case 8, CeruleanCity_House1_EventScript_StopDescribingBadges
	case 127, CeruleanCity_House1_EventScript_StopDescribingBadges
	end

CeruleanCity_House1_EventScript_DescribeBoulderBadge::
	msgbox CeruleanCity_House1_Text_ObeyLv20Flash
	goto CeruleanCity_House1_EventScript_DescribeAnotherBadge
	end

CeruleanCity_House1_EventScript_DescribeCascadeBadge::
	msgbox CeruleanCity_House1_Text_ObeyLv30Cut
	goto CeruleanCity_House1_EventScript_DescribeAnotherBadge
	end

CeruleanCity_House1_EventScript_DescribeThunderBadge::
	msgbox CeruleanCity_House1_Text_ObeyLv40Fly
	goto CeruleanCity_House1_EventScript_DescribeAnotherBadge
	end

CeruleanCity_House1_EventScript_DescribeRainbowBadge::
	msgbox CeruleanCity_House1_Text_ObeyLv50Strength
	goto CeruleanCity_House1_EventScript_DescribeAnotherBadge
	end

CeruleanCity_House1_EventScript_DescribeSoulBadge::
	msgbox CeruleanCity_House1_Text_ObeyLv60Surf
	goto CeruleanCity_House1_EventScript_DescribeAnotherBadge
	end

CeruleanCity_House1_EventScript_DescribeMarshBadge::
	msgbox CeruleanCity_House1_Text_ObeyLv70RockSmash
	goto CeruleanCity_House1_EventScript_DescribeAnotherBadge
	end

CeruleanCity_House1_EventScript_DescribeVolcanoBadge::
	msgbox CeruleanCity_House1_Text_ObeyLv80Waterfall
	goto CeruleanCity_House1_EventScript_DescribeAnotherBadge
	end

CeruleanCity_House1_EventScript_DescribeEarthBadge::
	msgbox CeruleanCity_House1_Text_AllMonsWillObeyYou
	goto CeruleanCity_House1_EventScript_DescribeAnotherBadge
	end

CeruleanCity_House1_EventScript_StopDescribingBadges::
	msgbox CeruleanCity_House1_Text_ComeVisitAnytime
	release
	end

CeruleanCity_House1_Text_BadgesHaveAmazingSecrets::
	.string "Only skilled TRAINERS can collect\n"
	.string "POKéMON BADGES.\p"
	.string "I see you have at least one.\p"
	.string "Those BADGES have amazing secrets,\n"
	.string "did you know?$"

CeruleanCity_House1_Text_DescribeWhichBadge::
	.string "Now then…\p"
	.string "Which of the eight BADGES should\n"
	.string "I describe?$"

CeruleanCity_House1_Text_ComeVisitAnytime::
	.string "Come visit me anytime you wish.$"

CeruleanCity_House1_Text_ObeyLv20Flash::
	.string "POKéMON up to Lv. 20 will obey\n"
	.string "you.\p"
	.string "That includes even outsiders you\n"
	.string "obtain in trades.\p"
	.string "POKéMON of higher levels will\n"
	.string "be unruly in battle, however.\p"
	.string "It also lets you use the move\n"
	.string "FLASH outside of battle.$"

CeruleanCity_House1_Text_ObeyLv30Cut::
	.string "POKéMON up to Lv. 30 will obey\n"
	.string "you.\p"
	.string "That includes even outsiders you\n"
	.string "obtain in trades.\p"
	.string "POKéMON of higher levels will\n"
	.string "be unruly in battle, however.\p"
	.string "It also lets you use the move\n"
	.string "CUT outside of battle.$"

CeruleanCity_House1_Text_ObeyLv40Fly::
	.string "POKéMON up to Lv. 40 will obey\n"
	.string "you.\p"
	.string "That includes even outsiders you\n"
	.string "obtain in trades.\p"
	.string "POKéMON of higher levels will\n"
	.string "be unruly in battle, however.\p"
	.string "It also lets you use the move\n"
	.string "FLY outside of battle.$"

CeruleanCity_House1_Text_ObeyLv50Strength::
	.string "POKéMON up to Lv. 50 will obey\n"
	.string "you.\p"
	.string "That includes even outsiders you\n"
	.string "obtain in trades.\p"
	.string "POKéMON of higher levels will\n"
	.string "be unruly in battle, however.\p"
	.string "It also lets you use the move\n"
	.string "STRENGTH outside of battle.$"

CeruleanCity_House1_Text_ObeyLv60Surf::
	.string "POKéMON up to Lv. 60 will obey\n"
	.string "you.\p"
	.string "That includes even outsiders you\n"
	.string "obtain in trades.\p"
	.string "POKéMON of higher levels will\n"
	.string "be unruly in battle, however.\p"
	.string "It also lets you use the move\n"
	.string "SURF outside of battle.$"

CeruleanCity_House1_Text_ObeyLv70RockSmash::
	.string "POKéMON up to Lv. 70 will obey\n"
	.string "you.\p"
	.string "That includes even outsiders you\n"
	.string "obtain in trades.\p"
	.string "POKéMON of higher levels will\n"
	.string "be unruly in battle, however.\p"
	.string "It also lets you use the move\n"
	.string "ROCK SMASH outside of battle.$"

CeruleanCity_House1_Text_ObeyLv80Waterfall::
	.string "POKéMON up to Lv. 80 will obey\n"
	.string "you.\p"
	.string "That includes even outsiders you\n"
	.string "obtain in trades.\p"
	.string "POKéMON of higher levels will\n"
	.string "be unruly in battle, however.\p"
	.string "It also lets you use the move\n"
	.string "WATERFALL outside of battle.$"

CeruleanCity_House1_Text_AllMonsWillObeyYou::
	.string "All POKéMON will obey you!$"

