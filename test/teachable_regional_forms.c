#include "global.h"
#include "test/test.h"

// porymoves' za.json files a regional form's learnset under its base species, so the generated
// tables gave the Kanto forms moves only the Alolan or Galarian form learns.

TEST("Kanto Marowak does not learn Alolan Marowak's TM moves")
{
    EXPECT(!CanLearnTeachableMove(SPECIES_MAROWAK, MOVE_SHADOW_BALL));
    EXPECT(!CanLearnTeachableMove(SPECIES_MAROWAK, MOVE_THUNDER));
    EXPECT(!CanLearnTeachableMove(SPECIES_MAROWAK, MOVE_THUNDERBOLT));
    EXPECT(CanLearnTeachableMove(SPECIES_MAROWAK, MOVE_EARTHQUAKE));
    EXPECT(CanLearnTeachableMove(SPECIES_MAROWAK_ALOLA, MOVE_SHADOW_BALL));
}

TEST("Kanto Meowth does not learn Galarian Meowth's TM moves")
{
    EXPECT(!CanLearnTeachableMove(SPECIES_MEOWTH, MOVE_BRICK_BREAK));
    EXPECT(!CanLearnTeachableMove(SPECIES_MEOWTH, MOVE_METRONOME));
    EXPECT(!CanLearnTeachableMove(SPECIES_MEOWTH, MOVE_SWORDS_DANCE));
    EXPECT(CanLearnTeachableMove(SPECIES_MEOWTH, MOVE_BULK_UP));
}

TEST("Kanto Slowbro and Slowking do not learn their Galarian forms' TM moves")
{
    EXPECT(!CanLearnTeachableMove(SPECIES_SLOWBRO, MOVE_SLUDGE_BOMB));
    EXPECT(!CanLearnTeachableMove(SPECIES_SLOWKING, MOVE_SLUDGE_BOMB));
    EXPECT(!CanLearnTeachableMove(SPECIES_SLOWKING, MOVE_TAUNT));
    EXPECT(CanLearnTeachableMove(SPECIES_SLOWBRO, MOVE_FIRE_PUNCH));
}
