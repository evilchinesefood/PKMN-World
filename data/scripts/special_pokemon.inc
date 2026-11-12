SpecialPokemon_EventScript_ClassicCapTrainer::
	lock
	faceplayer
	goto_if_unset FLAG_SYS_POKEMON_GET, SpecialPokemon_EventScript_StartJourneyFirst
	goto_if_set FLAG_SPECIAL_UNLOCKED_CLASSIC_CAP, SpecialPokemon_EventScript_ClassicCapRepeat
	msgbox SpecialPokemon_Text_ClassicCapWelcome, MSGBOX_DEFAULT
	setflag FLAG_SPECIAL_UNLOCKED_CLASSIC_CAP
SpecialPokemon_EventScript_ClassicCapRepeat::
	setvar VAR_0x8004, SPECIAL_POKEMON_CLASSIC_CAP
	msgbox SpecialPokemon_Text_ClassicCapOffer, MSGBOX_YESNO
	goto SpecialPokemon_EventScript_GiftAnswer

SpecialPokemon_EventScript_BalloonSeller::
	lock
	faceplayer
	goto_if_unset FLAG_SYS_POKEMON_GET, SpecialPokemon_EventScript_StartJourneyFirst
	goto_if_set FLAG_SPECIAL_UNLOCKED_BALLOONS, SpecialPokemon_EventScript_BalloonsRepeat
	msgbox SpecialPokemon_Text_BalloonSeller, MSGBOX_DEFAULT
	setflag FLAG_SPECIAL_UNLOCKED_BALLOONS
SpecialPokemon_EventScript_BalloonsRepeat::
	setvar VAR_0x8004, SPECIAL_POKEMON_BALLOONS
	msgbox SpecialPokemon_Text_BalloonsOffer, MSGBOX_YESNO
	goto SpecialPokemon_EventScript_GiftAnswer

SpecialPokemon_EventScript_GiftAnswer::
	goto_if_eq VAR_RESULT, NO, SpecialPokemon_EventScript_Later
	special SpecialPokemon_Give
	goto_if_eq VAR_RESULT, MON_CANT_GIVE, Common_EventScript_NoMoreRoomForPokemon
	copyvar VAR_0x8005, VAR_RESULT
	playfanfare MUS_OBTAIN_ITEM
	msgbox SpecialPokemon_Text_Received, MSGBOX_DEFAULT
	waitfanfare
	call_if_eq VAR_0x8005, MON_GIVEN_TO_PC, Common_EventScript_TransferredToPC
	callnative UpdateFollowingPokemon
	msgbox SpecialPokemon_Text_GiftAgain, MSGBOX_DEFAULT
	release
	end

SpecialPokemon_EventScript_Later::
	msgbox SpecialPokemon_Text_Later, MSGBOX_DEFAULT
	release
	end

SpecialPokemon_EventScript_StartJourneyFirst::
	msgbox SpecialPokemon_Text_StartJourneyFirst, MSGBOX_DEFAULT
	release
	end

SpecialPokemon_EventScript_SquadOrganizer::
	lock
	faceplayer
	goto_if_set FLAG_SPECIAL_UNLOCKED_SQUAD, SpecialPokemon_EventScript_SquadOffer
	goto_if_unset FLAG_SPECIAL_SQUAD_STARTED, SpecialPokemon_EventScript_StartSquad
	goto_if_unset FLAG_SPECIAL_SQUAD_ONE, SpecialPokemon_EventScript_SquadReminder
	goto_if_unset FLAG_SPECIAL_SQUAD_TWO, SpecialPokemon_EventScript_SquadReminder
	setflag FLAG_SPECIAL_UNLOCKED_SQUAD
	msgbox SpecialPokemon_Text_SquadThanks, MSGBOX_DEFAULT
SpecialPokemon_EventScript_SquadOffer::
	setvar VAR_0x8004, SPECIAL_POKEMON_SQUAD
	msgbox SpecialPokemon_Text_SquadOffer, MSGBOX_YESNO
	goto SpecialPokemon_EventScript_GiftAnswer

SpecialPokemon_EventScript_StartSquad::
	setflag FLAG_SPECIAL_SQUAD_STARTED
	msgbox SpecialPokemon_Text_SquadTask, MSGBOX_DEFAULT
	release
	end

SpecialPokemon_EventScript_SquadReminder::
	msgbox SpecialPokemon_Text_SquadReminder, MSGBOX_DEFAULT
	release
	end

SpecialPokemon_EventScript_SquadOne::
	lock
	faceplayer
	goto_if_unset FLAG_SPECIAL_SQUAD_STARTED, SpecialPokemon_EventScript_SquadIdle
	goto_if_set FLAG_SPECIAL_SQUAD_ONE, SpecialPokemon_EventScript_SquadFound
	setflag FLAG_SPECIAL_SQUAD_ONE
	playmoncry SPECIES_SQUIRTLE, CRY_MODE_NORMAL
	msgbox SpecialPokemon_Text_SquadFound, MSGBOX_DEFAULT
	waitmoncry
	release
	end

SpecialPokemon_EventScript_SquadTwo::
	lock
	faceplayer
	goto_if_unset FLAG_SPECIAL_SQUAD_STARTED, SpecialPokemon_EventScript_SquadIdle
	goto_if_set FLAG_SPECIAL_SQUAD_TWO, SpecialPokemon_EventScript_SquadFound
	setflag FLAG_SPECIAL_SQUAD_TWO
	playmoncry SPECIES_SQUIRTLE, CRY_MODE_NORMAL
	msgbox SpecialPokemon_Text_SquadFound, MSGBOX_DEFAULT
	waitmoncry
	release
	end

SpecialPokemon_EventScript_SquadIdle::
	msgbox SpecialPokemon_Text_SquadIdle, MSGBOX_DEFAULT
	release
	end

SpecialPokemon_EventScript_SquadFound::
	msgbox SpecialPokemon_Text_SquadFoundAgain, MSGBOX_DEFAULT
	release
	end

SpecialPokemon_EventScript_KilnHelper::
	lock
	faceplayer
	goto_if_set FLAG_SPECIAL_UNLOCKED_FIREFIGHTER, SpecialPokemon_EventScript_FirefighterOffer
	goto_if_unset FLAG_SPECIAL_FIREFIGHTER_STARTED, SpecialPokemon_EventScript_StartFirefighter
	goto_if_unset FLAG_SPECIAL_FIREFIGHTER_WATER, SpecialPokemon_EventScript_FirefighterReminder
	setflag FLAG_SPECIAL_UNLOCKED_FIREFIGHTER
	msgbox SpecialPokemon_Text_FirefighterThanks, MSGBOX_DEFAULT
SpecialPokemon_EventScript_FirefighterOffer::
	setvar VAR_0x8004, SPECIAL_POKEMON_FIREFIGHTER
	msgbox SpecialPokemon_Text_FirefighterOffer, MSGBOX_YESNO
	goto SpecialPokemon_EventScript_GiftAnswer

SpecialPokemon_EventScript_StartFirefighter::
	setflag FLAG_SPECIAL_FIREFIGHTER_STARTED
	msgbox SpecialPokemon_Text_FirefighterTask, MSGBOX_DEFAULT
	release
	end

SpecialPokemon_EventScript_FirefighterReminder::
	msgbox SpecialPokemon_Text_FirefighterReminder, MSGBOX_DEFAULT
	release
	end

SpecialPokemon_EventScript_WellHelper::
	lock
	faceplayer
	goto_if_unset FLAG_SPECIAL_FIREFIGHTER_STARTED, SpecialPokemon_EventScript_WellIdle
	goto_if_set FLAG_SPECIAL_FIREFIGHTER_WATER, SpecialPokemon_EventScript_WaterAgain
	setflag FLAG_SPECIAL_FIREFIGHTER_WATER
	msgbox SpecialPokemon_Text_WaterDelivery, MSGBOX_DEFAULT
	release
	end

SpecialPokemon_EventScript_WellIdle::
	msgbox SpecialPokemon_Text_WellIdle, MSGBOX_DEFAULT
	release
	end

SpecialPokemon_EventScript_WaterAgain::
	msgbox SpecialPokemon_Text_WaterAgain, MSGBOX_DEFAULT
	release
	end

SpecialPokemon_EventScript_Florist::
	lock
	faceplayer
	goto_if_set FLAG_SPECIAL_UNLOCKED_FLOWER_CROWN, SpecialPokemon_EventScript_FlowerOffer
	goto_if_unset FLAG_SPECIAL_FLOWERS_STARTED, SpecialPokemon_EventScript_StartFlowers
	goto_if_unset FLAG_SPECIAL_FLOWERS_ONE, SpecialPokemon_EventScript_FlowerReminder
	goto_if_unset FLAG_SPECIAL_FLOWERS_TWO, SpecialPokemon_EventScript_FlowerReminder
	setflag FLAG_SPECIAL_UNLOCKED_FLOWER_CROWN
	msgbox SpecialPokemon_Text_FlowerThanks, MSGBOX_DEFAULT
SpecialPokemon_EventScript_FlowerOffer::
	setvar VAR_0x8004, SPECIAL_POKEMON_FLOWER_CROWN
	msgbox SpecialPokemon_Text_FlowerOffer, MSGBOX_YESNO
	goto SpecialPokemon_EventScript_GiftAnswer

SpecialPokemon_EventScript_StartFlowers::
	setflag FLAG_SPECIAL_FLOWERS_STARTED
	msgbox SpecialPokemon_Text_FlowerTask, MSGBOX_DEFAULT
	release
	end

SpecialPokemon_EventScript_FlowerReminder::
	msgbox SpecialPokemon_Text_FlowerReminder, MSGBOX_DEFAULT
	release
	end

SpecialPokemon_EventScript_FlowerResidentOne::
	lock
	faceplayer
	goto_if_unset FLAG_SPECIAL_FLOWERS_STARTED, SpecialPokemon_EventScript_FlowerResidentIdle
	goto_if_set FLAG_SPECIAL_FLOWERS_ONE, SpecialPokemon_EventScript_FlowerDelivered
	setflag FLAG_SPECIAL_FLOWERS_ONE
	msgbox SpecialPokemon_Text_FlowerDelivered, MSGBOX_DEFAULT
	release
	end

SpecialPokemon_EventScript_FlowerResidentTwo::
	lock
	faceplayer
	goto_if_unset FLAG_SPECIAL_FLOWERS_STARTED, SpecialPokemon_EventScript_FlowerResidentIdle
	goto_if_set FLAG_SPECIAL_FLOWERS_TWO, SpecialPokemon_EventScript_FlowerDelivered
	setflag FLAG_SPECIAL_FLOWERS_TWO
	msgbox SpecialPokemon_Text_FlowerDelivered, MSGBOX_DEFAULT
	release
	end

SpecialPokemon_EventScript_FlowerResidentIdle::
	msgbox SpecialPokemon_Text_FlowerResidentIdle, MSGBOX_DEFAULT
	release
	end

SpecialPokemon_EventScript_FlowerDelivered::
	msgbox SpecialPokemon_Text_FlowerDeliveredAgain, MSGBOX_DEFAULT
	release
	end

SpecialPokemon_EventScript_Surfer::
	lock
	faceplayer
	setflag FLAG_SPECIAL_UNLOCKED_SURFBOARD
	msgbox SpecialPokemon_Text_Surfer, MSGBOX_DEFAULT
	release
	end

SpecialPokemon_EventScript_Surfboard::
	lock
	faceplayer
	goto_if_unset FLAG_SPECIAL_UNLOCKED_SURFBOARD, SpecialPokemon_EventScript_MeetSurfer
	setvar VAR_0x8004, SPECIAL_POKEMON_SURFBOARD
	goto SpecialPokemon_EventScript_Encounter

SpecialPokemon_EventScript_MeetSurfer::
	msgbox SpecialPokemon_Text_MeetSurfer, MSGBOX_DEFAULT
	release
	end

SpecialPokemon_EventScript_PirateSailor::
	lock
	faceplayer
	setflag FLAG_SPECIAL_UNLOCKED_PIRATE
	msgbox SpecialPokemon_Text_PirateSailor, MSGBOX_DEFAULT
	release
	end

SpecialPokemon_EventScript_Pirate::
	lock
	faceplayer
	goto_if_unset FLAG_SPECIAL_UNLOCKED_PIRATE, SpecialPokemon_EventScript_MeetSailor
	setvar VAR_0x8004, SPECIAL_POKEMON_PIRATE
	goto SpecialPokemon_EventScript_Encounter

SpecialPokemon_EventScript_MeetSailor::
	msgbox SpecialPokemon_Text_MeetSailor, MSGBOX_DEFAULT
	release
	end

SpecialPokemon_EventScript_Encounter::
	copyvar VAR_0x8006, VAR_0x8004
	setvar VAR_0x8004, PARTY_SIZE
	specialvar VAR_RESULT, CountPartyAliveNonEggMons_IgnoreVar0x8004Slot
	copyvar VAR_0x8004, VAR_0x8006
	goto_if_eq VAR_RESULT, 0, SpecialPokemon_EventScript_HealFirst
	msgbox SpecialPokemon_Text_EncounterOffer, MSGBOX_YESNO
	goto_if_eq VAR_RESULT, NO, SpecialPokemon_EventScript_Later
	closemessage
	special SpecialPokemon_CreateEncounter
	goto_if_eq VAR_RESULT, FALSE, SpecialPokemon_EventScript_Later
	dowildbattle
	release
	end

SpecialPokemon_EventScript_HealFirst::
	msgbox SpecialPokemon_Text_HealFirst, MSGBOX_DEFAULT
	release
	end

SpecialPokemon_Text_ClassicCapWelcome:
	.string "A new journey deserves a friend!\n"
	.string "I raise PIKACHU with classic red caps.$"
SpecialPokemon_Text_ClassicCapOffer:
	.string "Would you like a new red-cap PIKACHU?\n"
	.string "It's a free welcome gift.$"
SpecialPokemon_Text_BalloonSeller:
	.string "My balloons help these PIKACHU fly!\n"
	.string "They love meeting new TRAINERS.$"
SpecialPokemon_Text_BalloonsOffer:
	.string "Take a new balloon PIKACHU with you?\n"
	.string "There's no charge.$"
SpecialPokemon_Text_Received:
	.string "{PLAYER} received a special POKéMON!$"
SpecialPokemon_Text_GiftAgain:
	.string "Come back whenever you'd like\n"
	.string "another. No errands or fees!$"
SpecialPokemon_Text_Later:
	.string "No hurry. You can try again\n"
	.string "whenever you're ready.$"
SpecialPokemon_Text_StartJourneyFirst:
	.string "Visit the professor and meet your\n"
	.string "first POKéMON. Then come see me!$"
SpecialPokemon_Text_SquadTask:
	.string "Two SQUIRTLE are exploring outside\n"
	.string "our FAN CLUB. Please check on both.\p"
	.string "One is southwest of the door.\n"
	.string "The other is southeast.\p"
	.string "Talk to them, then come back here.\n"
	.string "There's no need to lead them home.$"
SpecialPokemon_Text_SquadReminder:
	.string "Please talk to both SQUIRTLE just\n"
	.string "south of the FAN CLUB, then return.$"
SpecialPokemon_Text_SquadThanks:
	.string "Both are safe! Thank you!\n"
	.string "Our sunglasses squad welcomes you.$"
SpecialPokemon_Text_SquadOffer:
	.string "Would you like a new SQUIRTLE\n"
	.string "wearing squad sunglasses?$"
SpecialPokemon_Text_SquadIdle:
	.string "SQUIRTLE is enjoying a little walk.\n"
	.string "Its organizer is in the FAN CLUB.$"
SpecialPokemon_Text_SquadFound:
	.string "SQUIRTLE: Squirt!\p"
	.string "This SQUIRTLE is safe. You can\n"
	.string "report back to the FAN CLUB.$"
SpecialPokemon_Text_SquadFoundAgain:
	.string "SQUIRTLE is safe and happy.\n"
	.string "The organizer will be glad to hear.$"
SpecialPokemon_Text_FirefighterTask:
	.string "Let's practice fire safety!\n"
	.string "We need water for a demonstration.\p"
	.string "Please speak to our helper on the\n"
	.string "east side of SLOWPOKE WELL.\p"
	.string "Then return here to the kiln.\n"
	.string "You won't need to carry any items.$"
SpecialPokemon_Text_FirefighterReminder:
	.string "Our helper is east of SLOWPOKE WELL.\n"
	.string "Ask for water, then return here.$"
SpecialPokemon_Text_FirefighterThanks:
	.string "The water is here! Keep water ready\n"
	.string "and let adults handle a kiln fire.\p"
	.string "Our helmet SQUIRTLE can make rain\n"
	.string "for the safety demonstration!$"
SpecialPokemon_Text_FirefighterOffer:
	.string "Would you like a new SQUIRTLE\n"
	.string "with a firefighter helmet?$"
SpecialPokemon_Text_WellIdle:
	.string "I help with fire-safety practice\n"
	.string "at the CHARCOAL KILN.$"
SpecialPokemon_Text_WaterDelivery:
	.string "Water for the kiln? I'll send it\n"
	.string "over. Please return to the helper.$"
SpecialPokemon_Text_WaterAgain:
	.string "The water is ready at the kiln.\n"
	.string "Your fire-safety helper is waiting.$"
SpecialPokemon_Text_FlowerTask:
	.string "Help me share some flowers!\n"
	.string "Two neighbors are waiting nearby.\p"
	.string "One is south of me by the pond.\n"
	.string "The other is farther southwest.\p"
	.string "Speak to both, then come back.\n"
	.string "I'll arrange the deliveries.$"
SpecialPokemon_Text_FlowerReminder:
	.string "Please speak to both neighbors\n"
	.string "south and southwest of me.$"
SpecialPokemon_Text_FlowerThanks:
	.string "Both deliveries are complete!\n"
	.string "My flower-crown EEVEE thank you.$"
SpecialPokemon_Text_FlowerOffer:
	.string "Would you like a new EEVEE\n"
	.string "wearing a flower crown?$"
SpecialPokemon_Text_FlowerResidentIdle:
	.string "Our florist is north of here.\n"
	.string "Her flower crowns are lovely!$"
SpecialPokemon_Text_FlowerDelivered:
	.string "Flowers from our florist?\n"
	.string "Thank you for arranging delivery!$"
SpecialPokemon_Text_FlowerDeliveredAgain:
	.string "The flowers are lovely!\n"
	.string "Please give the florist my thanks.$"
SpecialPokemon_Text_Surfer:
	.string "That PIKACHU rides its own board!\n"
	.string "Talk to it if you'd like to catch it.\p"
	.string "More surfers visit this shore.\n"
	.string "You can try again whenever you like.$"
SpecialPokemon_Text_MeetSurfer:
	.string "PIKACHU balances on its surfboard.\n"
	.string "The nearby surfer waves you over.$"
SpecialPokemon_Text_PirateSailor:
	.string "Ahoy! That bandana-wearing TOTODILE\n"
	.string "is looking for a new crew.\p"
	.string "Talk to it for a normal catch battle.\n"
	.string "More pirates always visit this dock!$"
SpecialPokemon_Text_MeetSailor:
	.string "TOTODILE adjusts its pirate bandana.\n"
	.string "The sailor beside it waves you over.$"
SpecialPokemon_Text_EncounterOffer:
	.string "Meet this special POKéMON in battle?\n"
	.string "Use your own POKé BALLS to catch it.$"
SpecialPokemon_Text_HealFirst:
	.string "Your team needs a healthy POKéMON\n"
	.string "before you can start this battle.$"
