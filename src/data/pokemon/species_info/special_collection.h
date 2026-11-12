#define SPECIAL_BASE_STAT(value) (((value) * 115 + 50) / 100)

#define SPECIAL_PIKACHU_INFO \
    .baseHP        = SPECIAL_BASE_STAT(35), \
    .baseAttack    = SPECIAL_BASE_STAT(55), \
    .baseDefense   = SPECIAL_BASE_STAT(PIKACHU_DEFENSE), \
    .baseSpeed     = SPECIAL_BASE_STAT(90), \
    .baseSpAttack  = SPECIAL_BASE_STAT(50), \
    .baseSpDefense = SPECIAL_BASE_STAT(P_UPDATED_STATS >= GEN_6 || P_UPDATED_STATS == GEN_1 ? 50 : 40), \
    .types = MON_TYPES(TYPE_ELECTRIC), \
    .catchRate = 190, \
    .expYield = PIKACHU_EXP_YIELD, \
    .evYield_Speed = 2, \
    .genderRatio = PERCENT_FEMALE(50), \
    .eggCycles = 10, \
    .friendship = STANDARD_FRIENDSHIP, \
    .growthRate = GROWTH_MEDIUM_FAST, \
    .eggGroups = MON_EGG_GROUPS(EGG_GROUP_NO_EGGS_DISCOVERED), \
    .abilities = { ABILITY_STATIC, ABILITY_NONE, ABILITY_LIGHTNING_ROD }, \
    .bodyColor = BODY_COLOR_YELLOW, \
    .speciesName = _("Pikachu"), \
    .cryId = CRY_PIKACHU, \
    .natDexNum = NATIONAL_DEX_PIKACHU, \
    .categoryName = _("Mouse"), \
    .height = 4, \
    .weight = 60, \
    .description = gPikachuPokedexText, \
    .pokemonScale = 479, \
    .pokemonOffset = 19, \
    .trainerScale = 256, \
    .trainerOffset = 0, \
    .levelUpLearnset = sPikachuLevelUpLearnset, \
    .teachableLearnset = sPikachuTeachableLearnset, \
    .formSpeciesIdTable = sPikachuFormSpeciesIdTable,

#define SPECIAL_SQUIRTLE_INFO \
    .baseHP        = SPECIAL_BASE_STAT(44), \
    .baseAttack    = SPECIAL_BASE_STAT(48), \
    .baseDefense   = SPECIAL_BASE_STAT(65), \
    .baseSpeed     = SPECIAL_BASE_STAT(43), \
    .baseSpAttack  = SPECIAL_BASE_STAT(50), \
    .baseSpDefense = SPECIAL_BASE_STAT(P_UPDATED_STATS >= GEN_2 ? 64 : 50), \
    .types = MON_TYPES(TYPE_WATER), \
    .catchRate = 45, \
    .expYield = (P_UPDATED_EXP_YIELDS >= GEN_5) ? 63 : 66, \
    .evYield_Defense = 1, \
    .genderRatio = PERCENT_FEMALE(12.5), \
    .eggCycles = 20, \
    .friendship = STANDARD_FRIENDSHIP, \
    .growthRate = GROWTH_MEDIUM_SLOW, \
    .eggGroups = MON_EGG_GROUPS(EGG_GROUP_NO_EGGS_DISCOVERED), \
    .abilities = { ABILITY_TORRENT, ABILITY_NONE, ABILITY_RAIN_DISH }, \
    .bodyColor = BODY_COLOR_BLUE, \
    .speciesName = _("Squirtle"), \
    .cryId = CRY_SQUIRTLE, \
    .natDexNum = NATIONAL_DEX_SQUIRTLE, \
    .categoryName = _("Tiny Turtle"), \
    .height = 5, \
    .weight = 90, \
    .description = COMPOUND_STRING( \
    "Its shell is not just for protection.\n" \
    "Its rounded shape and the grooves on its\n" \
    "surface minimize resistance in water,\n" \
    "enabling Squirtle to swim at high speeds."), \
    .pokemonScale = 412, \
    .pokemonOffset = 18, \
    .trainerScale = 256, \
    .trainerOffset = 0, \
    .levelUpLearnset = sSquirtleLevelUpLearnset, \
    .teachableLearnset = sSquirtleTeachableLearnset, \
    .eggMoveLearnset = sSquirtleEggMoveLearnset, \
    .formSpeciesIdTable = sSquirtleFormSpeciesIdTable,

#define SPECIAL_EEVEE_INFO \
    .baseHP        = SPECIAL_BASE_STAT(55), \
    .baseAttack    = SPECIAL_BASE_STAT(55), \
    .baseDefense   = SPECIAL_BASE_STAT(50), \
    .baseSpeed     = SPECIAL_BASE_STAT(55), \
    .baseSpAttack  = SPECIAL_BASE_STAT(EEVEE_SP_ATK), \
    .baseSpDefense = SPECIAL_BASE_STAT(65), \
    .types = MON_TYPES(TYPE_NORMAL), \
    .catchRate = 45, \
    .expYield = (P_UPDATED_EXP_YIELDS >= GEN_5) ? 65 : 92, \
    .evYield_SpDefense = 1, \
    .genderRatio = PERCENT_FEMALE(12.5), \
    .eggCycles = 35, \
    .friendship = STANDARD_FRIENDSHIP, \
    .growthRate = GROWTH_MEDIUM_FAST, \
    .eggGroups = MON_EGG_GROUPS(EGG_GROUP_NO_EGGS_DISCOVERED), \
    .abilities = EEVEE_ABILITIES, \
    .bodyColor = BODY_COLOR_BROWN, \
    .speciesName = _("Eevee"), \
    .cryId = CRY_EEVEE, \
    .natDexNum = NATIONAL_DEX_EEVEE, \
    .categoryName = _("Evolution"), \
    .height = 3, \
    .weight = 65, \
    .description = gEeveePokedexText, \
    .pokemonScale = 476, \
    .pokemonOffset = 18, \
    .trainerScale = 256, \
    .trainerOffset = 0, \
    .levelUpLearnset = sEeveeLevelUpLearnset, \
    .teachableLearnset = sEeveeTeachableLearnset, \
    .eggMoveLearnset = sEeveeEggMoveLearnset, \
    .formSpeciesIdTable = sEeveeFormSpeciesIdTable,

#define SPECIAL_TOTODILE_INFO \
    .baseHP        = SPECIAL_BASE_STAT(50), \
    .baseAttack    = SPECIAL_BASE_STAT(65), \
    .baseDefense   = SPECIAL_BASE_STAT(64), \
    .baseSpeed     = SPECIAL_BASE_STAT(43), \
    .baseSpAttack  = SPECIAL_BASE_STAT(44), \
    .baseSpDefense = SPECIAL_BASE_STAT(48), \
    .types = MON_TYPES(TYPE_WATER), \
    .catchRate = 45, \
    .expYield = (P_UPDATED_EXP_YIELDS >= GEN_5) ? 63 : 66, \
    .evYield_Attack = 1, \
    .genderRatio = PERCENT_FEMALE(12.5), \
    .eggCycles = 20, \
    .friendship = STANDARD_FRIENDSHIP, \
    .growthRate = GROWTH_MEDIUM_SLOW, \
    .eggGroups = MON_EGG_GROUPS(EGG_GROUP_NO_EGGS_DISCOVERED), \
    .abilities = { ABILITY_TORRENT, ABILITY_NONE, ABILITY_SHEER_FORCE }, \
    .bodyColor = BODY_COLOR_BLUE, \
    .speciesName = _("Totodile"), \
    .cryId = CRY_TOTODILE, \
    .natDexNum = NATIONAL_DEX_TOTODILE, \
    .categoryName = _("Big Jaw"), \
    .height = 6, \
    .weight = 95, \
    .description = COMPOUND_STRING( \
    "Despite its small body, Totodile's jaws\n" \
    "are very powerful. While it may think it is\n" \
    "just playfully nipping, its bite has enough\n" \
    "strength to cause serious injury."), \
    .pokemonScale = 487, \
    .pokemonOffset = 20, \
    .trainerScale = 256, \
    .trainerOffset = 0, \
    .levelUpLearnset = sTotodileLevelUpLearnset, \
    .teachableLearnset = sTotodileTeachableLearnset, \
    .eggMoveLearnset = sTotodileEggMoveLearnset, \
    .formSpeciesIdTable = sTotodileFormSpeciesIdTable,

#define SPECIAL_GRAPHICS(name, iconPalette) \
    .frontPic = gMonFrontPic_Special##name, \
    .frontAnimFrames = ANIM_FRAMES(ANIMCMD_FRAME(1, 30), ANIMCMD_FRAME(0, 1),), \
    .frontAnimId = ANIM_V_SQUISH_AND_BOUNCE, \
    .backPic = gMonBackPic_Special##name, \
    .backAnimId = BACK_ANIM_CONCAVE_ARC_SMALL, \
    .palette = gMonPalette_Special##name, \
    .shinyPalette = gMonPalette_Special##name, \
    .iconSprite = gMonIcon_Special##name, \
    .iconPalIndex = iconPalette, \
    .pokemonJumpType = PKMN_JUMP_TYPE_NORMAL,

// Opaque bounds of each sprite: the Y offset is the empty rows under frame 0, which rests the
// sprite on its battle platform. Remeasure after changing the art.
#define SPECIAL_BATTLE_COORDS(frontWidth, frontHeight, frontY, backWidth, backHeight, backY) \
    .frontPicSize = MON_COORDS_SIZE(frontWidth, frontHeight), \
    .frontPicYOffset = frontY, \
    .backPicSize = MON_COORDS_SIZE(backWidth, backHeight), \
    .backPicYOffset = backY,

#if P_FAMILY_PIKACHU
    [SPECIES_PIKACHU_CLASSIC_CAP] =
    {
        SPECIAL_PIKACHU_INFO
        SPECIAL_GRAPHICS(ClassicCap, 0)
        SPECIAL_BATTLE_COORDS(48, 48, 9, 64, 56, 4)
        OVERWORLD(sPicTable_SpecialClassicCap, SIZE_32x32, SHADOW_SIZE_M, TRACKS_FOOT, sAnimTable_Following,
            gOverworldPalette_SpecialClassicCap, gOverworldPalette_SpecialClassicCap)
        FOOTPRINT(Pikachu)
    },
#endif

#if P_FAMILY_PIKACHU
    [SPECIES_PIKACHU_SURFBOARD] =
    {
        SPECIAL_PIKACHU_INFO
        SPECIAL_GRAPHICS(Surfboard, 2)
        SPECIAL_BATTLE_COORDS(64, 56, 0, 64, 64, 0)
        OVERWORLD(sPicTable_SpecialSurfboard, SIZE_32x32, SHADOW_SIZE_M, TRACKS_FOOT, sAnimTable_Following,
            gOverworldPalette_SpecialSurfboard, gOverworldPalette_SpecialSurfboard)
        FOOTPRINT(Pikachu)
    },
#endif

#if P_FAMILY_PIKACHU
    [SPECIES_PIKACHU_BALLOONS] =
    {
        SPECIAL_PIKACHU_INFO
        SPECIAL_GRAPHICS(Balloons, 0)
        SPECIAL_BATTLE_COORDS(64, 56, 9, 64, 64, 4)
        OVERWORLD(sPicTable_SpecialBalloons, SIZE_32x32, SHADOW_SIZE_M, TRACKS_FOOT, sAnimTable_Following,
            gOverworldPalette_SpecialBalloons, gOverworldPalette_SpecialBalloons)
        FOOTPRINT(Pikachu)
    },
#endif

#if P_FAMILY_SQUIRTLE
    [SPECIES_SQUIRTLE_SQUAD] =
    {
        SPECIAL_SQUIRTLE_INFO
        SPECIAL_GRAPHICS(Squad, 0)
        SPECIAL_BATTLE_COORDS(40, 40, 11, 48, 48, 9)
        OVERWORLD(sPicTable_SpecialSquad, SIZE_32x32, SHADOW_SIZE_M, TRACKS_FOOT, sAnimTable_Following,
            gOverworldPalette_SpecialSquad, gOverworldPalette_SpecialSquad)
        FOOTPRINT(Squirtle)
    },
#endif

#if P_FAMILY_SQUIRTLE
    [SPECIES_SQUIRTLE_FIREFIGHTER] =
    {
        SPECIAL_SQUIRTLE_INFO
        SPECIAL_GRAPHICS(Firefighter, 0)
        SPECIAL_BATTLE_COORDS(40, 48, 11, 48, 56, 9)
        OVERWORLD(sPicTable_SpecialFirefighter, SIZE_32x32, SHADOW_SIZE_M, TRACKS_FOOT, sAnimTable_Following,
            gOverworldPalette_SpecialFirefighter, gOverworldPalette_SpecialFirefighter)
        FOOTPRINT(Squirtle)
    },
#endif

#if P_FAMILY_EEVEE
    [SPECIES_EEVEE_FLOWER_CROWN] =
    {
        SPECIAL_EEVEE_INFO
        SPECIAL_GRAPHICS(FlowerCrown, 2)
        SPECIAL_BATTLE_COORDS(40, 48, 11, 56, 48, 10)
        OVERWORLD(sPicTable_SpecialFlowerCrown, SIZE_32x32, SHADOW_SIZE_M, TRACKS_FOOT, sAnimTable_Following,
            gOverworldPalette_SpecialFlowerCrown, gOverworldPalette_SpecialFlowerCrown)
        FOOTPRINT(Eevee)
    },
#endif

#if P_FAMILY_TOTODILE
    [SPECIES_TOTODILE_PIRATE] =
    {
        SPECIAL_TOTODILE_INFO
        SPECIAL_GRAPHICS(Pirate, 0)
        SPECIAL_BATTLE_COORDS(40, 40, 14, 56, 48, 10)
        OVERWORLD(sPicTable_SpecialPirate, SIZE_32x32, SHADOW_SIZE_M, TRACKS_FOOT, sAnimTable_Following_Asym,
            gOverworldPalette_SpecialPirate, gOverworldPalette_SpecialPirate)
        FOOTPRINT(Totodile)
    },
#endif

#undef SPECIAL_PIKACHU_INFO
#undef SPECIAL_SQUIRTLE_INFO
#undef SPECIAL_EEVEE_INFO
#undef SPECIAL_TOTODILE_INFO
#undef SPECIAL_GRAPHICS
#undef SPECIAL_BATTLE_COORDS

#undef SPECIAL_BASE_STAT
