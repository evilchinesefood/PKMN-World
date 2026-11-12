#ifndef GUARD_PLAYER_OUTFIT_H
#define GUARD_PLAYER_OUTFIT_H

#include "global.h"
#include "constants/trainers.h"

#define PLAYER_OUTFIT_STYLE_ORIGINAL 0
#define PLAYER_OUTFIT_STYLE_KANTO 1
#define PLAYER_OUTFIT_STYLE_JOHTO 2
#define PLAYER_OUTFIT_STYLE_HOENN 3
#define PLAYER_OUTFIT_STYLE_COUNT 4
#define PLAYER_OUTFIT_COLOR_COUNT 6
#define PLAYER_OUTFIT_SELECTION_COUNT (PLAYER_OUTFIT_STYLE_COUNT * PLAYER_OUTFIT_COLOR_COUNT)

enum PlayerOutfitPaletteLayout
{
    OUTFIT_PALETTE_OVERWORLD,
    OUTFIT_PALETTE_FRONT,
    OUTFIT_PALETTE_BACK,
};

u16 ValidatePlayerOutfit(u16 selection);
u16 GetEquippedPlayerOutfit(void);
u16 GetOutfitGraphicsId(u16 selection, u16 originalGraphicsId);
u16 GetOriginalOutfitGraphicsId(u16 graphicsId);
enum TrainerPicID GetOutfitTrainerPic(u16 selection, enum Gender gender);
enum TrainerPicID GetEquippedOutfitTrainerPic(void);
u16 GetOutfitPaletteTag(u16 selection, enum Gender gender);
void LoadOutfitPalette(u16 selection, enum Gender gender, enum PlayerOutfitPaletteLayout layout, u16 offset);
void ApplyOutfitColor(u16 selection, enum Gender gender, enum PlayerOutfitPaletteLayout layout, u16 offset);
const u8 *GetOutfitStyleName(u16 selection);
bool8 OpenPlayerOutfitPicker(bool8 intro, void (*callback)(bool8 confirmed));
void ShowPlayerWardrobe(void);
u16 CreateEquippedOutfitTrainerSprite(s16 x, s16 y, u8 paletteSlot, u16 paletteTag);

#endif
