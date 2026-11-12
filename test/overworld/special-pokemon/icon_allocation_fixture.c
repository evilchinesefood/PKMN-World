#include "global.h"
#include "event_data.h"
#include "main.h"
#include "malloc.h"
#include "overworld.h"
#include "pokemon_icon.h"
#include "sprite.h"

static bool32 BytesEqual(const void *first, const void *second, u32 size)
{
    const u8 *a = first;
    const u8 *b = second;
    for (u32 i = 0; i < size; i++)
        if (a[i] != b[i])
            return FALSE;
    return TRUE;
}

void VisualFeatureFixture(void)
{
    struct Sprite *snapshot = Alloc(sizeof(gSprites));
    u8 owned[MAX_SPRITES];
    u32 count = 0;
    u32 result = 0;
    u32 id;

    SetMainCallback2(CB2_Overworld);
    gSpecialVar_Result = 0;
    if (snapshot == NULL)
        return;
    LoadMonIconPalette(SPECIES_PIKACHU);
    while ((id = CreateSpriteUnchecked(&gDummySpriteTemplate, 0, 0, 0)) < MAX_SPRITES)
        owned[count++] = id;
    if (count != 0)
        result |= 1;
    memcpy(snapshot, gSprites, sizeof(gSprites));
    if (CreateMonIcon(SPECIES_PIKACHU, SpriteCB_MonIcon, 32, 32, 0, 0) == MAX_SPRITES
        && BytesEqual(snapshot, gSprites, sizeof(gSprites)))
        result |= 2;
    if (CreateMonIconNoPersonality(SPECIES_PIKACHU, SpriteCB_MonIcon, 32, 32, 0) == MAX_SPRITES
        && BytesEqual(snapshot, gSprites, sizeof(gSprites)))
        result |= 4;
    if (CreateMonIconIsEgg(SPECIES_PIKACHU, SpriteCB_MonIcon, 32, 32, 0, 0, TRUE) == MAX_SPRITES
        && BytesEqual(snapshot, gSprites, sizeof(gSprites)))
        result |= 8;
    if (CreateMonIconNoPersonalityIsEgg(SPECIES_PIKACHU, SpriteCB_MonIcon, 32, 32, 0, TRUE) == MAX_SPRITES
        && BytesEqual(snapshot, gSprites, sizeof(gSprites)))
        result |= 16;
    if (count != 0)
    {
        DestroySprite(&gSprites[owned[--count]]);
        id = CreateMonIcon(SPECIES_PIKACHU, SpriteCB_MonIcon, 32, 32, 0, 0);
        if (id < MAX_SPRITES)
        {
            result |= 32;
            FreeAndDestroyMonIconSprite(&gSprites[id]);
        }
        id = CreateMonIconNoPersonality(SPECIES_PIKACHU, SpriteCB_MonIcon, 32, 32, 0);
        if (id < MAX_SPRITES)
        {
            result |= 64;
            FreeAndDestroyMonIconSprite(&gSprites[id]);
        }
    }
    while (count != 0)
        DestroySprite(&gSprites[owned[--count]]);
    Free(snapshot);
    gSpecialVar_Result = result;
}
