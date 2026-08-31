#include "global.h"
#include "mail.h"
#include "pokemon.h"
#include "pokemon_icon.h"
#include "test/test.h"

TEST("GetIconSpeciesNoPersonality maps encoded Unown mail to the stored letter")
{
    u32 letter;
    u32 personality = 0;
    u32 expected = SPECIES_NONE;
    u16 mailSpecies;

    for (letter = 0; letter < NUM_UNOWN_FORMS; letter++)
    {
        PARAMETRIZE {
            personality = (letter & 3)
                        | ((letter & 0x0C) << 6)
                        | ((letter & 0x30) << 12)
                        | ((letter & 0xC0) << 18);
            expected = (letter == 0) ? SPECIES_UNOWN : (letter + SPECIES_UNOWN_B - 1);
        }
    }

    mailSpecies = SpeciesToMailSpecies(SPECIES_UNOWN, personality);
    EXPECT_EQ(GetUnownSpeciesId(personality), expected);
    EXPECT_EQ(GetIconSpeciesNoPersonality(mailSpecies), expected);
}

TEST("GetIconSpeciesNoPersonality returns the species for non-Unown mail")
{
    EXPECT_EQ(GetIconSpeciesNoPersonality(SPECIES_BULBASAUR), SPECIES_BULBASAUR);
}
