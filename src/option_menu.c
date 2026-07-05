#include "global.h"
#include "option_menu.h"
#include "bg.h"
#include "gpu_regs.h"
#include "international_string_util.h"
#include "list_menu.h"
#include "main.h"
#include "menu.h"
#include "palette.h"
#include "scanline_effect.h"
#include "sprite.h"
#include "strings.h"
#include "task.h"
#include "text.h"
#include "text_window.h"
#include "window.h"
#include "gba/m4a_internal.h"
#include "constants/rgb.h"

#define tMenuSelection data[0]
#define tTextSpeed data[1]
#define tBattleSceneOff data[2]
#define tBattleStyle data[3]
#define tSound data[4]
#define tButtonMode data[5]
#define tWindowFrameType data[6]
#define tScrollOffset data[7]      // top visible MENUITEM_ index (0 when not scrolled)
#define tScrollArrowTaskId data[8] // TASK_NONE unless scroll arrows are active
#define tAutoRun data[9]
#define tAutosave data[10]
#define tRunShortcut data[11]
#define tHardMode data[12]
#define tExpMult data[13]
#define tCatchMult data[14]

#define NUM_VISIBLE_OPTIONS 7

enum
{
    MENUITEM_TEXTSPEED,
    MENUITEM_BATTLESCENE,
    MENUITEM_BATTLESTYLE,
    MENUITEM_SOUND,
    MENUITEM_BUTTONMODE,
    MENUITEM_FRAMETYPE,
    MENUITEM_AUTORUN,
    MENUITEM_AUTOSAVE,
    MENUITEM_RUNSHORTCUT,
    MENUITEM_HARDMODE,
    MENUITEM_EXPMULT,
    MENUITEM_CATCHMULT,
    MENUITEM_CANCEL,
    MENUITEM_COUNT,
};

enum
{
    WIN_HEADER,
    WIN_OPTIONS
};

static void Task_OptionMenuFadeIn(u8 taskId);
static void Task_OptionMenuProcessInput(u8 taskId);
static void Task_OptionMenuSave(u8 taskId);
static void Task_OptionMenuFadeOut(u8 taskId);
static void HighlightOptionMenuItem(u8 selection);
static bool8 GetOptionMenuItemY(u8 menuItem, s16 scrollOffset, u8 *y);
static void RedrawVisibleOptionsPage(u8 taskId);
static bool8 AdjustOptionMenuScrollOffset(u8 taskId);
static void CreateOptionMenuScrollArrows(u8 taskId);
static u8 TextSpeed_ProcessInput(u8 selection);
static void TextSpeed_DrawChoices(u8 selection, s16 scrollOffset);
static u8 BattleScene_ProcessInput(u8 selection);
static void BattleScene_DrawChoices(u8 selection, s16 scrollOffset);
static u8 BattleStyle_ProcessInput(u8 selection);
static void BattleStyle_DrawChoices(u8 selection, s16 scrollOffset);
static u8 Sound_ProcessInput(u8 selection);
static void Sound_DrawChoices(u8 selection, s16 scrollOffset);
static u8 FrameType_ProcessInput(u8 selection);
static void FrameType_DrawChoices(u8 selection, s16 scrollOffset);
static u8 ButtonMode_ProcessInput(u8 selection);
static void ButtonMode_DrawChoices(u8 selection, s16 scrollOffset);
static u8 AutoRun_ProcessInput(u8 selection);
static void AutoRun_DrawChoices(u8 selection, s16 scrollOffset);
static u8 Autosave_ProcessInput(u8 selection);
static void Autosave_DrawChoices(u8 selection, s16 scrollOffset);
static u8 RunShortcut_ProcessInput(u8 selection);
static void RunShortcut_DrawChoices(u8 selection, s16 scrollOffset);
static u8 HardMode_ProcessInput(u8 selection);
static void HardMode_DrawChoices(u8 selection, s16 scrollOffset);
static u8 ExpMult_ProcessInput(u8 selection);
static void ExpMult_DrawChoices(u8 selection, s16 scrollOffset);
static u8 CatchMult_ProcessInput(u8 selection);
static void CatchMult_DrawChoices(u8 selection, s16 scrollOffset);
static void DrawHeaderText(void);
static void DrawOptionMenuTexts(s16 scrollOffset);
static void DrawBgWindowFrames(void);

EWRAM_DATA static bool8 sArrowPressed = FALSE;

static const u8 gText_Option[]             = _("OPTION");
static const u8 gText_TextSpeedSlow[]      = _("{COLOR GREEN}{SHADOW LIGHT_GREEN}SLOW");
static const u8 gText_TextSpeedMid[]       = _("{COLOR GREEN}{SHADOW LIGHT_GREEN}MID");
static const u8 gText_TextSpeedFast[]      = _("{COLOR GREEN}{SHADOW LIGHT_GREEN}FAST");
static const u8 gText_BattleSceneOn[]      = _("{COLOR GREEN}{SHADOW LIGHT_GREEN}ON");
static const u8 gText_BattleSceneOff[]     = _("{COLOR GREEN}{SHADOW LIGHT_GREEN}OFF");
static const u8 gText_BattleStyleShift[]   = _("{COLOR GREEN}{SHADOW LIGHT_GREEN}SHIFT");
static const u8 gText_BattleStyleSet[]     = _("{COLOR GREEN}{SHADOW LIGHT_GREEN}SET");
static const u8 gText_SoundMono[]          = _("{COLOR GREEN}{SHADOW LIGHT_GREEN}MONO");
static const u8 gText_SoundStereo[]        = _("{COLOR GREEN}{SHADOW LIGHT_GREEN}STEREO");
static const u8 gText_FrameType[]          = _("{COLOR GREEN}{SHADOW LIGHT_GREEN}TYPE");
static const u8 gText_FrameTypeNumber[]    = _("{COLOR GREEN}{SHADOW LIGHT_GREEN}");
static const u8 gText_ButtonTypeNormal[]   = _("{COLOR GREEN}{SHADOW LIGHT_GREEN}NORMAL");
static const u8 gText_ButtonTypeLR[]       = _("{COLOR GREEN}{SHADOW LIGHT_GREEN}LR");
static const u8 gText_ButtonTypeLEqualsA[] = _("{COLOR GREEN}{SHADOW LIGHT_GREEN}L=A");
static const u8 gText_RunShortcutCursor[]  = _("{COLOR GREEN}{SHADOW LIGHT_GREEN}CURSOR");
static const u8 gText_RunShortcutInstant[] = _("{COLOR GREEN}{SHADOW LIGHT_GREEN}INSTANT");
static const u8 gText_Mult0_5x[]           = _("{COLOR GREEN}{SHADOW LIGHT_GREEN}0.5x");
static const u8 gText_Mult1x[]             = _("{COLOR GREEN}{SHADOW LIGHT_GREEN}1x");
static const u8 gText_Mult1_5x[]           = _("{COLOR GREEN}{SHADOW LIGHT_GREEN}1.5x");
static const u8 gText_Mult2x[]             = _("{COLOR GREEN}{SHADOW LIGHT_GREEN}2x");

static const u16 sOptionMenuText_Pal[] = INCGFX_U16("graphics/interface/option_menu_text.pal", ".gbapal");
// note: this is only used in the Japanese release
static const u8 sEqualSignGfx[] = INCGFX_U8("graphics/interface/option_menu_equals_sign.png", ".4bpp");

static const u8 *const sOptionMenuItemsNames[MENUITEM_COUNT] =
{
    [MENUITEM_TEXTSPEED]   = COMPOUND_STRING("TEXT SPEED"),
    [MENUITEM_BATTLESCENE] = COMPOUND_STRING("BATTLE SCENE"),
    [MENUITEM_BATTLESTYLE] = COMPOUND_STRING("BATTLE STYLE"),
    [MENUITEM_SOUND]       = COMPOUND_STRING("SOUND"),
    [MENUITEM_BUTTONMODE]  = COMPOUND_STRING("BUTTON MODE"),
    [MENUITEM_FRAMETYPE]   = COMPOUND_STRING("FRAME"),
    [MENUITEM_AUTORUN]     = COMPOUND_STRING("AUTO RUN"),
    [MENUITEM_AUTOSAVE]    = COMPOUND_STRING("AUTOSAVE"),
    [MENUITEM_RUNSHORTCUT] = COMPOUND_STRING("RUN SHORTCUT"),
    [MENUITEM_HARDMODE]    = COMPOUND_STRING("HARD MODE"),
    [MENUITEM_EXPMULT]     = COMPOUND_STRING("EXP GAIN"),
    [MENUITEM_CATCHMULT]   = COMPOUND_STRING("CATCH RATE"),
    [MENUITEM_CANCEL]      = COMPOUND_STRING("CANCEL"),
};

static const struct WindowTemplate sOptionMenuWinTemplates[] =
{
    [WIN_HEADER] = {
        .bg = 1,
        .tilemapLeft = 2,
        .tilemapTop = 1,
        .width = 26,
        .height = 2,
        .paletteNum = 1,
        .baseBlock = 2
    },
    [WIN_OPTIONS] = {
        .bg = 0,
        .tilemapLeft = 2,
        .tilemapTop = 5,
        .width = 26,
        .height = 14,
        .paletteNum = 1,
        .baseBlock = 0x36
    },
    DUMMY_WIN_TEMPLATE
};

static const struct BgTemplate sOptionMenuBgTemplates[] =
{
    {
        .bg = 1,
        .charBaseIndex = 1,
        .mapBaseIndex = 30,
        .screenSize = 0,
        .paletteMode = 0,
        .priority = 0,
        .baseTile = 0
    },
    {
        .bg = 0,
        .charBaseIndex = 1,
        .mapBaseIndex = 31,
        .screenSize = 0,
        .paletteMode = 0,
        .priority = 1,
        .baseTile = 0
    }
};

static const u16 sOptionMenuBg_Pal[] = {RGB(17, 18, 31)};

static void MainCB2(void)
{
    RunTasks();
    AnimateSprites();
    BuildOamBuffer();
    UpdatePaletteFade();
}

static void VBlankCB(void)
{
    LoadOam();
    ProcessSpriteCopyRequests();
    TransferPlttBuffer();
}

void CB2_InitOptionMenu(void)
{
    switch (gMain.state)
    {
    default:
    case 0:
        SetVBlankCallback(NULL);
        gMain.state++;
        break;
    case 1:
        DmaClearLarge16(3, (void *)(VRAM), VRAM_SIZE, 0x1000);
        DmaClear32(3, OAM, OAM_SIZE);
        DmaClear16(3, PLTT, PLTT_SIZE);
        SetGpuReg(REG_OFFSET_DISPCNT, 0);
        ResetBgsAndClearDma3BusyFlags(0);
        InitBgsFromTemplates(0, sOptionMenuBgTemplates, ARRAY_COUNT(sOptionMenuBgTemplates));
        ChangeBgX(0, 0, BG_COORD_SET);
        ChangeBgY(0, 0, BG_COORD_SET);
        ChangeBgX(1, 0, BG_COORD_SET);
        ChangeBgY(1, 0, BG_COORD_SET);
        ChangeBgX(2, 0, BG_COORD_SET);
        ChangeBgY(2, 0, BG_COORD_SET);
        ChangeBgX(3, 0, BG_COORD_SET);
        ChangeBgY(3, 0, BG_COORD_SET);
        InitWindows(sOptionMenuWinTemplates);
        DeactivateAllTextPrinters();
        SetGpuReg(REG_OFFSET_WIN0H, 0);
        SetGpuReg(REG_OFFSET_WIN0V, 0);
        SetGpuReg(REG_OFFSET_WININ, WININ_WIN0_BG0);
        SetGpuReg(REG_OFFSET_WINOUT, WINOUT_WIN01_BG0 | WINOUT_WIN01_BG1 | WINOUT_WIN01_CLR);
        SetGpuReg(REG_OFFSET_BLDCNT, BLDCNT_TGT1_BG0 | BLDCNT_EFFECT_DARKEN);
        SetGpuReg(REG_OFFSET_BLDALPHA, 0);
        SetGpuReg(REG_OFFSET_BLDY, 4);
        SetGpuReg(REG_OFFSET_DISPCNT, DISPCNT_WIN0_ON | DISPCNT_OBJ_ON | DISPCNT_OBJ_1D_MAP);
        ShowBg(0);
        ShowBg(1);
        gMain.state++;
        break;
    case 2:
        ResetPaletteFade();
        ScanlineEffect_Stop();
        ResetTasks();
        ResetSpriteData();
        gMain.state++;
        break;
    case 3:
        LoadBgTiles(1, GetWindowFrameTilesPal(gSaveBlock2Ptr->optionsWindowFrameType)->tiles, 0x120, 0x1A2);
        gMain.state++;
        break;
    case 4:
        LoadPalette(sOptionMenuBg_Pal, BG_PLTT_ID(0), sizeof(sOptionMenuBg_Pal));
        LoadPalette(GetWindowFrameTilesPal(gSaveBlock2Ptr->optionsWindowFrameType)->pal, BG_PLTT_ID(7), PLTT_SIZE_4BPP);
        gMain.state++;
        break;
    case 5:
        LoadPalette(sOptionMenuText_Pal, BG_PLTT_ID(1), sizeof(sOptionMenuText_Pal));
        gMain.state++;
        break;
    case 6:
        PutWindowTilemap(WIN_HEADER);
        DrawHeaderText();
        gMain.state++;
        break;
    case 7:
        gMain.state++;
        break;
    case 8:
        PutWindowTilemap(WIN_OPTIONS);
        gMain.state++;
    case 9:
        DrawBgWindowFrames();
        gMain.state++;
        break;
    case 10:
    {
        u8 taskId = CreateTask(Task_OptionMenuFadeIn, 0);

        gTasks[taskId].tMenuSelection = 0;
        gTasks[taskId].tTextSpeed = gSaveBlock2Ptr->optionsTextSpeed;
        gTasks[taskId].tBattleSceneOff = gSaveBlock2Ptr->optionsBattleSceneOff;
        gTasks[taskId].tBattleStyle = gSaveBlock2Ptr->optionsBattleStyle;
        gTasks[taskId].tSound = gSaveBlock2Ptr->optionsSound;
        gTasks[taskId].tButtonMode = gSaveBlock2Ptr->optionsButtonMode;
        gTasks[taskId].tWindowFrameType = gSaveBlock2Ptr->optionsWindowFrameType;
        gTasks[taskId].tAutoRun = gSaveBlock2Ptr->optionsAutoRun;
        gTasks[taskId].tAutosave = gSaveBlock2Ptr->optionsAutosave;
        gTasks[taskId].tRunShortcut = gSaveBlock2Ptr->optionsRunShortcut;
        gTasks[taskId].tHardMode = gSaveBlock2Ptr->optionsHardMode;
        gTasks[taskId].tExpMult = gSaveBlock2Ptr->optionsExpMultiplier;
        gTasks[taskId].tCatchMult = gSaveBlock2Ptr->optionsCatchMultiplier;
        gTasks[taskId].tScrollOffset = 0;

        RedrawVisibleOptionsPage(taskId);
        CreateOptionMenuScrollArrows(taskId);

        gMain.state++;
        break;
    }
    case 11:
        BeginNormalPaletteFade(PALETTES_ALL, 0, 16, 0, RGB_BLACK);
        SetVBlankCallback(VBlankCB);
        SetMainCallback2(MainCB2);
        return;
    }
}

static void Task_OptionMenuFadeIn(u8 taskId)
{
    if (!gPaletteFade.active)
        gTasks[taskId].func = Task_OptionMenuProcessInput;
}

static void Task_OptionMenuProcessInput(u8 taskId)
{
    if (JOY_NEW(A_BUTTON))
    {
        if (gTasks[taskId].tMenuSelection == MENUITEM_CANCEL)
            gTasks[taskId].func = Task_OptionMenuSave;
    }
    else if (JOY_NEW(B_BUTTON))
    {
        gTasks[taskId].func = Task_OptionMenuSave;
    }
    else if (JOY_NEW(DPAD_UP))
    {
        if (gTasks[taskId].tMenuSelection > 0)
            gTasks[taskId].tMenuSelection--;
        else
            gTasks[taskId].tMenuSelection = MENUITEM_CANCEL;

        if (AdjustOptionMenuScrollOffset(taskId))
            RedrawVisibleOptionsPage(taskId);
        else
            HighlightOptionMenuItem(gTasks[taskId].tMenuSelection - gTasks[taskId].tScrollOffset);
    }
    else if (JOY_NEW(DPAD_DOWN))
    {
        if (gTasks[taskId].tMenuSelection < MENUITEM_CANCEL)
            gTasks[taskId].tMenuSelection++;
        else
            gTasks[taskId].tMenuSelection = 0;

        if (AdjustOptionMenuScrollOffset(taskId))
            RedrawVisibleOptionsPage(taskId);
        else
            HighlightOptionMenuItem(gTasks[taskId].tMenuSelection - gTasks[taskId].tScrollOffset);
    }
    else
    {
        u8 previousOption;

        switch (gTasks[taskId].tMenuSelection)
        {
        case MENUITEM_TEXTSPEED:
            previousOption = gTasks[taskId].tTextSpeed;
            gTasks[taskId].tTextSpeed = TextSpeed_ProcessInput(gTasks[taskId].tTextSpeed);

            if (previousOption != gTasks[taskId].tTextSpeed)
                TextSpeed_DrawChoices(gTasks[taskId].tTextSpeed, gTasks[taskId].tScrollOffset);
            break;
        case MENUITEM_BATTLESCENE:
            previousOption = gTasks[taskId].tBattleSceneOff;
            gTasks[taskId].tBattleSceneOff = BattleScene_ProcessInput(gTasks[taskId].tBattleSceneOff);

            if (previousOption != gTasks[taskId].tBattleSceneOff)
                BattleScene_DrawChoices(gTasks[taskId].tBattleSceneOff, gTasks[taskId].tScrollOffset);
            break;
        case MENUITEM_BATTLESTYLE:
            previousOption = gTasks[taskId].tBattleStyle;
            gTasks[taskId].tBattleStyle = BattleStyle_ProcessInput(gTasks[taskId].tBattleStyle);

            if (previousOption != gTasks[taskId].tBattleStyle)
                BattleStyle_DrawChoices(gTasks[taskId].tBattleStyle, gTasks[taskId].tScrollOffset);
            break;
        case MENUITEM_SOUND:
            previousOption = gTasks[taskId].tSound;
            gTasks[taskId].tSound = Sound_ProcessInput(gTasks[taskId].tSound);

            if (previousOption != gTasks[taskId].tSound)
                Sound_DrawChoices(gTasks[taskId].tSound, gTasks[taskId].tScrollOffset);
            break;
        case MENUITEM_BUTTONMODE:
            previousOption = gTasks[taskId].tButtonMode;
            gTasks[taskId].tButtonMode = ButtonMode_ProcessInput(gTasks[taskId].tButtonMode);

            if (previousOption != gTasks[taskId].tButtonMode)
                ButtonMode_DrawChoices(gTasks[taskId].tButtonMode, gTasks[taskId].tScrollOffset);
            break;
        case MENUITEM_FRAMETYPE:
            previousOption = gTasks[taskId].tWindowFrameType;
            gTasks[taskId].tWindowFrameType = FrameType_ProcessInput(gTasks[taskId].tWindowFrameType);

            if (previousOption != gTasks[taskId].tWindowFrameType)
                FrameType_DrawChoices(gTasks[taskId].tWindowFrameType, gTasks[taskId].tScrollOffset);
            break;
        case MENUITEM_AUTORUN:
            previousOption = gTasks[taskId].tAutoRun;
            gTasks[taskId].tAutoRun = AutoRun_ProcessInput(gTasks[taskId].tAutoRun);

            if (previousOption != gTasks[taskId].tAutoRun)
                AutoRun_DrawChoices(gTasks[taskId].tAutoRun, gTasks[taskId].tScrollOffset);
            break;
        case MENUITEM_AUTOSAVE:
            previousOption = gTasks[taskId].tAutosave;
            gTasks[taskId].tAutosave = Autosave_ProcessInput(gTasks[taskId].tAutosave);

            if (previousOption != gTasks[taskId].tAutosave)
                Autosave_DrawChoices(gTasks[taskId].tAutosave, gTasks[taskId].tScrollOffset);
            break;
        case MENUITEM_RUNSHORTCUT:
            previousOption = gTasks[taskId].tRunShortcut;
            gTasks[taskId].tRunShortcut = RunShortcut_ProcessInput(gTasks[taskId].tRunShortcut);

            if (previousOption != gTasks[taskId].tRunShortcut)
                RunShortcut_DrawChoices(gTasks[taskId].tRunShortcut, gTasks[taskId].tScrollOffset);
            break;
        case MENUITEM_HARDMODE:
            previousOption = gTasks[taskId].tHardMode;
            gTasks[taskId].tHardMode = HardMode_ProcessInput(gTasks[taskId].tHardMode);

            if (previousOption != gTasks[taskId].tHardMode)
                HardMode_DrawChoices(gTasks[taskId].tHardMode, gTasks[taskId].tScrollOffset);
            break;
        case MENUITEM_EXPMULT:
            previousOption = gTasks[taskId].tExpMult;
            gTasks[taskId].tExpMult = ExpMult_ProcessInput(gTasks[taskId].tExpMult);

            if (previousOption != gTasks[taskId].tExpMult)
                ExpMult_DrawChoices(gTasks[taskId].tExpMult, gTasks[taskId].tScrollOffset);
            break;
        case MENUITEM_CATCHMULT:
            previousOption = gTasks[taskId].tCatchMult;
            gTasks[taskId].tCatchMult = CatchMult_ProcessInput(gTasks[taskId].tCatchMult);

            if (previousOption != gTasks[taskId].tCatchMult)
                CatchMult_DrawChoices(gTasks[taskId].tCatchMult, gTasks[taskId].tScrollOffset);
            break;
        default:
            return;
        }

        if (sArrowPressed)
        {
            sArrowPressed = FALSE;
            CopyWindowToVram(WIN_OPTIONS, COPYWIN_GFX);
        }
    }
}

static void Task_OptionMenuSave(u8 taskId)
{
    gSaveBlock2Ptr->optionsTextSpeed = gTasks[taskId].tTextSpeed;
    gSaveBlock2Ptr->optionsBattleSceneOff = gTasks[taskId].tBattleSceneOff;
    gSaveBlock2Ptr->optionsBattleStyle = gTasks[taskId].tBattleStyle;
    gSaveBlock2Ptr->optionsSound = gTasks[taskId].tSound;
    gSaveBlock2Ptr->optionsButtonMode = gTasks[taskId].tButtonMode;
    gSaveBlock2Ptr->optionsWindowFrameType = gTasks[taskId].tWindowFrameType;
    gSaveBlock2Ptr->optionsAutoRun = gTasks[taskId].tAutoRun;
    gSaveBlock2Ptr->optionsAutosave = gTasks[taskId].tAutosave;
    gSaveBlock2Ptr->optionsRunShortcut = gTasks[taskId].tRunShortcut;
    gSaveBlock2Ptr->optionsHardMode = gTasks[taskId].tHardMode;
    gSaveBlock2Ptr->optionsExpMultiplier = gTasks[taskId].tExpMult;
    gSaveBlock2Ptr->optionsCatchMultiplier = gTasks[taskId].tCatchMult;

    if (gTasks[taskId].tScrollArrowTaskId != TASK_NONE)
    {
        RemoveScrollIndicatorArrowPair(gTasks[taskId].tScrollArrowTaskId);
        gTasks[taskId].tScrollArrowTaskId = TASK_NONE;
    }

    BeginNormalPaletteFade(PALETTES_ALL, 0, 0, 16, RGB_BLACK);
    gTasks[taskId].func = Task_OptionMenuFadeOut;
}

static void Task_OptionMenuFadeOut(u8 taskId)
{
    if (!gPaletteFade.active)
    {
        DestroyTask(taskId);
        FreeAllWindowBuffers();
        SetMainCallback2(gMain.savedCallback);
    }
}

// Returns FALSE (and draws nothing) if menuItem is scrolled off the visible page.
static bool8 GetOptionMenuItemY(u8 menuItem, s16 scrollOffset, u8 *y)
{
    s16 row = menuItem - scrollOffset;

    if (row < 0 || row >= NUM_VISIBLE_OPTIONS)
        return FALSE;

    *y = row * 16;
    return TRUE;
}

static void HighlightOptionMenuItem(u8 index)
{
    SetGpuReg(REG_OFFSET_WIN0H, WIN_RANGE(16, DISPLAY_WIDTH - 16));
    SetGpuReg(REG_OFFSET_WIN0V, WIN_RANGE(index * 16 + 40, index * 16 + 56));
}

#define TAG_OPTIONS_SCROLL_ARROW_GFX 2000
#define TAG_OPTIONS_SCROLL_ARROW_PAL 100

// Creates the scroll-arrow pair when MENUITEM_COUNT exceeds NUM_VISIBLE_OPTIONS. AUTO RUN (#1)
// pushed the list to 8 items over the 7-row window, so this is LIVE: arrows show and CANCEL sits
// below the fold until you scroll. tScrollArrowTaskId stays TASK_NONE only if the list ever fits.
static void CreateOptionMenuScrollArrows(u8 taskId)
{
    gTasks[taskId].tScrollArrowTaskId = TASK_NONE;

    if (MENUITEM_COUNT > NUM_VISIBLE_OPTIONS)
    {
        gTempScrollArrowTemplate.firstArrowType = SCROLL_ARROW_UP;
        gTempScrollArrowTemplate.firstX = 216;
        gTempScrollArrowTemplate.firstY = 40;
        gTempScrollArrowTemplate.secondArrowType = SCROLL_ARROW_DOWN;
        gTempScrollArrowTemplate.secondX = 216;
        gTempScrollArrowTemplate.secondY = 152;
        gTempScrollArrowTemplate.fullyUpThreshold = 0;
        gTempScrollArrowTemplate.fullyDownThreshold = MENUITEM_COUNT - NUM_VISIBLE_OPTIONS;
        gTempScrollArrowTemplate.tileTag = TAG_OPTIONS_SCROLL_ARROW_GFX;
        gTempScrollArrowTemplate.palTag = TAG_OPTIONS_SCROLL_ARROW_PAL;
        gTempScrollArrowTemplate.palNum = 0;

        gTasks[taskId].tScrollArrowTaskId = AddScrollIndicatorArrowPair(&gTempScrollArrowTemplate, (u16 *)&gTasks[taskId].tScrollOffset);
    }
}

// Clamps tScrollOffset so tMenuSelection stays on the visible page. Returns TRUE if
// the offset changed (caller must do a full repaint) or FALSE if only the highlight moved.
static bool8 AdjustOptionMenuScrollOffset(u8 taskId)
{
    s16 sel = gTasks[taskId].tMenuSelection;
    s16 scrollOffset = gTasks[taskId].tScrollOffset;

    if (sel < scrollOffset)
        scrollOffset = sel;
    else if (sel > scrollOffset + NUM_VISIBLE_OPTIONS - 1)
        scrollOffset = sel - NUM_VISIBLE_OPTIONS + 1;

    if (scrollOffset == gTasks[taskId].tScrollOffset)
        return FALSE;

    gTasks[taskId].tScrollOffset = scrollOffset;
    return TRUE;
}

static void RedrawVisibleOptionsPage(u8 taskId)
{
    s16 scrollOffset = gTasks[taskId].tScrollOffset;

    DrawOptionMenuTexts(scrollOffset);
    TextSpeed_DrawChoices(gTasks[taskId].tTextSpeed, scrollOffset);
    BattleScene_DrawChoices(gTasks[taskId].tBattleSceneOff, scrollOffset);
    BattleStyle_DrawChoices(gTasks[taskId].tBattleStyle, scrollOffset);
    Sound_DrawChoices(gTasks[taskId].tSound, scrollOffset);
    ButtonMode_DrawChoices(gTasks[taskId].tButtonMode, scrollOffset);
    FrameType_DrawChoices(gTasks[taskId].tWindowFrameType, scrollOffset);
    AutoRun_DrawChoices(gTasks[taskId].tAutoRun, scrollOffset);
    Autosave_DrawChoices(gTasks[taskId].tAutosave, scrollOffset);
    RunShortcut_DrawChoices(gTasks[taskId].tRunShortcut, scrollOffset);
    HardMode_DrawChoices(gTasks[taskId].tHardMode, scrollOffset);
    ExpMult_DrawChoices(gTasks[taskId].tExpMult, scrollOffset);
    CatchMult_DrawChoices(gTasks[taskId].tCatchMult, scrollOffset);
    HighlightOptionMenuItem(gTasks[taskId].tMenuSelection - scrollOffset);

    // Scroll repaint is a full window copy, unlike the single-row COPYWIN_GFX
    // update used for in-place L/R edits, since every visible row can change.
    CopyWindowToVram(WIN_OPTIONS, COPYWIN_FULL);
}

static void DrawOptionMenuChoice(const u8 *text, u8 x, u8 y, u8 style)
{
    u8 dst[16];
    u16 i;

    for (i = 0; *text != EOS && i < ARRAY_COUNT(dst) - 1; i++)
        dst[i] = *(text++);

    if (style != 0)
    {
        dst[2] = TEXT_COLOR_RED;
        dst[5] = TEXT_COLOR_LIGHT_RED;
    }

    dst[i] = EOS;
    AddTextPrinterParameterized(WIN_OPTIONS, FONT_NORMAL, dst, x, y + 1, TEXT_SKIP_DRAW, NULL);
}

static u8 TextSpeed_ProcessInput(u8 selection)
{
    if (JOY_NEW(DPAD_RIGHT))
    {
        if (selection <= 1)
            selection++;
        else
            selection = 0;

        sArrowPressed = TRUE;
    }
    if (JOY_NEW(DPAD_LEFT))
    {
        if (selection != 0)
            selection--;
        else
            selection = 2;

        sArrowPressed = TRUE;
    }
    return selection;
}

static void TextSpeed_DrawChoices(u8 selection, s16 scrollOffset)
{
    u8 styles[3];
    s32 widthSlow, widthMid, widthFast, xMid;
    u8 y;

    if (!GetOptionMenuItemY(MENUITEM_TEXTSPEED, scrollOffset, &y))
        return;

    styles[0] = 0;
    styles[1] = 0;
    styles[2] = 0;
    styles[selection] = 1;

    DrawOptionMenuChoice(gText_TextSpeedSlow, 104, y, styles[0]);

    widthSlow = GetStringWidth(FONT_NORMAL, gText_TextSpeedSlow, 0);
    widthMid = GetStringWidth(FONT_NORMAL, gText_TextSpeedMid, 0);
    widthFast = GetStringWidth(FONT_NORMAL, gText_TextSpeedFast, 0);

    widthMid -= 94;
    xMid = (widthSlow - widthMid - widthFast) / 2 + 104;
    DrawOptionMenuChoice(gText_TextSpeedMid, xMid, y, styles[1]);

    DrawOptionMenuChoice(gText_TextSpeedFast, GetStringRightAlignXOffset(FONT_NORMAL, gText_TextSpeedFast, 198), y, styles[2]);
}

static u8 BattleScene_ProcessInput(u8 selection)
{
    if (JOY_NEW(DPAD_LEFT | DPAD_RIGHT))
    {
        selection ^= 1;
        sArrowPressed = TRUE;
    }

    return selection;
}

static void BattleScene_DrawChoices(u8 selection, s16 scrollOffset)
{
    u8 styles[2];
    u8 y;

    if (!GetOptionMenuItemY(MENUITEM_BATTLESCENE, scrollOffset, &y))
        return;

    styles[0] = 0;
    styles[1] = 0;
    styles[selection] = 1;

    DrawOptionMenuChoice(gText_BattleSceneOn, 104, y, styles[0]);
    DrawOptionMenuChoice(gText_BattleSceneOff, GetStringRightAlignXOffset(FONT_NORMAL, gText_BattleSceneOff, 198), y, styles[1]);
}

static u8 BattleStyle_ProcessInput(u8 selection)
{
    if (JOY_NEW(DPAD_LEFT | DPAD_RIGHT))
    {
        selection ^= 1;
        sArrowPressed = TRUE;
    }

    return selection;
}

static void BattleStyle_DrawChoices(u8 selection, s16 scrollOffset)
{
    u8 styles[2];
    u8 y;

    if (!GetOptionMenuItemY(MENUITEM_BATTLESTYLE, scrollOffset, &y))
        return;

    styles[0] = 0;
    styles[1] = 0;
    styles[selection] = 1;

    DrawOptionMenuChoice(gText_BattleStyleShift, 104, y, styles[0]);
    DrawOptionMenuChoice(gText_BattleStyleSet, GetStringRightAlignXOffset(FONT_NORMAL, gText_BattleStyleSet, 198), y, styles[1]);
}

static u8 Sound_ProcessInput(u8 selection)
{
    if (JOY_NEW(DPAD_LEFT | DPAD_RIGHT))
    {
        selection ^= 1;
        SetPokemonCryStereo(selection);
        sArrowPressed = TRUE;
    }

    return selection;
}

static void Sound_DrawChoices(u8 selection, s16 scrollOffset)
{
    u8 styles[2];
    u8 y;

    if (!GetOptionMenuItemY(MENUITEM_SOUND, scrollOffset, &y))
        return;

    styles[0] = 0;
    styles[1] = 0;
    styles[selection] = 1;

    DrawOptionMenuChoice(gText_SoundMono, 104, y, styles[0]);
    DrawOptionMenuChoice(gText_SoundStereo, GetStringRightAlignXOffset(FONT_NORMAL, gText_SoundStereo, 198), y, styles[1]);
}

static u8 FrameType_ProcessInput(u8 selection)
{
    if (JOY_NEW(DPAD_RIGHT))
    {
        if (selection < WINDOW_FRAMES_COUNT - 1)
            selection++;
        else
            selection = 0;

        LoadBgTiles(1, GetWindowFrameTilesPal(selection)->tiles, 0x120, 0x1A2);
        LoadPalette(GetWindowFrameTilesPal(selection)->pal, BG_PLTT_ID(7), PLTT_SIZE_4BPP);
        sArrowPressed = TRUE;
    }
    if (JOY_NEW(DPAD_LEFT))
    {
        if (selection != 0)
            selection--;
        else
            selection = WINDOW_FRAMES_COUNT - 1;

        LoadBgTiles(1, GetWindowFrameTilesPal(selection)->tiles, 0x120, 0x1A2);
        LoadPalette(GetWindowFrameTilesPal(selection)->pal, BG_PLTT_ID(7), PLTT_SIZE_4BPP);
        sArrowPressed = TRUE;
    }
    return selection;
}

static void FrameType_DrawChoices(u8 selection, s16 scrollOffset)
{
    u8 text[16] = {EOS};
    u8 n = selection + 1;
    u16 i;
    u8 y;

    if (!GetOptionMenuItemY(MENUITEM_FRAMETYPE, scrollOffset, &y))
        return;

    for (i = 0; gText_FrameTypeNumber[i] != EOS && i <= 5; i++)
        text[i] = gText_FrameTypeNumber[i];

    // Convert a number to decimal string
    if (n / 10 != 0)
    {
        text[i] = n / 10 + CHAR_0;
        i++;
        text[i] = n % 10 + CHAR_0;
        i++;
    }
    else
    {
        text[i] = n % 10 + CHAR_0;
        i++;
        text[i] = CHAR_SPACER;
        i++;
    }

    text[i] = EOS;

    DrawOptionMenuChoice(gText_FrameType, 104, y, 0);
    DrawOptionMenuChoice(text, 128, y, 1);
}

static u8 ButtonMode_ProcessInput(u8 selection)
{
    if (JOY_NEW(DPAD_RIGHT))
    {
        if (selection <= 1)
            selection++;
        else
            selection = 0;

        sArrowPressed = TRUE;
    }
    if (JOY_NEW(DPAD_LEFT))
    {
        if (selection != 0)
            selection--;
        else
            selection = 2;

        sArrowPressed = TRUE;
    }
    return selection;
}

static void ButtonMode_DrawChoices(u8 selection, s16 scrollOffset)
{
    s32 widthNormal, widthLR, widthLA, xLR;
    u8 styles[3];
    u8 y;

    if (!GetOptionMenuItemY(MENUITEM_BUTTONMODE, scrollOffset, &y))
        return;

    styles[0] = 0;
    styles[1] = 0;
    styles[2] = 0;
    styles[selection] = 1;

    DrawOptionMenuChoice(gText_ButtonTypeNormal, 104, y, styles[0]);

    widthNormal = GetStringWidth(FONT_NORMAL, gText_ButtonTypeNormal, 0);
    widthLR = GetStringWidth(FONT_NORMAL, gText_ButtonTypeLR, 0);
    widthLA = GetStringWidth(FONT_NORMAL, gText_ButtonTypeLEqualsA, 0);

    widthLR -= 94;
    xLR = (widthNormal - widthLR - widthLA) / 2 + 104;
    DrawOptionMenuChoice(gText_ButtonTypeLR, xLR, y, styles[1]);

    DrawOptionMenuChoice(gText_ButtonTypeLEqualsA, GetStringRightAlignXOffset(FONT_NORMAL, gText_ButtonTypeLEqualsA, 198), y, styles[2]);
}

static u8 AutoRun_ProcessInput(u8 selection)
{
    if (JOY_NEW(DPAD_LEFT | DPAD_RIGHT))
    {
        selection ^= 1;
        sArrowPressed = TRUE;
    }

    return selection;
}

static void AutoRun_DrawChoices(u8 selection, s16 scrollOffset)
{
    u8 styles[2];
    u8 y;

    if (!GetOptionMenuItemY(MENUITEM_AUTORUN, scrollOffset, &y))
        return;

    styles[0] = 0;
    styles[1] = 0;
    styles[selection] = 1;

    // optionsAutoRun is normal polarity (0 = OFF, 1 = ON), unlike BattleScene's inverted var,
    // so OFF must be the index-0 (value-0) choice or the menu would highlight the wrong state.
    DrawOptionMenuChoice(gText_BattleSceneOff, 104, y, styles[0]);
    DrawOptionMenuChoice(gText_BattleSceneOn, GetStringRightAlignXOffset(FONT_NORMAL, gText_BattleSceneOn, 198), y, styles[1]);
}

static u8 Autosave_ProcessInput(u8 selection)
{
    if (JOY_NEW(DPAD_LEFT | DPAD_RIGHT))
    {
        selection ^= 1;
        sArrowPressed = TRUE;
    }

    return selection;
}

static void Autosave_DrawChoices(u8 selection, s16 scrollOffset)
{
    u8 styles[2];
    u8 y;

    if (!GetOptionMenuItemY(MENUITEM_AUTOSAVE, scrollOffset, &y))
        return;

    styles[0] = 0;
    styles[1] = 0;
    styles[selection] = 1;

    // optionsAutosave is normal polarity (0 = OFF, 1 = ON) like AutoRun above, NOT like
    // BattleScene's inverted var: OFF must stay the index-0 (value-0) choice.
    DrawOptionMenuChoice(gText_BattleSceneOff, 104, y, styles[0]);
    DrawOptionMenuChoice(gText_BattleSceneOn, GetStringRightAlignXOffset(FONT_NORMAL, gText_BattleSceneOn, 198), y, styles[1]);
}

// optionsRunShortcut stores CURSOR as 0 (old-save compat) but the menu cycles
// OFF->CURSOR->INSTANT, so map value<->position; {1, 0, 2} is its own inverse.
static const u8 sRunShortcutValuePos[] = {1, 0, 2};

static u8 RunShortcut_ProcessInput(u8 selection)
{
    u8 pos = sRunShortcutValuePos[selection];

    if (JOY_NEW(DPAD_RIGHT))
    {
        pos = pos <= 1 ? pos + 1 : 0;
        sArrowPressed = TRUE;
    }
    if (JOY_NEW(DPAD_LEFT))
    {
        pos = pos != 0 ? pos - 1 : 2;
        sArrowPressed = TRUE;
    }
    return sRunShortcutValuePos[pos];
}

static void RunShortcut_DrawChoices(u8 selection, s16 scrollOffset)
{
    // OFF/CURSOR/INSTANT don't fit as columns, so show only the current choice
    // (FrameType-style). Indexed by STORED value: 0 = CURSOR, 1 = OFF, 2 = INSTANT.
    static const u8 *const sTexts[] = {gText_RunShortcutCursor, gText_BattleSceneOff, gText_RunShortcutInstant};
    u8 y;

    if (!GetOptionMenuItemY(MENUITEM_RUNSHORTCUT, scrollOffset, &y))
        return;

    // The three labels differ in width, so wipe the choice area before printing.
    FillWindowPixelRect(WIN_OPTIONS, PIXEL_FILL(1), 104, y, 104, 16);
    DrawOptionMenuChoice(sTexts[selection], 104, y, 1);
}

static u8 HardMode_ProcessInput(u8 selection)
{
    if (JOY_NEW(DPAD_LEFT | DPAD_RIGHT))
    {
        selection ^= 1;
        sArrowPressed = TRUE;
    }

    return selection;
}

static void HardMode_DrawChoices(u8 selection, s16 scrollOffset)
{
    u8 styles[2];
    u8 y;

    if (!GetOptionMenuItemY(MENUITEM_HARDMODE, scrollOffset, &y))
        return;

    styles[0] = 0;
    styles[1] = 0;
    styles[selection] = 1;

    // optionsHardMode is normal polarity (0 = OFF, 1 = ON) like Autosave above.
    DrawOptionMenuChoice(gText_BattleSceneOff, 104, y, styles[0]);
    DrawOptionMenuChoice(gText_BattleSceneOn, GetStringRightAlignXOffset(FONT_NORMAL, gText_BattleSceneOn, 198), y, styles[1]);
}

// optionsExpMultiplier stores 1x as 0 (old-save compat) but the menu columns run
// 0.5x/1x/1.5x/2x, so map value<->column; {1, 0, 2, 3} is its own inverse.
static const u8 sExpMultValueCol[] = {1, 0, 2, 3};

static u8 ExpMult_ProcessInput(u8 selection)
{
    u8 col = sExpMultValueCol[selection];

    if (JOY_NEW(DPAD_RIGHT))
    {
        col = col <= 2 ? col + 1 : 0;
        sArrowPressed = TRUE;
    }
    if (JOY_NEW(DPAD_LEFT))
    {
        col = col != 0 ? col - 1 : 3;
        sArrowPressed = TRUE;
    }
    return sExpMultValueCol[col];
}

static void ExpMult_DrawChoices(u8 selection, s16 scrollOffset)
{
    u8 styles[4];
    u8 y;

    if (!GetOptionMenuItemY(MENUITEM_EXPMULT, scrollOffset, &y))
        return;

    styles[0] = 0;
    styles[1] = 0;
    styles[2] = 0;
    styles[3] = 0;
    styles[sExpMultValueCol[selection]] = 1; // stored value -> menu column

    DrawOptionMenuChoice(gText_Mult0_5x, 104, y, styles[0]);
    DrawOptionMenuChoice(gText_Mult1x, 134, y, styles[1]);
    DrawOptionMenuChoice(gText_Mult1_5x, 155, y, styles[2]);
    DrawOptionMenuChoice(gText_Mult2x, GetStringRightAlignXOffset(FONT_NORMAL, gText_Mult2x, 198), y, styles[3]);
}

static u8 CatchMult_ProcessInput(u8 selection)
{
    if (JOY_NEW(DPAD_RIGHT))
    {
        if (selection <= 1)
            selection++;
        else
            selection = 0;

        sArrowPressed = TRUE;
    }
    if (JOY_NEW(DPAD_LEFT))
    {
        if (selection != 0)
            selection--;
        else
            selection = 2;

        sArrowPressed = TRUE;
    }
    return selection;
}

static void CatchMult_DrawChoices(u8 selection, s16 scrollOffset)
{
    u8 styles[3];
    u8 y;

    if (!GetOptionMenuItemY(MENUITEM_CATCHMULT, scrollOffset, &y))
        return;

    styles[0] = 0;
    styles[1] = 0;
    styles[2] = 0;
    styles[selection] = 1; // stored value == menu column (0 = 1x, 1 = 1.5x, 2 = 2x)

    DrawOptionMenuChoice(gText_Mult1x, 104, y, styles[0]);
    DrawOptionMenuChoice(gText_Mult1_5x, 140, y, styles[1]);
    DrawOptionMenuChoice(gText_Mult2x, GetStringRightAlignXOffset(FONT_NORMAL, gText_Mult2x, 198), y, styles[2]);
}

static void DrawHeaderText(void)
{
    FillWindowPixelBuffer(WIN_HEADER, PIXEL_FILL(1));
    AddTextPrinterParameterized(WIN_HEADER, FONT_NORMAL, gText_Option, 8, 1, TEXT_SKIP_DRAW, NULL);
    CopyWindowToVram(WIN_HEADER, COPYWIN_FULL);
}

static void DrawOptionMenuTexts(s16 scrollOffset)
{
    u8 i;

    FillWindowPixelBuffer(WIN_OPTIONS, PIXEL_FILL(1));
    for (i = 0; i < NUM_VISIBLE_OPTIONS && scrollOffset + i < MENUITEM_COUNT; i++)
        AddTextPrinterParameterized(WIN_OPTIONS, FONT_NORMAL, sOptionMenuItemsNames[scrollOffset + i], 8, (i * 16) + 1, TEXT_SKIP_DRAW, NULL);
    // No CopyWindowToVram here: the sole caller (RedrawVisibleOptionsPage) draws the choice
    // values on top and does the full window copy, so a copy here would just be a wasted DMA.
}

#define TILE_TOP_CORNER_L 0x1A2
#define TILE_TOP_EDGE     0x1A3
#define TILE_TOP_CORNER_R 0x1A4
#define TILE_LEFT_EDGE    0x1A5
#define TILE_RIGHT_EDGE   0x1A7
#define TILE_BOT_CORNER_L 0x1A8
#define TILE_BOT_EDGE     0x1A9
#define TILE_BOT_CORNER_R 0x1AA

static void DrawBgWindowFrames(void)
{
    //                     bg, tile,              x, y, width, height, palNum
    // Draw title window frame
    FillBgTilemapBufferRect(1, TILE_TOP_CORNER_L,  1,  0,  1,  1,  7);
    FillBgTilemapBufferRect(1, TILE_TOP_EDGE,      2,  0, 27,  1,  7);
    FillBgTilemapBufferRect(1, TILE_TOP_CORNER_R, 28,  0,  1,  1,  7);
    FillBgTilemapBufferRect(1, TILE_LEFT_EDGE,     1,  1,  1,  2,  7);
    FillBgTilemapBufferRect(1, TILE_RIGHT_EDGE,   28,  1,  1,  2,  7);
    FillBgTilemapBufferRect(1, TILE_BOT_CORNER_L,  1,  3,  1,  1,  7);
    FillBgTilemapBufferRect(1, TILE_BOT_EDGE,      2,  3, 27,  1,  7);
    FillBgTilemapBufferRect(1, TILE_BOT_CORNER_R, 28,  3,  1,  1,  7);

    // Draw options list window frame
    FillBgTilemapBufferRect(1, TILE_TOP_CORNER_L,  1,  4,  1,  1,  7);
    FillBgTilemapBufferRect(1, TILE_TOP_EDGE,      2,  4, 26,  1,  7);
    FillBgTilemapBufferRect(1, TILE_TOP_CORNER_R, 28,  4,  1,  1,  7);
    FillBgTilemapBufferRect(1, TILE_LEFT_EDGE,     1,  5,  1, 18,  7);
    FillBgTilemapBufferRect(1, TILE_RIGHT_EDGE,   28,  5,  1, 18,  7);
    FillBgTilemapBufferRect(1, TILE_BOT_CORNER_L,  1, 19,  1,  1,  7);
    FillBgTilemapBufferRect(1, TILE_BOT_EDGE,      2, 19, 26,  1,  7);
    FillBgTilemapBufferRect(1, TILE_BOT_CORNER_R, 28, 19,  1,  1,  7);

    CopyBgTilemapBufferToVram(1);
}
