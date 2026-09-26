#include "global.h"
#include "battle.h"
#include "battle_environment.h"
#include "battle_presentation.h"
#include "constants/maps.h"
#include "constants/rtc.h"
#include "test/test.h"

static struct BattlePresentationContext Context(u16 environment, u16 map, enum MapType mapType)
{
    return (struct BattlePresentationContext){
        .environment = environment,
        .entryEnvironment = environment,
        .introEnvironment = environment,
        .map = map,
        .mapType = mapType,
        .time = {.startBlend = gTimeOfDayBlend[TIME_NIGHT], .endBlend = gTimeOfDayBlend[TIME_NIGHT], .weight = 256},
    };
}

TEST("Battle presentation: all Ice Path floors reuse complete cave art with cold colors")
{
    u16 map;
    PARAMETRIZE { map = MAP_ICE_PATH_1F; }
    PARAMETRIZE { map = MAP_ICE_PATH_B1F; }
    PARAMETRIZE { map = MAP_ICE_PATH_B2F; }
    PARAMETRIZE { map = MAP_ICE_PATH_B3F; }
    PARAMETRIZE { map = MAP_ICE_PATH_B4F; }
    struct BattlePresentationContext input = Context(BATTLE_ENVIRONMENT_CAVE, map, MAP_TYPE_UNDERGROUND);
    struct BattlePresentation result;
    ResolveBattlePresentation(&input, &result);
    EXPECT_EQ(result.background.tileset, gBattleEnvironmentInfo[BATTLE_ENVIRONMENT_CAVE].background.tileset);
    EXPECT_EQ(result.entry.tileset, gBattleEnvironmentInfo[BATTLE_ENVIRONMENT_CAVE].entry.tileset);
    EXPECT_NE(result.dayPalette, gBattleEnvironmentInfo[BATTLE_ENVIRONMENT_CAVE].palette);
    EXPECT_EQ(result.introEnvironment, BATTLE_ENVIRONMENT_CAVE);
    EXPECT_EQ(result.tintWithTime, FALSE);
}

TEST("Battle presentation: snow changes only ordinary land and pairs rock art with its entry slide")
{
    u16 environment, map;
    PARAMETRIZE { environment = BATTLE_ENVIRONMENT_PLAIN; map = MAP_MT_SILVER_SNOW; }
    PARAMETRIZE { environment = BATTLE_ENVIRONMENT_MOUNTAIN; map = MAP_MT_SILVER_SNOW; }
    PARAMETRIZE { environment = BATTLE_ENVIRONMENT_MOUNTAIN; map = MAP_MT_SILVER_SUMMIT_DAY; }
    PARAMETRIZE { environment = BATTLE_ENVIRONMENT_GRASS; map = MAP_MT_SILVER_SNOW; }
    PARAMETRIZE { environment = BATTLE_ENVIRONMENT_POND; map = MAP_MT_SILVER_SNOW; }
    PARAMETRIZE { environment = BATTLE_ENVIRONMENT_WATER; map = MAP_MT_SILVER_SUMMIT_DAY; }
    struct BattlePresentationContext input = Context(environment, map, MAP_TYPE_ROUTE);
    struct BattlePresentation result;
    bool32 snow = environment == BATTLE_ENVIRONMENT_PLAIN || environment == BATTLE_ENVIRONMENT_MOUNTAIN;
    u16 visual = snow ? BATTLE_ENVIRONMENT_MOUNTAIN : environment;
    ResolveBattlePresentation(&input, &result);
    EXPECT_EQ(result.background.tileset, gBattleEnvironmentInfo[visual].background.tileset);
    EXPECT_EQ(result.entry.tileset, gBattleEnvironmentInfo[visual].entry.tileset);
    EXPECT_EQ(result.introEnvironment, visual);
    if (snow)
        EXPECT_NE(result.dayPalette, gBattleEnvironmentInfo[environment].palette);
    else
        EXPECT_EQ(result.dayPalette, gBattleEnvironmentInfo[environment].palette);
}

TEST("Battle presentation: explicit, legendary, facility, partner and tutorial scenes keep their palettes")
{
    u32 flags = 0;
    bool32 preserve = FALSE;
    PARAMETRIZE { flags = BATTLE_TYPE_LINK; }
    PARAMETRIZE { flags = BATTLE_TYPE_RECORDED; }
    PARAMETRIZE { flags = BATTLE_TYPE_RECORDED_LINK; }
    PARAMETRIZE { flags = BATTLE_TYPE_BATTLE_TOWER; }
    PARAMETRIZE { flags = BATTLE_TYPE_ARENA; }
    PARAMETRIZE { flags = BATTLE_TYPE_LEGENDARY; }
    PARAMETRIZE { flags = BATTLE_TYPE_FIRST_BATTLE; }
    PARAMETRIZE { flags = BATTLE_TYPE_CATCH_TUTORIAL; }
    PARAMETRIZE { flags = BATTLE_TYPE_POKEDUDE; }
    PARAMETRIZE { flags = BATTLE_TYPE_INGAME_PARTNER; }
    PARAMETRIZE { flags = BATTLE_TYPE_EREADER_TRAINER; }
    PARAMETRIZE { flags = BATTLE_TYPE_TRAINER_HILL; }
    PARAMETRIZE { flags = BATTLE_TYPE_GHOST; }
    PARAMETRIZE { preserve = TRUE; } // Forced environment or explicit map scene.
    struct BattlePresentationContext input = Context(BATTLE_ENVIRONMENT_MOUNTAIN, MAP_MT_SILVER_SNOW, MAP_TYPE_ROUTE);
    struct BattlePresentation result;
    input.battleTypeFlags = flags;
    input.preserveOriginal = preserve;
    ResolveBattlePresentation(&input, &result);
    EXPECT_EQ(result.dayPalette, gBattleEnvironmentInfo[BATTLE_ENVIRONMENT_MOUNTAIN].palette);
    EXPECT_EQ(result.tintWithTime, FALSE);
}

TEST("Battle presentation: only naturally lit maps receive outdoor time colors")
{
    enum MapType mapType;
    bool32 tint;
    PARAMETRIZE { mapType = MAP_TYPE_TOWN; tint = TRUE; }
    PARAMETRIZE { mapType = MAP_TYPE_CITY; tint = TRUE; }
    PARAMETRIZE { mapType = MAP_TYPE_ROUTE; tint = TRUE; }
    PARAMETRIZE { mapType = MAP_TYPE_OCEAN_ROUTE; tint = TRUE; }
    PARAMETRIZE { mapType = MAP_TYPE_UNDERGROUND; tint = FALSE; }
    PARAMETRIZE { mapType = MAP_TYPE_UNDERWATER; tint = FALSE; }
    PARAMETRIZE { mapType = MAP_TYPE_INDOOR; tint = FALSE; }
    PARAMETRIZE { mapType = MAP_TYPE_SECRET_BASE; tint = FALSE; }
    struct BattlePresentationContext input = Context(BATTLE_ENVIRONMENT_GRASS, MAP_ROUTE101, mapType);
    struct BattlePresentation result;
    ResolveBattlePresentation(&input, &result);
    EXPECT_EQ(result.tintWithTime, tint);
}

TEST("Battle presentation: incomplete and invalid visual environments have complete fallback art")
{
    u16 environment;
    PARAMETRIZE { environment = BATTLE_ENVIRONMENT_SNOW; }
    PARAMETRIZE { environment = BATTLE_ENVIRONMENT_ICE; }
    PARAMETRIZE { environment = BATTLE_ENVIRONMENT_COUNT; }
    PARAMETRIZE { environment = 0xFFFF; }
    struct BattlePresentationContext input = Context(environment, MAP_ICE_PATH_1F, MAP_TYPE_UNDERGROUND);
    struct BattlePresentation result;
    ResolveBattlePresentation(&input, &result);
    EXPECT_EQ(result.background.tileset, gBattleEnvironmentInfo[BATTLE_ENVIRONMENT_PLAIN].background.tileset);
    EXPECT_EQ(result.background.tilemap, gBattleEnvironmentInfo[BATTLE_ENVIRONMENT_PLAIN].background.tilemap);
    EXPECT_EQ(result.entry.tileset, gBattleEnvironmentInfo[BATTLE_ENVIRONMENT_PLAIN].entry.tileset);
    EXPECT_EQ(result.entry.tilemap, gBattleEnvironmentInfo[BATTLE_ENVIRONMENT_PLAIN].entry.tilemap);
    EXPECT_EQ(result.dayPalette, gBattleEnvironmentInfo[BATTLE_ENVIRONMENT_PLAIN].palette);
}

TEST("Battle presentation: tint snapshots do not mutate authored colors, inputs or gameplay environment")
{
    struct BattlePresentationContext input = Context(BATTLE_ENVIRONMENT_GRASS, MAP_ROUTE101, MAP_TYPE_ROUTE);
    struct BattlePresentationContext original = input;
    struct BattlePresentation result;
    u16 authored[BATTLE_PRESENTATION_COLORS], first[BATTLE_PRESENTATION_COLORS], second[BATTLE_PRESENTATION_COLORS];
    u8 environment = gBattleEnvironment;
    ResolveBattlePresentation(&input, &result);
    memcpy(authored, result.dayPalette, sizeof(authored));
    BuildBattlePresentationPalette(&result, first);
    input.time = (struct TimeBlendSettings){.weight = 256}; // The clock has moved to day.
    BuildBattlePresentationPalette(&result, second);
    EXPECT_EQ(memcmp(first, second, sizeof(first)), 0);
    EXPECT_NE(memcmp(first, authored, sizeof(first)), 0);
    EXPECT_EQ(memcmp(result.dayPalette, authored, sizeof(authored)), 0);
    EXPECT_EQ(memcmp(&result.time, &original.time, sizeof(original.time)), 0);
    EXPECT_EQ(gBattleEnvironment, environment);
    EXPECT_EQ(input.environment, original.environment);
    EXPECT_EQ(input.map, original.map);
}

TEST("Battle presentation: Granite Cave and authored day colors remain unchanged")
{
    struct BattlePresentationContext input = Context(BATTLE_ENVIRONMENT_CAVE, MAP_GRANITE_CAVE_1F, MAP_TYPE_UNDERGROUND);
    struct BattlePresentation result;
    u16 palette[BATTLE_PRESENTATION_COLORS];
    ResolveBattlePresentation(&input, &result);
    BuildBattlePresentationPalette(&result, palette);
    EXPECT_EQ(memcmp(palette, gBattleEnvironmentInfo[BATTLE_ENVIRONMENT_CAVE].palette, sizeof(palette)), 0);
    input = Context(BATTLE_ENVIRONMENT_GRASS, MAP_ROUTE101, MAP_TYPE_ROUTE);
    input.time = (struct TimeBlendSettings){.startBlend = gTimeOfDayBlend[TIME_DAY], .endBlend = gTimeOfDayBlend[TIME_DAY], .weight = 256};
    ResolveBattlePresentation(&input, &result);
    BuildBattlePresentationPalette(&result, palette);
    EXPECT_EQ(memcmp(palette, gBattleEnvironmentInfo[BATTLE_ENVIRONMENT_GRASS].palette, sizeof(palette)), 0);
}
