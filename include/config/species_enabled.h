#ifndef GUARD_CONFIG_SPECIES_ENABLED_H
#define GUARD_CONFIG_SPECIES_ENABLED_H

// Modifying the latest generation WILL change the saveblock due to Dex flags and will require a new save file.
// Generations of Pokémon are defined by the first member introduced,
// so Pikachu depends on the Gen 1 setting despite Pichu being the lowest member of the evolution tree.
// Eg: If P_GEN_2_POKEMON is set to FALSE, all members of the Sneasel Family will be disabled
// (Sneasel + Hisuian, Weavile and Sneasler).
#define P_GEN_1_POKEMON                  TRUE // Generation 1 Pokémon (RGBY)
#define P_GEN_2_POKEMON                  TRUE // Generation 2 Pokémon (GSC)
#define P_GEN_3_POKEMON                  TRUE // Generation 3 Pokémon (RSE, FRLG)
#define P_GEN_4_POKEMON                  TRUE // Generation 4 Pokémon (DPPt, HGSS)
#define P_GEN_5_POKEMON                  TRUE // Generation 5 Pokémon (BW, B2W2)
#define P_GEN_6_POKEMON                  TRUE // Generation 6 Pokémon (XY, ORAS)
#define P_GEN_7_POKEMON                  TRUE // Generation 7 Pokémon (SM, USUM, LGPE)
#define P_GEN_8_POKEMON                  TRUE // Generation 8 Pokémon (SwSh, BDSP, LA)
#define P_GEN_9_POKEMON                  TRUE // Generation 9 Pokémon (SV)

// Setting this to TRUE will add the new evolutions to the Regional Dex.
#define P_NEW_EVOS_IN_REGIONAL_DEX       TRUE

// Battle gimmick specific Forms.
#define P_MEGA_EVOLUTIONS                TRUE
#define P_PRIMAL_REVERSIONS              TRUE // Groudon and Kyogre only.
#define P_ULTRA_BURST_FORMS              TRUE // Ultra Necrozma only.
#define P_GIGANTAMAX_FORMS               FALSE // world-strip: no Dynamax in this game
#define P_TERA_FORMS                     FALSE // world-strip: no Terastal in this game

#define P_GEN_9_MEGA_EVOLUTIONS          P_MEGA_EVOLUTIONS // Mega Evolutions introduced in Z-A and its DLC

// Fusion forms
#define P_FUSION_FORMS                   TRUE

// Regional Forms. Includes Regional Form evolutions, like Sirfetch'd.
#define P_REGIONAL_FORMS                 TRUE
#define P_ALOLAN_FORMS                   P_REGIONAL_FORMS
#define P_GALARIAN_FORMS                 P_REGIONAL_FORMS
#define P_HISUIAN_FORMS                  P_REGIONAL_FORMS
#define P_PALDEAN_FORMS                  P_REGIONAL_FORMS

// Big groups of forms that aren't always desired when choosing families.
#define P_PIKACHU_EXTRA_FORMS            TRUE
#define P_COSPLAY_PIKACHU_FORMS          P_PIKACHU_EXTRA_FORMS
#define P_CAP_PIKACHU_FORMS              P_PIKACHU_EXTRA_FORMS

// Cross-generation evolutions. Includes pre-evolutions.
#define P_CROSS_GENERATION_EVOS          TRUE
#define P_GEN_2_CROSS_EVOS               P_CROSS_GENERATION_EVOS
#define P_GEN_3_CROSS_EVOS               P_CROSS_GENERATION_EVOS
#define P_GEN_4_CROSS_EVOS               P_CROSS_GENERATION_EVOS
//#define P_GEN_5_CROSS_EVOS             // Gen 5 didn't introduce any cross-gen evos.
#define P_GEN_6_CROSS_EVOS               P_CROSS_GENERATION_EVOS // Just Sylveon.
//#define P_GEN_7_CROSS_EVOS             // Alolan evolutions handled by P_ALOLAN_FORMS.
#define P_GEN_8_CROSS_EVOS               P_CROSS_GENERATION_EVOS // Regional evolutions handled by P_GALARIAN_FORMS and P_HISUIAN_FORMS.
#define P_GEN_9_CROSS_EVOS               P_CROSS_GENERATION_EVOS // Clodsire handled by P_PALDEAN_FORMS.

// To disable specific families, replace P_GEN_x_POKEMON with FALSE.
#define P_FAMILY_BULBASAUR               P_GEN_1_POKEMON
#define P_FAMILY_CHARMANDER              P_GEN_1_POKEMON
#define P_FAMILY_SQUIRTLE                P_GEN_1_POKEMON
#define P_FAMILY_CATERPIE                P_GEN_1_POKEMON
#define P_FAMILY_WEEDLE                  P_GEN_1_POKEMON
#define P_FAMILY_PIDGEY                  P_GEN_1_POKEMON
#define P_FAMILY_RATTATA                 P_GEN_1_POKEMON
#define P_FAMILY_SPEAROW                 P_GEN_1_POKEMON
#define P_FAMILY_EKANS                   P_GEN_1_POKEMON
#define P_FAMILY_PIKACHU                 P_GEN_1_POKEMON
#define P_FAMILY_SANDSHREW               P_GEN_1_POKEMON
#define P_FAMILY_NIDORAN                 P_GEN_1_POKEMON
#define P_FAMILY_CLEFAIRY                P_GEN_1_POKEMON
#define P_FAMILY_VULPIX                  P_GEN_1_POKEMON
#define P_FAMILY_JIGGLYPUFF              P_GEN_1_POKEMON
#define P_FAMILY_ZUBAT                   P_GEN_1_POKEMON
#define P_FAMILY_ODDISH                  P_GEN_1_POKEMON
#define P_FAMILY_PARAS                   P_GEN_1_POKEMON
#define P_FAMILY_VENONAT                 P_GEN_1_POKEMON
#define P_FAMILY_DIGLETT                 P_GEN_1_POKEMON
#define P_FAMILY_MEOWTH                  P_GEN_1_POKEMON
#define P_FAMILY_PSYDUCK                 P_GEN_1_POKEMON
#define P_FAMILY_MANKEY                  P_GEN_1_POKEMON
#define P_FAMILY_GROWLITHE               P_GEN_1_POKEMON
#define P_FAMILY_POLIWAG                 P_GEN_1_POKEMON
#define P_FAMILY_ABRA                    P_GEN_1_POKEMON
#define P_FAMILY_MACHOP                  P_GEN_1_POKEMON
#define P_FAMILY_BELLSPROUT              P_GEN_1_POKEMON
#define P_FAMILY_TENTACOOL               P_GEN_1_POKEMON
#define P_FAMILY_GEODUDE                 P_GEN_1_POKEMON
#define P_FAMILY_PONYTA                  P_GEN_1_POKEMON
#define P_FAMILY_SLOWPOKE                P_GEN_1_POKEMON
#define P_FAMILY_MAGNEMITE               P_GEN_1_POKEMON
#define P_FAMILY_FARFETCHD               P_GEN_1_POKEMON
#define P_FAMILY_DODUO                   P_GEN_1_POKEMON
#define P_FAMILY_SEEL                    P_GEN_1_POKEMON
#define P_FAMILY_GRIMER                  P_GEN_1_POKEMON
#define P_FAMILY_SHELLDER                P_GEN_1_POKEMON
#define P_FAMILY_GASTLY                  P_GEN_1_POKEMON
#define P_FAMILY_ONIX                    P_GEN_1_POKEMON
#define P_FAMILY_DROWZEE                 P_GEN_1_POKEMON
#define P_FAMILY_KRABBY                  P_GEN_1_POKEMON
#define P_FAMILY_VOLTORB                 P_GEN_1_POKEMON
#define P_FAMILY_EXEGGCUTE               P_GEN_1_POKEMON
#define P_FAMILY_CUBONE                  P_GEN_1_POKEMON
#define P_FAMILY_HITMONS                 P_GEN_1_POKEMON
#define P_FAMILY_LICKITUNG               P_GEN_1_POKEMON
#define P_FAMILY_KOFFING                 P_GEN_1_POKEMON
#define P_FAMILY_RHYHORN                 P_GEN_1_POKEMON
#define P_FAMILY_CHANSEY                 P_GEN_1_POKEMON
#define P_FAMILY_TANGELA                 P_GEN_1_POKEMON
#define P_FAMILY_KANGASKHAN              P_GEN_1_POKEMON
#define P_FAMILY_HORSEA                  P_GEN_1_POKEMON
#define P_FAMILY_GOLDEEN                 P_GEN_1_POKEMON
#define P_FAMILY_STARYU                  P_GEN_1_POKEMON
#define P_FAMILY_MR_MIME                 P_GEN_1_POKEMON
#define P_FAMILY_SCYTHER                 P_GEN_1_POKEMON
#define P_FAMILY_JYNX                    P_GEN_1_POKEMON
#define P_FAMILY_ELECTABUZZ              P_GEN_1_POKEMON
#define P_FAMILY_MAGMAR                  P_GEN_1_POKEMON
#define P_FAMILY_PINSIR                  P_GEN_1_POKEMON
#define P_FAMILY_TAUROS                  P_GEN_1_POKEMON
#define P_FAMILY_MAGIKARP                P_GEN_1_POKEMON
#define P_FAMILY_LAPRAS                  P_GEN_1_POKEMON
#define P_FAMILY_DITTO                   P_GEN_1_POKEMON
#define P_FAMILY_EEVEE                   P_GEN_1_POKEMON
#define P_FAMILY_PORYGON                 P_GEN_1_POKEMON
#define P_FAMILY_OMANYTE                 P_GEN_1_POKEMON
#define P_FAMILY_KABUTO                  P_GEN_1_POKEMON
#define P_FAMILY_AERODACTYL              P_GEN_1_POKEMON
#define P_FAMILY_SNORLAX                 P_GEN_1_POKEMON
#define P_FAMILY_ARTICUNO                P_GEN_1_POKEMON
#define P_FAMILY_ZAPDOS                  P_GEN_1_POKEMON
#define P_FAMILY_MOLTRES                 P_GEN_1_POKEMON
#define P_FAMILY_DRATINI                 P_GEN_1_POKEMON
#define P_FAMILY_MEWTWO                  P_GEN_1_POKEMON
#define P_FAMILY_MEW                     P_GEN_1_POKEMON

#define P_FAMILY_CHIKORITA               P_GEN_2_POKEMON
#define P_FAMILY_CYNDAQUIL               P_GEN_2_POKEMON
#define P_FAMILY_TOTODILE                P_GEN_2_POKEMON
#define P_FAMILY_SENTRET                 P_GEN_2_POKEMON
#define P_FAMILY_HOOTHOOT                P_GEN_2_POKEMON
#define P_FAMILY_LEDYBA                  P_GEN_2_POKEMON
#define P_FAMILY_SPINARAK                P_GEN_2_POKEMON
#define P_FAMILY_CHINCHOU                P_GEN_2_POKEMON
#define P_FAMILY_TOGEPI                  P_GEN_2_POKEMON
#define P_FAMILY_NATU                    P_GEN_2_POKEMON
#define P_FAMILY_MAREEP                  P_GEN_2_POKEMON
#define P_FAMILY_MARILL                  P_GEN_2_POKEMON
#define P_FAMILY_SUDOWOODO               P_GEN_2_POKEMON
#define P_FAMILY_HOPPIP                  P_GEN_2_POKEMON
#define P_FAMILY_AIPOM                   P_GEN_2_POKEMON
#define P_FAMILY_SUNKERN                 P_GEN_2_POKEMON
#define P_FAMILY_YANMA                   P_GEN_2_POKEMON
#define P_FAMILY_WOOPER                  P_GEN_2_POKEMON
#define P_FAMILY_MURKROW                 P_GEN_2_POKEMON
#define P_FAMILY_MISDREAVUS              P_GEN_2_POKEMON
#define P_FAMILY_UNOWN                   P_GEN_2_POKEMON
#define P_FAMILY_WOBBUFFET               P_GEN_2_POKEMON
#define P_FAMILY_GIRAFARIG               P_GEN_2_POKEMON
#define P_FAMILY_PINECO                  P_GEN_2_POKEMON
#define P_FAMILY_DUNSPARCE               P_GEN_2_POKEMON
#define P_FAMILY_GLIGAR                  P_GEN_2_POKEMON
#define P_FAMILY_SNUBBULL                P_GEN_2_POKEMON
#define P_FAMILY_QWILFISH                P_GEN_2_POKEMON
#define P_FAMILY_SHUCKLE                 P_GEN_2_POKEMON
#define P_FAMILY_HERACROSS               P_GEN_2_POKEMON
#define P_FAMILY_SNEASEL                 P_GEN_2_POKEMON
#define P_FAMILY_TEDDIURSA               P_GEN_2_POKEMON
#define P_FAMILY_SLUGMA                  P_GEN_2_POKEMON
#define P_FAMILY_SWINUB                  P_GEN_2_POKEMON
#define P_FAMILY_CORSOLA                 P_GEN_2_POKEMON
#define P_FAMILY_REMORAID                P_GEN_2_POKEMON
#define P_FAMILY_DELIBIRD                P_GEN_2_POKEMON
#define P_FAMILY_MANTINE                 P_GEN_2_POKEMON
#define P_FAMILY_SKARMORY                P_GEN_2_POKEMON
#define P_FAMILY_HOUNDOUR                P_GEN_2_POKEMON
#define P_FAMILY_PHANPY                  P_GEN_2_POKEMON
#define P_FAMILY_STANTLER                P_GEN_2_POKEMON
#define P_FAMILY_SMEARGLE                P_GEN_2_POKEMON
#define P_FAMILY_MILTANK                 P_GEN_2_POKEMON
#define P_FAMILY_RAIKOU                  P_GEN_2_POKEMON
#define P_FAMILY_ENTEI                   P_GEN_2_POKEMON
#define P_FAMILY_SUICUNE                 P_GEN_2_POKEMON
#define P_FAMILY_LARVITAR                P_GEN_2_POKEMON
#define P_FAMILY_LUGIA                   P_GEN_2_POKEMON
#define P_FAMILY_HO_OH                   P_GEN_2_POKEMON
#define P_FAMILY_CELEBI                  P_GEN_2_POKEMON

#define P_FAMILY_TREECKO                 P_GEN_3_POKEMON
#define P_FAMILY_TORCHIC                 P_GEN_3_POKEMON
#define P_FAMILY_MUDKIP                  P_GEN_3_POKEMON
#define P_FAMILY_POOCHYENA               P_GEN_3_POKEMON
#define P_FAMILY_ZIGZAGOON               P_GEN_3_POKEMON
#define P_FAMILY_WURMPLE                 P_GEN_3_POKEMON
#define P_FAMILY_LOTAD                   P_GEN_3_POKEMON
#define P_FAMILY_SEEDOT                  P_GEN_3_POKEMON
#define P_FAMILY_TAILLOW                 P_GEN_3_POKEMON
#define P_FAMILY_WINGULL                 P_GEN_3_POKEMON
#define P_FAMILY_RALTS                   P_GEN_3_POKEMON
#define P_FAMILY_SURSKIT                 P_GEN_3_POKEMON
#define P_FAMILY_SHROOMISH               P_GEN_3_POKEMON
#define P_FAMILY_SLAKOTH                 P_GEN_3_POKEMON
#define P_FAMILY_NINCADA                 P_GEN_3_POKEMON
#define P_FAMILY_WHISMUR                 P_GEN_3_POKEMON
#define P_FAMILY_MAKUHITA                P_GEN_3_POKEMON
#define P_FAMILY_NOSEPASS                P_GEN_3_POKEMON
#define P_FAMILY_SKITTY                  P_GEN_3_POKEMON
#define P_FAMILY_SABLEYE                 P_GEN_3_POKEMON
#define P_FAMILY_MAWILE                  P_GEN_3_POKEMON
#define P_FAMILY_ARON                    P_GEN_3_POKEMON
#define P_FAMILY_MEDITITE                P_GEN_3_POKEMON
#define P_FAMILY_ELECTRIKE               P_GEN_3_POKEMON
#define P_FAMILY_PLUSLE                  P_GEN_3_POKEMON
#define P_FAMILY_MINUN                   P_GEN_3_POKEMON
#define P_FAMILY_VOLBEAT_ILLUMISE        P_GEN_3_POKEMON
#define P_FAMILY_ROSELIA                 P_GEN_3_POKEMON
#define P_FAMILY_GULPIN                  P_GEN_3_POKEMON
#define P_FAMILY_CARVANHA                P_GEN_3_POKEMON
#define P_FAMILY_WAILMER                 P_GEN_3_POKEMON
#define P_FAMILY_NUMEL                   P_GEN_3_POKEMON
#define P_FAMILY_TORKOAL                 P_GEN_3_POKEMON
#define P_FAMILY_SPOINK                  P_GEN_3_POKEMON
#define P_FAMILY_SPINDA                  P_GEN_3_POKEMON
#define P_FAMILY_TRAPINCH                P_GEN_3_POKEMON
#define P_FAMILY_CACNEA                  P_GEN_3_POKEMON
#define P_FAMILY_SWABLU                  P_GEN_3_POKEMON
#define P_FAMILY_ZANGOOSE                P_GEN_3_POKEMON
#define P_FAMILY_SEVIPER                 P_GEN_3_POKEMON
#define P_FAMILY_LUNATONE                P_GEN_3_POKEMON
#define P_FAMILY_SOLROCK                 P_GEN_3_POKEMON
#define P_FAMILY_BARBOACH                P_GEN_3_POKEMON
#define P_FAMILY_CORPHISH                P_GEN_3_POKEMON
#define P_FAMILY_BALTOY                  P_GEN_3_POKEMON
#define P_FAMILY_LILEEP                  P_GEN_3_POKEMON
#define P_FAMILY_ANORITH                 P_GEN_3_POKEMON
#define P_FAMILY_FEEBAS                  P_GEN_3_POKEMON
#define P_FAMILY_CASTFORM                P_GEN_3_POKEMON
#define P_FAMILY_KECLEON                 P_GEN_3_POKEMON
#define P_FAMILY_SHUPPET                 P_GEN_3_POKEMON
#define P_FAMILY_DUSKULL                 P_GEN_3_POKEMON
#define P_FAMILY_TROPIUS                 P_GEN_3_POKEMON
#define P_FAMILY_CHIMECHO                P_GEN_3_POKEMON
#define P_FAMILY_ABSOL                   P_GEN_3_POKEMON
#define P_FAMILY_SNORUNT                 P_GEN_3_POKEMON
#define P_FAMILY_SPHEAL                  P_GEN_3_POKEMON
#define P_FAMILY_CLAMPERL                P_GEN_3_POKEMON
#define P_FAMILY_RELICANTH               P_GEN_3_POKEMON
#define P_FAMILY_LUVDISC                 P_GEN_3_POKEMON
#define P_FAMILY_BAGON                   P_GEN_3_POKEMON
#define P_FAMILY_BELDUM                  P_GEN_3_POKEMON
#define P_FAMILY_REGIROCK                P_GEN_3_POKEMON
#define P_FAMILY_REGICE                  P_GEN_3_POKEMON
#define P_FAMILY_REGISTEEL               P_GEN_3_POKEMON
#define P_FAMILY_LATIAS                  P_GEN_3_POKEMON
#define P_FAMILY_LATIOS                  P_GEN_3_POKEMON
#define P_FAMILY_KYOGRE                  P_GEN_3_POKEMON
#define P_FAMILY_GROUDON                 P_GEN_3_POKEMON
#define P_FAMILY_RAYQUAZA                P_GEN_3_POKEMON
#define P_FAMILY_JIRACHI                 P_GEN_3_POKEMON
#define P_FAMILY_DEOXYS                  P_GEN_3_POKEMON

#define P_FAMILY_TURTWIG                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_CHIMCHAR                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_PIPLUP                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_STARLY                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_BIDOOF                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_KRICKETOT               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_SHINX                   FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_CRANIDOS                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_SHIELDON                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_BURMY                   FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_COMBEE                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_PACHIRISU               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_BUIZEL                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_CHERUBI                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_SHELLOS                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_DRIFLOON                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_BUNEARY                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_GLAMEOW                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_STUNKY                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_BRONZOR                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_CHATOT                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_SPIRITOMB               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_GIBLE                   FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_RIOLU                   FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_HIPPOPOTAS              FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_SKORUPI                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_CROAGUNK                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_CARNIVINE               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_FINNEON                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_SNOVER                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_ROTOM                   FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_UXIE                    FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_MESPRIT                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_AZELF                   FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_DIALGA                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_PALKIA                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_HEATRAN                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_REGIGIGAS               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_GIRATINA                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_CRESSELIA               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_MANAPHY                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_DARKRAI                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_SHAYMIN                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)
#define P_FAMILY_ARCEUS                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_4_POKEMON)

#define P_FAMILY_VICTINI                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_SNIVY                   FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_TEPIG                   FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_OSHAWOTT                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_PATRAT                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_LILLIPUP                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_PURRLOIN                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_PANSAGE                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_PANSEAR                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_PANPOUR                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_MUNNA                   FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_PIDOVE                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_BLITZLE                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_ROGGENROLA              FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_WOOBAT                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_DRILBUR                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_AUDINO                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_TIMBURR                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_TYMPOLE                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_THROH                   FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_SAWK                    FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_SEWADDLE                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_VENIPEDE                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_COTTONEE                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_PETILIL                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_BASCULIN                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_SANDILE                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_DARUMAKA                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_MARACTUS                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_DWEBBLE                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_SCRAGGY                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_SIGILYPH                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_YAMASK                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_TIRTOUGA                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_ARCHEN                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_TRUBBISH                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_ZORUA                   FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_MINCCINO                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_GOTHITA                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_SOLOSIS                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_DUCKLETT                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_VANILLITE               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_DEERLING                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_EMOLGA                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_KARRABLAST              FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_FOONGUS                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_FRILLISH                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_ALOMOMOLA               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_JOLTIK                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_FERROSEED               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_KLINK                   FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_TYNAMO                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_ELGYEM                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_LITWICK                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_AXEW                    FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_CUBCHOO                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_CRYOGONAL               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_SHELMET                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_STUNFISK                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_MIENFOO                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_DRUDDIGON               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_GOLETT                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_PAWNIARD                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_BOUFFALANT              FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_RUFFLET                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_VULLABY                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_HEATMOR                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_DURANT                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_DEINO                   FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_LARVESTA                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_COBALION                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_TERRAKION               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_VIRIZION                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_TORNADUS                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_THUNDURUS               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_RESHIRAM                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_ZEKROM                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_LANDORUS                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_KYUREM                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_KELDEO                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_MELOETTA                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)
#define P_FAMILY_GENESECT                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_5_POKEMON)

#define P_FAMILY_CHESPIN                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_FENNEKIN                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_FROAKIE                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_BUNNELBY                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_FLETCHLING              FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_SCATTERBUG              FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_LITLEO                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_FLABEBE                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_SKIDDO                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_PANCHAM                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_FURFROU                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_ESPURR                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_HONEDGE                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_SPRITZEE                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_SWIRLIX                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_INKAY                   FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_BINACLE                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_SKRELP                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_CLAUNCHER               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_HELIOPTILE              FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_TYRUNT                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_AMAURA                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_HAWLUCHA                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_DEDENNE                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_CARBINK                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_GOOMY                   FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_KLEFKI                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_PHANTUMP                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_PUMPKABOO               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_BERGMITE                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_NOIBAT                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_XERNEAS                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_YVELTAL                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_ZYGARDE                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_DIANCIE                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_HOOPA                   FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)
#define P_FAMILY_VOLCANION               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_6_POKEMON)

#define P_FAMILY_ROWLET                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_LITTEN                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_POPPLIO                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_PIKIPEK                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_YUNGOOS                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_GRUBBIN                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_CRABRAWLER              FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_ORICORIO                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_CUTIEFLY                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_ROCKRUFF                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_WISHIWASHI              FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_MAREANIE                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_MUDBRAY                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_DEWPIDER                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_FOMANTIS                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_MORELULL                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_SALANDIT                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_STUFFUL                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_BOUNSWEET               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_COMFEY                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_ORANGURU                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_PASSIMIAN               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_WIMPOD                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_SANDYGAST               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_PYUKUMUKU               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_TYPE_NULL               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_MINIOR                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_KOMALA                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_TURTONATOR              FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_TOGEDEMARU              FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_MIMIKYU                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_BRUXISH                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_DRAMPA                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_DHELMISE                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_JANGMO_O                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_TAPU_KOKO               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_TAPU_LELE               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_TAPU_BULU               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_TAPU_FINI               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_COSMOG                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_NIHILEGO                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_BUZZWOLE                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_PHEROMOSA               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_XURKITREE               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_CELESTEELA              FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_KARTANA                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_GUZZLORD                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_NECROZMA                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_MAGEARNA                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_MARSHADOW               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_POIPOLE                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_STAKATAKA               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_BLACEPHALON             FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_ZERAORA                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)
#define P_FAMILY_MELTAN                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_7_POKEMON)

#define P_FAMILY_GROOKEY                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_SCORBUNNY               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_SOBBLE                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_SKWOVET                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_ROOKIDEE                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_BLIPBUG                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_NICKIT                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_GOSSIFLEUR              FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_WOOLOO                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_CHEWTLE                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_YAMPER                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_ROLYCOLY                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_APPLIN                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_SILICOBRA               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_CRAMORANT               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_ARROKUDA                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_TOXEL                   FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_SIZZLIPEDE              FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_CLOBBOPUS               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_SINISTEA                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_HATENNA                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_IMPIDIMP                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_MILCERY                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_FALINKS                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_PINCURCHIN              FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_SNOM                    FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_STONJOURNER             FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_EISCUE                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_INDEEDEE                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_MORPEKO                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_CUFANT                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_DRACOZOLT               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_ARCTOZOLT               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_DRACOVISH               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_ARCTOVISH               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_DURALUDON               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_DREEPY                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_ZACIAN                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_ZAMAZENTA               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_ETERNATUS               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_KUBFU                   FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_ZARUDE                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_REGIELEKI               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_REGIDRAGO               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_GLASTRIER               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_SPECTRIER               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_CALYREX                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)
#define P_FAMILY_ENAMORUS                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_8_POKEMON)

#define P_FAMILY_SPRIGATITO              FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_FUECOCO                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_QUAXLY                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_LECHONK                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_TAROUNTULA              FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_NYMBLE                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_PAWMI                   FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_TANDEMAUS               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_FIDOUGH                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_SMOLIV                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_SQUAWKABILLY            FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_NACLI                   FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_CHARCADET               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_TADBULB                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_WATTREL                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_MASCHIFF                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_SHROODLE                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_BRAMBLIN                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_TOEDSCOOL               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_KLAWF                   FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_CAPSAKID                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_RELLOR                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_FLITTLE                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_TINKATINK               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_WIGLETT                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_BOMBIRDIER              FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_FINIZEN                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_VAROOM                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_CYCLIZAR                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_ORTHWORM                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_GLIMMET                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_GREAVARD                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_FLAMIGO                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_CETODDLE                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_VELUZA                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_DONDOZO                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_TATSUGIRI               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_GREAT_TUSK              FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_SCREAM_TAIL             FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_BRUTE_BONNET            FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_FLUTTER_MANE            FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_SLITHER_WING            FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_SANDY_SHOCKS            FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_IRON_TREADS             FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_IRON_BUNDLE             FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_IRON_HANDS              FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_IRON_JUGULIS            FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_IRON_MOTH               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_IRON_THORNS             FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_FRIGIBAX                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_GIMMIGHOUL              FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_WO_CHIEN                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_CHIEN_PAO               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_TING_LU                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_CHI_YU                  FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_ROARING_MOON            FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_IRON_VALIANT            FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_KORAIDON                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_MIRAIDON                FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_WALKING_WAKE            FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_IRON_LEAVES             FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_POLTCHAGEIST            FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_SINISTCHA               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_OKIDOGI                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_MUNKIDORI               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_FEZANDIPITI             FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_OGERPON                 FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_GOUGING_FIRE            FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_RAGING_BOLT             FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_IRON_BOULDER            FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_IRON_CROWN              FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_TERAPAGOS               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)
#define P_FAMILY_PECHARUNT               FALSE // world-strip: unreferenced in all 3 campaigns (was P_GEN_9_POKEMON)

#endif // GUARD_CONFIG_SPECIES_ENABLED_H
