#include "global.h"
#include "fieldmap.h"
#include "constants/layouts.h"
#include "constants/metatile_behaviors.h"
#include "test/test.h"

// Issue #53: the metatile-attribute width is a property of the TILESET, not of the layout.
//
// `MapGridGetMetatileAttributeAt` used to select the width from `mapLayout->isFrlg`. Eleven
// `layout_version: "johto"` layouts borrow a Kanto tileset whose attribute blob is natively u32, so
// those layouts read a u32 blob at u16 stride: metatile `m` landed on byte `2m`, which made even ids
// return a different metatile's behaviour and odd ids return ~0 = MB_NORMAL. `hasFrlgAttributes` now
// carries the width per tileset, derived at compile time by TILESET_METATILES from the blob sizes.
//
// Both mixed shapes are covered, because one flag per layout cannot express either of them:
//   NATIONAL_PARK_NORMAL = u32 primary (gTileset_General_Frlg) + u16 secondary (gTileset_NationalPark)
//   ROUTE28              = u16 primary (gTileset_Johto_NorthEast) + u32 secondary (gTileset_ViridianCity)
//
// Every "expect an arrow warp / a door" line below returned MB_NORMAL before the fix, and every
// control line returned the same value before and after — so a regression to a single layout-wide
// width fails the first group and still passes the second, which is what makes the pairs worth having.

extern const struct MapLayout *const gMapLayouts[];

#define SECONDARY(i) (NUM_METATILES_IN_PRIMARY_FRLG + (i))

static u32 BehaviorOf(u32 layoutId, u16 metatile)
{
    gMapHeader.mapLayout = gMapLayouts[layoutId - 1];
    return GetAttributeByMetatileIdAndMapLayout(metatile, METATILE_ATTRIBUTE_BEHAVIOR);
}

TEST("A johto layout reads a borrowed Kanto PRIMARY at u32")
{
    const struct MapLayout *saved = gMapHeader.mapLayout;

    // National Park's three gate tiles. Read at u16 these are all MB_NORMAL, and neither
    // IsArrowWarpMetatileBehavior nor IsWarpMetatileBehavior accepts MB_NORMAL - so the park's only
    // exits could not fire and entering it was a one-way trip.
    EXPECT_EQ(BehaviorOf(LAYOUT_NATIONAL_PARK_NORMAL, 377), MB_SOUTH_ARROW_WARP);
    EXPECT_EQ(BehaviorOf(LAYOUT_NATIONAL_PARK_NORMAL, 320), MB_EAST_ARROW_WARP);
    EXPECT_EQ(BehaviorOf(LAYOUT_NATIONAL_PARK_NORMAL, 324), MB_WEST_ARROW_WARP);
    EXPECT_EQ(BehaviorOf(LAYOUT_NATIONAL_PARK_NORMAL, 503), MB_NORTH_ARROW_WARP);

    // Same layout, its own Johto SECONDARY: still u16, and it always was. This is the half that a
    // "make the whole layout u32" fix would break.
    EXPECT_EQ(BehaviorOf(LAYOUT_NATIONAL_PARK_NORMAL, SECONDARY(7)), MB_LONG_GRASS);
    EXPECT_EQ(BehaviorOf(LAYOUT_NATIONAL_PARK_NORMAL, SECONDARY(15)), MB_LONG_GRASS);

    gMapHeader.mapLayout = saved;
}

TEST("A johto layout reads a borrowed Kanto SECONDARY at u32")
{
    const struct MapLayout *saved = gMapHeader.mapLayout;

    // The opposite mix. mt 665 is an animated door: #39 established that a door works because of its
    // BEHAVIOUR, not its collision, so reading this one as MB_NORMAL turned a door into a wall.
    EXPECT_EQ(BehaviorOf(LAYOUT_ROUTE28, SECONDARY(25)), MB_ANIMATED_DOOR);
    EXPECT_EQ(BehaviorOf(LAYOUT_ROUTE28, SECONDARY(14)), MB_JUMP_SOUTH);

    // Its Johto primary is u16 and unaffected.
    EXPECT_EQ(BehaviorOf(LAYOUT_ROUTE28, 11), MB_TALL_GRASS);
    EXPECT_EQ(BehaviorOf(LAYOUT_ROUTE28, 12), MB_TALL_GRASS);

    gMapHeader.mapLayout = saved;
}

TEST("An out-of-range metatile is still MB_INVALID")
{
    const struct MapLayout *saved = gMapHeader.mapLayout;
    EXPECT_EQ(BehaviorOf(LAYOUT_NATIONAL_PARK_NORMAL, NUM_METATILES_TOTAL), MB_INVALID);
    gMapHeader.mapLayout = saved;
}
