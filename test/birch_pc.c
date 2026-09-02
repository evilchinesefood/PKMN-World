#include "global.h"
#include "birch_pc.h"
#include "pokedex.h"
#include "pokemon.h"
#include "strings.h"
#include "test/test.h"

static void CatchRegionalDex(bool32 includeMythicals)
{
    u32 i;
    enum NationalDexOrder nationalDexNo;
    enum Species species;

    ResetPokedex();
    for (i = 0; i < REGIONAL_DEX_COUNT; i++)
    {
        nationalDexNo = RegionalToNationalOrder(i + 1);
        species = NationalPokedexNumToSpecies(nationalDexNo);
        if (species == SPECIES_NONE)
            continue;
        if (!includeMythicals && gSpeciesInfo[species].isMythical && !gSpeciesInfo[species].dexForceRequired)
            continue;
        GetSetPokedexFlag(nationalDexNo, FLAG_SET_CAUGHT);
    }
}

TEST("GetPokedexRatingText: full regional caught count minus only actually-caught mythicals selects DexCompleted")
{
    bool32 includeMythicals = FALSE;

    PARAMETRIZE { includeMythicals = FALSE; }
    PARAMETRIZE { includeMythicals = TRUE; }

    CatchRegionalDex(includeMythicals);
    EXPECT(GetPokedexRatingText(GetRegionalPokedexCount(FLAG_GET_CAUGHT)) == gBirchDexRatingText_DexCompleted);
}

TEST("GetPokedexRatingText: zero count with a mythical species id does not wrap the index")
{
    enum NationalDexOrder nationalDexNo;
    enum Species species;
    u32 i;

    ResetPokedex();
    for (i = 0; i < REGIONAL_DEX_COUNT; i++)
    {
        nationalDexNo = RegionalToNationalOrder(i + 1);
        species = NationalPokedexNumToSpecies(nationalDexNo);
        if (gSpeciesInfo[species].isMythical && !gSpeciesInfo[species].dexForceRequired)
        {
            GetSetPokedexFlag(nationalDexNo, FLAG_SET_CAUGHT);
            break;
        }
    }

    EXPECT(GetPokedexRatingText(0) == gBirchDexRatingText_LessThan10);
}
