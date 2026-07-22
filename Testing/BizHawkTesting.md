# BizHawk Testing Guide (PKMN-World)

How to drive this ROM in BizHawk/EmuHawk with Lua for automated, evidence-producing tests.
Written for future agents and for anyone picking the project back up cold.

> **Test plans** live beside this guide — see
> [`BattleFrontierRematchTestPlan.md`](BattleFrontierRematchTestPlan.md) (Battle Frontier +
> gym/league rematches). Broader open work is tracked in **the repo's GitHub issues**
> (local index: `docs/StatusBoard.md`, gitignored).

Everything here was verified empirically against real runs. Where a technique has a
known failure mode, it is called out — most of the pain in this project has come from
harness quirks, not from game bugs.

---

## 1. Build, then test the build you think you're testing

```bash
cd /mnt/c/Users/evilc/Github/PKMN-World
PATH="$HOME/.local/arm-none-eabi/usr/bin:$PATH" make -j12      # -> pokemonworld.gba
```

- The toolchain is **modern-only** (no agbcc). Always prepend `~/.local/arm-none-eabi/usr/bin`.
  A stale `~/.local/bin/devkitarm-shim/` on PATH contains **Windows `.exe`** wrappers that fail
  headless (`cannot execute 'cc1'`) and kill every `.o` identically.
- **A rebuild changes every address.** Re-extract symbols from `pokemonworld.map` each build
  (see §4). Old `.State` savestates are dead after a rebuild; only `.SaveRAM` survives.

### ⚠ The stale-play-ROM trap

The user **plays** `C:\Users\evilc\BizHawk\pokemonworld.gba` — a *copy*, separate from the
build output at `<repo>/pokemonworld.gba`. `make` only updates the repo one.

- When scripting a test, **always pass the repo build path explicitly** (or an isolated copy of
  it), never assume the BizHawk-dir ROM is fresh.
- After a build the user will test: refresh **both** `BizHawk\pokemonworld.gba` (name must stay
  exactly that — its save `pokemonworld.SaveRAM` is keyed to the name) **and**
  `Downloads\Pokemon - World.gba` (user's display name), then md5-verify they match.

---

## 2. Save safety (read this before your first run)

BizHawk **flushes `.SaveRAM` to disk on exit**, and stray A-presses can hit START → SAVE and
persist your test mutations (cleared party, debug-given mons, test flags) into the user's real save.

**Always isolate the run.** Copy the ROM *and* the save to a throwaway pair and drive that:

```bash
cp <repo>/pokemonworld.gba            "C:/Users/evilc/BizHawk/Verify1.gba"
cp <backup-of>/pokemonworld.SaveRAM   "C:/Users/evilc/BizHawk/GBA/SaveRAM/Verify1.SaveRAM"
```

The SaveRAM filename must match the ROM basename (`Verify1.gba` ↔ `Verify1.SaveRAM`). A stray
save then only clobbers the copy.

**Back up and verify the real save anyway:**

```bash
cp  BizHawk/GBA/SaveRAM/pokemonworld.SaveRAM  <backup>
# after testing — compare the 128KB flash body, NOT the whole file:
cmp -n 131072 BizHawk/GBA/SaveRAM/pokemonworld.SaveRAM <backup> && echo INTACT
```

> A BizHawk `.SaveRAM` is the raw **131072-byte** save **+ a 16-byte footer**. The footer can
> differ between sessions even when nothing was saved, so an `md5sum` of the whole file gives
> false alarms. Compare the first 131072 bytes.

---

## 3. Launching

```bash
cmd.exe /c 'C:\Users\evilc\BizHawk\EmuHawk.exe C:\Users\evilc\BizHawk\Verify1.gba --lua=C:\Users\evilc\Github\PKMN-World\_pwtest\MyTest.lua'
```

- Run it with `run_in_background: true` and `dangerouslyDisableSandbox: true`.
- Scripts live in `_pwtest/` (gitignored scratch).
- The emulator's stdout prints the loaded ROM's `CRC`/`MD5` — **grep it to prove you tested the
  build you meant to.** This is the cheapest guard against the stale-ROM trap.
- `client.speedmode(800)` for headless speed; `client.exit()` to end the run.
- Several EmuHawk instances can run in parallel (3–4 is fine) for independent test lanes.

### Logging gotcha

Lua `io.open(path,"w")` + `flush()` per line usually works, but the file can appear **0 bytes**
from the WSL side until the handle closes. If a log looks empty yet the screenshots exist,
re-read it a moment later — the data is usually there. Prefer **screenshots + RAM reads** as
primary evidence; logs are a convenience.

---

## 4. Addresses: re-extract every build

```bash
grep -E ' (gMain|gSaveBlock1Ptr|gSaveBlock2Ptr|gObjectEvents|gBattleTypeFlags|gBattlersCount|gSaveblock3|gParties|gPartiesCount)$' pokemonworld.map
grep -E ' CB2_Overworld$' pokemonworld.map
```

Reference values for build `a63282099b` (**re-derive for yours**):

| Symbol | Address | Notes |
|---|---|---|
| `CB2_Overworld` | `0x08198b18` | compare with low bit masked off |
| `gMain` | `0x030065a0` | **cb2 is at +4** → read `0x030065a4` |
| `gSaveBlock1Ptr` | `0x030050a0` | pointer; deref then read |
| `gObjectEvents` | `0x0200189c` | stride `0x24` |
| `gBattleTypeFlags` | `0x020000c8` | |
| `gBattlersCount` | `0x020000cc` | |
| `gSaveblock3` | `0x02014f24` | **fixed EWRAM symbol, no ASLR** |
| `gPartiesCount` | `0x020324cc` | player party count |
| `gParties` | `0x020324dc` | player party base; `struct Pokemon` = 100 B |

Useful offsets:

- Player position: `*gSaveBlock1Ptr + 0x00` = x, `+0x02` = y (s16). Map group `+0x04`, map num `+0x05`.
- Object event: byte0 bit0 = **alive/active**; `+0x10` = x, `+0x12` = y (s16, **= map coord + 7**).
- `struct Pokemon`: level `+0x54`, hp `+0x56`, maxHP `+0x58`.
- `usmSaved` (start-menu wheel order) = `gSaveblock3 + 928`: `u8 items[12]` then `u8 count`.
  Reads `count=0` until the wheel is opened once — it rebuilds defaults on open.
- Live shop inventory while a mart is open: `sMartInfo.itemList` @ `0x020356a8`,
  `.itemCount` @ `0x020356ac` — dumping this beats OCR'ing the menu.

> **SaveBlock1 struct offset comments are STALE** in this build. Do **not** RAM-poke flags/vars
> by the annotated `/*0x1270*/ flags` / `/*0x139C*/ vars` offsets — they don't hit the real bytes.
> Use the debug menu's flag/var editor instead.

> Struct layout must be computed with the repo's **exact CFLAGS** (`-mabi=apcs-gnu` changes
> layout). Config-based guesses have been 6 bytes off. Use an `offsetof` probe + `arm-none-eabi-gcc -S`.

---

## 5. Boot reliably

Do **not** guess at timing or use a map-group heuristic (`grp==0` at the title screen is a false
positive that exits early). Wait for the real signal:

```lua
local CB2_OW, GMAIN_CB2 = 0x08198b18, 0x030065a4
local function cb2() return memory.read_u32_le(GMAIN_CB2,"System Bus") & 0xFFFFFFFE end
local function ow() return cb2() == CB2_OW end

client.speedmode(800)
for _=1,300 do joypad.set({}); emu.frameadvance() end
local f = 0
while f < 60000 and not ow() do
  local p = f % 30
  if p < 3 then joypad.set({A=true})              -- A: dismiss / CONTINUE
  elseif p >= 15 and p < 17 then joypad.set({Start=true})
  else joypad.set({}) end
  emu.frameadvance(); f = f + 1
end
```

**Never `savestate.load` across EmuHawk sessions.** `pcall` hides the failure and the input
stream then drives the title screen into new-game chaos. Save blocks also *relocate* on savestate
load (`gSaveBlock1Ptr` changes), desyncing any poke made before the save. **Write single-run
scripts**: boot → act → assert → exit.

---

## 6. Moving around

Blind hold-walking drifts. Use **coordinate-verified** stepping — step until the coords actually
change, then finish the tile:

```lua
local function step(dir)
  local x0,y0 = pos()
  for f=1,26 do
    joypad.set({[dir]=true}); emu.frameadvance()
    local x,y = pos()
    if x~=x0 or y~=y0 then
      for _=1,14 do joypad.set({[dir]=true}); emu.frameadvance() end  -- finish the tile
      return true
    end
  end
  return false                                                        -- blocked
end
```

Build `goTo(tx,ty)` on top: pick an axis, `step()`, and on a block try the perpendicular axis.
It is not a real pathfinder — **verify your target tile is walkable first** (§7) or it will spin.

`face(dir)` = tap the direction ~4 frames without completing a step.

### Check collision before you trust a coordinate

Flood-check the layout's `map.bin` rather than trusting plan-specified tiles. This has caught a
real shipped bug (the Mt Moon trio was placed on an unreachable wall band, so the ambush could
never fire):

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

An NPC can legitimately **stand on a `#` tile** (the object itself is the obstacle) — you
interact from an adjacent walkable tile. So target the neighbour, not the NPC's own tile.
(Real miss: the hub Curator is at `(22,7)` and `(22,8)` is wall; the correct approach is
`(22,6)` facing Down.)

---

## 7. The debug menu

Open with **hold R + tap Start** in the overworld. The root menu **opens at item 0 every time**
(`ListMenuInit(&t,0,0)`) — the cursor does *not* persist across fresh opens. (The numeric
spinner's active digit *does* persist within a warp session, and the cursor persists inside the
Utilities submenu between opens — a Time-Functions detour once broke the next warp; re-enter fresh.)

Navigate by Down-count + A. Indices as of this build (`src/debug.c` — **re-check if it changes**):

**Root:** `Utilities…(0)`, `PC/Bag…(1)`, `Party…(2)`, `Give X…(3)`, `Player…(4)`, `Scripts…(5)`,
`Trainers…(6)`, `Flags & Vars…(7)`, `Sound…(8)`, `ROM Info…(9)`, `Cancel(10)`

**Utilities:** `Fly to map…(0)`, `Warp to map warp…(1)`, `Set weather…(2)`, `Font Test…(3)`,
`Time Functions…(4)`, `Watch credits…(5)`, `Cheat start(6)`, `Berry Functions…(7)`,
`EWRAM Counters…(8)`, `Follower NPC…(9)`, `Wally Tutorial(10)`, `Steven Multi(11)`

**Party:** `Move Relearner(0)`, `Hatch an Egg(1)`, `Heal party(2)`, `Edit Pokemon(3)`,
`Check EVs(4)`, `Check IVs(5)`, `Give Pokerus(6)`, `Clear Pokerus(7)`, `Clear Party(8)`,
`Set Party(9)`, `Start Debug Battle(10)`

**Give X:** `Give item XYZ…(0)`, `Pokémon (Basic)(1)`, `Pokémon (Complex)(2)`, `Give Egg(3)`,
`Give Decoration…(4)`, `Max Money(5)`, `Max Coins(6)`, `Max Battle Points(7)`, `Daycare Egg(8)`

**Flags & Vars:** `Set Flag XYZ…(0)`, `Set Var XYZ…(1)`, `Pokédex Flags All(2)`,
`Pokédex Flags Reset(3)`, then the various `Toggle …` entries.

### ⛔ Do NOT touch the Encounter-OFF / Trainer-See-OFF toggles

They raise `"Please define a usable flag in: include/config/overworld.h!"` (no
`OW_FLAG_NO_ENCOUNTER` configured) and the error msgbox **desyncs all following menu input** —
the next menu open lands on top of it and your D-pad walks the player. Collision-OFF is likely
the same. This is a pre-existing debug limitation, not a game bug.

### Spinners — there are two different mechanics

**Flag editor (`Set Flag XYZ…`) — step spinner, opens at Flag 1, no floor.**
The `←+1→` indicator is the *step*. Right/Left change the step (1→10→100→1000);
Up/Down **add/subtract the step**. To land on flag **N, add (N − 1)** decomposed by digit:

```lua
-- flag 3450: start 1, add 3449 = 3*1000 + 4*100 + 4*10 + 9*1
press("Right",2); press("Right",2); press("Right",2)  -- step -> 1000
for _=1,3 do press("Up",2) end                        -- +3000
press("Left",2);  for _=1,4 do press("Up",2) end      -- +400  (step 100)
press("Left",2);  for _=1,4 do press("Up",2) end      -- +40   (step 10)
press("Left",2);  for _=1,9 do press("Up",2) end      -- +9    -> 3450
```

Using the target's own digits (instead of `target-1`) lands you **off by one** — that silently
set the Route-118 flag instead of the Radio-Tower one in a real run. **Always screenshot before
pressing A**: the editor shows `Flag / hex / TRUE-FALSE` live, so the shot proves you toggled the
right flag. A toggles the shown flag.

**Warp / give-item / give-Pokémon spinners — floor-then-build works reliably:**

```lua
-- go to the high digit, floor the field, then build the value up
press("Right",2); press("Right",2)          -- move to hundreds
for _=1,6 do press("Down",2) end            -- floor to min
for _=1,h do press("Up",2) end              -- +100 each
press("Left",2); for _=1,t do press("Up",2) end
press("Left",2); for _=1,o do press("Up",2) end
press("A",2)
```

Level fields **clamp at max** (asking for 100 is safe). Give-item qty defaults to 1.

### Warps desync sometimes — make them self-verifying

A warp immediately after Give-Pokémon / Clear-Party can desync (the menu closes early and the
D-pad walks the player). Always confirm arrival and retry:

```lua
-- after warping: check group/num and that we're within ±2 of the expected tile; retry up to 4x
if grp()==eg and mapn()==em and math.abs(x-ex)<=2 and math.abs(y-ey)<=2 then ok() end
```

Flush debug state before the first warp (open the menu once and B out).

### Flags/vars you cannot set from the editor

**Kanto trainer defeat flags live in a 640-slot SaveBlock3 bank (`FLAG_KANTO_TRAINER_BASE`,
`0x6400+`) which is ABOVE the debug flag editor's range** — you cannot inject Kanto gym wins that
way. Use **Trainers… → Try Battle** (it takes the same difficulty-driven party path) when a
scripted win is unreliable.

Region vars (`VAR_JOHTO_BASE 0xA080+`) live in `SaveBlock3.regionVars[]`, not the normal
`0x4000` space — treat editor access to them as unproven.

---

## 8. Menus and UI

**START opens the graphical wheel** (`src/unbound_start_menu.c`), not the classic list.
Navigate with **D-pad Right/Left**; A activates. **SELECT is icon-REORDER mode, not navigation.**
Icon order is the player's saved order (`SaveBlock3.usmSaved`) and therefore **profile-specific** —
never hardcode it. Read it from RAM, or `Left×8..12` to pin to slot 0 and count Rights from there.

> A script that assumed one profile's 7-icon order would land on **SAVE** on the current
> smoke-test profile (5 icons: Party/Bag/Trainer/Save/Options) and save the game. Read the order.

**Bag** opens on Items; pockets wrap, so **one Left = Key Items** (Items/Balls/TMs/Berries/Key).
New key items append at the pocket end.

**Party action menu** is built dynamically (`SetPartyMonFieldSelectionActions` in
`swsh_party_menu.c` — **edit that file, not `party_menu.c`**, which is a dead
`#if !SWSH_PARTY_MENU` stub). Row count depends on the mon's field moves, so
**FOLLOW is not at a fixed index**: a no-field-move mon gives
`Summary(0) / Item(1) / Follow(2) / Nickname(3) / Cancel(4)`, while a 4-field-move mon shifts
everything and drops Nickname. Screenshot the action list before selecting.

---

## 9. Battles

Read the battle state instead of trusting the screen:

```lua
local bt = memory.read_u32_le(0x020000c8,"System Bus")   -- gBattleTypeFlags
local bc = memory.read_u8 (0x020000cc,"System Bus")      -- gBattlersCount
local partner = (bt & 0x400000) ~= 0                     -- PARTNER bit
```

A genuine solo player-vs-two-trainers double is `gBattleTypeFlags == 0x800D`
(`DOUBLE|TWO_OPPONENTS|TRAINER`), `gBattlersCount == 4`, **PARTNER bit clear**.

**Wait for battle init before reading**: poll until `gBattlersCount > 0`, else you'll sample a
half-initialised `0x8009`/`battlers=0` and report a false failure.

### ⚠ Blind A-spam cannot reliably win

- A stray directional press drifts the battle menu FIGHT→POKéMON and strands `CB2` in the
  bag/party submenu. Use a **pure-A driver with no directional presses**.
- **Teams with Wobbuffet (Counter/Mirror Coat) stall pure-A indefinitely** — it has no attacking
  moves, so neither side faints and the run burns to the frame cap. Jessie's/James's ambush teams
  all carry one. A Lv100 sweeper is *not* sufficient; one such fight was won only by PP exhaustion.

**Prefer deterministic proof over winning the fight.** To verify a defeat's *consequences*
(despawn/persistence), set the relevant hide flag via the flag editor and reload the map:

```
pre: trio present -> set FLAG_HIDE_* -> warp out+back: 0 -> warp out+back again: 0
```

This proves the exact `setflag` → hide → persist mechanic the victory path triggers, with no
battle RNG. (Used to verify the Radio Tower ambush after pure-A stalled.)

Also: **the Frontier rejects duplicate species** — registering 3 identical mons silently
self-cancels registration. Give 3 **distinct** species.

---

## 10. NPCs

**Wandering NPCs need live-position chasing.** Read the target's object-event coords each step and
close in, then face + A. Fixed-target nav misses them (the Dome's championship registrar is the
repurposed Maniac, `localId 5`, `MOVEMENT_TYPE_WANDER_AROUND` range 1 → a 3×3 roam).

**A following Pokémon steals your A-press.** With a follower out, A can pet it
("*X is suddenly playful*") instead of talking to your target. Combined with a wandering NPC this
makes blind interaction unreliable — the Dome registrar could not be driven this way. Remove the
follower or approach from a side the follower isn't on.

---

## 11. Evidence

Screenshot on a cadence and **name shots by step**, not just number:

```lua
local shotn = 0
local function shot(n)
  shotn = shotn + 1
  client.screenshot(OUT .. string.format("t1_%02d_%s.png", shotn, n))
end
```

> Because the filename embeds the step name, a **shorter rerun does not overwrite a longer
> previous run's shots** — stale screenshots from a killed run can survive and mislead you.
> A blue-screen shot from an aborted run was misread as a fresh failure this way. Clear old
> shots between runs, or check the log's shot list to see which files the current run wrote.

Dump object events to prove spawn/despawn:

```lua
for i=0,15 do
  local b = OBJ + i*0x24
  if (memory.read_u8(b,"System Bus") & 1) == 1 then
    local x = memory.read_s16_le(b+0x10,"System Bus") - 7
    local y = memory.read_s16_le(b+0x12,"System Bus") - 7
  end
end
```

`OBJECT_EVENTS_COUNT = 16` including the player **and** an active follower → ~14 map objects
usable. The spawn window is ~20 wide × 17 tall, so on a dense map objects can silently fail to
spawn; walking the whole map and dumping counts is how you catch it.

---

## 12. Reusable scripts

`_pwtest/` holds working examples (gitignored). Good starting points:

| Script | Pattern |
|---|---|
| `BootSmokeIssue2.lua` | minimal boot → overworld → move → screenshot → exit |
| `T1VendorsV2.lua` | talk vendors, dump live mart inventory from RAM, hub sweep |
| `T4Ambush.lua` | give mons → warp → talk → battle-state asserts → post-battle object dump |
| `T4RadioFlag.lua` | **deterministic flag-set → reload → persistence proof** (no battle) |
| `T6Dome.lua` | champion flags via editor, wander-NPC chase, Frontier registration |

Copy the helpers (`ow()`, `step()`, `goTo()`, `objdump()`, `shot()`, `dbg()`, `spin()`,
self-verifying `warpTo()`) rather than rewriting them.

---

## 13. Checklist before reporting a result

1. Did the emulator load the **build you intended**? (check the printed MD5)
2. Are your addresses from **this build's** `pokemonworld.map`?
3. Did you assert on **RAM**, not on a screenshot you eyeballed?
4. Are the screenshots you're reading from **this run** (not a stale leftover)?
5. Is a "failure" actually a **harness** failure (nav stuck, pure-A stall, wrong flag)?
   Prove the mechanic deterministically before blaming the game.
6. Is the user's `pokemonworld.SaveRAM` byte-identical to your backup (first 131072 bytes)?
