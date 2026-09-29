// Test-only entry point, linked into checked-unused ROM padding. Never shipped.
#include "global.h"
#include "battle_setup.h"
#include "event_data.h"
#include "event_object_movement.h"
#include "field_screen_effect.h"
#include "main.h"
#include "overworld.h"
#include "palette_swap.h"
#include "pokemon.h"
#include "save.h"
#include "trainer_card.h"
#include "wild_encounter.h"
#include "constants/flags.h"
#include "constants/maps.h"
#include "constants/species.h"
#include "constants/trainers.h"
#include "constants/vars.h"

void VisualFeatureFixture(void)
{
    u32 command = gSpecialVar_0x8004;
    u32 arg = gSpecialVar_0x8005;
    SetMainCallback2(CB2_Overworld);
    switch (command)
    {
    case 0:
        RemoveFollowingPokemon();
        CreateMonWithIVs(&gParties[B_TRAINER_PLAYER][0], SPECIES_JOLTEON, 80, 0x12345678, OTID_STRUCT_PLAYER_ID, 31);
        gPartiesCount[B_TRAINER_PLAYER] = 1;
        FlagSet(FLAG_SYS_POKEMON_GET);
        FlagSet(FLAG_HUB_INTRO_TOUR_DONE);
        FlagSet(FLAG_TEMP_HIDE_FOLLOWER);
        VarSet(VAR_REPEL_STEP_COUNT, 250);
        gSpecialVar_0x8005 = TRAINER_PIC_COUNT;
        break;
    case 1:
        if (arg >= 12)
            return;
        gSaveBlock2Ptr->playerGender = arg / NUM_PLAYER_OUTFITS;
        VarSet(VAR_PLAYER_PALETTE, arg % NUM_PLAYER_OUTFITS);
        SetWarpDestination(MAP_GROUP(MAP_PETALBURG_CITY), MAP_NUM(MAP_PETALBURG_CITY), WARP_ID_NONE, 7, 22);
        DoWarp();
        break;
    case 2:
        ShowPlayerTrainerCard(CB2_ReturnToField);
        break;
    case 3:
        CreateWildMon(SPECIES_POOCHYENA, 2);
        BattleSetup_StartWildBattle();
        break;
    case 4:
        gSpecialVar_0x8005 = TrySavingData(SAVE_NORMAL);
        break;
    }
}
