#include "global.h"
#include "pokevial.h"
#include "constants/items.h"
#include "graphics.h"

#if POKEVIAL_FEATURE

static void PokevialFixDoseOverflow(void);

static void PokevialInit(void)
{
    if (gSaveBlock3Ptr->pokevial.size < VIAL_MIN_SIZE)
    {
        gSaveBlock3Ptr->pokevial.size = VIAL_MIN_SIZE;
        gSaveBlock3Ptr->pokevial.dose = VIAL_MIN_SIZE;
    }
}

u32 PokevialGetDose(void)
{
    PokevialInit();
    // Unlimited Pokevial: always report full so the empty-gate never fires and it always heals
    // the whole party (revive + HP + status + PP), on any existing save. See Pokevial_HealPlayerParty.
    return gSaveBlock3Ptr->pokevial.size;
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
    gSaveBlock3Ptr->pokevial.size = ((PokevialGetSize() - sizeDecrease) < VIAL_MIN_SIZE ? VIAL_MIN_SIZE : (gSaveBlock3Ptr->pokevial.size - sizeDecrease));
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

    if (dose == size)
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

#endif // POKEVIAL_FEATURE
