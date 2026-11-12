#include "global.h"
#include "player_outfit.h"
#include "main.h"
#include "task.h"
#include "menu.h"
#include "window.h"
#include "text.h"
#include "text_window.h"
#include "palette.h"
#include "sprite.h"
#include "trainer_pokemon_sprites.h"
#include "event_object_movement.h"
#include "field_player_avatar.h"
#include "event_data.h"
#include "overworld.h"
#include "field_screen_effect.h"
#include "script.h"
#include "sound.h"
#include "constants/event_objects.h"
#include "constants/songs.h"
#include "constants/vars.h"

#define OUTFIT_PREVIEW_TRAINER_TAG 0xF374
#define OUTFIT_PREVIEW_OVERWORLD_TAG 0xF375

struct PlayerOutfitPicker
{
    u16 selection;
    bool8 active;
    bool8 intro;
    u8 windowId;
    u8 trainerSpriteId;
    u8 overworldSpriteId;
    void (*callback)(bool8 confirmed);
};

EWRAM_DATA struct PlayerOutfitPicker gPlayerOutfitPicker = {0};

static const struct WindowTemplate sWindow =
{
    .bg = 0,
    .tilemapLeft = 1,
    .tilemapTop = 1,
    .width = 28,
    .height = 18,
    .paletteNum = 15,
    .baseBlock = 1,
};
static const u8 sTitle[] = _("CHOOSE YOUR OUTFIT");
static const u8 sRed[] = _("Red");
static const u8 sBlue[] = _("Blue");
static const u8 sGreen[] = _("Green");
static const u8 sPurple[] = _("Purple");
static const u8 sBlack[] = _("Black");
static const u8 sPink[] = _("Pink");
static const u8 *const sColors[] = {sRed, sBlue, sGreen, sPurple, sBlack, sPink};
static const u8 sStyleControls[] = _("{LEFT_ARROW} Style {RIGHT_ARROW}");
static const u8 sIntroHelp[] = _("A: Confirm");
static const u8 sHubHelp[] = _("A: Apply  B: Cancel");
static const u8 sLater[] = _("Change later at World Transit.");
static const u8 sCursor[] = _("{RIGHT_ARROW}");
static const u8 sTextColors[] = {TEXT_COLOR_WHITE, TEXT_COLOR_DARK_GRAY, TEXT_COLOR_LIGHT_GRAY};

static EWRAM_DATA struct SpriteTemplate sPreviewTemplate = {0};

static void DestroyPreviews(void)
{
    if (gPlayerOutfitPicker.trainerSpriteId < MAX_SPRITES)
        FreeAndDestroyTrainerPicSprite(gPlayerOutfitPicker.trainerSpriteId);
    if (gPlayerOutfitPicker.overworldSpriteId < MAX_SPRITES)
        DestroySpriteAndFreeResources(&gSprites[gPlayerOutfitPicker.overworldSpriteId]);
    FreeSpritePaletteByTag(OUTFIT_PREVIEW_TRAINER_TAG);
    FreeSpritePaletteByTag(OUTFIT_PREVIEW_OVERWORLD_TAG);
    gPlayerOutfitPicker.trainerSpriteId = MAX_SPRITES;
    gPlayerOutfitPicker.overworldSpriteId = MAX_SPRITES;
}

static void DrawPicker(void)
{
    u32 i;
    u8 window = gPlayerOutfitPicker.windowId;
    FillWindowPixelBuffer(window, PIXEL_FILL(TEXT_COLOR_WHITE));
    AddTextPrinterParameterized3(window, FONT_NORMAL, 8, 0, sTextColors, 0, sTitle);
    AddTextPrinterParameterized3(window, FONT_SMALL, 8, 18, sTextColors, 0, sStyleControls);
    AddTextPrinterParameterized3(window, FONT_NORMAL, 8, 30, sTextColors, 0, GetOutfitStyleName(gPlayerOutfitPicker.selection));
    for (i = 0; i < ARRAY_COUNT(sColors); i++)
        AddTextPrinterParameterized3(window, FONT_SMALL, 20, 47 + i * 12, sTextColors, 0, sColors[i]);
    AddTextPrinterParameterized3(window, FONT_SMALL, 7, 47 + (gPlayerOutfitPicker.selection % PLAYER_OUTFIT_COLOR_COUNT) * 12, sTextColors, 0, sCursor);
    AddTextPrinterParameterized3(window, FONT_SMALL, 8, 119, sTextColors, 0, gPlayerOutfitPicker.intro ? sIntroHelp : sHubHelp);
    AddTextPrinterParameterized3(window, FONT_SMALL, 8, 132, sTextColors, 0, sLater);
    PutWindowTilemap(window);
    CopyWindowToVram(window, COPYWIN_FULL);
}

static bool8 CreatePreviews(void)
{
    enum Gender gender = gSaveBlock2Ptr->playerGender;
    u16 selection = gPlayerOutfitPicker.selection;
    u16 graphicsId = GetOutfitGraphicsId(selection, gender == FEMALE ? OBJ_EVENT_GFX_MAY_NORMAL : OBJ_EVENT_GFX_BRENDAN_NORMAL);
    const struct ObjectEventGraphicsInfo *info = GetObjectEventGraphicsInfo(graphicsId);
    u16 palette[16] = {0};
    struct SpritePalette spritePalette = {palette, OUTFIT_PREVIEW_OVERWORLD_TAG};
    u8 slot;
    u16 trainer;
    u32 i, freeSprites = 0;

    DestroyPreviews();
    // The sprite keeps this pointer and reads it again when destroyed, so it must outlive the call.
    sPreviewTemplate = (struct SpriteTemplate)
    {
        .tileTag = TAG_NONE,
        .paletteTag = OUTFIT_PREVIEW_OVERWORLD_TAG,
        .oam = info->oam,
        .anims = info->anims,
        .images = info->images,
        .affineAnims = gDummySpriteAffineAnimTable,
        .callback = SpriteCallbackDummy,
    };
    for (i = 0; i < MAX_SPRITES; i++)
        if (!gSprites[i].inUse)
            freeSprites++;
    if (freeSprites < 2)
        return FALSE;
    spritePalette.tag = OUTFIT_PREVIEW_TRAINER_TAG;
    if (LoadSpritePalette(&spritePalette) == 0xFF)
        return FALSE;
    spritePalette.tag = OUTFIT_PREVIEW_OVERWORLD_TAG;
    slot = LoadSpritePalette(&spritePalette);
    if (slot == 0xFF)
        return FALSE;
    trainer = CreateTrainerPicSprite(GetOutfitTrainerPic(selection, gender), TRUE, 159, 75, 0, OUTFIT_PREVIEW_TRAINER_TAG);
    if (trainer >= MAX_SPRITES)
        return FALSE;
    gPlayerOutfitPicker.trainerSpriteId = trainer;
    gSprites[trainer].oam.priority = 0;
    LoadOutfitPalette(selection, gender, OUTFIT_PALETTE_FRONT, OBJ_PLTT_ID(gSprites[trainer].oam.paletteNum));
    LoadOutfitPalette(selection, gender, OUTFIT_PALETTE_OVERWORLD, OBJ_PLTT_ID(slot));
    gPlayerOutfitPicker.overworldSpriteId = CreateSprite(&sPreviewTemplate, 210, 100, 0);
    if (gPlayerOutfitPicker.overworldSpriteId >= MAX_SPRITES)
    {
        FreeSpritePaletteByTag(OUTFIT_PREVIEW_OVERWORLD_TAG);
        return FALSE;
    }
    gSprites[gPlayerOutfitPicker.overworldSpriteId].oam.priority = 0;
    StartSpriteAnim(&gSprites[gPlayerOutfitPicker.overworldSpriteId], 0);
    return TRUE;
}

static void ClosePicker(u8 taskId, bool8 confirmed)
{
    void (*callback)(bool8) = gPlayerOutfitPicker.callback;
    if (confirmed)
        VarSet(VAR_PLAYER_PALETTE, gPlayerOutfitPicker.selection);
    DestroyPreviews();
    ClearStdWindowAndFrameToTransparent(gPlayerOutfitPicker.windowId, TRUE);
    RemoveWindow(gPlayerOutfitPicker.windowId);
    gPlayerOutfitPicker.active = FALSE;
    DestroyTask(taskId);
    callback(confirmed);
}

static void Task_OutfitPicker(u8 taskId)
{
    u16 selection = gPlayerOutfitPicker.selection;
    u8 style = selection / PLAYER_OUTFIT_COLOR_COUNT;
    u8 color = selection % PLAYER_OUTFIT_COLOR_COUNT;
    if (!gTasks[taskId].data[0])
    {
        gTasks[taskId].data[0] = 1;
        return;
    }
    if (JOY_NEW(A_BUTTON))
    {
        PlaySE(SE_SELECT);
        ClosePicker(taskId, TRUE);
        return;
    }
    if (JOY_NEW(B_BUTTON))
    {
        PlaySE(SE_SELECT);
        if (!gPlayerOutfitPicker.intro)
            ClosePicker(taskId, FALSE);
        return;
    }
    if (JOY_NEW(DPAD_LEFT))
        style = (style + PLAYER_OUTFIT_STYLE_COUNT - 1) % PLAYER_OUTFIT_STYLE_COUNT;
    else if (JOY_NEW(DPAD_RIGHT))
        style = (style + 1) % PLAYER_OUTFIT_STYLE_COUNT;
    else if (JOY_NEW(DPAD_UP))
        color = (color + PLAYER_OUTFIT_COLOR_COUNT - 1) % PLAYER_OUTFIT_COLOR_COUNT;
    else if (JOY_NEW(DPAD_DOWN))
        color = (color + 1) % PLAYER_OUTFIT_COLOR_COUNT;
    gPlayerOutfitPicker.selection = style * PLAYER_OUTFIT_COLOR_COUNT + color;
    if (selection != gPlayerOutfitPicker.selection)
    {
        PlaySE(SE_SELECT);
        DrawPicker();
        if (!CreatePreviews())
        {
            gPlayerOutfitPicker.selection = selection;
            DrawPicker();
            if (!CreatePreviews())
                ClosePicker(taskId, FALSE);
        }
    }
}

bool8 OpenPlayerOutfitPicker(bool8 intro, void (*callback)(bool8 confirmed))
{
    u8 window;
    if (gPlayerOutfitPicker.active || GetTaskCount() >= NUM_TASKS)
        return FALSE;
    window = AddWindow(&sWindow);
    if (window == WINDOW_NONE)
        return FALSE;
    gPlayerOutfitPicker.selection = intro ? 0 : GetEquippedPlayerOutfit();
    gPlayerOutfitPicker.intro = intro;
    gPlayerOutfitPicker.windowId = window;
    gPlayerOutfitPicker.trainerSpriteId = MAX_SPRITES;
    gPlayerOutfitPicker.overworldSpriteId = MAX_SPRITES;
    gPlayerOutfitPicker.callback = callback;
    LoadUserWindowBorderGfx(window, STD_WINDOW_BASE_TILE_NUM, BG_PLTT_ID(14));
    Menu_LoadStdPalAt(BG_PLTT_ID(15));
    DrawStdFrameWithCustomTileAndPalette(window, FALSE, STD_WINDOW_BASE_TILE_NUM, 14);
    DrawPicker();
    if (!CreatePreviews())
    {
        DestroyPreviews();
        ClearStdWindowAndFrameToTransparent(window, TRUE);
        RemoveWindow(window);
        return FALSE;
    }
    gPlayerOutfitPicker.active = TRUE;
    CreateTask(Task_OutfitPicker, 1);
    return TRUE;
}

static void ReturnFromWardrobe(bool8 confirmed)
{
    if (confirmed)
        ObjectEventSetGraphicsId(&gObjectEvents[gPlayerAvatar.objectEventId], GetPlayerAvatarGraphicsIdByCurrentState());
    SetMainCallback2(CB2_ReturnToFieldContinueScriptPlayMapMusic);
}

void ShowPlayerWardrobe(void)
{
    if (!OpenPlayerOutfitPicker(FALSE, ReturnFromWardrobe))
        ScriptContext_Enable();
}
