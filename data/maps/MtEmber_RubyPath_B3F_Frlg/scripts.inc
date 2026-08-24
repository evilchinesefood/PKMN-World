MtEmber_RubyPath_B3F_Frlg_MapScripts::
	.byte 0

@ Odd that this is here and not in MtEmber_RubyPath_B5F/scripts.inc
MtEmber_RubyPath_B5F_EventScript_Ruby::
	lock
	faceplayer
	giveitem ITEM_RUBY
	goto_if_eq VAR_RESULT, FALSE, EventScript_BagIsFull
	removeobject VAR_LAST_TALKED
	setflag FLAG_GOT_RUBY
	release
	end

MtEmber_RubyPath_B3F_Text_FoundARuby::
	.string "{PLAYER} found a RUBY!$"

