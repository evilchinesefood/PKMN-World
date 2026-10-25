// Disposable audit ROM only; never linked into production.
#include "global.h"
#include "main.h"
#include "overworld.h"
#include "event_data.h"
#include "pokemon.h"
#include "field_screen_effect.h"
#include "constants/species.h"
#include "constants/moves.h"
#include "constants/flags.h"
#include "constants/vars.h"
#include "item.h"
#include "sprite.h"
#include "field_effect_helpers.h"
#include "field_weather.h"
#include "constants/field_weather.h"
#include "constants/metatile_behaviors.h"
#include "constants/items.h"
static void CheckReflectionAllocation(u32 kind)
{
    struct ObjectEvent *obj = &gObjectEvents[gPlayerAvatar.objectEventId];
    struct Sprite *mainSprite = &gSprites[obj->spriteId];
    u16 colors[16] = {0};
    u16 tags[16];
    bool8 used[MAX_SPRITES];
    u32 count = 0;
    u8 oldState = gWeatherPtr->palProcessingState;
    u8 oldPrevious = obj->previousMetatileBehavior;
    u8 oldCurrent = obj->currentMetatileBehavior;
    bool8 oldReflection = obj->hasReflection;
    u8 reflectionId = MAX_SPRITES;
    for (u32 i = 0; i < 16; i++)
    {
        struct SpritePalette pal = {.data = colors, .tag = 0x5000 + i};
        if (LoadSpritePalette(&pal) == 0xFF)
            break;
        tags[count++] = pal.tag;
    }
    for (u32 i = 0; i < MAX_SPRITES; i++)
        used[i] = gSprites[i].inUse;
    obj->previousMetatileBehavior = kind == 2 ? MB_BRIDGE_OVER_POND_HIGH : MB_NORMAL;
    obj->currentMetatileBehavior = MB_NORMAL;
    gWeatherPtr->palProcessingState = WEATHER_PAL_STATE_SCREEN_FADING_OUT;
    SetUpReflection(obj, mainSprite, kind == 1);
    gSpecialVar_0x8005 = FALSE;
    for (u32 i = 0; i < MAX_SPRITES; i++)
    {
        if (!used[i] && gSprites[i].inUse)
        {
            gSpecialVar_0x8005 = gSprites[i].oam.paletteNum == mainSprite->oam.paletteNum;
            reflectionId = i;
        }
    }
    for (u32 i = 0; i < count; i++)
        FreeSpritePaletteByTag(tags[i]);
    gSpecialVar_0x8006 = count;
    gSpecialVar_0x8007 = FALSE;
    if (reflectionId != MAX_SPRITES)
    {
        struct Sprite *reflection = &gSprites[reflectionId];
        obj->hasReflection = TRUE;
        reflection->callback(reflection);
        gSpecialVar_0x8007 = reflection->oam.paletteNum != mainSprite->oam.paletteNum;
        u16 tag = GetSpritePaletteTagByPaletteNum(reflection->oam.paletteNum);
        if (kind == 2)
            gSpecialVar_0x8007 &= tag == 0x3010;
        reflection->inUse = FALSE;
        FreeSpritePaletteByTag(tag);
    }
    gWeatherPtr->palProcessingState = oldState;
    obj->previousMetatileBehavior = oldPrevious;
    obj->currentMetatileBehavior = oldCurrent;
    obj->hasReflection = oldReflection;
}
void VisualFeatureFixture(void)
{
    SetMainCallback2(CB2_Overworld);
    switch (gSpecialVar_0x8004)
    {
    case 0:
        ZeroPlayerPartyMons();
        CreateMonWithIVs(&gParties[B_TRAINER_PLAYER][0], gSpecialVar_0x8005 ? gSpecialVar_0x8005 : SPECIES_MEWTWO, 100, 0x12345678, OTID_STRUCT_PLAYER_ID, 31);
        SetMonMoveSlot(&gParties[B_TRAINER_PLAYER][0], MOVE_PSYCHIC, 0);
        SetMonMoveSlot(&gParties[B_TRAINER_PLAYER][0], MOVE_AURA_SPHERE, 1);
        CalculatePlayerPartyCount();
        break;
    case 1:
        SetWarpDestination(gSpecialVar_0x8005, gSpecialVar_0x8006, -1, gSpecialVar_0x8007, gSpecialVar_0x8008);
        DoWarp();
        break;
    case 8:
        CheckReflectionAllocation(gSpecialVar_0x8005);
        break;
    case 7:
        SetWarpDestination(gSpecialVar_0x8005, gSpecialVar_0x8006, gSpecialVar_0x8007, -1, -1);
        DoWarp();
        break;
    case 3:
        FlagSet(gSpecialVar_0x8005);
        break;
    case 5:
        FlagClear(gSpecialVar_0x8005);
        break;
    case 6:
        AddBagItem(ITEM_SECRET_POTION, 1);
        break;
    case 4:
        VarSet(gSpecialVar_0x8005, gSpecialVar_0x8006);
        break;
    }
}
