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
#include "pokemon_jump.h"

static void Task_ShowPokemonJumpRecords(u8 taskId);
static void PrintRecordsText(u16 windowId, int width);
static inline void TruncateToFirstWordOnly(u8 *str);

bool32 IsSpeciesAllowedInPokemonJump(enum Species species)
{
    return gSpeciesInfo[SanitizeSpeciesId(species)].pokemonJumpType != PKMN_JUMP_TYPE_NONE;
}

void IsPokemonJumpSpeciesInParty(void)
{
    int i;

    for (i = 0; i < PARTY_SIZE; i++)
    {
        if (GetMonData(&gParties[B_TRAINER_PLAYER][i], MON_DATA_SANITY_HAS_SPECIES))
        {
            enum Species species = GetMonData(&gParties[B_TRAINER_PLAYER][i], MON_DATA_SPECIES_OR_EGG);
            if (IsSpeciesAllowedInPokemonJump(species))
            {
                gSpecialVar_Result = TRUE;
                return;
            }
        }
    }

    gSpecialVar_Result = FALSE;
}

#if FREE_POKEMON_JUMP == FALSE
static struct PokemonJumpRecords *GetPokeJumpRecords(void)
{
    return &gSaveBlock2Ptr->pokeJump;
}
#endif //FREE_POKEMON_JUMP

void ResetPokemonJumpRecords(void)
{
#if FREE_POKEMON_JUMP == FALSE
    struct PokemonJumpRecords *records = GetPokeJumpRecords();
    records->jumpsInRow = 0;
    records->bestJumpScore = 0;
    records->excellentsInRow = 0;
    records->gamesWithMaxPlayers = 0;
    records->unused2 = 0;
    records->unused1 = 0;
#endif //FREE_POKEMON_JUMP
}

void ShowPokemonJumpRecords(void)
{
    u8 taskId = CreateTask(Task_ShowPokemonJumpRecords, 0);
    Task_ShowPokemonJumpRecords(taskId);
}

static const struct WindowTemplate sWindowTemplate_Records =
{
    .bg = 0,
    .tilemapLeft = 1,
    .tilemapTop = 1,
    .width = 28,
    .height = 9,
    .paletteNum = 15,
    .baseBlock = 0x1,
};

static const u8 *const sRecordsTexts[] = {gText_JumpsInARow, gText_BestScore2, gText_ExcellentsInARow};

#define tState data[0]
#define tWindowId data[1]

static void Task_ShowPokemonJumpRecords(u8 taskId)
{
    struct WindowTemplate window;
    int i, width, widthCurr;
    s16 *data = gTasks[taskId].data;

    switch (tState)
    {
    case 0:
        window = sWindowTemplate_Records;
        width = GetStringWidth(FONT_NORMAL, gText_PkmnJumpRecords, 0);
        for (i = 0; i < ARRAY_COUNT(sRecordsTexts); i++)
        {
            widthCurr = GetStringWidth(FONT_NORMAL, sRecordsTexts[i], 0) + 38;
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

static void PrintRecordsText(u16 windowId, int width)
{
#if FREE_POKEMON_JUMP == FALSE
    int i, x;
    int recordNums[3];
    struct PokemonJumpRecords *records = GetPokeJumpRecords();
    recordNums[0] = records->jumpsInRow;
    recordNums[1] = records->bestJumpScore;
    recordNums[2] = records->excellentsInRow;

    LoadUserWindowBorderGfx_(windowId, 0x21D, BG_PLTT_ID(13));
    DrawTextBorderOuter(windowId, 0x21D, 13);
    FillWindowPixelBuffer(windowId, PIXEL_FILL(1));
    AddTextPrinterParameterized(windowId, FONT_NORMAL, gText_PkmnJumpRecords, GetStringCenterAlignXOffset(FONT_NORMAL, gText_PkmnJumpRecords, width * 8), 1, TEXT_SKIP_DRAW, NULL);
    for (i = 0; i < ARRAY_COUNT(sRecordsTexts); i++)
    {
        AddTextPrinterParameterized(windowId, FONT_NORMAL, sRecordsTexts[i], 0, 25 + (i * 16), TEXT_SKIP_DRAW, NULL);
        ConvertIntToDecimalStringN(gStringVar1, recordNums[i], STR_CONV_MODE_LEFT_ALIGN, 5);
        TruncateToFirstWordOnly(gStringVar1);
        x = (width * 8) - GetStringWidth(FONT_NORMAL, gStringVar1, 0);
        AddTextPrinterParameterized(windowId, FONT_NORMAL, gStringVar1, x, 25 + (i * 16), TEXT_SKIP_DRAW, NULL);
    }
    PutWindowTilemap(windowId);
#endif //FREE_POKEMON_JUMP
}

static inline void TruncateToFirstWordOnly(u8 *str)
{
    for (;*str != EOS; str++)
    {
        if (*str == CHAR_SPACE)
        {
            *str = EOS;
            break;
        }
    }
}
