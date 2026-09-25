#include "global.h"
#include "battle.h"
#include "battle_bg.h"
#include "bg.h"
#include "dma3.h"
#include "palette.h"
#include "text_window.h"
#include "window.h"
#include "test/test.h"

extern const u8 gTextWindowFrame1_Gfx[];
extern const u16 gTextWindowFrame1_Pal[];

TEST("Visual window frames: actual battle loader preserves selected art and palette")
{
    u32 frame, flags;
    PARAMETRIZE { frame = 0; flags = 0; }
    PARAMETRIZE { frame = 1; flags = 0; }
    PARAMETRIZE { frame = 19; flags = 0; }
    PARAMETRIZE { frame = 31; flags = 0; }
    PARAMETRIZE { frame = 0; flags = BATTLE_TYPE_ARENA; }
    PARAMETRIZE { frame = 0; flags = BATTLE_TYPE_POKEDUDE; }
    u32 savedFrame = gSaveBlock2Ptr->optionsWindowFrameType;
    u32 savedFlags = gBattleTypeFlags;
    const struct TilesPal *selected = GetWindowFrameTilesPal(frame);
    const void *tiles = frame == 0 || frame >= WINDOW_FRAMES_COUNT ? gTextWindowFrame1_Gfx : selected->tiles;
    const void *palette = frame == 0 || frame >= WINDOW_FRAMES_COUNT ? gTextWindowFrame1_Pal : selected->pal;
    gSaveBlock2Ptr->optionsWindowFrameType = frame;
    gBattleTypeFlags = flags;
    BattleInitBgsAndWindows();
    LoadBattleMenuWindowGfx();
    ProcessDma3Requests();
    EXPECT_EQ(memcmp(gPlttBufferUnfaded + BG_PLTT_ID(1), palette, PLTT_SIZE_4BPP), 0);
    EXPECT_EQ(memcmp((u8 *)BG_VRAM + 0x12 * TILE_SIZE_4BPP, tiles, 0x120), 0);
    EXPECT_EQ(memcmp((u8 *)BG_VRAM + 0x22 * TILE_SIZE_4BPP, tiles, 0x120), 0);
    EXPECT_EQ((u32)gSaveBlock2Ptr->optionsWindowFrameType, frame);
    FreeAllWindowBuffers();
    gSaveBlock2Ptr->optionsWindowFrameType = savedFrame;
    gBattleTypeFlags = savedFlags;
}
