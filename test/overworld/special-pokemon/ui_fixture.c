#include "global.h"
#include "main.h"
#include "event_data.h"
#include "overworld.h"
#include "pokedex.h"
#include "pokedex_plus_hgss.h"
#include "pokemon.h"
#include "constants/flags.h"
#include "constants/pokedex.h"
#include "constants/species.h"

void VisualFeatureFixture(void)
{
    u32 command = gSpecialVar_0x8004;

    SetMainCallback2(CB2_Overworld);
    if (command == 0)
    {
        FlagSet(FLAG_SYS_POKEDEX_GET);
        FlagSet(FLAG_SYS_POKEMON_GET);
        EnableNationalPokedex();
        gSaveBlock2Ptr->pokedex.mode = DEX_MODE_NATIONAL;
        gSaveBlock2Ptr->pokedex.order = 0;
        for (u32 i = 1; i <= NATIONAL_DEX_CELEBI; i++)
        {
            GetSetPokedexFlag(i, FLAG_SET_SEEN);
            GetSetPokedexFlag(i, FLAG_SET_CAUGHT);
        }
    }
    else if (command == 1)
    {
        CleanupOverworldWindowsAndTilemaps();
        gMain.state = 0;
        SetMainCallback2(CB2_OpenPokedexPlusHGSS);
    }
}
