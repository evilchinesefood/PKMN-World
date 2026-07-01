#include "global.h"
#include "palette.h"
#include "event_data.h"
#include "constants/rgb.h"
#include "constants/vars.h"
#include "palette_swap.h"
#include "data/player_outfit_palettes.h"

u8 GetPlayerOutfit(void)
{
    u16 val = VarGet(VAR_PLAYER_PALETTE);
    if (val >= NUM_PLAYER_OUTFITS)
        return PLAYER_OUTFIT_RED;
    return (u8)val;
}

// Overwrite only the clothing indices with the outfit's authored colors,
// leaving constants (skin, hair, cap-front white, outline — incl. the
// gender-specific portrait skin) untouched. Idempotent: re-applying the same
// authored colors is stable, so any path that reloads the player palette
// (return-to-field, battle send-out) lands correctly.
//
// PKMN-World port note: the target has no day/night engine, so instead of the
// reference's DayNight_PaletteFadedWrite we write BOTH palette buffers directly
// (unfaded + faded) — palette.c mirrors these two buffers, and a direct write to
// both is what a plain LoadPalette does under the hood.
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
    u8 outfit = GetPlayerOutfit();

    if (outfit == PLAYER_OUTFIT_RED)
        return;
    if (gSaveBlock2Ptr->playerGender == FEMALE)
        WriteOutfitClothing(sOutfitOW_Female[outfit], sOWClothingIdx_Female, ARRAY_COUNT(sOWClothingIdx_Female), plttOffset);
    else
        WriteOutfitClothing(sOutfitOW_Male[outfit], sOWClothingIdx_Male, ARRAY_COUNT(sOWClothingIdx_Male), plttOffset);
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
    u8 outfit = GetPlayerOutfit();

    if (outfit == PLAYER_OUTFIT_RED)
        return;
    if (gSaveBlock2Ptr->playerGender == FEMALE)
        WriteOutfitClothing(sOutfitFrontPic_Female[outfit], sFrontPicClothingIdx_Female, ARRAY_COUNT(sFrontPicClothingIdx_Female), plttOffset);
    else
        WriteOutfitClothing(sOutfitFrontPic_Male[outfit], sFrontPicClothingIdx_Male, ARRAY_COUNT(sFrontPicClothingIdx_Male), plttOffset);
}

void ApplyPlayerPaletteSwapBackPic(u16 plttOffset)
{
    u8 outfit = GetPlayerOutfit();

    if (outfit == PLAYER_OUTFIT_RED)
        return;
    if (gSaveBlock2Ptr->playerGender == FEMALE)
        WriteOutfitClothing(sOutfitBackPic_Female[outfit], sBackPicClothingIdx_Female, ARRAY_COUNT(sBackPicClothingIdx_Female), plttOffset);
    else
        WriteOutfitClothing(sOutfitBackPic_Male[outfit], sBackPicClothingIdx_Male, ARRAY_COUNT(sBackPicClothingIdx_Male), plttOffset);
}

// The reflection slot is patched from a pre-tinted "reflection" palette set that
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
