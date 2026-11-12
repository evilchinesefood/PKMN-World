#include "global.h"
#include "player_outfit.h"
#include "palette_swap.h"
#include "event_data.h"
#include "palette.h"
#include "data.h"
#include "sprite.h"
#include "trainer_pokemon_sprites.h"
#include "constants/event_objects.h"
#include "constants/vars.h"

struct OutfitStyle
{
    const u8 *name;
    enum TrainerPicID trainerPics[GENDER_COUNT];
    u16 paletteTags[GENDER_COUNT];
    const u16 *overworldPalettes[GENDER_COUNT];
};

extern const u16 gObjectEventPal_Brendan[];
extern const u16 gObjectEventPal_May[];
extern const u16 gObjectEventPal_KantoBrendan[];
extern const u16 gObjectEventPal_KantoMay[];
extern const u16 gObjectEventPal_JohtoBrendan[];
extern const u16 gObjectEventPal_JohtoMay[];
extern const u16 gObjectEventPal_HoennBrendan[];
extern const u16 gObjectEventPal_HoennMay[];
static const u8 sName_Original[] = _("Original");
static const u8 sName_Kanto[] = _("Kanto Classic");
static const u8 sName_Johto[] = _("Johto Classic");
static const u8 sName_Hoenn[] = _("Hoenn Classic");

static const struct OutfitStyle sOutfitStyles[PLAYER_OUTFIT_STYLE_COUNT] =
{
    {sName_Original, {TRAINER_PIC_BRENDAN, TRAINER_PIC_MAY},
     {OBJ_EVENT_PAL_TAG_BRENDAN, OBJ_EVENT_PAL_TAG_MAY},
     {gObjectEventPal_Brendan, gObjectEventPal_May}},
    {sName_Kanto, {TRAINER_PIC_KANTO_BRENDAN, TRAINER_PIC_KANTO_MAY},
     {OBJ_EVENT_PAL_TAG_KANTO_BRENDAN, OBJ_EVENT_PAL_TAG_KANTO_MAY},
     {gObjectEventPal_KantoBrendan, gObjectEventPal_KantoMay}},
    {sName_Johto, {TRAINER_PIC_JOHTO_BRENDAN, TRAINER_PIC_JOHTO_MAY},
     {OBJ_EVENT_PAL_TAG_JOHTO_BRENDAN, OBJ_EVENT_PAL_TAG_JOHTO_MAY},
     {gObjectEventPal_JohtoBrendan, gObjectEventPal_JohtoMay}},
    {sName_Hoenn, {TRAINER_PIC_HOENN_BRENDAN, TRAINER_PIC_HOENN_MAY},
     {OBJ_EVENT_PAL_TAG_HOENN_BRENDAN, OBJ_EVENT_PAL_TAG_HOENN_MAY},
     {gObjectEventPal_HoennBrendan, gObjectEventPal_HoennMay}},
};

static const u16 sOutfitGraphics[PLAYER_OUTFIT_STYLE_COUNT][GENDER_COUNT][9] =
{
    {
        {OBJ_EVENT_GFX_BRENDAN_NORMAL, OBJ_EVENT_GFX_BRENDAN_MACH_BIKE, OBJ_EVENT_GFX_BRENDAN_ACRO_BIKE, OBJ_EVENT_GFX_BRENDAN_SURFING, OBJ_EVENT_GFX_BRENDAN_FIELD_MOVE, OBJ_EVENT_GFX_BRENDAN_FISHING, OBJ_EVENT_GFX_BRENDAN_WATERING, OBJ_EVENT_GFX_BRENDAN_UNDERWATER, OBJ_EVENT_GFX_BRENDAN_DECORATING},
        {OBJ_EVENT_GFX_MAY_NORMAL, OBJ_EVENT_GFX_MAY_MACH_BIKE, OBJ_EVENT_GFX_MAY_ACRO_BIKE, OBJ_EVENT_GFX_MAY_SURFING, OBJ_EVENT_GFX_MAY_FIELD_MOVE, OBJ_EVENT_GFX_MAY_FISHING, OBJ_EVENT_GFX_MAY_WATERING, OBJ_EVENT_GFX_MAY_UNDERWATER, OBJ_EVENT_GFX_MAY_DECORATING},
    },
    {
        {OBJ_EVENT_GFX_KANTO_BRENDAN_NORMAL, OBJ_EVENT_GFX_KANTO_BRENDAN_MACH_BIKE, OBJ_EVENT_GFX_KANTO_BRENDAN_ACRO_BIKE, OBJ_EVENT_GFX_KANTO_BRENDAN_SURFING, OBJ_EVENT_GFX_KANTO_BRENDAN_FIELD_MOVE, OBJ_EVENT_GFX_KANTO_BRENDAN_FISHING, OBJ_EVENT_GFX_KANTO_BRENDAN_WATERING, OBJ_EVENT_GFX_KANTO_BRENDAN_UNDERWATER, OBJ_EVENT_GFX_KANTO_BRENDAN_DECORATING},
        {OBJ_EVENT_GFX_KANTO_MAY_NORMAL, OBJ_EVENT_GFX_KANTO_MAY_MACH_BIKE, OBJ_EVENT_GFX_KANTO_MAY_ACRO_BIKE, OBJ_EVENT_GFX_KANTO_MAY_SURFING, OBJ_EVENT_GFX_KANTO_MAY_FIELD_MOVE, OBJ_EVENT_GFX_KANTO_MAY_FISHING, OBJ_EVENT_GFX_KANTO_MAY_WATERING, OBJ_EVENT_GFX_KANTO_MAY_UNDERWATER, OBJ_EVENT_GFX_KANTO_MAY_DECORATING},
    },
    {
        {OBJ_EVENT_GFX_JOHTO_BRENDAN_NORMAL, OBJ_EVENT_GFX_JOHTO_BRENDAN_MACH_BIKE, OBJ_EVENT_GFX_JOHTO_BRENDAN_ACRO_BIKE, OBJ_EVENT_GFX_JOHTO_BRENDAN_SURFING, OBJ_EVENT_GFX_JOHTO_BRENDAN_FIELD_MOVE, OBJ_EVENT_GFX_JOHTO_BRENDAN_FISHING, OBJ_EVENT_GFX_JOHTO_BRENDAN_WATERING, OBJ_EVENT_GFX_JOHTO_BRENDAN_UNDERWATER, OBJ_EVENT_GFX_JOHTO_BRENDAN_DECORATING},
        {OBJ_EVENT_GFX_JOHTO_MAY_NORMAL, OBJ_EVENT_GFX_JOHTO_MAY_MACH_BIKE, OBJ_EVENT_GFX_JOHTO_MAY_ACRO_BIKE, OBJ_EVENT_GFX_JOHTO_MAY_SURFING, OBJ_EVENT_GFX_JOHTO_MAY_FIELD_MOVE, OBJ_EVENT_GFX_JOHTO_MAY_FISHING, OBJ_EVENT_GFX_JOHTO_MAY_WATERING, OBJ_EVENT_GFX_JOHTO_MAY_UNDERWATER, OBJ_EVENT_GFX_JOHTO_MAY_DECORATING},
    },
    {
        {OBJ_EVENT_GFX_HOENN_BRENDAN_NORMAL, OBJ_EVENT_GFX_HOENN_BRENDAN_MACH_BIKE, OBJ_EVENT_GFX_HOENN_BRENDAN_ACRO_BIKE, OBJ_EVENT_GFX_HOENN_BRENDAN_SURFING, OBJ_EVENT_GFX_HOENN_BRENDAN_FIELD_MOVE, OBJ_EVENT_GFX_HOENN_BRENDAN_FISHING, OBJ_EVENT_GFX_HOENN_BRENDAN_WATERING, OBJ_EVENT_GFX_HOENN_BRENDAN_UNDERWATER, OBJ_EVENT_GFX_HOENN_BRENDAN_DECORATING},
        {OBJ_EVENT_GFX_HOENN_MAY_NORMAL, OBJ_EVENT_GFX_HOENN_MAY_MACH_BIKE, OBJ_EVENT_GFX_HOENN_MAY_ACRO_BIKE, OBJ_EVENT_GFX_HOENN_MAY_SURFING, OBJ_EVENT_GFX_HOENN_MAY_FIELD_MOVE, OBJ_EVENT_GFX_HOENN_MAY_FISHING, OBJ_EVENT_GFX_HOENN_MAY_WATERING, OBJ_EVENT_GFX_HOENN_MAY_UNDERWATER, OBJ_EVENT_GFX_HOENN_MAY_DECORATING},
    },
};

u16 ValidatePlayerOutfit(u16 selection)
{
    u16 style = selection / PLAYER_OUTFIT_COLOR_COUNT;
    if (style >= ARRAY_COUNT(sOutfitStyles) || sOutfitStyles[style].name == NULL)
        return 0;
    return selection;
}

u16 GetEquippedPlayerOutfit(void)
{
    return ValidatePlayerOutfit(VarGet(VAR_PLAYER_PALETTE));
}

const u8 *GetOutfitStyleName(u16 selection)
{
    return sOutfitStyles[ValidatePlayerOutfit(selection) / PLAYER_OUTFIT_COLOR_COUNT].name;
}

u16 GetOriginalOutfitGraphicsId(u16 graphicsId)
{
    u32 style, gender, pose;
    for (style = 1; style < PLAYER_OUTFIT_STYLE_COUNT; style++)
        for (gender = 0; gender < GENDER_COUNT; gender++)
            for (pose = 0; pose < ARRAY_COUNT(sOutfitGraphics[0][0]); pose++)
                if (sOutfitGraphics[style][gender][pose] == graphicsId)
                    return sOutfitGraphics[0][gender][pose];
    return graphicsId;
}

u16 GetOutfitGraphicsId(u16 selection, u16 originalGraphicsId)
{
    u32 gender, pose;
    u32 style = ValidatePlayerOutfit(selection) / PLAYER_OUTFIT_COLOR_COUNT;
    originalGraphicsId = GetOriginalOutfitGraphicsId(originalGraphicsId);
    for (gender = 0; gender < GENDER_COUNT; gender++)
        for (pose = 0; pose < ARRAY_COUNT(sOutfitGraphics[0][0]); pose++)
            if (sOutfitGraphics[0][gender][pose] == originalGraphicsId)
                return sOutfitGraphics[style][gender][pose];
    return originalGraphicsId;
}

enum TrainerPicID GetOutfitTrainerPic(u16 selection, enum Gender gender)
{
    return sOutfitStyles[ValidatePlayerOutfit(selection) / PLAYER_OUTFIT_COLOR_COUNT].trainerPics[gender == FEMALE];
}

enum TrainerPicID GetEquippedOutfitTrainerPic(void)
{
    return GetOutfitTrainerPic(GetEquippedPlayerOutfit(), gSaveBlock2Ptr->playerGender);
}

u16 GetOutfitPaletteTag(u16 selection, enum Gender gender)
{
    return sOutfitStyles[ValidatePlayerOutfit(selection) / PLAYER_OUTFIT_COLOR_COUNT].paletteTags[gender == FEMALE];
}

void LoadOutfitPalette(u16 selection, enum Gender gender, enum PlayerOutfitPaletteLayout layout, u16 offset)
{
    const struct OutfitStyle *style;
    selection = ValidatePlayerOutfit(selection);
    gender = gender == FEMALE;
    style = &sOutfitStyles[selection / PLAYER_OUTFIT_COLOR_COUNT];
    if (layout == OUTFIT_PALETTE_OVERWORLD)
        LoadPalette(style->overworldPalettes[gender], offset, PLTT_SIZE_4BPP);
    else if (layout == OUTFIT_PALETTE_FRONT)
        LoadPalette(GetTrainerFrontPicPalette(style->trainerPics[gender]), offset, PLTT_SIZE_4BPP);
    else
        LoadPalette(GetTrainerBackPicPalette(style->trainerPics[gender]), offset, PLTT_SIZE_4BPP);
    ApplyOutfitColor(selection, gender, layout, offset);
}

u16 CreateEquippedOutfitTrainerSprite(s16 x, s16 y, u8 paletteSlot, u16 paletteTag)
{
    u16 spriteId = CreateTrainerPicSprite(GetEquippedOutfitTrainerPic(), TRUE, x, y, paletteSlot, paletteTag);
    if (spriteId < MAX_SPRITES)
        LoadOutfitPalette(GetEquippedPlayerOutfit(), gSaveBlock2Ptr->playerGender, OUTFIT_PALETTE_FRONT, OBJ_PLTT_ID(gSprites[spriteId].oam.paletteNum));
    return spriteId;
}
