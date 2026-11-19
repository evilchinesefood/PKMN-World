#include "global.h"
#include "bg.h"
#include "event_data.h"
#include "international_string_util.h"
#include "main.h"
#include "menu.h"
#include "palette.h"
#include "pokemon.h"
#include "script.h"
#include "string_util.h"
#include "strings.h"
#include "task.h"
#include "text_window.h"
#include "window.h"
#include "dodrio_berry_picking.h"

static void Task_ShowDodrioBerryPickingRecords(u8 taskId);
static void PrintRecordsText(u8 windowId, s32 width);

void IsDodrioInParty(void)
{
    int i;
    for (i = 0; i < PARTY_SIZE; i++)
    {
        if (GetMonData(&gParties[B_TRAINER_PLAYER][i], MON_DATA_SANITY_HAS_SPECIES)
            && GetMonData(&gParties[B_TRAINER_PLAYER][i], MON_DATA_SPECIES_OR_EGG) == SPECIES_DODRIO)
        {
            gSpecialVar_Result = TRUE;
            return;
        }
    }

    gSpecialVar_Result = FALSE;
}

#define NUM_RECORD_TYPES 3

void ShowDodrioBerryPickingRecords(void)
{
    u8 taskId = CreateTask(Task_ShowDodrioBerryPickingRecords, 0);
    Task_ShowDodrioBerryPickingRecords(taskId);
}

static const struct WindowTemplate sWindowTemplates_Records =
{
    .bg = 0,
    .tilemapLeft = 5,
    .tilemapTop = 1,
    .width = 20,
    .height = 11,
    .paletteNum = 15,
    .baseBlock = 0x1,
};

static const u8 *const sRecordsTexts[NUM_RECORD_TYPES] = {gText_BerriesPicked, gText_BestScore, gText_BerriesInRowFivePlayers};
static const u8 sRecordNumMaxDigits[NUM_RECORD_TYPES] = {4, 7, 4};
ALIGNED(4)
static const u8 sRecordTextYCoords[NUM_RECORD_TYPES][2] = {{25}, {41}, {57}};
static const u8 sRecordNumYCoords[NUM_RECORD_TYPES][2] = {{25}, {41}, {73}};

#define tState data[0]
#define tWindowId data[1]

static void Task_ShowDodrioBerryPickingRecords(u8 taskId)
{
    struct WindowTemplate window;
    s32 i, width, widthCurr;
    s16 *data = gTasks[taskId].data;

    switch (tState)
    {
    case 0:
        window = sWindowTemplates_Records;
        width = GetStringWidth(FONT_NORMAL, gText_BerryPickingRecords, 0);
        for (i = 0; i < ARRAY_COUNT(sRecordsTexts); i++)
        {
            widthCurr = GetStringWidth(FONT_NORMAL, sRecordsTexts[i], 0) + 50;
            if (widthCurr > width)
                width = widthCurr;
        }
        width = (width + 7) / 8;
        if (width & 1)
            width++;
        window.tilemapLeft = (30 - width) / 2;
        window.width = width;
        tWindowId = AddWindow(&window);
        PrintRecordsText(tWindowId, width);
        CopyWindowToVram(tWindowId, COPYWIN_FULL);
        tState++;
        break;
    case 1:
        if (!IsDma3ManagerBusyWithBgCopy())
            tState++;
        break;
    case 2:
        if (JOY_NEW(A_BUTTON | B_BUTTON))
        {
            rbox_fill_rectangle(tWindowId);
            CopyWindowToVram(tWindowId, COPYWIN_MAP);
            tState++;
        }
        break;
    case 3:
        if (!IsDma3ManagerBusyWithBgCopy())
        {
            RemoveWindow(tWindowId);
            DestroyTask(taskId);
            ScriptContext_Enable();
        }
        break;
    }
}

#undef tState
#undef tWindowId

static void PrintRecordsText(u8 windowId, s32 width)
{
    s32 i, x, numWidth;
    s32 recordNums[NUM_RECORD_TYPES];
    recordNums[0] = gSaveBlock2Ptr->berryPick.berriesPicked;
    recordNums[1] = gSaveBlock2Ptr->berryPick.bestScore;
    recordNums[2] = gSaveBlock2Ptr->berryPick.berriesPickedInRow;

    LoadUserWindowBorderGfx_(windowId, 0x21D, BG_PLTT_ID(13));
    DrawTextBorderOuter(windowId, 0x21D, 13);
    FillWindowPixelBuffer(windowId, PIXEL_FILL(1));
    AddTextPrinterParameterized(windowId, FONT_NORMAL, gText_BerryPickingRecords, GetStringCenterAlignXOffset(FONT_NORMAL, gText_BerryPickingRecords, width * 8), 1, TEXT_SKIP_DRAW, NULL);
    for (i = 0; i < NUM_RECORD_TYPES; i++)
    {
        ConvertIntToDecimalStringN(gStringVar1, recordNums[i], STR_CONV_MODE_LEFT_ALIGN, sRecordNumMaxDigits[i]);
        numWidth = GetStringWidth(FONT_NORMAL, gStringVar1, -1);
        AddTextPrinterParameterized(windowId, FONT_NORMAL, sRecordsTexts[i], 0, sRecordTextYCoords[i][0], TEXT_SKIP_DRAW, NULL);
        x = (width * 8) - numWidth;
        AddTextPrinterParameterized(windowId, FONT_NORMAL, gStringVar1, x, sRecordNumYCoords[i][0], TEXT_SKIP_DRAW, NULL);
    }
    PutWindowTilemap(windowId);
}
