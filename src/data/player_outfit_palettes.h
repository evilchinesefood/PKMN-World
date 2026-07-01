#ifndef GUARD_DATA_PLAYER_OUTFIT_PALETTES_H
#define GUARD_DATA_PLAYER_OUTFIT_PALETTES_H

// Player-outfit clothing palettes. Each Apply* in palette_swap.c overwrites ONLY
// the clothing indices listed here, leaving constants (skin, hair, cap-front
// white, outline) untouched. RGB() components are 0-31. Indexed by
// PLAYER_OUTFIT_*. The RED rows are vanilla colors for reference only — Apply*
// early-returns for RED, so they are never read.
//
// PKMN-World: regenerated for Brendan (male, canonical) via
// /home/evilc/python/OutfitPalettes.py. Garment ramps: blue 5-8 (main body ->
// jacket), red 12-13 (cap emblem -> pants shade), green 10-11 (bag -> accent).
// The OW/Front/Back palettes share the same index roles (blue 5-8, green 10-11,
// red 12-13, skin 1-4, white 9/14, outline 15), so one clothing layout covers all.
//
// PLAYTEST — clothing indices are BEST-GUESS from the palette; verify with the
// visual companion (.plans/2026-05-27-player-outfit-palettes-visual-companion.html)
// and in-game. May's palette DIVERGES from Brendan's at the shared indices
// (index 7/8 = May hair, 5/6 = May shorts/gray), so the swap is Brendan-accurate;
// May needs its own verification / possibly a separate table.
// The Portrait rows still target the Red 32c Oak-intro palette (no Brendan/May
// intro portrait art exists yet) — verify once that art is converted.

// Overworld sprite (16c): clothing indices (jacket dark->light, pants dark->light, accent)
static const u8 sOWClothingIdx[] = {8, 7, 6, 5, 13, 12, 11, 10};
static const u16 sOutfitOW[NUM_PLAYER_OUTFITS][8] = {
    [PLAYER_OUTFIT_RED] = {RGB( 2,  4,  7), RGB( 3,  5, 10), RGB( 5,  7, 12), RGB( 7,  9, 15), RGB(24,  8,  8), RGB(31, 12, 11), RGB( 9, 18, 10), RGB(14, 25, 14)}, // vanilla (unused; Red early-returns)
    [PLAYER_OUTFIT_BLUE] = {RGB( 2,  4, 13), RGB( 6,  9, 19), RGB( 9, 14, 25), RGB(13, 19, 31), RGB( 2,  3, 10), RGB( 7, 11, 22), RGB(31, 25,  7), RGB(31, 25,  7)},
    [PLAYER_OUTFIT_GREEN] = {RGB( 1,  5,  1), RGB( 4, 10,  4), RGB( 8, 16,  6), RGB(11, 21,  9), RGB( 8,  8,  3), RGB(17, 16,  9), RGB(24, 17,  5), RGB(24, 17,  5)},
    [PLAYER_OUTFIT_PURPLE] = {RGB( 6,  2, 11), RGB(11,  6, 17), RGB(17,  9, 23), RGB(22, 13, 29), RGB( 5,  2,  9), RGB(13,  8, 18), RGB(25, 25, 28), RGB(25, 25, 28)},
    [PLAYER_OUTFIT_BLACK] = {RGB( 2,  2,  3), RGB( 6,  6,  7), RGB( 9,  9, 11), RGB(13, 13, 15), RGB( 2,  2,  3), RGB( 9,  9, 11), RGB(31, 25,  7), RGB(31, 25,  7)},
    [PLAYER_OUTFIT_PINK] = {RGB(13,  3,  7), RGB(19,  8, 12), RGB(25, 13, 18), RGB(31, 18, 23), RGB(12,  5,  9), RGB(24, 12, 16), RGB(31, 30, 23), RGB(31, 30, 23)},
};

// Trainer-card / front pic (16c): clothing indices (jacket dark->light, pants dark->light, accent)
static const u8 sFrontPicClothingIdx[] = {8, 7, 6, 5, 13, 12, 11, 10};
static const u16 sOutfitFrontPic[NUM_PLAYER_OUTFITS][8] = {
    [PLAYER_OUTFIT_RED] = {RGB( 3,  5, 10), RGB( 6,  8, 13), RGB( 9, 11, 16), RGB(12, 15, 19), RGB(24,  8,  8), RGB(31, 12, 11), RGB(12, 19, 11), RGB(17, 27, 14)}, // vanilla (unused; Red early-returns)
    [PLAYER_OUTFIT_BLUE] = {RGB( 2,  4, 13), RGB( 6,  9, 19), RGB( 9, 14, 25), RGB(13, 19, 31), RGB( 2,  3, 10), RGB( 7, 11, 22), RGB(31, 25,  7), RGB(31, 25,  7)},
    [PLAYER_OUTFIT_GREEN] = {RGB( 1,  5,  1), RGB( 4, 10,  4), RGB( 8, 16,  6), RGB(11, 21,  9), RGB( 8,  8,  3), RGB(17, 16,  9), RGB(24, 17,  5), RGB(24, 17,  5)},
    [PLAYER_OUTFIT_PURPLE] = {RGB( 6,  2, 11), RGB(11,  6, 17), RGB(17,  9, 23), RGB(22, 13, 29), RGB( 5,  2,  9), RGB(13,  8, 18), RGB(25, 25, 28), RGB(25, 25, 28)},
    [PLAYER_OUTFIT_BLACK] = {RGB( 2,  2,  3), RGB( 6,  6,  7), RGB( 9,  9, 11), RGB(13, 13, 15), RGB( 2,  2,  3), RGB( 9,  9, 11), RGB(31, 25,  7), RGB(31, 25,  7)},
    [PLAYER_OUTFIT_PINK] = {RGB(13,  3,  7), RGB(19,  8, 12), RGB(25, 13, 18), RGB(31, 18, 23), RGB(12,  5,  9), RGB(24, 12, 16), RGB(31, 30, 23), RGB(31, 30, 23)},
};

// Battle back-pic (16c): clothing indices (jacket dark->light, pants dark->light, accent)
static const u8 sBackPicClothingIdx[] = {8, 7, 6, 5, 13, 12, 11, 10};
static const u16 sOutfitBackPic[NUM_PLAYER_OUTFITS][8] = {
    [PLAYER_OUTFIT_RED] = {RGB( 3,  5, 10), RGB( 6,  8, 13), RGB( 9, 11, 16), RGB(12, 15, 19), RGB(24,  8,  8), RGB(31, 12, 11), RGB(12, 19, 11), RGB(17, 27, 14)}, // vanilla (unused; Red early-returns)
    [PLAYER_OUTFIT_BLUE] = {RGB( 2,  4, 13), RGB( 6,  9, 19), RGB( 9, 14, 25), RGB(13, 19, 31), RGB( 2,  3, 10), RGB( 7, 11, 22), RGB(31, 25,  7), RGB(31, 25,  7)},
    [PLAYER_OUTFIT_GREEN] = {RGB( 1,  5,  1), RGB( 4, 10,  4), RGB( 8, 16,  6), RGB(11, 21,  9), RGB( 8,  8,  3), RGB(17, 16,  9), RGB(24, 17,  5), RGB(24, 17,  5)},
    [PLAYER_OUTFIT_PURPLE] = {RGB( 6,  2, 11), RGB(11,  6, 17), RGB(17,  9, 23), RGB(22, 13, 29), RGB( 5,  2,  9), RGB(13,  8, 18), RGB(25, 25, 28), RGB(25, 25, 28)},
    [PLAYER_OUTFIT_BLACK] = {RGB( 2,  2,  3), RGB( 6,  6,  7), RGB( 9,  9, 11), RGB(13, 13, 15), RGB( 2,  2,  3), RGB( 9,  9, 11), RGB(31, 25,  7), RGB(31, 25,  7)},
    [PLAYER_OUTFIT_PINK] = {RGB(13,  3,  7), RGB(19,  8, 12), RGB(25, 13, 18), RGB(31, 18, 23), RGB(12,  5,  9), RGB(24, 12, 16), RGB(31, 30, 23), RGB(31, 30, 23)},
};

// Oak intro portrait (32c): clothing indices (jacket dark->light, pants dark->light)
static const u8 sPortraitClothingIdx[] = {31, 30, 29, 28, 27, 21, 20, 19, 18, 17};
static const u16 sOutfitPortrait[NUM_PLAYER_OUTFITS][10] = {
    [PLAYER_OUTFIT_RED] = {RGB(12,  3,  2), RGB(17,  7,  6), RGB(20, 10,  9), RGB(23, 13, 12), RGB(26, 16, 15), RGB( 4,  8, 11), RGB( 6, 11, 14), RGB(10, 16, 19), RGB(13, 19, 22), RGB(16, 23, 26)}, // vanilla (unused; Red early-returns)
    [PLAYER_OUTFIT_BLUE] = {RGB( 2,  4, 13), RGB( 5,  8, 18), RGB( 8, 12, 22), RGB(10, 15, 26), RGB(13, 19, 31), RGB( 2,  3, 10), RGB( 3,  5, 13), RGB( 4,  7, 16), RGB( 6,  9, 19), RGB( 7, 11, 22)},
    [PLAYER_OUTFIT_GREEN] = {RGB( 1,  5,  1), RGB( 4,  9,  3), RGB( 6, 13,  5), RGB( 8, 17,  7), RGB(11, 21,  9), RGB( 8,  8,  3), RGB(10, 10,  4), RGB(12, 12,  6), RGB(15, 14,  8), RGB(17, 16,  9)},
    [PLAYER_OUTFIT_PURPLE] = {RGB( 6,  2, 11), RGB(10,  5, 16), RGB(14,  8, 20), RGB(18, 10, 24), RGB(22, 13, 29), RGB( 5,  2,  9), RGB( 7,  4, 11), RGB( 9,  5, 14), RGB(11,  6, 16), RGB(13,  8, 18)},
    [PLAYER_OUTFIT_BLACK] = {RGB( 2,  2,  3), RGB( 5,  5,  6), RGB( 8,  8,  9), RGB(10, 10, 12), RGB(13, 13, 15), RGB( 2,  2,  3), RGB( 4,  4,  5), RGB( 6,  6,  7), RGB( 7,  7,  9), RGB( 9,  9, 11)},
    [PLAYER_OUTFIT_PINK] = {RGB(13,  3,  7), RGB(18,  7, 11), RGB(22, 10, 15), RGB(26, 14, 19), RGB(31, 18, 23), RGB(12,  5,  9), RGB(15,  7, 11), RGB(18,  8, 12), RGB(21, 10, 14), RGB(24, 12, 16)},
};

#endif // GUARD_DATA_PLAYER_OUTFIT_PALETTES_H
