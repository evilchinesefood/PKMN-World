#include "global.h"
#include "daycare.h"
#include "event_data.h"
#include "main.h"
#include "move_relearner.h"
#include "overworld.h"
#include "party_menu.h"
#include "pokemon.h"
#include "pokemon_storage_system.h"
#include "regional_travel.h"
#include "special_pokemon.h"
#include "constants/daycare.h"

static bool32 BytesEqual(const void *first, const void *second, u32 size)
{
    const u8 *a = first;
    const u8 *b = second;
    for (u32 i = 0; i < size; i++)
        if (a[i] != b[i])
            return FALSE;
    return TRUE;
}

static void ClearOwnership(void)
{
    ZeroPlayerPartyMons();
    memset(gPokemonStoragePtr->boxes, 0, sizeof(gPokemonStoragePtr->boxes));
    memset(gPokemonStoragePtr->fusions, 0, sizeof(gPokemonStoragePtr->fusions));
    memset(&gSaveBlock1Ptr->daycare, 0, sizeof(gSaveBlock1Ptr->daycare));
    memset(&gSaveBlock3Ptr->region.route5DayCareMon, 0, sizeof(gSaveBlock3Ptr->region.route5DayCareMon));
    for (u32 i = 0; i < SPECIAL_POKEMON_COUNT; i++)
        FlagClear(SpecialPokemon_GetEntry(i)->collectedFlag);
}

static struct Pokemon *Acquire(u32 id)
{
    const struct SpecialPokemonEntry *entry = SpecialPokemon_GetEntry(id);
    u32 slot = gPartiesCount[B_TRAINER_PLAYER];
    FlagSet(entry->unlockedFlag);
    gSpecialVar_0x8004 = id;
    if (entry->sourceKind == SPECIAL_POKEMON_GIFT)
        SpecialPokemon_Give();
    else
    {
        SpecialPokemon_CreateEncounter();
        if (gSpecialVar_Result)
            gSpecialVar_Result = GiveCapturedMonToPlayer(&gParties[B_TRAINER_OPPONENT_A][0]);
        else
            gSpecialVar_Result = MON_CANT_GIVE;
    }
    if (gSpecialVar_Result != MON_GIVEN_TO_PARTY)
        return NULL;
    return &gParties[B_TRAINER_PLAYER][slot];
}

static u32 CheckAcquisitions(void)
{
    u32 passed = 0;
    for (u32 id = 0; id < SPECIAL_POKEMON_COUNT; id++)
    {
        const struct SpecialPokemonEntry *entry = SpecialPokemon_GetEntry(id);
        const struct SpeciesInfo *variant = &gSpeciesInfo[entry->species];
        const struct SpeciesInfo *base = &gSpeciesInfo[entry->baseSpecies];
        struct Pokemon *first;
        struct Pokemon *second;
        u32 occurrences = 0;
        bool32 ok;
        ClearOwnership();
        first = Acquire(id);
        if (first == NULL)
            continue;
        second = Acquire(id);
        if (second == NULL)
            continue;
        for (u32 move = 0; move < MAX_MON_MOVES; move++)
            occurrences += GetMonData(first, MON_DATA_MOVE1 + move) == entry->themedMove;
        ok = GetMonData(first, MON_DATA_SPECIES) == entry->species
            && GetMonData(first, MON_DATA_LEVEL) == entry->level
            && !GetMonData(first, MON_DATA_IS_SHINY)
            && !GetMonData(first, MON_DATA_HELD_ITEM)
            && occurrences == 1
            && FlagGet(entry->collectedFlag)
            && (GetMonData(first, MON_DATA_PERSONALITY) != GetMonData(second, MON_DATA_PERSONALITY)
                || GetMonData(first, MON_DATA_IVS) != GetMonData(second, MON_DATA_IVS))
            && variant->baseHP == base->baseHP + (base->baseHP * 15 + 50) / 100
            && variant->baseAttack == base->baseAttack + (base->baseAttack * 15 + 50) / 100
            && variant->baseDefense == base->baseDefense + (base->baseDefense * 15 + 50) / 100
            && variant->baseSpeed == base->baseSpeed + (base->baseSpeed * 15 + 50) / 100
            && variant->baseSpAttack == base->baseSpAttack + (base->baseSpAttack * 15 + 50) / 100
            && variant->baseSpDefense == base->baseSpDefense + (base->baseSpDefense * 15 + 50) / 100
            && variant->types[0] == base->types[0] && variant->types[1] == base->types[1]
            && variant->genderRatio == base->genderRatio
            && variant->abilities[0] == base->abilities[0]
            && variant->abilities[1] == base->abilities[1]
            && variant->abilities[2] == base->abilities[2]
            && variant->levelUpLearnset == base->levelUpLearnset
            && variant->natDexNum == base->natDexNum
            && GET_BASE_SPECIES_ID(entry->species) == entry->baseSpecies
            && CanLearnTeachableMove(entry->species, entry->themedMove);
        if (!RegionalTravel_RecordDeparture(REGION_HOENN)
            || !GetMonData(first, MON_DATA_REGIONAL_ID)
            || GetMonData(first, MON_DATA_REGIONAL_ID) == GetMonData(second, MON_DATA_REGIONAL_ID))
            ok = FALSE;
        if (ok)
            passed |= 1 << id;
    }
    return passed;
}

static u32 CheckBreedingAndEvolution(void)
{
    struct Pokemon first, second;
    struct DayCare daycare = {0};
    u32 passed = 0;
    for (u32 id = 0; id < SPECIAL_POKEMON_COUNT; id++)
    {
        const struct SpecialPokemonEntry *entry = SpecialPokemon_GetEntry(id);
        bool32 ok = TRUE;
        CreateRandomMon(&first, entry->species, 100);
        for (u32 partner = 0; partner < 3; partner++)
        {
            u16 species = partner == 0 ? SPECIES_DITTO : partner == 1 ? entry->baseSpecies : entry->species;
            CreateRandomMon(&second, species, 100);
            daycare.mons[0].mon = first.box;
            daycare.mons[1].mon = second.box;
            ok &= GetDaycareCompatibilityScore(&daycare) == PARENTS_INCOMPATIBLE;
            daycare.mons[0].mon = second.box;
            daycare.mons[1].mon = first.box;
            ok &= GetDaycareCompatibilityScore(&daycare) == PARENTS_INCOMPATIBLE;
        }
        for (u32 mode = EVO_MODE_NORMAL; mode <= EVO_MODE_BATTLE_ONLY; mode++)
        {
            bool32 canStop = TRUE;
            ok &= GetEvolutionTargetSpecies(&first, mode, ITEM_THUNDER_STONE, &second, &canStop, CHECK_EVO) == SPECIES_NONE;
        }
        if (ok)
            passed |= 1 << id;
    }
    return passed;
}

static u32 CheckRecovery(void)
{
    struct Pokemon filler, reward;
    const struct SpecialPokemonEntry *gift = SpecialPokemon_GetEntry(SPECIAL_POKEMON_CLASSIC_CAP);
    const struct SpecialPokemonEntry *caught = SpecialPokemon_GetEntry(SPECIAL_POKEMON_SURFBOARD);
    u32 passed = 0;
    ClearOwnership();
    CreateRandomMon(&filler, SPECIES_PIDGEY, 5);
    for (u32 i = 0; i < PARTY_SIZE; i++)
        gParties[B_TRAINER_PLAYER][i] = filler;
    gPartiesCount[B_TRAINER_PLAYER] = PARTY_SIZE;
    for (u32 box = 0; box < TOTAL_BOXES_COUNT; box++)
        for (u32 slot = 0; slot < IN_BOX_COUNT; slot++)
            *GetBoxedMonPtr(box, slot) = filler.box;
    FlagSet(gift->unlockedFlag);
    gSpecialVar_0x8004 = SPECIAL_POKEMON_CLASSIC_CAP;
    SpecialPokemon_Give();
    if (gSpecialVar_Result == MON_CANT_GIVE && !FlagGet(gift->collectedFlag) && FlagGet(gift->unlockedFlag))
        passed |= 1;
    FlagSet(caught->unlockedFlag);
    gSpecialVar_0x8004 = SPECIAL_POKEMON_SURFBOARD;
    SpecialPokemon_CreateEncounter();
    reward = gParties[B_TRAINER_OPPONENT_A][0];
    if (GiveCapturedMonToPlayer(&reward) == MON_CANT_GIVE && !FlagGet(caught->collectedFlag))
        passed |= 2;
    memset(GetBoxedMonPtr(0, 0), 0, sizeof(struct BoxPokemon));
    gSpecialVar_0x8004 = SPECIAL_POKEMON_CLASSIC_CAP;
    SpecialPokemon_Give();
    if (gSpecialVar_Result == MON_GIVEN_TO_PC && FlagGet(gift->collectedFlag))
        passed |= 4;
    memset(GetBoxedMonPtr(0, 1), 0, sizeof(struct BoxPokemon));
    if (GiveCapturedMonToPlayer(&reward) == MON_GIVEN_TO_PC && FlagGet(caught->collectedFlag))
        passed |= 8;
    memset(GetBoxedMonPtr(0, 0), 0, sizeof(struct BoxPokemon));
    memset(GetBoxedMonPtr(0, 1), 0, sizeof(struct BoxPokemon));
    SpecialPokemon_ReconcileOwned();
    if (FlagGet(gift->collectedFlag) && FlagGet(caught->collectedFlag))
        passed |= 16;
    ClearOwnership();
    for (u32 i = 0; i < 4; i++)
    {
        CreateRandomMon(&reward, SpecialPokemon_GetEntry(i)->species, 5);
        if (i == 0) gParties[B_TRAINER_PLAYER][0] = reward;
        if (i == 1) *GetBoxedMonPtr(0, 0) = reward.box;
        if (i == 2) gSaveBlock1Ptr->daycare.mons[0].mon = reward.box;
        if (i == 3) gSaveBlock3Ptr->region.route5DayCareMon.mon = reward.box;
    }
    SpecialPokemon_ReconcileOwned();
    for (u32 i = 0; i < 4; i++)
        if (FlagGet(SpecialPokemon_GetEntry(i)->collectedFlag))
            passed |= 1 << (5 + i);
    ClearOwnership();
    gSpecialVar_0x8004 = SPECIAL_POKEMON_SURFBOARD;
    FlagSet(caught->unlockedFlag);
    SpecialPokemon_CreateEncounter();
    u32 personality = GetMonData(&gParties[B_TRAINER_OPPONENT_A][0], MON_DATA_PERSONALITY);
    SpecialPokemon_CreateEncounter();
    if (gSpecialVar_Result && !FlagGet(caught->collectedFlag)
        && personality != GetMonData(&gParties[B_TRAINER_OPPONENT_A][0], MON_DATA_PERSONALITY))
        passed |= 1 << 9;
    return passed;
}

static u32 CheckLegacyAndOrdinary(void)
{
    struct Pokemon mon, partner;
    struct DayCare daycare = {0};
    u32 passed = 0;
    u32 shiny = TRUE;
    ClearOwnership();
    CreateRandomMon(&mon, SPECIES_PIKACHU_ORIGINAL, 5);
    SetMonData(&mon, MON_DATA_IS_SHINY, &shiny);
    struct BoxPokemon before = mon.box;
    SpecialPokemon_RecordReceived(&mon.box);
    if (BytesEqual(&before, &mon.box, sizeof(before)) && FlagGet(FLAG_SPECIAL_COLLECTED_CLASSIC_CAP)
        && gSpeciesInfo[SPECIES_PIKACHU_ORIGINAL].genderRatio == MON_MALE
        && SpecialPokemon_FindSpecies(SPECIES_PIKACHU_ORIGINAL) == SPECIAL_POKEMON_COUNT
        && SpecialPokemon_GetThemedMove(SPECIES_PIKACHU_ORIGINAL) == MOVE_NONE)
        passed |= 1;
    if (!CanLearnTeachableMove(SPECIES_PIKACHU, MOVE_FLY) && CanLearnTeachableMove(SPECIES_PIKACHU, MOVE_SURF))
        passed |= 2;
    CreateRandomMon(&mon, SPECIES_SQUIRTLE, 20);
    CreateRandomMon(&partner, SPECIES_DITTO, 20);
    daycare.mons[0].mon = mon.box;
    daycare.mons[1].mon = partner.box;
    if (GetDaycareCompatibilityScore(&daycare) != PARENTS_INCOMPATIBLE)
        passed |= 4;
    bool32 canStop = TRUE;
    if (GetEvolutionTargetSpecies(&mon, EVO_MODE_NORMAL, ITEM_NONE, &partner, &canStop, CHECK_EVO) == SPECIES_WARTORTLE)
        passed |= 8;
    ClearOwnership();
    CreateRandomMon(&mon, SPECIES_PIKACHU, 20);
    gParties[B_TRAINER_PLAYER][0] = mon;
    SpecialPokemon_ReconcileOwned();
    if (!FlagGet(FLAG_SPECIAL_COLLECTED_CLASSIC_CAP))
        passed |= 16;
    CreateEgg(&mon, SPECIES_PIKACHU_CLASSIC_CAP, FALSE);
    SpecialPokemon_RecordReceived(&mon.box);
    if (!FlagGet(FLAG_SPECIAL_COLLECTED_CLASSIC_CAP))
        passed |= 32;
    return passed;
}

static u32 CheckReminder(u32 address)
{
    u32 (*getMoves)(struct BoxPokemon *, u16 *) = (void *)(address | 1);
    struct Pokemon mon;
    u16 moves[MAX_RELEARNER_MOVES + 1];
    u32 passed = 0;
    for (u32 id = 0; id < SPECIAL_POKEMON_COUNT; id++)
    {
        const struct SpecialPokemonEntry *entry = SpecialPokemon_GetEntry(id);
        CreateRandomMon(&mon, entry->species, entry->level);
        for (u32 slot = 0; slot < MAX_MON_MOVES; slot++)
            SetMonMoveSlot(&mon, MOVE_NONE, slot);
        memset(moves, 0, sizeof(moves));
        moves[MAX_RELEARNER_MOVES] = 0xA55A;
        u32 count = getMoves(&mon.box, moves);
        u32 occurrences = 0;
        for (u32 i = 0; i < count && i < MAX_RELEARNER_MOVES; i++)
            occurrences += moves[i] == entry->themedMove;
        bool32 ok = count <= MAX_RELEARNER_MOVES && moves[MAX_RELEARNER_MOVES] == 0xA55A
            && occurrences == 1 && HasMoveToRelearn(&mon.box, MOVE_RELEARNER_LEVEL_UP_MOVES);
        SetMonMoveSlot(&mon, entry->themedMove, 0);
        count = getMoves(&mon.box, moves);
        for (u32 i = 0; i < count && i < MAX_RELEARNER_MOVES; i++)
            if (moves[i] == entry->themedMove)
                ok = FALSE;
        if (ok)
            passed |= 1 << id;
    }
    return passed;
}

static u32 CheckCalculatedStats(void)
{
    static const struct
    {
        u16 species;
        u16 stats[6];
    } ordinary[] =
    {
        {SPECIES_PIKACHU, {35, 55, P_UPDATED_STATS >= GEN_6 ? 40 : 30, 90, 50, P_UPDATED_STATS >= GEN_6 || P_UPDATED_STATS == GEN_1 ? 50 : 40}},
        {SPECIES_SQUIRTLE, {44, 48, 65, 43, 50, P_UPDATED_STATS >= GEN_2 ? 64 : 50}},
        {SPECIES_EEVEE, {55, 55, 50, 55, P_UPDATED_STATS >= GEN_2 ? 45 : 65, 65}},
        {SPECIES_TOTODILE, {50, 65, 64, 43, 44, 48}},
        {SPECIES_PIKACHU_ORIGINAL, {35, 55, 40, 90, 50, 50}},
    };
    static const u32 fields[] = {MON_DATA_MAX_HP, MON_DATA_ATK, MON_DATA_DEF, MON_DATA_SPEED, MON_DATA_SPATK, MON_DATA_SPDEF};
    struct Pokemon mon;
    u32 passed = 0;
    for (u32 i = 0; i < ARRAY_COUNT(ordinary); i++)
    {
        CreateMonWithIVs(&mon, ordinary[i].species, 50, 0, OTID_STRUCT_PLAYER_ID, 0);
        for (u32 stat = 0; stat < ARRAY_COUNT(fields); stat++)
            if (GetMonData(&mon, fields[stat]) != ordinary[i].stats[stat] + (stat == 0 ? 60 : 5))
                return 0;
    }
    for (u32 id = 0; id < SPECIAL_POKEMON_COUNT; id++)
    {
        const struct SpecialPokemonEntry *entry = SpecialPokemon_GetEntry(id);
        const struct SpeciesInfo *base = &gSpeciesInfo[entry->baseSpecies];
        u16 stats[] = {base->baseHP, base->baseAttack, base->baseDefense, base->baseSpeed, base->baseSpAttack, base->baseSpDefense};
        bool32 ok = TRUE;
        CreateMonWithIVs(&mon, entry->species, 50, 0, OTID_STRUCT_PLAYER_ID, 0);
        for (u32 stat = 0; stat < ARRAY_COUNT(fields); stat++)
        {
            u32 expected = stats[stat] + (stats[stat] * 15 + 50) / 100 + (stat == 0 ? 60 : 5);
            if (GetMonData(&mon, fields[stat]) != expected)
                ok = FALSE;
        }
        if (ok)
            passed |= 1 << id;
    }
    return passed;
}

void VisualFeatureFixture(void)
{
    u32 command = gSpecialVar_0x8004;
    u32 address = gSpecialVar_0x8006 | (gSpecialVar_0x8007 << 16);
    SetMainCallback2(CB2_Overworld);
    switch (command)
    {
    case 0: gSpecialVar_Result = CheckAcquisitions(); break;
    case 1: gSpecialVar_Result = CheckBreedingAndEvolution(); break;
    case 2: gSpecialVar_Result = CheckRecovery(); break;
    case 3: gSpecialVar_Result = CheckLegacyAndOrdinary(); break;
    case 4: gSpecialVar_Result = CheckReminder(address); break;
    case 5: gSpecialVar_Result = CheckCalculatedStats(); break;
    }
}
