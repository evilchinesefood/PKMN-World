#ifndef GUARD_DATA_PLAYER_OUTFIT_PALETTES_H
#define GUARD_DATA_PLAYER_OUTFIT_PALETTES_H

// Hand-authored player-outfit clothing palettes (user-approved 2026-05-27).
// Each Apply* in palette_swap.c overwrites ONLY the clothing indices listed
// here, leaving constants (skin, hair, cap-front white, outline — incl. the
// gender-specific Oak-portrait skin) untouched. RGB() components are 0-31.
// Indexed by PLAYER_OUTFIT_*. The RED rows are vanilla colors for reference
// only — Apply* early-returns for RED, so they are never read.
//
// NOTE (PKMN-World port): these tables were authored for the FireRed Red/Leaf
// sprites. This target's player is Brendan/May. The clothing INDICES below may
// not line up with the Brendan/May palettes, so colors are a PLACEHOLDER until
// regenerated. Regenerate for Brendan/May via /home/evilc/python/OutfitPalettes.py
// (update its VANILLA base dict to brendan.pal/may.pal + portrait, then paste here).

// Overworld sprite (16c): jacket dark->light, pants dark->light, accent
static const u8 sOWClothingIdx[] = {8, 4, 12, 11, 6, 5, 7};
static const u16 sOutfitOW[NUM_PLAYER_OUTFITS][7] = {
    [PLAYER_OUTFIT_RED]    = {RGB(13,  5,  5), RGB(15,  8,  8), RGB(24,  7,  7), RGB(31, 13,  9), RGB( 7,  7, 15), RGB( 8,  8, 26), RGB(14, 20, 24)}, // vanilla (unused)
    [PLAYER_OUTFIT_BLUE]   = {RGB( 2,  4, 13), RGB( 6,  9, 19), RGB( 9, 14, 25), RGB(13, 19, 31), RGB( 2,  3, 10), RGB( 7, 11, 22), RGB(31, 25,  7)},
    [PLAYER_OUTFIT_GREEN]  = {RGB( 1,  5,  1), RGB( 4, 10,  4), RGB( 8, 16,  6), RGB(11, 21,  9), RGB( 8,  8,  3), RGB(17, 16,  9), RGB(24, 17,  5)},
    [PLAYER_OUTFIT_PURPLE] = {RGB( 6,  2, 11), RGB(11,  6, 17), RGB(17,  9, 23), RGB(22, 13, 29), RGB( 5,  2,  9), RGB(13,  8, 18), RGB(25, 25, 28)},
    [PLAYER_OUTFIT_BLACK]  = {RGB( 2,  2,  3), RGB( 6,  6,  7), RGB( 9,  9, 11), RGB(13, 13, 15), RGB( 2,  2,  3), RGB( 9,  9, 11), RGB(31, 25,  7)},
    [PLAYER_OUTFIT_PINK]   = {RGB(13,  3,  7), RGB(19,  8, 12), RGB(25, 13, 18), RGB(31, 18, 23), RGB(12,  5,  9), RGB(24, 12, 16), RGB(31, 30, 23)},
};

// Trainer-card / front pic (16c): jacket dark->light, pants dark->light
static const u8 sFrontPicClothingIdx[] = {13, 12, 8, 7, 6, 5};
static const u16 sOutfitFrontPic[NUM_PLAYER_OUTFITS][6] = {
    [PLAYER_OUTFIT_RED]    = {RGB(24,  8,  8), RGB(31, 12, 11), RGB( 3,  5, 10), RGB( 6, 13, 17), RGB(10, 17, 22), RGB(15, 23, 27)}, // vanilla (unused)
    [PLAYER_OUTFIT_BLUE]   = {RGB( 2,  4, 13), RGB(13, 19, 31), RGB( 2,  3, 10), RGB( 4,  6, 14), RGB( 5,  8, 18), RGB( 7, 11, 22)},
    [PLAYER_OUTFIT_GREEN]  = {RGB( 1,  5,  1), RGB(11, 21,  9), RGB( 8,  8,  3), RGB(11, 11,  5), RGB(14, 13,  7), RGB(17, 16,  9)},
    [PLAYER_OUTFIT_PURPLE] = {RGB( 6,  2, 11), RGB(22, 13, 29), RGB( 5,  2,  9), RGB( 8,  4, 12), RGB(10,  6, 15), RGB(13,  8, 18)},
    [PLAYER_OUTFIT_BLACK]  = {RGB( 2,  2,  3), RGB(13, 13, 15), RGB( 2,  2,  3), RGB( 4,  4,  6), RGB( 7,  7,  8), RGB( 9,  9, 11)},
    [PLAYER_OUTFIT_PINK]   = {RGB(13,  3,  7), RGB(31, 18, 23), RGB(12,  5,  9), RGB(16,  7, 11), RGB(20, 10, 14), RGB(24, 12, 16)},
};

// Battle back-pic (16c): jacket dark->light, pants dark->light, accent
static const u8 sBackPicClothingIdx[] = {12, 11, 6, 5, 7};
static const u16 sOutfitBackPic[NUM_PLAYER_OUTFITS][5] = {
    [PLAYER_OUTFIT_RED]    = {RGB(25, 12,  9), RGB(31, 14, 11), RGB( 7,  7, 15), RGB(11, 12, 23), RGB(14, 20, 24)}, // vanilla (unused)
    [PLAYER_OUTFIT_BLUE]   = {RGB( 2,  4, 13), RGB(13, 19, 31), RGB( 2,  3, 10), RGB( 7, 11, 22), RGB(31, 25,  7)},
    [PLAYER_OUTFIT_GREEN]  = {RGB( 1,  5,  1), RGB(11, 21,  9), RGB( 8,  8,  3), RGB(17, 16,  9), RGB(24, 17,  5)},
    [PLAYER_OUTFIT_PURPLE] = {RGB( 6,  2, 11), RGB(22, 13, 29), RGB( 5,  2,  9), RGB(13,  8, 18), RGB(25, 25, 28)},
    [PLAYER_OUTFIT_BLACK]  = {RGB( 2,  2,  3), RGB(13, 13, 15), RGB( 2,  2,  3), RGB( 9,  9, 11), RGB(31, 25,  7)},
    [PLAYER_OUTFIT_PINK]   = {RGB(13,  3,  7), RGB(31, 18, 23), RGB(12,  5,  9), RGB(24, 12, 16), RGB(31, 30, 23)},
};

// Oak intro portrait (32c): jacket dark->light, pants dark->light
static const u8 sPortraitClothingIdx[] = {31, 30, 29, 28, 27, 21, 20, 19, 18, 17};
static const u16 sOutfitPortrait[NUM_PLAYER_OUTFITS][10] = {
    [PLAYER_OUTFIT_RED]    = {RGB(12,  3,  2), RGB(17,  7,  6), RGB(20, 10,  9), RGB(23, 13, 12), RGB(26, 16, 15), RGB( 4,  8, 11), RGB( 6, 11, 14), RGB(10, 16, 19), RGB(13, 19, 22), RGB(16, 23, 26)}, // vanilla (unused)
    [PLAYER_OUTFIT_BLUE]   = {RGB( 2,  4, 13), RGB( 5,  8, 18), RGB( 8, 12, 22), RGB(10, 15, 26), RGB(13, 19, 31), RGB( 2,  3, 10), RGB( 3,  5, 13), RGB( 4,  7, 16), RGB( 6,  9, 19), RGB( 7, 11, 22)},
    [PLAYER_OUTFIT_GREEN]  = {RGB( 1,  5,  1), RGB( 4,  9,  3), RGB( 6, 13,  5), RGB( 8, 17,  7), RGB(11, 21,  9), RGB( 8,  8,  3), RGB(10, 10,  4), RGB(12, 12,  6), RGB(15, 14,  8), RGB(17, 16,  9)},
    [PLAYER_OUTFIT_PURPLE] = {RGB( 6,  2, 11), RGB(10,  5, 16), RGB(14,  8, 20), RGB(18, 10, 24), RGB(22, 13, 29), RGB( 5,  2,  9), RGB( 7,  4, 11), RGB( 9,  5, 14), RGB(11,  6, 16), RGB(13,  8, 18)},
    [PLAYER_OUTFIT_BLACK]  = {RGB( 2,  2,  3), RGB( 5,  5,  6), RGB( 8,  8,  9), RGB(10, 10, 12), RGB(13, 13, 15), RGB( 2,  2,  3), RGB( 4,  4,  5), RGB( 6,  6,  7), RGB( 7,  7,  9), RGB( 9,  9, 11)},
    [PLAYER_OUTFIT_PINK]   = {RGB(13,  3,  7), RGB(18,  7, 11), RGB(22, 10, 15), RGB(26, 14, 19), RGB(31, 18, 23), RGB(12,  5,  9), RGB(15,  7, 11), RGB(18,  8, 12), RGB(21, 10, 14), RGB(24, 12, 16)},
};

#endif // GUARD_DATA_PLAYER_OUTFIT_PALETTES_H
