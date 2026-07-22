# Test Plan — Battle Frontier & Gym / League Rematches

Covers the **Battle Frontier** (all 7 facilities + the fork's World Championship Dome mode) and the
**gym leader / Elite Four / Champion rematch** system (Feature C difficulty tiers).

Read **`Testing/BizHawkTesting.md`** first — it has the harness, save-safety protocol, debug-menu
indices and spinner mechanics every case below depends on.

Facts here were derived from the source and **adversarially verified** (57 claims confirmed,
3 refuted). Claims marked ⚠ **UNVERIFIED AT RUNTIME** are static source reads only — that is
precisely why this plan exists.

---

## 0. How to read this plan

Each case gives **Setup → Steps → Expected → Evidence to capture**. Expected values are the
*intended* behavior; a mismatch is either a bug or a harness error — see §7 before filing.

**Priority:** P1 = most likely broken / highest blast radius. Do P1 first.

---

## 1. Test rig setup (once)

1. Build: `PATH="$HOME/.local/arm-none-eabi/usr/bin:$PATH" make -j12`.
2. **Isolate**: copy the ROM + a save to `FrTest.gba` / `FrTest.SaveRAM`. Never test on
   `pokemonworld.gba` — BizHawk flushes SaveRAM on exit.
3. Re-derive addresses from **this build's** `pokemonworld.map`.
4. Verify the emulator's printed MD5 matches your build before trusting any result.

### Key flags / vars

| Name | Value | Notes |
|---|---|---|
| `FLAG_KANTO_CHAMPION` | `0xA48` = 2632 | debug flag editor reachable |
| `FLAG_JOHTO_CHAMPION` | `0xA49` = 2633 | |
| `FLAG_HOENN_CHAMPION` | `0xA4A` = 2634 | |
| `FLAG_WORLD_CHAMPION` | `0xD73` | WC reward title |
| `VAR_DIFFICULTY` | `0x40F8` | `0`=EASY `1`=NORMAL `2`=HARD |
| `VAR_WORLD_CHAMPIONSHIP_MODE` | `0x40F7` | **leak hazard** — must be 0 outside a WC run |
| `VAR_FRONTIER_FACILITY` | — | 1 = DOME |
| `VAR_FRONTIER_BATTLE_MODE` | `0x40CE` | 0=SINGLES 1=DOUBLES 2=MULTIS 3=LINK_MULTIS |

> ⚠ **Kanto trainer defeat flags (`FLAG_KANTO_TRAINER_BASE` = `0x6400`, 640 slots) and the Johto
> bank (`0x6000`) are ABOVE the debug flag editor's cap (`FLAGS_COUNT-1` = `0x102F`).** You
> **cannot** set/clear a gym leader's defeat flag from the editor. Use **Trainers… → Try Battle**
> (same difficulty-driven party path) or a Lua RAM watch instead.

### Map coordinates

All Frontier maps live in **map group 26** (`gMapGroup_SpecialArea`, shared with Safari Zone /
Navel Rock — **there is no "BattleFrontier" group**).

| Location | group/num |
|---|---|
| RegionHub (Frontier attendant at **(4,2)**) | 100 / 0 |
| Reception Gate | 26 / 50 |
| Outside West / East | 26 / 4, 26 / 14 |
| Battle Tower lobby | 26 / 5 |
| Battle Dome lobby (registrar Maniac at **(8,14)**) | 26 / 18 |
| Battle Palace lobby | 26 / 22 |
| Battle Pyramid lobby | 26 / 25 |
| Battle Arena lobby | 26 / 28 |
| Battle Factory lobby | 26 / 31 |
| Battle Pike lobby | 26 / 34 |

---

# PART A — Battle Frontier

## A1. Access gate  (P1)

The Frontier is reached from the **RegionHub attendant at (4,2)**, gated on
`RegionHub_ScrIsAnyRegionChampion` → **`IsNRegionChampion(1)`**.

> **The gate is ONE region cleared, not three.** `IsNRegionChampion(3)` gates the *World
> Championship* inside the Dome lobby — a different thing. Do not conflate them.

**A1.1 — Locked with zero champion flags**
- Setup: hub (100/0); clear `0xA48`, `0xA49`, `0xA4A`.
- Steps: walk to (4,2), talk.
- Expected: `RegionHub_Text_FrontierLocked` ("…conquered at least one region's POKéMON LEAGUE"); **no warp**.
- Evidence: screenshot of the refusal + player still at grp 100.

**A1.2 — ONE champion flag unlocks it** (proves the gate is 1, not 3)
- Setup: set **only** `0xA48`; leave `0xA49`/`0xA4A` clear.
- Steps: talk to (4,2), answer YES.
- Expected: `RegionHub_Text_TravelFrontier` Yes/No → warps to Reception Gate (26/50).
  **Party is NOT boxed** (this attendant deliberately does *not* call `SetCurrentRegion` and does
  *not* deposit the party, unlike the three region attendants).
- Evidence: `gPartiesCount` **unchanged** across the warp; grp/num after warp.

**A1.3 — Same for Johto-only and Hoenn-only**
- Repeat A1.2 with only `0xA49`, then only `0xA4A`. All three must unlock.

**A1.4 — First entry grants the Frontier Pass**
- Setup: `VAR_HAS_ENTERED_BATTLE_FRONTIER` = 0; clear `FLAG_SYS_FRONTIER_PASS`.
- Steps: warp to 26/50, step onto the ON_FRAME trigger.
- Expected: Scott cutscene; `FLAG_SYS_FRONTIER_PASS` set; `VAR_HAS_ENTERED_BATTLE_FRONTIER` 0→1;
  `FLAG_LANDMARK_BATTLE_FRONTIER` set. **Does not replay** on re-entry.
- Evidence: re-enter and confirm no cutscene.

## A2. Facility reachability  (P1)

**A2.1 — All 7 lobbies load and start a challenge**
- Steps: warp to each of 26/{5,18,22,25,28,31,34}; talk to the attendant.
- Expected: each loads; mode choice → `MULTI_LEVEL_MODE` (Lv50 / Open) at screen (17,6) →
  party select requests **exactly 3** mons.
- Evidence: screenshot per lobby.
- Note: no facility is disabled/stubbed/flag-hidden in this fork (no `FREE_BATTLE_FRONTIER`).

**A2.2 — Walk-in routes work**
- Steps: from OutsideWest (26/4) and OutsideEast (26/14), walk to each lobby door.
- Expected: no blocked doors, no missing warps.

## A3. Battle rules & formats  (P2)

**A3.1 — Mode availability per facility**

| Facility | Expected modes |
|---|---|
| Tower | Singles, Doubles, **Multis, Link Multis** |
| Dome, Palace, Factory | Singles, Doubles |
| Arena, Pike, Pyramid | **Singles only** |

- Evidence: read `VAR_FRONTIER_BATTLE_MODE` (`0x40CE`) after choosing each attendant.

**A3.2 — Party size is 3**
- Expected: `FRONTIER_PARTY_SIZE` = 3 everywhere; picking fewer blocks confirm.

**A3.3 — Duplicate species/items rejected**  (P1 — *known to bite*)
- Setup: 3× the **same species** (e.g. 3 Jirachi).
- Steps: register at any lobby.
- Expected: `frontier_checkineligible` → `VAR_0x8004` = TRUE → *NotEnoughValidMons*; **registration
  self-cancels**.
- Why P1: this silently ate a real test run — registration appeared to "do nothing".
- Then: repeat with **3 distinct species** → registration proceeds.

## A4. Level modes  (P1)

**A4.1 — Lv50 mode**
- Expected: player entry capped at 50 (`FRONTIER_MAX_LEVEL_50`); **enemies fixed at 50**.

**A4.2 — Open Level has NO minimum for the player** ⚠ *counter-intuitive — verify carefully*
- Setup: party of 3 **distinct** mons at **Lv5**.
- Steps: enter Tower (26/5) → Open Level.
- Expected: **entry is ALLOWED** (Open Level caps at `MAX_LEVEL`, no minimum).
  `FRONTIER_MIN_LEVEL_OPEN` (60) is **not** a player gate — it floors the **ENEMY** level:
  `GetFrontierEnemyMonLevel()` = highest level in your party, raised to 60 if lower
  (`src/frontier_util.c:3282`). So a Lv5 party faces **Lv60** opponents.
- Evidence: `gBattleMons` enemy levels == 60.
- Note: an earlier research pass claimed "Open Level rejects below 60" — **that is wrong**; it was
  refuted against source. If you observe a rejection, that IS a finding.

**A4.3 — Open Level scales to your highest**
- Setup: party topping at Lv80.
- Expected: enemies at 80 (not 60, not 50).

## A5. Rewards / BP / streaks  (P2)

**A5.1 — BP divisor differs per facility** ⚠
- Expected `challengeNum` = streak **/ 7** for Tower/Palace/Arena/Factory/Pyramid,
  **/ 14** for Pike (`NUM_PIKE_ROOMS`), and **no divisor at all** for **Dome**.
- Steps: set `pikeWinStreaks[0]`=28 and `domeWinStreaks[0][0]`=4; complete a challenge at each.
- Expected: Dome streak 4 indexes a **much higher** BP row than Pike streak 4.
- Evidence: `battlePoints` (SaveBlock2 `0xEB8`) before/after vs `sBattlePointAwards`.

**A5.2 — BP saturates, never overflows**
- Setup: `battlePoints` = 9995 → complete a BP-awarding challenge.
- Expected: clamps to **9999** (`MAX_BATTLE_FRONTIER_POINTS`).

**A5.3 — Symbols drive brain progression**
- Setup: set `FLAG_SYS_TOWER_SILVER` only.
- Expected: `GetPlayerSymbolCountForFacility(TOWER)` = 1 → next brain uses the **gold** threshold (70), not silver (35).
- ⚠ Symbol flags are addressed by pointer arithmetic (`FLAG_SYS_TOWER_SILVER + facility*2`) — the
  14 symbol flags **must stay contiguous and correctly ordered**. Any flag insertion in that block
  silently corrupts every facility's symbol lookup. Worth a static re-check after any flag edit.

## A6. Frontier Brains  (P2)

**A6.1 — Brain appears at an EXACT streak, not ≥** ⚠ *high-surprise*
- Setup: 0 tower symbols; `towerWinStreaks[0][0]` = **34** (34 + 1 == 35 silver threshold).
- Expected: **Anabel appears**. At raw streak **35** or **40** she does **NOT** — the test is
  `winStreak == threshold` (`src/frontier_util.c:1760/1767/1770`), not `>=`. Overshooting skips the
  brain entirely until the next gold-interval multiple.
- Why it matters: a player who overshoots can silently never meet the brain.

**A6.2 — Brain never appears in Doubles**
- Setup: `towerWinStreaks[1][0]` = 35, `VAR_FRONTIER_BATTLE_MODE` = 1.
- Expected: `GetFrontierBrainStatus` = `FRONTIER_BRAIN_NOT_READY`.

**A6.3 — Brain win grants +10 BP over the table**
- Expected: `battlePoints` += `sBattlePointAwards[...]` **+ 10**.

## A7. Challenge lifecycle  (P2)

**A7.1 — Declining the save prompt cancels cleanly**
- Steps: start Singles Lv50, pick 3, answer **NO** to the save prompt.
- Expected: `LoadPlayerParty` restores the **original party order**; player remains in the lobby;
  no streak/BP change.

**A7.2 — Party is restored after a challenge**
- Expected: `SavePlayerParty` / `LoadPlayerParty` round-trips; box/party unchanged.

# A8. World Championship (Dome)  (P1 — fork-specific, least tested)

Registrar = repurposed **Maniac, localId 5, at (8,14)** in the Dome lobby (26/18),
`MOVEMENT_TYPE_WANDER_AROUND` range 1.

**A8.1 — Locked below 3 champion flags**
- Setup: set only `0xA48` + `0xA49` (Hoenn clear).
- Expected: `Text_ChampionshipLocked`; `VAR_WORLD_CHAMPIONSHIP_MODE` stays **0**.

**A8.2 — Unlocks with all 3; seeds the fixed bracket**
- Setup: set `0xA48`, `0xA49`, `0xA4A`. Party = **3 distinct** Lv100 mons (see A3.3!).
- Steps: talk to the Maniac at (8,14) → YES → challenge flow → party select → save → enter.
- Expected: `Text_ChampionshipOffer`; accepting sets `VAR_WORLD_CHAMPIONSHIP_MODE`=1,
  `VAR_FRONTIER_FACILITY`=1 (DOME), `VAR_FRONTIER_BATTLE_MODE`=0 (SINGLES).
  Bracket = player + the **fixed 15** `sChampionshipTrainerIds`.
- Evidence: read `gSaveBlock2Ptr->frontier.domeTrainers[i].trainerId` for i=1..15; **and a
  screenshot of the tourney tree** (this is the one item that still needs eyes-on).

**A8.3 — Bracket contents**
- Expected: a **TEAM ROCKET** slot (`FRONTIER_TRAINER_WC_ROCKET` = **315**, mons
  Arbok / Weezing / Wobbuffet / Victreebel / Meowth, Rocket pic/class);
  **Clair is absent** (ROCKET intentionally *replaces* her — a seed swap, not an append);
  **singles only**, never 2-v-1.

**A8.4 — RED is always the finalist**
- Expected: `FRONTIER_TRAINER_WC_RED` (**300**) occupies the finalist slot on the **opposite half**
  of the bracket from `TRAINER_PLAYER`.
- Evidence: tourney tree screenshot + `DOME_TRAINERS` dump.

**A8.5 — Reward: bag-full withholds the title** ⚠ *intentional (the bag-full reclaim idiom)*
- Setup: **fill the Items pocket**, then win the Championship.
- Expected: `giveitem ITEM_GOLD_BOTTLE_CAP` fails → branches to `ChampionshipPrizePending` →
  `Text_ChampionshipBagFull` → **`FLAG_WORLD_CHAMPION` is left UNSET** → BP still awarded.
  Re-winning with space then grants **both**.
- Evidence: `FLAG_WORLD_CHAMPION` state + BP delta in both bag states.

**A8.6 — `VAR_WORLD_CHAMPIONSHIP_MODE` must not leak**  (P1)
- Steps: manually set `0x40F7` = 1, then talk to a **normal** Dome attendant (Teala at (5,10) singles / (17,10) doubles).
- Expected: `0x40F7` reads **0** afterwards → the next normal Dome tourney uses the random pool.
- Why P1: if it sticks at 1, `InitDomeTrainers` keeps seeding the champions bracket into **normal**
  Dome runs (`src/battle_dome.c:1967`). Cleared at 4 script sites — test **every** exit path:
  win, loss, retire/quit, and Hub-Pass attempt.

**A8.7 — Hub Pass refuses during a WC run**
- Steps: start a WC run, advance to the pre-battle room (26/20), Bag → Hub Pass.
- Expected: refused (`CannotUseHubReturnHere()` includes `VAR_WORLD_CHAMPIONSHIP_MODE != 0`) —
  so the var can't be stranded at 1 by warping out.

**A8.8 — Championship is rematchable**
- Expected: an existing champion (`FLAG_WORLD_CHAMPION` set) skips the prize and goes straight to BP.

---

# PART B — Gym / League Rematches

## B0. The model (get this right first)

> **The split is LEAGUE vs GYM — NOT Hoenn vs Johto/Kanto.**
>
> - **All 24 GYMS, in all three regions** (incl. Johto `TRAINER_FALKNER_1` and Kanto
>   `TRAINER_LEADER_BROCK`) reuse the **SAME first-run trainer ID** and pick the rematch team purely
>   via **`VAR_DIFFICULTY`**.
> - **LEAGUES:** Hoenn's E4/Champion also reuse one ID + difficulty, but **Johto's and Kanto's
>   E4/Champion use separate `_2` rematch IDs**, and their HARD blocks live **only on the `_2` IDs**
>   (the first-run league IDs have no HARD block at all).

Rematch **availability** is gated on the **region champion FLAG only** — not badge count, not
`VAR_DIFFICULTY`.

`VAR_DIFFICULTY` is a **single global var**, but Hard teams exist in all 3 regions, so
`SyncDifficultyForRegion()` (`src/region_switch.c:56-59`) **rewrites it from the ACTIVE region's
champion flag on every region entry**. That is what stops HARD leaking across regions.

## B1. Gym rematches  (P1)

**B1.1 — Hoenn gym rematch (representative: Roxanne)**
- Setup: `FLAG_HOENN_CHAMPION` + `FLAG_RECEIVED_TM_ROCK_TOMB`; `VAR_DIFFICULTY` = **2**;
  warp `RustboroCity_Gym`.
- Steps: talk to Roxanne.
- Expected: `RematchAsk` YES/NO prompt; accepting fights the **HARD** team off the **same**
  `TRAINER_ROXANNE_1` ID.
- Then set `VAR_DIFFICULTY` = 1 and re-battle → **NORMAL** team, same ID, no script change.

**B1.2 — Johto gym rematch (Falkner)**
- Setup: `FLAG_JOHTO_CHAMPION` (`0xA49`); `VAR_DIFFICULTY` = 2.
- Expected: HARD team **Skarmory 58 / Noctowl 58 / Aerodactyl 60 / Murkrow 62 / Pidgeot 65** —
  *not* the 2-mon Lv8-11 first-run team.

**B1.3 — Kanto gym rematch (Brock)**  ⚠ *has a trap*
- Setup: `FLAG_KANTO_CHAMPION` (`0xA48`) **and `FLAG_GOT_TM39_FROM_BROCK`**.
- 🪤 `PewterCity_Gym_Frlg/scripts.inc:7` checks `goto_if_unset FLAG_GOT_TM39_FROM_BROCK` **before**
  the champion gate at :8 — a save that skipped the TM pickup will **never** show Brock's rematch
  prompt no matter what champion flags are set. Do not report this as a rematch bug.
- Expected: with only `FLAG_JOHTO_CHAMPION` set → plain post-battle text, **no** prompt;
  with `FLAG_KANTO_CHAMPION` → prompt + HARD team.

**B1.4 — All 24 gyms serve a HARD team**
- Expected: **every HARD gym ace is Lv65** (uniform across all 24). Any gym whose rematch ace
  isn't 65 is a data gap.
- Sweep all 24 via **Trainers… → Try Battle** (remember: you cannot clear their defeat flags).

**B1.5 — Naming-pattern exceptions (don't miss these two)**
- `PetalburgCity_Gym` uses **`PetalburgCity_Gym_EventScript_NormanOfferRematch`** (breaks the
  `*_EventScript_OfferRematch` pattern) — reachable from **both** the post-battle path and the
  Match Call path; test both. HARD = 6 mons Lv59-65, ace **Slaking Lv65 @ Choice Band**.
- `MossdeepCity_Gym` continuation is **`EventScript_RematchWon`**.

**B1.6 — Mossdeep is a DOUBLE rematch and needs 2 usable mons**
- Setup: `FLAG_HOENN_CHAMPION` + `FLAG_RECEIVED_TM_CALM_MIND`, `VAR_DIFFICULTY`=2, **1-mon party**.
- Expected: aborts to `RematchNeedTwoMons`, **no battle**. With 2+ usable mons → double battle,
  victory routes through `EventScript_RematchWon`.
- Note: contrast with the Jessie & James ambush, which deliberately allows a 1-mon forced double.

## B2. League rematches  (P1)

**B2.1 — Johto E4 uses the `_2` IDs with HARD parties**
- Setup: `FLAG_JOHTO_CHAMPION` + `VAR_DIFFICULTY` = 2 → `JohtoPokemonLeague_WillsRoom`.
- Expected: `goto_if_set FLAG_JOHTO_CHAMPION` (`scripts.inc:57`) routes to `WillRematch` (:66);
  Will fields the **6-mon HARD** team topping at **Xatu 73** (not the Lv66-68 NORMAL `_2` team, not
  the Lv48-50 `WILL_1` team). Chain through to **Lance: ace Dragonite 78** (HARD 70-78).

**B2.2 — Kanto E4 (HARD 70-76)**
- Expected: `ELITE_FOUR_*_2` HARD parties, 70-76.

**B2.3 — Kanto Champion rematch is starter-matched**
- Setup: `FLAG_KANTO_CHAMPION` + `VAR_DIFFICULTY`=2 → `PokemonLeague_ChampionsRoom_Frlg`.
- Expected: `CHAMPION_REMATCH_{SQUIRTLE|BULBASAUR|CHARMANDER}` selected by the player's starter;
  ace **Blastoise / Venusaur / Charizard @ 80** over a shared core
  **Heracross 77 / Alakazam 78 / Tyranitar 78** (HARD 77-80).
- Test all three starters.

**B2.4 — Hoenn league reuses one ID + difficulty**
- Expected: Hoenn E4/Wallace/Steven have Normal + `Difficulty: Hard` blocks under the **same** ID.

**B2.5 — The NORMAL `_2` parties are dead data**
- Expected: no reachable path battles a `_2` ID while `VAR_DIFFICULTY != HARD`.
- Only reachable by forcing an inconsistent state (champion flag ON + `VAR_DIFFICULTY`=1 without
  leaving the region). **Do not delete them** — `battle_net.inc:16-17` documents them as an
  intentional harmless fallback.

## B3. Difficulty containment  (P1 — highest regression risk)

**B3.1 — HARD must not leak across regions**
- Setup: `FLAG_HOENN_CHAMPION` + `VAR_DIFFICULTY`=2, `FLAG_JOHTO_CHAMPION` **clear**.
- Steps: travel to Johto via the RegionHub clerk (`SetCurrentRegion` → `SyncDifficultyForRegion`).
- Expected: on arrival `VAR_DIFFICULTY` is rewritten to **1**; Falkner fights his **NORMAL**
  first-run team. Returning to Hoenn flips it back to **2**.
- Evidence: read `0x40F8` immediately after each region entry.

**B3.2 — Continue re-syncs the tier**
- Steps: save in Rustboro as Hoenn champion → **soft reset (A+B+Start+Select)** → Continue → Roxanne.
- Expected: `ResyncCurrentRegionFromMap` (`src/overworld.c:2325`) re-derives the region and
  re-applies `VAR_DIFFICULTY`=2 (EWRAM `gCurrentRegion` zeroes on soft reset), so Roxanne is still HARD.

**B3.3 — A champion flag alone does NOT flip the var** 🪤
- `SyncDifficultyForRegion` runs **only** on region entry (`SetCurrentRegion` /
  `ResyncCurrentRegionFromMap`). A debug-set champion flag unlocks the *dialogue branch* but leaves
  `VAR_DIFFICULTY` untouched → you'd fight the **NORMAL** team and might wrongly file a bug.
- **When testing, always either set `VAR_DIFFICULTY` manually or warp out and back in.**

## B4. Fallback semantics  (P2)

**B4.1 — Trainer with no HARD block falls back to NORMAL**
- Setup: `VAR_DIFFICULTY`=2 → battle `TRAINER_JOSH` (`RustboroCity_Gym/scripts.inc:75`), an ordinary
  trainer with no Hard block.
- Expected: ordinary team, unchanged. `GetTrainerDifficultyLevel()` returns NORMAL whenever
  `gTrainers[difficulty][id].party == NULL`.
- Only **27** trainers in `trainers.party` + **15** in `trainers_frlg.party` have HARD blocks.

**B4.2 — EASY tier degrades to NORMAL**
- Setup: `VAR_DIFFICULTY` = **0**.
- Expected: identical to NORMAL (the EASY tier has **0** blocks in either file → NULL-party fallback).

## B5. Hall of Fame sets the tier  (P2)

**B5.1 — Each region's HoF sets `VAR_DIFFICULTY = DIFFICULTY_HARD`**
- Hoenn: `data/scripts/hall_of_fame.inc:4-5` sets `FLAG_HOENN_CHAMPION` + `VAR_DIFFICULTY`=HARD in
  adjacent lines.
- Expected: first clear stays NORMAL; the rematch is HARD.

**B5.2 — Johto HoF branches on the GLOBAL `FLAG_IS_CHAMPION`** 🪤
- A player who became champion of another region first takes the **rematch branch on their FIRST
  Johto clear**. Both branches must set `FLAG_JOHTO_CHAMPION`.
- ⚠ Johto's HoF sets **both** `FLAG_IS_KANTO_CHAMPION` and `FLAG_JOHTO_CHAMPION`
  (`JohtoPokemonLeague_HallOfFame/scripts.inc:86,90`). `FLAG_IS_KANTO_CHAMPION` is a **legacy HnS
  story flag and is NOT the same thing as `FLAG_KANTO_CHAMPION` (0xA48)** — do not confuse them.
- Test: clear Hoenn first, then clear Johto **for the first time** → confirm `FLAG_JOHTO_CHAMPION`
  ends set and the first clear isn't mistakenly treated as a rematch.

## B6. Battle Net hook  (LIVE — issue #5 P1)

`data/scripts/battle_net.inc` is now the **live reward routine** (wired at
`data/event_scripts.s:1330`, called from all 41 rematch victory points with
`VAR_0x8004` = the defeated trainer ID). `TryBattleNetRematchReward` self-gates on
`DIFFICULTY_HARD` (the 5 Hoenn league sites also fire on first clears — those stay no-ops).

**B6.1 — Reward contract on a HARD rematch win**
- Expected per qualifying win: **Shards every win** (leaders 1, E4/Champion 2), guarded by
  `checkitemspace` — with a full Items pocket the payout is announced as **forfeited** (no
  silent loss), while the win still records. The **signature Mega Stone** drops once per
  leader; a failed stone give leaves its guard flag clear for **reclaim on a later win**.
  The Kanto champion trio pays a **double stone** (Mewtwonite X + Y).
- Deeper coverage lives in the scripted suites: `_pwtest/BnetP1Reward.lua`,
  `_pwtest/BnetKanto.lua`, `_pwtest/BnetStonePending.lua` (gitignored scratch).
- Non-HARD sites: winning a first clear through the same hook must reward nothing.

---

## 6. Priority order

1. **A8** World Championship (fork-specific, never fully eyes-on verified — the bracket render is the single biggest gap)
2. **B3** Difficulty containment (a leak silently breaks every region's balance)
3. **A8.6** `VAR_WORLD_CHAMPIONSHIP_MODE` leak (poisons *normal* Dome runs)
4. **A1** Frontier access gate (1-region, and the party-not-boxed behavior)
5. **B1/B2** Gym + league rematch teams (24 gyms + 3 leagues = the bulk of new data)
6. **A4** Level modes (the Open-Level enemy floor is counter-intuitive)
7. **A3.3** duplicate-species rejection (known to silently eat registrations)
8. **A5/A6** BP, streaks, brains (divisor + exact-equality quirks)
9. **B6** Battle Net rewards (covered by the scripted `_pwtest` suites)

## 7. Known traps — rule these out before filing a bug

| Symptom | Likely cause |
|---|---|
| Rematch shows NORMAL team | `VAR_DIFFICULTY` not synced — champion flag alone doesn't flip it (B3.3) |
| Brock never offers a rematch | `FLAG_GOT_TM39_FROM_BROCK` unset — checked *before* the champion gate |
| Frontier registration "does nothing" | duplicate species in party (A3.3) |
| Can't set a gym leader's defeat flag | Kanto `0x6400` / Johto `0x6000` banks are above the editor cap `0x102F` |
| Can't talk to the Dome registrar | wandering NPC + **a follower steals the A-press** ("X is suddenly playful") |
| Battle never ends under pure-A | Wobbuffet Counter/Mirror Coat stall — prove the mechanic via flags instead |
| Grep finds no `FRONTIER_LVL_*` | they're **enum members** in `include/constants/global.h:158`, not `#define`s |
| Grep returns the wrong trainer ID | `opponents_frlg.h` defines every Kanto ID **twice** (`#if ALL_REGIONS` vs `#else`) |
| Difficulty block looks unlabelled | blocks are **positional**: NORMAL = *absence* of a `Difficulty:` line |

## 8. Stale comments — FIXED 2026-07-17

All four were comment-only accuracy bugs (no functional change); each was verified against source
before correcting, and the build stayed green.

| Site | Was | Now |
|---|---|---|
| `BattleFrontier_BattleDomeLobby/scripts.inc:54` | "permanent title (granted first, bag-independent)" — **contradicted the code** | states the title is granted **only if the Cap is received**; bag-full leaves it unset for reclaim (see A8.5) |
| `RegionHub/scripts.inc:131` | "Gated OPEN for now; two-tier unlock TBD" | states the real gate: `IsNRegionChampion(1)`, and that the 3-region gate is the WC's |
| `include/constants/region_flags.h:34` | "624 used → 16 spare" | **631 used / 9 spare**, expressed as the formula `TRAINERS_COUNT - KANTO_TRAINER_ID_OFFSET` so it can't silently rot again |
| `include/constants/opponents_frlg.h:7` | Kanto ids "1097..1719" | `1097..TRAINERS_COUNT-1 = 1726` (was stale by 7 — Jessie & James were appended after it was written) |

The A8.5 behavior itself is **unchanged and intentional** (the bag-full reclaim idiom) — only the
comment lied about it. A8.5 remains a valid test case.
