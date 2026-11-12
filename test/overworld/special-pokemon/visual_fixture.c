#include "global.h"
#include "battle_setup.h"
#include "event_data.h"
#include "event_object_movement.h"
#include "field_effect.h"
#include "field_player_avatar.h"
#include "field_screen_effect.h"
#include "main.h"
#include "overworld.h"
#include "party_menu.h"
#include "pokemon.h"
#include "pokemon_summary_screen.h"
#include "special_pokemon.h"
#include "sprite.h"
#include "wild_encounter.h"
#include "constants/event_objects.h"
#include "constants/field_effects.h"
#include "constants/maps.h"
#include "constants/moves.h"

static u16 ExpectedGraphics(void)
{
    struct Pokemon *mon = &gParties[B_TRAINER_PLAYER][0];
    return OBJ_EVENT_MON + GetMonData(mon, MON_DATA_SPECIES)
        + (GetMonGender(mon) == MON_FEMALE ? OBJ_EVENT_MON_FEMALE : 0);
}

void VisualFeatureFixture(void)
{
    u32 command = gSpecialVar_0x8004;
    u32 arg = gSpecialVar_0x8005;
    struct Pokemon *mon = &gParties[B_TRAINER_PLAYER][0];
    SetMainCallback2(CB2_Overworld);
    if (command == 0)
    {
        const struct SpecialPokemonEntry *entry = SpecialPokemon_GetEntry(arg % SPECIAL_POKEMON_COUNT);
        u32 zero = 0;
        RemoveFollowingPokemon();
        ZeroPlayerPartyMons();
        CreateMonWithIVs(mon, entry->species, entry->level, arg >= SPECIAL_POKEMON_COUNT ? 0x12345600 : 0x123456FF, OTID_STRUCT_PLAYER_ID, 31);
        SetMonData(mon, MON_DATA_IS_SHINY, &zero);
        SetMonMoveSlot(mon, entry->themedMove, 0);
        gPartiesCount[B_TRAINER_PLAYER] = 1;
        gSaveBlock2Ptr->followerSlot = 1;
        FlagSet(FLAG_SYS_POKEMON_GET);
        FlagSet(FLAG_HUB_INTRO_TOUR_DONE);
        FlagClear(FLAG_TEMP_HIDE_FOLLOWER);
        VarSet(VAR_REPEL_STEP_COUNT, 250);
        SetWarpDestination(MAP_GROUP(MAP_PETALBURG_CITY), MAP_NUM(MAP_PETALBURG_CITY), WARP_ID_NONE, 14, 10);
        DoWarp();
    }
    else if (command == 1)
    {
        CleanupOverworldWindowsAndTilemaps();
        ShowPokemonSummaryScreen(SUMMARY_MODE_NORMAL, gParties[B_TRAINER_PLAYER], 0, 0, CB2_ReturnToField);
    }
    else if (command == 2)
    {
        u32 personality = GetMonData(mon, MON_DATA_PERSONALITY);
        u32 zero = 0;
        CreateMonWithIVs(&gParties[B_TRAINER_OPPONENT_A][0], GetMonData(mon, MON_DATA_SPECIES), 2, personality, OTID_STRUCT_PLAYER_ID, 31);
        SetMonData(&gParties[B_TRAINER_OPPONENT_A][0], MON_DATA_IS_SHINY, &zero);
        BattleSetup_StartWildBattle();
    }
    else if (command == 3)
    {
        CleanupOverworldWindowsAndTilemaps();
        CB2_PartyMenuFromStartMenu();
    }
    else if (command == 4)
    {
        struct ObjectEvent *follower = GetFollowerObject();
        u16 graphics = ExpectedGraphics();
        u16 species = GetMonData(mon, MON_DATA_SPECIES);
        const struct ObjectEventGraphicsInfo *expected = &gSpeciesInfo[species].overworldData;
#if P_GENDER_DIFFERENCES
        if (GetMonGender(mon) == MON_FEMALE && gSpeciesInfo[species].overworldDataFemale.images != NULL)
            expected = &gSpeciesInfo[species].overworldDataFemale;
#endif
        gSpecialVar_Result = 0;
        if (GetObjectEventGraphicsInfo(graphics) == expected && expected->images != NULL)
            gSpecialVar_Result |= 1;
        if (follower != NULL)
        {
            gSpecialVar_Result |= 2;
            if (follower->graphicsId == graphics)
                gSpecialVar_Result |= 4;
            if (!follower->invisible && follower->spriteId < MAX_SPRITES && gSprites[follower->spriteId].inUse && !gSprites[follower->spriteId].invisible)
                gSpecialVar_Result |= 8;
        }
    }
    else if (command == 5)
    {
        gFieldEffectArguments[0] = 0;
        FieldEffectStart(FLDEFF_USE_SURF);
    }
    else if (command == 6)
    {
        struct ObjectEvent *player = &gObjectEvents[gPlayerAvatar.objectEventId];
        gSpecialVar_Result = (GetSurfMountGraphicsId() == ExpectedGraphics())
            | ((gPlayerAvatar.flags & PLAYER_AVATAR_FLAG_SURFING) != 0) << 1
            | ((player->fieldEffectSpriteId < MAX_SPRITES && gSprites[player->fieldEffectSpriteId].inUse && !gSprites[player->fieldEffectSpriteId].invisible) << 2);
    }
    else if (command == 8)
    {
        SetWarpDestination(MAP_GROUP(MAP_PETALBURG_CITY), MAP_NUM(MAP_PETALBURG_CITY), WARP_ID_NONE, 7, 22);
        DoWarp();
    }
    else if (command == 7)
    {
        gSpecialVar_Result = GetFlightMountGraphicsId() == ExpectedGraphics();
    }
}
