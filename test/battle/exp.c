#include "global.h"
#include "test/battle.h"

WILD_BATTLE_TEST("Pokemon gain experience after catching a Pokemon (Gen6+)")
{
    u8 level = 0;
    u32 config = 0;

    PARAMETRIZE { level = MAX_LEVEL; config = GEN_5; }
    PARAMETRIZE { level = 50;        config = GEN_5; }
    PARAMETRIZE { level = 50;        config = GEN_6; }

    GIVEN {
        WITH_CONFIG(B_EXP_CATCH, config);
        PLAYER(SPECIES_WOBBUFFET) { Level(level); }
        OPPONENT(SPECIES_CATERPIE) { HP(1); }
    } WHEN {
        TURN { USE_ITEM(player, ITEM_ULTRA_BALL, WITH_RNG(RNG_BALLTHROW_SHAKE, 0)); }
    } SCENE {
        MESSAGE("You used Ultra Ball!");
        ANIMATION(ANIM_TYPE_SPECIAL, B_ANIM_BALL_THROW, player);
        if (level != MAX_LEVEL && config >= GEN_6) {
            EXPERIENCE_BAR(player);
        } else {
            NOT EXPERIENCE_BAR(player);
        }
    }
}

WILD_BATTLE_TEST("Higher leveled Pokemon give more exp", s32 exp)
{
    u8 level = 0;

    PARAMETRIZE { level = 5; }
    PARAMETRIZE { level = 10; }

    GIVEN {
        PLAYER(SPECIES_WOBBUFFET) { Level(20); }
        OPPONENT(SPECIES_CATERPIE) { Level(level); HP(1); }
    } WHEN {
        TURN { MOVE(player, MOVE_SCRATCH); }
    } SCENE {
        MESSAGE("Wobbuffet used Scratch!");
        MESSAGE("The wild Caterpie fainted!");
        EXPERIENCE_BAR(player, captureGainedExp: &results[i].exp);
    } FINALLY {
        EXPECT_GT(results[1].exp, results[0].exp);
    }
}

WILD_BATTLE_TEST("Lucky Egg boosts gained exp points by 50%", s32 exp)
{
    enum Item item = ITEM_NONE;

    PARAMETRIZE { item = ITEM_LUCKY_EGG; }
    PARAMETRIZE { item = ITEM_NONE; }

    GIVEN {
        PLAYER(SPECIES_WOBBUFFET) { Level(20); Item(item); }
        OPPONENT(SPECIES_CATERPIE) { Level(10); HP(1); }
    } WHEN {
        TURN { MOVE(player, MOVE_SCRATCH); }
    } SCENE {
        MESSAGE("Wobbuffet used Scratch!");
        MESSAGE("The wild Caterpie fainted!");
        EXPERIENCE_BAR(player, captureGainedExp: &results[i].exp);
    } FINALLY {
        EXPECT_MUL_EQ(results[1].exp, Q_4_12(1.5), results[0].exp);
    }
}

#if (B_SCALED_EXP == GEN_5 || B_SCALED_EXP >= GEN_7)

WILD_BATTLE_TEST("Exp is scaled to player and opponent's levels", s32 exp)
{
    u8 level = 0;

    PARAMETRIZE { level = 5; }
    PARAMETRIZE { level = 10; }

    GIVEN {
        PLAYER(SPECIES_WOBBUFFET) { Level(level); }
        OPPONENT(SPECIES_CATERPIE) { Level(5); HP(1); }
    } WHEN {
        TURN { MOVE(player, MOVE_SCRATCH); }
    } SCENE {
        MESSAGE("Wobbuffet used Scratch!");
        MESSAGE("The wild Caterpie fainted!");
        EXPERIENCE_BAR(player, captureGainedExp: &results[i].exp);
    } FINALLY {
        EXPECT_GT(results[0].exp, results[1].exp);
    }
}

#endif

WILD_BATTLE_TEST("Large exp gains are supported", s32 exp) // #1455
{
    u8 level = 0;

    PARAMETRIZE { level = 10; }
    PARAMETRIZE { level = 50; }
    PARAMETRIZE { level = MAX_LEVEL; }

    GIVEN {
        PLAYER(SPECIES_WOBBUFFET) { Level(1); Item(ITEM_LUCKY_EGG); OTName("Test"); } // OT Name is different so it gets more exp as a traded mon
        OPPONENT(SPECIES_BLISSEY) { Level(level); HP(1); }
    } WHEN {
        TURN { MOVE(player, MOVE_SCRATCH); }
    } SCENE {
        MESSAGE("Wobbuffet used Scratch!");
        MESSAGE("The wild Blissey fainted!");
        EXPERIENCE_BAR(player, captureGainedExp: &results[i].exp);
    } THEN {
        EXPECT(GetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_LEVEL) > 1);
        EXPECT(GetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_EXP) > 1);
    } FINALLY {
        EXPECT_GT(results[1].exp, results[0].exp);
        EXPECT_GT(results[2].exp, results[1].exp);
    }
}

#if I_EXP_SHARE_ITEM < GEN_6

WILD_BATTLE_TEST("Exp Share(held) gives Experience to mons which did not participate in battle")
{
    enum Item item = ITEM_NONE;

    PARAMETRIZE { item = ITEM_NONE; }
    PARAMETRIZE { item = ITEM_EXP_SHARE; }

    GIVEN {
        PLAYER(SPECIES_WOBBUFFET);
        PLAYER(SPECIES_WYNAUT) { Level(40); Item(item); }
        OPPONENT(SPECIES_CATERPIE) { Level(10); HP(1); }
    } WHEN {
        TURN { MOVE(player, MOVE_SCRATCH); }
    } SCENE {
        MESSAGE("Wobbuffet used Scratch!");
        MESSAGE("The wild Caterpie fainted!");
        // This message should appear only for gen6> exp share.
        NOT MESSAGE("The rest of your team gained EXP. Points thanks to the Exp. Share!");
    } THEN {
        if (item == ITEM_EXP_SHARE)
            EXPECT_GT(GetMonData(&gParties[B_TRAINER_PLAYER][1], MON_DATA_EXP), gExperienceTables[gSpeciesInfo[SPECIES_WYNAUT].growthRate][40]);
        else
            EXPECT_EQ(GetMonData(&gParties[B_TRAINER_PLAYER][1], MON_DATA_EXP), gExperienceTables[gSpeciesInfo[SPECIES_WYNAUT].growthRate][40]);
    }
}

// B_EXP_SHARE_DIVISOR is the knob behind "the first Pokemon always gets the most EXP". Gen6+ hands
// a non-participant calculatedExp / 2, so the mon that fought visibly out-earned the rest of the
// party no matter what the player did; at 1 the share is even.
//
// WHAT MAKES THIS DISCRIMINATE: it reads MON_DATA_EXP off BOTH party slots and compares them.
// EXPERIENCE_BAR() cannot see this — TestRunner_Battle_RecordExp is only reached from the ACTIVE
// battler's bar (src/battle_controller_player.c), so party members 2-6 are invisible to it. The
// comparison is against the mon that fought rather than a hardcoded number, so it stays honest if
// the base EXP formula or the scaling factors are ever retuned.
//
// BOTH MONS ARE THE SAME SPECIES AND LEVEL ON PURPOSE. ApplyExperienceMultipliers weights per mon:
// B_SCALED_EXP divides by the recipient's own level, and B_UNEVOLVED_EXP_MULTIPLIER gives a ~1.2x
// bonus to a mon sitting past its evolution level. A Wynaut in slot 2 would collect that bonus and
// a Wobbuffet in slot 1 would not, so an equal split would still read as unequal EXP.
WILD_BATTLE_TEST("Exp Share splits EXP evenly with the Pokemon that fought")
{
    GIVEN {
        PLAYER(SPECIES_WOBBUFFET) { Level(25); }
        PLAYER(SPECIES_WOBBUFFET) { Level(25); Item(ITEM_EXP_SHARE); }
        OPPONENT(SPECIES_CATERPIE) { Level(10); HP(1); }
    } WHEN {
        TURN { MOVE(player, MOVE_SCRATCH); }
    } THEN {
        u32 startExp = gExperienceTables[gSpeciesInfo[SPECIES_WOBBUFFET].growthRate][25];
        u32 fought  = GetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_EXP) - startExp;
        u32 benched = GetMonData(&gParties[B_TRAINER_PLAYER][1], MON_DATA_EXP) - startExp;

        EXPECT_GT(fought, 0);
        EXPECT_GT(benched, 0);
        // A runtime branch on the compile-time constant, deliberately: an #if here would silently
        // compile the assertion away if the divisor were ever changed back, which reads as a green
        // build with no coverage.
        if (B_EXP_SHARE_DIVISOR == 1)
            EXPECT_EQ(benched, fought);
        else
            EXPECT_LT(benched, fought);
    }
}

#endif // I_EXP_SHARE_ITEM

static bool32 TestMonKnowsMove(struct Pokemon *mon, enum Move move)
{
    u32 i;

    for (i = 0; i < MAX_MON_MOVES; i++)
    {
        if (GetMonData(mon, MON_DATA_MOVE1 + i) == move)
            return TRUE;
    }
    return FALSE;
}

// #116: GEN9+ applies a multi-level EXP dump in one shot, then
// Cmd_handlelearnnewmove walks beforeLvlUp->level up to the new level.
WILD_BATTLE_TEST("Leveling multiple levels at once teaches a move only on the final level")
{
    u32 startLevel = 0;
    u32 foeLevel = 0;

    PARAMETRIZE { startLevel = 13; foeLevel = 13; } // 13→15
    PARAMETRIZE { startLevel = 12; foeLevel = 15; } // 12→15

    GIVEN {
        ASSUME(B_LEVEL_UP_NOTIFICATION >= GEN_9);
        const struct LevelUpMove *learnset = GetSpeciesLevelUpLearnset(SPECIES_MAGIKARP);
        ASSUME(learnset[1].level == 15 && learnset[1].move == MOVE_TACKLE);
        ASSUME(learnset[2].level == 25 && learnset[2].move == MOVE_FLAIL);
        PLAYER(SPECIES_MAGIKARP) { Level(startLevel); }
        OPPONENT(SPECIES_BLISSEY) { Level(foeLevel); HP(1); }
    } WHEN {
        TURN { MOVE(player, MOVE_SCRATCH); }
    } SCENE {
        MESSAGE("The wild Blissey fainted!");
        EXPERIENCE_BAR(player);
    } THEN {
        EXPECT_EQ(GetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_LEVEL), 15);
        EXPECT_EQ(gLevelUpStartLevels[0], startLevel);
        EXPECT(TestMonKnowsMove(&gParties[B_TRAINER_PLAYER][0], MOVE_TACKLE));
        EXPECT(!TestMonKnowsMove(&gParties[B_TRAINER_PLAYER][0], MOVE_FLAIL));
    }
}

WILD_BATTLE_TEST("Leveling multiple levels at once teaches both moves learned at the same level")
{
    u32 startLevel = 0;
    u32 foeLevel = 0;
    u32 expectedLevel = 0;
    enum Item item = ITEM_NONE;

    PARAMETRIZE { startLevel = 13; foeLevel = 9;  expectedLevel = 15; item = ITEM_NONE; }      // 2-level, dual at landing
    PARAMETRIZE { startLevel = 12; foeLevel = 10; expectedLevel = 15; item = ITEM_NONE; }      // 3-level, dual at landing
    PARAMETRIZE { startLevel = 14; foeLevel = 10; expectedLevel = 16; item = ITEM_EVERSTONE; } // 2-level, dual in the middle

    GIVEN {
        ASSUME(B_LEVEL_UP_NOTIFICATION >= GEN_9);
        const struct LevelUpMove *learnset = GetSpeciesLevelUpLearnset(SPECIES_BULBASAUR);
        ASSUME(learnset[5].level == 12 && learnset[5].move == MOVE_RAZOR_LEAF);
        ASSUME(learnset[6].level == 15 && learnset[6].move == MOVE_POISON_POWDER);
        ASSUME(learnset[7].level == 15 && learnset[7].move == MOVE_SLEEP_POWDER);
        ASSUME(learnset[8].level == 18 && learnset[8].move == MOVE_SEED_BOMB);
        PLAYER(SPECIES_BULBASAUR) { Level(startLevel); Item(item); }
        OPPONENT(SPECIES_BLISSEY) { Level(foeLevel); HP(1); }
    } WHEN {
        TURN { MOVE(player, MOVE_TACKLE); }
    } SCENE {
        MESSAGE("The wild Blissey fainted!");
        EXPERIENCE_BAR(player);
    } THEN {
        EXPECT_EQ(GetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_LEVEL), expectedLevel);
        EXPECT_EQ(gLevelUpStartLevels[0], startLevel);
        EXPECT_EQ(GetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_MOVE2), MOVE_POISON_POWDER);
        EXPECT_EQ(GetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_MOVE3), MOVE_SLEEP_POWDER);
        EXPECT(!TestMonKnowsMove(&gParties[B_TRAINER_PLAYER][0], MOVE_RAZOR_LEAF));
        EXPECT(!TestMonKnowsMove(&gParties[B_TRAINER_PLAYER][0], MOVE_SEED_BOMB));
    }
}
