#include "global.h"
#include "test/battle.h"
#include "battle_setup.h"
#include "event_data.h"
#include "money.h"
#include "constants/battle_setup.h"
#include "constants/trainers.h"

static void PrepareMoneyBattle(u32 rate)
{
    gSaveBlock2Ptr->optionsMoneyLoss = rate;
    SetMoney(&gSaveBlock1Ptr->money, 10000);
    for (u32 i = 0; i < NUM_BADGES; i++)
        FlagClear(gBadgeFlags[i]);
    FlagClear(B_FLAG_NO_WHITEOUT);
    TRAINER_BATTLE_PARAM.mode = TRAINER_BATTLE_SINGLE;
    TRAINER_BATTLE_PARAM.rivalBattleFlags = 0;
}

WILD_BATTLE_TEST("Family money: wild defeat reaches the scaled loss branch")
{
    u32 rate = 0, remaining = 0;
    PARAMETRIZE { rate = OPTIONS_RATE_0_5X; remaining = 9800; }
    PARAMETRIZE { rate = OPTIONS_RATE_1X; remaining = 9600; }
    PARAMETRIZE { rate = OPTIONS_RATE_1_5X; remaining = 9400; }
    PARAMETRIZE { rate = OPTIONS_RATE_2X; remaining = 9200; }
    GIVEN {
        PrepareMoneyBattle(rate);
        PLAYER(SPECIES_WOBBUFFET) { Level(50); }
        OPPONENT(SPECIES_WOBBUFFET);
    } WHEN {
        TURN { MOVE(player, MOVE_MEMENTO); }
    } THEN {
        EXPECT_EQ(gBattleOutcome, B_OUTCOME_LOST);
        EXPECT_EQ(GetMoney(&gSaveBlock1Ptr->money), remaining);
        gSaveBlock2Ptr->optionsMoneyLoss = OPTIONS_RATE_1X;
    }
}

AI_SINGLE_BATTLE_TEST("Family money: trainer defeat reaches the scaled loss branch")
{
    u32 rate = 0, remaining = 0;
    PARAMETRIZE { rate = OPTIONS_RATE_0_5X; remaining = 9800; }
    PARAMETRIZE { rate = OPTIONS_RATE_1X; remaining = 9600; }
    PARAMETRIZE { rate = OPTIONS_RATE_1_5X; remaining = 9400; }
    PARAMETRIZE { rate = OPTIONS_RATE_2X; remaining = 9200; }
    GIVEN {
        PrepareMoneyBattle(rate);
        PLAYER(SPECIES_WOBBUFFET) { Level(50); }
        OPPONENT(SPECIES_WOBBUFFET) { Moves(MOVE_SPLASH); }
    } WHEN {
        TURN { MOVE(player, MOVE_MEMENTO); }
    } THEN {
        EXPECT_EQ(gBattleOutcome, B_OUTCOME_LOST);
        EXPECT_EQ(GetMoney(&gSaveBlock1Ptr->money), remaining);
        gSaveBlock2Ptr->optionsMoneyLoss = OPTIONS_RATE_1X;
    }
}

WILD_BATTLE_TEST("Family money: loss preference does not change Pay Day winnings")
{
    u32 rate = 0;
    for (u32 i = 0; i < OPTIONS_RATE_COUNT; i++)
        PARAMETRIZE { rate = i; }
    GIVEN {
        PrepareMoneyBattle(rate);
        PLAYER(SPECIES_MEOWTH) { Level(50); }
        OPPONENT(SPECIES_WOBBUFFET) { HP(1); }
    } WHEN {
        TURN { MOVE(player, MOVE_PAY_DAY); }
    } THEN {
        EXPECT_EQ(gBattleOutcome, B_OUTCOME_WON);
        EXPECT_EQ(GetMoney(&gSaveBlock1Ptr->money), 10250);
        gSaveBlock2Ptr->optionsMoneyLoss = OPTIONS_RATE_1X;
    }
}

AI_SINGLE_BATTLE_TEST("Family money: trainer prize and Pay Day remain unchanged")
{
    u32 rate = 0;
    for (u32 i = 0; i < OPTIONS_RATE_COUNT; i++)
        PARAMETRIZE { rate = i; }
    GIVEN {
        PrepareMoneyBattle(rate);
        PLAYER(SPECIES_MEOWTH) { Level(50); }
        OPPONENT(SPECIES_WOBBUFFET) { HP(1); Moves(MOVE_SPLASH); }
    } WHEN {
        TURN { MOVE(player, MOVE_PAY_DAY); }
    } THEN {
        EXPECT_EQ(gBattleOutcome, B_OUTCOME_WON);
        EXPECT_EQ(GetMoney(&gSaveBlock1Ptr->money), 10550);
        gSaveBlock2Ptr->optionsMoneyLoss = OPTIONS_RATE_1X;
    }
}

AI_SINGLE_BATTLE_TEST("Family money: ordinary simulation defeats remain free")
{
    u32 rate = 0;
    for (u32 i = 0; i < OPTIONS_RATE_COUNT; i++)
        PARAMETRIZE { rate = i; }
    GIVEN {
        PrepareMoneyBattle(rate);
        FLAG_SET(B_FLAG_NO_WHITEOUT);
        PLAYER(SPECIES_WOBBUFFET) { Level(50); }
        OPPONENT(SPECIES_WOBBUFFET) { Moves(MOVE_SPLASH); }
    } WHEN {
        TURN { MOVE(player, MOVE_MEMENTO); }
    } THEN {
        EXPECT_EQ(gBattleOutcome, B_OUTCOME_LOST);
        EXPECT_EQ(GetMoney(&gSaveBlock1Ptr->money), 10000);
        gSaveBlock2Ptr->optionsMoneyLoss = OPTIONS_RATE_1X;
    }
}

AI_SINGLE_BATTLE_TEST("Family money: early rival healing losses remain free")
{
    GIVEN {
        PrepareMoneyBattle(OPTIONS_RATE_2X);
        TRAINER_BATTLE_PARAM.mode = TRAINER_BATTLE_EARLY_RIVAL;
        TRAINER_BATTLE_PARAM.rivalBattleFlags = RIVAL_BATTLE_HEAL_AFTER;
        PLAYER(SPECIES_WOBBUFFET) { Level(50); }
        OPPONENT(SPECIES_WOBBUFFET) { Moves(MOVE_SPLASH); }
    } WHEN {
        TURN { MOVE(player, MOVE_MEMENTO); }
    } THEN {
        EXPECT_EQ(gBattleOutcome, B_OUTCOME_LOST);
        EXPECT_EQ(GetMoney(&gSaveBlock1Ptr->money), 10000);
        gSaveBlock2Ptr->optionsMoneyLoss = OPTIONS_RATE_1X;
        TRAINER_BATTLE_PARAM.mode = TRAINER_BATTLE_SINGLE;
        TRAINER_BATTLE_PARAM.rivalBattleFlags = 0;
    }
}
