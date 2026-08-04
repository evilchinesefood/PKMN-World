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
#include "daycare.h"
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

    if (stringVarIndex >= ARRAY_COUNT(sJohtoScriptStringVars)) // hand-transcribed opcode — never write through a bad operand
        return;
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
static const u8 sJohtoDefaultRivalName[] = _("GARY");

void NameRival(void)
{
    // Region merge: rival naming removed — fixed default (GARY), no naming screen. The
    // calling script's waitstate returns immediately since we no longer swap the callback.
    StringCopy(gSaveBlock1Ptr->rivalName, sJohtoDefaultRivalName);
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

// HnS Ruins of Alph fossil-reward checks (ported from braille_puzzles.c): TRUE when the
// lead party mon is the matching fossil/legendary species. Invoked by the Unown reward
// chambers via `specialvar VAR_RESULT, Check*`. The sliding-puzzle minigame itself
// (DoSlidingPuzzle) now lives in src/sliding_puzzle.c.
bool8 CheckHooh(void)       { return GetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_SPECIES_OR_EGG, NULL) == SPECIES_HO_OH; }
bool8 CheckAerodactyl(void) { return GetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_SPECIES_OR_EGG, NULL) == SPECIES_AERODACTYL; }
bool8 CheckKabuto(void)     { return GetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_SPECIES_OR_EGG, NULL) == SPECIES_KABUTO; }
bool8 CheckOmanyte(void)    { return GetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_SPECIES_OR_EGG, NULL) == SPECIES_OMANYTE; }
// Both are consumed via `specialvar`, which stores the RETURN VALUE (scrcmd.c) — a void
// special leaves garbage r0 in the target var, so these must return, not write Result.
u16 IsRandomMovesActivated(void) { return FALSE; } // HnS randomizer: report OFF (region merge stub)
u16 IsPokecenterChallengeActivated(void) { return FALSE; } // HnS Pokecenter challenge: report OFF so SS Aqua cabin beds heal normally (region merge stub)

// HnS removenamedmon: removes a delivered story mon (Kenya/Shuckie). Story-mon delivery
// is unported; stub reads its operand and no-ops so the script pointer stays aligned.
void ScrCmd_removenamedmon_Compat(struct ScriptContext *ctx)
{
    u16 number = ScriptReadHalfword(ctx);
    (void)number;
}

// HnS `giveoddegg <1..7>` (Route 34 Day-Care): the Odd Egg, which hatches into a baby
// (Pichu/Cleffa/Igglybuff/Tyrogue/Smoochum/Elekid/Magby) knowing Dizzy Punch. The species
// index is chosen by the caller. Built on the expansion CreateEgg helper. v1 uses the engine's
// default shiny odds (HnS's name-list 100%-shiny easter egg + 14% boost are flavor polish).
void ScrCmd_giveoddegg_Compat(struct ScriptContext *ctx)
{
    static const enum Species sOddEggSpecies[8] = {
        SPECIES_NONE, SPECIES_PICHU, SPECIES_CLEFFA, SPECIES_IGGLYBUFF,
        SPECIES_TYROGUE, SPECIES_SMOOCHUM, SPECIES_ELEKID, SPECIES_MAGBY,
    };
    u16 which = VarGet(ScriptReadHalfword(ctx)); // immediate or VAR
    enum Species species;
    u8 i;

    if (which == 0 || which >= ARRAY_COUNT(sOddEggSpecies) || sOddEggSpecies[which] == SPECIES_NONE)
    {
        gSpecialVar_Result = MON_CANT_GIVE;
        return;
    }
    species = sOddEggSpecies[which];

    for (i = 0; i < PARTY_SIZE; i++)
    {
        struct Pokemon *mon = &gParties[B_TRAINER_PLAYER][i];
        if (GetMonData(mon, MON_DATA_SPECIES, NULL) != SPECIES_NONE)
            continue;
        CreateEgg(mon, species, FALSE);
        SetMonMoveSlot(mon, MOVE_DIZZY_PUNCH, 1);
        CalculateMonStats(mon);
        // This bypasses GiveMonToPlayer, the only path that does gPlayerPartyCount = i + 1,
        // so without this the egg is in the array but invisible to every count consumer.
        CalculatePlayerPartyCount();
        gSpecialVar_Result = MON_GIVEN_TO_PARTY;
        return;
    }
    gSpecialVar_Result = MON_CANT_GIVE;
}

// HnS tx_randomizer GetMaxPartySize (challenge modes cap party size). Randomizer/
// challenge modes are unported; report the normal max so daycare/party logic proceeds.
// Consumed via `specialvar VAR_0x8004, ...` (Route 34 daycare full-party guard), which
// stores the RETURN VALUE — as a void special the guard compared against pointer garbage
// and the egg give could overwrite party slot 6.
u16 GetMaxPartySize(void) { return PARTY_SIZE; }

// Goldenrod Underground haircut brothers: boost the chosen party mon's friendship
// (VAR_0x8004 = the ChoosePartyMon slot, already bounds-checked by the scripts). HnS
// used dedicated FRIENDSHIP_EVENT_HAIRCUT1/2; the massage event is the faithful
// equivalent in the target. Both brothers call this special.
void HaircutBrother1(void)
{
    u8 slot = VarGet(VAR_0x8004);

    if (slot < PARTY_SIZE)
        AdjustFriendship(&gParties[B_TRAINER_PLAYER][slot], FRIENDSHIP_EVENT_MASSAGE);
}

// Region-merge stub. ToggleShinyColors targets a tx_randomizer save field that does
// not exist in the target, so it is correctly a no-op. (EnterBugContestMode and
// ShowBugContestChosenMon now have real implementations in src/bug_contest.c.)
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
    // Sized buffers, not bare literals: SetMonData copies a fixed POKEMON_NAME_LENGTH /
    // PLAYER_NAME_LENGTH bytes (it does not stop at EOS), so short literals over-read .rodata.
    static const u8 sKenyaNickname[POKEMON_NAME_LENGTH + 1]   = _("KENYA");
    static const u8 sKenyaOtName[PLAYER_NAME_LENGTH + 1]      = _("RUDY");
    static const u8 sShuckieNickname[POKEMON_NAME_LENGTH + 1] = _("SHUCKIE");
    static const u8 sShuckieOtName[PLAYER_NAME_LENGTH + 1]    = _("KIRK");
    static const u8 sEeveeOtName[PLAYER_NAME_LENGTH + 1]      = _("BILL");

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
        // Bypasses GiveMonToPlayer (see giveoddegg above) - resync or the gift stays uncounted.
        CalculatePlayerPartyCount();
        gSpecialVar_Result = MON_GIVEN_TO_PARTY;
        return;
    }
    gSpecialVar_Result = MON_CANT_GIVE; // party full
}
// HnS `remove5mons` (Bug Contest entry): validates the lead party mon is usable
// (not fainted, not an egg), then clears party slots 2..6 so the player enters the
// contest with a single mon. Ported from HnS scrcmd.c ScrCmd_remove5mons; reports via
// gSpecialVar_Result (MON_GIVEN_TO_PARTY on success, MON_CANT_GIVE on a bad lead).
void ScrCmd_remove5mons_Compat(struct ScriptContext *ctx)
{
    u8 removedCount = 0;
    u8 i;
    (void)ctx;

    if (GetMonData(&gPlayerParty[0], MON_DATA_HP, NULL) == 0)
    {
        gSpecialVar_Result = MON_CANT_GIVE;
        return;
    }

    if (GetMonData(&gPlayerParty[0], MON_DATA_SPECIES_OR_EGG, NULL) == SPECIES_EGG)
    {
        gSpecialVar_Result = MON_CANT_GIVE;
        return;
    }

    for (i = 1; i < PARTY_SIZE; i++)
    {
        if (GetMonData(&gPlayerParty[i], MON_DATA_SPECIES, NULL) != SPECIES_NONE)
        {
            ZeroMonData(&gPlayerParty[i]);
            removedCount++;
        }
    }

    // CompactPartySlots only shuffles and zeroes - it does NOT touch gPlayerPartyCount. Without
    // this the count stays at the pre-entry size with slots 1-5 zeroed, and Gate_NationalPark
    // warps straight into the contest map with no intervening resync, so Pokevial_HealPlayerParty
    // and the Battle Net party checks iterate zeroed mons - and autosave-on-transition persists it.
    if (removedCount > 0)
    {
        CompactPartySlots();
        CalculatePlayerPartyCount();
        // Same hazard DepositPartyToPC (region_switch.c) documents: a follower chosen from
        // slots 2-6 would keep pointing into a now-emptied/reshuffled slot for the contest.
        gSaveBlock2Ptr->followerSlot = 0;
    }

    gSpecialVar_Result = MON_GIVEN_TO_PARTY;
}

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

    // Hand-transcribed opcode operand — sanitize before CreateBoxMon indexes gSpeciesInfo,
    // matching the validation every sibling compat handler in this file performs.
    CreateScriptedWildMon(SanitizeSpeciesId(species), level, item);
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
            CalculatePlayerPartyCount(); // CompactPartySlots does not maintain the count
            gSpecialVar_Result = 2; // MON_SATISFACTORY
            return;
        }
    }

    ZeroMonData(mon);
    CompactPartySlots();
    CalculatePlayerPartyCount(); // CompactPartySlots does not maintain the count
    gSpecialVar_Result = 1; // MON_UNSATISFACTORY
}

// === Safari Zone area (region merge) ===

// HnS `baobacheckmon <area>` (Safari Zone gate entrance): the HGSS Safari-Zone custom-area
// quest checks whether the chosen party mon is the "exotic" species Warden Baoba wants from
// area <area>, reporting via gSpecialVar_Result. Read the operand (the script pointer must stay
// aligned) and report FALSE, so the quest path dead-ends on "That can't be right!" instead of
// paying out or freezing.
//
// WONTFIX (issue #66). This is the permanent behavior, not a placeholder, and the reason is not
// the one this comment used to give. It claimed "the Fuchsia/Kanto safari areas and the per-area
// species table are content-stage". That premise is stale, and the real situation is worse:
//
//   * The Fuchsia safari SHIPPED with the Kanto merge. data/maps holds the FRLG four-area set
//     (SafariZone_{Center,East,North,West}_Frlg plus the four rest houses and the secret house);
//     FuchsiaCity_Frlg/map.json warps into FuchsiaCity_SafariZone_Entrance_Frlg, which warps on
//     to MAP_SAFARI_ZONE_CENTER. The blocker the old comment named no longer exists.
//
//   * The quest can never start, which no species table would fix. VAR_BAOBA_QUEST_STATE
//     (constants/johto_vars.h) is read at SafariZoneGate_SafariZoneEntrance/scripts.inc:59-63 and
//     written ONLY as 2/3/4/5, by the four stage-completion branches themselves. Nothing in the
//     tree ever sets it to 1. Vars are zero-initialised, so EventScript_Baoba always falls through
//     to the generic greeting, and not one of the four `baobacheckmon` call sites is reachable
//     without externally forcing the var — this handler cannot run in normal play. The one Baoba
//     phone call that does exist (Route27_EventScript_BaobaCall) announces the Safari Zone west
//     expansion and sets its own VAR_ROUTE27_BAOBA_CALL; it does not touch the quest state.
//
//   * The areas the script names do not exist. The four prompts ask for an exotic mon from the
//     BEACH / BRUSH / MOUNTAIN / CAVE area of the FUCHSIA SAFARI ZONE. The shipped Fuchsia safari
//     is FRLG geography — Center / East / North / West — and this gate warps into the JOHTO safari
//     (MAP_SAFARI_ZONE_ENTERANCE) regardless. There is no beach, brush, mountain or cave area to
//     derive an area->species mapping from, and no sSafariZoneAreas-style table anywhere in the
//     tree to derive it into.
//
// So reviving this needs a quest starter AND an authored area->species mapping the shipped
// geography cannot supply: new game design, not a port. Two more signs the HnS port was abandoned
// mid-flight — Text_BaobaLastMon (the "I can't take your last POKEMON!" refusal) is defined and
// never referenced, and the four stages pay out 1,300,000 total (200k/300k/400k/400k), a figure
// nobody balanced because nobody could reach it. See the file-head note in
// SafariZoneGate_SafariZoneEntrance/scripts.inc.
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
// Consumed via `specialvar VAR_RESULT, ...` which stores the RETURN VALUE (same idiom as
// CheckHooh above) — as a void special the gate compared against leftover r0 and the
// encounter could never legitimately arm.
bool8 CheckCelebi(void)
{
    struct Pokemon *mon = &gParties[B_TRAINER_PLAYER][0];
    struct ObjectEvent *follower;

    if (GetMonData(mon, MON_DATA_SPECIES_OR_EGG, NULL) != SPECIES_CELEBI)
        return FALSE;
    if (GetMonData(mon, MON_DATA_HP, NULL) != GetMonData(mon, MON_DATA_MAX_HP, NULL))
        return FALSE;
    follower = GetFollowerObject();
    if (follower == NULL || follower->invisible)
        return FALSE;
    return TRUE;
}

// HnS `checkrandomizer` (callnative, used by Mr. Pokemon's House): reports whether randomizer
// mode is active via gSpecialVar_Result; on TRUE the script grants the National Dex immediately
// (randomizer rules skip the story gate). Report FALSE.
//
// WONTFIX (issue #66). FALSE is not a placeholder here — it is the correct permanent answer, and
// the old "real toggle lands in the content stage" line promised work that would be a regression
// if it happened. The tx_randomizer feature is unported BY DESIGN (see the file header), so there
// is no mode for this to read and no user-visible setting to toggle. This file already stubs the
// whole family on exactly these grounds: IsRandomMovesActivated, IsPokecenterChallengeActivated,
// IsNuzlockeNicknamingActive, ToggleShinyColors (whose tx_randomizer save field does not exist in
// the target at all), and GetMaxPartySize documents the same reasoning.
//
// With FALSE, Mr. Pokemon's House takes the normal branch and the National Dex is earned through
// story progress, which is what this hack wants. A "real" implementation would only ever hand out
// a free National Dex on behalf of a mode that cannot be entered.
void ScrCmd_checkrandomizer_Compat(struct ScriptContext *ctx)
{
    (void)ctx;
    gSpecialVar_Result = FALSE;
}
