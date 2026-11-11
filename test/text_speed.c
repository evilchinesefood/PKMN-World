#include "global.h"
#include "test/test.h"
#include "battle.h"
#include "battle_message.h"
#include "malloc.h"
#include "recorded_battle.h"
#include "bg.h"
#include "dma3.h"
#include "main.h"
#include "m4a.h"
#include "sound.h"
#include "text.h"
#include "window.h"
#include "constants/songs.h"

static const struct BgTemplate sTextTestBg[] = {
    {.bg = 0, .charBaseIndex = 0, .mapBaseIndex = 31, .screenSize = 0, .paletteMode = 0},
};

static const struct WindowTemplate sTextTestWindows[] = {
    {.bg = 0, .width = 20, .height = 6, .baseBlock = 1},
    {.bg = 0, .width = 20, .height = 6, .baseBlock = 121},
    DUMMY_WIN_TEMPLATE,
};

static struct {
    const u8 *start;
    u32 cursor;
    u32 prints;
    u32 updates;
    u8 state;
    u8 delay;
    u8 autoScroll;
    u16 utility;
} sTrace[2];

static void TracePrinter(struct TextPrinterTemplate *template, u16 result)
{
    struct TextPrinter *printer = (struct TextPrinter *)template;
    u32 window = template->windowId;
    sTrace[window].cursor = template->currentChar - sTrace[window].start;
    sTrace[window].state = printer->state;
    sTrace[window].delay = printer->delayCounter;
    sTrace[window].autoScroll = printer->autoScrollDelay;
    sTrace[window].utility = printer->utilityCounter;
    if (result == RENDER_PRINT)
        sTrace[window].prints++;
    if (result == RENDER_UPDATE)
        sTrace[window].updates++;
}

static void InitTextTest(u32 speed)
{
    SetVBlankCallback(NULL);
    ForgetAllTextPrinters();
    ResetBgsAndClearDma3BusyFlags(0);
    InitBgsFromTemplates(0, sTextTestBg, ARRAY_COUNT(sTextTestBg));
    InitWindows(sTextTestWindows);
    SetDefaultFontsPointer();
    gTextFlags = (TextFlags){0};
    gSaveBlock2Ptr->optionsTextSpeed = speed;
    gMain.newKeys = 0;
    gMain.heldKeys = 0;
    gMain.inBattle = FALSE;
    gBattleTypeFlags = 0;
    memset(sTrace, 0, sizeof(sTrace));
}

static void LoadRecordedTextSpeed(u32 speed, u32 flags)
{
    struct RecordedBattleSave *recorded = AllocZeroed(sizeof(*recorded));
    recorded->textSpeed = speed;
    recorded->battleFlags = flags;
    SetVariablesForRecordedBattle(recorded);
    Free(recorded);
    gMain.inBattle = TRUE;
    gBattleScripting.windowsType = B_WIN_TYPE_NORMAL;
}

static void StartText(u32 window, const u8 *text, u32 speed)
{
    sTrace[window].start = text;
    EXPECT(AddTextPrinterParameterized(window, FONT_NORMAL, text, 0, 0, speed, TracePrinter));
}

static void TextFrame(u16 newKeys, u16 heldKeys)
{
    gMain.newKeys = newKeys;
    gMain.heldKeys = heldKeys;
    RunTextPrinters();
}

static void FinishTextTest(void)
{
    DeactivateAllTextPrinters();
    FreeAllWindowBuffers();
    ResetBgsAndClearDma3BusyFlags(0);
    gTextFlags = (TextFlags){0};
    gMain.newKeys = 0;
    gMain.heldKeys = 0;
    gMain.inBattle = FALSE;
    gBattleTypeFlags = 0;
    gSaveBlock2Ptr->optionsTextSpeed = OPTIONS_TEXT_SPEED_MID;
}

TEST("Family text: Instant renders a full line in one frame")
{
    InitTextTest(OPTIONS_TEXT_SPEED_INSTANT);
    StartText(0, COMPOUND_STRING("Hello world"), GetPlayerTextSpeedDelay());
    TextFrame(0, 0);
    EXPECT_EQ(sTrace[0].prints, 11);
    EXPECT_EQ(sTrace[0].cursor, 11);
    EXPECT_EQ(IsTextPrinterActiveOnWindow(0), FALSE);
    FinishTextTest();
}

TEST("Family text: a pause advances once per frame at every speed")
{
    u32 speed = 0;
    PARAMETRIZE { speed = OPTIONS_TEXT_SPEED_SLOW; }
    PARAMETRIZE { speed = OPTIONS_TEXT_SPEED_MID; }
    PARAMETRIZE { speed = OPTIONS_TEXT_SPEED_FAST; }
    PARAMETRIZE { speed = OPTIONS_TEXT_SPEED_INSTANT; }
    InitTextTest(speed);
    StartText(0, COMPOUND_STRING("{PAUSE 3}B"), 1);
    TextFrame(0, 0);
    EXPECT_EQ(sTrace[0].state, RENDER_STATE_PAUSE);
    EXPECT_EQ(sTrace[0].delay, 2);
    EXPECT_EQ(sTrace[0].prints, 0);
    TextFrame(A_BUTTON, A_BUTTON);
    EXPECT_EQ(sTrace[0].delay, 1);
    EXPECT_EQ(sTrace[0].prints, 0);
    TextFrame(0, A_BUTTON);
    EXPECT_EQ(sTrace[0].delay, 0);
    EXPECT_EQ(sTrace[0].state, RENDER_STATE_PAUSE);
    TextFrame(0, 0);
    EXPECT_EQ(sTrace[0].state, RENDER_STATE_HANDLE_CHAR);
    EXPECT_EQ(sTrace[0].prints, 0);
    TextFrame(0, 0);
    EXPECT_EQ(sTrace[0].prints, 1);
    EXPECT_EQ(sTrace[0].cursor, 4);
    FinishTextTest();
}

TEST("Family text: one A press cannot accept two clear pages")
{
    InitTextTest(OPTIONS_TEXT_SPEED_INSTANT);
    StartText(0, COMPOUND_STRING("A\pB\pC"), 1);
    TextFrame(A_BUTTON, A_BUTTON);
    EXPECT_EQ(sTrace[0].state, RENDER_STATE_CLEAR);
    EXPECT_EQ(sTrace[0].prints, 1);
    TextFrame(A_BUTTON, A_BUTTON);
    EXPECT_EQ(sTrace[0].state, RENDER_STATE_HANDLE_CHAR);
    EXPECT_EQ(sTrace[0].prints, 1);
    TextFrame(0, A_BUTTON);
    EXPECT_EQ(sTrace[0].state, RENDER_STATE_CLEAR);
    EXPECT_EQ(sTrace[0].prints, 2);
    TextFrame(0, A_BUTTON);
    EXPECT_EQ(sTrace[0].state, RENDER_STATE_CLEAR);
    EXPECT_EQ(sTrace[0].prints, 2);
    TextFrame(B_BUTTON, B_BUTTON);
    EXPECT_EQ(sTrace[0].state, RENDER_STATE_HANDLE_CHAR);
    EXPECT_EQ(sTrace[0].prints, 2);
    TextFrame(0, 0);
    EXPECT_EQ(sTrace[0].prints, 3);
    EXPECT_EQ(IsTextPrinterActiveOnWindow(0), FALSE);
    FinishTextTest();
}

TEST("Family text: explicit waits require a fresh input after rendering")
{
    InitTextTest(OPTIONS_TEXT_SPEED_INSTANT);
    StartText(0, COMPOUND_STRING("A{PAUSE_UNTIL_PRESS}B{PAUSE_UNTIL_PRESS}C"), 1);
    TextFrame(A_BUTTON, A_BUTTON);
    EXPECT_EQ(sTrace[0].state, RENDER_STATE_WAIT);
    EXPECT_EQ(sTrace[0].prints, 1);
    TextFrame(0, A_BUTTON);
    EXPECT_EQ(sTrace[0].state, RENDER_STATE_WAIT);
    TextFrame(A_BUTTON, A_BUTTON);
    EXPECT_EQ(sTrace[0].state, RENDER_STATE_HANDLE_CHAR);
    EXPECT_EQ(sTrace[0].prints, 1);
    TextFrame(0, 0);
    EXPECT_EQ(sTrace[0].state, RENDER_STATE_WAIT);
    EXPECT_EQ(sTrace[0].prints, 2);
    TextFrame(0, 0);
    EXPECT_EQ(sTrace[0].prints, 2);
    TextFrame(B_BUTTON, B_BUTTON);
    TextFrame(0, 0);
    EXPECT_EQ(sTrace[0].prints, 3);
    EXPECT_EQ(IsTextPrinterActiveOnWindow(0), FALSE);
    FinishTextTest();
}

TEST("Family text: Instant handles simultaneous printers independently")
{
    InitTextTest(OPTIONS_TEXT_SPEED_INSTANT);
    StartText(0, COMPOUND_STRING("A{PAUSE 3}B"), 1);
    StartText(1, COMPOUND_STRING("The second printer finishes"), 1);
    TextFrame(0, 0);
    EXPECT_EQ(sTrace[0].prints, 1);
    EXPECT_EQ(sTrace[0].delay, 2);
    EXPECT_EQ(sTrace[1].prints, 27);
    EXPECT_EQ(IsTextPrinterActiveOnWindow(0), TRUE);
    EXPECT_EQ(IsTextPrinterActiveOnWindow(1), FALSE);
    TextFrame(0, 0);
    EXPECT_EQ(sTrace[0].delay, 1);
    FinishTextTest();
}

TEST("Family text: ordinary speeds retain their character delays")
{
    u32 speed = 0, delay = 0;
    PARAMETRIZE { speed = OPTIONS_TEXT_SPEED_SLOW; delay = 8; }
    PARAMETRIZE { speed = OPTIONS_TEXT_SPEED_MID; delay = 4; }
    PARAMETRIZE { speed = OPTIONS_TEXT_SPEED_FAST; delay = 1; }
    InitTextTest(speed);
    StartText(0, COMPOUND_STRING("AB"), GetPlayerTextSpeedDelay());
    TextFrame(0, 0);
    EXPECT_EQ(sTrace[0].prints, 1);
    for (u32 frame = 1; frame < delay; frame++)
    {
        TextFrame(0, 0);
        EXPECT_EQ(sTrace[0].prints, 1);
    }
    TextFrame(0, 0);
    EXPECT_EQ(sTrace[0].prints, 2);
    FinishTextTest();
}

TEST("Family text: force Mid overrides selected Instant")
{
    InitTextTest(OPTIONS_TEXT_SPEED_INSTANT);
    gTextFlags.forceMidTextSpeed = TRUE;
    StartText(0, COMPOUND_STRING("AB"), GetPlayerTextSpeedDelay());
    TextFrame(0, 0);
    EXPECT_EQ(sTrace[0].prints, 1);
    EXPECT_EQ(sTrace[0].delay, 3);
    for (u32 frame = 0; frame < 3; frame++)
    {
        TextFrame(0, 0);
        EXPECT_EQ(sTrace[0].prints, 1);
    }
    TextFrame(0, 0);
    EXPECT_EQ(sTrace[0].prints, 2);
    FinishTextTest();
}

TEST("Family text: link and recorded battles retain explicit printer delays")
{
    u32 flags = 0;
    PARAMETRIZE { flags = BATTLE_TYPE_LINK; }
    PARAMETRIZE { flags = BATTLE_TYPE_RECORDED; }
    InitTextTest(OPTIONS_TEXT_SPEED_INSTANT);
    gMain.inBattle = TRUE;
    gBattleTypeFlags = flags;
    if (flags & BATTLE_TYPE_RECORDED)
        LoadRecordedTextSpeed(OPTIONS_TEXT_SPEED_MID, 0);
    StartText(0, COMPOUND_STRING("AB"), 4);
    TextFrame(0, 0);
    EXPECT_EQ(sTrace[0].prints, 1);
    EXPECT_EQ(sTrace[0].delay, 3);
    for (u32 frame = 0; frame < 3; frame++)
    {
        TextFrame(0, 0);
        EXPECT_EQ(sTrace[0].prints, 1);
    }
    TextFrame(0, 0);
    EXPECT_EQ(sTrace[0].prints, 2);
    FinishTextTest();
}

TEST("Family text: Instant auto scroll waits fifty frames")
{
    InitTextTest(OPTIONS_TEXT_SPEED_INSTANT);
    gTextFlags.autoScroll = TRUE;
    StartText(0, COMPOUND_STRING("A{PAUSE_UNTIL_PRESS}B"), 1);
    TextFrame(0, 0);
    EXPECT_EQ(sTrace[0].state, RENDER_STATE_WAIT);
    EXPECT_EQ(sTrace[0].prints, 1);
    for (u32 frame = 1; frame <= 49; frame++)
    {
        TextFrame(0, 0);
        EXPECT_EQ(sTrace[0].autoScroll, frame);
        EXPECT_EQ(sTrace[0].state, RENDER_STATE_WAIT);
        EXPECT_EQ(sTrace[0].prints, 1);
    }
    TextFrame(0, 0);
    EXPECT_EQ(sTrace[0].state, RENDER_STATE_HANDLE_CHAR);
    EXPECT_EQ(sTrace[0].prints, 1);
    TextFrame(0, 0);
    EXPECT_EQ(sTrace[0].prints, 2);
    EXPECT_EQ(IsTextPrinterActiveOnWindow(0), FALSE);
    FinishTextTest();
}

TEST("Family text: Instant scrolls without a twelve-frame compensation")
{
    InitTextTest(OPTIONS_TEXT_SPEED_INSTANT);
    StartText(0, COMPOUND_STRING("A\lB"), 1);
    TextFrame(A_BUTTON, A_BUTTON);
    EXPECT_EQ(sTrace[0].state, RENDER_STATE_SCROLL_START);
    EXPECT_EQ(sTrace[0].prints, 1);
    TextFrame(A_BUTTON, A_BUTTON);
    EXPECT_EQ(sTrace[0].state, RENDER_STATE_SCROLL);
    for (u32 frame = 0; frame < 3; frame++)
    {
        TextFrame(0, 0);
        EXPECT_EQ(sTrace[0].state, RENDER_STATE_SCROLL);
        EXPECT_EQ(sTrace[0].utility, 0);
        EXPECT_EQ(sTrace[0].prints, 1);
    }
    TextFrame(0, 0);
    EXPECT_EQ(sTrace[0].state, RENDER_STATE_HANDLE_CHAR);
    EXPECT_EQ(sTrace[0].prints, 1);
    TextFrame(0, 0);
    EXPECT_EQ(sTrace[0].prints, 2);
    EXPECT_EQ(IsTextPrinterActiveOnWindow(0), FALSE);
    FinishTextTest();
}

TEST("Family text: Instant arrow animation counts frames")
{
    InitTextTest(OPTIONS_TEXT_SPEED_INSTANT);
    StartText(0, COMPOUND_STRING("A\pB"), 1);
    TextFrame(0, 0);
    TextFrame(0, 0);
    EXPECT_EQ(sTrace[0].utility, 8);
    for (u32 frame = 1; frame <= 8; frame++)
    {
        TextFrame(0, 0);
        EXPECT_EQ(sTrace[0].utility, 8 - frame);
        EXPECT_EQ(sTrace[0].prints, 1);
    }
    TextFrame(0, 0);
    EXPECT_EQ(sTrace[0].utility, 8);
    FinishTextTest();
}

TEST("Family text: sound waits yield before and after sound completion")
{
    InitTextTest(OPTIONS_TEXT_SPEED_INSTANT);
    PlaySE12WithPanning(SE_SELECT, 0);
    MPlayMain(&gMPlayInfo_SE1);
    MPlayMain(&gMPlayInfo_SE2);
    EXPECT_EQ(IsSEPlaying(), TRUE);
    StartText(0, COMPOUND_STRING("A{WAIT_SE}B"), 1);
    TextFrame(0, 0);
    EXPECT_EQ(sTrace[0].state, RENDER_STATE_WAIT_SE);
    EXPECT_EQ(sTrace[0].prints, 1);
    TextFrame(A_BUTTON, A_BUTTON);
    EXPECT_EQ(sTrace[0].state, RENDER_STATE_WAIT_SE);
    EXPECT_EQ(sTrace[0].prints, 1);
    m4aMPlayStop(&gMPlayInfo_SE1);
    m4aMPlayStop(&gMPlayInfo_SE2);
    TextFrame(0, 0);
    EXPECT_EQ(sTrace[0].state, RENDER_STATE_HANDLE_CHAR);
    EXPECT_EQ(sTrace[0].prints, 1);
    TextFrame(0, 0);
    EXPECT_EQ(sTrace[0].prints, 2);
    FinishTextTest();
}

TEST("Family text: Instant limits each printer to 1024 glyphs per frame")
{
    u8 text[1026];
    memset(text, CHAR_SPACE, 1025);
    text[1025] = EOS;
    InitTextTest(OPTIONS_TEXT_SPEED_INSTANT);
    StartText(0, text, 1);
    TextFrame(0, 0);
    EXPECT_EQ(sTrace[0].prints, 1024);
    EXPECT_EQ(sTrace[0].cursor, 1024);
    EXPECT_EQ(IsTextPrinterActiveOnWindow(0), TRUE);
    TextFrame(0, 0);
    EXPECT_EQ(sTrace[0].prints, 1025);
    EXPECT_EQ(IsTextPrinterActiveOnWindow(0), FALSE);
    FinishTextTest();
}

TEST("Family text: disabling printers freezes Instant and then resumes")
{
    InitTextTest(OPTIONS_TEXT_SPEED_INSTANT);
    StartText(0, COMPOUND_STRING("ABC"), 1);
    gDisableTextPrinters = TRUE;
    TextFrame(A_BUTTON, A_BUTTON);
    EXPECT_EQ(sTrace[0].prints, 0);
    EXPECT_EQ(IsTextPrinterActiveOnWindow(0), TRUE);
    gDisableTextPrinters = FALSE;
    TextFrame(0, 0);
    EXPECT_EQ(sTrace[0].prints, 3);
    EXPECT_EQ(IsTextPrinterActiveOnWindow(0), FALSE);
    FinishTextTest();
}

TEST("Family text: synchronous UI printing keeps the same rendered pixels")
{
    u32 speed = 0;
    PARAMETRIZE { speed = 0; }
    PARAMETRIZE { speed = TEXT_SKIP_DRAW; }
    InitTextTest(OPTIONS_TEXT_SPEED_INSTANT);
    StartText(0, COMPOUND_STRING("Static UI"), speed);
    EXPECT_EQ(IsTextPrinterActiveOnWindow(0), FALSE);
    StartText(1, COMPOUND_STRING("Static UI"), 1);
    TextFrame(0, 0);
    EXPECT_EQ(sTrace[1].prints, 9);
    EXPECT_EQ(IsTextPrinterActiveOnWindow(1), FALSE);
    EXPECT_EQ(memcmp(gWindows[0].tileData, gWindows[1].tileData, 20 * 6 * 32), 0);
    FinishTextTest();
}

TEST("Family text: recorded Instant uses the real battle message pause path")
{
    const u32 pixelSize = 20 * 6 * 32;
    InitTextTest(OPTIONS_TEXT_SPEED_SLOW);
    u8 *pixels = Alloc(pixelSize);
    LoadRecordedTextSpeed(OPTIONS_TEXT_SPEED_INSTANT, 0);
    BattlePutTextOnWindow(COMPOUND_STRING("A{PAUSE 3}B"), B_WIN_MSG);
    EXPECT_EQ(IsTextPrinterActiveOnWindow(B_WIN_MSG), TRUE);
    TextFrame(0, 0);
    EXPECT_EQ(IsTextPrinterActiveOnWindow(B_WIN_MSG), TRUE);
    memcpy(pixels, (const void *)GetWindowAttribute(B_WIN_MSG, WINDOW_TILE_DATA), pixelSize);
    for (u32 frame = 0; frame < 3; frame++)
    {
        TextFrame(A_BUTTON, A_BUTTON);
        EXPECT_EQ(IsTextPrinterActiveOnWindow(B_WIN_MSG), TRUE);
        EXPECT_EQ(memcmp(pixels, (const void *)GetWindowAttribute(B_WIN_MSG, WINDOW_TILE_DATA), pixelSize), 0);
    }
    TextFrame(0, 0);
    EXPECT_EQ(IsTextPrinterActiveOnWindow(B_WIN_MSG), FALSE);
    EXPECT_NE(memcmp(pixels, (const void *)GetWindowAttribute(B_WIN_MSG, WINDOW_TILE_DATA), pixelSize), 0);
    Free(pixels);
    FinishTextTest();
}

TEST("Family text: recorded battle speed is independent of the current preference")
{
    u32 recordedSpeed = 0, playerSpeed = 0, stillPrinting = 0;
    PARAMETRIZE { recordedSpeed = OPTIONS_TEXT_SPEED_MID; playerSpeed = OPTIONS_TEXT_SPEED_INSTANT; stillPrinting = TRUE; }
    PARAMETRIZE { recordedSpeed = OPTIONS_TEXT_SPEED_INSTANT; playerSpeed = OPTIONS_TEXT_SPEED_SLOW; stillPrinting = FALSE; }
    InitTextTest(playerSpeed);
    LoadRecordedTextSpeed(recordedSpeed, 0);
    BattlePutTextOnWindow(COMPOUND_STRING("ABCDEFGHIJ"), B_WIN_MSG);
    EXPECT_EQ(IsTextPrinterActiveOnWindow(B_WIN_MSG), TRUE);
    TextFrame(0, 0);
    EXPECT_EQ(IsTextPrinterActiveOnWindow(B_WIN_MSG), stillPrinting);
    FinishTextTest();
}

TEST("Family text: recorded link timing takes precedence over recorded Instant")
{
    InitTextTest(OPTIONS_TEXT_SPEED_INSTANT);
    LoadRecordedTextSpeed(OPTIONS_TEXT_SPEED_INSTANT, BATTLE_TYPE_RECORDED_LINK);
    BattlePutTextOnWindow(COMPOUND_STRING("ABCDEFGHIJ"), B_WIN_MSG);
    EXPECT_EQ(IsTextPrinterActiveOnWindow(B_WIN_MSG), TRUE);
    TextFrame(0, 0);
    EXPECT_EQ(IsTextPrinterActiveOnWindow(B_WIN_MSG), TRUE);
    FinishTextTest();
}

TEST("Family text: long Instant printers both reach VRAM without exhausting DMA")
{
    u8 longText[161];
    u32 marker = 0x12345678, copied = 0;
    memset(longText, CHAR_A, sizeof(longText) - 1);
    longText[sizeof(longText) - 1] = EOS;
    InitTextTest(OPTIONS_TEXT_SPEED_INSTANT);
    StartText(0, longText, 1);
    StartText(1, COMPOUND_STRING("B"), 1);
    u16 ime = REG_IME;
    REG_IME = 0;
    CpuFill32(0, (void *)VRAM, 0x4000);
    ClearDma3Requests();
    TextFrame(0, 0);
    s16 request = RequestDma3Copy(&marker, &copied, sizeof(marker), 1);
    for (u32 i = 0; i < 512 && CheckForSpaceForDma3Request(-1) != 0; i++)
        ProcessDma3Requests();
    s32 first = memcmp(gWindows[0].tileData, (const void *)(VRAM + 32), 20 * 6 * 32);
    s32 second = memcmp(gWindows[1].tileData, (const void *)(VRAM + 121 * 32), 20 * 6 * 32);
    REG_IME = ime;
    EXPECT_NE(request, -1);
    EXPECT_EQ(copied, marker);
    EXPECT_EQ(first, 0);
    EXPECT_EQ(second, 0);
    EXPECT_EQ(sTrace[0].prints, 160);
    EXPECT_EQ(sTrace[1].prints, 1);
    EXPECT_EQ(IsTextPrinterActiveOnWindow(0), FALSE);
    EXPECT_EQ(IsTextPrinterActiveOnWindow(1), FALSE);
    FinishTextTest();
}

static void PauseAfterGlyph(struct TextPrinterTemplate *template, u16 result)
{
    TracePrinter(template, result);
    if (result == RENDER_PRINT)
        gDisableTextPrinters = TRUE;
}

TEST("Family text: a callback can pause after one glyph and freeze later printers")
{
    InitTextTest(OPTIONS_TEXT_SPEED_INSTANT);
    const u8 *first = COMPOUND_STRING("AB");
    sTrace[0].start = first;
    EXPECT(AddTextPrinterParameterized(0, FONT_NORMAL, first, 0, 0, 1, PauseAfterGlyph));
    StartText(1, COMPOUND_STRING("CD"), 1);
    TextFrame(0, 0);
    EXPECT_EQ(sTrace[0].prints, 1);
    EXPECT_EQ(sTrace[1].prints, 0);
    EXPECT_EQ(gDisableTextPrinters, TRUE);
    TextFrame(0, 0);
    EXPECT_EQ(sTrace[0].prints, 1);
    EXPECT_EQ(sTrace[1].prints, 0);
    gDisableTextPrinters = FALSE;
    TextFrame(0, 0);
    EXPECT_EQ(sTrace[0].prints, 2);
    EXPECT_EQ(sTrace[1].prints, 0);
    EXPECT_EQ(gDisableTextPrinters, TRUE);
    gDisableTextPrinters = FALSE;
    TextFrame(0, 0);
    EXPECT_EQ(sTrace[0].prints, 2);
    EXPECT_EQ(sTrace[1].prints, 2);
    EXPECT_EQ(IsTextPrinterActiveOnWindow(0), FALSE);
    EXPECT_EQ(IsTextPrinterActiveOnWindow(1), FALSE);
    FinishTextTest();
}
