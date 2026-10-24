// Disposable audit ROM only; never linked into production.
#include "global.h"
#include "main.h"
#include "overworld.h"
#include "event_data.h"
#include "pokemon.h"
#include "script.h"
#include "field_screen_effect.h"
#include "constants/species.h"
#include "constants/moves.h"
#include "constants/flags.h"
#include "constants/vars.h"
void VisualFeatureFixture(void)
{
    SetMainCallback2(CB2_Overworld);
    switch (gSpecialVar_0x8004)
    {
    case 0:
        ZeroPlayerPartyMons();
        CreateMonWithIVs(&gParties[B_TRAINER_PLAYER][0], gSpecialVar_0x8005 ? gSpecialVar_0x8005 : SPECIES_MEWTWO, 100, 0x12345678, OTID_STRUCT_PLAYER_ID, 31);
        SetMonMoveSlot(&gParties[B_TRAINER_PLAYER][0], MOVE_PSYCHIC, 0);
        SetMonMoveSlot(&gParties[B_TRAINER_PLAYER][0], MOVE_AURA_SPHERE, 1);
        CalculatePlayerPartyCount();
        break;
    case 1:
        SetWarpDestination(gSpecialVar_0x8005, gSpecialVar_0x8006, -1, gSpecialVar_0x8007, gSpecialVar_0x8008);
        DoWarp();
        break;
    case 2:
        ScriptContext_SetupScript((const u8 *)(gSpecialVar_0x8005 | (gSpecialVar_0x8006 << 16)));
        break;
    case 3:
        FlagSet(gSpecialVar_0x8005);
        break;
    case 4:
        VarSet(gSpecialVar_0x8005, gSpecialVar_0x8006);
        break;
    }
}
