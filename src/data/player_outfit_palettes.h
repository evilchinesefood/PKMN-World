#ifndef GUARD_DATA_PLAYER_OUTFIT_PALETTES_H
#define GUARD_DATA_PLAYER_OUTFIT_PALETTES_H

// Hand-authored RGB5 colorways. This file is the source of truth; no external
// generator is required. Each pair is ordered shadow -> highlight. RED rows
// document the original palette; Apply* returns before writing them.
//
// OW: indices 12/13 are the shirt, 10/11 the band/bag. Keep 5-8 unchanged:
// Brendan shares them with cap shading, eyes and hair; May uses 7/8 for hair.
// Front/back: Brendan's garment fill is 5/6, trim 12/13 and band/bag 10/11;
// 7/8 remain fixed hair/ink shades. May uses 12/13 for her top, 5/6 for dark
// shorts/gloves, and 10/11 for the band/bag. Skin 1-4, white 9/14 and outline
// 15 are never written. Audit sheets and native captures: Testing/player-outfits.
//
// BLUE: cobalt/slate with gold. GREEN: jade/earth with copper.
// PURPLE: blue-violet with silver. BLACK: graphite with teal and gold trim.
// PINK: rose with plum and cream. Larger back sprites have brighter midtones
// so their broad shadow areas retain shape during the send-out animation.

static const u8 sOWClothingIdx_Male[] = {13, 12, 11, 10};
static const u16 sOutfitOW_Male[NUM_PLAYER_OUTFITS][4] = {
    [PLAYER_OUTFIT_RED] = {RGB(24,  8,  8), RGB(31, 12, 11), RGB( 9, 18, 10), RGB(14, 25, 14)},
    [PLAYER_OUTFIT_BLUE] = {RGB( 4,  9, 18), RGB(10, 18, 29), RGB(18, 12,  4), RGB(31, 24,  9)},
    [PLAYER_OUTFIT_GREEN] = {RGB( 4, 13,  9), RGB(11, 24, 16), RGB(18, 11,  3), RGB(30, 22,  8)},
    [PLAYER_OUTFIT_PURPLE] = {RGB(11,  6, 19), RGB(20, 14, 29), RGB(15, 17, 24), RGB(27, 28, 31)},
    [PLAYER_OUTFIT_BLACK] = {RGB( 7,  9, 12), RGB(14, 16, 19), RGB( 3, 15, 17), RGB(10, 27, 26)},
    [PLAYER_OUTFIT_PINK] = {RGB(21,  6, 12), RGB(31, 16, 21), RGB(21, 18, 11), RGB(31, 29, 20)},
};

static const u8 sOWClothingIdx_Female[] = {13, 12, 11, 10};
static const u16 sOutfitOW_Female[NUM_PLAYER_OUTFITS][4] = {
    [PLAYER_OUTFIT_RED] = {RGB(24,  8,  8), RGB(31, 12, 11), RGB( 8, 21,  4), RGB(13, 26,  8)},
    [PLAYER_OUTFIT_BLUE] = {RGB( 6, 12, 22), RGB(13, 21, 30), RGB(19, 13,  4), RGB(31, 25, 11)},
    [PLAYER_OUTFIT_GREEN] = {RGB( 6, 15,  7), RGB(14, 25, 13), RGB(17, 12,  5), RGB(29, 23, 10)},
    [PLAYER_OUTFIT_PURPLE] = {RGB(13,  8, 22), RGB(23, 16, 30), RGB(16, 18, 24), RGB(28, 29, 31)},
    [PLAYER_OUTFIT_BLACK] = {RGB( 8, 10, 13), RGB(16, 18, 21), RGB( 4, 16, 17), RGB(12, 28, 25)},
    [PLAYER_OUTFIT_PINK] = {RGB(23,  8, 15), RGB(31, 18, 24), RGB(22, 18, 12), RGB(31, 29, 22)},
};

static const u8 sFrontPicClothingIdx_Male[] = {6, 5, 13, 12, 11, 10};
static const u16 sOutfitFrontPic_Male[NUM_PLAYER_OUTFITS][6] = {
    [PLAYER_OUTFIT_RED] = {RGB( 9, 11, 16), RGB(12, 15, 19), RGB(24,  8,  8), RGB(31, 12, 11), RGB(12, 19, 11), RGB(17, 27, 14)},
    [PLAYER_OUTFIT_BLUE] = {RGB( 6, 11, 20), RGB(13, 19, 29), RGB(11, 15, 22), RGB(22, 25, 30), RGB(18, 12,  4), RGB(30, 23, 10)},
    [PLAYER_OUTFIT_GREEN] = {RGB( 4, 13,  9), RGB(11, 23, 16), RGB(14, 10,  6), RGB(25, 20, 12), RGB(17,  8,  3), RGB(29, 17,  8)},
    [PLAYER_OUTFIT_PURPLE] = {RGB(11,  7, 20), RGB(21, 16, 29), RGB( 8, 16, 20), RGB(19, 26, 27), RGB(15, 16, 23), RGB(27, 27, 31)},
    [PLAYER_OUTFIT_BLACK] = {RGB( 7,  9, 12), RGB(14, 17, 21), RGB(17, 12,  5), RGB(29, 24, 12), RGB( 3, 14, 15), RGB( 9, 25, 23)},
    [PLAYER_OUTFIT_PINK] = {RGB(20,  7, 13), RGB(30, 17, 22), RGB( 9,  5, 11), RGB(17, 11, 19), RGB(19, 17, 11), RGB(30, 28, 21)},
};

static const u8 sFrontPicClothingIdx_Female[] = {13, 12, 6, 5, 11, 10};
static const u16 sOutfitFrontPic_Female[NUM_PLAYER_OUTFITS][6] = {
    [PLAYER_OUTFIT_RED] = {RGB(24,  8,  8), RGB(31, 12, 11), RGB( 5,  7,  8), RGB(12, 12, 14), RGB(12, 19, 11), RGB(17, 27, 14)},
    [PLAYER_OUTFIT_BLUE] = {RGB( 7, 12, 22), RGB(15, 21, 30), RGB( 4,  7, 13), RGB(10, 14, 21), RGB(18, 12,  4), RGB(30, 24, 11)},
    [PLAYER_OUTFIT_GREEN] = {RGB( 5, 14,  8), RGB(14, 24, 14), RGB( 8,  8,  5), RGB(16, 15,  9), RGB(17, 10,  4), RGB(29, 21, 10)},
    [PLAYER_OUTFIT_PURPLE] = {RGB(13,  8, 22), RGB(24, 17, 30), RGB( 6,  5, 10), RGB(13, 12, 19), RGB(16, 17, 23), RGB(28, 28, 31)},
    [PLAYER_OUTFIT_BLACK] = {RGB( 8, 10, 13), RGB(16, 18, 21), RGB( 4,  5,  7), RGB( 8, 10, 13), RGB( 3, 15, 16), RGB(11, 26, 24)},
    [PLAYER_OUTFIT_PINK] = {RGB(23,  8, 15), RGB(31, 19, 25), RGB( 6,  4,  8), RGB(14,  9, 14), RGB(21, 17, 11), RGB(31, 28, 22)},
};

static const u8 sBackPicClothingIdx_Male[] = {6, 5, 13, 12, 11, 10};
static const u16 sOutfitBackPic_Male[NUM_PLAYER_OUTFITS][6] = {
    [PLAYER_OUTFIT_RED] = {RGB( 9, 11, 16), RGB(12, 15, 19), RGB(24,  8,  8), RGB(31, 12, 11), RGB(12, 19, 11), RGB(17, 27, 14)},
    [PLAYER_OUTFIT_BLUE] = {RGB( 6, 12, 21), RGB(14, 20, 30), RGB(12, 16, 23), RGB(24, 27, 31), RGB(19, 13,  5), RGB(31, 25, 11)},
    [PLAYER_OUTFIT_GREEN] = {RGB( 5, 14, 10), RGB(13, 24, 17), RGB(15, 11,  6), RGB(27, 21, 13), RGB(18,  9,  3), RGB(30, 18,  8)},
    [PLAYER_OUTFIT_PURPLE] = {RGB(12,  8, 21), RGB(23, 17, 30), RGB( 9, 17, 21), RGB(21, 27, 29), RGB(16, 18, 25), RGB(29, 29, 31)},
    [PLAYER_OUTFIT_BLACK] = {RGB( 8, 10, 13), RGB(16, 18, 22), RGB(18, 13,  6), RGB(30, 25, 13), RGB( 4, 16, 18), RGB(11, 27, 26)},
    [PLAYER_OUTFIT_PINK] = {RGB(22,  8, 14), RGB(31, 19, 24), RGB(10,  6, 13), RGB(19, 13, 21), RGB(21, 18, 12), RGB(31, 30, 23)},
};

static const u8 sBackPicClothingIdx_Female[] = {13, 12, 6, 5, 11, 10};
static const u16 sOutfitBackPic_Female[NUM_PLAYER_OUTFITS][6] = {
    [PLAYER_OUTFIT_RED] = {RGB(24,  8,  8), RGB(31, 12, 11), RGB( 5,  7,  8), RGB(12, 12, 14), RGB(12, 19, 11), RGB(17, 27, 14)},
    [PLAYER_OUTFIT_BLUE] = {RGB( 8, 14, 24), RGB(16, 22, 31), RGB( 5,  8, 14), RGB(12, 16, 23), RGB(19, 13,  5), RGB(31, 26, 12)},
    [PLAYER_OUTFIT_GREEN] = {RGB( 6, 16, 10), RGB(15, 26, 17), RGB( 9,  9,  6), RGB(18, 17, 11), RGB(18, 11,  4), RGB(30, 23, 11)},
    [PLAYER_OUTFIT_PURPLE] = {RGB(14,  9, 23), RGB(25, 18, 31), RGB( 7,  6, 12), RGB(15, 14, 21), RGB(17, 19, 25), RGB(29, 30, 31)},
    [PLAYER_OUTFIT_BLACK] = {RGB( 9, 11, 14), RGB(17, 19, 22), RGB( 5,  6,  8), RGB(10, 12, 15), RGB( 4, 16, 18), RGB(12, 28, 26)},
    [PLAYER_OUTFIT_PINK] = {RGB(24,  9, 16), RGB(31, 20, 26), RGB( 7,  5,  9), RGB(16, 11, 16), RGB(22, 18, 12), RGB(31, 30, 23)},
};

// Legacy 32-color Red portrait data; no live caller after the Brendan/May intro port.
// The actual Oak picker uses the gender-specific FrontPic tables above.
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
