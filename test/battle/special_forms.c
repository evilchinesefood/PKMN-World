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

// Stress pass 5: the built-in Light Ball must hold when the held-item path is switched off, and the
// themed types and abilities must behave as the vanilla mechanics do on any other species.
SINGLE_BATTLE_TEST("Classic Cap Pikachu keeps its built-in Light Ball under Embargo, Magic Room and Knock Off", s16 damage)
{
    u32 species = 0, item = 0;
    enum Move foeMove = MOVE_CELEBRATE;

    PARAMETRIZE { species = SPECIES_PIKACHU_SURFBOARD;   item = ITEM_NONE;       foeMove = MOVE_CELEBRATE; }
    PARAMETRIZE { species = SPECIES_PIKACHU_CLASSIC_CAP; item = ITEM_NONE;       foeMove = MOVE_CELEBRATE; }
    PARAMETRIZE { species = SPECIES_PIKACHU_CLASSIC_CAP; item = ITEM_LIGHT_BALL; foeMove = MOVE_EMBARGO; }
    PARAMETRIZE { species = SPECIES_PIKACHU_CLASSIC_CAP; item = ITEM_LIGHT_BALL; foeMove = MOVE_MAGIC_ROOM; }
    PARAMETRIZE { species = SPECIES_PIKACHU_CLASSIC_CAP; item = ITEM_LIGHT_BALL; foeMove = MOVE_KNOCK_OFF; }
    PARAMETRIZE { species = SPECIES_PIKACHU_CLASSIC_CAP; item = ITEM_NONE;       foeMove = MOVE_EMBARGO; }

    GIVEN {
        ASSUME(GetMoveEffect(MOVE_EMBARGO) == EFFECT_EMBARGO);
        ASSUME(GetMoveEffect(MOVE_MAGIC_ROOM) == EFFECT_MAGIC_ROOM);
        ASSUME(GetMoveEffect(MOVE_KNOCK_OFF) == EFFECT_KNOCK_OFF);
        PLAYER(species) { Item(item); Speed(1); }
        OPPONENT(SPECIES_WOBBUFFET) { Speed(100); }
    } WHEN {
        TURN { MOVE(opponent, foeMove); MOVE(player, MOVE_CELEBRATE); }
        TURN { MOVE(player, MOVE_THUNDER_SHOCK); }
    } SCENE {
        ANIMATION(ANIM_TYPE_MOVE, MOVE_THUNDER_SHOCK, player);
        HP_BAR(opponent, captureDamage: &results[i].damage);
    } FINALLY {
        EXPECT_MUL_EQ(results[0].damage, Q_4_12(2.0), results[1].damage);
        EXPECT_EQ(results[1].damage, results[2].damage);
        EXPECT_EQ(results[1].damage, results[3].damage);
        EXPECT_EQ(results[1].damage, results[4].damage);
        EXPECT_EQ(results[1].damage, results[5].damage);
    }
}

SINGLE_BATTLE_TEST("Classic Cap Pikachu's built-in Light Ball does not pass to the target of Trick", s16 damage)
{
    u32 species = 0;

    PARAMETRIZE { species = SPECIES_PIKACHU_SURFBOARD; }
    PARAMETRIZE { species = SPECIES_PIKACHU_CLASSIC_CAP; }

    GIVEN {
        ASSUME(GetMoveEffect(MOVE_TRICK) == EFFECT_TRICK);
        PLAYER(species) { Item(ITEM_LIGHT_BALL); Speed(100); }
        OPPONENT(SPECIES_PIKACHU) { Item(ITEM_ORAN_BERRY); Speed(1); }
    } WHEN {
        TURN { MOVE(player, MOVE_TRICK); MOVE(opponent, MOVE_CELEBRATE); }
        TURN { MOVE(player, MOVE_THUNDER_SHOCK); }
    } SCENE {
        ANIMATION(ANIM_TYPE_MOVE, MOVE_TRICK, player);
        ANIMATION(ANIM_TYPE_MOVE, MOVE_THUNDER_SHOCK, player);
        HP_BAR(opponent, captureDamage: &results[i].damage);
    } THEN {
        EXPECT_EQ(player->item, ITEM_ORAN_BERRY);
        EXPECT_EQ(opponent->item, ITEM_LIGHT_BALL);
    } FINALLY {
        EXPECT_MUL_EQ(results[0].damage, Q_4_12(2.0), results[1].damage);
    }
}

SINGLE_BATTLE_TEST("Balloon Pikachu's Gale Wings gives no priority below full HP")
{
    GIVEN {
        PLAYER(SPECIES_PIKACHU_BALLOONS) { Speed(1); HP(1); }
        OPPONENT(SPECIES_WOBBUFFET) { Speed(100); }
    } WHEN {
        TURN { MOVE(player, MOVE_WING_ATTACK); MOVE(opponent, MOVE_CELEBRATE); }
    } SCENE {
        ANIMATION(ANIM_TYPE_MOVE, MOVE_CELEBRATE, opponent);
        ANIMATION(ANIM_TYPE_MOVE, MOVE_WING_ATTACK, player);
    }
}

SINGLE_BATTLE_TEST("Surfboard Pikachu's Swift Swim doubles its Speed in rain")
{
    GIVEN {
        PLAYER(SPECIES_PIKACHU_SURFBOARD) { Speed(60); }
        OPPONENT(SPECIES_WOBBUFFET) { Speed(100); }
    } WHEN {
        TURN { MOVE(opponent, MOVE_RAIN_DANCE); MOVE(player, MOVE_CELEBRATE); }
        TURN { MOVE(player, MOVE_THUNDER_SHOCK); MOVE(opponent, MOVE_CELEBRATE); }
    } SCENE {
        ANIMATION(ANIM_TYPE_MOVE, MOVE_RAIN_DANCE, opponent);
        ANIMATION(ANIM_TYPE_MOVE, MOVE_CELEBRATE, player);
        ANIMATION(ANIM_TYPE_MOVE, MOVE_THUNDER_SHOCK, player);
        ANIMATION(ANIM_TYPE_MOVE, MOVE_CELEBRATE, opponent);
    }
}

SINGLE_BATTLE_TEST("Firefighter Squirtle's Flash Fire absorbs Fire moves")
{
    GIVEN {
        PLAYER(SPECIES_SQUIRTLE_FIREFIGHTER);
        OPPONENT(SPECIES_WOBBUFFET);
    } WHEN {
        TURN { MOVE(opponent, MOVE_EMBER); }
    } SCENE {
        ABILITY_POPUP(player, ABILITY_FLASH_FIRE);
        NONE_OF { HP_BAR(player); }
    }
}

SINGLE_BATTLE_TEST("Pirate Totodile's Cursed Body can disable the move that hit it")
{
    PASSES_RANDOMLY(3, 10, RNG_CURSED_BODY);
    GIVEN {
        PLAYER(SPECIES_WOBBUFFET);
        OPPONENT(SPECIES_TOTODILE_PIRATE);
    } WHEN {
        TURN { MOVE(player, MOVE_AQUA_JET); }
    } SCENE {
        ANIMATION(ANIM_TYPE_MOVE, MOVE_AQUA_JET, player);
        ABILITY_POPUP(opponent, ABILITY_CURSED_BODY);
        MESSAGE("Wobbuffet's Aqua Jet was disabled!");
    }
}

SINGLE_BATTLE_TEST("Squad Squirtle's Intimidate lowers Attack and is blocked by Clear Body")
{
    u32 species = 0, ability = 0;

    PARAMETRIZE { species = SPECIES_WOBBUFFET; ability = ABILITY_SHADOW_TAG; }
    PARAMETRIZE { species = SPECIES_TENTACOOL; ability = ABILITY_CLEAR_BODY; }

    GIVEN {
        PLAYER(SPECIES_SQUIRTLE_SQUAD);
        OPPONENT(species) { Ability(ability); }
    } WHEN {
        TURN { }
    } SCENE {
        ABILITY_POPUP(player, ABILITY_INTIMIDATE);
    } THEN {
        if (ability == ABILITY_CLEAR_BODY)
            EXPECT_EQ(opponent->statStages[STAT_ATK], DEFAULT_STAT_STAGE);
        else
            EXPECT_EQ(opponent->statStages[STAT_ATK], DEFAULT_STAT_STAGE - 1);
    }
}

SINGLE_BATTLE_TEST("Special forms take their second type's immunities")
{
    u32 species = 0;
    enum Move move = MOVE_NONE;

    PARAMETRIZE { species = SPECIES_TOTODILE_PIRATE;    move = MOVE_TACKLE; }
    PARAMETRIZE { species = SPECIES_PIKACHU_BALLOONS;   move = MOVE_EARTHQUAKE; }
    PARAMETRIZE { species = SPECIES_EEVEE_FLOWER_CROWN; move = MOVE_DRAGON_CLAW; }
    PARAMETRIZE { species = SPECIES_SQUIRTLE_SQUAD;     move = MOVE_PSYCHIC; }

    GIVEN {
        PLAYER(species);
        OPPONENT(SPECIES_WOBBUFFET);
    } WHEN {
        TURN { MOVE(opponent, move); }
    } SCENE {
        NONE_OF { HP_BAR(player); }
    }
}

SINGLE_BATTLE_TEST("Skill Swap takes Balloon Pikachu's Gale Wings and gives it the user's ability")
{
    GIVEN {
        ASSUME(GetMoveEffect(MOVE_SKILL_SWAP) == EFFECT_SKILL_SWAP);
        PLAYER(SPECIES_PIKACHU_BALLOONS) { Speed(1); }
        OPPONENT(SPECIES_WOBBUFFET) { Ability(ABILITY_SHADOW_TAG); Speed(100); }
    } WHEN {
        TURN { MOVE(opponent, MOVE_SKILL_SWAP); MOVE(player, MOVE_CELEBRATE); }
    } SCENE {
        ANIMATION(ANIM_TYPE_MOVE, MOVE_SKILL_SWAP, opponent);
    } THEN {
        EXPECT_EQ(player->ability, ABILITY_SHADOW_TAG);
        EXPECT_EQ(opponent->ability, ABILITY_GALE_WINGS);
    }
}

// Transform copies the species, so a Ditto that becomes Classic Cap Pikachu wears the cap, the same
// way a held Light Ball boosts a Ditto transformed into Pikachu (both key on the current species).
SINGLE_BATTLE_TEST("A Ditto transformed into Classic Cap Pikachu gets the built-in Light Ball", s16 damage)
{
    u32 species = 0;

    PARAMETRIZE { species = SPECIES_PIKACHU_SURFBOARD; }
    PARAMETRIZE { species = SPECIES_PIKACHU_CLASSIC_CAP; }

    GIVEN {
        ASSUME(GetMoveEffect(MOVE_TRANSFORM) == EFFECT_TRANSFORM);
        ASSUME(GetMoveCategory(MOVE_TACKLE) == DAMAGE_CATEGORY_PHYSICAL);
        PLAYER(SPECIES_DITTO) { Speed(100); Moves(MOVE_TRANSFORM, MOVE_TACKLE); }
        OPPONENT(species) { Speed(1); Moves(MOVE_CELEBRATE, MOVE_TACKLE); }
    } WHEN {
        TURN { MOVE(player, MOVE_TRANSFORM); MOVE(opponent, MOVE_CELEBRATE); }
        TURN { MOVE(player, MOVE_TACKLE); MOVE(opponent, MOVE_CELEBRATE); }
    } SCENE {
        ANIMATION(ANIM_TYPE_MOVE, MOVE_TRANSFORM, player);
        ANIMATION(ANIM_TYPE_MOVE, MOVE_TACKLE, player);
        HP_BAR(opponent, captureDamage: &results[i].damage);
    } FINALLY {
        EXPECT_MUL_EQ(results[0].damage, Q_4_12(2.0), results[1].damage);
    }
}
