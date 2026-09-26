#ifndef GUARD_BATTLE_PRESENTATION_H
#define GUARD_BATTLE_PRESENTATION_H

#include "battle_bg.h"
#include "palette.h"
#include "constants/map_types.h"

#define BATTLE_PRESENTATION_COLORS (3 * 16)

// Visual inputs only. The resolver never changes battle environment mechanics.
struct BattlePresentationContext
{
    u16 environment;
    u16 entryEnvironment;
    u16 introEnvironment;
    u16 map;
    enum MapType mapType;
    u32 battleTypeFlags;
    bool8 preserveOriginal;
    struct TimeBlendSettings time;
};

struct BattlePresentation
{
    struct BattleBackground background;
    struct BattleBackgroundEntry entry;
    const u16 *dayPalette;
    u16 introEnvironment;
    bool8 tintWithTime;
    struct TimeBlendSettings time;
};

void ResolveBattlePresentation(const struct BattlePresentationContext *context, struct BattlePresentation *result);
void BuildBattlePresentationPalette(const struct BattlePresentation *presentation, u16 *dest);

#endif
