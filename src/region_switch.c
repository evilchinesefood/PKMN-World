#include "global.h"
#include "regions.h"
#include "event_data.h"
#include "script.h"
#include "constants/regions.h"
#include "constants/vars.h"
#include "constants/difficulty.h"
#include "pokemon.h"
#include "pokemon_storage_system.h"
#include "constants/battle.h"
#include "constants/pokemon.h"
#include "constants/flags.h"
#include "constants/maps.h"
#include "constants/map_groups.h"
#include "overworld.h"
#include "mail.h"
#include "constants/heal_locations.h"
#include "constants/items.h"
#include "item.h"
#include "pokedex.h"

// World Transit hub - region-switch foundation. Pairs with the map-derived
// GetCurrentRegion() in include/regions.h.
//
// gCurrentRegion is the EWRAM-resident "active campaign" context the hub sets when the
// player picks a destination. Per the merge architecture's IWRAM discipline, new resident
// region state lives in EWRAM (never IWRAM) and costs zero SaveBlock growth.
EWRAM_DATA enum Region gCurrentRegion = REGION_NONE;

// Set the active region context for the campaign the player is travelling into.
//
// In this engine most "region context" needs no runtime swap on a region change:
//   - Per-region story FLAGS/VARS use absolute IDs (FLAG_<REGION>_BASE / VAR_<REGION>_BASE)
//     dispatched in GetFlagPointer()/GetVarPointer() - there is no active bank pointer to
//     repoint, so nothing to swap here.
//   - The region map, roamer ownership and GetCurrentRegion() all derive the region from
//     the destination map's MAPSEC / map group, so they self-update once the hub warp lands.
//
// So the routine records the explicit active-region intent (the seam region-aware systems
// and the deferred arrival-quest work hook into) and leaves the rest to the warp.
// Feature C: gym-leader HARD rematches unlock per region. The difficulty tier follows the
// ACTIVE region's champion status so a champion of one region still fights NORMAL first-run
// teams in a region they haven't cleared (VAR_DIFFICULTY is global; HARD parties exist for
// gym leaders in all three regions, so it must never leak across regions).
bool8 IsRegionChampion(enum Region region)
{
    switch (region)
    {
    case REGION_KANTO: return FlagGet(FLAG_KANTO_CHAMPION);
    case REGION_JOHTO: return FlagGet(FLAG_JOHTO_CHAMPION);
    case REGION_HOENN: return FlagGet(FLAG_HOENN_CHAMPION);
    default:           return FALSE;
    }
}

void SyncDifficultyForRegion(enum Region region)
{
    VarSet(VAR_DIFFICULTY, IsRegionChampion(region) ? DIFFICULTY_HARD : DIFFICULTY_NORMAL);
}

// INVARIANT (difficulty containment): every cross-region entry MUST pass through
// SetCurrentRegion (hub gate) or ResyncCurrentRegionFromMap (warp/continue load).
// A future cross-region warp that bypasses both would carry the previous region's
// VAR_DIFFICULTY tier with it unnoticed - route new entry points through here.
void SetCurrentRegion(enum Region region)
{
    gCurrentRegion = region;
    gSaveBlock2Ptr->currentRegion = region; // persist so a reset / hub trip keeps the context (task 21)
    SyncDifficultyForRegion(region);

    // TODO(region-switch follow-up): when per-region heal/fly defaults exist, reset the
    // last-heal location to this region's start here. Deferred with the arrival-quest work
    // (.plans/features/03b-RegionSwitchDesignSpec.md G4/Section 5). The clerk's resume warp
    // already drops the player at the chosen region's start town.
}

// Field-load re-sync for the EWRAM active-region mirror. gCurrentRegion lives only in EWRAM and
// zeroes to REGION_NONE on a soft-reset. Without this, a Continue (or any cross-region warp that
// bypasses the hub gate) leaves it stale, so the next hub trip where you re-pick the region you
// are ALREADY in sees target != gCurrentRegion and DepositPartyToPC() boxes your whole party.
//
// Prefer the PERSISTED SaveBlock2.currentRegion (task 21): it survives resets and is correct even
// in the hub, where GetCurrentRegion() falls back to REGION_HOENN. Fall back to the map only for
// saves that never recorded a region (pre-first-gate, or older saves from before the field
// existed), and never clobber the mirror while standing in the hub.
void ResyncCurrentRegionFromMap(void)
{
    // Back-fill DexNav for saves made before it was enabled (commit 5f96268e, 2026-07-05). The
    // Pokedex-give scripts now also setflag FLAG_SYS_DEXNAV_GET, but saves that already received
    // the Pokedex passed that point and never got the flag, so the DexNav never appeared in the
    // start menu. Runs on Continue/warp (idempotent): if you have the Pokedex, you have the DexNav.
    if (FlagGet(FLAG_SYS_POKEDEX_GET) && !FlagGet(FLAG_SYS_DEXNAV_GET))
        FlagSet(FLAG_SYS_DEXNAV_GET);

    // Merged-game essential: any Pokedex holder should already have the National Dex (enabled at
    // the early Oak/Birch/Elm dex-give scene). Belt-and-suspenders for any save that somehow
    // reached the Pokedex without it. Guarded, so it's a no-op once enabled.
    if (FlagGet(FLAG_SYS_POKEDEX_GET) && !IsNationalPokedexEnabled())
        EnableNationalPokedex();

    if (gSaveBlock2Ptr->currentRegion != REGION_NONE)
    {
        gCurrentRegion = gSaveBlock2Ptr->currentRegion;
        SyncDifficultyForRegion(gCurrentRegion); // self-heal pre-Feature-C champion saves
        return;
    }

    if (gSaveBlock1Ptr->location.mapGroup == MAP_GROUP(MAP_REGION_HUB)
     && gSaveBlock1Ptr->location.mapNum == MAP_NUM(MAP_REGION_HUB))
        return;

    gCurrentRegion = GetCurrentRegion();
    SyncDifficultyForRegion(gCurrentRegion); // pre-region-field champion saves need the tier too
}

// callnative hook used by the hub transit clerk. The clerk's multichoice stores the
// selection in VAR_RESULT (0 = Kanto, 1 = Johto, 2 = Hoenn); map it onto enum Region,
// which is contiguous from REGION_KANTO.
void RegionHub_ScrSetCurrentRegion(struct ScriptContext *ctx)
{
    SetCurrentRegion((enum Region)(REGION_KANTO + VarGet(VAR_RESULT)));
}

// Task 5a: on a region CROSS, arm the whiteout respawn at the destination region's start-town
// heal location. The hub no longer sets itself as the respawn (its OnTransition setrespawn was
// removed - the hub PokeCenter is OAM-starved and crash-prone, and should never be a whiteout
// target), so without this the respawn would be left pointing into the PREVIOUS region. The
// player re-sets it normally by healing at a local PokeCenter.
static void SetRegionArrivalRespawn(enum Region region)
{
    u8 healLocationId;

    switch (region)
    {
    case REGION_KANTO:
        healLocationId = HEAL_LOCATION_PALLET_TOWN;
        break;
    case REGION_JOHTO:
        healLocationId = HEAL_LOCATION_NEW_BARK_TOWN;
        break;
    case REGION_HOENN:
    default:
        healLocationId = (gSaveBlock2Ptr->playerGender == FEMALE)
                       ? HEAL_LOCATION_LITTLEROOT_TOWN_MAYS_HOUSE
                       : HEAL_LOCATION_LITTLEROOT_TOWN_BRENDANS_HOUSE;
        break;
    }
    SetLastHealLocationWarp(healLocationId);
}

// Hub spatial-gate entry (D2): box the carried party only when crossing into a DIFFERENT region
// (so a hub -> same-region round trip keeps your current team), then set the active region and
// point the whiteout respawn into that region. VAR_RESULT holds the gate's region index
// (0 = Kanto, 1 = Johto, 2 = Hoenn). A brand-new game has gCurrentRegion == REGION_NONE and an
// empty party, so the deposit is a harmless no-op but the respawn is still armed correctly.
void RegionHub_ScrEnterRegion(struct ScriptContext *ctx)
{
    enum Region target = (enum Region)(REGION_KANTO + VarGet(VAR_RESULT));

    if (target != gCurrentRegion)
    {
        DepositPartyToPC();
        SetRegionArrivalRespawn(target);
    }
    SetCurrentRegion(target);
}

// D3 arrival: arm the start-town "Mom moves into a new house" scene. Sets VAR_REGION_ARRIVAL=1
// only when the CURRENT region's intro-done bit is unset; the town's ON_FRAME map_script_2
// reacts to it. Called from each start town's ON_TRANSITION, so it self-clears on return visits.
void RegionHub_ScrArmArrival(struct ScriptContext *ctx)
{
    bool8 done;

    switch (GetCurrentRegion())
    {
    case REGION_KANTO: done = gSaveBlock2Ptr->kantoIntroDone; break;
    case REGION_JOHTO: done = gSaveBlock2Ptr->johtoIntroDone; break;
    case REGION_HOENN: done = gSaveBlock2Ptr->hoennIntroDone; break;
    default:           done = TRUE; break;
    }
    VarSet(VAR_REGION_ARRIVAL, done ? 0 : 1);
}

// D3 arrival: mark the current region's first-visit intro complete (set by the arrival scene).
void RegionHub_ScrSetIntroDone(struct ScriptContext *ctx)
{
    switch (GetCurrentRegion())
    {
    case REGION_KANTO: gSaveBlock2Ptr->kantoIntroDone = TRUE; break;
    case REGION_JOHTO: gSaveBlock2Ptr->johtoIntroDone = TRUE; break;
    case REGION_HOENN: gSaveBlock2Ptr->hoennIntroDone = TRUE; break;
    default: break;
    }
}

// D5: in the hub gate (AFTER ScrEnterRegion set gCurrentRegion to the TARGET), report whether
// that target region's first-visit intro is already done -> VAR_RESULT. The gate then warps to
// the region's access point (return) vs its start town (first visit). Uses gCurrentRegion (the
// explicit target), NOT the map-derived GetCurrentRegion() which still reads the hub here.
void RegionHub_ScrTargetIntroDone(struct ScriptContext *ctx)
{
    bool8 done;

    switch (gCurrentRegion)
    {
    case REGION_KANTO: done = gSaveBlock2Ptr->kantoIntroDone; break;
    case REGION_JOHTO: done = gSaveBlock2Ptr->johtoIntroDone; break;
    case REGION_HOENN: done = gSaveBlock2Ptr->hoennIntroDone; break;
    default:           done = FALSE; break;
    }
    gSpecialVar_Result = done;
}

// World-tour board (R8). Counts the player's gym badges across all three regions' badge
// banks (8 each, set per-region by K9) and exposes them to the hub board script:
//   VAR_0x8000 = total /24, VAR_0x8001 = Hoenn, VAR_0x8002 = Kanto, VAR_0x8003 = Johto.
// The grand 24-badge tournament is a future item; this is a read-only progress report.
void RegionHub_ScrCountWorldTourBadges(struct ScriptContext *ctx)
{
    u8 i, hoenn = 0, kanto = 0, johto = 0;

    for (i = 0; i < NUM_BADGES; i++)
    {
        if (HasBadge(REGION_HOENN, i))
            hoenn++;
        if (HasBadge(REGION_KANTO, i))
            kanto++;
        if (HasBadge(REGION_JOHTO, i))
            johto++;
    }

    gSpecialVar_0x8000 = hoenn + kanto + johto;
    gSpecialVar_0x8001 = hoenn;
    gSpecialVar_0x8002 = kanto;
    gSpecialVar_0x8003 = johto;
}

// Sky Charm give-gate (F1). The World Transit keeper only hands over the overworld
// free-flight charm once the player can actually FLY: they must hold the Fly HM AND
// have earned a region's Fly badge. The badge check mirrors the USE gate exactly
// (IsFieldMoveUnlocked_Fly in field_move.c: Kanto Thunder = idx 2, Johto Mineral /
// Hoenn Feather = idx 5). VAR_RESULT = TRUE only when both conditions hold.
void RegionHub_ScrCanFly(struct ScriptContext *ctx)
{
    bool32 hasFlyBadge = HasBadge(REGION_KANTO, 2)   // FLAG_KANTO_BADGE_3
                      || HasBadge(REGION_JOHTO, 5)   // FLAG_JOHTO_BADGE_6
                      || HasBadge(REGION_HOENN, 5);  // FLAG_BADGE06_GET

    gSpecialVar_Result = (CheckBagHasItem(ITEM_HM_FLY, 1) && hasFlyBadge) ? TRUE : FALSE;
}

// Region-switch: box the player's entire party into the global PC. The party is fully
// retrievable later; obedience while it is out is enforced by the CURRENT region's badges
// (see battle_util.c). Each present mon is copied via CopyMonToPC then cleared; if the PC
// fills up mid-transfer the remaining mons stay in the party (partial deposit).
// CalculatePlayerPartyCount() resyncs the count afterward (CompactPartySlots does not).
void DepositPartyToPC(void)
{
    u8 i;

    for (i = 0; i < PARTY_SIZE; i++)
    {
        struct Pokemon *mon = &gParties[B_TRAINER_PLAYER][i];

        if (GetMonData(mon, MON_DATA_SPECIES) == SPECIES_NONE)
            continue;
        // Confirm the PC has a free slot BEFORE stripping mail, so a mon that can't be deposited
        // keeps BOTH its slot and its held mail (stripping first could discard mail on a full PC).
        if (CountAllStorageMons() >= TOTAL_BOXES_COUNT * IN_BOX_COUNT)
            break; // PC full -> leave the rest (mail intact) in the party
        // A boxed mon can't carry mail: CopyMonToPC copies only the BoxPokemon, so the mon's
        // gSaveBlock1.mail[] slot would be orphaned (and later reused -> dup). Move any held mail
        // to the PC mailbox first (retrievable), falling back to discarding it only if the mailbox
        // is full - never leave it dangling. (deep-review task 23)
        if (MonHasMail(mon) && TakeMailFromMonAndSave(mon) == MAIL_NONE)
            TakeMailFromMon(mon);
        if (CopyMonToPC(mon) != MON_GIVEN_TO_PC)
            break; // PC full -> leave the rest in the party
        ZeroMonData(mon);
    }
    CompactPartySlots();
    CalculatePlayerPartyCount();
}

// TRUE once the player has cleared at least n regions' leagues. Per-region champion flags are
// set by each region's Hall of Fame (C1). Drives the D6 PC-2F hub warp-pad unlock (2 regions).
bool8 IsNRegionChampion(u8 n)
{
    u8 count = 0;

    if (FlagGet(FLAG_KANTO_CHAMPION))
        count++;
    if (FlagGet(FLAG_JOHTO_CHAMPION))
        count++;
    if (FlagGet(FLAG_HOENN_CHAMPION))
        count++;
    return count >= n;
}

// D6: PokeCenter-2F World Transit pad gate. VAR_RESULT = has the player cleared >= 2 regions'
// leagues; if so the pad warps straight to the hub, bypassing the trek to a region access point.
void RegionHub_ScrIsTwoRegionChampion(struct ScriptContext *ctx)
{
    gSpecialVar_Result = IsNRegionChampion(2);
}

// Safari exit routing: VAR_RESULT = is the current map in Kanto. The shared safari exit
// scripts route at runtime (their old #if IS_FRLG branches always compiled to the Hoenn
// path in this merged build, dumping Kanto players at Route 121).
void ScrIsCurrentRegionKanto(struct ScriptContext *ctx)
{
    gSpecialVar_Result = (GetCurrentRegion() == REGION_KANTO);
}

// World Championship gate: VAR_RESULT = has the player cleared all three regions' leagues.
// Used by the Championship Registrar to unlock the cross-region champions bracket.
void RegionHub_ScrIsThreeRegionChampion(struct ScriptContext *ctx)
{
    gSpecialVar_Result = IsNRegionChampion(3);
}

// Battle Frontier access gate: VAR_RESULT = has the player cleared at least one region's league.
void RegionHub_ScrIsAnyRegionChampion(struct ScriptContext *ctx)
{
    gSpecialVar_Result = IsNRegionChampion(1);
}

// Dex reward NPC: VAR_RESULT = species owned (caught) in the National Dex. No script
// special exposes this, so the reward researcher reads it here. u16 result holds it fine.
void RegionHub_ScrGetCaughtCount(struct ScriptContext *ctx)
{
    gSpecialVar_Result = GetNationalPokedexCount(FLAG_GET_CAUGHT);
}

// Dex reward NPC tier 3 gate: VAR_RESULT = is the National Dex complete. Uses the same
// HasAllMons() test the diploma runs (src/diploma.c), so "complete" matches the diploma.
void RegionHub_ScrHasCompletedDex(struct ScriptContext *ctx)
{
    gSpecialVar_Result = HasAllMons();
}

// The Kanto champion + badge flags live just ABOVE the daily-flag block that ClearDailyFlags()
// wipes on every RTC rollover (DAILY_FLAGS_START..DAILY_FLAGS_END). This margin was breached once
// before (see region_flags.h) when the Johto trainer port slid DAILY_FLAGS_END up. Fail the build
// instead of silently wiping the player's Kanto badges/championship if a future count bump reopens
// that gap.
STATIC_ASSERT(FLAG_KANTO_CHAMPION > DAILY_FLAGS_END, KantoChampionFlagInsideDailyClearRange);
STATIC_ASSERT(FLAG_KANTO_BADGE(0) > DAILY_FLAGS_END, KantoBadgeFlagsInsideDailyClearRange);
