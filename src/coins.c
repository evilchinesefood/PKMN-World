#include "global.h"
#include "coins.h"
#include "event_data.h"
#include "money.h"
#include "text.h"
#include "window.h"
#include "strings.h"
#include "string_util.h"
#include "menu.h"
#include "international_string_util.h"
#include "constants/coins.h"

static EWRAM_DATA u8 sCoinsWindowId = 0;

void PrintCoinsString(u32 coinAmount)
{
    u32 xAlign;

    ConvertIntToDecimalStringN(gStringVar1, coinAmount, STR_CONV_MODE_RIGHT_ALIGN, MAX_COIN_DIGITS);
    StringExpandPlaceholders(gStringVar4, gText_Coins);

    xAlign = GetStringRightAlignXOffset(FONT_NORMAL, gStringVar4, 0x40);
    AddTextPrinterParameterized(sCoinsWindowId, FONT_NORMAL, gStringVar4, xAlign, 1, 0, NULL);
}

void ShowCoinsWindow(u32 coinAmount, u8 x, u8 y)
{
    struct WindowTemplate template;
    SetWindowTemplateFields(&template, 0, x, y, 8, 2, 0xF, 0x141);
    sCoinsWindowId = AddWindow(&template);
    FillWindowPixelBuffer(sCoinsWindowId, PIXEL_FILL(0));
    PutWindowTilemap(sCoinsWindowId);
    DrawStdFrameWithCustomTileAndPalette(sCoinsWindowId, FALSE, STD_WINDOW_BASE_TILE_NUM, 0xE);
    PrintCoinsString(coinAmount);
}

void HideCoinsWindow(void)
{
    ClearStdWindowAndFrame(sCoinsWindowId, TRUE);
    RemoveWindow(sCoinsWindowId);
}

u16 GetCoins(void)
{
    return gSaveBlock1Ptr->coins ^ gSaveBlock2Ptr->encryptionKey;
}

void SetCoins(u16 coinAmount)
{
    gSaveBlock1Ptr->coins = coinAmount ^ gSaveBlock2Ptr->encryptionKey;
}

bool8 AddCoins(u16 toAdd)
{
    u16 newAmount;
    u16 ownedCoins = GetCoins();
    if (ownedCoins >= MAX_COINS)
        return FALSE;
    // check overflow, can't have less coins than previously
    if (ownedCoins > ownedCoins + toAdd)
    {
        newAmount = MAX_COINS;
    }
    else
    {
        ownedCoins += toAdd;
        if (ownedCoins > MAX_COINS)
            ownedCoins = MAX_COINS;
        newAmount = ownedCoins;
    }
    SetCoins(newAmount);
    return TRUE;
}

bool8 RemoveCoins(u16 toSub)
{
    u16 ownedCoins = GetCoins();
    if (ownedCoins >= toSub)
    {
        SetCoins(ownedCoins - toSub);
        return TRUE;
    }
    return FALSE;
}

// The coin desks fill the case to MAX_COINS rather than refusing a block that does not fit, so
// charge only for the coins that fit. Charging the whole block bought one coin for 100000.
// VAR_0x8004 = coins asked for; VAR_RESULT = BUY_COINS_*.
void BuyGameCornerCoins(void)
{
    u32 owned = GetCoins();
    u32 coins = owned >= MAX_COINS ? 0 : min(gSpecialVar_0x8004, MAX_COINS - owned);
    u32 cost = coins * GAME_CORNER_COIN_PRICE;

    if (coins == 0)
    {
        gSpecialVar_Result = BUY_COINS_CASE_FULL;
    }
    else if (!IsEnoughMoney(&gSaveBlock1Ptr->money, cost))
    {
        gSpecialVar_Result = BUY_COINS_NO_MONEY;
    }
    else
    {
        AddCoins(coins);
        RemoveMoney(&gSaveBlock1Ptr->money, cost);
        gSpecialVar_Result = BUY_COINS_OK;
    }
}
