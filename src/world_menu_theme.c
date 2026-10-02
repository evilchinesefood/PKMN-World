#include "global.h"
#include "world_menu_theme.h"
#include "bg.h"
#include "decompress.h"
#include "palette.h"
#include "menu.h"
#include "text.h"
#include "window.h"
#include "constants/rgb.h"

#define PANEL RGB(31, 31, 31)
#define INK RGB(5, 6, 9)
#define ACCENT RGB(26, 6, 10)

static const u32 sBackgroundTiles[] = INCGFX_U32("graphics/pokemon_storage/scrolling_bg.png", ".4bpp.smol");
static const u32 sBackgroundMap[] = INCGFX_U32("graphics/pokemon_storage/scrolling_bg.bin", ".smolTM");
static const u16 sBackgroundPalette[16] = {[8] = PANEL, [9] = RGB(29, 30, 30), [10] = RGB(27, 28, 29)};
static const u16 sTextPalette[16] = {
    0, PANEL, INK, PANEL, ACCENT, PANEL, INK, PANEL,
    INK, PANEL, PANEL, INK, PANEL, INK, INK, PANEL
};
static const u16 sSelectedPalette[16] = {
    0, ACCENT, PANEL, ACCENT, PANEL, ACCENT, PANEL, ACCENT,
    PANEL, ACCENT, ACCENT, PANEL, ACCENT, PANEL, PANEL, ACCENT
};

void WorldMenu_InitBackground(u8 charBaseIndex)
{
    struct BgTemplate bg = {.bg = 3, .charBaseIndex = charBaseIndex, .mapBaseIndex = 28, .priority = 3};
    InitBgFromTemplate(&bg);
    DecompressAndLoadBgGfxUsingHeap(3, sBackgroundTiles, 0, 0, 0);
    DecompressDataWithHeaderVram(sBackgroundMap, (void *)BG_SCREEN_ADDR(28));
    LoadPalette(sBackgroundPalette, BG_PLTT_ID(3), sizeof(sBackgroundPalette));
    ChangeBgX(3, 0, BG_COORD_SET);
    ChangeBgY(3, 0, BG_COORD_SET);
    ShowBg(3);
}

void WorldMenu_UpdateBackground(void)
{
    // Match the PC box's half-pixel diagonal scroll per frame.
    ChangeBgX(3, 128, BG_COORD_ADD);
    ChangeBgY(3, 128, BG_COORD_SUB);
}

void WorldMenu_LoadTextPalette(u8 palette)
{
    LoadPalette(sTextPalette, BG_PLTT_ID(palette), sizeof(sTextPalette));
}

void WorldMenu_LoadSelectedPalette(u8 palette)
{
    LoadPalette(sSelectedPalette, BG_PLTT_ID(palette), sizeof(sSelectedPalette));
}

void WorldMenu_DrawHeader(u8 window, const u8 *title)
{
    static const u8 colors[] = {1, 2, 3};
    WorldMenu_LoadSelectedPalette(12);
    FillWindowPixelBuffer(window, PIXEL_FILL(1));
    AddTextPrinterParameterized3(window, FONT_SMALL, 8, 2, colors, TEXT_SKIP_DRAW, title);
    PutWindowTilemap(window);
    CopyWindowToVram(window, COPYWIN_FULL);
}

void WorldMenu_RoundWindowTopCorners(u8 window)
{
    u32 width = GetWindowAttribute(window, WINDOW_WIDTH) * 8;
    static const u8 cutouts[] = {3, 1};

    // Round only the top corners so footers stay flush with the screen bottom.
    // Transparent pixels reveal the moving background without extra frame tiles.
    // Apply after text printing, which may paint its background into the corners.
    for (u32 y = 0; y < ARRAY_COUNT(cutouts); y++)
    {
        u32 inset = cutouts[y];
        FillWindowPixelRect(window, PIXEL_FILL(0), 0, y, inset, 1);
        FillWindowPixelRect(window, PIXEL_FILL(0), width - inset, y, inset, 1);
    }
}
