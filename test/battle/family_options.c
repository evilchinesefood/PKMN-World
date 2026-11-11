#include "global.h"
#include "test/battle.h"

WILD_BATTLE_TEST("Family retired Hard Mode permits battle growth past the first badge ceiling")
{
    u32 hard = 0;
    PARAMETRIZE { hard = FALSE; }
    PARAMETRIZE { hard = TRUE; }
    GIVEN {
        gSaveBlock2Ptr->optionsHardMode = hard;
        gSaveBlock2Ptr->optionsExpMultiplier = OPTIONS_EXP_MULT_1X;
        PLAYER(SPECIES_BULBASAUR) { Level(14); Item(ITEM_EVERSTONE); }
        OPPONENT(SPECIES_BLISSEY) { Level(10); HP(1); }
    } WHEN {
        TURN { MOVE(player, MOVE_TACKLE); }
    } SCENE {
        MESSAGE("The wild Blissey fainted!");
        EXPERIENCE_BAR(player);
    } THEN {
        EXPECT_EQ(GetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_LEVEL), 16);
    }
}

WILD_BATTLE_TEST("Family retired Hard Mode gives no battle EXP beyond maximum level")
{
    GIVEN {
        gSaveBlock2Ptr->optionsHardMode = TRUE;
        PLAYER(SPECIES_PIKACHU) { Level(MAX_LEVEL); }
        OPPONENT(SPECIES_CATERPIE) { HP(1); }
    } WHEN {
        TURN { MOVE(player, MOVE_TACKLE); }
    } SCENE {
        NOT EXPERIENCE_BAR(player);
    } THEN {
        EXPECT_EQ(GetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_LEVEL), MAX_LEVEL);
    }
}
