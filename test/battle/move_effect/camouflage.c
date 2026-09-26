#include "global.h"
#include "test/battle.h"
#include "battle_environment.h"

SINGLE_BATTLE_TEST("Camouflage uses the gameplay environment for cave, mountain and plain battles")
{
    u32 environment;
    PARAMETRIZE { environment = BATTLE_ENVIRONMENT_CAVE; }
    PARAMETRIZE { environment = BATTLE_ENVIRONMENT_MOUNTAIN; }
    PARAMETRIZE { environment = BATTLE_ENVIRONMENT_PLAIN; }
    GIVEN {
        Environment(environment);
        PLAYER(SPECIES_WOBBUFFET);
        OPPONENT(SPECIES_WOBBUFFET);
    } WHEN {
        TURN { MOVE(player, MOVE_CAMOUFLAGE); }
    } SCENE {
        ANIMATION(ANIM_TYPE_MOVE, MOVE_CAMOUFLAGE, player);
    } THEN {
        EXPECT_EQ(player->types[0], gBattleEnvironmentInfo[environment].camouflageType);
        EXPECT_EQ(player->types[1], gBattleEnvironmentInfo[environment].camouflageType);
        EXPECT_EQ(gBattleEnvironment, environment);
    }
}
TO_DO_BATTLE_TEST("Camouflage changes the type of the user to Grass if Grassy Terrain is active");
TO_DO_BATTLE_TEST("Camouflage changes the type of the user to Electric if Electric Terrain is active");
TO_DO_BATTLE_TEST("Camouflage changes the type of the user to Psychic if Psychic Terrain is active");
TO_DO_BATTLE_TEST("Camouflage changes the type of the user to Fairy if Misty Terrain is active");
