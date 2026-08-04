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
#include "mail.h"
#include "international_string_util.h"
#include "constants/characters.h"
#include "constants/johto_compat.h"
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

// === Named story gifts (Kenya / Shuckie / Eevee / Dratini) ===
//
// Identity data shared by givenamedmon (which creates them) and removenamedmon (which has to
// recognise one again, possibly many hours of play later). Kept at file scope on purpose: two
// copies of "KENYA" is two things to keep in sync, and the delivery quest fails silently -
// not loudly - if they ever drift apart.
//
// Sized buffers, not bare literals: SetMonData copies a fixed POKEMON_NAME_LENGTH /
// PLAYER_NAME_LENGTH bytes and does NOT stop at EOS, so a short literal makes it over-read
// whatever .rodata happens to follow.
static const u8 sKenyaNickname[POKEMON_NAME_LENGTH + 1]   = _("KENYA");
static const u8 sKenyaOtName[PLAYER_NAME_LENGTH + 1]      = _("RUDY");
static const u8 sShuckieNickname[POKEMON_NAME_LENGTH + 1] = _("SHUCKIE");
static const u8 sShuckieOtName[PLAYER_NAME_LENGTH + 1]    = _("KIRK");
static const u8 sEeveeOtName[PLAYER_NAME_LENGTH + 1]      = _("BILL");

// HnS's preset OT ids for the named gifts. Kenya's is also stamped into her RetroMail as the
// SENDER id, so the letter and the bird agree on who wrote it - that is the only thing that
// lets Route 31 tell Randy's mail apart from a RetroMail the player wrote and swapped in.
#define KENYA_OT_ID    61225
#define SHUCKIE_OT_ID  4336
#define EEVEE_OT_ID    5231

// HnS `removenamedmon <giftId>`: hands a delivered story mon back to the NPC who asked for it.
// Two call sites: data/maps/Route31/scripts.inc (gift 1, Kenya, the sleeping man Randy sends you
// to) and data/maps/CianwoodHouse3/scripts.inc (gift 2, Shuckie, returned to Kirk). Shuckie is
// wired here too so the Cianwood half needs no second handler - note that script also branches on
// a bare `3`, HnS's "SHUCKLE likes you, keep it" friendship outcome, which is why
// REMOVE_NAMED_MON_KEPT is reserved and the new refusal codes start at 4.
//
// This shipped as a stub that read its operand and returned WITHOUT ever writing
// gSpecialVar_Result. The MSGBOX_YESNO immediately before it leaves VAR_RESULT == TRUE (1) and
// MON_CANT_GIVE is 2, so the script's `goto_if_eq VAR_RESULT, MON_CANT_GIVE` could never fire:
// the player "handed over" Kenya, kept her, and still collected TM Torment.
//
// Reports through gSpecialVar_Result using the REMOVE_NAMED_MON_* codes in
// constants/johto_compat.h. REMOVED/NOT_FOUND deliberately alias MON_GIVEN_TO_PARTY (0) and
// MON_CANT_GIVE (2) so the pre-existing branch keeps its meaning; the extra reasons are what
// let Route 31 finally use the refusal texts HnS shipped and this fork left defined-but-dead
// (Route31_Text_MissingMail / _WrongMail / _CantTakeLastMon).
void ScrCmd_removenamedmon_Compat(struct ScriptContext *ctx)
{
    u16 giftId = ScriptReadHalfword(ctx);
    enum Species species;
    const u8 *nickname;
    enum Item requiredMail; // ITEM_NONE = this gift is not a mail delivery
    u32 senderOtId;
    u8 nickBuffer[POKEMON_NAME_LENGTH + 1]; // MON_DATA_NICKNAME writes up to POKEMON_NAME_LENGTH bytes plus EOS
    struct Pokemon *target = NULL;
    u8 targetSlot = 0;
    u8 i;

    switch (giftId)
    {
    case 1: species = SPECIES_SPEAROW; nickname = sKenyaNickname;   senderOtId = KENYA_OT_ID;   requiredMail = ITEM_RETRO_MAIL; break;
    case 2: species = SPECIES_SHUCKLE; nickname = sShuckieNickname; senderOtId = SHUCKIE_OT_ID; requiredMail = ITEM_NONE;       break;
    default:
        // Hand-transcribed opcode operand, same discipline as the other handlers here: an id
        // we have no gift for must not fall through into a party scan on an uninitialised
        // species and delete something.
        gSpecialVar_Result = REMOVE_NAMED_MON_NOT_FOUND;
        return;
    }

    for (i = 0; i < PARTY_SIZE; i++)
    {
        struct Pokemon *mon = &gParties[B_TRAINER_PLAYER][i];

        if (GetMonData(mon, MON_DATA_SPECIES, NULL) != species)
            continue;
        GetMonData(mon, MON_DATA_NICKNAME, nickBuffer);
        if (StringCompare(nickBuffer, nickname) != 0)
            continue;
        target = mon;
        targetSlot = i;
        break;
    }

    if (target == NULL)
    {
        gSpecialVar_Result = REMOVE_NAMED_MON_NOT_FOUND;
        return;
    }

    // The same guard the PC deposit screen uses (CountPartyAliveNonEggMonsExcept): walking away
    // with nothing healthy and non-egg in the party is a white-out on the next patch of grass,
    // and the script cannot undo the removal once we have done it. Route 31 has a text for
    // precisely this case ("what are you going to use in battle?"), so refuse instead.
    if (CountPartyAliveNonEggMonsExcept(targetSlot) == 0)
    {
        gSpecialVar_Result = REMOVE_NAMED_MON_LAST_MON;
        return;
    }

    if (requiredMail != ITEM_NONE)
    {
        u32 mailId;
        bool8 fromSender = TRUE;

        if (!MonHasMail(target))
        {
            gSpecialVar_Result = REMOVE_NAMED_MON_NO_MAIL;
            return;
        }
        // "Holds mail" is not enough. The party menu lets the player take Kenya's letter off
        // and hang a different one on her, so check the item AND the sender: the mail's
        // trainerId is whoever wrote it, stamped from KENYA_OT_ID by givenamedmon below.
        // MAIL_NONE is already excluded by MonHasMail; the bound is for a corrupt save, since
        // a bad mailId indexes straight into the save block.
        mailId = GetMonData(target, MON_DATA_MAIL, NULL);
        if (mailId >= MAIL_COUNT || gSaveBlock1Ptr->mail[mailId].itemId != requiredMail)
        {
            gSpecialVar_Result = REMOVE_NAMED_MON_WRONG_MAIL;
            return;
        }
        for (i = 0; i < TRAINER_ID_LENGTH; i++)
        {
            if (gSaveBlock1Ptr->mail[mailId].trainerId[i] != (u8)(senderOtId >> (8 * i)))
                fromSender = FALSE;
        }
        if (!fromSender)
        {
            gSpecialVar_Result = REMOVE_NAMED_MON_WRONG_MAIL;
            return;
        }
    }

    // Frees the save block's mail record as well. ZeroMonData alone would drop the mon's
    // mailId reference and leave gSaveBlock1Ptr->mail[id].itemId set forever, permanently
    // burning one of the six party mail slots for the rest of the save.
    TakeMailFromMon(target);
    ZeroMonData(target);
    // CompactPartySlots shuffles and zeroes but does NOT maintain gPlayerPartyCount (same trap
    // remove5mons documents below), and a follower chosen from a now-reshuffled slot would keep
    // pointing at the wrong mon - Route 31 calls UpdateFollowingPokemon right after us, which
    // re-reads the slot, so it has to be reset before that runs.
    CompactPartySlots();
    CalculatePlayerPartyCount();
    gSaveBlock2Ptr->followerSlot = 0;

    gSpecialVar_Result = REMOVE_NAMED_MON_REMOVED;
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

// HnS `givenamedmon <giftId>`: the named story gifts. 1=Kenya (Spearow, OT RUDY, carrying
// Randy's RetroMail for the Route 31 sleeper), 2=Shuckie (Shuckle, OT KIRK), 3=Eevee (OT BILL),
// 4=Dratini (ExtremeSpeed + HnS's forced-shiny PID, Dragon's Den elder). Adapted to the
// expansion mon-creation API (CreateMon + OTID_STRUCT_*).
void ScrCmd_givenamedmon_Compat(struct ScriptContext *ctx)
{
    // Randy's note to his napping pal, written in the 2/2/2/2/1 word grouping Retro Mail
    // actually renders (sMailLayouts_Tall, src/mail.c - the "wide" 3x3 layout is never
    // reached outside JP): "MY FRIEND / YOU SLEEP / TOO MUCH / WAKE UP SOON / SEE YA".
    // Every entry must be a real EC_WORD_* constant: the mail viewer feeds these straight to
    // the easy-chat word tables with no range check, so a made-up group/index reads off the
    // end of them and prints garbage into the reader.
    static const u16 sKenyaMailWords[MAIL_WORDS_COUNT] = {
        EC_WORD_MY,      EC_WORD_FRIEND,
        EC_WORD_YOU,     EC_WORD_SLEEP,
        EC_WORD_TOO,     EC_WORD_MUCH,
        EC_WORD_WAKE_UP, EC_WORD_SOON,
        EC_WORD_SEE_YA,
    };
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

    switch (giftId)
    {
    case 1: species = SPECIES_SPEAROW; level = 20; nickname = sKenyaNickname;   otName = sKenyaOtName;   otId = KENYA_OT_ID; break;
    case 2: species = SPECIES_SHUCKLE; level = 20; item = ITEM_BERRY_JUICE; nickname = sShuckieNickname; otName = sShuckieOtName; otId = SHUCKIE_OT_ID; break;
    case 3: species = SPECIES_EEVEE;   level = 20; otName = sEeveeOtName;   otId = EEVEE_OT_ID; break;
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

        // Kenya is a MAIL delivery, not a loaner Spearow: Randy promises "a POKéMON with MAIL"
        // and Route 31's removenamedmon above now refuses a bird that is not carrying it.
        //
        // GiveMailToMon, NOT GiveMailToMonByItemId: the ByItemId path stamps the PLAYER's name
        // and trainer id into the record, and this letter is from RUDY. GiveMailToMon calls it
        // to claim a slot, then overwrites the record with the struct we hand it - that
        // overwrite is the entire reason the function exists. It also re-writes the held item
        // to the mail, which is why this has to run AFTER the ITEM_NONE write just above.
        if (giftId == 1)
        {
            struct Mail mail;
            u8 word;

            ClearMail(&mail); // initialise every field; this struct is copied into the save block verbatim
            for (word = 0; word < MAIL_WORDS_COUNT; word++)
                mail.words[word] = sKenyaMailWords[word];
            StringCopy(mail.playerName, sKenyaOtName);
            // The signature is centre-aligned against a fixed width, and every player-written
            // mail reaches that code space-padded (GiveMailToMonByItemId does it); pad here
            // too or RUDY's letter sits a few pixels off from every other mail in the game.
            PadNameString(mail.playerName, CHAR_SPACE);
            // Little-endian byte view of the 32-bit id, exactly how gSaveBlock2Ptr->playerTrainerId
            // is packed - removenamedmon compares against it byte for byte.
            for (word = 0; word < TRAINER_ID_LENGTH; word++)
                mail.trainerId[word] = (u8)(otId >> (8 * word));
            mail.species = SpeciesToMailSpecies(species, personality); // drives the mon drawn on the letter
            mail.itemId = ITEM_RETRO_MAIL;

            // Six party mail slots, and GiveMailToMon reports MAIL_NONE when all are taken. A
            // mail-less Kenya would still set VAR_KENYA = 1 at the call site and leave a quest
            // that can never complete, so refuse the whole gift - which means putting back the
            // party slot we already filled, or the player keeps a phantom Spearow.
            if (GiveMailToMon(mon, &mail) == MAIL_NONE)
            {
                ZeroMonData(mon);
                gSpecialVar_Result = MON_CANT_GIVE;
                return;
            }
        }

        if (giftId == 4)
        {
            u16 move = MOVE_EXTREME_SPEED;
            u8 pp = gMovesInfo[move].pp;
            bool8 isShiny = TRUE;

            SetMonData(mon, MON_DATA_MOVE1, &move);
            SetMonData(mon, MON_DATA_PP1, &pp);
            // HnS forces a shiny PID on the elder's Dratini; the call site
            // (DragonsDen_Shrine_EventScript_ElderGiveSpecialDratini) is reached only on
            // VAR_DRAGONS_DEN_QUIZ == 0, a perfect quiz, so this is a guaranteed shiny.
            // There is no CreateMonWithNature-style helper in this fork to re-roll a PID
            // against, and rejection-sampling one here would also re-roll nature/gender/IVs.
            // MON_DATA_IS_SHINY is the writable lever the expansion added for exactly this: it
            // XORs BoxPokemon.shinyModifier against the PID's natural shininess, in the
            // unencrypted header, so it survives the substruct shuffle. Same thing
            // ScriptGiveMonParameterized does for SHINY_MODE_ALWAYS and debug.c for its
            // shiny toggle.
            SetMonData(mon, MON_DATA_IS_SHINY, &isShiny);
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
// (randomizer rules). The HnS randomizer feature is unported, so report FALSE — the normal
// (non-randomized) path runs and the National Dex is earned through standard story progress.
// Real toggle lands in the content stage.
void ScrCmd_checkrandomizer_Compat(struct ScriptContext *ctx)
{
    (void)ctx;
    gSpecialVar_Result = FALSE;
}
