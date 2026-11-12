#include "global.h"
#include "palette.h"
#include "event_data.h"
#include "constants/rgb.h"
#include "constants/vars.h"
#include "palette_swap.h"
#include "player_outfit.h"
#include "data/player_outfit_palettes.h"

u8 GetPlayerOutfit(void)
{
    return GetEquippedPlayerOutfit() % PLAYER_OUTFIT_COLOR_COUNT;
}

// Overwrite only the clothing indices with the outfit's authored colors,
// leaving constants (skin, hair, cap-front white, outline — incl. the
// gender-specific portrait skin) untouched. Idempotent: re-applying the same
// authored colors is stable, so any path that reloads the player palette
// (return-to-field, battle send-out) lands correctly.
//
// Match LoadPalette by writing both buffers. The normal weather/time palette
// refresh paths and the dynamic reflection filters consume the authored source.
static void WriteOutfitClothing(const u16 *colors, const u8 *indices, u8 count, u16 plttOffset)
{
    u8 i;

    for (i = 0; i < count; i++)
    {
        u16 idx = plttOffset + indices[i];
        // Out-of-range index = caller bug (data-table mismatch) — silently
        // skip rather than trash adjacent palette slots.
        if (idx >= PLTT_BUFFER_SIZE)
            continue;
        gPlttBufferUnfaded[idx] = colors[i];
        gPlttBufferFaded[idx] = colors[i];
    }
}

void ApplyPlayerPaletteSwap(u16 plttOffset)
{
    ApplyOutfitColor(GetEquippedPlayerOutfit(), gSaveBlock2Ptr->playerGender, OUTFIT_PALETTE_OVERWORLD, plttOffset);
}

void ApplyPlayerPaletteSwapPortrait(u16 plttOffset)
{
    u8 outfit = GetPlayerOutfit();

    if (outfit == PLAYER_OUTFIT_RED)
        return;
    WriteOutfitClothing(sOutfitPortrait[outfit], sPortraitClothingIdx, ARRAY_COUNT(sPortraitClothingIdx), plttOffset);
}

void ApplyPlayerPaletteSwapFrontPic(u16 plttOffset)
{
    ApplyOutfitColor(GetEquippedPlayerOutfit(), gSaveBlock2Ptr->playerGender, OUTFIT_PALETTE_FRONT, plttOffset);
}

void ApplyPlayerPaletteSwapBackPic(u16 plttOffset)
{
    ApplyOutfitColor(GetEquippedPlayerOutfit(), gSaveBlock2Ptr->playerGender, OUTFIT_PALETTE_BACK, plttOffset);
}

// Legacy reflection-slot path, retained for callers of
// LoadPlayerObjectReflectionPalette. Live water reflections instead derive
// their filtered colors from the current OW palette in field_effect_helpers.c.
// The legacy slot is patched from a pre-tinted "reflection" palette set that
// only carries RED. Mirror the outfit's OW clothing colors over the reflection
// slot so non-RED outfits read correctly in water reflections (trades the subtle
// blue cast for outfit-accurate color, matching the reference behavior).
void ApplyPlayerPaletteSwapReflection(u16 plttOffset)
{
    u8 outfit = GetPlayerOutfit();

    if (outfit == PLAYER_OUTFIT_RED)
        return;
    if (gSaveBlock2Ptr->playerGender == FEMALE)
        WriteOutfitClothing(sOutfitOW_Female[outfit], sOWClothingIdx_Female, ARRAY_COUNT(sOWClothingIdx_Female), plttOffset);
    else
        WriteOutfitClothing(sOutfitOW_Male[outfit], sOWClothingIdx_Male, ARRAY_COUNT(sOWClothingIdx_Male), plttOffset);
}

void ApplyOutfitColor(u16 selection, enum Gender gender, enum PlayerOutfitPaletteLayout layout, u16 offset)
{
    static const u8 regionalMaleTopIndices[] = {13, 12};
    u8 color = ValidatePlayerOutfit(selection) % PLAYER_OUTFIT_COLOR_COUNT;
    if (color == PLAYER_OUTFIT_RED)
        return;
    if (layout == OUTFIT_PALETTE_OVERWORLD)
    {
        if (gender == FEMALE)
            WriteOutfitClothing(sOutfitOW_Female[color], sOWClothingIdx_Female, ARRAY_COUNT(sOWClothingIdx_Female), offset);
        else
            WriteOutfitClothing(sOutfitOW_Male[color], sOWClothingIdx_Male, ARRAY_COUNT(sOWClothingIdx_Male), offset);
    }
    else if (layout == OUTFIT_PALETTE_FRONT)
    {
        if (gender == FEMALE)
            WriteOutfitClothing(sOutfitFrontPic_Female[color], sFrontPicClothingIdx_Female, ARRAY_COUNT(sFrontPicClothingIdx_Female), offset);
        else
            WriteOutfitClothing(sOutfitFrontPic_Male[color], sFrontPicClothingIdx_Male, ARRAY_COUNT(sFrontPicClothingIdx_Male), offset);
    }
    else
    {
        if (gender == FEMALE)
            WriteOutfitClothing(sOutfitBackPic_Female[color], sBackPicClothingIdx_Female, ARRAY_COUNT(sBackPicClothingIdx_Female), offset);
        else
            WriteOutfitClothing(sOutfitBackPic_Male[color], sBackPicClothingIdx_Male, ARRAY_COUNT(sBackPicClothingIdx_Male), offset);
    }
    if (ValidatePlayerOutfit(selection) >= PLAYER_OUTFIT_COLOR_COUNT && gender == MALE)
    {
        if (layout == OUTFIT_PALETTE_FRONT)
            WriteOutfitClothing(sOutfitFrontPic_Male[color], regionalMaleTopIndices, ARRAY_COUNT(regionalMaleTopIndices), offset);
        else if (layout == OUTFIT_PALETTE_BACK)
            WriteOutfitClothing(sOutfitBackPic_Male[color], regionalMaleTopIndices, ARRAY_COUNT(regionalMaleTopIndices), offset);
    }

}
