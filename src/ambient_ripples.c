#include "global.h"
#include "ambient_ripples.h"
#include "event_object_movement.h"
#include "field_effect.h"
#include "field_weather.h"
#include "fieldmap.h"
#include "main.h"
#include "overworld.h"
#include "palette.h"
#include "script.h"
#include "sprite.h"
#include "constants/field_effects.h"
#include "constants/field_weather.h"
#include "constants/maps.h"
#include "constants/metatile_behaviors.h"
#include "constants/weather.h"

#define AMBIENT_CLEAR_CAP 3
#define AMBIENT_RAIN_CAP 5
#define AMBIENT_SPRITE_RESERVE 12
#define AMBIENT_TILE_RESERVE 64
#define AMBIENT_PALETTE_RESERVE 2
#define AMBIENT_RING_TILES 4
#define AMBIENT_CANDIDATE_LIMIT 8

extern const u16 gFieldEffectObjectPalette1[];

static void SpriteCB_AmbientRipple(struct Sprite *sprite);

// Permanent template storage borrows only immutable frame/animation/OAM data.
// A private palette tag permits safe reclamation at any allocation boundary,
// including between a gameplay effect's palette load and sprite creation.
static EWRAM_DATA struct SpriteTemplate sAmbientRippleTemplate = {0};
static EWRAM_DATA u32 sAmbientRandom = 0;
static EWRAM_DATA u16 sAmbientMap = 0;
static EWRAM_DATA u8 sAmbientTimer = 0;
static EWRAM_DATA bool8 sCreatingAmbientRipple = FALSE;

static const struct SpritePalette sAmbientRipplePalette =
{
    .data = gFieldEffectObjectPalette1,
    .tag = FLDEFF_PAL_TAG_AMBIENT_RIPPLE,
};

static bool32 IsAmbientRipple(const struct Sprite *sprite)
{
    return sprite->inUse && !sprite->usingSheet
        && sprite->template == &sAmbientRippleTemplate
        && sprite->callback == SpriteCB_AmbientRipple;
}

static void FreeAmbientPaletteIfUnused(void)
{
    u32 palette = IndexOfSpritePaletteTag(FLDEFF_PAL_TAG_AMBIENT_RIPPLE);
    if (palette < 16)
        FieldEffectFreePaletteIfUnused(palette);
}

bool32 ReclaimAmbientRipples(void)
{
    bool32 released = FALSE;

    // A failed cosmetic allocation must skip, without entering allocator retry
    // recursively or destroying a sprite that is still being constructed.
    if (sCreatingAmbientRipple)
        return FALSE;

    for (u32 i = 0; i < MAX_SPRITES; i++)
    {
        if (IsAmbientRipple(&gSprites[i]))
        {
            // Untagged frame images own four tiles. No cached sheet is owned;
            // FieldEffectFreeGraphicsResources would inspect sheet tile zero.
            DestroySpriteAndClearFrameImages(&gSprites[i]);
            released = TRUE;
        }
    }
    if (released)
        FreeAmbientPaletteIfUnused();
    return released;
}

void ResetAmbientRipples(void)
{
    ReclaimAmbientRipples();
    sAmbientMap = MAP_UNDEFINED;
    sAmbientTimer = 0;
    sAmbientRandom = 0;
    sCreatingAmbientRipple = FALSE;
    sAmbientRippleTemplate = *gFieldEffectObjectTemplatePointers[FLDEFFOBJ_RIPPLE];
    sAmbientRippleTemplate.paletteTag = FLDEFF_PAL_TAG_AMBIENT_RIPPLE;
    sAmbientRippleTemplate.callback = SpriteCB_AmbientRipple;
}

static u32 NextAmbientRandom(u32 limit)
{
    // Private cosmetic sequence; no Random/Random2/RandomUniform calls.
    u32 value = sAmbientRandom;
    value ^= value << 13;
    value ^= value >> 17;
    value ^= value << 5;
    sAmbientRandom = value;
    return value % limit;
}

static bool32 IsPondMap(u16 map)
{
    return map == MAP_PETALBURG_CITY || map == MAP_VIOLET_CITY || map == MAP_FUCHSIA_CITY;
}

static u32 GetAmbientCap(u16 map)
{
    if (!IsPondMap(map) && map != MAP_ROUTE119)
        return 0;
    switch (GetCurrentWeather())
    {
    case WEATHER_RAIN:
    case WEATHER_RAIN_THUNDERSTORM:
    case WEATHER_DOWNPOUR:
        return AMBIENT_RAIN_CAP;
    case WEATHER_NONE:
    case WEATHER_SUNNY:
    case WEATHER_SUNNY_CLOUDS:
    case WEATHER_SHADE:
        return IsPondMap(map) ? AMBIENT_CLEAR_CAP : 0;
    default:
        return 0;
    }
}

static bool32 IsPondTile(s16 x, s16 y)
{
    u32 behavior = MapGridGetMetatileBehaviorAt(x, y);
    return behavior == MB_POND_WATER || behavior == MB_SOOTOPOLIS_DEEP_WATER;
}

static bool32 IsSuitableSurface(s16 x, s16 y)
{
    if (sAmbientMap == MAP_ROUTE119)
        return MapGridGetMetatileBehaviorAt(x, y) == MB_PUDDLE;
    for (s32 dy = -1; dy <= 1; dy++)
        for (s32 dx = -1; dx <= 1; dx++)
            if (!IsPondTile(x + dx, y + dy))
                return FALSE;
    return TRUE;
}

static bool32 IsNearActor(s16 x, s16 y)
{
    for (u32 i = 0; i < OBJECT_EVENTS_COUNT; i++)
    {
        const struct ObjectEvent *object = &gObjectEvents[i];
        if (object->active
            && ((abs(object->currentCoords.x - x) <= 1 && abs(object->currentCoords.y - y) <= 1)
             || (abs(object->previousCoords.x - x) <= 1 && abs(object->previousCoords.y - y) <= 1)))
            return TRUE;
    }
    return FALSE;
}

static bool32 IsInsideViewport(s16 x, s16 y)
{
    s16 screenX = x + gSpriteCoordOffsetX;
    s16 screenY = y + gSpriteCoordOffsetY;
    return screenX >= 8 && screenX <= DISPLAY_WIDTH - 8
        && screenY >= 8 && screenY <= DISPLAY_HEIGHT - 8;
}

static void SpriteCB_AmbientRipple(struct Sprite *sprite)
{
    if (sprite->animEnded || !IsInsideViewport(sprite->x, sprite->y))
    {
        DestroySpriteAndClearFrameImages(sprite);
        FreeAmbientPaletteIfUnused();
    }
}

static void TryCreateAmbientRipple(s16 x, s16 y)
{
    u32 palette = IndexOfSpritePaletteTag(FLDEFF_PAL_TAG_AMBIENT_RIPPLE);
    bool32 loadedPalette = palette == 0xFF;
    u32 spriteId;

    if (CountFreePaletteSlots() < AMBIENT_PALETTE_RESERVE + loadedPalette
        || !CanAllocSpriteTiles(AMBIENT_TILE_RESERVE + AMBIENT_RING_TILES))
        return;

    sCreatingAmbientRipple = TRUE;
    if (loadedPalette)
    {
        palette = LoadSpritePalette(&sAmbientRipplePalette);
        if (palette == 0xFF)
        {
            sCreatingAmbientRipple = FALSE;
            return;
        }
        SetPaletteColorMapType(palette + 16, COLOR_MAP_DARK_CONTRAST);
        UpdateSpritePaletteWithWeather(palette, TRUE);
    }
    spriteId = CreateSpriteAtEndUnchecked(&sAmbientRippleTemplate, x, y, 153);
    sCreatingAmbientRipple = FALSE;
    if (spriteId == MAX_SPRITES)
    {
        if (loadedPalette)
            FreeAmbientPaletteIfUnused();
        return;
    }
    gSprites[spriteId].coordOffsetEnabled = TRUE;
    gSprites[spriteId].oam.priority = 3;
}

void UpdateAmbientRipples(void)
{
    u16 map;
    u32 cap, count = 0, freeSprites = 0;

    if (gMain.callback2 != CB2_Overworld)
        return;
    map = (gSaveBlock1Ptr->location.mapGroup << 8) | gSaveBlock1Ptr->location.mapNum;
    if (map != sAmbientMap)
    {
        ReclaimAmbientRipples();
        sAmbientMap = map;
        sAmbientTimer = 0;
        sAmbientRandom = 0xA3619C25 ^ (map + 1);
    }
    cap = GetAmbientCap(map);
    if (cap == 0)
    {
        ReclaimAmbientRipples();
        sAmbientTimer = 0;
        return;
    }
    for (u32 i = 0; i < MAX_SPRITES; i++)
    {
        freeSprites += !gSprites[i].inUse;
        count += IsAmbientRipple(&gSprites[i]);
    }
    if (freeSprites < AMBIENT_SPRITE_RESERVE
        || !CanAllocSpriteTiles(AMBIENT_TILE_RESERVE)
        || CountFreePaletteSlots() < AMBIENT_PALETTE_RESERVE
        || count > cap)
    {
        ReclaimAmbientRipples();
        sAmbientTimer = 0;
        return;
    }
    if (ArePlayerFieldControlsLocked() || gPaletteFade.active)
        return;
    if (++sAmbientTimer < (cap == AMBIENT_RAIN_CAP ? 15 : 30))
        return;
    sAmbientTimer = 0;
    if (count >= cap || freeSprites <= AMBIENT_SPRITE_RESERVE)
        return;

    for (u32 attempt = 0; attempt < AMBIENT_CANDIDATE_LIMIT; attempt++)
    {
        s16 mapX = gSaveBlock1Ptr->pos.x + NextAmbientRandom(15);
        // Include camera pan and partial edge rows; the pixel check below
        // excludes clipped rings, including when the camera is scrolling.
        s16 mapY = gSaveBlock1Ptr->pos.y + NextAmbientRandom(14);
        s16 x = mapX, y = mapY;
        if (!IsSuitableSurface(mapX, mapY) || IsNearActor(mapX, mapY))
            continue;
        SetSpritePosToOffsetMapCoords(&x, &y, 8, 8);
        if (map != MAP_ROUTE119)
        {
            x += (s32)NextAmbientRandom(9) - 4;
            y += (s32)NextAmbientRandom(9) - 4;
        }
        if (!IsInsideViewport(x, y))
            continue;
        TryCreateAmbientRipple(x, y);
        return;
    }
}
