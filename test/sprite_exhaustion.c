#include "global.h"
#include "event_object_movement.h"
#include "field_effect.h"
#include "field_effect_helpers.h"
#include "field_weather.h"
#include "sprite.h"
#include "test/overworld_script.h"
#include "test/test.h"
#include "constants/field_effects.h"
#include "constants/field_weather.h"
#include "constants/event_objects.h"

static void OccupySpriteSlots(u32 count)
{
    ResetSpriteData();
    FreeAllSpritePalettes();
    FieldEffectActiveListClear();
    for (u32 i = 0; i < count; i++)
        CreateSprite(&gDummySpriteTemplate, 0, 0, 0);
}

TEST("Sprite exhaustion audit: warp arrow can report allocation failure")
{
    struct Sprite sentinel;
    u8 spriteId;
    OccupySpriteSlots(MAX_SPRITES);
    sentinel = gSprites[MAX_SPRITES];
    spriteId = CreateWarpArrowSprite();
    EXPECT_EQ(spriteId, MAX_SPRITES);
    ShowWarpArrowSprite(spriteId, DIR_SOUTH, 5, 5);
    SetSpriteInvisible(spriteId);
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);

    DestroySprite(&gSprites[MAX_SPRITES - 1]);
    spriteId = CreateWarpArrowSprite();
    EXPECT_EQ(spriteId, MAX_SPRITES - 1);
    ShowWarpArrowSprite(spriteId, DIR_SOUTH, 5, 5);
    EXPECT(!gSprites[spriteId].invisible);
    SetSpriteInvisible(spriteId);
    EXPECT(gSprites[spriteId].invisible);
}

TEST("Sprite exhaustion audit: rain initializes, changes intensity and tears down with missing sprites")
{
    u32 available;
    u32 frames;
    u32 count = 0;
    PARAMETRIZE { available = 0; }
    PARAMETRIZE { available = 1; }
    PARAMETRIZE { available = MAX_RAIN_SPRITES; }
    OccupySpriteSlots(MAX_SPRITES - available);
    memset(gWeatherPtr, 0, sizeof(*gWeatherPtr));
    gWeatherPtr->targetRainSpriteCount = 10;
    for (frames = 0; frames < 128 && !gWeatherPtr->weatherGfxLoaded; frames++)
        Rain_Main();
    EXPECT(gWeatherPtr->weatherGfxLoaded);
    EXPECT_EQ(gWeatherPtr->rainSpriteCount, MAX_RAIN_SPRITES);
    for (u32 i = 0; i < MAX_RAIN_SPRITES; i++)
        if (gWeatherPtr->sprites.s1.rainSprites[i] != NULL)
            count++;
    EXPECT_EQ(count, available);

    // Exercise both visibility directions, including NULL entries.
    gWeatherPtr->initStep = 2;
    gWeatherPtr->weatherGfxLoaded = FALSE;
    gWeatherPtr->targetRainSpriteCount = MAX_RAIN_SPRITES;
    for (frames = 0; frames < 128 && !gWeatherPtr->weatherGfxLoaded; frames++)
        Rain_Main();
    EXPECT(gWeatherPtr->weatherGfxLoaded);
    EXPECT_EQ(gWeatherPtr->curRainSpriteIndex, MAX_RAIN_SPRITES);
    for (frames = 0; frames < 128 && Rain_Finish(); frames++)
        ;
    EXPECT(frames < 128);
    EXPECT_EQ(gWeatherPtr->rainSpriteCount, 0);
    EXPECT_EQ(gWeatherPtr->curRainSpriteIndex, 0);
    for (u32 i = 0; i < MAX_SPRITES; i++)
        EXPECT(gSprites[i].inUse == (i < MAX_SPRITES - available));
}

TEST("Sprite exhaustion audit: trainer exclamation must not leave encounters waiting")
{
    OccupySpriteSlots(MAX_SPRITES);
    memset(gFieldEffectArguments, 0, sizeof(gFieldEffectArguments));
    FieldEffectStart(FLDEFF_EXCLAMATION_MARK_ICON);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_EXCLAMATION_MARK_ICON));

    DestroySprite(&gSprites[MAX_SPRITES - 1]);
    FieldEffectStart(FLDEFF_EXCLAMATION_MARK_ICON);
    EXPECT(FieldEffectActiveListContains(FLDEFF_EXCLAMATION_MARK_ICON));
    EXPECT(gSprites[MAX_SPRITES - 1].inUse);
    gSprites[MAX_SPRITES - 1].animEnded = TRUE;
    gSprites[MAX_SPRITES - 1].callback(&gSprites[MAX_SPRITES - 1]);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_EXCLAMATION_MARK_ICON));
    EXPECT(!gSprites[MAX_SPRITES - 1].inUse);
}

TEST("Sprite exhaustion audit: map light skips allocation and retries when a slot opens")
{
    static const struct MapEvents events = {.objectEventCount = 1};
    const struct MapEvents *savedEvents = gMapHeader.events;
    OccupySpriteSlots(MAX_SPRITES);
    gMapHeader.events = &events;
    gSaveBlock1Ptr->objectEventTemplates[0] = (struct ObjectEventTemplate){
        .graphicsId = OBJ_EVENT_GFX_LIGHT_SPRITE,
    };
    TrySpawnObjectEvents(0, 0);
    for (u32 i = 0; i < MAX_SPRITES; i++)
        EXPECT(gSprites[i].callback == SpriteCallbackDummy);

    DestroySprite(&gSprites[0]);
    TrySpawnObjectEvents(0, 0);
    EXPECT(gSprites[0].inUse);
    EXPECT(gSprites[0].callback != SpriteCallbackDummy);
    gMapHeader.events = savedEvents;
}

TEST("Sprite exhaustion audit: actual Dome final audience script tolerates limited capacity")
{
    u32 occupied;
    u32 sprites = 0;
    PARAMETRIZE { occupied = 0; }
    PARAMETRIZE { occupied = 40; }
    PARAMETRIZE { occupied = MAX_SPRITES; }

    // Run the real audience script, without requiring a tournament save or
    // fabricating battle records. This is a capacity test, not a final playthrough.
    OccupySpriteSlots(occupied);
    RUN_OVERWORLD_SCRIPT(
        call BattleFrontier_BattleDomeBattleRoom_EventScript_AddFinalAudience;
    );
    for (u32 i = 0; i < MAX_SPRITES; i++)
        if (gSprites[i].inUse)
            sprites++;
    EXPECT_EQ(sprites, min(MAX_SPRITES, occupied + 32));
    for (u32 i = 0; i < occupied; i++)
        EXPECT(gSprites[i].callback == SpriteCallbackDummy);
}
