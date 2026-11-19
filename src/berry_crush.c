#include "global.h"
#include "berry_crush.h"
#include "event_data.h"
#include "link.h"
#include "main.h"
#include "menu.h"
#include "palette.h"
#include "overworld.h"
#include "script.h"
#include "string_util.h"
#include "strings.h"
#include "task.h"
#include "text_window.h"
#include "window.h"

static const u8 sHeaderColor[] = {TEXT_COLOR_WHITE, TEXT_COLOR_BLUE, TEXT_COLOR_LIGHT_BLUE};
static const u8 sRecordColor[] = {TEXT_COLOR_WHITE, TEXT_COLOR_DARK_GRAY, TEXT_COLOR_LIGHT_GRAY};

static const struct WindowTemplate sWindowTemplate_Rankings =
{
    .bg = 0,
    .tilemapLeft = 3,
    .tilemapTop = 4,
    .width = 24,
    .height = 13,
    .paletteNum = 15,
    .baseBlock = 1
};

static const u32 sPressingSpeedConversionTable[] =
{
    50000000, // 50
    25000000, // 25
    12500000, // 12.5
     6250000, //  6.25
     3125000, //  3.125
     1562500, //  1.5625
      781250, //  0.78125
      390625  //  0.390625
};

#define tState             data[0]
#define tWindowId          data[1]
#define tPressingSpeeds(i) data[2 + (i)] // data[2]-[5], for different group sizes

static void Task_ShowRankings(u8 taskId)
{
    u8 i = 0, j, xPos, yPos;
    u32 score = 0;
    s16 *data = gTasks[taskId].data;

    switch (tState)
    {
    case 0:
        tWindowId = AddWindow(&sWindowTemplate_Rankings);
        PutWindowTilemap(tWindowId);
        FillWindowPixelBuffer(tWindowId, PIXEL_FILL(0));
        LoadUserWindowBorderGfx_(tWindowId, 541, BG_PLTT_ID(13));
        DrawStdFrameWithCustomTileAndPalette(tWindowId, FALSE, 541, 13);
        break;
    case 1:
        // Print header text
        xPos = 96 - GetStringWidth(FONT_NORMAL, gText_BerryCrush2, -1) / 2u;
        AddTextPrinterParameterized3(tWindowId, FONT_NORMAL, xPos, 1, sHeaderColor, 0, gText_BerryCrush2);
        xPos = 96 - GetStringWidth(FONT_NORMAL, gText_PressingSpeedRankings, -1) / 2u;
        AddTextPrinterParameterized3(tWindowId, FONT_NORMAL, xPos, 17, sHeaderColor, 0, gText_PressingSpeedRankings);

        // Print pressing speed record for each group size, ranked
        yPos = 41;
        for (i = 0; i < MAX_RFU_PLAYERS - 1; i++)
        {
            ConvertIntToDecimalStringN(gStringVar1, i + 2, STR_CONV_MODE_LEFT_ALIGN, 1);
            StringExpandPlaceholders(gStringVar4, gText_Var1Players);
            AddTextPrinterParameterized3(tWindowId, FONT_NORMAL, 0, yPos, sRecordColor, 0, gStringVar4);
            xPos = 192 - (u8)GetStringWidth(FONT_NORMAL, gText_TimesPerSec, -1);
            AddTextPrinterParameterized3(tWindowId, FONT_NORMAL, xPos, yPos, sRecordColor, 0, gText_TimesPerSec);
            for (j = 0; j < 8; j++)
            {
                if (((tPressingSpeeds(i) & 0xFF) >> (7 - j)) & 1)
                    score += sPressingSpeedConversionTable[j];
            }
            ConvertIntToDecimalStringN(gStringVar1, (u16)tPressingSpeeds(i) >> 8, STR_CONV_MODE_RIGHT_ALIGN, 3);
            ConvertIntToDecimalStringN(gStringVar2, score / 1000000, STR_CONV_MODE_LEADING_ZEROS, 2);
            StringExpandPlaceholders(gStringVar4, gText_XDotY3);
            xPos -= GetStringWidth(FONT_NORMAL, gStringVar4, -1);
            AddTextPrinterParameterized3(tWindowId, FONT_NORMAL, xPos, yPos, sRecordColor, 0, gStringVar4);
            yPos += 16;
            score = 0;
        }
        CopyWindowToVram(tWindowId, COPYWIN_FULL);
        break;
    case 2:
        if (JOY_NEW(A_BUTTON | B_BUTTON))
            break;
        else
            return;
    case 3:
        ClearStdWindowAndFrameToTransparent(tWindowId, TRUE);
        ClearWindowTilemap(tWindowId);
        RemoveWindow(tWindowId);
        DestroyTask(taskId);
        ScriptContext_Enable();
        UnlockPlayerFieldControls();
        tState = 0;
        return;
    }
    tState++;
}

void ShowBerryCrushRankings(void)
{
    u8 taskId;

    LockPlayerFieldControls();
    taskId = CreateTask(Task_ShowRankings, 0);
    gTasks[taskId].tPressingSpeeds(0) = gSaveBlock2Ptr->berryCrush.pressingSpeeds[0];
    gTasks[taskId].tPressingSpeeds(1) = gSaveBlock2Ptr->berryCrush.pressingSpeeds[1];
    gTasks[taskId].tPressingSpeeds(2) = gSaveBlock2Ptr->berryCrush.pressingSpeeds[2];
    gTasks[taskId].tPressingSpeeds(3) = gSaveBlock2Ptr->berryCrush.pressingSpeeds[3];
}
