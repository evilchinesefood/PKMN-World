#include "global.h"
#include "test/battle.h"

TO_DO_BATTLE_TEST("TODO: Write Recover/Slack Off/Heal Order (Move Effect) test titles")

SINGLE_BATTLE_TEST("Recovery moves restore half of an odd max HP, rounded up from Gen 5")
{
    enum Move move;
    PARAMETRIZE { move = MOVE_RECOVER; }
    PARAMETRIZE { move = MOVE_SLACK_OFF; }
    PARAMETRIZE { move = MOVE_HEAL_ORDER; }
    PARAMETRIZE { move = MOVE_SOFT_BOILED; }
    PARAMETRIZE { move = MOVE_MILK_DRINK; }
    PARAMETRIZE { move = MOVE_ROOST; }
    GIVEN {
        PLAYER(SPECIES_WOBBUFFET) { HP(1); MaxHP(99); Moves(move); }
        OPPONENT(SPECIES_WOBBUFFET) { Moves(MOVE_CELEBRATE); }
    } WHEN {
        TURN { MOVE(player, move); MOVE(opponent, MOVE_CELEBRATE); }
    } THEN {
        EXPECT_EQ(player->hp, B_UPDATED_MOVE_DATA >= GEN_5 ? 51 : 50);
    }
}

SINGLE_BATTLE_TEST("Recover's rounded-up heal stops at max HP")
{
    GIVEN {
        PLAYER(SPECIES_WOBBUFFET) { HP(98); MaxHP(99); Moves(MOVE_RECOVER); }
        OPPONENT(SPECIES_WOBBUFFET) { Moves(MOVE_CELEBRATE); }
    } WHEN {
        TURN { MOVE(player, MOVE_RECOVER); MOVE(opponent, MOVE_CELEBRATE); }
    } THEN {
        EXPECT_EQ(player->hp, 99);
    }
}

SINGLE_BATTLE_TEST("Purify restores half of the user's odd max HP, rounded up from Gen 5")
{
    GIVEN {
        PLAYER(SPECIES_WOBBUFFET) { HP(1); MaxHP(99); Moves(MOVE_PURIFY); }
        OPPONENT(SPECIES_WOBBUFFET) { Status1(STATUS1_PARALYSIS); Moves(MOVE_CELEBRATE); }
    } WHEN {
        TURN { MOVE(player, MOVE_PURIFY); MOVE(opponent, MOVE_CELEBRATE); }
    } THEN {
        EXPECT_EQ(player->hp, B_UPDATED_MOVE_DATA >= GEN_5 ? 51 : 50);
        EXPECT_EQ(opponent->status1, 0);
    }
}
