#include "global.h"
#include "pokevial.h"
#include "constants/items.h"
#include "graphics.h"

#if POKEVIAL_FEATURE

static void PokevialFixDoseOverflow(void);

// The vial lives in two 4-bit SaveBlock3 fields (struct Pokevial: size:4/dose:4) — a config
// raised past 15 would truncate silently on save.
STATIC_ASSERT(POKEVIAL_MAX_SIZE <= 15, PokevialMaxSizeExceedsSaveNibble);

static void PokevialInit(void)
{
    if (gSaveBlock3Ptr->pokevial.size < VIAL_MIN_SIZE)
    {
        gSaveBlock3Ptr->pokevial.size = VIAL_MIN_SIZE;
        gSaveBlock3Ptr->pokevial.dose = VIAL_MIN_SIZE;
    }
    // Un-checksummed SB3 nibbles (same reasoning as PokevialGetVialPercent's clamp): a
    // corrupted pair like size=2/dose=15 passed the floor check above and granted 15 heals.
    // Clamped DIRECTLY — PokevialFixDoseOverflow routes through PokevialDoseUp ->
    // PokevialGetDose -> PokevialInit and would recurse without bound.
    if (gSaveBlock3Ptr->pokevial.dose > gSaveBlock3Ptr->pokevial.size)
        gSaveBlock3Ptr->pokevial.dose = gSaveBlock3Ptr->pokevial.size;
}

u32 PokevialGetDose(void)
{
    PokevialInit();
    return gSaveBlock3Ptr->pokevial.dose;
}

u32 PokevialGetSize(void)
{
    PokevialInit();
    return gSaveBlock3Ptr->pokevial.size;
}

void PokevialSizeUp(u8 sizeIncrease)
{
    gSaveBlock3Ptr->pokevial.size = ((PokevialGetSize() + sizeIncrease) > VIAL_MAX_SIZE ? VIAL_MAX_SIZE : gSaveBlock3Ptr->pokevial.size + sizeIncrease);
}

void PokevialDoseUp(u8 doseIncrease)
{
    gSaveBlock3Ptr->pokevial.dose = ((PokevialGetDose() + doseIncrease) > gSaveBlock3Ptr->pokevial.size ? gSaveBlock3Ptr->pokevial.size : gSaveBlock3Ptr->pokevial.dose + doseIncrease);
}

void PokevialSizeDown(u8 sizeDecrease)
{
    gSaveBlock3Ptr->pokevial.size = ((sizeDecrease >= PokevialGetSize() || (PokevialGetSize() - sizeDecrease) < VIAL_MIN_SIZE) ? VIAL_MIN_SIZE : (gSaveBlock3Ptr->pokevial.size - sizeDecrease));
    PokevialFixDoseOverflow();
}

void PokevialDoseDown(u8 doseDecrease)
{
    gSaveBlock3Ptr->pokevial.dose = (doseDecrease > PokevialGetDose()) ? EMPTY_VIAL : (gSaveBlock3Ptr->pokevial.dose - doseDecrease);
}

static void PokevialFixDoseOverflow(void)
{
    PokevialDoseUp(0);
}

bool32 PokevialRefill(void)
{
    if (PokevialGetDose() == PokevialGetSize())
        return FALSE;

    gSaveBlock3Ptr->pokevial.dose = gSaveBlock3Ptr->pokevial.size;
    return TRUE;
}

const u32 *const pokevialIconIndex[VIAL_NUM_STATES] =
{
    gItemIcon_Pokevial0,
    gItemIcon_Pokevial1,
    gItemIcon_Pokevial2,
    gItemIcon_Pokevial3,
    gItemIcon_Pokevial4,
    gItemIcon_Pokevial5,
    gItemIcon_Pokevial6,
    gItemIcon_Pokevial7,
    gItemIcon_Pokevial8,
    gItemIcon_Pokevial9,
    gItemIcon_Pokevial
};

static u32 PokevialGetVialPercent(void)
{
    u32 dose = PokevialGetDose(), size = PokevialGetSize(), vialPercent = 0;

    if (dose == EMPTY_VIAL)
        return POKEVIAL_ICON_PERCENT_0;

    if (dose >= size) // >= : the nibbles live in un-checksummed SB3 — never index past the icon table
        return POKEVIAL_ICON_PERCENT_100;

    vialPercent = (dose * 10 / size);

    return (vialPercent == EMPTY_VIAL && dose > EMPTY_VIAL) ? POKEVIAL_ICON_PERCENT_10 : vialPercent;
}

const void *PokevialGetDoseIcon(void)
{
    return pokevialIconIndex[PokevialGetVialPercent()];
}

void Pokevial_HealPlayerParty(void)
{
    u8 i, j;
    u8 ppBonuses;
    u8 arg[4];

    // restore HP.
    for (i = 0; i < gPartiesCount[B_TRAINER_PLAYER]; i++)
    {
        u16 maxHP = GetMonData(&gParties[B_TRAINER_PLAYER][i], MON_DATA_MAX_HP);
        arg[0] = maxHP;
        arg[1] = maxHP >> 8;
        SetMonData(&gParties[B_TRAINER_PLAYER][i], MON_DATA_HP, arg);
        ppBonuses = GetMonData(&gParties[B_TRAINER_PLAYER][i], MON_DATA_PP_BONUSES);

        // restore PP.
        for (j = 0; j < MAX_MON_MOVES; j++)
        {
            arg[0] = CalculatePPWithBonus(GetMonData(&gParties[B_TRAINER_PLAYER][i], MON_DATA_MOVE1 + j), ppBonuses, j);
            SetMonData(&gParties[B_TRAINER_PLAYER][i], MON_DATA_PP1 + j, arg);
        }

        arg[0] = 0;
        arg[1] = 0;
        arg[2] = 0;
        arg[3] = 0;
        SetMonData(&gParties[B_TRAINER_PLAYER][i], MON_DATA_STATUS, arg);
    }
}

#else // POKEVIAL_FEATURE
// data/specials.inc holds these three def_special rows UNCONDITIONALLY -- that table
// is index-based and a conditional row silently renumbers every special after it in
// test builds (see the comment on the rows). So the flag is honoured here, at the
// target, exactly as #59 did for the 25 link specials in src/cable_club.c.
//
// PokevialRefill is genuinely REACHABLE with the feature off: both PokeCenter nurse
// scripts call `special PokevialRefill` unconditionally, right after HealPlayerParty.
// FALSE is the honest answer -- there is no vial to top up -- and `special` discards
// the return anyway, so the nurse just heals and moves on.
bool32 PokevialRefill(void)
{
    return FALSE;
}

// Reachable only through the `pokevialgetdose` / `pokevialgetsize` macros, which
// asm/macros/event.inc compiles out with the feature. They exist to keep the two
// table rows linkable; an absent vial holds nothing and has no capacity.
u32 PokevialGetDose(void)
{
    return EMPTY_VIAL;
}

u32 PokevialGetSize(void)
{
    return EMPTY_VIAL;
}

#endif // POKEVIAL_FEATURE
