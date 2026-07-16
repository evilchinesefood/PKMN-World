#ifndef GUARD_DATA_PLAYER_OUTFIT_PALETTES_H
#define GUARD_DATA_PLAYER_OUTFIT_PALETTES_H

// Player-outfit clothing palettes, PER-GENDER. Each Apply* in palette_swap.c overwrites ONLY the
// clothing indices for the player's gender, leaving constants (skin, hair, white, outline)
// untouched. RGB() components are 0-31. Indexed by PLAYER_OUTFIT_*. RED rows are vanilla and
// unused (Apply* early-returns for RED). Regenerated via the external OutfitPalettes.py helper.
//
// Brendan (Male) and May (Female) have DIFFERENT palette layouts, so each gets its own tables:
//   Male   garments = blue body 5-8 (jacket), red cap 12-13 (pants), green bag 10-11 (accent).
//   Female garments = red top 12-13 (jacket), shorts 5-6 (pants), green pack 10-11 (accent);
//          May's hair 7-8 + skin 1-4 are constants and are NOT recolored (that was the earlier
//          Brendan-only bug where May's hair mis-tinted).
// Portrait rows are shared (the Red 32c Oak-intro palette; no Brendan/May intro portrait art
// exists yet). PLAYTEST: verify each gender with the visual companion
// (.plans/2026-05-27-player-outfit-palettes-visual-companion.html) + in-game.

// Overworld sprite (16c) — Male: clothing indices (jacket dark->light, pants dark->light, accent)
static const u8 sOWClothingIdx_Male[] = {8, 7, 6, 5, 13, 12, 11, 10};
static const u16 sOutfitOW_Male[NUM_PLAYER_OUTFITS][8] = {
    [PLAYER_OUTFIT_RED] = {RGB( 2,  4,  7), RGB( 3,  5, 10), RGB( 5,  7, 12), RGB( 7,  9, 15), RGB(24,  8,  8), RGB(31, 12, 11), RGB( 9, 18, 10), RGB(14, 25, 14)}, // vanilla (unused; Red early-returns)
    [PLAYER_OUTFIT_BLUE] = {RGB( 2,  4, 13), RGB( 6,  9, 19), RGB( 9, 14, 25), RGB(13, 19, 31), RGB( 2,  3, 10), RGB( 7, 11, 22), RGB(31, 25,  7), RGB(31, 25,  7)},
    [PLAYER_OUTFIT_GREEN] = {RGB( 1,  5,  1), RGB( 4, 10,  4), RGB( 8, 16,  6), RGB(11, 21,  9), RGB( 8,  8,  3), RGB(17, 16,  9), RGB(24, 17,  5), RGB(24, 17,  5)},
    [PLAYER_OUTFIT_PURPLE] = {RGB( 6,  2, 11), RGB(11,  6, 17), RGB(17,  9, 23), RGB(22, 13, 29), RGB( 5,  2,  9), RGB(13,  8, 18), RGB(25, 25, 28), RGB(25, 25, 28)},
    [PLAYER_OUTFIT_BLACK] = {RGB( 2,  2,  3), RGB( 6,  6,  7), RGB( 9,  9, 11), RGB(13, 13, 15), RGB( 2,  2,  3), RGB( 9,  9, 11), RGB(31, 25,  7), RGB(31, 25,  7)},
    [PLAYER_OUTFIT_PINK] = {RGB(13,  3,  7), RGB(19,  8, 12), RGB(25, 13, 18), RGB(31, 18, 23), RGB(12,  5,  9), RGB(24, 12, 16), RGB(31, 30, 23), RGB(31, 30, 23)},
};

// Overworld sprite (16c) — Female: clothing indices (jacket dark->light, pants dark->light, accent)
static const u8 sOWClothingIdx_Female[] = {13, 12, 6, 5, 11, 10};
static const u16 sOutfitOW_Female[NUM_PLAYER_OUTFITS][6] = {
    [PLAYER_OUTFIT_RED] = {RGB(24,  8,  8), RGB(31, 12, 11), RGB( 5,  7,  8), RGB(12, 12, 14), RGB( 8, 21,  4), RGB(13, 26,  8)}, // vanilla (unused; Red early-returns)
    [PLAYER_OUTFIT_BLUE] = {RGB( 2,  4, 13), RGB(13, 19, 31), RGB( 2,  3, 10), RGB( 7, 11, 22), RGB(31, 25,  7), RGB(31, 25,  7)},
    [PLAYER_OUTFIT_GREEN] = {RGB( 1,  5,  1), RGB(11, 21,  9), RGB( 8,  8,  3), RGB(17, 16,  9), RGB(24, 17,  5), RGB(24, 17,  5)},
    [PLAYER_OUTFIT_PURPLE] = {RGB( 6,  2, 11), RGB(22, 13, 29), RGB( 5,  2,  9), RGB(13,  8, 18), RGB(25, 25, 28), RGB(25, 25, 28)},
    [PLAYER_OUTFIT_BLACK] = {RGB( 2,  2,  3), RGB(13, 13, 15), RGB( 2,  2,  3), RGB( 9,  9, 11), RGB(31, 25,  7), RGB(31, 25,  7)},
    [PLAYER_OUTFIT_PINK] = {RGB(13,  3,  7), RGB(31, 18, 23), RGB(12,  5,  9), RGB(24, 12, 16), RGB(31, 30, 23), RGB(31, 30, 23)},
};

// Trainer-card / front pic (16c) — Male: clothing indices (jacket dark->light, pants dark->light, accent)
static const u8 sFrontPicClothingIdx_Male[] = {8, 7, 6, 5, 13, 12, 11, 10};
static const u16 sOutfitFrontPic_Male[NUM_PLAYER_OUTFITS][8] = {
    [PLAYER_OUTFIT_RED] = {RGB( 3,  5, 10), RGB( 6,  8, 13), RGB( 9, 11, 16), RGB(12, 15, 19), RGB(24,  8,  8), RGB(31, 12, 11), RGB(12, 19, 11), RGB(17, 27, 14)}, // vanilla (unused; Red early-returns)
    [PLAYER_OUTFIT_BLUE] = {RGB( 2,  4, 13), RGB( 6,  9, 19), RGB( 9, 14, 25), RGB(13, 19, 31), RGB( 2,  3, 10), RGB( 7, 11, 22), RGB(31, 25,  7), RGB(31, 25,  7)},
    [PLAYER_OUTFIT_GREEN] = {RGB( 1,  5,  1), RGB( 4, 10,  4), RGB( 8, 16,  6), RGB(11, 21,  9), RGB( 8,  8,  3), RGB(17, 16,  9), RGB(24, 17,  5), RGB(24, 17,  5)},
    [PLAYER_OUTFIT_PURPLE] = {RGB( 6,  2, 11), RGB(11,  6, 17), RGB(17,  9, 23), RGB(22, 13, 29), RGB( 5,  2,  9), RGB(13,  8, 18), RGB(25, 25, 28), RGB(25, 25, 28)},
    [PLAYER_OUTFIT_BLACK] = {RGB( 2,  2,  3), RGB( 6,  6,  7), RGB( 9,  9, 11), RGB(13, 13, 15), RGB( 2,  2,  3), RGB( 9,  9, 11), RGB(31, 25,  7), RGB(31, 25,  7)},
    [PLAYER_OUTFIT_PINK] = {RGB(13,  3,  7), RGB(19,  8, 12), RGB(25, 13, 18), RGB(31, 18, 23), RGB(12,  5,  9), RGB(24, 12, 16), RGB(31, 30, 23), RGB(31, 30, 23)},
};

// Trainer-card / front pic (16c) — Female: clothing indices (jacket dark->light, pants dark->light, accent)
static const u8 sFrontPicClothingIdx_Female[] = {13, 12, 6, 5, 11, 10};
static const u16 sOutfitFrontPic_Female[NUM_PLAYER_OUTFITS][6] = {
    [PLAYER_OUTFIT_RED] = {RGB(24,  8,  8), RGB(31, 12, 11), RGB( 5,  7,  8), RGB(12, 12, 14), RGB(12, 19, 11), RGB(17, 27, 14)}, // vanilla (unused; Red early-returns)
    [PLAYER_OUTFIT_BLUE] = {RGB( 2,  4, 13), RGB(13, 19, 31), RGB( 2,  3, 10), RGB( 7, 11, 22), RGB(31, 25,  7), RGB(31, 25,  7)},
    [PLAYER_OUTFIT_GREEN] = {RGB( 1,  5,  1), RGB(11, 21,  9), RGB( 8,  8,  3), RGB(17, 16,  9), RGB(24, 17,  5), RGB(24, 17,  5)},
    [PLAYER_OUTFIT_PURPLE] = {RGB( 6,  2, 11), RGB(22, 13, 29), RGB( 5,  2,  9), RGB(13,  8, 18), RGB(25, 25, 28), RGB(25, 25, 28)},
    [PLAYER_OUTFIT_BLACK] = {RGB( 2,  2,  3), RGB(13, 13, 15), RGB( 2,  2,  3), RGB( 9,  9, 11), RGB(31, 25,  7), RGB(31, 25,  7)},
    [PLAYER_OUTFIT_PINK] = {RGB(13,  3,  7), RGB(31, 18, 23), RGB(12,  5,  9), RGB(24, 12, 16), RGB(31, 30, 23), RGB(31, 30, 23)},
};

// Battle back-pic (16c) — Male: clothing indices (jacket dark->light, pants dark->light, accent)
static const u8 sBackPicClothingIdx_Male[] = {8, 7, 6, 5, 13, 12, 11, 10};
static const u16 sOutfitBackPic_Male[NUM_PLAYER_OUTFITS][8] = {
    [PLAYER_OUTFIT_RED] = {RGB( 3,  5, 10), RGB( 6,  8, 13), RGB( 9, 11, 16), RGB(12, 15, 19), RGB(24,  8,  8), RGB(31, 12, 11), RGB(12, 19, 11), RGB(17, 27, 14)}, // vanilla (unused; Red early-returns)
    [PLAYER_OUTFIT_BLUE] = {RGB( 2,  4, 13), RGB( 6,  9, 19), RGB( 9, 14, 25), RGB(13, 19, 31), RGB( 2,  3, 10), RGB( 7, 11, 22), RGB(31, 25,  7), RGB(31, 25,  7)},
    [PLAYER_OUTFIT_GREEN] = {RGB( 1,  5,  1), RGB( 4, 10,  4), RGB( 8, 16,  6), RGB(11, 21,  9), RGB( 8,  8,  3), RGB(17, 16,  9), RGB(24, 17,  5), RGB(24, 17,  5)},
    [PLAYER_OUTFIT_PURPLE] = {RGB( 6,  2, 11), RGB(11,  6, 17), RGB(17,  9, 23), RGB(22, 13, 29), RGB( 5,  2,  9), RGB(13,  8, 18), RGB(25, 25, 28), RGB(25, 25, 28)},
    [PLAYER_OUTFIT_BLACK] = {RGB( 2,  2,  3), RGB( 6,  6,  7), RGB( 9,  9, 11), RGB(13, 13, 15), RGB( 2,  2,  3), RGB( 9,  9, 11), RGB(31, 25,  7), RGB(31, 25,  7)},
    [PLAYER_OUTFIT_PINK] = {RGB(13,  3,  7), RGB(19,  8, 12), RGB(25, 13, 18), RGB(31, 18, 23), RGB(12,  5,  9), RGB(24, 12, 16), RGB(31, 30, 23), RGB(31, 30, 23)},
};

// Battle back-pic (16c) — Female: clothing indices (jacket dark->light, pants dark->light, accent)
static const u8 sBackPicClothingIdx_Female[] = {13, 12, 6, 5, 11, 10};
static const u16 sOutfitBackPic_Female[NUM_PLAYER_OUTFITS][6] = {
    [PLAYER_OUTFIT_RED] = {RGB(24,  8,  8), RGB(31, 12, 11), RGB( 5,  7,  8), RGB(12, 12, 14), RGB(12, 19, 11), RGB(17, 27, 14)}, // vanilla (unused; Red early-returns)
    [PLAYER_OUTFIT_BLUE] = {RGB( 2,  4, 13), RGB(13, 19, 31), RGB( 2,  3, 10), RGB( 7, 11, 22), RGB(31, 25,  7), RGB(31, 25,  7)},
    [PLAYER_OUTFIT_GREEN] = {RGB( 1,  5,  1), RGB(11, 21,  9), RGB( 8,  8,  3), RGB(17, 16,  9), RGB(24, 17,  5), RGB(24, 17,  5)},
    [PLAYER_OUTFIT_PURPLE] = {RGB( 6,  2, 11), RGB(22, 13, 29), RGB( 5,  2,  9), RGB(13,  8, 18), RGB(25, 25, 28), RGB(25, 25, 28)},
    [PLAYER_OUTFIT_BLACK] = {RGB( 2,  2,  3), RGB(13, 13, 15), RGB( 2,  2,  3), RGB( 9,  9, 11), RGB(31, 25,  7), RGB(31, 25,  7)},
    [PLAYER_OUTFIT_PINK] = {RGB(13,  3,  7), RGB(31, 18, 23), RGB(12,  5,  9), RGB(24, 12, 16), RGB(31, 30, 23), RGB(31, 30, 23)},
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
