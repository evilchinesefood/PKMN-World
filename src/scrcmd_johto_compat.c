#include "global.h"
#include "event_data.h"
#include "pokemon.h"
#include "string_util.h"
#include "naming_screen.h"
#include "overworld.h"
#include "random.h"
#include "script.h"
#include "script_pokemon_util.h"
#include "pokemon_storage_system.h"
#include "event_object_movement.h"
#include "move.h"
#include "constants/songs.h"
#include "constants/vars.h"
#include "constants/species.h"
#include "constants/items.h"
#include "constants/moves.h"
#include "constants/pokedex.h"

// Region merge (Johto port): compat handlers + specials for HnS scripts.
//
// HnS event scripts call a handful of commands/specials whose opcode the target
// reuses or lacks (classes E/F in CompatEvent.inc), plus a few HnS-only specials.
// CompatEvent.inc re-expresses the class-E/F ops as `callnative ScrCmd_<name>_Compat`,
// reading their operands inline exactly as emitted, so byte layout is preserved.
//
// For the starting-area slice we only need the handlers/specials the New Bark +
// Route 29 + Cherrygrove maps actually use. HnS-only feature systems (the
// tx_randomizer / Nuzlocke challenge mode) are NOT ported; their hooks become
// functional no-ops / FALSE so the story scripts run correctly without them.
// Append handlers here as more Johto maps are ported.

// Mirrors scrcmd.c's static sScriptStringVars[] (gStringVar1..4) so a callnative
// compat handler can write the same script string buffers.
static u8 *const sJohtoScriptStringVars[] =
{
    gStringVar1,
    gStringVar2,
    gStringVar3,
    gStringVar4,
};

// HnS `buffermoncategory <stringVarId>, <species>` -> buffers the species' Pokedex
// category name into the script string var. HnS's version branched on tx-challenge
// state to swap the displayed species; with challenges unported we buffer the plain
// category, which is the faithful default-mode behavior.
void ScrCmd_buffermoncategory_Compat(struct ScriptContext *ctx)
{
    u8 stringVarIndex = ScriptReadByte(ctx);
    u16 species = VarGet(ScriptReadHalfword(ctx));

    StringCopy(sJohtoScriptStringVars[stringVarIndex], GetSpeciesCategory(species));
}

// HnS static-encounter randomizer toggles. Randomizer is not ported, so these are
// no-ops (static encounters always behave normally). Kept as real symbols because
// the lab starter scripts call them around the gift.
void DisableStaticRandomizer(struct ScriptContext *ctx)
{
    (void)ctx;
}

void EnableStaticRandomizer(struct ScriptContext *ctx)
{
    (void)ctx;
}

// HnS time-based-encounter selector (sets VAR_TIME_BASED_ENCOUNTER from the RTC and
// the alt-spawns mode). Phase-2 flattens day/night encounters to a single table
// (see recipe Risk #15), so this is a no-op for the slice.
void SetTimeBasedEncounters(struct ScriptContext *ctx)
{
    (void)ctx;
}

// HnS rival-naming special. Picks a default name then opens the rival naming screen,
// storing into gSaveBlock1Ptr->rivalName (where the target's {RIVAL} placeholder
// reads it under the always-on FRLG path).
static const u8 sJohtoDefaultRivalName[] = _("SILVER");

void NameRival(void)
{
    StringCopy(gSaveBlock1Ptr->rivalName, sJohtoDefaultRivalName);
    DoNamingScreen(NAMING_SCREEN_RIVAL, gSaveBlock1Ptr->rivalName, 0, 0, 0,
                   CB2_ReturnToFieldContinueScript);
}

// HnS Togepi check: TRUE if the lead party mon is in the Togepi line. Ported verbatim
// (all three species exist in the target).
u16 CheckTogepi(void)
{
    u16 species = GetMonData(&gPlayerParty[0], MON_DATA_SPECIES_OR_EGG, NULL);

    if (species == SPECIES_TOGEPI || species == SPECIES_TOGETIC || species == SPECIES_TOGEKISS)
        return TRUE;
    return FALSE;
}

// HnS Nuzlocke nickname gate. Nuzlocke mode is unported, so always inactive.
u16 IsNuzlockeNicknamingActive(void)
{
    return FALSE;
}

// HnS Ruins of Alph sliding-puzzle minigame (sliding_puzzle.c, ~430 lines). Unported
// for the Violet-area pass; the puzzles are optional side content (they unlock Unown).
// Stub reports "not solved" so the chamber scripts continue without the reward.
void DoSlidingPuzzle(void)
{
    gSpecialVar_Result = FALSE;
}

// HnS Ruins of Alph fossil-reward checks. The Unown fossil minigame is unported
// (optional side content); stubs report "no fossil brought" so the chamber scripts
// skip the reward and stay walkable.
void CheckHooh(void) { gSpecialVar_Result = FALSE; }
void CheckAerodactyl(void) { gSpecialVar_Result = FALSE; }
void CheckKabuto(void) { gSpecialVar_Result = FALSE; }
void CheckOmanyte(void) { gSpecialVar_Result = FALSE; }
void IsRandomMovesActivated(void) { gSpecialVar_Result = FALSE; } // HnS randomizer: report OFF (region merge stub)
void IsPokecenterChallengeActivated(void) { gSpecialVar_Result = FALSE; } // HnS Pokecenter challenge: report OFF so SS Aqua cabin beds heal normally (region merge stub)

// HnS removenamedmon: removes a delivered story mon (Kenya/Shuckie). Story-mon delivery
// is unported; stub reads its operand and no-ops so the script pointer stays aligned.
void ScrCmd_removenamedmon_Compat(struct ScriptContext *ctx)
{
    u16 number = ScriptReadHalfword(ctx);
    (void)number;
}

// HnS giveoddegg (Azalea daycare): gives the Day-Care Odd Egg. The HnS odd-egg
// generator (random species + boosted shiny odds) is unported; stub reads its operand
// and no-ops so the script pointer stays aligned. Real egg gift lands in the content stage.
void ScrCmd_giveoddegg_Compat(struct ScriptContext *ctx)
{
    u16 number = ScriptReadHalfword(ctx);
    (void)number;
}

// HnS tx_randomizer GetMaxPartySize (challenge modes cap party size). Randomizer/
// challenge modes are unported; report the normal max so daycare/party logic proceeds.
void GetMaxPartySize(void) { gSpecialVar_Result = PARTY_SIZE; }

// Goldenrod-area special stubs (region merge). Bug Contest minigame, haircut
// brothers, and shiny-palette toggle are unported side systems; these no-op so
// the maps' scripts run. Refine in a later content pass.
void EnterBugContestMode(void) {}
void ShowBugContestChosenMon(void) {}
void HaircutBrother1(void) {}
void ToggleShinyColors(void) {}

// HnS `givenamedmon <giftId>`: the named story gifts. 1=Kenya (Spearow, OT RUDY), 2=Shuckie
// (Shuckle, OT KIRK), 3=Eevee (OT BILL), 4=Dratini (ExtremeSpeed, Dragon's Den elder). Adapted
// to the expansion mon-creation API (CreateMon + OTID_STRUCT_*). v1 omits Kenya's RetroMail
// content (the guard quest checks species/nickname) and Dratini's forced-shiny PID.
void ScrCmd_givenamedmon_Compat(struct ScriptContext *ctx)
{
    u16 giftId = ScriptReadHalfword(ctx);
    struct Pokemon *mon;
    enum Species species;
    u8 level;
    u16 item = ITEM_NONE;
    u32 personality = Random32();
    u32 otId = 0;
    const u8 *nickname = NULL;
    const u8 *otName = NULL;
    u8 heldItem[2];
    u8 i;
    static const u8 sKenyaNickname[]   = _("KENYA");
    static const u8 sKenyaOtName[]     = _("RUDY");
    static const u8 sShuckieNickname[] = _("SHUCKIE");
    static const u8 sShuckieOtName[]   = _("KIRK");
    static const u8 sEeveeOtName[]     = _("BILL");

    switch (giftId)
    {
    case 1: species = SPECIES_SPEAROW; level = 20; nickname = sKenyaNickname;   otName = sKenyaOtName;   otId = 61225; break;
    case 2: species = SPECIES_SHUCKLE; level = 20; item = ITEM_BERRY_JUICE; nickname = sShuckieNickname; otName = sShuckieOtName; otId = 4336; break;
    case 3: species = SPECIES_EEVEE;   level = 20; otName = sEeveeOtName;   otId = 5231; break;
    case 4: species = SPECIES_DRATINI; level = 15; break; // player OT
    default: gSpecialVar_Result = MON_CANT_GIVE; return;
    }

    heldItem[0] = item & 0xFF;
    heldItem[1] = item >> 8;

    for (i = 0; i < PARTY_SIZE; i++)
    {
        mon = &gParties[B_TRAINER_PLAYER][i];
        if (GetMonData(mon, MON_DATA_SPECIES, NULL) != SPECIES_NONE)
            continue;

        if (giftId == 4)
            CreateMon(mon, species, level, personality, OTID_STRUCT_PLAYER_ID);
        else
            CreateMon(mon, species, level, personality, OTID_STRUCT_PRESET(otId));

        if (nickname != NULL)
            SetMonData(mon, MON_DATA_NICKNAME, nickname);
        if (otName != NULL)
            SetMonData(mon, MON_DATA_OT_NAME, otName);
        SetMonData(mon, MON_DATA_HELD_ITEM, heldItem);

        if (giftId == 4)
        {
            u16 move = MOVE_EXTREME_SPEED;
            u8 pp = gMovesInfo[move].pp;
            SetMonData(mon, MON_DATA_MOVE1, &move);
            SetMonData(mon, MON_DATA_PP1, &pp);
        }

        CalculateMonStats(mon);
        HandleSetPokedexFlag(SpeciesToNationalPokedexNum(species), FLAG_SET_SEEN, personality);
        HandleSetPokedexFlag(SpeciesToNationalPokedexNum(species), FLAG_SET_CAUGHT, personality);
        gSpecialVar_Result = MON_GIVEN_TO_PARTY;
        return;
    }
    gSpecialVar_Result = MON_CANT_GIVE; // party full
}
void ScrCmd_remove5mons_Compat(struct ScriptContext *ctx) { (void)ctx; }

// === Mahogany area (region merge) ===

// HnS `setwildbattleshiny <species>, <level>, <item>` -> sets up the next scripted wild
// battle (Lake of Rage Red Gyarados). HnS's CreateShinyScriptedMon forces a shiny PID via
// tx_randomizer-coupled helpers that aren't ported; create a standard scripted wild mon so
// the battle fires. The red/shiny palette is content-stage polish.
void ScrCmd_setwildbattleshiny_Compat(struct ScriptContext *ctx)
{
    u16 species = ScriptReadHalfword(ctx);
    u8 level = ScriptReadByte(ctx);
    u16 item = ScriptReadHalfword(ctx);

    CreateScriptedWildMon(species, level, item);
}

// HnS `removegenericmon <species>` (Lake of Rage Magikarp-length house): removes the party
// mon at slot VAR_0x8004 if it matches <species>, reporting via gSpecialVar_Result. Ported
// verbatim from HnS scrcmd.c; MON_SATISFACTORY/MON_UNSATISFACTORY are the HnS result codes
// (2/1) inlined since the target lacks those constants.
void ScrCmd_removegenericmon_Compat(struct ScriptContext *ctx)
{
    u16 targetSpecies = ScriptReadHalfword(ctx);
    u8 monIndex = VarGet(VAR_0x8004);

    if (monIndex >= PARTY_SIZE)
    {
        gSpecialVar_Result = FALSE;
        return;
    }

    struct Pokemon *mon = &gPlayerParty[monIndex];
    u16 species = GetMonData(mon, MON_DATA_SPECIES, NULL);

    if (species == SPECIES_NONE || species != targetSpecies)
    {
        gSpecialVar_Result = FALSE;
        return;
    }

    if (species == SPECIES_MAGIKARP)
    {
        u8 level = GetMonData(mon, MON_DATA_LEVEL, NULL);
        if (level == 100)
        {
            ZeroMonData(mon);
            CompactPartySlots();
            gSpecialVar_Result = 2; // MON_SATISFACTORY
            return;
        }
    }

    ZeroMonData(mon);
    CompactPartySlots();
    gSpecialVar_Result = 1; // MON_UNSATISFACTORY
}

// === Safari Zone area (region merge) ===

// HnS `baobacheckmon <area>` (Safari Zone gate entrance): the HGSS Safari-Zone custom-area
// quest checks whether the chosen party mon is the "exotic" species Baoba wants from Fuchsia
// Safari Zone area <area>, reporting via gSpecialVar_Result. The Fuchsia/Kanto safari areas
// and the per-area species table are content-stage; read the operand and report FALSE so the
// quest path safely dead-ends ("That can't be right!") instead of paying out or freezing.
// Real check lands in the content stage.
void ScrCmd_baobacheckmon_Compat(struct ScriptContext *ctx)
{
    u16 number = ScriptReadHalfword(ctx);
    (void)number;
    gSpecialVar_Result = FALSE;
}

// HnS CheckCelebi (Tohjo Falls): the post-game Giovanni encounter triggers only when the
// player arrives with Celebi as the lead, at full HP, walking with it as a follower (the
// Ilex-Forest time-travel setup). Ported from HnS braille_puzzles.c. (Obtaining Celebi via
// the GS-Ball/Ilex shrine is its own event; this check is correct regardless.)
void CheckCelebi(void)
{
    struct Pokemon *mon = &gParties[B_TRAINER_PLAYER][0];
    struct ObjectEvent *follower;

    if (GetMonData(mon, MON_DATA_SPECIES_OR_EGG, NULL) != SPECIES_CELEBI)
    {
        gSpecialVar_Result = FALSE;
        return;
    }
    if (GetMonData(mon, MON_DATA_HP, NULL) != GetMonData(mon, MON_DATA_MAX_HP, NULL))
    {
        gSpecialVar_Result = FALSE;
        return;
    }
    follower = GetFollowerObject();
    if (follower == NULL || follower->invisible)
    {
        gSpecialVar_Result = FALSE;
        return;
    }
    gSpecialVar_Result = TRUE;
}

// HnS `checkrandomizer` (callnative, used by Mr. Pokemon's House): reports whether randomizer
// mode is active via gSpecialVar_Result; on TRUE the script grants the National Dex immediately
// (randomizer rules). The HnS randomizer feature is unported, so report FALSE — the normal
// (non-randomized) path runs and the National Dex is earned through standard story progress.
// Real toggle lands in the content stage.
void ScrCmd_checkrandomizer_Compat(struct ScriptContext *ctx)
{
    (void)ctx;
    gSpecialVar_Result = FALSE;
}
