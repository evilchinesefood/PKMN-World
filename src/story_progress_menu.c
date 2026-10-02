#include "global.h"
#include "story_progress.h"
#include "bg.h"
#include "gpu_regs.h"
#include "main.h"
#include "menu.h"
#include "menu_helpers.h"
#include "palette.h"
#include "scanline_effect.h"
#include "sound.h"
#include "sprite.h"
#include "string_util.h"
#include "task.h"
#include "text.h"
#include "window.h"
#include "world_menu_theme.h"
#include "constants/rgb.h"
#include "constants/songs.h"

enum { WIN_HEADER, WIN_BODY, WIN_FOOTER };
static const struct BgTemplate sStoryBgs[] = {
    {.bg = 0, .charBaseIndex = 2, .mapBaseIndex = 31, .priority = 0},
};
static const struct WindowTemplate sStoryWindows[] = {
    {0, 1, 1, 28, 2, 12, 1},
    {0, 1, 4, 28, 13, 1, 57},
    {0, 1, 18, 28, 2, 1, 421},
    DUMMY_WIN_TEMPLATE,
};
static const u8 sColors[] = {1, 2, 3};
static const u8 sAccent[] = {1, 4, 3};
static const u8 sKanto[] = _("Kanto");
static const u8 sJohto[] = _("Johto");
static const u8 sHoenn[] = _("Hoenn");
static const u8 *const sRegions[] = {sKanto, sJohto, sHoenn};
static const u8 sNotStarted[] = _("Not started");
static const u8 sInProgress[] = _("In progress");
static const u8 sComplete[] = _("Main story complete");
static const u8 *const sStatus[] = {sNotStarted, sInProgress, sComplete};
static const u8 sOverview[] = _("Story Progress");
static const u8 sOverviewControls[] = _("Up/Down: region   A: details   B: back");
static const u8 sDetailControls[] = _("Left/Right: page   Up/Down: region   B: back");
static const u8 sChapter[] = _("Chapter");
static const u8 sNext[] = _("Next action");
static const u8 sWhere[] = _("Where / who");
static const u8 sWhy[] = _("Why / prerequisite");
static const u8 sRecap[] = _("Last established milestone");
static const u8 sProgress[] = _("Progress");
static const u8 sOptionalNext[] = _("Optional: next action");
static const u8 sOptionalWhy[] = _("Optional: prerequisite");
static const u8 sLeagueNotCleared[] = _("Regional League: not cleared.");
static const u8 sLeagueCleared[] = _("Regional League: Champion.");
static const u8 sBadges[] = _("Badges: ");
static const u8 sEight[] = _("/8");
static const u8 sSpace[] = _("  ");
static const u8 sPage[] = _(" - page ");
static const u8 sSlash[] = _("/");

static EWRAM_DATA struct StoryProgress sStoryProgress[3] = {0};
static EWRAM_DATA void (*sStoryReturnCallback)(void) = NULL;
static EWRAM_DATA u8 sStoryRegion = 0;
static EWRAM_DATA u8 sStoryPage = 0;
static EWRAM_DATA bool8 sStoryDetail = FALSE;
static EWRAM_DATA u8 sStoryBuffer[128] = {0};

static void CB2_InitStory(void);

static void Print(u8 window, u8 x, u8 y, const u8 *text, bool8 accent)
{
    AddTextPrinterParameterized3(window, FONT_SMALL, x, y, accent ? sAccent : sColors, TEXT_SKIP_DRAW, text);
}

static void FirstLine(const u8 *text)
{
    u32 i;
    for (i = 0; i < sizeof(sStoryBuffer) - 1 && text[i] != EOS && text[i] != CHAR_NEWLINE; i++)
        sStoryBuffer[i] = text[i];
    sStoryBuffer[i] = EOS;
}

static u8 PageCount(void) { return sStoryProgress[sStoryRegion].optional ? 5 : 3; }

static void Draw(void)
{
    const struct StoryProgress *progress = &sStoryProgress[sStoryRegion];
    const struct StoryObjective *objective = progress->objective;
    u8 i;
    FillWindowPixelBuffer(WIN_BODY, PIXEL_FILL(1));
    FillWindowPixelBuffer(WIN_FOOTER, PIXEL_FILL(1));
    PutWindowTilemap(WIN_BODY);
    PutWindowTilemap(WIN_FOOTER);
    if (!sStoryDetail)
    {
        WorldMenu_DrawHeader(WIN_HEADER, sOverview);
        for (i = 0; i < 3; i++)
        {
            StringCopy(sStoryBuffer, sRegions[i]);
            StringAppend(sStoryBuffer, sSpace);
            ConvertIntToDecimalStringN(sStoryBuffer + StringLength(sStoryBuffer), sStoryProgress[i].badges, STR_CONV_MODE_LEFT_ALIGN, 1);
            StringAppend(sStoryBuffer, sEight);
            Print(WIN_BODY, 8, i * 32 + 1, sStoryBuffer, FALSE);
            Print(WIN_BODY, 88, i * 32 + 1, sStatus[sStoryProgress[i].status], FALSE);
            FirstLine(sStoryProgress[i].objective->action);
            Print(WIN_BODY, 8, i * 32 + 16, sStoryBuffer, FALSE);
        }
        PutWindowRectTilemapOverridePalette(WIN_BODY, 0, sStoryRegion * 4, 28, 4, 2);
        Print(WIN_FOOTER, 2, 2, sOverviewControls, FALSE);
    }
    else
    {
        StringCopy(sStoryBuffer, sRegions[sStoryRegion]);
        StringAppend(sStoryBuffer, sPage);
        ConvertIntToDecimalStringN(sStoryBuffer + StringLength(sStoryBuffer), sStoryPage + 1, STR_CONV_MODE_LEFT_ALIGN, 1);
        StringAppend(sStoryBuffer, sSlash);
        ConvertIntToDecimalStringN(sStoryBuffer + StringLength(sStoryBuffer), PageCount(), STR_CONV_MODE_LEFT_ALIGN, 1);
        WorldMenu_DrawHeader(WIN_HEADER, sStoryBuffer);
        switch (sStoryPage)
        {
        case 0:
            Print(WIN_BODY, 8, 0, progress->status == STORY_COMPLETE ? sComplete : sChapter, TRUE);
            Print(WIN_BODY, 8, 12, objective->chapter, FALSE);
            Print(WIN_BODY, 8, 52, sNext, TRUE);
            Print(WIN_BODY, 8, 64, objective->action, FALSE);
            break;
        case 1:
            Print(WIN_BODY, 8, 0, sWhere, TRUE);
            Print(WIN_BODY, 8, 12, objective->where, FALSE);
            Print(WIN_BODY, 8, 52, sWhy, TRUE);
            Print(WIN_BODY, 8, 64, objective->why, FALSE);
            break;
        case 2:
            Print(WIN_BODY, 8, 0, sRecap, TRUE);
            Print(WIN_BODY, 8, 12, objective->recap, FALSE);
            Print(WIN_BODY, 8, 52, sProgress, TRUE);
            StringCopy(sStoryBuffer, sBadges);
            ConvertIntToDecimalStringN(sStoryBuffer + StringLength(sStoryBuffer), progress->badges, STR_CONV_MODE_LEFT_ALIGN, 1);
            StringAppend(sStoryBuffer, sEight);
            Print(WIN_BODY, 8, 64, sStoryBuffer, FALSE);
            Print(WIN_BODY, 8, 80, progress->status == STORY_COMPLETE ? sLeagueCleared : sLeagueNotCleared, FALSE);
            break;
        case 3:
            objective = progress->optional;
            Print(WIN_BODY, 8, 0, sOptionalNext, TRUE);
            Print(WIN_BODY, 8, 12, objective->action, FALSE);
            Print(WIN_BODY, 8, 52, sWhere, TRUE);
            Print(WIN_BODY, 8, 64, objective->where, FALSE);
            break;
        case 4:
            objective = progress->optional;
            Print(WIN_BODY, 8, 0, sOptionalWhy, TRUE);
            Print(WIN_BODY, 8, 12, objective->why, FALSE);
            Print(WIN_BODY, 8, 52, sRecap, TRUE);
            Print(WIN_BODY, 8, 64, objective->recap, FALSE);
            break;
        }
        Print(WIN_FOOTER, 2, 2, sDetailControls, FALSE);
    }
    WorldMenu_RoundWindowTopCorners(WIN_FOOTER);
    CopyWindowToVram(WIN_BODY, COPYWIN_FULL);
    CopyWindowToVram(WIN_FOOTER, COPYWIN_FULL);
}

static void Task_StoryClose(u8 taskId)
{
    if (!gPaletteFade.active)
    {
        SetVBlankCallback(NULL);
        FreeAllWindowBuffers();
        DestroyTask(taskId);
        SetMainCallback2(sStoryReturnCallback);
    }
}

static void Task_StoryInput(u8 taskId)
{
    if (gPaletteFade.active) return;
    if (JOY_NEW(B_BUTTON))
    {
        if (sStoryDetail) sStoryDetail = FALSE;
        else
        {
            BeginNormalPaletteFade(PALETTES_ALL, 0, 0, 16, RGB_BLACK);
            gTasks[taskId].func = Task_StoryClose;
            return;
        }
    }
    else if (JOY_NEW(DPAD_UP)) { sStoryRegion = (sStoryRegion + 2) % 3; sStoryPage = 0; }
    else if (JOY_NEW(DPAD_DOWN)) { sStoryRegion = (sStoryRegion + 1) % 3; sStoryPage = 0; }
    else if (JOY_NEW(A_BUTTON) && !sStoryDetail) { sStoryDetail = TRUE; sStoryPage = 0; }
    else if (sStoryDetail && JOY_NEW(DPAD_RIGHT | R_BUTTON)) sStoryPage = (sStoryPage + 1) % PageCount();
    else if (sStoryDetail && JOY_NEW(DPAD_LEFT | L_BUTTON)) sStoryPage = (sStoryPage + PageCount() - 1) % PageCount();
    else return;
    PlaySE(SE_SELECT);
    Draw();
}

static void VBlank_Story(void) { LoadOam(); ProcessSpriteCopyRequests(); TransferPlttBuffer(); }
static void CB2_Story(void)
{
    RunTasks(); AnimateSprites(); BuildOamBuffer(); UpdatePaletteFade(); WorldMenu_UpdateBackground();
}

static void CB2_InitStory(void)
{
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
    InitBgsFromTemplates(0, sStoryBgs, ARRAY_COUNT(sStoryBgs));
    InitWindows(sStoryWindows);
    DeactivateAllTextPrinters();
    ResetTasks(); ResetSpriteData(); ResetPaletteFade(); ScanlineEffect_Stop();
    WorldMenu_LoadTextPalette(1); WorldMenu_LoadSelectedPalette(2);
    SetGpuReg(REG_OFFSET_DISPCNT, DISPCNT_OBJ_1D_MAP | DISPCNT_OBJ_ON);
    WorldMenu_InitBackground(0);
    for (i = 0; i < 3; i++) StoryProgress_Resolve(REGION_KANTO + i, &sStoryProgress[i]);
    sStoryRegion = StoryProgress_DefaultRegion() - REGION_KANTO;
    sStoryPage = 0; sStoryDetail = FALSE;
    Draw();
    ShowBg(0);
    BeginNormalPaletteFade(PALETTES_ALL, 0, 16, 0, RGB_BLACK);
    CreateTask(Task_StoryInput, 0);
    SetVBlankCallback(VBlank_Story);
    SetMainCallback2(CB2_Story);
}

void ShowStoryProgress(void (*returnCallback)(void))
{
    sStoryReturnCallback = returnCallback;
    SetMainCallback2(CB2_InitStory);
}
