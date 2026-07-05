// Parametrized sprite-creation helpers by Hedara, ported with the Unbound-style start menu
// (miriamlefae/pokeemerald-expansion feat/usm/upcoming). Only compiled for the graphical menu.
#include "global.h"
#include "config/start_menu.h"

#if PW_GRAPHICAL_START_MENU

#include "even_sprite.h"
#include "decompress.h"
#include "malloc.h"
#include "sprite.h"

static const struct OamData sOamData_ItemIcon =
{
    .y = 0,
    .affineMode = ST_OAM_AFFINE_OFF,
    .objMode = ST_OAM_OBJ_NORMAL,
    .mosaic = FALSE,
    .bpp = ST_OAM_4BPP,
    .shape = 0,
    .x = 0,
    .matrixNum = 0,
    .size = 0,
    .tileNum = 0,
    .priority = 1,
    .paletteNum = 2,
    .affineParam = 0
};

static const union AnimCmd sSpriteAnim_ItemIcon[] =
{
    ANIMCMD_FRAME(0, 0),
    ANIMCMD_END
};

static const union AnimCmd *const sSpriteAnimTable_ItemIcon[] =
{
    sSpriteAnim_ItemIcon
};

static const struct SpriteTemplate sTempSpriteTemplate =
{
    .tileTag = 0,
    .paletteTag = 0,
    .oam = NULL,
    .anims = sSpriteAnimTable_ItemIcon,
    .images = NULL,
    .affineAnims = gDummySpriteAffineAnimTable,
    .callback = SpriteCallbackDummy,
};

u32 Even_CreateSprite(struct Even_CreateSpriteStruct *createStruct)
{
    u8 spriteId;
    struct SpriteSheet spriteSheet;
    struct SpriteTemplate *spriteTemplate;
    struct OamData oamData = sOamData_ItemIcon;
    oamData.size = createStruct->spriteSize;
    oamData.shape = createStruct->spriteShape;

    u32 *spriteSrc;
    if (createStruct->spriteCompressed)
    {
        spriteSrc = Alloc(GetDecompressedDataSize(createStruct->sprite));
        DecompressDataWithHeaderWram(createStruct->sprite, spriteSrc);
    }
    else
    {
        spriteSrc = (u32 *)createStruct->sprite;
    }

    if (createStruct->palette != NULL)
    {
        struct SpritePalette spritePalette;
        spritePalette.tag = createStruct->palTag;
        spritePalette.data = createStruct->palette;
        LoadSpritePalette(&spritePalette);
    }

    u32 byteSize = 0;
    switch (createStruct->spriteSize)
    {
    case ST_OAM_SIZE_0:
        if (createStruct->spriteShape == ST_OAM_SQUARE)
            byteSize = 32;
        else
            byteSize = 64;
        break;
    case ST_OAM_SIZE_1:
        byteSize = 128;
        break;
    case ST_OAM_SIZE_2:
        if (createStruct->spriteShape == ST_OAM_SQUARE)
            byteSize = 512;
        else
            byteSize = 256;
        break;
    case ST_OAM_SIZE_3:
        if (createStruct->spriteShape == ST_OAM_SQUARE)
            byteSize = 2048;
        else
            byteSize = 1024;
        break;
    }

    spriteSheet.data = spriteSrc;
    spriteSheet.size = byteSize;
    spriteSheet.tag = createStruct->tileTag;
    LoadSpriteSheet(&spriteSheet);

    spriteTemplate = Alloc(sizeof(*spriteTemplate));
    CpuCopy16(&sTempSpriteTemplate, spriteTemplate, sizeof(*spriteTemplate));
    spriteTemplate->tileTag = createStruct->tileTag;
    spriteTemplate->paletteTag = createStruct->palTag;
    spriteTemplate->oam = &oamData;

    if (createStruct->callback == NULL)
        spriteTemplate->callback = SpriteCallbackDummy;
    else
        spriteTemplate->callback = createStruct->callback;

    spriteId = CreateSprite(spriteTemplate, createStruct->posX, createStruct->posY, createStruct->subpriority);

    Free(spriteTemplate);

    if (createStruct->spriteCompressed)
        Free(spriteSrc);
    return spriteId;
}

u32 Even_CreateSpriteParametrized(const u32* sprite, u16 tileTag, const u16* palette, u16 palTag, u8 size, u8 shape,
                                  s16 x, s16 y, u8 subpriority, SpriteCallback callback, bool32 spriteCompressed)
{
    struct Even_CreateSpriteStruct cs = {0};
    cs.sprite = sprite;
    cs.tileTag = tileTag;
    cs.palette = palette;
    cs.palTag = palTag;
    cs.spriteSize = size;
    cs.spriteShape = shape;
    cs.posX = x;
    cs.posY = y;
    cs.subpriority = 0;
    cs.callback = callback;
    cs.spriteCompressed = spriteCompressed;
    return Even_CreateSprite(&cs);
}

#endif // PW_GRAPHICAL_START_MENU
