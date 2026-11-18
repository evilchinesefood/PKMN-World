GoldenrodCity_BikeShop_MapScripts::
	.byte 0

GoldenrodCity_BikeShop_EventScript_Clerk::
	lock
	faceplayer
	goto_if_set FLAG_RECEIVED_BIKE, GoldenrodCity_BikeShop_EventScript_Clerk_BikeReceived
	msgbox GoldenrodCity_BikeShop_Text_ClerkIntro, MSGBOX_YESNO
	goto_if_eq VAR_RESULT, TRUE, GoldenrodCity_BikeShop_EventScript_Clerk_BikeAgreed
	msgbox GoldenrodCity_BikeShop_Text_Refused, MSGBOX_DEFAULT
	closemessage
	release
	end

GoldenrodCity_BikeShop_EventScript_Clerk_BikeAgreed::
	msgbox GoldenrodCity_BikeShop_Text_ClerkAgreed, MSGBOX_DEFAULT
	giveitem ITEM_MACH_BIKE
	goto_if_eq VAR_RESULT, FALSE, Common_EventScript_ShowBagIsFull
	setflag FLAG_RECEIVED_BIKE
	closemessage
	release
	end

GoldenrodCity_BikeShop_EventScript_Clerk_BikeReceived::
	msgbox GoldenrodCity_BikeShop_Text_Mainshop, MSGBOX_DEFAULT
	closemessage
	release
	end

GoldenrodCity_BikeShop_EventScript_Clerk2::
	lock
	faceplayer
	msgbox GoldenrodCity_BikeShop_Text_Clerk2, MSGBOX_DEFAULT
	closemessage
	release
	end

GoldenrodCity_BikeShop_EventScript_Bike::
	lock
	msgbox GoldenrodCity_BikeShop_Text_Bicycle, MSGBOX_DEFAULT
	closemessage
	release
	end

GoldenrodCity_BikeShop_Text_Clerk2:
	.string "REGISTER your BIKE from the BAG.\n"
	.string "Then press SELECT to ride!\p"
	.string "The MACH BIKE picks up speed as\n"
	.string "you ride. Let go of the Control\l"
	.string "Pad to slow to a stop.$"

GoldenrodCity_BikeShop_Text_ClerkIntro:
    .string "…sigh… I moved here, but I can't\n"
    .string "sell my BICYCLES. Why is that?\p"
    .string "Could you ride a BICYCLE and\n"
    .string "advertise for me?$"

GoldenrodCity_BikeShop_Text_ClerkAgreed:
    .string "Really? Great!\p"
    .string "Give me your name and phone number,\n"
    .string "and I'll loan you a BICYCLE.$"

GoldenrodCity_BikeShop_Text_BorrowedBicycle:
    .string "{PLAYER} borrowed a BICYCLE.$"

GoldenrodCity_BikeShop_Text_Mainshop:
	.string "Business has been hard to come\n"
	.string "by since we moved from KANTO.\l"
	.string "We appreciate your help!\p"
	.string "Take our MACH BIKE for a spin!\n"
	.string "Let folks see how fast it goes!$"

GoldenrodCity_BikeShop_Text_Refused:
    .string "…sigh… Oh, for the kindness of\n"
    .string "people…$"

GoldenrodCity_BikeShop_Text_JustReleasedCompact:
    .string "Just released!\p"
    .string "First-rate compact BICYCLES!$"

GoldenrodCity_BikeShop_Text_Bicycle:
    .string "It's a shiny new BICYCLE!$"
