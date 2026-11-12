#include "global.h"
#include "bg.h"
#include "event_data.h"
#include "gpu_regs.h"
#include "line_break.h"
#include "main.h"
#include "malloc.h"
#include "menu.h"
#include "move.h"
#include "palette.h"
#include "pokemon_icon.h"
#include "sound.h"
#include "special_pokemon.h"
#include "special_pokemon_menu.h"
#include "sprite.h"
#include "string_util.h"
#include "task.h"
#include "text.h"
#include "window.h"
#include "constants/rgb.h"
#include "constants/songs.h"

#define COLLECTION_ROWS 5

struct SpecialPokemonMenu
{
    MainCallback returnCallback;
    u16 tilemap[BG_SCREEN_SIZE / 2];
    u8 iconSpriteIds[COLLECTION_ROWS];
    u8 selected;
    bool8 detail;
};

static EWRAM_DATA struct SpecialPokemonMenu *sSpecialPokemonMenu = NULL;

static const struct BgTemplate sCollectionBg = {
    .bg = 0,
    .charBaseIndex = 0,
    .mapBaseIndex = 31,
    .priority = 1,
};

static const struct WindowTemplate sCollectionWindows[] = {
    {.bg = 0, .tilemapLeft = 0, .tilemapTop = 0, .width = 30, .height = 20, .paletteNum = 0, .baseBlock = 1},
    DUMMY_WIN_TEMPLATE
};

static const u16 sCollectionPalette[16] = {
    RGB(3, 6, 10), RGB(29, 30, 31), RGB(3, 6, 10), RGB(19, 22, 25),
    RGB(21, 26, 29), RGB(9, 16, 21), RGB(12, 24, 17), RGB(31, 31, 31)
};
static const u8 sCollectionColors[] = {TEXT_COLOR_TRANSPARENT, 2, 3};
static const u8 sCollectionHeaderColors[] = {TEXT_COLOR_TRANSPARENT, 7, 0};

static void PrintCollectionText(const u8 *text, u8 x, u8 y)
{
    AddTextPrinterParameterized3(0, FONT_SMALL, x, y, sCollectionColors, TEXT_SKIP_DRAW, text);
}

static void DestroyCollectionIcons(void)
{
    u32 i;

    for (i = 0; i < COLLECTION_ROWS; i++)
    {
        if (sSpecialPokemonMenu->iconSpriteIds[i] < MAX_SPRITES)
            FreeAndDestroyMonIconSprite(&gSprites[sSpecialPokemonMenu->iconSpriteIds[i]]);
        sSpecialPokemonMenu->iconSpriteIds[i] = MAX_SPRITES;
    }
    FreeMonIconPalettes();
}

static void CreateCollectionIcon(u32 slot, u16 species, s16 x, s16 y)
{
    u8 spriteId;

    LoadMonIconPalette(species);
    spriteId = CreateMonIconNoPersonality(species, SpriteCB_MonIcon, x, y, 0);
    sSpecialPokemonMenu->iconSpriteIds[slot] = spriteId;
    if (spriteId < MAX_SPRITES)
        gSprites[spriteId].oam.priority = 0;
}

static void DrawCollection(void)
{
    const struct SpecialPokemonEntry *entry;
    u32 i;
    u32 collected = 0;
    u8 text[256];
    u8 number[8];

    DestroyCollectionIcons();
    FillWindowPixelBuffer(0, PIXEL_FILL(1));
    FillWindowPixelRect(0, PIXEL_FILL(5), 0, 0, 240, 20);
    AddTextPrinterParameterized3(0, FONT_SMALL, 6, 3, sCollectionHeaderColors, TEXT_SKIP_DRAW,
                                COMPOUND_STRING("Special Pokémon"));
    for (i = 0; i < SPECIAL_POKEMON_COUNT; i++)
        if (FlagGet(SpecialPokemon_GetEntry(i)->collectedFlag))
            collected++;
    ConvertIntToDecimalStringN(text, collected, STR_CONV_MODE_LEFT_ALIGN, 2);
    StringAppend(text, COMPOUND_STRING("/"));
    ConvertIntToDecimalStringN(number, SPECIAL_POKEMON_COUNT, STR_CONV_MODE_LEFT_ALIGN, 2);
    StringAppend(text, number);
    StringAppend(text, COMPOUND_STRING(" collected"));
    AddTextPrinterParameterized3(0, FONT_SMALL, 155, 3, sCollectionHeaderColors, TEXT_SKIP_DRAW, text);

    if (sSpecialPokemonMenu->detail)
    {
        entry = SpecialPokemon_GetEntry(sSpecialPokemonMenu->selected);
        CreateCollectionIcon(0, entry->species, 23, 39);
        PrintCollectionText(entry->name, 44, 24);
        PrintCollectionText(FlagGet(entry->collectedFlag) ? COMPOUND_STRING("Collected") : COMPOUND_STRING("Missing"), 44, 39);
        StringCopy(text, COMPOUND_STRING("Level "));
        ConvertIntToDecimalStringN(number, entry->level, STR_CONV_MODE_LEFT_ALIGN, 2);
        StringAppend(text, number);
        PrintCollectionText(text, 8, 57);
        PrintCollectionText(GetMoveName(entry->themedMove), 92, 57);
        StringCopy(text, entry->location);
        BreakStringAutomatic(text, 224, 2, FONT_SMALL, HIDE_SCROLL_PROMPT);
        PrintCollectionText(text, 8, 74);
        StringCopy(text, entry->hint);
        BreakStringAutomatic(text, 224, 3, FONT_SMALL, HIDE_SCROLL_PROMPT);
        PrintCollectionText(text, 8, 102);
        PrintCollectionText(COMPOUND_STRING("{DPAD_LEFTRIGHT} Entry   {B_BUTTON} List"), 8, 145);
    }
    else
    {
        u32 first = sSpecialPokemonMenu->selected / COLLECTION_ROWS * COLLECTION_ROWS;

        for (i = 0; i < COLLECTION_ROWS && first + i < SPECIAL_POKEMON_COUNT; i++)
        {
            u32 id = first + i;
            entry = SpecialPokemon_GetEntry(id);
            if (id == sSpecialPokemonMenu->selected)
                FillWindowPixelRect(0, PIXEL_FILL(4), 3, 23 + i * 23, 234, 23);
            CreateCollectionIcon(i, entry->species, 21, 34 + i * 23);
            PrintCollectionText(entry->name, 40, 28 + i * 23);
            PrintCollectionText(FlagGet(entry->collectedFlag) ? COMPOUND_STRING("OK") : COMPOUND_STRING("--"), 215, 28 + i * 23);
        }
        PrintCollectionText(COMPOUND_STRING("{DPAD_UPDOWN} Select  {A_BUTTON} Details  {B_BUTTON} Back"), 8, 145);
    }
    PutWindowTilemap(0);
    CopyWindowToVram(0, COPYWIN_FULL);
}

static void CloseCollection(u8 taskId)
{
    MainCallback returnCallback;

    if (gPaletteFade.active)
        return;
    returnCallback = sSpecialPokemonMenu->returnCallback;
    SetVBlankCallback(NULL);
    DestroyCollectionIcons();
    FreeAllWindowBuffers();
    UnsetBgTilemapBuffer(0);
    Free(sSpecialPokemonMenu);
    sSpecialPokemonMenu = NULL;
    DestroyTask(taskId);
    SetMainCallback2(returnCallback);
}

static void HandleCollectionInput(u8 taskId)
{
    u8 oldSelection = sSpecialPokemonMenu->selected;

    if (gPaletteFade.active)
        return;
    if (JOY_NEW(B_BUTTON))
    {
        PlaySE(SE_SELECT);
        if (sSpecialPokemonMenu->detail)
        {
            sSpecialPokemonMenu->detail = FALSE;
            DrawCollection();
        }
        else
        {
            BeginNormalPaletteFade(PALETTES_ALL, 0, 0, 16, RGB_BLACK);
            gTasks[taskId].func = CloseCollection;
        }
        return;
    }
    if (sSpecialPokemonMenu->detail)
    {
        if (JOY_REPEAT(DPAD_LEFT) && oldSelection > 0)
            sSpecialPokemonMenu->selected--;
        else if (JOY_REPEAT(DPAD_RIGHT) && oldSelection + 1 < SPECIAL_POKEMON_COUNT)
            sSpecialPokemonMenu->selected++;
    }
    else
    {
        if (JOY_NEW(A_BUTTON))
        {
            sSpecialPokemonMenu->detail = TRUE;
            PlaySE(SE_SELECT);
            DrawCollection();
            return;
        }
        if (JOY_REPEAT(DPAD_UP) && oldSelection > 0)
            sSpecialPokemonMenu->selected--;
        else if (JOY_REPEAT(DPAD_DOWN) && oldSelection + 1 < SPECIAL_POKEMON_COUNT)
            sSpecialPokemonMenu->selected++;
        else if (JOY_REPEAT(DPAD_LEFT) && oldSelection >= COLLECTION_ROWS)
            sSpecialPokemonMenu->selected -= COLLECTION_ROWS;
        else if (JOY_REPEAT(DPAD_RIGHT) && oldSelection + COLLECTION_ROWS < SPECIAL_POKEMON_COUNT)
            sSpecialPokemonMenu->selected += COLLECTION_ROWS;
    }
    if (oldSelection != sSpecialPokemonMenu->selected)
    {
        PlaySE(SE_SELECT);
        DrawCollection();
    }
}

static void VBlankCollection(void)
{
    LoadOam();
    ProcessSpriteCopyRequests();
    TransferPlttBuffer();
}

static void RunCollection(void)
{
    RunTasks();
    AnimateSprites();
    BuildOamBuffer();
    UpdatePaletteFade();
}

static void InitCollection(void)
{
    SetVBlankCallback(NULL);
    SetGpuReg(REG_OFFSET_DISPCNT, 0);
    SetGpuReg(REG_OFFSET_BLDCNT, 0);
    SetGpuReg(REG_OFFSET_BLDALPHA, 0);
    SetGpuReg(REG_OFFSET_BLDY, 0);
    ResetTasks();
    ResetSpriteData();
    FreeAllSpritePalettes();
    ResetPaletteFade();
    ResetBgsAndClearDma3BusyFlags(0);
    InitBgsFromTemplates(0, &sCollectionBg, 1);
    ChangeBgX(0, 0, BG_COORD_SET);
    ChangeBgY(0, 0, BG_COORD_SET);
    SetBgTilemapBuffer(0, sSpecialPokemonMenu->tilemap);
    InitWindows(sCollectionWindows);
    DeactivateAllTextPrinters();
    LoadPalette(sCollectionPalette, 0, sizeof(sCollectionPalette));
    SpecialPokemon_ReconcileOwned();
    DrawCollection();
    CreateTask(HandleCollectionInput, 0);
    BeginNormalPaletteFade(PALETTES_ALL, 0, 16, 0, RGB_BLACK);
    SetGpuReg(REG_OFFSET_DISPCNT, DISPCNT_OBJ_1D_MAP | DISPCNT_OBJ_ON);
    ShowBg(0);
    SetVBlankCallback(VBlankCollection);
    SetMainCallback2(RunCollection);
}

void ShowSpecialPokemonMenu(MainCallback returnCallback)
{
    u32 i;

    sSpecialPokemonMenu = AllocZeroed(sizeof(*sSpecialPokemonMenu));
    if (sSpecialPokemonMenu == NULL)
    {
        SetMainCallback2(returnCallback);
        return;
    }
    sSpecialPokemonMenu->returnCallback = returnCallback;
    for (i = 0; i < COLLECTION_ROWS; i++)
        sSpecialPokemonMenu->iconSpriteIds[i] = MAX_SPRITES;
    SetMainCallback2(InitCollection);
}
