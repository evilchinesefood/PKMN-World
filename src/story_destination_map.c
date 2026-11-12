#include "global.h"
#include "story_progress.h"
#include "region_map.h"
#include "bg.h"
#include "gpu_regs.h"
#include "main.h"
#include "malloc.h"
#include "menu.h"
#include "palette.h"
#include "scanline_effect.h"
#include "sound.h"
#include "sprite.h"
#include "task.h"
#include "text.h"
#include "window.h"
#include "world_menu_theme.h"
#include "constants/rgb.h"
#include "constants/songs.h"

enum { WIN_TITLE, WIN_INFO, WIN_CONTROLS };
struct StoryDestinationMap
{
    struct RegionMap map;
    const struct StoryObjective *objective;
    MainCallback returnCallback;
    bool8 info;
    bool8 pinned;
};
static EWRAM_DATA struct StoryDestinationMap *sStoryDestinationMap = NULL;
static const struct BgTemplate sBgs[] = {
    {.bg = 0, .charBaseIndex = 0, .mapBaseIndex = 31, .priority = 0},
    {.bg = 2, .charBaseIndex = 2, .mapBaseIndex = 28, .screenSize = 2, .paletteMode = 1, .priority = 2},
};
static const struct WindowTemplate sWindows[] = {
    {0, 1, 0, 28, 2, 1, 1},
    {0, 1, 3, 28, 14, 1, 57},
    {0, 1, 18, 28, 2, 1, 449},
    DUMMY_WIN_TEMPLATE,
};
static const u8 sColors[] = {1, 2, 3};
static const u8 sMapControls[] = _("A: location details   B: Story");
static const u8 sInfoControls[] = _("A: map   B: Story");
static const u8 sBackControls[] = _("B: Story");
static const u8 sLocation[] = _("Where / who");
static const u8 sAccess[] = _("Follow the Story prerequisites.\nA marker does not open a route.");
static const u8 *const sExplanations[] = {
    [STORY_DESTINATION_PIN] = COMPOUND_STRING("No regional marker is available."),
    [STORY_DESTINATION_HUB] = COMPOUND_STRING("World Transit is outside\nthe regional maps."),
    [STORY_DESTINATION_FREE_ROAM] = COMPOUND_STRING("There is no single destination\nfor free exploration."),
    [STORY_DESTINATION_MULTIPLE] = COMPOUND_STRING("Several places can advance\nthis objective."),
    [STORY_DESTINATION_WAITING] = COMPOUND_STRING("Complete the prerequisite\nbefore returning here."),
    [STORY_DESTINATION_DYNAMIC] = COMPOUND_STRING("The destination is not known\nwell enough to mark it."),
};
static const u8 *const sTitles[] = {
    [REGION_MAP_HOENN] = COMPOUND_STRING("Hoenn"),
    [REGION_MAP_KANTO] = COMPOUND_STRING("Kanto"),
    [REGION_MAP_SEVII123] = COMPOUND_STRING("Sevii 1-3"),
    [REGION_MAP_SEVII45] = COMPOUND_STRING("Sevii 4-5"),
    [REGION_MAP_SEVII67] = COMPOUND_STRING("Sevii 6-7"),
    [REGION_MAP_JOHTO] = COMPOUND_STRING("Johto"),
};

static void Print(u8 window, u8 y, const u8 *text)
{
    AddTextPrinterParameterized3(window, FONT_SMALL, 4, y, sColors, TEXT_SKIP_DRAW, text);
}

static void Draw(void)
{
    struct StoryDestinationMap *view = sStoryDestinationMap;
    u16 kind = StoryProgress_GetDestination(view->objective)->kind;
    FillWindowPixelBuffer(WIN_TITLE, PIXEL_FILL(1));
    FillWindowPixelBuffer(WIN_CONTROLS, PIXEL_FILL(1));
    PutWindowTilemap(WIN_TITLE);
    PutWindowTilemap(WIN_CONTROLS);
    Print(WIN_TITLE, 0, view->pinned ? sTitles[view->map.mapType] : sLocation);
    if (view->pinned)
        AddTextPrinterParameterized3(WIN_TITLE, FONT_SMALL, 96, 0, sColors, TEXT_SKIP_DRAW, view->map.mapSecName);
    if (view->info)
    {
        HideBg(2);
        FillWindowPixelBuffer(WIN_INFO, PIXEL_FILL(1));
        PutWindowTilemap(WIN_INFO);
        if (view->objective != NULL)
            Print(WIN_INFO, 0, view->objective->where);
        Print(WIN_INFO, 56, view->pinned ? sAccess : sExplanations[kind <= STORY_DESTINATION_DYNAMIC ? kind : STORY_DESTINATION_DYNAMIC]);
        Print(WIN_CONTROLS, 0, view->pinned ? sInfoControls : sBackControls);
        CopyWindowToVram(WIN_INFO, COPYWIN_FULL);
    }
    else
    {
        ClearWindowTilemap(WIN_INFO);
        ShowBg(2);
        Print(WIN_CONTROLS, 0, sMapControls);
    }
    if (view->map.cursorSprite != NULL)
        view->map.cursorSprite->invisible = view->info;
    if (view->map.playerIconSprite != NULL)
        view->map.playerIconSprite->invisible = view->info;
    CopyWindowToVram(WIN_TITLE, COPYWIN_FULL);
    CopyWindowToVram(WIN_CONTROLS, COPYWIN_FULL);
}

static void VBlank(void)
{
    LoadOam();
    ProcessSpriteCopyRequests();
    TransferPlttBuffer();
}

static void Task_Close(u8 taskId)
{
    MainCallback callback;
    if (gPaletteFade.active)
        return;
    SetVBlankCallback(NULL);
    callback = sStoryDestinationMap->returnCallback;
    if (sStoryDestinationMap->pinned)
        FreeRegionMapIconResources();
    FreeAllWindowBuffers();
    FREE_AND_SET_NULL(sStoryDestinationMap);
    DestroyTask(taskId);
    SetMainCallback2(callback);
}

static void Task_Input(u8 taskId)
{
    if (gPaletteFade.active)
        return;
    if (JOY_NEW(B_BUTTON))
    {
        PlaySE(SE_SELECT);
        BeginNormalPaletteFade(PALETTES_ALL, 0, 0, 16, RGB_BLACK);
        gTasks[taskId].func = Task_Close;
    }
    else if (JOY_NEW(A_BUTTON) && sStoryDestinationMap->pinned)
    {
        PlaySE(SE_SELECT);
        sStoryDestinationMap->info = !sStoryDestinationMap->info;
        Draw();
    }
}

static void CB2_StoryDestinationMap(void)
{
    RunTasks();
    AnimateSprites();
    if (sStoryDestinationMap != NULL && sStoryDestinationMap->map.playerIconSprite != NULL)
        sStoryDestinationMap->map.playerIconSprite->invisible = sStoryDestinationMap->info;
    BuildOamBuffer();
    UpdatePaletteFade();
}

static void CB2_InitDestinationMap(void)
{
    struct StoryDestinationMap *view = sStoryDestinationMap;
    const struct StoryDestination *destination = StoryProgress_GetDestination(view->objective);
    u8 i;
    SetVBlankCallback(NULL);
    SetGpuReg(REG_OFFSET_DISPCNT, 0);
    SetGpuReg(REG_OFFSET_BLDCNT, 0);
    SetGpuReg(REG_OFFSET_BLDY, 0);
    ResetBgsAndClearDma3BusyFlags(0);
    for (i = 0; i < 4; i++)
    {
        ChangeBgX(i, 0, BG_COORD_SET);
        ChangeBgY(i, 0, BG_COORD_SET);
    }
    DmaClearLarge16(3, (void *)VRAM, VRAM_SIZE, 0x1000);
    ResetTasks();
    ResetSpriteData();
    FreeAllSpritePalettes();
    ResetPaletteFade();
    ScanlineEffect_Stop();
    InitBgsFromTemplates(1, sBgs, ARRAY_COUNT(sBgs));
    InitWindows(sWindows);
    DeactivateAllTextPrinters();
    WorldMenu_LoadTextPalette(1);
    if (destination->kind == STORY_DESTINATION_PIN)
    {
        InitRegionMapDataForType(&view->map, NULL, FALSE, GetRegionMapType(destination->mapSecId));
        while (LoadRegionMapGfx());
        view->pinned = RegionMap_SetDestination(destination->mapSecId);
        if (view->pinned)
        {
            if (view->map.playerOnMap)
                CreateRegionMapPlayerIcon(0, 0);
            CreateRegionMapCursor(1, 1);
        }
    }
    view->info = !view->pinned;
    Draw();
    ShowBg(0);
    SetGpuRegBits(REG_OFFSET_DISPCNT, DISPCNT_OBJ_1D_MAP | DISPCNT_OBJ_ON);
    BeginNormalPaletteFade(PALETTES_ALL, 0, 16, 0, RGB_BLACK);
    CreateTask(Task_Input, 0);
    SetVBlankCallback(VBlank);
    SetMainCallback2(CB2_StoryDestinationMap);
}

void ShowStoryDestinationMap(const struct StoryObjective *objective, void (*returnCallback)(void))
{
    sStoryDestinationMap = AllocZeroed(sizeof(*sStoryDestinationMap));
    if (sStoryDestinationMap == NULL)
    {
        SetMainCallback2(returnCallback);
        return;
    }
    sStoryDestinationMap->objective = objective;
    sStoryDestinationMap->returnCallback = returnCallback;
    SetMainCallback2(CB2_InitDestinationMap);
}
