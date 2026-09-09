#include "global.h"
#include "event_object_movement.h"
#include "field_effect.h"
#include "sprite.h"
#include "test/test.h"
#include "constants/event_object_movement.h"
#include "constants/event_objects.h"

static const u32 sFrame16x32[256 / sizeof(u32)] = {0};
static const u32 sFrame32x32[512 / sizeof(u32)] = {0};

static const struct OamData sOam16x32 = {
    .shape = SPRITE_SHAPE(16x32),
    .size = SPRITE_SIZE(16x32),
};

static const struct OamData sOam32x32 = {
    .shape = SPRITE_SHAPE(32x32),
    .size = SPRITE_SIZE(32x32),
};

static const struct SpriteFrameImage sImages16x32[] = {
    {.data = sFrame16x32, .size = sizeof(sFrame16x32)},
};

static const struct SpriteFrameImage sImages32x32[] = {
    {.data = sFrame32x32, .size = sizeof(sFrame32x32)},
};

static const struct SpriteTemplate sSpriteTemplate16x32 = {
    .tileTag = TAG_NONE,
    .paletteTag = TAG_NONE,
    .oam = &sOam16x32,
    .images = sImages16x32,
    .callback = SpriteCallbackDummy,
};

static const struct ObjectEventGraphicsInfo sGraphicsInfo32x32 = {
    .tileTag = TAG_NONE,
    .size = sizeof(sFrame32x32),
    .oam = &sOam32x32,
    .images = sImages32x32,
};

extern u16 LoadSheetGraphicsInfo(const struct ObjectEventGraphicsInfo *info, u16 uuid, struct Sprite *sprite);
extern u32 FldEff_Shadow(void);
extern void UpdateShadowFieldEffect(struct Sprite *sprite);

static void FillOverworldSpritePool(void)
{
    ResetSpriteData();
    FreeAllSpritePalettes();
    memset(gObjectEvents, 0, sizeof(gObjectEvents));
    for (u32 i = 0; i < MAX_SPRITES; i++)
        CreateSprite(&gDummySpriteTemplate, 0, 0, 0);
}

TEST("Overworld sprite exhaustion: object spawn rolls back and can retry")
{
    static const struct ObjectEventTemplate template = {
        .localId = 1,
        .graphicsId = OBJ_EVENT_GFX_LITTLE_BOY,
        .kind = OBJ_KIND_NORMAL,
        .movementType = MOVEMENT_TYPE_FACE_DOWN,
        .x = 5,
        .y = 5,
    };
    u8 objectEventId;

    FillOverworldSpritePool();
    EXPECT_EQ(TrySpawnObjectEventTemplate(&template, 0, 0, 0, 0), OBJECT_EVENTS_COUNT);
    for (u32 i = 0; i < OBJECT_EVENTS_COUNT; i++)
        EXPECT(!gObjectEvents[i].active);

    DestroySprite(&gSprites[0]);
    objectEventId = TrySpawnObjectEventTemplate(&template, 0, 0, 0, 0);
    EXPECT(objectEventId < OBJECT_EVENTS_COUNT);
    EXPECT(gObjectEvents[objectEventId].active);
    EXPECT_EQ(gObjectEvents[objectEventId].spriteId, 0);
    EXPECT(gSprites[0].inUse);
}

TEST("Overworld sprite exhaustion: virtual object skips creation and can retry")
{
    FillOverworldSpritePool();
    EXPECT_EQ(CreateVirtualObject(OBJ_EVENT_GFX_LITTLE_BOY, 1, 5, 5, 0, DIR_SOUTH), MAX_SPRITES);

    DestroySprite(&gSprites[MAX_SPRITES - 1]);
    EXPECT_EQ(CreateVirtualObject(OBJ_EVENT_GFX_LITTLE_BOY, 1, 5, 5, 0, DIR_SOUTH), MAX_SPRITES - 1);
    EXPECT(gSprites[MAX_SPRITES - 1].inUse);
}

TEST("Overworld sprite exhaustion: shadow skips creation and can retry")
{
    FillOverworldSpritePool();
    gObjectEvents[0].active = TRUE;
    gObjectEvents[0].localId = 1;
    gObjectEvents[0].graphicsId = OBJ_EVENT_GFX_LITTLE_BOY;
    gFieldEffectArguments[0] = 1;
    gFieldEffectArguments[1] = 0;
    gFieldEffectArguments[2] = 0;
    ASSUME(GetObjectEventGraphicsInfo(OBJ_EVENT_GFX_LITTLE_BOY)->shadowSize != SHADOW_SIZE_NONE);

    FldEff_Shadow();
    for (u32 i = 0; i < MAX_SPRITES; i++)
    {
        EXPECT(gSprites[i].inUse);
        EXPECT(gSprites[i].callback == SpriteCallbackDummy);
    }

    DestroySprite(&gSprites[MAX_SPRITES - 1]);
    FldEff_Shadow();
    EXPECT(gSprites[MAX_SPRITES - 1].inUse);
    EXPECT(gSprites[MAX_SPRITES - 1].callback == UpdateShadowFieldEffect);
}

TEST("LoadSheetGraphicsInfo reallocates non-sheet sprites when frame size changes")
{
    u16 i;
    u16 tileNum;
    u16 tileCount;
    u8 spriteId;
    struct Sprite *sprite;

    ASSUME(sOam16x32.size == sOam32x32.size);
    ASSUME(sOam16x32.shape != sOam32x32.shape);

    ResetSpriteData();
    spriteId = CreateSprite(&sSpriteTemplate16x32, 0, 0, 0);
    ASSUME(spriteId != MAX_SPRITES);

    sprite = &gSprites[spriteId];
    tileNum = sprite->oam.tileNum;
    tileCount = sGraphicsInfo32x32.images->size / TILE_SIZE_4BPP;

    EXPECT_EQ(sprite->images->size, sizeof(sFrame16x32));
    EXPECT_EQ(sGraphicsInfo32x32.images->size, sizeof(sFrame32x32));

    LoadSheetGraphicsInfo(&sGraphicsInfo32x32, 0, sprite);

    for (i = 0; i < tileCount; i++)
        EXPECT(SpriteTileAllocBitmapOp(tileNum + i, 2) != 0);

    DestroySprite(sprite);
}
