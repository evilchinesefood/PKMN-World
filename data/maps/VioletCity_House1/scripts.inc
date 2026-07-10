VioletCity_House1_MapScripts::
	.byte 0

VioletCity_House1_EventScript_Kyle::
	lock
	faceplayer
	msgbox VioletCity_House1_Text_PokefanM, MSGBOX_DEFAULT
	closemessage
	release
	end

VioletCity_House1_EventScript_Rudy::
	lock
	faceplayer
	@ Region merge (Johto port): the Bellsprout<->Onix in-game trade is stubbed to
	@ dialogue only — the expansion restructured INGAME_TRADE_*/gIngameTrades, so the
	@ Johto trade table is deferred to the Stage-4 content pass. NPC stays interactable.
	msgbox VioletCity_House1_Text_YouWillTradeWontYou, MSGBOX_DEFAULT
	release
	end

VioletCity_House1_EventScript_DeclineTrade::
	msgbox VioletCity_House1_Text_YouWontTradeMe, MSGBOX_DEFAULT
	release
	end

VioletCity_House1_EventScript_NotRequestedMon::
	bufferspeciesname STR_VAR_1, VAR_0x8009
	msgbox VioletCity_House1_Text_ThisIsntAMon, MSGBOX_DEFAULT
	release
	end

VioletCity_House1_EventScript_TradeCompleted::
	msgbox VioletCity_House1_Text_After, MSGBOX_DEFAULT
	release
	end

VioletCity_House1_Text_YouWillTradeWontYou:
	.string "I collect POKéMON!\n"
	.string "Do you have a {STR_VAR_1}?\p"
	.string "Want to trade it for my\n"
	.string "{STR_VAR_2}?$"

VioletCity_House1_Text_MonYouTakeCare:
	.string "Yay! I got myself {STR_VAR_1}!\p"
	.string "{STR_VAR_2}, you take care!$"

VioletCity_House1_Text_ThisIsntAMon:
	.string "Uh, no, I don't think so.\n"
	.string "That isn't a {STR_VAR_1}.$"

VioletCity_House1_Text_YouWontTradeMe:
	.string "You don't want to trade? Aww…$"

VioletCity_House1_Text_After:
	.string "Hi, how's my old ONIX doing?$"

VioletCity_House1_Text_PokefanM:
	.string "A POKéMON you get in a trade\n"
	.string "grows quickly.\p"
	.string "But if you don't have the right\n"
	.string "GYM BADGE, they may disobey you.$"
