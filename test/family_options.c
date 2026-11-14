#include "global.h"
#include "battle.h"
#include "battle_message.h"
#include "battle_script_commands.h"
#include "battle_setup.h"
#include "battle_util.h"
#include "caps.h"
#include "daycare.h"
#include "event_data.h"
#include "field_player_avatar.h"
#include "load_save.h"
#include "main.h"
#include "money.h"
#include "new_game.h"
#include "option_rates.h"
#include "overworld.h"
#include "wild_encounter.h"
#include "constants/maps.h"
#include "constants/metatile_behaviors.h"
#include "pokemon.h"
#include "pokemon_storage_system.h"
#include "random.h"
#include "regions.h"
#include "script_pokemon_util.h"
#include "task.h"
#include "test/test.h"
#include "constants/abilities.h"
#include "constants/flags.h"
#include "constants/item.h"
#include "constants/items.h"
#include "constants/vars.h"
#include "constants/weather.h"

extern void RockSmashWildEncounter(void);
extern u32 Test_GetLastEncounterRate(void);
extern bool8 Test_WildEncounterCheck(u32 rate, bool8 ignoreAbility, bool8 ordinary);

static void ResetFamilySave(void)
{
    SetVBlankCallback(NULL);
    memset(gSaveBlock1Ptr, 0, sizeof(*gSaveBlock1Ptr));
    memset(gSaveBlock2Ptr, 0, sizeof(*gSaveBlock2Ptr));
    memset(gSaveBlock3Ptr, 0, sizeof(*gSaveBlock3Ptr));
    memset(gPokemonStoragePtr, 0, sizeof(*gPokemonStoragePtr));
    ZeroPlayerPartyMons();
    SetCurrentRegion(REGION_HOENN);
    gMain.inBattle = FALSE;
    gBattleTypeFlags = 0;
    gIsFishingEncounter = FALSE;
}

static u16 ReadOptionWord(u32 offset)
{
    u16 value;
    memcpy(&value, (u8 *)gSaveBlock2Ptr + offset, sizeof(value));
    return value;
}

TEST("Family options occupy only the reserved four bits")
{
    ResetFamilySave();
    gSaveBlock2Ptr->optionsEncounterRate = OPTIONS_RATE_2X;
    EXPECT_EQ(ReadOptionWord(0x16), 0x00C0);
    gSaveBlock2Ptr->optionsMoneyLoss = OPTIONS_RATE_2X;
    EXPECT_EQ(ReadOptionWord(0x16), 0x03C0);
    gSaveBlock2Ptr->optionsHardMode = TRUE;
    EXPECT_EQ(ReadOptionWord(0x16), 0x03D0);
    EXPECT_EQ(offsetof(struct SaveBlock2, pokedex), 0x18);
    EXPECT_EQ(sizeof(struct SaveBlock1), 14752);
    EXPECT_EQ(sizeof(struct SaveBlock2), 3884);
    EXPECT_EQ(sizeof(struct SaveBlock3), 1432);
}

TEST("Family options initialize new saves without changing text default")
{
    ResetFamilySave();
    memset(gSaveBlock2Ptr, 0xFF, sizeof(*gSaveBlock2Ptr));
    Sav2_ClearSetDefault();
    EXPECT_EQ((u32)gSaveBlock2Ptr->optionsEncounterRate, OPTIONS_RATE_1X);
    EXPECT_EQ((u32)gSaveBlock2Ptr->optionsMoneyLoss, OPTIONS_RATE_1X);
    EXPECT_EQ((u32)gSaveBlock2Ptr->optionsTextSpeed, OPTIONS_TEXT_SPEED_MID);
    EXPECT_EQ((u32)gSaveBlock2Ptr->optionsBattleStyle, OPTIONS_BATTLE_STYLE_SHIFT);
    EXPECT_EQ((u32)gSaveBlock2Ptr->optionsExpMultiplier, OPTIONS_EXP_MULT_1X);
    EXPECT_EQ((u32)gSaveBlock2Ptr->optionsCatchMultiplier, OPTIONS_CATCH_MULT_1X);
}

TEST("Family options migrate dirty padding without changing adjacent preferences")
{
    u32 version = 0, hard = 0, text = 0;
    for (u32 v = 7; v <= 11; v++)
        for (u32 h = 0; h < 2; h++)
            for (u32 t = 0; t < 3; t++)
                PARAMETRIZE { version = v; hard = h; text = t; }
    ResetFamilySave();
    gSaveBlock2Ptr->saveVersion = version;
    ((u8 *)gSaveBlock2Ptr)[0x16] = 0xFF;
    ((u8 *)gSaveBlock2Ptr)[0x17] = 0xFF;
    gSaveBlock2Ptr->optionsHardMode = hard;
    gSaveBlock2Ptr->optionsExpMultiplier = OPTIONS_EXP_MULT_1_5X;
    gSaveBlock2Ptr->optionsCatchMultiplier = OPTIONS_CATCH_MULT_1_5X;
    gSaveBlock2Ptr->optionsTextSpeed = text;
    gSaveBlock2Ptr->optionsBattleStyle = OPTIONS_BATTLE_STYLE_SHIFT;
    gSaveBlock2Ptr->optionsAutoRun = TRUE;
    gSaveBlock2Ptr->optionsRunShortcut = OPTIONS_RUN_SHORTCUT_INSTANT;
    gSaveBlock2Ptr->optionsWindowFrameType = 17;
    gSaveBlock1Ptr->coins = 456;
    SetMoney(&gSaveBlock1Ptr->money, 12345);
    CreateMon(&gSaveBlock1Ptr->playerParty[0], SPECIES_PIKACHU, 25, 12345, OTID_STRUCT_PRESET(54321));
    u16 beforeFirst = ReadOptionWord(0x14);
    u16 beforeSecond = ReadOptionWord(0x16);
    MigrateSaveFormatIfNeeded();
    EXPECT_EQ(gSaveBlock2Ptr->saveVersion, 12);
    EXPECT_EQ(ReadOptionWord(0x14), beforeFirst);
    EXPECT_EQ(ReadOptionWord(0x16), beforeSecond & ~0x03C0);
    EXPECT_EQ((u32)gSaveBlock2Ptr->optionsEncounterRate, OPTIONS_RATE_1X);
    EXPECT_EQ((u32)gSaveBlock2Ptr->optionsMoneyLoss, OPTIONS_RATE_1X);
    EXPECT_EQ(gSaveBlock1Ptr->coins, 456);
    EXPECT_EQ(GetMoney(&gSaveBlock1Ptr->money), 12345);
    EXPECT_EQ(GetMonData(&gSaveBlock1Ptr->playerParty[0], MON_DATA_SPECIES), SPECIES_PIKACHU);
    EXPECT_EQ(GetMonData(&gSaveBlock1Ptr->playerParty[0], MON_DATA_LEVEL), 25);
}

TEST("Family options migration preserves v11 travel history and is idempotent")
{
    ResetFamilySave();
    gSaveBlock2Ptr->saveVersion = 11;
    gSaveBlock3Ptr->region.regionalTravel.nextIdentity = 123;
    gSaveBlock3Ptr->region.regionalTravel.teams[1].count = 1;
    gSaveBlock3Ptr->region.regionalTravel.teams[1].members[0].identity = 99;
    MigrateSaveFormatIfNeeded();
    EXPECT_EQ(gSaveBlock3Ptr->region.regionalTravel.nextIdentity, 123);
    EXPECT_EQ(gSaveBlock3Ptr->region.regionalTravel.teams[1].count, 1);
    EXPECT_EQ(gSaveBlock3Ptr->region.regionalTravel.teams[1].members[0].identity, 99);
    gSaveBlock2Ptr->optionsEncounterRate = OPTIONS_RATE_1_5X;
    gSaveBlock2Ptr->optionsMoneyLoss = OPTIONS_RATE_0_5X;
    MigrateSaveFormatIfNeeded();
    EXPECT_EQ((u32)gSaveBlock2Ptr->optionsEncounterRate, OPTIONS_RATE_1_5X);
    EXPECT_EQ((u32)gSaveBlock2Ptr->optionsMoneyLoss, OPTIONS_RATE_0_5X);
}

TEST("Family rates multiply once and round down with a wide intermediate")
{
    u32 amount = 0, rate = 0, expected = 0;
    PARAMETRIZE { amount = 1000; rate = OPTIONS_RATE_0_5X; expected = 500; }
    PARAMETRIZE { amount = 1000; rate = OPTIONS_RATE_1X; expected = 1000; }
    PARAMETRIZE { amount = 1000; rate = OPTIONS_RATE_1_5X; expected = 1500; }
    PARAMETRIZE { amount = 1000; rate = OPTIONS_RATE_2X; expected = 2000; }
    PARAMETRIZE { amount = 1001; rate = OPTIONS_RATE_0_5X; expected = 500; }
    PARAMETRIZE { amount = 1001; rate = OPTIONS_RATE_1_5X; expected = 1501; }
    PARAMETRIZE { amount = 0; rate = OPTIONS_RATE_2X; expected = 0; }
    PARAMETRIZE { amount = 0x80000001; rate = OPTIONS_RATE_0_5X; expected = 0x40000000; }
    EXPECT_EQ(ApplyOptionRate(amount, rate), expected);
}

static void ResetEncounter(void)
{
    ResetFamilySave();
    memset(&gPlayerAvatar, 0, sizeof(gPlayerAvatar));
    memset(&gMapHeader, 0, sizeof(gMapHeader));
    CreateMon(&gParties[B_TRAINER_PLAYER][0], SPECIES_PIKACHU, 20, 12345, OTID_STRUCT_PRESET(54321));
}

static rng_value_t sEncounterRngAfter;

static bool8 CheckEncounterAtRoll(u32 base, u32 roll, bool8 ignoreAbility, bool8 ordinary)
{
    u16 ime = REG_IME;
    REG_IME = 0;
    gRngValue = (rng_value_t){.a = roll << 16};
    bool8 result = Test_WildEncounterCheck(base, ignoreAbility, ordinary);
    sEncounterRngAfter = gRngValue;
    REG_IME = ime;
    return result;
}

TEST("Family encounters use exact scaled thresholds and consume one RNG value")
{
    u32 rate = 0, threshold = 0;
    PARAMETRIZE { rate = OPTIONS_RATE_0_5X; threshold = 800; }
    PARAMETRIZE { rate = OPTIONS_RATE_1X; threshold = 1600; }
    PARAMETRIZE { rate = OPTIONS_RATE_1_5X; threshold = 2400; }
    PARAMETRIZE { rate = OPTIONS_RATE_2X; threshold = 2880; }
    ResetEncounter();
    gSaveBlock2Ptr->optionsEncounterRate = rate;
    EXPECT_EQ(CheckEncounterAtRoll(100, threshold - 1, FALSE, TRUE), TRUE);
    EXPECT_EQ(sEncounterRngAfter.ctr, 1);
    if (threshold < 2880)
        EXPECT_EQ(CheckEncounterAtRoll(100, threshold, FALSE, TRUE), FALSE);
    EXPECT_EQ(sEncounterRngAfter.ctr, 1);
}

TEST("Family encounter scaling precedes the probability cap")
{
    ResetEncounter();
    gSaveBlock2Ptr->optionsEncounterRate = OPTIONS_RATE_0_5X;
    EXPECT_EQ(CheckEncounterAtRoll(255, 2039, FALSE, TRUE), TRUE);
    EXPECT_EQ(CheckEncounterAtRoll(255, 2040, FALSE, TRUE), FALSE);
    gSaveBlock2Ptr->optionsEncounterRate = OPTIONS_RATE_2X;
    EXPECT_EQ(CheckEncounterAtRoll(255, 2879, FALSE, TRUE), TRUE);
}

TEST("Family encounters leave fixed scope unchanged at every saved rate")
{
    u32 rate = 0;
    for (u32 i = 0; i < OPTIONS_RATE_COUNT; i++)
        PARAMETRIZE { rate = i; }
    ResetEncounter();
    gSaveBlock2Ptr->optionsEncounterRate = rate;
    EXPECT_EQ(CheckEncounterAtRoll(100, 1599, FALSE, FALSE), TRUE);
    EXPECT_EQ(CheckEncounterAtRoll(100, 1600, FALSE, FALSE), FALSE);
    EXPECT_EQ(CheckEncounterAtRoll(100, 1599, TRUE, FALSE), TRUE);
    EXPECT_EQ(CheckEncounterAtRoll(100, 1600, TRUE, FALSE), FALSE);
}

TEST("Family 1x encounters preserve the baseline result and RNG state")
{
    ResetEncounter();
    gSaveBlock2Ptr->optionsEncounterRate = OPTIONS_RATE_1X;
    for (u32 roll = 0; roll < 2880; roll++)
    {
        bool8 baseline = CheckEncounterAtRoll(100, roll, FALSE, FALSE);
        rng_value_t afterBaseline = sEncounterRngAfter;
        EXPECT_EQ(CheckEncounterAtRoll(100, roll, FALSE, TRUE), baseline);
        EXPECT_EQ(memcmp(&sEncounterRngAfter, &afterBaseline, sizeof(sEncounterRngAfter)), 0);
    }
}

TEST("Family encounters retain bike flute lure item and ability modifiers")
{
    u32 modifier = 0, threshold = 0;
    PARAMETRIZE { modifier = 0; threshold = 192; }
    PARAMETRIZE { modifier = 1; threshold = 360; }
    PARAMETRIZE { modifier = 2; threshold = 120; }
    PARAMETRIZE { modifier = 3; threshold = 480; }
    PARAMETRIZE { modifier = 4; threshold = 159; }
    PARAMETRIZE { modifier = 5; threshold = 120; }
    PARAMETRIZE { modifier = 6; threshold = 480; }
    ResetEncounter();
    gSaveBlock2Ptr->optionsEncounterRate = OPTIONS_RATE_1_5X;
    gPlayerAvatar.flags = PLAYER_AVATAR_FLAG_MACH_BIKE;
    if (modifier != 0)
        gPlayerAvatar.flags = 0;
    if (modifier == 1)
        FlagSet(FLAG_SYS_ENC_UP_ITEM);
    if (modifier == 2)
        FlagSet(FLAG_SYS_ENC_DOWN_ITEM);
    if (modifier == 3)
        VarSet(VAR_REPEL_STEP_COUNT, REPEL_LURE_MASK | 100);
    if (modifier == 4)
        SetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_HELD_ITEM, &(u16){ITEM_CLEANSE_TAG});
    if (modifier == 5 || modifier == 6)
    {
        CreateMon(&gParties[B_TRAINER_PLAYER][0], modifier == 5 ? SPECIES_GRIMER : SPECIES_DIGLETT, 20, 12345, OTID_STRUCT_PRESET(54321));
        SetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_ABILITY_NUM, &(u32){modifier == 6 ? 1 : 0});
    }
    EXPECT_EQ(CheckEncounterAtRoll(10, threshold - 1, FALSE, TRUE), TRUE);
    EXPECT_EQ(CheckEncounterAtRoll(10, threshold, FALSE, TRUE), FALSE);
}

static u32 PrintedMoney(void)
{
    return gBattleTextBuff1[4] | (gBattleTextBuff1[5] << 8) | (gBattleTextBuff1[6] << 16) | (gBattleTextBuff1[7] << 24);
}

TEST("Family money loss command clamps the scaled deduction and displays that amount")
{
    u32 rate = 0, wallet = 0, loss = 0, outcome = 0;
    PARAMETRIZE { rate = OPTIONS_RATE_0_5X; wallet = 50000; loss = 400; outcome = B_OUTCOME_LOST; }
    PARAMETRIZE { rate = OPTIONS_RATE_1X; wallet = 50000; loss = 800; outcome = B_OUTCOME_LOST; }
    PARAMETRIZE { rate = OPTIONS_RATE_1_5X; wallet = 50000; loss = 1200; outcome = B_OUTCOME_LOST; }
    PARAMETRIZE { rate = OPTIONS_RATE_2X; wallet = 50000; loss = 1600; outcome = B_OUTCOME_LOST; }
    PARAMETRIZE { rate = OPTIONS_RATE_2X; wallet = 0; loss = 0; outcome = B_OUTCOME_LOST; }
    PARAMETRIZE { rate = OPTIONS_RATE_1_5X; wallet = 499; loss = 499; outcome = B_OUTCOME_LOST; }
    PARAMETRIZE { rate = OPTIONS_RATE_2X; wallet = 999999; loss = 1600; outcome = B_OUTCOME_LOST; }
    PARAMETRIZE { rate = OPTIONS_RATE_1_5X; wallet = 50000; loss = 1200; outcome = B_OUTCOME_FORFEITED; }
    static const u8 command[] = {B_SCR_OP_GETMONEYREWARD};
    ResetFamilySave();
    CreateMon(&gParties[B_TRAINER_PLAYER][0], SPECIES_PIKACHU, 100, 12345, OTID_STRUCT_PRESET(54321));
    gSaveBlock2Ptr->optionsMoneyLoss = rate;
    SetMoney(&gSaveBlock1Ptr->money, wallet);
    gBattleOutcome = outcome;
    gBattlescriptCurrInstr = command;
    gBattleScriptingCommandsTable[B_SCR_OP_GETMONEYREWARD]();
    EXPECT_EQ(GetMoney(&gSaveBlock1Ptr->money), wallet - loss);
    EXPECT_EQ(PrintedMoney(), loss);
    EXPECT_EQ(gBattlescriptCurrInstr, command + 1);
}

TEST("Family retired Hard Mode permits trainer bag use and uncapped growth")
{
    u32 hard = 0;
    PARAMETRIZE { hard = FALSE; }
    PARAMETRIZE { hard = TRUE; }
    ResetFamilySave();
    gSaveBlock2Ptr->optionsHardMode = hard;
    gBattleTypeFlags = BATTLE_TYPE_TRAINER;
    EXPECT_EQ(IsAllowedToUseBag(), TRUE);
    EXPECT_EQ(GetCurrentLevelCap(), MAX_LEVEL);
    EXPECT_EQ(GetSoftLevelCapExpValue(25, 123), 123);
    CreateMon(&gParties[B_TRAINER_PLAYER][0], SPECIES_PIKACHU, 15, 12345, OTID_STRUCT_PRESET(54321));
    EXPECT_EQ(PokemonUseItemEffects(&gParties[B_TRAINER_PLAYER][0], ITEM_RARE_CANDY, 0, 0, FALSE), FALSE);
    EXPECT_EQ(GetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_LEVEL), 16);
}

TEST("Family retired Hard Mode daycare grows beyond the former badge ceiling")
{
    u32 hard = 0, level = 0, steps = 0, expected = 0;
    PARAMETRIZE { hard = FALSE; level = 15; steps = 721; expected = 16; }
    PARAMETRIZE { hard = TRUE; level = 15; steps = 721; expected = 16; }
    PARAMETRIZE { hard = TRUE; level = 99; steps = 1000000; expected = 100; }
    ResetFamilySave();
    gSaveBlock2Ptr->optionsHardMode = hard;
    CreateMon(&gParties[B_TRAINER_PLAYER][0], SPECIES_PIKACHU, level, 12345, OTID_STRUCT_PRESET(54321));
    StorePokemonInDaycare(&gParties[B_TRAINER_PLAYER][0], &gSaveBlock1Ptr->daycare.mons[0]);
    gSaveBlock1Ptr->daycare.mons[0].steps = steps;
    gSpecialVar_0x8004 = 0;
    EXPECT_EQ(TakePokemonFromDaycare(), SPECIES_PIKACHU);
    EXPECT_EQ(GetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_LEVEL), expected);
}

TEST("Family retired Hard Mode still honors maximum level for candy and increments")
{
    ResetFamilySave();
    gSaveBlock2Ptr->optionsHardMode = TRUE;
    CreateMon(&gParties[B_TRAINER_PLAYER][0], SPECIES_PIKACHU, MAX_LEVEL, 12345, OTID_STRUCT_PRESET(54321));
    EXPECT_EQ(PokemonUseItemEffects(&gParties[B_TRAINER_PLAYER][0], ITEM_RARE_CANDY, 0, 0, FALSE), TRUE);
    EXPECT_EQ(TryIncrementMonLevel(&gParties[B_TRAINER_PLAYER][0]), FALSE);
    EXPECT_EQ(GetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_LEVEL), MAX_LEVEL);
}

TEST("Family encounter callers opt in only ordinary land and surf checks")
{
    u32 map = 0, behavior = 0, expected = 0, rate = 0, kind = 0;
    PARAMETRIZE { map = MAP_ROUTE102; behavior = MB_TALL_GRASS; rate = OPTIONS_RATE_0_5X; expected = 160; }
    PARAMETRIZE { map = MAP_ROUTE102; behavior = MB_TALL_GRASS; rate = OPTIONS_RATE_2X; expected = 640; }
    PARAMETRIZE { map = MAP_ROUTE102; behavior = MB_POND_WATER; rate = OPTIONS_RATE_0_5X; expected = 32; }
    PARAMETRIZE { map = MAP_ROUTE102; behavior = MB_POND_WATER; rate = OPTIONS_RATE_2X; expected = 128; }
    PARAMETRIZE { map = MAP_BATTLE_FRONTIER_BATTLE_PIKE_ROOM_WILD_MONS; behavior = MB_TALL_GRASS; rate = OPTIONS_RATE_0_5X; expected = 160; }
    PARAMETRIZE { map = MAP_BATTLE_FRONTIER_BATTLE_PIKE_ROOM_WILD_MONS; behavior = MB_TALL_GRASS; rate = OPTIONS_RATE_2X; expected = 160; }
    PARAMETRIZE { map = MAP_BATTLE_FRONTIER_BATTLE_PYRAMID_FLOOR; behavior = MB_TALL_GRASS; rate = OPTIONS_RATE_0_5X; expected = 64; }
    PARAMETRIZE { map = MAP_BATTLE_FRONTIER_BATTLE_PYRAMID_FLOOR; behavior = MB_TALL_GRASS; rate = OPTIONS_RATE_2X; expected = 64; }
    PARAMETRIZE { map = MAP_ROUTE111; kind = 1; rate = OPTIONS_RATE_0_5X; expected = 320; }
    PARAMETRIZE { map = MAP_ROUTE111; kind = 1; rate = OPTIONS_RATE_2X; expected = 320; }
    ResetEncounter();
    CalculatePlayerPartyCount();
    gSaveBlock1Ptr->location.mapGroup = MAP_GROUP(map);
    gSaveBlock1Ptr->location.mapNum = MAP_NUM(map);
    gMapHeader = *Overworld_GetMapHeaderByGroupAndId(MAP_GROUP(map), MAP_NUM(map));
    gPlayerAvatar.flags = behavior == MB_POND_WATER ? PLAYER_AVATAR_FLAG_SURFING : PLAYER_AVATAR_FLAG_ON_FOOT;
    gSaveBlock2Ptr->optionsEncounterRate = rate;
    DisableWildEncounters(FALSE);
    u16 ime = REG_IME;
    REG_IME = 0;
    gRngValue = (rng_value_t){.a = 2879u << 16};
    bool8 encountered;
    if (kind == 1)
    {
        RockSmashWildEncounter();
        encountered = gSpecialVar_Result;
    }
    else
    {
        encountered = StandardWildEncounter(behavior, behavior);
    }
    u32 observedRate = Test_GetLastEncounterRate();
    u32 randomCalls = gRngValue.ctr;
    REG_IME = ime;
    EXPECT_EQ(encountered, FALSE);
    EXPECT_EQ(observedRate, expected);
    EXPECT_EQ(randomCalls, 1);
}

TEST("Family encounter preference leaves fishing generation and RNG unchanged")
{
    struct Pokemon baseline;
    rng_value_t rngAfter;
    for (u32 rate = 0; rate < OPTIONS_RATE_COUNT; rate++)
    {
        ResetEncounter();
        gSaveBlock1Ptr->location.mapGroup = MAP_GROUP(MAP_ROUTE102);
        gSaveBlock1Ptr->location.mapNum = MAP_NUM(MAP_ROUTE102);
        gMapHeader = *Overworld_GetMapHeaderByGroupAndId(MAP_GROUP(MAP_ROUTE102), MAP_NUM(MAP_ROUTE102));
        gChainFishingDexNavStreak = 0;
        gSaveBlock2Ptr->optionsEncounterRate = rate;
        u16 ime = REG_IME;
        REG_IME = 0;
        SeedRng(123);
        SeedRng2(456);
        FishingWildEncounter(0);
        struct Pokemon generated = gParties[B_TRAINER_OPPONENT_A][0];
        rng_value_t generatedRng = gRngValue;
        REG_IME = ime;
        // FishingWildEncounter always ends in BattleSetup_StartWildBattle, which queues
        // Task_BattleStart for the transition. Only the generated mon and RNG are under test,
        // so drop the queued battle start rather than leak one task per iteration.
        ResetTasks();
        if (rate == OPTIONS_RATE_1X)
        {
            baseline = generated;
            rngAfter = generatedRng;
            EXPECT_EQ(GetMonData(&baseline, MON_DATA_SPECIES), SPECIES_GOLDEEN);
        }
        EXPECT_EQ(memcmp(&generated, &baseline, sizeof(baseline)), 0);
        EXPECT_EQ(memcmp(&generatedRng, &rngAfter, sizeof(rngAfter)), 0);
    }
    gIsFishingEncounter = FALSE;
}

TEST("Family encounter preference leaves scripted Pokemon and RNG unchanged")
{
    struct Pokemon baseline;
    rng_value_t rngAfter;
    for (u32 rate = 0; rate < OPTIONS_RATE_COUNT; rate++)
    {
        ResetEncounter();
        gSaveBlock2Ptr->optionsEncounterRate = rate;
        u16 ime = REG_IME;
        REG_IME = 0;
        SeedRng(123);
        SeedRng2(456);
        CreateScriptedWildMon(SPECIES_SNORLAX, 30, ITEM_LEFTOVERS);
        struct Pokemon generated = gParties[B_TRAINER_OPPONENT_A][0];
        rng_value_t generatedRng = gRngValue;
        REG_IME = ime;
        EXPECT_EQ(GetMonData(&gParties[B_TRAINER_OPPONENT_A][0], MON_DATA_SPECIES), SPECIES_SNORLAX);
        EXPECT_EQ(GetMonData(&gParties[B_TRAINER_OPPONENT_A][0], MON_DATA_LEVEL), 30);
        EXPECT_EQ(GetMonData(&gParties[B_TRAINER_OPPONENT_A][0], MON_DATA_HELD_ITEM), ITEM_LEFTOVERS);
        if (rate == OPTIONS_RATE_1X)
        {
            baseline = generated;
            rngAfter = generatedRng;
        }
        EXPECT_EQ(memcmp(&generated, &baseline, sizeof(baseline)), 0);
        EXPECT_EQ(memcmp(&generatedRng, &rngAfter, sizeof(rngAfter)), 0);
    }
}
