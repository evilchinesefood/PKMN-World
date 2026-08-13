# Overworld test harness — field guide (PKMN-World)

How to drive this ROM headlessly and get evidence out of it. Written for anyone picking the
project back up cold.

> ## BizHawk is not used. The suites run on a patched headless mGBA.
>
> This file is still called `BizHawkTesting.md` for link stability, but **nothing in the repo
> launches BizHawk or EmuHawk, and no BizHawk workflow is supported.** Upstream ships Windows and
> Linux builds only — there is no macOS build, no Homebrew formula, no Apple Silicon target.
>
> Everything runs through `Testing/mgba-run.sh` / `Testing/run-all.sh` against a purpose-built
> `mgba-headless`, with `Testing/lua/mgba_shim.lua` supplying the EmuHawk Lua API the suites were
> originally written against. Build the emulator once: **[`Testing/mgba/README.md`](mgba/README.md)**.
>
> The BizHawk vocabulary survives inside the harness (`memory.read_u32_le`, `joypad.set`,
> `client.screenshot`) because the shim implements it. That is an API shape, not a supported
> emulator.

Companion docs:

- **[`Testing/lua/MANIFEST.md`](lua/MANIFEST.md)** — what each suite proves, the fixtures, and how
  to run the whole battery.
- **[`Testing/mgba/README.md`](mgba/README.md)** — building `mgba-headless`, the patch, determinism.
- **[`BattleFrontierRematchTestPlan.md`](BattleFrontierRematchTestPlan.md)** — a manual test plan
  for the Battle Frontier and the rematch system (no automated suite covers it).

Everything below was verified empirically against real runs. Where a technique has a known failure
mode it is called out — most of the pain in this project has come from harness quirks, not game bugs.

---

## 1. Build, then test the build you think you're testing

```bash
cd ~/Github/PKMN-World
make modern -j$(sysctl -n hw.ncpu)          # -> pokemonworld.gba (+ Testing/lua/symbols.lua)
```

`make modern` → `all` → `rom`, and `rom: $(ROM) $(LUA_SYMBOLS)` — so a normal build also
regenerates `Testing/lua/symbols.lua`. You do not need `make symbols` separately.
(Some in-tree comments in `lib.lua` and the generated `symbols.lua` still say a plain build leaves
symbols stale. That was true before the prerequisite was added; the Makefile is the authority.)

The build needs `PKG_CONFIG_PATH` pointing at Homebrew or the host graphics tools won't build —
devkitPro ships its own `pkg-config` earlier on PATH that cannot see Homebrew's libpng. See
`INSTALL.md`.

**A rebuild changes every address.** `symbols.lua` is regenerated with the ROM and every suite
reads its addresses from it, so this is handled for you — but never hardcode an address in a new
script, and never reuse a savestate across builds.

### Run one suite

```bash
Testing/mgba-run.sh Testing/lua/SmokeBoot.lua
Testing/mgba-run.sh Testing/lua/VerifyV7Migrate.lua pokemonworld.gba Testing/lua/fixtures/v7dirty.srm
```

Arguments are `<suite.lua> [rom.gba] [save.srm]`; the ROM defaults to the repo build. Exit code is
**0** pass, **1** suite failure, **2** setup error. Evidence lands in `_pwtest/` (gitignored):
`<Suite>.log`, numbered `<Suite>_NN_<step>.png` screenshots, and a `<Suite>.PASS` / `.FAIL` sentinel.

### Run the whole battery

```bash
Testing/run-all.sh                 # ~1.5 minutes for the current 20-suite list
```

Read [`lua/MANIFEST.md`](lua/MANIFEST.md) before you trust its exit code — a green sweep can still
exit non-zero for structural reasons, and that is documented there.

---

## 2. Save safety

A suite blind-presses A and Start for thousands of frames, and the shipped save profile has SAVE on
the start-menu wheel. Pointed at a real ROM/save pair, that is a live clobber path — it has
happened once already.

**`mgba-run.sh` already handles this.** It copies the ROM into a `mktemp -d` work directory under
the name `Verify1.gba`, copies any save fixture beside it as `Verify1.sav`, and deletes the
directory on exit. Anything the run writes dies with it. Two independent guards back that up:

1. **ROM/symbols binding** — `symbols.lua` records the md5 of the `.gba` it was generated from and
   `lib.new()` aborts against any other ROM. Without it the normal accident (rebuild, then launch a
   stale hand-copy) boots fine and reports every test green while exercising the *previous* build,
   because `gSaveblock3` is a fixed EWRAM symbol.
2. **Throwaway-ROM allowlist** — the ROM basename must match `^Verify`, `^MigChk` or `^FixGen`
   (`lib.lua:38`). Override deliberately with `opts.allowAnyRom = true`.

The owner's live save is `pokemonworld.gba`'s neighbour `pokemonworld.sav` at the repo root
(gitignored, untracked). `VerifyOwnerSave.lua` is the only suite that reads it. `mgba-run.sh` copies
it into the temp dir, but pass a copy anyway if you are experimenting.

> A raw `.srm` battery save is 131072 bytes and is already mGBA's `.sav` format — converting one is
> a rename. A blank save is all `0xFF`. mGBA may append a 16-byte RTC trailer to a `.sav` it wrote;
> when comparing saves, compare the first 131072 bytes (`cmp -n 131072`), not the whole file.

---

## 3. Addresses: read them from `symbols.lua`, never by hand

`Testing/GenLuaSymbols.py` reads the freshly built `pokemonworld.elf` and emits
`Testing/lua/symbols.lua` — runtime addresses, a curated ABI-fixed struct-offset table, and the
ROM's md5/sha1. It is a build artifact: **gitignored, never committed.**

```lua
local S = require("symbols")
local F = require("lib").new(require("symbols"), "MySuite")
S.gMain            -- and CB2_Overworld, gSaveBlock1Ptr, gObjectEvents, gParties, sMartInfo, ...
S.SaveBlock1.money -- ABI-fixed struct offsets
S.SaveBlock3.usmSaved
```

If you need something the table does not carry, add it to `GenLuaSymbols.py` and rebuild — do not
paste a literal into a suite. Every address in this file's history rotted within a build or two.

Useful offsets (these are structural, not addresses):

- Player position: `*gSaveBlock1Ptr + 0x00` = x, `+0x02` = y (s16). Map group `+0x04`, map num `+0x05`.
- `WarpData` is 8 bytes: `0` group, `1` num, `2` warpId, **`3` pad**, `4` x, `6` y. Reading x at
  `+3` returns the coordinate shifted a byte left (39 reads as 9984) and looks like corruption.
- Object event: byte0 bit0 = alive/active; `+0x10` = x, `+0x12` = y (s16, **= map coord + 7**);
  `invisible` is `flags1` bit 5. Stride `0x24`.
- `struct Pokemon`: level `+0x54`, hp `+0x56`, maxHP `+0x58`.

> Struct layout must be computed with the repo's **exact CFLAGS** (`-mabi=apcs-gnu` changes layout).
> Config-based guesses have been 6 bytes off. Use an `offsetof` probe compiled with the real flags —
> `Testing/mgba/README.md` has a ready-made one-liner.
>
> The annotated `/*0x1270*/`-style offset comments in `include/global.h` **have been wrong before**
> (`bag` read `0x568`, a pre-expansion value, for the whole life of the expansion). They are also
> not uniformly wrong: an `offsetof` probe confirmed `objectEventTemplates` at `0xF94` exactly as
> annotated. Probe, don't assume, in either direction.

---

## 4. Boot reliably

Use `F.boot(expectedGroup [, keepScene])` from `lib.lua`. It waits for the real overworld signal —
`gMain.callback2 == CB2_Overworld` with the low bit masked — rather than guessing at timing or using
a map-group heuristic (`grp == 0` at the title screen is a false positive that exits early), and it
re-tests the same condition after settling so a suite cannot run its assertions on the wrong map.

Two things to know:

- `boot()` fails loudly. A `BOOT FAIL (overworld=... grp=N want=M)` line usually means your
  `expectGroup` is wrong, not that the save is broken. Run a known-good suite as a control before
  blaming a fixture.
- The default post-boot cleanup calls `ensureFree()`, which **steps the player** — and a step runs
  the camera update's `TrySpawnObjectEvents`. If a suite's whole point is "nothing spawned it but
  the fix", pass `keepScene = true`.

**Never `savestate.load` across sessions.** Save blocks relocate on savestate load
(`gSaveBlock1Ptr` changes), desyncing any poke made earlier, and a `pcall` hides the failure while
the input stream drives the title screen into new-game chaos. **Write single-run scripts**:
boot → act → assert → exit.

---

## 5. Moving around

Blind hold-walking drifts. `lib.lua` gives you **coordinate-verified** stepping: `F.step(dir)`
presses until the coords actually change and then finishes the tile, returning false when blocked.
`F.leg` / `F.route` build paths on top, and `F.warpTo` warps through the debug menu and verifies
arrival.

Three traps that have each cost a run:

- **`F.warpTo` tests group+map only** (`lib.lua:362`). Called while already on the target map it
  returns *true* having warped nobody — **and leaves the debug menu open**, which then silently eats
  every later step. Always warp to a different map than the one you are on.
- **`F.step` is a coordinate-CHANGE detector.** A cutscene `applymovement` also changes coordinates,
  so a "press B until a step lands" loop breaks out mid-cutscene and samples the world hundreds of
  frames too early. One suite scored a full 17/17 against the *unfixed* ROM this way.
- **`F.ensureFree()` / `F.dismiss()` prove control with a Left/Right step**, so they always report
  "stuck" in a one-tile-wide corridor and they **ride an escalator** if you call them next to one.
  Step vertically, or away from the tile.

### Check collision before you trust a coordinate

Flood-check the layout's blockdata rather than trusting plan-specified tiles. This has caught a real
shipped bug — the Mt Moon trio was placed on an unreachable wall band, so the ambush could never fire:

```python
import json, struct
lay = json.load(open('data/layouts/layouts.json'))['layouts']
d   = json.load(open('data/maps/RegionHub/map.json'))
L   = [l for l in lay if l and l['id'] == d['layout']][0]
w, h = L['width'], L['height']
dat  = open(L['blockdata_filepath'], 'rb').read()
for y in range(h):
    row = ''
    for x in range(w):
        v = struct.unpack_from('<H', dat, 2*(y*w + x))[0]
        row += '.' if (v >> 10) & 3 == 0 else '#'   # bits 10-11 = collision
    print('%2d %s' % (y, row))
```

An NPC can legitimately **stand on a `#` tile** (the object itself is the obstacle) — you interact
from an adjacent walkable tile, so target the neighbour, not the NPC's own tile. (Real miss: the hub
Curator is at `(22,7)` and `(22,8)` is wall; the correct approach is `(22,6)` facing Down.)

For a static, whole-tree version of this check, `make validate` runs `Testing/ValidateMapEvents.py`
and friends — see MANIFEST.md §"Host-side validators".

---

## 6. The debug menu

Open with **hold R + tap Start** in the overworld. `F.dbg()` / `F.sel()` / `F.bOut()` drive it.

The root menu **opens at item 0 every time** (`ListMenuInit(&t,0,0)`) — the cursor does not persist
across fresh opens. The numeric spinner's active digit *does* persist within a warp session, and the
cursor persists inside the Utilities submenu between opens; a Time-Functions detour once broke the
next warp, so re-enter fresh.

Navigate by Down-count + A. **Indices verified against `src/debug.c` on this build:**

**Root:** `Utilities…(0)`, `PC/Bag…(1)`, `Party…(2)`, `Give X…(3)`, `Player…(4)`, `Scripts…(5)`,
`Trainers…(6)`, `Flags & Vars…(7)`, `Sound…(8)`, `ROM Info…(9)`, `Cancel(10)`

**Utilities:** `Fly to map…(0)`, `Warp to map warp…(1)`, `Set weather…(2)`, `Font Test…(3)`,
`Time Functions…(4)`, `Watch credits…(5)`, `Cheat start(6)`, `Berry Functions…(7)`,
`EWRAM Counters…(8)`, `Follower NPC…(9)`, `Wally Tutorial(10)`, `Steven Multi(11)`

**Party:** `Move Relearner(0)`, `Hatch an Egg(1)`, `Heal party(2)`, `Edit Pokemon(3)`, `Check EVs(4)`,
`Check IVs(5)`, `Give Pokerus(6)`, `Clear Pokerus(7)`, `Clear Party(8)`, `Set Party(9)`,
`Start Debug Battle(10)`

**Give X:** `Give item XYZ…(0)`, `Pokémon (Basic)(1)`, `Pokémon (Complex)(2)`, `Give Egg(3)`,
`Give Decoration…(4)`, `Max Money(5)`, `Max Coins(6)`, `Max Battle Points(7)`, `Daycare Egg(8)`

**Trainers:** the static array has 9 entries, but a **fresh open** dynamically filters to 7 rows:
`Choose trainer from map(0)`, `Trainer 1(1)`, `Trainer 2(2)`, `Partner(3)`, `Double Battle(4)`,
`Try Battle(5)`, `Recharge VS Seeker(6)`. The hidden `Matches` / `Rematch Ready` rows draw only once
a real fight is armed (e.g. via `Choose trainer from map`), which shifts `Try Battle` and
`Recharge VS Seeker` down.

**Flags & Vars:** `Set Flag XYZ…(0)`, `Set Var XYZ…(1)`, `Pokédex Flags All(2)`,
`Pokédex Flags Reset(3)`, then fourteen `Toggle …` entries.

### Warp targets: the map constant is `(num | group << 8)`

`MAP_GROUP(m) = m >> 8` — the **HIGH** byte is the group, the low byte the map num
(`MAP_REGION_HUB_2F = (1 | (100 << 8))` → group 100, num 1). The warp spinners are entered
**(group, num, warp)** in that order. Misreading the constant warps somewhere plausible-looking:
aiming at "Oldale PC 2F (3, 2)" with the bytes swapped landed in **Dewford's** PC 2F, which also
exists — always assert `grp()`/`mapn()` after a warp (`warpTo` does).

### Do NOT touch the Encounter-OFF / Trainer-See-OFF toggles

They raise `"Please define a usable flag in: include/config/overworld.h!"` (no
`OW_FLAG_NO_ENCOUNTER` configured) and the error msgbox **desyncs all following menu input** — the
next menu open lands on top of it and your D-pad walks the player. Collision-OFF is likely the same.
Pre-existing debug limitation, not a game bug.

### Spinners — two different mechanics

**Flag editor (`Set Flag XYZ…`) — step spinner, opens at Flag 1, no floor.** The `←+1→` indicator is
the *step*. Right/Left change the step (1→10→100→1000); Up/Down **add/subtract the step**. To land on
flag **N, add (N − 1)** decomposed by digit. Using the target's own digits instead of `target-1`
lands you off by one — that silently set the Route-118 flag instead of the Radio-Tower one in a real
run. **Screenshot before pressing A**: the editor shows `Flag / hex / TRUE-FALSE` live, so the shot
proves which flag you toggled.

**`F.spin(h, t, o)` — floor-then-build, and it is NOT `100h + 10t + o`.** It floors the digit with six
Downs and builds back up, and `Debug_HandleInput_Numeric` clamps at `min`. The warp spinners pass
`min = 0`, but the **item-id field passes `min = 1` and starts at 1** (`src/debug.c:2698`, `:2667`),
so it yields `1 + 100h + 10t + o`. `ITEM_SS_TICKET` (727) needs `spin(7, 2, 6)`; `spin(7, 2, 7)`
silently hands over item 728. Level fields clamp at max (asking for 100 is safe); give-item qty
defaults to 1.

### Warps desync sometimes — make them self-verifying

A warp immediately after Give-Pokémon / Clear-Party can desync (the menu closes early and the D-pad
walks the player). `F.warpTo` confirms arrival and retries. Flush debug state before the first warp
by opening the menu once and B-ing out.

### Flags/vars you cannot set from the editor

The editor's cap is `FLAGS_COUNT - 1` = **`0x102F`** (`include/constants/flags.h:4187`).

- **Kanto trainer defeat flags** (`FLAG_KANTO_TRAINER_BASE`, `0x6400`+, 640 slots) and the **Johto
  bank** (`0x6000`+) live in SaveBlock3 and are far above that cap. You cannot inject a Kanto or
  Johto gym win from the editor — use **Trainers… → Try Battle** (same difficulty-driven party path).
- **Region vars** (`VAR_JOHTO_BASE 0xA080`+) live in `SaveBlock3.regionVars[]`, not the normal
  `0x4000` space — treat editor access to them as unproven and write them through RAM instead.

---

## 7. Menus and UI

**START opens the graphical wheel** (`src/unbound_start_menu.c`), not the classic list. Navigate with
D-pad Right/Left; A activates. **SELECT is icon-REORDER mode, not navigation.** Icon order is the
player's saved order (`SaveBlock3.usmSaved`) and therefore **profile-specific** — never hardcode it.
Read it from RAM, or `Left×8..12` to pin to slot 0 and count Rights from there.

> A script that assumed one profile's 7-icon order landed on **SAVE** on a 5-icon smoke-test profile
> and saved the game. Read the order.

**Bag** opens on Items; pockets wrap, so **one Left = Key Items** (Items/Balls/TMs/Berries/Key). New
key items append at the pocket end. An item slot is `{u16 id, u16 quantity}` and **only the quantity
is XORed** against `SaveBlock2.encryptionKey` (`BagPocket_GetSlotDataGeneric`, `src/item.c`) — the
id is plaintext, so a RAM read compares against the same value `checkitem` does.

**Party action menu** is built dynamically (`SetPartyMonFieldSelectionActions` in
`src/swsh_party_menu.c` — **edit that file, not `party_menu.c`**, which is a dead
`#if !SWSH_PARTY_MENU` stub). Row count depends on the mon's field moves, so **FOLLOW is not at a
fixed index**. Screenshot the action list before selecting.

### Script multichoice: navigate by READING THE CURSOR

A Down pressed before the multichoice has drawn is **silently eaten** and the whole flow slides one
row — three Battle Net runs mis-selected a neighbouring mode this way, and generous settles did not
fix it. `menu.c`'s static `sMenu` backs script `multichoice` and yes/no boxes; `symbols.lua` carries
its address and `maxCursorPos` offset, and `F.mcur` / `F.menuLive` / `F.pick` wrap it.

Two things that make `sMenu` bite:

- **It is a static that KEEPS the last menu's fields.** Open the same board twice with only
  ListMenu traffic in between and the second wait returns true on its first probe, against the
  *first* pass's `maxCursorPos`. Zero `cursorPos` and `maxCursorPos` before re-waiting.
- **`menuLive()`/`pick()` press Down to probe**, which is unusable on a `message` + `waitmessage` +
  `multichoice` board (the probe lands mid-typewriter and the A press behind it selects row 0), and
  unusable on menus whose input handler **clamps** instead of wrapping (`Menu_ProcessInputNoWrap`) —
  a cursor driven past row 0 there can never come back.

---

## 8. Battles

Read the battle state instead of trusting the screen — `F.battleFlags()`, `F.battlers()`,
`F.outcome()` wrap `gBattleTypeFlags`, `gBattlersCount`, `gBattleOutcome`.

A genuine solo player-vs-two-trainers double is `gBattleTypeFlags == 0x800D`
(`DOUBLE|TWO_OPPONENTS|TRAINER`), `gBattlersCount == 4`, **PARTNER bit (`0x400000`) clear**.

- **Wait for battle init before reading**: poll until `gBattlersCount > 0`, or you sample a
  half-initialised state and report a false failure. `gBattlersCount` is still 0 on the frame the
  overworld callback drops.
- **There is no `BATTLE_TYPE_WILD` bit.** A wild single battle is exactly `BATTLE_TYPE_IS_MASTER`,
  so `flags == 0` is not the test.
- **Assert `gBattleOutcome == 1` for a win.** "The battle ended" is not a verdict — a simultaneous
  KO gives a DRAW (`3`) and the game correctly pays nothing for it.

### Blind A-spam cannot reliably win

- A stray directional press drifts the battle menu FIGHT→POKéMON and strands `CB2` in a submenu.
  Use a **pure-A driver with no directional presses**.
- **Teams with Wobbuffet (Counter/Mirror Coat) stall pure-A indefinitely** — no attacking moves, so
  neither side faints and the run burns to the frame cap. A Lv100 sweeper is not sufficient; one such
  fight was won only by PP exhaustion.
- Down + A pressed during send-out text is silently eaten, so a "party menu" you think you opened may
  still be `Go! Buffie!`. Prove a menu open by watching `gMain.callback2` move and come back.

**Prefer deterministic proof over winning the fight.** To verify a defeat's *consequences*
(despawn/persistence), set the relevant hide flag via the flag editor and reload the map:

```
pre: trio present -> set FLAG_HIDE_* -> warp out+back: 0 -> warp out+back again: 0
```

That proves the exact `setflag` → hide → persist mechanic the victory path triggers, with no RNG.

**Level caps eat EXP by design**: a fresh profile runs Hard Mode, where badge level caps bind
(`src/caps.c`). An at-cap mon gaining zero EXP is the game working. Lift with **Utilities → Cheat
start(6)** (badges + starters, RAM only) — it does not warp the player, but re-anchor your route
anyway.

Also: **the Frontier rejects duplicate species** — registering 3 identical mons silently self-cancels
registration. Give 3 **distinct** species.

---

## 9. NPCs and followers

**Wandering NPCs need live-position chasing.** Read the target's object-event coords each step and
close in, then face + A. Fixed-target nav misses them.

**A following Pokémon steals your A-press.** With a follower out, A can pet it ("*X is suddenly
playful*") instead of talking to your target. Combined with a wandering NPC this makes blind
interaction unreliable. Remove the follower or approach from a side it isn't on.

**`active` is not `visible`.** `ScrCmd_applymovement` pockets the follower for the duration of a
scripted walk, and a pocketed follower stays *active* in `gObjectEvents` parked on its last tile. An
active-only check reads it as still on the map and reports a phantom desync that grows as the player
walks away. Read `invisible` (`ObjectEvent.flags1` bit 5).

A follower given by the debug party also carries `OBJ_EVENT_MON`, so exclude it by local id (**254**)
when scanning for map-placed overworld Pokémon.

---

## 10. Evidence

`F.shot(name)` screenshots and names the file `<Suite>_NN_<name>.png`, so a **shorter rerun does not
overwrite a longer previous run's shots**. That cuts both ways: stale screenshots from a killed run
survive and mislead — a blue-screen shot from an aborted run was misread as a fresh failure this way.
Clear `_pwtest/` between runs, or check the log's shot list for what this run actually wrote.

`F.objdump()` dumps live object events to prove spawn/despawn. `OBJECT_EVENTS_COUNT = 16` including
the player **and** an active follower → ~14 map objects usable, and the spawn window is ~20 wide ×
17 tall, so on a dense map objects can silently fail to spawn. Walking the map and dumping counts is
how you catch it.

### Crash screens are readable — and the colour lies

`F.crashScreen()` decodes the assert screen straight out of VRAM and returns
`"FILE.C:LINE: MESSAGE"`; `F.reportCrash(tag)` logs it, screenshots it, and returns true so a walk
loop can `if F.reportCrash("step"..i) then break end`. Verified end to end against a planted
`fatalf`. **Never key off the blue/red palette** — by the time anything reads `BG_PLTT` it holds the
interrupted scene's colours, not the mode colour.

> **`gMain.callback2` is not an assert-screen detector.** `AssertfCrashScreen`
> (`src/assertf.c`) sets `REG_IME = 0` and busy-loops on `REG_VCOUNT` waiting for START *inside*
> `CB2_Overworld`'s own call stack, so `F.ow()` still reads `CB2_Overworld` with the crash screen up.
> What stops is the main loop — interrupts off means `VBlankIntr` never runs and
> `gMain.vblankCounter1` **freezes**. Sample that. And do not press Start during a segment that
> might crash: the screen is resumable and Start dismisses it.
>
> `assertf` compiles to `(void)0` under `#if RELEASE` (`include/assertf.h`), and `RELEASE` is set
> only by `make release` / `tidyrelease`. These checks discriminate against `make modern` builds —
> against a true RELEASE build the assert is absent and the check goes green vacuously.

---

## 11. Checklist before reporting a result

1. Did the run load the **build you intended**? The runner prints `md5 :` and the guard aborts on a
   mismatch — but check the line.
2. Are you reading `symbols.lua` rather than a pasted address?
3. Did you assert on **RAM**, not on a screenshot you eyeballed? A wrong metatile still draws
   *something*; a screenshot assert passes on a broken build.
4. Are the screenshots you're reading from **this run** (not a stale leftover)?
5. Is the "failure" actually a **harness** failure — nav stuck, pure-A stall, wrong flag,
   `warpTo` no-op, `sMenu` holding the last menu's fields? Prove the mechanic deterministically
   before blaming the game.
6. Did you prove the check **discriminates**? Stash the fix, rebuild, and confirm the suite goes red.
   One suite scored a full 17/17 against the unfixed ROM.
