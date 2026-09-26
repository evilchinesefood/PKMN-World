#include "global.h"
#include "battle_environment.h"
#include "battle_presentation.h"
#include "overworld.h"
#include "constants/maps.h"

static const u16 sIcePathPalette[] = INCGFX_U16("graphics/battle_environment/cave/ice_path.pal", ".gbapal");
static const u16 sMtSilverSnowPalette[] = INCGFX_U16("graphics/battle_environment/rock/mt_silver_snow.pal", ".gbapal");
STATIC_ASSERT(ARRAY_COUNT(sIcePathPalette) == BATTLE_PRESENTATION_COLORS, IcePathPaletteSize);
STATIC_ASSERT(ARRAY_COUNT(sMtSilverSnowPalette) == BATTLE_PRESENTATION_COLORS, MtSilverSnowPaletteSize);

static u16 GetCompleteVisualEnvironment(u16 environment)
{
    if (environment < BATTLE_ENVIRONMENT_COUNT
     && gBattleEnvironmentInfo[environment].background.tileset != NULL
     && gBattleEnvironmentInfo[environment].background.tilemap != NULL
     && gBattleEnvironmentInfo[environment].entry.tileset != NULL
     && gBattleEnvironmentInfo[environment].entry.tilemap != NULL
     && gBattleEnvironmentInfo[environment].palette != NULL)
        return environment;
    return BATTLE_ENVIRONMENT_PLAIN;
}

static bool32 IsIcePath(u16 map)
{
    switch (map)
    {
    case MAP_ICE_PATH_1F:
    case MAP_ICE_PATH_B1F:
    case MAP_ICE_PATH_B2F:
    case MAP_ICE_PATH_B3F:
    case MAP_ICE_PATH_B4F:
        return TRUE;
    default:
        return FALSE;
    }
}

void ResolveBattlePresentation(const struct BattlePresentationContext *context, struct BattlePresentation *result)
{
    u16 environment = GetCompleteVisualEnvironment(context->environment);
    u16 entryEnvironment = GetCompleteVisualEnvironment(context->entryEnvironment);
    const struct BattleEnvironment *base = &gBattleEnvironmentInfo[environment];
    bool32 ordinary = !context->preserveOriginal
        && context->environment <= BATTLE_ENVIRONMENT_PLAIN
        && !(context->battleTypeFlags & (BATTLE_TYPE_LINK | BATTLE_TYPE_RECORDED | BATTLE_TYPE_RECORDED_LINK
             | BATTLE_TYPE_FRONTIER | BATTLE_TYPE_EREADER_TRAINER | BATTLE_TYPE_LEGENDARY
             | BATTLE_TYPE_FIRST_BATTLE | BATTLE_TYPE_CATCH_TUTORIAL | BATTLE_TYPE_POKEDUDE
             | BATTLE_TYPE_TRAINER_HILL | BATTLE_TYPE_SECRET_BASE | BATTLE_TYPE_GHOST
             | BATTLE_TYPE_INGAME_PARTNER));

    *result = (struct BattlePresentation){
        .background = base->background,
        .entry = gBattleEnvironmentInfo[entryEnvironment].entry,
        .dayPalette = base->palette,
        .introEnvironment = GetCompleteVisualEnvironment(context->introEnvironment),
        .time = context->time,
    };
    if (!ordinary)
        return;

    if (IsIcePath(context->map) && environment == BATTLE_ENVIRONMENT_CAVE)
    {
        result->dayPalette = sIcePathPalette;
    }
    else if ((context->map == MAP_MT_SILVER_SNOW || context->map == MAP_MT_SILVER_SUMMIT_DAY)
          && (environment == BATTLE_ENVIRONMENT_MOUNTAIN || environment == BATTLE_ENVIRONMENT_PLAIN))
    {
        result->background = gBattleEnvironmentInfo[BATTLE_ENVIRONMENT_MOUNTAIN].background;
        result->entry = gBattleEnvironmentInfo[BATTLE_ENVIRONMENT_MOUNTAIN].entry;
        result->introEnvironment = BATTLE_ENVIRONMENT_MOUNTAIN;
        result->dayPalette = sMtSilverSnowPalette;
    }
    result->tintWithTime = MapHasNaturalLight(context->mapType);
}

void BuildBattlePresentationPalette(const struct BattlePresentation *presentation, u16 *dest)
{
    // Always start with authored day colors, including after terrain/menu returns.
    // Only this three-bank buffer is tinted; UI and OBJ palettes are never inputs.
    CpuCopy16(presentation->dayPalette, dest, BATTLE_PRESENTATION_COLORS * sizeof(u16));
    if (presentation->tintWithTime)
    {
        struct TimeBlendSettings time = presentation->time;
        TimeMixPalettes(0x7, dest, dest, &time.startBlend, &time.endBlend, time.weight);
    }
}
