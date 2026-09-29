// Test-only commands attached to a disposable ROM. Never linked into the game.
#include "global.h"
#include "main.h"
#include "load_save.h"
#include "party_menu.h"
#include "overworld.h"
#include "event_data.h"
#include "pokemon.h"
#include "item.h"
#include "item_menu.h"
#include "battle.h"
#include "battle_setup.h"
#include "battle_partner.h"
#include "wild_encounter.h"
#include "pokedex.h"
#include "random.h"
#include "safari_zone.h"
#include "constants/species.h"
#include "constants/items.h"
#include "constants/moves.h"
#include "constants/flags.h"
#include "constants/vars.h"
#include "constants/abilities.h"
#include "constants/battle_partner.h"
#include "constants/opponents.h"
#include "battle_controllers.h"
#include "battle_interface.h"
#include "bw_battle_ui.h"
#include "sprite.h"
#include "task.h"
#include "text.h"
#include "string_util.h"
#include "constants/characters.h"
#include "constants/maps.h"
#include "field_screen_effect.h"
#include "egg_hatch.h"
#include "trade.h"
#include "malloc.h"
#include "international_string_util.h"
#include "battle_gimmick.h"
#include "save.h"
#include "link.h"
#include "cable_club.h"
#include "pokemon_storage_system.h"
#include "battle_gfx_sfx_util.h"
#include "constants/battle_anim.h"
#include "palette_swap.h"
#include "debug.h"
#include "bug_contest.h"
#include "recorded_battle.h"
#include "gpu_regs.h"

extern void DoInGameTradeScene(void);

// Weak references keep the same capture seed usable with the classic baseline.
extern void BattleUI_ResetGraphics(void) __attribute__((weak));
extern void BattleUI_DisplayMoveBox(enum BattlerId) __attribute__((weak));
extern void BattleUI_CreateAbilityPopUp(enum BattlerId, enum Ability) __attribute__((weak));
extern void BattleUI_DestroyCursorSprite(void) __attribute__((weak));
extern void BattleUI_CreateCursorSprite(enum BattlerId) __attribute__((weak));
extern u32 BattleUI_GetCursorSpriteId(void) __attribute__((weak));
extern u32 BattleUI_CreateMoveInfoTriggerSprite(void) __attribute__((weak));
extern u32 BattleUI_CreateLastBallTriggerSprite(void) __attribute__((weak));
extern const u8 *BattleUI_GetTypeEffectivenessSymbol(enum BattlerId, enum Move) __attribute__((weak));
extern enum Type BattleUI_GetMoveType(enum BattlerId, enum Move) __attribute__((weak));

static bool32 BytesEqual(const void *a, const void *b, u32 size)
{
    const volatile u8 *left = a, *right = b;
    for (u32 i = 0; i < size; i++)
        if (left[i] != right[i])
            return FALSE;
    return TRUE;
}

// Compare the actual healthbox tiles across an Illusion break with a clean
// render, rather than assuming that a nickname repaint also erased its tail.
static void CheckIllusionHealthbox(u32 battler)
{
    struct Pokemon *mon = GetBattlerMon(battler);
    struct Pokemon original = *mon;
    struct Pokemon disguise;
    struct Illusion illusion = gBattleStruct->illusion[battler];
    u8 sprite = gHealthboxSpriteIds[battler];
    u8 second = gSprites[sprite].oam.affineParam;
    void *left = (void *)(OBJ_VRAM0 + gSprites[sprite].oam.tileNum * 32);
    void *right = (void *)(OBJ_VRAM0 + gSprites[second].oam.tileNum * 32);
    u8 *saved = Alloc(0x800);
    CreateMonWithIVs(mon, SPECIES_NIDORAN_M, 40, 0x12345678, OTID_STRUCT_PLAYER_ID, 31);
    SetMonData(mon, MON_DATA_NICKNAME, (const u8[]){CHAR_Z, CHAR_e, CHAR_d, EOS});
    CreateMonWithIVs(&disguise, SPECIES_NIDORAN_F, 5, 0x12345678, OTID_STRUCT_PLAYER_ID, 31);
    SetMonData(&disguise, MON_DATA_NICKNAME, (const u8[]){CHAR_W, CHAR_W, CHAR_W, CHAR_W, CHAR_W, CHAR_W, CHAR_W, CHAR_W, CHAR_W, CHAR_W, EOS});
    gBattleStruct->illusion[battler].state = ILLUSION_OFF;
    UpdateHealthboxAttribute(sprite, mon, HEALTHBOX_NICK);
    memcpy(saved, left, 0x400);
    memcpy(saved + 0x400, right, 0x400);
    gBattleStruct->illusion[battler].state = ILLUSION_ON;
    gBattleStruct->illusion[battler].mon = &disguise;
    UpdateHealthboxAttribute(sprite, mon, HEALTHBOX_NICK);
    gBattleStruct->illusion[battler].state = ILLUSION_OFF;
    UpdateHealthboxAttribute(sprite, mon, HEALTHBOX_NICK);
    gSpecialVar_0x8005 = BytesEqual(left, saved, 0x400) && BytesEqual(right, saved + 0x400, 0x400);

    gBattleStruct->illusion[battler].state = ILLUSION_ON;
    UpdateHealthboxAttribute(sprite, mon, HEALTHBOX_NICK);
    memcpy(saved, left, 0x400);
    memcpy(saved + 0x400, right, 0x400);
    gBattleStruct->illusion[battler].state = ILLUSION_OFF;
    u32 level = 40;
    SetMonData(&disguise, MON_DATA_LEVEL, &level);
    UpdateHealthboxAttribute(sprite, &disguise, HEALTHBOX_NICK);
    gSpecialVar_0x8006 = BytesEqual(left, saved, 0x400) && BytesEqual(right, saved + 0x400, 0x400);
    *mon = original;
    gBattleStruct->illusion[battler] = illusion;
    UpdateHealthboxAttribute(sprite, mon, HEALTHBOX_ALL);
    Free(saved);
}

static void CountResources(void)
{
    u32 sprites = 0, tasks = 0, printers = 0;
    for (u32 i = 0; i < MAX_SPRITES; i++)
        sprites += gSprites[i].inUse;
    for (u32 i = 0; i < NUM_TASKS; i++)
        tasks += gTasks[i].isActive;
    for (u32 i = 0; i < MAX_SPRITES; i++)
        printers += IsTextPrinterActiveOnSprite(i);
    for (u32 i = 0; i < 32; i++)
        printers += IsTextPrinterActiveOnWindow(i);
    gSpecialVar_0x8005 = sprites;
    gSpecialVar_0x8006 = printers;
    gSpecialVar_0x8007 = tasks;
}

static void CheckPreview(u32 arg)
{
    struct BattlePokemon mons[MAX_BATTLERS_COUNT];
    memcpy(mons, gBattleMons, sizeof(mons));
    struct BattleStruct *original = Alloc(sizeof(*original));
    struct BattleStruct *before = Alloc(sizeof(*before));
    memcpy(original, gBattleStruct, sizeof(*original));
    u16 weather = gBattleWeather;
    u32 field = gFieldStatuses;
    enum BattlerId item = gPotentialItemEffectBattler;
    rng_value_t rng = gRngValue;
    u8 message = gBattleCommunication[MULTISTRING_CHOOSER];
    enum Move move = MOVE_WEATHER_BALL;
    enum Type type = TYPE_WATER;
    u8 expected = 0x15; // super effective
    SET_BATTLER_TYPE(0, TYPE_NORMAL);
    SET_BATTLER_TYPE(1, TYPE_ROCK);
    gBattleMons[1].types[1] = TYPE_GROUND;
    gBattleMons[0].ability = ABILITY_INNER_FOCUS;
    gBattleMons[1].ability = ABILITY_STURDY;
    gBattleMons[0].item = gBattleMons[1].item = ITEM_NONE;
    gBattleWeather = B_WEATHER_RAIN;
    gFieldStatuses = 0;
    gBattleStruct->moldBreakerActive = TRUE; // deliberately stale previous action
    gBattleStruct->battlerState[0].ateBoost = FALSE;
    switch (arg)
    {
    case 0: break;
    case 1: gBattleWeather = B_WEATHER_SUN; type = TYPE_FIRE; expected = 0x16; break;
    case 2: move = MOVE_TERRAIN_PULSE; gFieldStatuses = STATUS_FIELD_GRASSY_TERRAIN; type = TYPE_GRASS; break;
    case 3: move = MOVE_TERRAIN_PULSE; gFieldStatuses = STATUS_FIELD_ELECTRIC_TERRAIN; type = TYPE_ELECTRIC; expected = CHAR_BIG_MULT_X; break;
    case 4: move = MOVE_HIDDEN_POWER; type = TYPE_DARK; expected = 0x18; break;
    case 5: move = MOVE_TACKLE; gBattleMons[0].ability = ABILITY_PIXILATE; type = TYPE_FAIRY; expected = 0x18; break;
    case 6: move = MOVE_SURF; gBattleMons[0].ability = ABILITY_NORMALIZE; type = TYPE_NORMAL; expected = 0x16; break;
    case 7: move = MOVE_EARTHQUAKE; type = TYPE_GROUND; gBattleMons[1].ability = ABILITY_LEVITATE; expected = CHAR_BIG_MULT_X; break;
    case 8: move = MOVE_EARTHQUAKE; type = TYPE_GROUND; gBattleMons[1].ability = ABILITY_LEVITATE; gBattleMons[0].ability = ABILITY_MOLD_BREAKER; break;
    case 9: move = MOVE_EARTHQUAKE; type = TYPE_GROUND; gBattleMons[1].ability = ABILITY_LEVITATE; gBattleMons[0].ability = ABILITY_MOLD_BREAKER; gBattleMons[1].item = ITEM_ABILITY_SHIELD; expected = CHAR_BIG_MULT_X; break;
    case 10: move = MOVE_SURF; gBattleMons[1].ability = ABILITY_WATER_ABSORB; gBattleMons[1].hp--; expected = CHAR_BIG_MULT_X; break;
    case 11: move = MOVE_FLAMETHROWER; type = TYPE_FIRE; gBattleMons[1].ability = ABILITY_FLASH_FIRE; expected = CHAR_BIG_MULT_X; break;
    case 12: move = MOVE_EARTHQUAKE; type = TYPE_GROUND; gBattleMons[1].item = ITEM_AIR_BALLOON; expected = CHAR_BIG_MULT_X; break;
    }
    memcpy(before, gBattleStruct, sizeof(*before));
    const u8 *symbol = BattleUI_GetTypeEffectivenessSymbol(0, move);
    bool32 correct = symbol[0] == CHAR_EXTRA_SYMBOL && symbol[1] == expected;
    bool32 correctType = BattleUI_GetMoveType(0, move) == type;
    bool32 pure = BytesEqual(before, gBattleStruct, sizeof(*before))
        && BytesEqual(&rng, &gRngValue, sizeof(rng))
        && gPotentialItemEffectBattler == item
        && gBattleCommunication[MULTISTRING_CHOOSER] == message;
    memcpy(gBattleMons, mons, sizeof(mons));
    memcpy(gBattleStruct, original, sizeof(*original));
    gBattleWeather = weather;
    gFieldStatuses = field;
    gPotentialItemEffectBattler = item;
    gBattleCommunication[MULTISTRING_CHOOSER] = message;
    Free(before);
    Free(original);
    gSpecialVar_0x8005 = correct;
    gSpecialVar_0x8006 = correctType;
    gSpecialVar_0x8007 = pure;
}

static void LiveBattleCommand(u32 command, u32 arg)
{
    struct ChooseMoveStruct *info = (void *)&gBattleResources->bufferA[0][4];
    switch (command)
    {
    case 125:
    {
        u32 hp = 1, status = STATUS1_POISON;
        SetMonData(GetBattlerMon(0), MON_DATA_HP, &hp);
        SetMonData(GetBattlerMon(0), MON_DATA_STATUS, &status);
        gBattleMons[0].hp = hp;
        gBattleMons[0].status1 = status;
        UpdateHealthboxAttribute(gHealthboxSpriteIds[0], GetBattlerMon(0), HEALTHBOX_ALL);
        break;
    }
    case 126:
        gBagPosition.pocket = POCKET_POKE_BALLS;
        break;
    case 124:
        gSpecialVar_0x8005 = MoveRecordedBattleToSaveData();
        break;
    case 121:
        if (arg == 0)
        {
            SetGpuReg(REG_OFFSET_MOSAIC, 0x1243);
            CreateAbilityPopUp(0, ABILITY_NEUTRALIZING_GAS, IsDoubleBattle());
            CreateAbilityPopUp(1, ABILITY_STURDY, IsDoubleBattle());
        }
        else
            BattleUI_ResetGraphics();
        break;
    case 122:
    {
        bool8 active[NUM_TASKS];
        for (u32 i = 0; i < NUM_TASKS; i++)
        {
            active[i] = gTasks[i].isActive;
            gTasks[i].isActive = TRUE;
        }
        BattleUI_CreateAbilityPopUp(0, ABILITY_STURDY);
        for (u32 i = 0; i < NUM_TASKS; i++)
            gTasks[i].isActive = active[i];
        break;
    }
    case 123:
    {
        static const u16 colors[16] = {0};
        BattleUI_ResetGraphics();
        for (u32 i = 0; i < 16; i++)
            LoadSpritePalette(&(const struct SpritePalette){colors, 0xE800 + i});
        BattleUI_CreateCursorSprite(0);
        gSpecialVar_0x8005 = BattleUI_GetCursorSpriteId() == SPRITE_NONE;
        gSpecialVar_0x8006 = BattleUI_CreateMoveInfoTriggerSprite() == MAX_SPRITES;
        gSpecialVar_0x8007 = BattleUI_CreateLastBallTriggerSprite() == MAX_SPRITES;
        BattleUI_CreateAbilityPopUp(0, ABILITY_STURDY);
        for (u32 i = 0; i < 16; i++)
            FreeSpritePaletteByTag(0xE800 + i);
        BattleUI_CreateCursorSprite(0);
        break;
    }
    case 114:
        CheckIllusionHealthbox(arg);
        break;
    case 115:
        // Exercise the real Silph Scope reveal hook (including caught marker).
        GetSetPokedexFlag(SpeciesToNationalPokedexNum(gBattleMons[1].species), FLAG_SET_CAUGHT);
        HandleSpeciesGfxDataChange(1, 0, SPECIES_GFX_CHANGE_GHOST_UNVEIL);
        break;
    case 105:
        CheckPreview(arg);
        break;
    case 106:
        gSpecialVar_0x8005 = 0;
        gSpecialVar_0x8006 = 0;
        for (u32 move = 1; move < MOVES_COUNT; move++)
        {
            const u8 *name = GetMoveName(move);
            u32 font = GetFontIdToFit(name, FONT_SMALL, 0, 96);
            if (GetStringWidth(font, name, 0) > 96)
            {
                gSpecialVar_0x8005++;
                gSpecialVar_0x8006 = move;
            }
        }
        break;
    case 108:
        gSpecialVar_0x8005 = gBattleStruct->gimmick.usableGimmick[0];
        gSpecialVar_0x8006 = gBattleStruct->gimmick.playerSelect;
        gSpecialVar_0x8007 = GetActiveGimmick(0);
        break;
    case 109:
        gSpecialVar_0x8005 = HasTrainerUsedGimmick(0, arg);
        break;
    case 111:
        gSpecialVar_0x8005 = CountTotalItemQuantityInBag(ITEM_POKE_BALL);
        gSpecialVar_0x8006 = CountTotalItemQuantityInBag(ITEM_GREAT_BALL);
        gSpecialVar_0x8007 = CountTotalItemQuantityInBag(ITEM_MASTER_BALL);
        break;
    case 100:
        CreateAbilityPopUp(arg & 1, arg > 1 ? ABILITY_NEUTRALIZING_GAS : ABILITY_STURDY, IsDoubleBattle());
        break;
    case 101:
        SwapHpBarsWithHpText();
        break;
    case 102:
    {
        static const u16 moves[][4] = {
            {MOVE_THUNDERBOLT, MOVE_SURF, MOVE_FLAMETHROWER, MOVE_DRAGON_CLAW},
            {MOVE_PRECIPICE_BLADES, MOVE_SPACIAL_REND, MOVE_SELF_DESTRUCT, MOVE_PARABOLIC_CHARGE},
            {MOVE_SWORDS_DANCE, MOVE_HIDDEN_POWER, MOVE_TACKLE, MOVE_NONE},
        };
        for (u32 i = 0; i < 4; i++)
        {
            info->moves[i] = moves[arg % 3][i];
            info->currentPP[i] = arg == 2 && i == 2 ? 0 : 15;
            info->maxPP[i] = 15;
        }
        if (BattleUI_DisplayMoveBox)
            BattleUI_DisplayMoveBox(0);
        break;
    }
    case 103:
    {
        rng_value_t rng = gRngValue;
        gSpecialVar_0x8005 = 0;
        const u8 expected[] = {CHAR_BIG_MULT_X, 0x15, 0x16, 0x18};
        if (BattleUI_GetTypeEffectivenessSymbol)
        {
            const u16 moves[] = {MOVE_THUNDERBOLT, MOVE_SURF, MOVE_FLAMETHROWER, MOVE_DRAGON_CLAW};
            for (u32 i = 0; i < 4; i++)
            {
                const u8 *symbol = BattleUI_GetTypeEffectivenessSymbol(0, moves[i]);
                if (symbol[0] == CHAR_EXTRA_SYMBOL && symbol[1] == expected[i])
                    gSpecialVar_0x8005 |= 1 << i;
            }
            gSpecialVar_0x8007 = BattleUI_GetTypeEffectivenessSymbol(0, MOVE_SWORDS_DANCE)[0] == EOS;
        }
        gSpecialVar_0x8006 = memcmp(&rng, &gRngValue, sizeof(rng)) == 0;
        break;
    }
    case 104:
    {
        bool8 reserved[MAX_SPRITES];
        if (!BattleUI_CreateCursorSprite)
            break;
        BattleUI_ResetGraphics();
        for (u32 i = 0; i < MAX_SPRITES; i++)
        {
            reserved[i] = !gSprites[i].inUse;
            gSprites[i].inUse = TRUE;
        }
        BattleUI_CreateCursorSprite(0);
        gSpecialVar_0x8005 = BattleUI_GetCursorSpriteId() == SPRITE_NONE;
        gSpecialVar_0x8006 = BattleUI_CreateMoveInfoTriggerSprite() == MAX_SPRITES;
        gSpecialVar_0x8007 = BattleUI_CreateLastBallTriggerSprite() == MAX_SPRITES;
        BattleUI_CreateAbilityPopUp(0, ABILITY_STURDY);
        for (u32 i = 0; i < MAX_SPRITES; i++)
            if (reserved[i])
                gSprites[i].inUse = FALSE;
        BattleUI_CreateCursorSprite(0);
        break;
    }
    }
}

static void SeedParty(void)
{
    static const u16 species[] = {SPECIES_DRAGONITE, SPECIES_GENGAR, SPECIES_ABSOL, SPECIES_SNORLAX, SPECIES_ALAKAZAM, SPECIES_EEVEE};
    static const u16 balls[] = {ITEM_POKE_BALL, ITEM_GREAT_BALL, ITEM_ULTRA_BALL, ITEM_MASTER_BALL};
    ClearBag();
    ResetBagScrollPositions();
    for (u32 i = 0; i < ARRAY_COUNT(balls); i++)
        AddBagItem(balls[i], 5);
    AddBagItem(ITEM_POTION, 10);
    AddBagItem(ITEM_REVIVE, 10);
    AddBagItem(ITEM_ETHER, 10);
    for (u32 i = 0; i < ARRAY_COUNT(species); i++)
    {
        struct Pokemon *mon = &gParties[B_TRAINER_PLAYER][i];
        CreateMonWithIVs(mon, species[i], 40, 0x12345678 + i, OTID_STRUCT_PLAYER_ID, 31);
        u32 metLevel = 5;
        SetMonData(mon, MON_DATA_MET_LEVEL, &metLevel);
        SetMonMoveSlot(mon, MOVE_THUNDERBOLT, 0);
        SetMonMoveSlot(mon, MOVE_SURF, 1);
        SetMonMoveSlot(mon, MOVE_FLAMETHROWER, 2);
        SetMonMoveSlot(mon, MOVE_DRAGON_CLAW, 3);
    }
    gPartiesCount[B_TRAINER_PLAYER] = ARRAY_COUNT(species);
    FlagSet(FLAG_SYS_POKEMON_GET);
    FlagSet(FLAG_SYS_POKEDEX_GET);
    VarSet(VAR_REPEL_STEP_COUNT, 250);
    gSaveBlock2Ptr->optionsTextSpeed = 2;
    gSaveBlock2Ptr->optionsButtonMode = OPTIONS_BUTTON_MODE_LR;
    gLastUsedBall = gBallToDisplay = ITEM_POKE_BALL;
    SeedRng(42);
}

void VisualFeatureFixture(void)
{
    u32 command = gSpecialVar_0x8004;
    u32 arg = gSpecialVar_0x8005;
    if (command >= 100)
    {
        SetMainCallback2(BattleMainCB2);
        LiveBattleCommand(command, arg);
        return;
    }
    SetMainCallback2(CB2_Overworld);
    switch (command)
    {
    case 0:
        SeedParty();
        break;
    case 1:
        CreateWildMon(SPECIES_GEODUDE, 15);
        u32 abilityNum = 1; // Sturdy: ensures a visible HP-drain turn before the KO.
        SetMonData(&gParties[B_TRAINER_OPPONENT_A][0], MON_DATA_ABILITY_NUM, &abilityNum);
        SetMonMoveSlot(&gParties[B_TRAINER_OPPONENT_A][0], MOVE_DEFENSE_CURL, 0);
        for (u32 i = 1; i < MAX_MON_MOVES; i++)
            SetMonMoveSlot(&gParties[B_TRAINER_OPPONENT_A][0], MOVE_NONE, i);
        GetSetPokedexFlag(SpeciesToNationalPokedexNum(SPECIES_GEODUDE), FLAG_SET_SEEN);
        if (arg == 2)
        {
            gPartnerTrainerId = TRAINER_PARTNER(PARTNER_LANCE);
            FillPartnerParty(gPartnerTrainerId);
        }
        if (arg)
        {
            gParties[B_TRAINER_OPPONENT_A][1] = gParties[B_TRAINER_OPPONENT_A][0];
            BattleSetup_StartDoubleWildBattle();
        }
        else
            BattleSetup_StartWildBattle();
        break;
    case 2:
        gSpecialVar_0x8005 = CountTotalItemQuantityInBag(ITEM_POKE_BALL);
        gSpecialVar_0x8006 = CountTotalItemQuantityInBag(ITEM_MASTER_BALL);
        gSpecialVar_0x8007 = CountTotalItemQuantityInBag(ITEM_GREAT_BALL);
        break;
    case 3:
        SavePlayerParty();
        TRAINER_BATTLE_PARAM.opponentA = TRAINER_CALVIN_1;
        TRAINER_BATTLE_PARAM.opponentB = TRAINER_BILLY;
        gPartnerTrainerId = TRAINER_PARTNER(PARTNER_LANCE);
        gBattleTypeFlags = BATTLE_TYPE_TRAINER | BATTLE_TYPE_DOUBLE | BATTLE_TYPE_MULTI | BATTLE_TYPE_INGAME_PARTNER | BATTLE_TYPE_TWO_OPPONENTS;
        for (u32 i = 0; i < MAX_FRONTIER_PARTY_SIZE; i++)
        {
            gSelectedOrderFromParty[i] = i + 1;
            gSaveBlock2Ptr->frontier.selectedPartyMons[i] = i + 1;
        }
        FillPartnerParty(gPartnerTrainerId);
        gBattleEnvironment = BattleSetup_GetEnvironmentId();
        CalculateEnemyPartyCount();
        BattleSetup_StartTrainerBattle_Debug();
        break;
    case 4:
        SetWarpDestination(MAP_GROUP(MAP_ROUTE101), MAP_NUM(MAP_ROUTE101), WARP_ID_NONE, 9, 9);
        DoWarp();
        break;
    case 5:
    {
        u32 value = TRUE;
        CreateMonWithIVs(&gParties[B_TRAINER_PLAYER][5], SPECIES_EEVEE, 5, 0x12345678, OTID_STRUCT_PLAYER_ID, 31);
        SetMonData(&gParties[B_TRAINER_PLAYER][5], MON_DATA_IS_EGG, &value);
        gSpecialVar_0x8004 = 5;
        EggHatch();
        break;
    }
    case 6:
        CreateMonWithIVs(&gParties[B_TRAINER_OPPONENT_A][0], SPECIES_MAGIKARP, 15, 0x87654321, OTID_STRUCT_PLAYER_ID, 31);
        gSpecialVar_0x8004 = 5;
        DoInGameTradeScene();
        break;
    case 7:
        gSpecialVar_0x8005 = GetMonData(&gParties[B_TRAINER_PLAYER][5], MON_DATA_SPECIES);
        gSpecialVar_0x8006 = GetMonData(&gParties[B_TRAINER_PLAYER][5], MON_DATA_IS_EGG);
        break;
    case 8:
    {
        u32 item = arg == 0 ? ITEM_CHARIZARDITE_X : ITEM_ELECTRIUM_Z;
        CreateMonWithIVs(&gParties[B_TRAINER_PLAYER][0], arg == 0 ? SPECIES_CHARIZARD : SPECIES_DRAGONITE, 40, 0x12345678, OTID_STRUCT_PLAYER_ID, 31);
        u32 metLevel = 5;
        SetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_MET_LEVEL, &metLevel);
        SetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_HELD_ITEM, &item);
        SetMonMoveSlot(&gParties[B_TRAINER_PLAYER][0], MOVE_THUNDERBOLT, 0);
        SetMonMoveSlot(&gParties[B_TRAINER_PLAYER][0], MOVE_SURF, 1);
        SetMonMoveSlot(&gParties[B_TRAINER_PLAYER][0], MOVE_FLAMETHROWER, 2);
        SetMonMoveSlot(&gParties[B_TRAINER_PLAYER][0], MOVE_DRAGON_CLAW, 3);
        AddBagItem(arg == 0 ? ITEM_MEGA_RING : ITEM_Z_POWER_RING, 1);
        break;
    }
    case 9:
        VarSet(VAR_REPEL_STEP_COUNT, 0);
        gSpecialVar_0x8005 = TrySavingData(SAVE_NORMAL);
        break;
    case 10:
        gLinkType = LINKTYPE_BATTLE;
        gBattleTypeFlags = BATTLE_TYPE_LINK | BATTLE_TYPE_TRAINER;
        TRAINER_BATTLE_PARAM.opponentA = TRAINER_LINK_OPPONENT;
        SetLocalLinkPlayerId(arg);
        gSaveBlock2Ptr->playerName[0] = CHAR_A + arg;
        CleanupOverworldWindowsAndTilemaps();
        gMain.savedCallback = CB2_ReturnToField;
        SetMainCallback2(CB2_InitBattle);
        break;
    case 12:
        ClearBag();
        AddBagItem(ITEM_MASTER_BALL, 1);
        gLastUsedBall = gBallToDisplay = ITEM_MASTER_BALL;
        break;
    case 13:
        gSpecialVar_0x8005 = CountMonsInBox(0);
        gSpecialVar_0x8006 = CountTotalItemQuantityInBag(ITEM_MASTER_BALL);
        break;
    case 14:
        gSaveBlock2Ptr->playerGender = arg / NUM_PLAYER_OUTFITS;
        VarSet(VAR_PLAYER_PALETTE, arg % NUM_PLAYER_OUTFITS);
        break;
    case 15:
        gIsDebugBattle = TRUE;
        gBattleEnvironment = arg;
        break;
    case 16:
        for (u32 i = 1; i < PARTY_SIZE; i++)
            ZeroMonData(&gParties[B_TRAINER_PLAYER][i]);
        gPartiesCount[B_TRAINER_PLAYER] = 1;
        EnterBugContestMode();
        break;
    case 17:
        gSpecialVar_0x8005 = GetBugContestFlag();
        gSpecialVar_0x8006 = gPartiesCount[B_TRAINER_PLAYER];
        ExitBugContestMode();
        break;
    case 19:
        gSpecialVar_0x8005 = CanCopyRecordedBattleSaveData();
        if (gSpecialVar_0x8005)
        {
            CleanupOverworldWindowsAndTilemaps();
            PlayRecordedBattle(CB2_ReturnToField);
        }
        break;
    case 21:
        CountResources();
        break;
    case 22:
    {
        struct Pokemon *mon = &gParties[B_TRAINER_PLAYER][0];
        u32 exp = gExperienceTables[gSpeciesInfo[GetMonData(mon, MON_DATA_SPECIES)].growthRate][41] - 1;
        SetMonData(mon, MON_DATA_EXP, &exp);
        if (arg)
        {
            u32 hp = 0;
            for (u32 i = 1; i < PARTY_SIZE; i++)
                SetMonData(&gParties[B_TRAINER_PLAYER][i], MON_DATA_HP, &hp);
        }
        break;
    }
    case 20:
        gIsDebugBattle = FALSE;
        if (arg == 0)
            SetWarpDestination(MAP_GROUP(MAP_ICE_PATH_1F), MAP_NUM(MAP_ICE_PATH_1F), WARP_ID_NONE, 9, 9);
        else
            SetWarpDestination(MAP_GROUP(MAP_MT_SILVER_SNOW), MAP_NUM(MAP_MT_SILVER_SNOW), WARP_ID_NONE, 9, 9);
        DoWarp();
        break;
    }
}
