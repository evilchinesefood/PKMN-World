#ifndef GUARD_WORLD_MENU_THEME_H
#define GUARD_WORLD_MENU_THEME_H

// Reserves BG3, screen block 28 and palette 3. Text headers use palette 12.
void WorldMenu_InitBackground(u8 charBaseIndex);
void WorldMenu_UpdateBackground(void);
void WorldMenu_LoadTextPalette(u8 palette);
void WorldMenu_LoadSelectedPalette(u8 palette);
void WorldMenu_DrawHeader(u8 window, const u8 *title);
void WorldMenu_RoundWindowTopCorners(u8 window);

#endif
