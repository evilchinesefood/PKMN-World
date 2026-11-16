#include "global.h"
#include "battle_pyramid.h"
#include "bg.h"
#include "comfy_anim.h"
#include "event_data.h"
#include "field_weather.h"
#include "gpu_regs.h"
#include "graphics.h"
#include "international_string_util.h"
#include "main.h"
#include "overworld.h"
#include "menu.h"
#include "map_name_popup.h"
#include "palette.h"
#include "region_map.h"
#include "rtc.h"
#include "start_menu.h"
#include "strings.h"
#include "string_util.h"
#include "task.h"
#include "text.h"
#include "constants/battle_frontier.h"
#include "constants/layouts.h"
#include "constants/map_types.h"
#include "constants/region_map_sections.h"
#include "constants/weather.h"
#include "config/general.h"
#include "config/overworld.h"

// static functions
static void Task_MapNamePopUpWindow(u8 taskId);
static void ShowMapNamePopUpWindow(void);
static void LoadMapNamePopUpWindowBg(void);

// EWRAM
EWRAM_DATA u8 gPopupTaskId = 0;

// .rodata
// Only the Gen 8 (SwSh) pop-up exists. The Gen 3 themed frames, the Gen 5 banner, their art and
// the per-map-section theme tables were deleted; git history has them.
#if OW_POPUP_GENERATION != GEN_8
#error "OW_POPUP_GENERATION must be GEN_8: the Gen 3 and Gen 5 map pop-up code and art were deleted. Restore them from git history first."
#endif

// Gen8 assets
static const u8 sMapPopUp_SwSh[] = INCBIN_U8("graphics/map_popup/swsh.4bpp");
static const u8 sMapPopUp_Outline_SwSh[] = INCBIN_U8("graphics/map_popup/swsh_outline.4bpp");
static const u16 sMapPopUp_Palette_SwSh[] = INCBIN_U16("graphics/map_popup/swsh.gbapal");

static const u8 sText_PyramidFloor1[] = _("PYRAMID FLOOR 1");
static const u8 sText_PyramidFloor2[] = _("PYRAMID FLOOR 2");
static const u8 sText_PyramidFloor3[] = _("PYRAMID FLOOR 3");
static const u8 sText_PyramidFloor4[] = _("PYRAMID FLOOR 4");
static const u8 sText_PyramidFloor5[] = _("PYRAMID FLOOR 5");
static const u8 sText_PyramidFloor6[] = _("PYRAMID FLOOR 6");
static const u8 sText_PyramidFloor7[] = _("PYRAMID FLOOR 7");
static const u8 sText_Pyramid[] = _("PYRAMID");

static const u8 *const sBattlePyramid_MapHeaderStrings[FRONTIER_STAGES_PER_CHALLENGE + 1] =
{
    sText_PyramidFloor1,
    sText_PyramidFloor2,
    sText_PyramidFloor3,
    sText_PyramidFloor4,
    sText_PyramidFloor5,
    sText_PyramidFloor6,
    sText_PyramidFloor7,
    sText_Pyramid,
};

static bool8 UNUSED StartMenu_ShowMapNamePopup(void)
{
    HideStartMenu();
    ShowMapNamePopup();
    return TRUE;
}

// States and data defines for Task_MapNamePopUpWindow
enum {
    STATE_SLIDE_IN,
    STATE_WAIT,
    STATE_SLIDE_OUT,
    STATE_UNUSED,
    STATE_ERASE,
    STATE_END,
    STATE_PRINT, // For some reason the first state is numerically last.
};

#define POPUP_OFFSCREEN_X  112

#define tState         data[0]
#define tOnscreenTimer data[1]
#define tXOffset       data[2]
#define tIncomingPopUp data[3]
#define tPrintTimer    data[4]
#define tComfyAnimId   data[5]

// The pop-up clips its slide with WIN0 and shows every layer outside it. In a dark place
// (a Flash cave, the Battle Pyramid) the light circle owns WIN0 through a per-scanline effect, so
// the banner never showed and the whole dark map lit up until the pop-up slid out.
static bool32 IsDarkPlace(void)
{
    return GetFlashLevel() > 0 || CurrentBattlePyramidLocation() == PYRAMID_LOCATION_FLOOR;
}

void ShowMapNamePopup(void)
{
    if (FlagGet(FLAG_HIDE_MAP_NAME_POPUP) != TRUE && !IsDarkPlace())
    {
        if (!FuncIsActiveTask(Task_MapNamePopUpWindow))
        {
            // New pop up window
            gPopupTaskId = CreateTask(Task_MapNamePopUpWindow, 90);

            SetGpuReg(REG_OFFSET_BG0HOFS, -POPUP_OFFSCREEN_X);
            SetGpuReg(REG_OFFSET_WIN0H, (128 << 8) | 240);
            SetGpuReg(REG_OFFSET_WINOUT, WINOUT_WIN01_BG1 | WINOUT_WIN01_BG2 | WINOUT_WIN01_BG3 | WINOUT_WIN01_OBJ);
            SetGpuRegBits(REG_OFFSET_DISPCNT, DISPCNT_WIN0_ON);

            gTasks[gPopupTaskId].tState = STATE_PRINT;
        }
        else
        {
            // There's already a pop up window running.
            // Hurry the old pop up offscreen so the new one can appear.
            if (gTasks[gPopupTaskId].tState != STATE_SLIDE_OUT)
                gTasks[gPopupTaskId].tState = STATE_SLIDE_OUT;
            gTasks[gPopupTaskId].tIncomingPopUp = TRUE;
        }
    }
}

static void Task_MapNamePopUpWindow(u8 taskId)
{
    struct Task *task = &gTasks[taskId];

    switch (task->tState)
    {
    case STATE_PRINT:
        // Wait, then create and print the pop up window
        if (++task->tPrintTimer > 30)
        {
            task->tState = STATE_SLIDE_IN;
            task->tPrintTimer = 0;
            ShowMapNamePopUpWindow();
        }
        break;
    case STATE_SLIDE_IN:
        // Slide the window onscreen.
        {
            if (task->tPrintTimer == 0)
            {
                struct ComfyAnimEasingConfig config;
                InitComfyAnimConfig_Easing(&config);
                config.durationFrames = 20;
                config.from = Q_24_8(-POPUP_OFFSCREEN_X);
                config.to = Q_24_8(0);
                config.easingFunc = ComfyAnimEasing_EaseInOutCubic;
                config.delayFrames = 0;
                task->tComfyAnimId = CreateComfyAnim_Easing(&config);
                task->tPrintTimer = 1;
            }

            if (task->tComfyAnimId >= NUM_COMFY_ANIMS)
            {
                // Comfy anim pool was exhausted; snap onscreen without animating.
                SetGpuReg(REG_OFFSET_BG0HOFS, 0);
                task->tState = STATE_WAIT;
                gTasks[gPopupTaskId].tOnscreenTimer = 0;
                break;
            }

            TryAdvanceComfyAnim(&gComfyAnims[task->tComfyAnimId]);
            s32 xOffset = ReadComfyAnimValueSmooth(&gComfyAnims[task->tComfyAnimId]);
            SetGpuReg(REG_OFFSET_BG0HOFS, xOffset);

            if (gComfyAnims[task->tComfyAnimId].completed)
            {
                task->tState = STATE_WAIT;
                gTasks[gPopupTaskId].tOnscreenTimer = 0;
            }
        }
        break;
    case STATE_WAIT:
        // Wait while the window is fully onscreen.
        if (++task->tOnscreenTimer > 120)
        {
            task->tOnscreenTimer = 0;
            task->tState = STATE_SLIDE_OUT;
        }
        break;
    case STATE_SLIDE_OUT:
        // Slide the window offscreen.
        {
            if (task->tPrintTimer != 2)
            {
                struct ComfyAnimEasingConfig config;
                InitComfyAnimConfig_Easing(&config);
                config.durationFrames = 12;
                s32 currentPos = (task->tComfyAnimId < NUM_COMFY_ANIMS)
                    ? ReadComfyAnimValueSmooth(&gComfyAnims[task->tComfyAnimId])
                    : 0;
                config.from = Q_24_8(currentPos);
                config.to = Q_24_8(-POPUP_OFFSCREEN_X);
                config.easingFunc = ComfyAnimEasing_EaseInOutCubic;
                config.delayFrames = 0;
                if (task->tComfyAnimId < NUM_COMFY_ANIMS)
                    ReleaseComfyAnim(task->tComfyAnimId);
                task->tComfyAnimId = CreateComfyAnim_Easing(&config);
                task->tPrintTimer = 2;
            }

            if (task->tComfyAnimId >= NUM_COMFY_ANIMS)
            {
                // Comfy anim pool was exhausted; snap offscreen without animating.
                SetGpuReg(REG_OFFSET_BG0HOFS, -POPUP_OFFSCREEN_X);
                if (task->tIncomingPopUp)
                {
                    task->tState = STATE_PRINT;
                    task->tPrintTimer = 0;
                    task->tIncomingPopUp = FALSE;
                }
                else
                {
                    task->tState = STATE_ERASE;
                }
                return;
            }

            TryAdvanceComfyAnim(&gComfyAnims[task->tComfyAnimId]);
            s32 xOffset = ReadComfyAnimValueSmooth(&gComfyAnims[task->tComfyAnimId]);
            SetGpuReg(REG_OFFSET_BG0HOFS, xOffset);
        }

        if (gComfyAnims[task->tComfyAnimId].completed)
        {
            if (task->tIncomingPopUp)
            {
                // A new pop up window is incoming,
                // return to the first state to show it.
                ReleaseComfyAnim(task->tComfyAnimId);
                task->tState = STATE_PRINT;
                task->tPrintTimer = 0;
                task->tIncomingPopUp = FALSE;
            }
            else
            {
                task->tState = STATE_ERASE;
                return;
            }
        }
        break;
    case STATE_ERASE:
        ClearStdWindowAndFrame(GetMapNamePopUpWindowId(), TRUE);
        task->tState = STATE_END;
        break;
    case STATE_END:
        HideMapNamePopUpWindow();
        return;
    }
}

void HideMapNamePopUpWindow(void)
{
    if (FuncIsActiveTask(Task_MapNamePopUpWindow))
    {
    #ifdef UBFIX
        if (GetMapNamePopUpWindowId() != WINDOW_NONE)
    #endif // UBFIX
        {
            ClearStdWindowAndFrame(GetMapNamePopUpWindowId(), TRUE);
            RemoveMapNamePopUpWindow();
        }

        ReleaseComfyAnim(gTasks[gPopupTaskId].tComfyAnimId);
        SetGpuReg(REG_OFFSET_WIN0H, 0xFF);
        SetGpuReg(REG_OFFSET_WINOUT, WINOUT_WIN01_BG0 | WINOUT_WINOBJ_BG0);

        SetGpuReg_ForcedBlank(REG_OFFSET_BG0VOFS, 0);
        SetGpuReg_ForcedBlank(REG_OFFSET_BG0HOFS, 0);
        DestroyTask(gPopupTaskId);
    }
}

static void MapNamePopupAppendFloorNum(u8 *map_name, s8 floorNum)
{
    if (floorNum == 0)
        return;
    u8 *dest = map_name;
    while (*dest != EOS)
        dest++;
    *dest++ = CHAR_SPACE;
    if (floorNum == FLOOR_ROOFTOP)
    {
        StringCopy(dest, gText_Rooftop);
        return;
    }
    if (floorNum < 0)
    {
        *dest++ = CHAR_B;
        floorNum *= -1;
    }
    dest = ConvertIntToDecimalStringN(dest, floorNum, STR_CONV_MODE_LEFT_ALIGN, 2);
    *dest++ = CHAR_F;
    *dest = EOS;
}

static bool32 IsCeladonDeptStore(const struct MapHeader *mapHeader)
{
    if (mapHeader->regionMapSectionId != MAPSEC_CELADON_CITY)
        return FALSE;
    if (mapHeader->mapLayoutId != LAYOUT_CELADON_CITY_DEPARTMENT_STORE_1F
     && mapHeader->mapLayoutId != LAYOUT_CELADON_CITY_DEPARTMENT_STORE_2F
     && mapHeader->mapLayoutId != LAYOUT_CELADON_CITY_DEPARTMENT_STORE_3F
     && mapHeader->mapLayoutId != LAYOUT_CELADON_CITY_DEPARTMENT_STORE_4F
     && mapHeader->mapLayoutId != LAYOUT_CELADON_CITY_DEPARTMENT_STORE_5F
     && mapHeader->mapLayoutId != LAYOUT_CELADON_CITY_DEPARTMENT_STORE_ROOF
     && mapHeader->mapLayoutId != LAYOUT_CELADON_CITY_DEPARTMENT_STORE_ELEVATOR)
    {
        return FALSE;
    }
    return TRUE;
}

u8 *GetPopUpMapName(u8 *dest, const struct MapHeader *mapHeader)
{
    if (IsCeladonDeptStore(mapHeader))
        // No trailing period: with " ROOFTOP" appended this is the widest popup name in the
        // game at exactly 96px, and the GEN_8 popup window is 96px with no shrink-to-fit.
        // The period cost 3px and overflowed it. Margin here is 0 — if this name or the floor
        // suffix ever grows, it breaks again. Every other name has >=11px to spare.
        StringCopy(dest, COMPOUND_STRING("CELADON DEPT"));
    else
        GetMapName(dest, mapHeader->regionMapSectionId, 0);
    if (mapHeader->floorNumber == 0)
        return dest;
    MapNamePopupAppendFloorNum(dest, mapHeader->floorNumber);
    return dest;
}

static void ShowMapNamePopUpWindow(void)
{
    u8 mapDisplayHeader[MAP_POPUP_STRING_BUFFER_LENGTH];
    u8 *withoutPrefixPtr;
    u8 x;
    const u8 *mapDisplayHeaderSource;

    if (CurrentBattlePyramidLocation() != PYRAMID_LOCATION_NONE)
    {
        if (gMapHeader.mapLayoutId == LAYOUT_BATTLE_FRONTIER_BATTLE_PYRAMID_TOP)
        {
            withoutPrefixPtr = &(mapDisplayHeader[MAP_POPUP_PREFIX_BUFFER_LENGTH]);
            mapDisplayHeaderSource = sBattlePyramid_MapHeaderStrings[FRONTIER_STAGES_PER_CHALLENGE];
        }
        else
        {
            withoutPrefixPtr = &(mapDisplayHeader[MAP_POPUP_PREFIX_BUFFER_LENGTH]);
            mapDisplayHeaderSource = sBattlePyramid_MapHeaderStrings[gSaveBlock2Ptr->frontier.curChallengeBattleNum];
        }
        StringCopy(withoutPrefixPtr, mapDisplayHeaderSource);
    }
    else
    {
        withoutPrefixPtr = &(mapDisplayHeader[MAP_POPUP_PREFIX_BUFFER_LENGTH]);
        GetPopUpMapName(withoutPrefixPtr, &gMapHeader);
    }

    AddMapNamePopUpWindow();

    LoadMapNamePopUpWindowBg();

    mapDisplayHeader[0] = EXT_CTRL_CODE_BEGIN;
    mapDisplayHeader[1] = EXT_CTRL_CODE_BACKGROUND;
    mapDisplayHeader[2] = TEXT_COLOR_TRANSPARENT;
    mapDisplayHeader[3] = EXT_CTRL_CODE_BEGIN;
    mapDisplayHeader[4] = EXT_CTRL_CODE_ACCENT;
    mapDisplayHeader[5] = TEXT_COLOR_TRANSPARENT;

    x = GetStringCenterAlignXOffset(FONT_NARROW, withoutPrefixPtr, 96);
    AddTextPrinterParameterized(GetMapNamePopUpWindowId(), FONT_NARROW, mapDisplayHeader, x, 0, TEXT_SKIP_DRAW, NULL);
    CopyWindowToVram(GetMapNamePopUpWindowId(), COPYWIN_FULL);
}

#define TILE_SWSH_TOP_EDGE_START 0x21D
#define TILE_SWSH_TOP_EDGE_END   0x22A
#define TILE_SWSH_LEFT_EDGE_TOP  0x22B
#define TILE_SWSH_RIGHT_EDGE_TOP 0x22C
#define TILE_SWSH_LEFT_EDGE_BOT  0x22D
#define TILE_SWSH_RIGHT_EDGE_BOT 0x22E
#define TILE_SWSH_BOT_EDGE_START 0x22F
#define TILE_SWSH_BOT_EDGE_END   0x23C

static void DrawMapNamePopUpFrame_SwSh(u8 bg, u8 x, u8 y, u8 deltaX, u8 deltaY, u8 unused)
{
    s32 i;

    // Draw top edge (Tiles 0-13)
    for (i = 0; i < 1 + TILE_SWSH_TOP_EDGE_END - TILE_SWSH_TOP_EDGE_START; i++)
        FillBgTilemapBufferRect(bg, TILE_SWSH_TOP_EDGE_START + i, x - 1 + i, y - 1, 1, 1, 14);

    // Draw sides (Tiles 14-17)
    FillBgTilemapBufferRect(bg, TILE_SWSH_LEFT_EDGE_TOP,       x - 1,     y, 1, 1, 14);
    FillBgTilemapBufferRect(bg, TILE_SWSH_RIGHT_EDGE_TOP, deltaX + x,     y, 1, 1, 14);
    FillBgTilemapBufferRect(bg, TILE_SWSH_LEFT_EDGE_BOT,       x - 1, y + 1, 1, 1, 14);
    FillBgTilemapBufferRect(bg, TILE_SWSH_RIGHT_EDGE_BOT, deltaX + x, y + 1, 1, 1, 14);

    // Draw bottom edge (Tiles 18-31)
    for (i = 0; i < 1 + TILE_SWSH_BOT_EDGE_END - TILE_SWSH_BOT_EDGE_START; i++)
        FillBgTilemapBufferRect(bg, TILE_SWSH_BOT_EDGE_START + i, x - 1 + i, y + deltaY, 1, 1, 14);
}

static void LoadMapNamePopUpWindowBg(void)
{
    u8 popupWindowId = GetMapNamePopUpWindowId();

    LoadBgTiles(GetWindowAttribute(popupWindowId, WINDOW_BG), sMapPopUp_Outline_SwSh, 0x400, 0x21D);
    CallWindowFunction(popupWindowId, DrawMapNamePopUpFrame_SwSh);
    PutWindowTilemap(popupWindowId);
    LoadPalette(sMapPopUp_Palette_SwSh, BG_PLTT_ID(14), sizeof(sMapPopUp_Palette_SwSh));
    BlitBitmapToWindow(popupWindowId, sMapPopUp_SwSh, 0, 0, 96, 16);
}
