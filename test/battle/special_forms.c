#include "global.h"
#include "test/battle.h"

TEST("Special collection forms have their themed types and abilities")
{
    EXPECT_EQ(GetSpeciesType(SPECIES_PIKACHU_CLASSIC_CAP, 0), TYPE_ELECTRIC);
    EXPECT_EQ(GetSpeciesType(SPECIES_PIKACHU_CLASSIC_CAP, 1), TYPE_ELECTRIC);

    EXPECT_EQ(GetSpeciesType(SPECIES_PIKACHU_SURFBOARD, 0), TYPE_ELECTRIC);
    EXPECT_EQ(GetSpeciesType(SPECIES_PIKACHU_SURFBOARD, 1), TYPE_WATER);
    EXPECT_EQ(GetSpeciesAbility(SPECIES_PIKACHU_SURFBOARD, 0), ABILITY_SWIFT_SWIM);

    EXPECT_EQ(GetSpeciesType(SPECIES_PIKACHU_BALLOONS, 0), TYPE_ELECTRIC);
    EXPECT_EQ(GetSpeciesType(SPECIES_PIKACHU_BALLOONS, 1), TYPE_FLYING);
    EXPECT_EQ(GetSpeciesAbility(SPECIES_PIKACHU_BALLOONS, 0), ABILITY_GALE_WINGS);

    EXPECT_EQ(GetSpeciesType(SPECIES_SQUIRTLE_SQUAD, 0), TYPE_WATER);
    EXPECT_EQ(GetSpeciesType(SPECIES_SQUIRTLE_SQUAD, 1), TYPE_DARK);
    EXPECT_EQ(GetSpeciesAbility(SPECIES_SQUIRTLE_SQUAD, 0), ABILITY_INTIMIDATE);

    EXPECT_EQ(GetSpeciesType(SPECIES_SQUIRTLE_FIREFIGHTER, 0), TYPE_WATER);
    EXPECT_EQ(GetSpeciesType(SPECIES_SQUIRTLE_FIREFIGHTER, 1), TYPE_WATER);
    EXPECT_EQ(GetSpeciesAbility(SPECIES_SQUIRTLE_FIREFIGHTER, 0), ABILITY_FLASH_FIRE);

    EXPECT_EQ(GetSpeciesType(SPECIES_EEVEE_FLOWER_CROWN, 0), TYPE_NORMAL);
    EXPECT_EQ(GetSpeciesType(SPECIES_EEVEE_FLOWER_CROWN, 1), TYPE_FAIRY);

    EXPECT_EQ(GetSpeciesType(SPECIES_TOTODILE_PIRATE, 0), TYPE_WATER);
    EXPECT_EQ(GetSpeciesType(SPECIES_TOTODILE_PIRATE, 1), TYPE_GHOST);
    EXPECT_EQ(GetSpeciesAbility(SPECIES_TOTODILE_PIRATE, 0), ABILITY_CURSED_BODY);
}

// Surfboard Pikachu shares Classic Cap's stats and Electric STAB, so it is the unboosted control.
SINGLE_BATTLE_TEST("Classic Cap Pikachu has a built-in Light Ball that does not stack", s16 damage)
{
    u32 species = 0, item = 0, move = 0;

    PARAMETRIZE { species = SPECIES_PIKACHU_SURFBOARD;   item = ITEM_NONE;       move = MOVE_THUNDER_SHOCK; }
    PARAMETRIZE { species = SPECIES_PIKACHU_CLASSIC_CAP; item = ITEM_NONE;       move = MOVE_THUNDER_SHOCK; }
    PARAMETRIZE { species = SPECIES_PIKACHU_CLASSIC_CAP; item = ITEM_LIGHT_BALL; move = MOVE_THUNDER_SHOCK; }
    PARAMETRIZE { species = SPECIES_PIKACHU_SURFBOARD;   item = ITEM_NONE;       move = MOVE_SPARK; }
    PARAMETRIZE { species = SPECIES_PIKACHU_CLASSIC_CAP; item = ITEM_NONE;       move = MOVE_SPARK; }

    GIVEN {
        ASSUME(GetMoveCategory(MOVE_THUNDER_SHOCK) == DAMAGE_CATEGORY_SPECIAL);
        ASSUME(GetMoveCategory(MOVE_SPARK) == DAMAGE_CATEGORY_PHYSICAL);
        PLAYER(species) { Item(item); }
        OPPONENT(SPECIES_WOBBUFFET);
    } WHEN {
        TURN { MOVE(player, move); }
    } SCENE {
        HP_BAR(opponent, captureDamage: &results[i].damage);
    } FINALLY {
        EXPECT_MUL_EQ(results[0].damage, Q_4_12(2.0), results[1].damage);
        EXPECT_EQ(results[1].damage, results[2].damage);
        EXPECT_MUL_EQ(results[3].damage, Q_4_12(2.0), results[4].damage);
    }
}

SINGLE_BATTLE_TEST("Balloon Pikachu's Gale Wings gives Flying moves priority at full HP")
{
    GIVEN {
        PLAYER(SPECIES_PIKACHU_BALLOONS) { Speed(1); }
        OPPONENT(SPECIES_WOBBUFFET) { Speed(100); }
    } WHEN {
        TURN { MOVE(player, MOVE_WING_ATTACK); MOVE(opponent, MOVE_CELEBRATE); }
    } SCENE {
        ANIMATION(ANIM_TYPE_MOVE, MOVE_WING_ATTACK, player);
        ANIMATION(ANIM_TYPE_MOVE, MOVE_CELEBRATE, opponent);
    }
}
