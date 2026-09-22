#include "global.h"
#include "fieldmap.h"
#include "sprite.h"
#include "test/test.h"
#include "constants/layouts.h"
#include "constants/species.h"

extern bool32 Test_OWECanLoadGraphics(enum Species species, s32 x, s32 y);
extern const struct MapLayout *const gMapLayouts[];

TEST("Overworld encounter graphics: palette exhaustion skips spawn")
{
    ResetSpriteData();
    FreeAllSpritePalettes();
    for (u32 i = 0; i < 16; i++)
        AllocSpritePalette(0x7000 + i);
    EXPECT(!Test_OWECanLoadGraphics(SPECIES_EKANS, 0, 0));
    FreeAllSpritePalettes();
}

TEST("Overworld encounter graphics: full tile pool skips spawn and recovers")
{
    const struct MapLayout *savedLayout = gMapHeader.mapLayout;
    struct BackupMapLayout savedBackup = gBackupMapLayout;
    u16 grass = 11 | (3 << 12);

    ResetSpriteData();
    FreeAllSpritePalettes();
    gMapHeader.mapLayout = gMapLayouts[LAYOUT_ROUTE42 - 1];
    gBackupMapLayout = (struct BackupMapLayout){.width = 1, .height = 1, .map = &grass};
    for (u32 i = 0; i < 1024; i++)
        SpriteTileAllocBitmapOp(i, 1);
    EXPECT(!Test_OWECanLoadGraphics(SPECIES_EKANS, 0, 0));
    ResetSpriteData();
    EXPECT(Test_OWECanLoadGraphics(SPECIES_EKANS, 0, 0));
    gMapHeader.mapLayout = savedLayout;
    gBackupMapLayout = savedBackup;
}
