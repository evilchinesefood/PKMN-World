#include "global.h"
#include "event_data.h"
#include "pokemon.h"
#include "party_menu.h"
#include "pokemon_storage_system.h"
#include "script_pokemon_util.h"
#include "script.h"
#include "special_pokemon.h"
#include "constants/items.h"
#include "constants/moves.h"

static const struct SpecialPokemonEntry sSpecialPokemon[] =
{
    [SPECIAL_POKEMON_CLASSIC_CAP] =
    {
        .species = SPECIES_PIKACHU_CLASSIC_CAP, .baseSpecies = SPECIES_PIKACHU,
        .themedMove = MOVE_THUNDERBOLT, .level = 5, .sourceKind = SPECIAL_POKEMON_GIFT,
        .collectedFlag = FLAG_SPECIAL_COLLECTED_CLASSIC_CAP,
        .unlockedFlag = FLAG_SPECIAL_UNLOCKED_CLASSIC_CAP,
        .name = COMPOUND_STRING("Classic Cap Pikachu"),
        .location = COMPOUND_STRING("Kanto: Pallet Town"),
        .hint = COMPOUND_STRING("Talk to the trainer outside\nOAK's lab for a welcome gift."),
    },
    [SPECIAL_POKEMON_SURFBOARD] =
    {
        .species = SPECIES_PIKACHU_SURFBOARD, .baseSpecies = SPECIES_PIKACHU,
        .themedMove = MOVE_SURF, .level = 25, .sourceKind = SPECIAL_POKEMON_CATCH,
        .collectedFlag = FLAG_SPECIAL_COLLECTED_SURFBOARD,
        .unlockedFlag = FLAG_SPECIAL_UNLOCKED_SURFBOARD,
        .name = COMPOUND_STRING("Surfboard Pikachu"),
        .location = COMPOUND_STRING("Kanto: Route 19 shore"),
        .hint = COMPOUND_STRING("Talk to the surfer south of\nFUCHSIA, then catch PIKACHU."),
    },
    [SPECIAL_POKEMON_BALLOONS] =
    {
        .species = SPECIES_PIKACHU_BALLOONS, .baseSpecies = SPECIES_PIKACHU,
        .themedMove = MOVE_FLY, .level = 15, .sourceKind = SPECIAL_POKEMON_GIFT,
        .collectedFlag = FLAG_SPECIAL_COLLECTED_BALLOONS,
        .unlockedFlag = FLAG_SPECIAL_UNLOCKED_BALLOONS,
        .name = COMPOUND_STRING("Balloon Pikachu"),
        .location = COMPOUND_STRING("Johto: Goldenrod City"),
        .hint = COMPOUND_STRING("Meet the balloon seller\noutside the department store."),
    },
    [SPECIAL_POKEMON_SQUAD] =
    {
        .species = SPECIES_SQUIRTLE_SQUAD, .baseSpecies = SPECIES_SQUIRTLE,
        .themedMove = MOVE_BITE, .level = 15, .sourceKind = SPECIAL_POKEMON_GIFT,
        .collectedFlag = FLAG_SPECIAL_COLLECTED_SQUAD,
        .unlockedFlag = FLAG_SPECIAL_UNLOCKED_SQUAD,
        .name = COMPOUND_STRING("Squad Squirtle"),
        .location = COMPOUND_STRING("Kanto: Vermilion Fan Club"),
        .hint = COMPOUND_STRING("Ask the organizer to help.\nFind both nearby SQUIRTLE,\nthen return to the Fan Club."),
    },
    [SPECIAL_POKEMON_FIREFIGHTER] =
    {
        .species = SPECIES_SQUIRTLE_FIREFIGHTER, .baseSpecies = SPECIES_SQUIRTLE,
        .themedMove = MOVE_RAIN_DANCE, .level = 10, .sourceKind = SPECIAL_POKEMON_GIFT,
        .collectedFlag = FLAG_SPECIAL_COLLECTED_FIREFIGHTER,
        .unlockedFlag = FLAG_SPECIAL_UNLOCKED_FIREFIGHTER,
        .name = COMPOUND_STRING("Firefighter Squirtle"),
        .location = COMPOUND_STRING("Johto: Azalea Charcoal Kiln"),
        .hint = COMPOUND_STRING("Speak to the kiln helper.\nGet water from the helper by\nSLOWPOKE WELL, then return."),
    },
    [SPECIAL_POKEMON_FLOWER_CROWN] =
    {
        .species = SPECIES_EEVEE_FLOWER_CROWN, .baseSpecies = SPECIES_EEVEE,
        .themedMove = MOVE_CHARM, .level = 20, .sourceKind = SPECIAL_POKEMON_GIFT,
        .collectedFlag = FLAG_SPECIAL_COLLECTED_FLOWER_CROWN,
        .unlockedFlag = FLAG_SPECIAL_UNLOCKED_FLOWER_CROWN,
        .name = COMPOUND_STRING("Flower Crown Eevee"),
        .location = COMPOUND_STRING("Kanto: Celadon City"),
        .hint = COMPOUND_STRING("Help the florist. Deliver to\nboth nearby residents, then\nreturn for your EEVEE."),
    },
    [SPECIAL_POKEMON_PIRATE] =
    {
        .species = SPECIES_TOTODILE_PIRATE, .baseSpecies = SPECIES_TOTODILE,
        .themedMove = MOVE_THIEF, .level = 20, .sourceKind = SPECIAL_POKEMON_CATCH,
        .collectedFlag = FLAG_SPECIAL_COLLECTED_PIRATE,
        .unlockedFlag = FLAG_SPECIAL_UNLOCKED_PIRATE,
        .name = COMPOUND_STRING("Pirate Totodile"),
        .location = COMPOUND_STRING("Johto: Olivine waterfront"),
        .hint = COMPOUND_STRING("Meet the waterfront sailor,\nthen catch TOTODILE outside\nthe ship terminal."),
    },
};

STATIC_ASSERT(ARRAY_COUNT(sSpecialPokemon) == SPECIAL_POKEMON_COUNT, SpecialPokemonCatalogSize);

const struct SpecialPokemonEntry *SpecialPokemon_GetEntry(u32 id)
{
    if (id >= ARRAY_COUNT(sSpecialPokemon))
        return NULL;
    return &sSpecialPokemon[id];
}

u32 SpecialPokemon_FindSpecies(u16 species)
{
    for (u32 i = 0; i < ARRAY_COUNT(sSpecialPokemon); i++)
        if (sSpecialPokemon[i].species == species)
            return i;
    return SPECIAL_POKEMON_COUNT;
}

u16 SpecialPokemon_GetThemedMove(u16 species)
{
    const struct SpecialPokemonEntry *entry = SpecialPokemon_GetEntry(SpecialPokemon_FindSpecies(species));
    return entry == NULL ? MOVE_NONE : entry->themedMove;
}

void SpecialPokemon_RecordReceived(struct BoxPokemon *mon)
{
    u16 species = GetBoxMonData(mon, MON_DATA_SPECIES);
    u32 id;

    if (GetBoxMonData(mon, MON_DATA_IS_EGG) || GetBoxMonData(mon, MON_DATA_SANITY_IS_BAD_EGG))
        return;
    id = species == SPECIES_PIKACHU_ORIGINAL ? SPECIAL_POKEMON_CLASSIC_CAP : SpecialPokemon_FindSpecies(species);
    if (id < SPECIAL_POKEMON_COUNT)
        FlagSet(sSpecialPokemon[id].collectedFlag);
}

void SpecialPokemon_ReconcileOwned(void)
{
    for (u32 i = 0; i < PARTY_SIZE; i++)
        SpecialPokemon_RecordReceived(&gParties[B_TRAINER_PLAYER][i].box);
    for (u32 box = 0; box < TOTAL_BOXES_COUNT; box++)
        for (u32 slot = 0; slot < IN_BOX_COUNT; slot++)
            SpecialPokemon_RecordReceived(GetBoxedMonPtr(box, slot));
    for (u32 i = 0; i < DAYCARE_MON_COUNT; i++)
        SpecialPokemon_RecordReceived(&gSaveBlock1Ptr->daycare.mons[i].mon);
#if ALL_REGIONS
    SpecialPokemon_RecordReceived(&gSaveBlock3Ptr->region.route5DayCareMon.mon);
#endif
    for (u32 i = 0; i < MAX_FUSION_STORAGE; i++)
        SpecialPokemon_RecordReceived(&gPokemonStoragePtr->fusions[i].box);
}

static void PrepareAcquisition(struct Pokemon *mon, const struct SpecialPokemonEntry *entry)
{
    u32 zero = 0;

    SetMonData(mon, MON_DATA_IS_SHINY, &zero);
    SetMonData(mon, MON_DATA_HELD_ITEM, &zero);
    if (!MonKnowsMove(mon, entry->themedMove))
    {
        if (GiveMoveToMon(mon, entry->themedMove) == MON_HAS_MAX_MOVES)
            DeleteFirstMoveAndGiveMoveToMon(mon, entry->themedMove);
    }
}

void SpecialPokemon_Give(void)
{
    const struct SpecialPokemonEntry *entry = SpecialPokemon_GetEntry(gSpecialVar_0x8004);
    struct Pokemon mon;

    gSpecialVar_Result = MON_CANT_GIVE;
    if (entry == NULL || entry->sourceKind != SPECIAL_POKEMON_GIFT || !FlagGet(entry->unlockedFlag))
        return;
    VarSet(VAR_TEMP_TRANSFERRED_SPECIES, entry->species);
    CreateRandomMon(&mon, entry->species, entry->level);
    PrepareAcquisition(&mon, entry);
    gSpecialVar_Result = GiveScriptedMonToPlayer(&mon, PARTY_SIZE);
}

void SpecialPokemon_CreateEncounter(void)
{
    const struct SpecialPokemonEntry *entry = SpecialPokemon_GetEntry(gSpecialVar_0x8004);

    gSpecialVar_Result = FALSE;
    if (entry == NULL || entry->sourceKind != SPECIAL_POKEMON_CATCH || !FlagGet(entry->unlockedFlag))
        return;
    SetScriptedWildBattleIsDouble(FALSE);
    CreateScriptedWildMon(entry->species, entry->level, ITEM_NONE);
    PrepareAcquisition(&gParties[B_TRAINER_OPPONENT_A][0], entry);
    gSpecialVar_Result = TRUE;
}
