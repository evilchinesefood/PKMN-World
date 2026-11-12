#ifndef GUARD_SPECIAL_POKEMON_H
#define GUARD_SPECIAL_POKEMON_H

#include "constants/special_pokemon.h"

struct BoxPokemon;

struct SpecialPokemonEntry
{
    u16 species;
    u16 baseSpecies;
    u16 themedMove;
    u16 collectedFlag;
    u16 unlockedFlag;
    u8 level;
    u8 sourceKind;
    const u8 *name;
    const u8 *location;
    const u8 *hint;
};

const struct SpecialPokemonEntry *SpecialPokemon_GetEntry(u32 id);
u32 SpecialPokemon_FindSpecies(u16 species);
u16 SpecialPokemon_GetThemedMove(u16 species);
void SpecialPokemon_RecordReceived(struct BoxPokemon *mon);
void SpecialPokemon_ReconcileOwned(void);
void SpecialPokemon_Give(void);
void SpecialPokemon_CreateEncounter(void);

#endif
