#ifndef GUARD_PALETTE_SWAP_H
#define GUARD_PALETTE_SWAP_H

#include "global.h"

#define PLAYER_OUTFIT_RED    0
#define PLAYER_OUTFIT_BLUE   1
#define PLAYER_OUTFIT_GREEN  2
#define PLAYER_OUTFIT_PURPLE 3
#define PLAYER_OUTFIT_BLACK  4
#define PLAYER_OUTFIT_PINK   5
#define NUM_PLAYER_OUTFITS   6

void ApplyPlayerPaletteSwap(u16 plttOffset);
void ApplyPlayerPaletteSwapPortrait(u16 plttOffset);
void ApplyPlayerPaletteSwapFrontPic(u16 plttOffset);
void ApplyPlayerPaletteSwapBackPic(u16 plttOffset);
void ApplyPlayerPaletteSwapReflection(u16 plttOffset);
u8 GetPlayerOutfit(void);

#endif // GUARD_PALETTE_SWAP_H
