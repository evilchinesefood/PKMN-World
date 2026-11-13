-- Double battles, played adversarially: wild doubles and trainer doubles must never freeze,
-- crash, softlock or corrupt the party, the PC or the Bag.
--
-- HOW A WILD DOUBLE IS REACHED. Nothing in this build rolls one from the field:
-- WE_DOUBLE_WILD_CHANCE is 0, WE_FLAG_FORCE_DOUBLE_WILD is 0 and NPC followers are compiled out,
-- so TryDoDoubleWildBattle (src/wild_encounter.c) is always FALSE, and no map script uses the
-- two-species form of setwildbattle. The engine path still ships, though, and the grass, fishing
-- and overworld-encounter callers all end in BattleSetup_StartDoubleWildBattle
-- (src/battle_setup.c), i.e. DoStandardWildBattle(TRUE) with CB2_EndWildBattle. The suite drives
-- that exact function: a three-command script written into EWRAM (setwildbattle with two species,
-- then callnative BattleSetup_StartDoubleWildBattle, then end) is handed to the global script
-- context, the same seam LanceMultiBattle.lua uses for a ROM script. The scripted double
-- (dowildbattle -> BattleSetup_StartScriptedDoubleWildBattle) is covered too.
--
-- Trainer doubles come from the debug Trainers menu (Trainer 1 + Trainer 2 + Try Battle), the
-- route ExpansionHealthboxes.lua already proves reaches BATTLE_TYPE_DOUBLE.
--
-- WHAT IS ASSERTED, all on RAM: the battle ends with the outcome the scenario forces, the field
-- callback comes back and the player can walk, no crash screen is up, and the party is sane
-- (every occupied slot decrypts with a valid checksum and species, HP <= max HP, no hole below
-- gPartiesCount and nothing above it). Catching additionally counts every personality value in
-- the party and all fourteen boxes before and after, so a caught Pokemon that lands twice, or a
-- ball that is thrown without leaving the Bag, fails.
--
-- Mashing never presses SELECT: DEBUG_BATTLE_MENU is
-- on in dev builds and SELECT there opens the battle debug menu, which edits the battle directly.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/DoubleBattleStress.lua <rom>
-- PW_DBL_ONLY=<text> (runner --env) runs only the scenarios whose name contains <text>.

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "DoubleBattleStress")

local HUB_GROUP = 100
local ONLY = os.getenv("PW_DBL_ONLY")

local B_DOUBLE, B_TRAINER = 1 << 0, 1 << 3
local OUT_WON, OUT_LOST, OUT_RAN, OUT_CAUGHT = 1, 2, 4, 7
local PARTY_SIZE, BOX_SLOTS = 6, 14 * 30
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local MAX_SPECIES_BITS = 0x7FF

local SPECIES_CATERPIE, SPECIES_METAPOD = 10, 11
local SPECIES_MAGIKARP, SPECIES_TOGEPI = 129, 175
local SPECIES_POOCHYENA, SPECIES_ZIGZAGOON, SPECIES_WURMPLE = 261, 263, 265
local SPECIES_BELDUM = 374
local ITEM_POKE_BALL, ITEM_MASTER_BALL, ITEM_POTION = 1, 4, 28

-- struct BattlePokemon (symbols.lua): species is the u16 at 0.
local BM = S.BattlePokemon
local OPP_PARTY = S.gParties + PARTY_SIZE * S.Pokemon.size   -- gParties[B_TRAINER_OPPONENT_A]

-- ---- small utilities ---------------------------------------------------------------------------

local function tap(n) for _ = 1, n do F.press("Down", 3); F.idle(16) end end
local function inBattle() return F.cb2() == (S.BattleMainCB2 & ~1) end
local function vblank() return F.r32(S.gMain + 0x20) end

local function options()
  return F.sb2() + S.SaveBlock2.optionsU16
end
-- optionsU16 bits 14-15: the QoL B-button run shortcut (0 cursor to RUN, 1 off, 2 flee at once).
local RUN_SHORTCUT_CURSOR, RUN_SHORTCUT_OFF, RUN_SHORTCUT_INSTANT = 0, 1, 2
local function setRunShortcut(v) F.w16(options(), (F.r16(options()) & 0x3FFF) | (v << 14)) end
local function instantText() F.w16(options(), (F.r16(options()) & ~7) | 3) end
-- optionsU16: bit 9 battle style SET (no "Will you switch?" prompt), bit 10 battle scene off.
local function fastBattles(on)
  local v = F.r16(options()) | (1 << 9)
  if on then v = v | (1 << 10) else v = v & ~(1 << 10) end
  F.w16(options(), v)
end

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0
    and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end

-- ---- Pokemon decoding ---------------------------------------------------------------------------
-- struct BoxPokemon: personality 0, otId 4, flags byte 19 (bit0 isBadEgg, bit1 hasSpecies,
-- bit2 isEgg), checksum u16 at 28, 48 encrypted bytes at 32 (key = personality ^ otId,
-- substruct order from sSubstructOffsets[type][personality % 24]). Species is the low 11 bits
-- of substruct 0's first word.
local function monAt(a)
  local fl = F.r8(a + 19)
  local m = { present = (fl & 2) ~= 0, egg = (fl & 4) ~= 0, bad = (fl & 1) ~= 0, pid = F.r32(a) }
  if not m.present then return m end
  local key = F.r32(a) ~ F.r32(a + 4)
  local w, sum = {}, 0
  for i = 0, 11 do
    w[i] = F.r32(a + 32 + i * 4) ~ key
    sum = (sum + (w[i] & 0xFFFF) + (w[i] >> 16)) & 0xFFFF
  end
  m.species = w[F.r8(S.sSubstructOffsets + (m.pid % 24)) * 3] & MAX_SPECIES_BITS
  m.checksumOk = sum == F.r16(a + 28)
  return m
end

-- The four move ids: substruct 1 is four u16s, each move:11 with 5 bits of tracker above it.
local function monMoves(a)
  local key = F.r32(a) ~ F.r32(a + 4)
  local base = F.r8(S.sSubstructOffsets + 24 + (F.r32(a) % 24)) * 3
  local w0, w1 = F.r32(a + 32 + base * 4) ~ key, F.r32(a + 32 + (base + 1) * 4) ~ key
  return { w0 & 0x7FF, (w0 >> 16) & 0x7FF, w1 & 0x7FF, (w1 >> 16) & 0x7FF }
end

local function partyAddr(s) return S.gParties + s * S.Pokemon.size end
local function partyCount() return F.r8(S.gPartiesCount) end
local function boxAddr(s) return F.r32(S.gPokemonStoragePtr) + 4 + s * S.BoxPokemon.size end
local function monHp(s) return F.r16(partyAddr(s) + S.Pokemon.hp) end
local function monMaxHp(s) return F.r16(partyAddr(s) + S.Pokemon.maxHP) end

local function partySane()
  local n, bad = partyCount(), {}
  if n < 1 or n > PARTY_SIZE then bad[#bad + 1] = "count=" .. n end
  local occupied = 0
  for s = 0, PARTY_SIZE - 1 do
    local a = partyAddr(s)
    local m = monAt(a)
    if m.present then
      occupied = occupied + 1
      if s >= n then bad[#bad + 1] = "slot" .. s .. " above count" end
      if m.bad then bad[#bad + 1] = "slot" .. s .. " bad egg" end
      if not m.checksumOk then bad[#bad + 1] = "slot" .. s .. " checksum" end
      if m.species < 1 or m.species >= MAX_SPECIES_BITS then bad[#bad + 1] = "slot" .. s .. " species=" .. m.species end
      if not m.egg then
        local hp, mx, lv = monHp(s), monMaxHp(s), F.r8(a + S.Pokemon.level)
        if mx == 0 or hp > mx then bad[#bad + 1] = string.format("slot%d hp=%d/%d", s, hp, mx) end
        if lv < 1 or lv > 100 then bad[#bad + 1] = "slot" .. s .. " level=" .. lv end
      end
    elseif s < n then
      bad[#bad + 1] = "slot" .. s .. " empty below count"
    end
  end
  if occupied ~= n then bad[#bad + 1] = string.format("occupied=%d count=%d", occupied, n) end
  return #bad == 0, (#bad == 0 and ("n=" .. n) or table.concat(bad, "; "))
end

-- Every personality value in the party and the boxes, with a duplicate count. A caught Pokemon
-- that is written to two places, or a party member copied into the PC, shows up here.
local function census()
  local seen, total, dups, species = {}, 0, 0, {}
  local function add(a)
    local m = monAt(a)
    if m.present then
      total = total + 1
      if seen[m.pid] then dups = dups + 1 end
      seen[m.pid] = true
      species[m.species] = (species[m.species] or 0) + 1
    end
  end
  for s = 0, PARTY_SIZE - 1 do add(partyAddr(s)) end
  for s = 0, BOX_SLOTS - 1 do add(boxAddr(s)) end
  return { total = total, dups = dups, species = species, pids = seen }
end

-- ---- Bag ---------------------------------------------------------------------------------------
-- Item ids are plaintext; quantities are XORed with the low half of SaveBlock2.encryptionKey.
local function itemQty(id)
  local key = F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF
  local n = 0
  for p = 0, 4 do
    local ptr = F.r32(S.gBagPockets + p * S.BagPocket.stride)
    local cap = F.pocketCap(p)
    if ptr >= 0x02000000 and ptr < 0x02040000 and cap > 0 and cap < 400 then
      for s = 0, cap - 1 do
        if F.r16(ptr + s * 4) == id then n = n + (F.r16(ptr + s * 4 + 2) ~ key) end
      end
    end
  end
  return n
end

-- ---- scripts from EWRAM ------------------------------------------------------------------------
-- The tail of gStringVar4 (1000 bytes): no message the field or the battle prints gets that long,
-- and the scripted-double case below needs its bytes to survive the battle and run on return.
local SCRIPT_BUF = S.gStringVar4 + 960
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end

local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)       -- stackDepth
  F.w8(S.sGlobalScriptContext + 1, 1)   -- SCRIPT_MODE_BYTECODE
  F.w32(S.sGlobalScriptContext + 4, 0)  -- nativePtr
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
end

local function scriptAddItem(id, qty)
  local b = { 0x44 }; le16(b, id); le16(b, qty); b[#b + 1] = 0x02   -- additem, end
  runScript(b); F.idle(10)
end

-- createmon (src/script_pokemon_util.c) for the player's side into the first free slot, or the
-- PC when the party is full, exactly as `givemon` does, with the four moves pinned so a battle
-- policy knows what each move slot does. A player-OT mon also obeys at any level, which the debug
-- party's Wobbuffet (a trainer-OT mon) does not without badges.
local MOVE_FLAMETHROWER, MOVE_SPLASH, MOVE_CELEBRATE, MOVE_TACKLE, MOVE_PROTECT = 53, 150, 606, 33, 182
local function scriptGiveMon(species, level, moves)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = PARTY_SIZE
  le16(b, species); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for k = 1, 4 do le16(b, moves[k] or 0) end
  b[#b + 1] = 0x02
  local before = partyCount()
  runScript(b); F.idle(20)
  return partyCount() == before + 1
end

local function scriptGiveEgg(species)
  local b = { 0x7A }; le16(b, species); b[#b + 1] = 0x02
  local before = partyCount()
  runScript(b); F.idle(20)
  return partyCount() == before + 1
end

local function setWildBattleBytes(sp1, lv1, sp2, lv2)
  local b = { 0xB6 }                                 -- setwildbattle
  le16(b, sp1); b[#b + 1] = lv1; le16(b, 0)
  le16(b, sp2); b[#b + 1] = lv2; le16(b, 0)
  return b
end

-- Wait for the battle to be fully set up: CB2 on BattleMainCB2 and gBattlersCount published.
local function waitBattle(tag, budget)
  for i = 1, budget or 1200 do
    F.idle(1)
    if inBattle() and F.battlers() >= 2 then F.idle(4); return true end
    if i % 60 == 0 and F.reportCrash(tag) then return false end
  end
  return false
end

-- Natural wild-double entry: BattleSetup_StartDoubleWildBattle (DoStandardWildBattle(TRUE)).
local function startWildDouble(tag, sp1, lv1, sp2, lv2)
  local b = setWildBattleBytes(sp1, lv1, sp2, lv2)
  b[#b + 1] = 0x23; le32(b, S.BattleSetup_StartDoubleWildBattle | 1)   -- callnative
  b[#b + 1] = 0x02                                                      -- end
  runScript(b)
  return waitBattle(tag)
end

-- Scripted wild-double entry: dowildbattle after a two-species setwildbattle.
local function startScriptedWildDouble(tag, sp1, lv1, sp2, lv2)
  local b = setWildBattleBytes(sp1, lv1, sp2, lv2)
  b[#b + 1] = 0xB7                                                      -- dowildbattle
  b[#b + 1] = 0x02                                                      -- end
  runScript(b)
  return waitBattle(tag)
end

-- ---- debug menu ---------------------------------------------------------------------------------
local ROW_PCBAG, ROW_PARTY, ROW_GIVE, ROW_TRAINERS = 1, 2, 3, 6

local function debugRow(root, row, extra)
  F.dbg(); F.idle(40)
  tap(root); F.press("A", 3); F.idle(50)
  tap(row); F.press("A", 3); F.idle(extra or 120)
end
local function flushMenus() for _ = 1, 8 do F.press("B", 3); F.idle(18) end end

local function setParty() debugRow(ROW_PARTY, 9, 180); flushMenus() end
local function clearParty() debugRow(ROW_PARTY, 8, 120); flushMenus() end
local function clearBag() debugRow(ROW_PCBAG, 2, 120); flushMenus() end
local function clearBoxes() debugRow(ROW_PCBAG, 3, 120); flushMenus() end
local function fillBoxes()
  F.dbg(); F.idle(40)
  tap(ROW_PCBAG); F.press("A", 3); F.idle(50)
  tap(1); F.press("A", 3); F.idle(50)
  F.press("A", 3); F.idle(400)
  flushMenus()
end

local function task(fn)
  for j = 0, S.Task.count - 1 do
    local t = S.gTasks + j * S.Task.stride
    if F.r8(t + S.Task.isActive) ~= 0 and (F.r32(t) & ~1) == (fn & ~1) then return t end
  end
end

-- Give X -> Pokemon (Basic) or Give Egg, writing the spinner's tInput (data[3]) directly.
local function giveMon(species, level)
  local before = partyCount()
  F.dbg(); F.idle(40)
  tap(ROW_GIVE); F.press("A", 3); F.idle(50)
  tap(level and 1 or 3); F.press("A", 3); F.idle(80)
  local t = task(S.DebugAction_Give_Pokemon_SelectId)
  if t then
    F.w16(t + S.Task.data + 6, species); F.idle(4); F.press("A", 3); F.idle(40)
    if level then
      local t2 = task(S.DebugAction_Give_Pokemon_SelectLevel)
      if t2 then F.w16(t2 + S.Task.data + 6, level); F.idle(4); F.press("A", 3); F.idle(60) end
    end
  end
  flushMenus()
  return partyCount() == before + 1 or (before == PARTY_SIZE and t ~= nil)
end

-- ---- battle state -------------------------------------------------------------------------------
local function bmon(b) return S.gBattleMons + b * BM.size end
local function bhp(b) return F.r16(bmon(b) + BM.hp) end
local function bmax(b) return F.r16(bmon(b) + BM.maxHP) end
local function bspecies(b) return F.r16(bmon(b)) end
local function setBhp(b, v) F.w16(bmon(b) + BM.hp, v) end
local function absent(b) return ((F.r8(S.gAbsentBattlerFlags) >> b) & 1) == 1 end
local function partyIndex(b) return F.r16(S.gBattlerPartyIndexes + b * 2) end
local function ctrl(b) return F.r32(S.gBattlerControllerFuncs + b * 4) & ~1 end

local function isAction(fn)
  for _, p in ipairs(S.ActionInputFunctions) do if fn == (p & ~1) then return true end end
  return false
end

-- Which player battler is waiting on input, and on what.
local function playerInput()
  for _, b in ipairs({ 0, 2 }) do
    if b < F.battlers() then
      local fn = ctrl(b)
      if isAction(fn) then return b, "action" end
      if fn == (S.HandleInputChooseMove & ~1) then return b, "move" end
      if fn == (S.HandleInputChooseTarget & ~1) then return b, "target" end
      if fn == (S.PlayerHandleYesNoInput & ~1) then return b, "yesno" end
    end
  end
  return nil, inBattle() and "text" or "screen"
end

-- Steer the action cursor (0 FIGHT, 1 BAG, 2 POKEMON, 3 RUN) to `want`, then A.
local function steer(b, want)
  local cur = F.r8(S.gActionSelectionCursor + b)
  if cur == want then return "A" end
  if (cur & 1) < (want & 1) then return "Right" end
  if (cur & 1) > (want & 1) then return "Left" end
  if (cur & 2) < (want & 2) then return "Down" end
  return "Up"
end

-- Steer the move cursor to slot `want` (2x2: 0 1 / 2 3), then A. A battler whose `want` slot is
-- empty (Magikarp knows only Splash) uses slot 0 instead.
local function moveTo(b, want)
  if F.r16(bmon(b) + BM.moves + want * 2) == 0 then want = 0 end
  local cur = F.r8(S.gMoveSelectionCursor + b)
  if cur == want then return "A" end
  if (cur & 1) ~= (want & 1) then return (cur & 1) < (want & 1) and "Right" or "Left" end
  return (cur & 2) < (want & 2) and "Down" or "Up"
end

-- Egg / fainted-mon guard, sampled every frame of every battle: no player battler may ever be
-- backed by an Egg, and a battler on the field must not be a party slot that is empty.
local eggSeen, eggDetail = false, ""
local currentScenario = ""
-- Only on the battle screen itself: the in-battle party menu shows the party in battle order by
-- physically reordering gParties while it is open, so gBattlerPartyIndexes does not index the
-- open menu's copy.
-- And only once the first action menu has been offered: during the intro gAbsentBattlerFlags is
-- not computed yet (TryDoEventsBeforeFirstTurn marks unusable slots absent), and gBattleMons[2]
-- already holds the Egg's data for a Pokemon + Egg party although nothing is sent out for it
-- (verified on screen: "Go! Zigzagoon!" alone, no second sprite or healthbox).
local function guardEggs(live)
  if not inBattle() or not live then return end
  for _, b in ipairs({ 0, 2 }) do
    if b < F.battlers() and not absent(b) and bspecies(b) ~= 0 then
      local s = partyIndex(b)
      if s < PARTY_SIZE then
        local m = monAt(partyAddr(s))
        if m.present and m.egg then
          eggSeen = true
          if eggDetail == "" then
            eggDetail = string.format("[%s] battler %d is party slot %d, an Egg (species %d), party n=%d"
              .. " f=%d bspecies=%d bhp=%d abs=%d ctrl=%08X",
              currentScenario, b, s, m.species, partyCount(), emu.framecount(), bspecies(b), bhp(b),
              F.r8(S.gAbsentBattlerFlags), ctrl(b))
            F.shot("egg_battler")
          end
        end
      end
    end
  end
end

-- Target-cursor guard: while a player battler is choosing a target, the cursor must never rest on
-- a battler that is absent or already fainted. Sampled every frame of every battle.
local targetBad, targetDetail, targetSamples = false, "", 0
local function guardTarget()
  for _, b in ipairs({ 0, 2 }) do
    if b < F.battlers() and ctrl(b) == (S.HandleInputChooseTarget & ~1) then
      local t = F.r8(S.gMultiUsePlayerCursor)
      if t < F.battlers() then
        targetSamples = targetSamples + 1
        if absent(t) or bhp(t) == 0 then
          targetBad = true
          targetDetail = string.format("battler %d's target cursor on battler %d (absent=%s hp=%d)",
            b, t, tostring(absent(t)), bhp(t))
        end
      end
    end
  end
end

-- Generic driver. `pol.key(b, kind, n)` returns a key (or a table of keys) every `gap` frames;
-- `pol.frame(i)` runs every frame (HP assists, observers). Returns when the field callback is
-- back, or on a crash, or when the budget runs out.
local TRACE = os.getenv("PW_DBL_TRACE")
local function drive(tag, budget, pol)
  local gap, key, n, lastSig, live = pol.gap or 8, nil, 0, "", false
  local lastVb, stall = vblank(), 0
  for i = 1, budget do
    if i % 30 == 0 then
      if F.reportCrash(tag) then return "crash", i end
      local vb = vblank()
      if vb == lastVb then stall = stall + 1 else stall = 0 end
      lastVb = vb
      if stall > 4 then return "frozen", i end
    end
    if F.ow() then return "field", i end
    if pol.stop and pol.stop(i) then return "stop", i end
    if not live then
      for _, x in ipairs({ 0, 2 }) do if x < F.battlers() and isAction(ctrl(x)) then live = true end end
    end
    guardEggs(live)
    guardTarget()
    if pol.frame then pol.frame(i) end
    local phase = i % gap
    if phase == 0 then
      local b, kind = playerInput()
      n = n + 1
      key = pol.key(b, kind, n)
      if TRACE then
        local sig = tostring(b) .. kind
        if sig ~= lastSig then
          lastSig = sig
          F.L(string.format("  t f%d b=%s %s key=%s cb2=%08X c0=%08X c2=%08X ac=%d,%d out=%d hp=%d/%d/%d/%d abs=%d",
            i, tostring(b), kind, type(key) == "table" and "mash" or tostring(key), F.cb2(), ctrl(0), ctrl(2),
            F.r8(S.gActionSelectionCursor), F.r8(S.gActionSelectionCursor + 2), F.outcome(),
            bhp(0), bhp(1), bhp(2), bhp(3), F.r8(S.gAbsentBattlerFlags)))
        end
      end
    end
    if key and phase < 2 then
      joypad.set(type(key) == "table" and key or { [key] = true })
    else
      joypad.set({})
    end
    emu.frameadvance()
  end
  return "budget", budget
end

-- Off the battle screen (party menu after a faint, Bag, summary, evolution): Down and A pick a
-- live party member for a forced switch, which refuses B.
local function screenKey(n) return ({ "Down", "A", "A", "B" })[n % 4 + 1] end

-- The in-battle party menu, driven by its cursor (gPartyMenu.slotId, struct PartyMenu +9). While
-- it is open gParties is in battle order, so slots 0 and 1 are the two on the field in a double;
-- the target is the first later slot holding a live non-Egg member. A on it opens
-- Shift / Summary / Cancel, and a second A takes Shift.
local PARTY_MENU_SLOT = 9
local partyPending = false
local function partyKey()
  local slot = F.rs8(S.gPartyMenu + PARTY_MENU_SLOT)
  local target
  for t = 2, partyCount() - 1 do
    local m = monAt(partyAddr(t))
    if m.present and not m.egg and monHp(t) > 0 then target = t; break end
  end
  if partyPending then partyPending = false; return "A" end
  if target == nil then return "B" end
  if slot == target then partyPending = true; return "A" end
  return "Down"
end

local function fightKey(b, kind, n)
  if kind == "action" then return steer(b, 0) end
  if kind == "move" or kind == "target" or kind == "text" then return "A" end
  if kind == "yesno" then return (n % 2 == 0) and "B" or "A" end
  return screenKey(n)
end

-- Trainer battles answer RUN with a forfeit Yes/No whose cursor starts on No: Up, then A.
local function runKey(b, kind, n)
  if kind == "action" then return steer(b, 3) end
  if kind == "move" then return "B" end
  if kind == "yesno" then return (n % 2 == 0) and "Up" or "A" end
  if kind == "text" then return "A" end
  return screenKey(n)
end

-- Keep the player's side alive and the wild side one hit from fainting.
local function assistWin(i)
  if i % 20 ~= 0 then return end
  for b = 0, F.battlers() - 1 do
    local h = bhp(b)
    if b % 2 == 1 and h > 1 then setBhp(b, 1) end
    if b % 2 == 0 and h > 0 then setBhp(b, bmax(b)) end
  end
end

-- Trainer mons hit far harder than the wild ones: pin their Attack and Sp. Atk to 1 (struct
-- BattlePokemon +2 and +8) and top the player's side up every frame, so a mash cannot lose.
local function assistTrainer(i)
  for b = 0, F.battlers() - 1 do
    if b % 2 == 1 then
      F.w16(bmon(b) + 2, 1); F.w16(bmon(b) + 8, 1)
      if i % 20 == 0 and bhp(b) > 1 then setBhp(b, 1) end
    elseif bhp(b) > 0 then
      setBhp(b, bmax(b))
    end
  end
end

-- Back to a walkable field after a battle: wait for the field, then prove control.
local function backToField(tag, budget)
  for i = 1, budget or 2400 do
    if F.reportCrash(tag) then return false, "crash" end
    if hasControl() then
      F.idle(20)
      if hasControl() then return true, "after " .. i end
    end
    if i % 40 == 0 then F.press("B", 2) else F.idle(1) end
  end
  return false, string.format("cb2=%08X lock=%d ctx=%d", F.cb2(), F.r8(S.sLockFieldControls),
    F.r8(S.sGlobalScriptContextStatus))
end

local function scenario(name, body)
  if ONLY and not name:find(ONLY, 1, true) then return end
  F.L("== " .. name .. " ==")
  currentScenario = name
  local ok, err = pcall(body)
  if not ok then F.check(name .. ": scenario ran without a Lua error", false, tostring(err)) end
  if not hasControl() then
    -- Leave the next scenario a usable field even if this one failed: run with the left
    -- Pokemon, then force a win and page through the end, as LevelUpSummary.lua does.
    F.L("  cleanup: battle or menu still up")
    if not F.ow() then drive("cleanup", 4000, { key = runKey }) end
    if not F.ow() then
      F.w8(S.gBattleOutcome, OUT_WON)
      for i = 1, 3000 do
        if F.ow() then break end
        F.press(i % 3 == 0 and "B" or "A", 2); F.idle(6)
      end
    end
    backToField("cleanup")
  end
end

local function checkBattleEnd(name, res, at, wantOutcomes)
  F.check(name .. ": no crash or freeze in battle", res ~= "crash" and res ~= "frozen", res .. " at " .. at)
  F.check(name .. ": the battle ended and the field callback returned", res == "field",
    string.format("%s at %d cb2=%08X", res, at, F.cb2()))
  local o = F.outcome()
  local okOutcome = false
  for _, w in ipairs(wantOutcomes) do if o == w then okOutcome = true end end
  F.check(name .. ": battle outcome is one the scenario allows", okOutcome, "outcome=" .. o)
  local ctlOk, how = backToField(name)
  F.check(name .. ": the player can move again", ctlOk, how)
  local sane, why = partySane()
  F.check(name .. ": party data is sane", sane, why)
  return ctlOk
end

local function ensureParty(builder)
  clearParty()
  builder()
  instantText()
end

-- A catch battle against two copies of `species`. Party slot 0 is a Zigzagoon with Flamethrower
-- then Celebrate (a single-target hit, then a move that touches nobody), slot 1 a Magikarp that
-- only Splashes.
--   phase "two":   both wild Pokemon stand. Each battler presses R (the last-used-ball shortcut)
--                  once, which must throw nothing, then Zigzagoon Flamethrowers the LEFT target
--                  (battler 1) through the target cursor and Magikarp Splashes.
--   phase "throw": battler 1 is down. Each battler presses R; once the Bag is empty Zigzagoon
--                  runs. The right target is kept at full HP so most balls miss.
-- Every BattleScript_BallThrow entry is counted, so the caller can compare throws with what left
-- the Bag.
local ACTION_THROW_BALL = 21
local function catchParty()
  scriptGiveMon(SPECIES_ZIGZAGOON, 10, { MOVE_FLAMETHROWER, MOVE_CELEBRATE, MOVE_SPLASH })
  scriptGiveMon(SPECIES_MAGIKARP, 5, { MOVE_SPLASH })
end
-- `ko` picks which wild battler is knocked out first (1 left, the default, or 3 right) and
-- `species2` the right-hand species when it should differ from the left.
local function catchBattleWith(tag, species, level, ball, after, ko, species2)
  ko = ko or 1
  local keep = (ko == 1) and 3 or 1
  local s = { census = census(), throws = 0, throwsWhileTwo = 0, qtyAfterTwo = -1, qtyBefore = itemQty(ball),
              leftFainted = false, doubleThrowTurn = false }
  if not F.check(tag .. ": a wild double started", startWildDouble(tag, species, level, species2 or species, level)) then
    return "nostart", 0, s
  end
  local phase, lastInstr, live = "two", 0, false
  local onMenu, rTried, waited, rTries = {}, {}, {}, 0
  local res, at = drive(tag, 30000, {
    frame = function(i)
      local instr = F.r32(S.gBattlescriptCurrInstr)
      if instr == S.BattleScript_BallThrow and lastInstr ~= instr then
        s.throws = s.throws + 1
        if phase == "two" then s.throwsWhileTwo = s.throwsWhileTwo + 1 end
      end
      lastInstr = instr
      if F.r8(S.gChosenActionByBattler) == ACTION_THROW_BALL
        and F.r8(S.gChosenActionByBattler + 2) == ACTION_THROW_BALL then s.doubleThrowTurn = true end
      if phase == "two" and live and (bhp(ko) == 0 or absent(ko)) then
        phase = "throw"; s.leftFainted = true
        s.qtyAfterTwo = itemQty(ball); s.qtyBefore = s.qtyAfterTwo
        F.L(string.format("  %s: left target down at frame %d, bag=%d", tag, i, s.qtyBefore))
      end
      if live and i % 10 == 0 then
        for _, b in ipairs({ 0, 2 }) do if bhp(b) > 0 then setBhp(b, bmax(b)) end end
        if bhp(keep) > 0 then setBhp(keep, bmax(keep)) end
        if phase == "two" and bhp(ko) > 1 then setBhp(ko, 1) end
      end
    end,
    key = function(b, kind, n)
      if after and s.throws > 0 then return after(kind, n) end
      for _, x in ipairs({ 0, 2 }) do if not (b == x and kind == "action") then onMenu[x] = false end end
      if kind == "action" then
        live = true
        if not onMenu[b] then onMenu[b] = true; rTried[b] = false; waited[b] = 0 end
        if not rTried[b] then
          if F.r8(S.gLastUsedBallMenuPresent) ~= 0 or phase == "two" or waited[b] >= 6 then
            rTried[b] = true
            if phase == "throw" then rTries = rTries + 1 end
            return "R"
          end
          waited[b] = waited[b] + 1; return nil
        end
        if phase == "throw" and b == 0 and (itemQty(ball) == 0 or rTries >= 3 and s.throws == 0) then return steer(b, 3) end
        return steer(b, 0)
      end
      if kind == "move" then return moveTo(b, (b == 0 and phase ~= "two") and 1 or 0) end
      if kind == "target" then
        if F.r8(S.gMultiUsePlayerCursor) == ko then return "A" end
        return "Left"  -- one direction: Left and Right alternately can bounce between two slots
      end
      if kind == "yesno" then return "B" end
      if kind == "text" then return "B" end
      return screenKey(n)
    end,
  })
  return res, at, s
end

-- ---- scenario helpers ---------------------------------------------------------------------------

local FLAG_QOL_SHARED_EXP = 0x21
local function setFlag(id, on)
  local a = F.sb1() + S.SaveBlock1.flags + (id // 8)
  local bit = 1 << (id % 8)
  F.w8(a, on and (F.r8(a) | bit) or (F.r8(a) & ~bit & 0xFF))
end

local function setMoney(v)
  F.w32(F.sb1() + S.SaveBlock1.money, v ~ F.r32(F.sb2() + S.SaveBlock2.encryptionKey))
end
local function healMap()
  local a = F.sb1() + S.SaveBlock1.lastHealLocation
  return F.rs8(a), F.rs8(a + 1)
end
local function aliveNonEgg()
  local n = 0
  for s = 0, partyCount() - 1 do
    local m = monAt(partyAddr(s))
    if m.present and not m.egg and monHp(s) > 0 then n = n + 1 end
  end
  return n
end

-- A wild double the player wins: the wild side is held at 1 HP and the player's at full, the
-- lead uses move slot 0 (Flamethrower in every party built here). With `peek`, the first action
-- menu opens POKEMON and backs out, which draws the in-battle party layout for this party shape.
local function winWildDouble(tag, peek)
  local seen = { lead = nil, partner = nil, absent2 = nil, peeked = false, menus = 0 }
  local live = false
  local res, at = drive(tag, 20000, {
    frame = function(i)
      if live and i % 10 == 0 then
        for b = 0, F.battlers() - 1 do
          local h = bhp(b)
          if b % 2 == 1 and h > 1 then setBhp(b, 1) end
          if b % 2 == 0 and h > 0 then setBhp(b, bmax(b)) end
        end
      end
    end,
    key = function(b, kind, n)
      if kind == "action" then
        live = true
        if seen.lead == nil then
          seen.lead = partyIndex(0); seen.absent2 = absent(2)
          seen.partner = (not absent(2)) and partyIndex(2) or nil
        end
        seen.menus = seen.menus + 1
        if peek and not seen.peeked and b == 0 then
          if F.r8(S.gActionSelectionCursor + b) == 2 then seen.peeked = true end
          return steer(b, 2)
        end
        return steer(b, 0)
      end
      if kind == "move" then
        local cur = F.r8(S.gMoveSelectionCursor + b)
        if cur == 0 then return "A" end
        return (cur & 1) == 1 and "Left" or "Up"
      end
      if kind == "screen" and peek then return "B" end
      return fightKey(b, kind, n)
    end,
  })
  return res, at, seen
end

local function onePartyCase(name, builder, wantLead, wantPartner)
  ensureParty(builder)
  fastBattles(true)
  local before = census()
  if not F.check(name .. ": a wild double started", startWildDouble(name, SPECIES_WURMPLE, 3, SPECIES_ZIGZAGOON, 3)) then return end
  F.check(name .. ": it is a double with four battler slots",
    (F.battleFlags() & B_DOUBLE) ~= 0 and F.battlers() == 4,
    string.format("flags=0x%X battlers=%d", F.battleFlags(), F.battlers()))
  local res, at, seen = winWildDouble(name, true)
  F.check(name .. ": the lead is the usable party slot", seen.lead == wantLead,
    string.format("lead slot=%s want=%d", tostring(seen.lead), wantLead))
  if wantPartner then
    F.check(name .. ": the partner is the next usable slot, not the Egg",
      seen.partner == wantPartner and not seen.absent2,
      string.format("partner=%s absent2=%s want=%d", tostring(seen.partner), tostring(seen.absent2), wantPartner))
  else
    F.check(name .. ": the second player slot stays empty", seen.absent2 == true,
      "absent2=" .. tostring(seen.absent2) .. " partner=" .. tostring(seen.partner))
  end
  F.check(name .. ": the in-battle party menu opened and closed", seen.peeked)
  checkBattleEnd(name, res, at, { OUT_WON })
  local after = census()
  F.check(name .. ": party and PC unchanged by the battle", after.total == before.total and after.dups == 0,
    string.format("total %d -> %d dups=%d", before.total, after.total, after.dups))
end

local function startTrainerDouble(tag)
  F.dbg(); F.idle(80)
  tap(ROW_TRAINERS); F.press("A", 3); F.idle(80)
  tap(1); F.press("A", 3); F.idle(50)
  F.press("Up", 3); F.idle(16)          -- Trainer 1: 0 -> 1
  F.press("A", 3); F.idle(80)
  tap(2); F.press("A", 3); F.idle(50)
  F.press("Up", 3); F.idle(16)
  F.press("Up", 3); F.idle(16)          -- Trainer 2: 0 -> 2
  F.press("A", 3); F.idle(80)
  tap(4); F.press("A", 3); F.idle(30)   -- Double Battle toggle as a belt
  F.press("Down", 3); F.idle(16)
  F.press("A", 3)                       -- Try Battle
  return waitBattle(tag, 1500)
end

-- Mash through the end of a battle: A, the D-pad, Start, L and R every frame, never B (it would
-- cancel an evolution) and never SELECT.
local endSeed = 0xD0B1E
local function endMashKeys()
  endSeed = (endSeed * 1103515245 + 12345) & 0x7FFFFFFF
  local t = {}
  for k, btn in ipairs({ "A", "Start", "L", "R", "Up", "Down", "Left", "Right" }) do
    if (endSeed >> (k + 5)) & 1 == 1 then t[btn] = true end
  end
  t.A = true
  return t
end

-- ---- scenarios ----------------------------------------------------------------------------------

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  instantText()

  -- 1. Doubles with every button mashed every frame until the battle ends. Each case gets its
  -- own seed; `skip` drops buttons from the mash. With no Right and the B run shortcut off, the
  -- cursor can never reach BAG or RUN, so the battle has to end through moves, switches and
  -- faints; B is also held back until the first action menu, because holding B through the
  -- intro is the QoL hold-B auto-run (ShouldHoldBAutoRun, src/battle_main.c), which flees any
  -- ordinary wild battle before the first turn. The trainer case also drops Left and Down: the Bag ignores B while a pocket switch
  -- animates, so a mash that holds Left/Right half the time keeps it open for thousands of frames,
  -- and RUN only offers a forfeit.
  local function mashCase(name, cfg)
    ensureParty(cfg.party)
    fastBattles(cfg.fast)
    if cfg.balls then clearBag(); scriptAddItem(ITEM_POKE_BALL, cfg.balls) end
    local n0 = partyCount()
    local before = census()
    if not F.check(name .. ": the battle started", cfg.start()) then return end
    F.check(name .. ": it is a double", (F.battleFlags() & B_DOUBLE) ~= 0 and F.battlers() == 4,
      string.format("flags=0x%X battlers=%d", F.battleFlags(), F.battlers()))
    local seed, seenMenu = cfg.seed, false
    local res, at = drive(name, 40000, {
      gap = 1,
      frame = cfg.assist or assistWin,
      key = function(_, kind)
        if kind == "action" then seenMenu = true end
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
        local t = {}
        for k, btn in ipairs({ "A", "B", "Start", "L", "R", "Up", "Down", "Left", "Right" }) do
          if (seed >> (k + 3)) & 1 == 1 and not (cfg.skip and cfg.skip[btn]) then t[btn] = true end
        end
        if cfg.noRun and not seenMenu then t.B = nil end
        return t
      end,
    })
    checkBattleEnd(name, res, at, cfg.outcomes)
    local after = census()
    F.check(name .. ": no Pokemon duplicated", after.dups == 0, "dups=" .. after.dups)
    F.check(name .. ": the party kept its members, plus at most one catch",
      partyCount() >= n0 and after.total >= before.total and after.total <= before.total + 1,
      string.format("n=%d -> %d total %d -> %d", n0, partyCount(), before.total, after.total))
    if cfg.balls then
      F.check(name .. ": the Bag never went negative", itemQty(ITEM_POKE_BALL) >= 0 and itemQty(ITEM_POKE_BALL) <= cfg.balls,
        "balls=" .. itemQty(ITEM_POKE_BALL))
    end
  end
  local wildStart = function() return startWildDouble("mash", SPECIES_WURMPLE, 3, SPECIES_ZIGZAGOON, 3) end
  local WILD_OUT = { OUT_WON, OUT_RAN, OUT_CAUGHT }

  scenario("mash wild double, debug party", function()
    mashCase("mash debug", { seed = 0x5EED, fast = false, start = wildStart, outcomes = WILD_OUT, party = function()
      setParty(); giveMon(SPECIES_ZIGZAGOON, 50); giveMon(SPECIES_POOCHYENA, 50)
    end })
  end)
  scenario("mash wild double, past the intro", function()
    mashCase("mash past intro", { seed = 0x1D7, fast = false, noRun = true, start = wildStart, outcomes = WILD_OUT,
      party = function()
        setParty(); giveMon(SPECIES_ZIGZAGOON, 50); giveMon(SPECIES_POOCHYENA, 50)
      end })
  end)
  scenario("mash wild double, balls in the Bag", function()
    mashCase("mash balls", { seed = 0xBA11, fast = false, balls = 10, start = wildStart, outcomes = WILD_OUT, party = function()
      scriptGiveMon(SPECIES_ZIGZAGOON, 10, { MOVE_FLAMETHROWER, MOVE_CELEBRATE, MOVE_SPLASH })
      scriptGiveMon(SPECIES_POOCHYENA, 10, { MOVE_TACKLE, MOVE_SPLASH })
      scriptGiveMon(SPECIES_MAGIKARP, 5, { MOVE_SPLASH })
    end })
  end)
  scenario("mash wild double, no way to RUN", function()
    setRunShortcut(RUN_SHORTCUT_OFF)
    mashCase("mash norun", { seed = 0x4E0, fast = true, skip = { Right = true }, noRun = true, start = wildStart,
      outcomes = { OUT_WON, OUT_CAUGHT }, party = function()
        scriptGiveMon(SPECIES_ZIGZAGOON, 10, { MOVE_FLAMETHROWER, MOVE_TACKLE })
        scriptGiveMon(SPECIES_POOCHYENA, 10, { MOVE_TACKLE })
        scriptGiveMon(SPECIES_MAGIKARP, 5, { MOVE_SPLASH })
      end })
    setRunShortcut(RUN_SHORTCUT_CURSOR)
  end)
  scenario("mash wild double, Egg in the party", function()
    mashCase("mash egg", { seed = 0xE66, fast = true, start = wildStart, outcomes = WILD_OUT, party = function()
      scriptGiveMon(SPECIES_ZIGZAGOON, 10, { MOVE_FLAMETHROWER, MOVE_TACKLE })
      scriptGiveEgg(SPECIES_TOGEPI)
      scriptGiveMon(SPECIES_MAGIKARP, 5, { MOVE_SPLASH })
    end })
  end)
  scenario("mash trainer double", function()
    mashCase("mash trainer", { seed = 0x7A1, fast = true, skip = { Down = true, Left = true, Right = true }, assist = assistTrainer, start = function() return startTrainerDouble("mash trainer") end,
      outcomes = { OUT_WON, 9 }, party = function()
        scriptGiveMon(SPECIES_ZIGZAGOON, 10, { MOVE_FLAMETHROWER, MOVE_TACKLE })
        scriptGiveMon(SPECIES_POOCHYENA, 10, { MOVE_TACKLE })
        scriptGiveMon(SPECIES_MAGIKARP, 5, { MOVE_SPLASH })
      end })
  end)

  -- 2. One usable Pokemon, and Eggs in the party.
  local ZIG = { MOVE_FLAMETHROWER, MOVE_CELEBRATE, MOVE_SPLASH }
  scenario("one usable: mon then Egg", function()
    onePartyCase("mon+egg", function()
      scriptGiveMon(SPECIES_ZIGZAGOON, 10, ZIG); scriptGiveEgg(SPECIES_TOGEPI)
    end, 0, nil)
  end)
  scenario("one usable: Egg lead", function()
    onePartyCase("egg+mon", function()
      scriptGiveEgg(SPECIES_TOGEPI); scriptGiveMon(SPECIES_ZIGZAGOON, 10, ZIG)
    end, 1, nil)
  end)
  scenario("one usable: two fainted", function()
    onePartyCase("fainted", function()
      scriptGiveMon(SPECIES_ZIGZAGOON, 10, ZIG)
      scriptGiveMon(SPECIES_MAGIKARP, 5, { MOVE_SPLASH })
      scriptGiveMon(SPECIES_POOCHYENA, 5, { MOVE_TACKLE })
      F.w16(partyAddr(1) + S.Pokemon.hp, 0); F.w16(partyAddr(2) + S.Pokemon.hp, 0)
    end, 0, nil)
    F.check("fainted: the fainted members are still fainted",
      monHp(1) == 0 and monHp(2) == 0, string.format("hp1=%d hp2=%d", monHp(1), monHp(2)))
  end)
  scenario("Egg in slot 2", function()
    onePartyCase("egg slot2", function()
      scriptGiveMon(SPECIES_ZIGZAGOON, 10, ZIG); scriptGiveEgg(SPECIES_TOGEPI)
      scriptGiveMon(SPECIES_MAGIKARP, 5, { MOVE_SPLASH })
    end, 0, 2)
  end)

  -- An Egg-only party (a World Transit gate boxes the party; a gift Egg can be all that is left)
  -- has nothing to fight a double with. Both entries must refuse without a battle AND hand the
  -- player back control: the natural entry simply returns, and the scripted entry must release
  -- the script that is waiting on dowildbattle. A Zigzagoon party through the same scripted entry
  -- is the control: there the battle does start.
  scenario("Egg-only party refuses a wild double", function()
    ensureParty(function() scriptGiveEgg(SPECIES_TOGEPI) end)
    F.check("egg only: the party is one Egg", partyCount() == 1 and monAt(partyAddr(0)).egg,
      "n=" .. partyCount())
    local function noBattle(tag, start)
      start()
      local sawBattle, freed = false, false
      for i = 1, 600 do
        F.idle(1)
        if not F.ow() or F.battleFlags() & B_DOUBLE ~= 0 and inBattle() then sawBattle = true end
        if i > 30 and hasControl() then freed = true; break end
        if i % 60 == 0 and F.reportCrash(tag) then break end
      end
      F.check(tag .. ": no battle started", not sawBattle, string.format("cb2=%08X", F.cb2()))
      F.check(tag .. ": the player has control again", freed,
        string.format("lock=%d ctx=%d", F.r8(S.sLockFieldControls), F.r8(S.sGlobalScriptContextStatus)))
    end
    F.w32(S.gBattleTypeFlags, 0)
    noBattle("egg only natural", function()
      local b = setWildBattleBytes(SPECIES_WURMPLE, 3, SPECIES_ZIGZAGOON, 3)
      b[#b + 1] = 0x23; le32(b, S.BattleSetup_StartDoubleWildBattle | 1)
      b[#b + 1] = 0x02
      runScript(b)
    end)
    local function unstick()
      if not hasControl() then
        -- Unstick a script left waiting so the cases below and later scenarios can run.
        F.w8(S.sGlobalScriptContextStatus, CONTEXT_SHUTDOWN); F.w8(S.sLockFieldControls, 0); F.idle(10)
      end
    end
    noBattle("egg only scripted", function()
      local b = setWildBattleBytes(SPECIES_WURMPLE, 3, SPECIES_ZIGZAGOON, 3)
      b[#b + 1] = 0xB7; b[#b + 1] = 0x02
      runScript(b)
    end)
    unstick()
    -- The same refusal on the single-species form, which is what the shipped static encounters
    -- (Sudowoodo, Red Gyarados, the box legendaries) run.
    noBattle("egg only scripted single", function()
      local b = setWildBattleBytes(SPECIES_WURMPLE, 3, 0, 0)
      b[#b + 1] = 0xB7; b[#b + 1] = 0x02
      runScript(b)
    end)
    unstick()
    ensureParty(function() scriptGiveMon(SPECIES_ZIGZAGOON, 10, ZIG) end)
    fastBattles(true)
    F.check("scripted control: the scripted wild double starts with a Pokemon to send",
      startScriptedWildDouble("scripted", SPECIES_WURMPLE, 3, SPECIES_ZIGZAGOON, 3))
    local res, at = winWildDouble("scripted", false)
    checkBattleEnd("scripted control", res, at, { OUT_WON })
  end)

  -- 3. Catching in a wild double.
  scenario("catch two then one", function()
    ensureParty(catchParty)
    fastBattles(true)
    clearBag(); scriptAddItem(ITEM_POKE_BALL, 5)
    F.check("catch: five Poke Balls in the Bag", itemQty(ITEM_POKE_BALL) == 5, "qty=" .. itemQty(ITEM_POKE_BALL))
    local res, at, s = catchBattleWith("catch", SPECIES_BELDUM, 5, ITEM_POKE_BALL)
    F.check("catch: the R shortcut threw nothing while both wild Pokemon stood",
      s.throwsWhileTwo == 0 and s.qtyAfterTwo == 5,
      string.format("throws=%d qty=%d", s.throwsWhileTwo, s.qtyAfterTwo))
    F.check("catch: the left wild Pokemon fainted to a targeted move", s.leftFainted)
    F.check("catch: a ball was thrown once only one target stood", s.throws > 0, "throws=" .. s.throws)
    F.check("catch: every ball thrown left the Bag",
      s.throws == s.qtyBefore - itemQty(ITEM_POKE_BALL),
      string.format("throws=%d bag %d -> %d", s.throws, s.qtyBefore, itemQty(ITEM_POKE_BALL)))
    checkBattleEnd("catch", res, at, { OUT_CAUGHT, OUT_RAN, OUT_WON })
    local after = census()
    F.check("catch: nothing duplicated", after.dups == 0, "dups=" .. after.dups)
    local caught = F.outcome() == OUT_CAUGHT and 1 or 0
    F.check("catch: exactly the caught Pokemon was added",
      after.total == s.census.total + caught
        and (after.species[SPECIES_BELDUM] or 0) == (s.census.species[SPECIES_BELDUM] or 0) + caught,
      string.format("total %d -> %d, caught=%d", s.census.total, after.total, caught))
  end)

  -- One ball, and both battlers press R in the same turn. A throw by the left Pokemon skips the
  -- right one's selection (gBattleStruct->throwingPokeBall), so the single ball can never be
  -- thrown twice; the count of BattleScript_BallThrow entries has to match what left the Bag.
  scenario("catch one ball both throw", function()
    ensureParty(catchParty)
    fastBattles(true)
    clearBag(); scriptAddItem(ITEM_POKE_BALL, 1)
    local res, at, s = catchBattleWith("oneball", SPECIES_BELDUM, 5, ITEM_POKE_BALL)
    F.check("one ball: the left wild Pokemon fainted to a targeted move", s.leftFainted)
    F.check("one ball: a ball was thrown", s.throws > 0, "throws=" .. s.throws)
    F.check("one ball: no more balls thrown than the Bag held",
      s.throws <= s.qtyBefore and s.throws == s.qtyBefore - itemQty(ITEM_POKE_BALL),
      string.format("throws=%d bag %d -> %d (both battlers chose a throw in one turn: %s)",
        s.throws, s.qtyBefore, itemQty(ITEM_POKE_BALL), tostring(s.doubleThrowTurn)))
    F.check("one ball: both battlers never had a throw queued in the same turn", not s.doubleThrowTurn)
    checkBattleEnd("one ball", res, at, { OUT_CAUGHT, OUT_RAN, OUT_WON })
    F.check("one ball: nothing duplicated", census().dups == 0)
  end)

  scenario("catch master ball", function()
    ensureParty(catchParty)
    fastBattles(true)
    clearBag(); scriptAddItem(ITEM_MASTER_BALL, 1)
    local res, at, s = catchBattleWith("master", SPECIES_BELDUM, 5, ITEM_MASTER_BALL)
    F.check("master: a ball was thrown at the one remaining target", s.throws == 1 and s.leftFainted,
      string.format("throws=%d leftFainted=%s", s.throws, tostring(s.leftFainted)))
    checkBattleEnd("master", res, at, { OUT_CAUGHT })
    local after = census()
    F.check("master: the caught Beldum joined the party, once",
      partyCount() == 3 and after.total == s.census.total + 1 and after.dups == 0
        and monAt(partyAddr(2)).species == SPECIES_BELDUM,
      string.format("n=%d total %d -> %d dups=%d slot2=%s", partyCount(), s.census.total, after.total,
        after.dups, tostring(monAt(partyAddr(2)).species)))
    F.check("master: the Master Ball left the Bag", itemQty(ITEM_MASTER_BALL) == 0)
  end)

  -- The mirror case: the RIGHT wild Pokemon is knocked out, so the ball has to go to the LEFT one
  -- (GetCatchingBattler). Different species on each side tell the two apart.
  scenario("catch the left target", function()
    ensureParty(catchParty)
    fastBattles(true)
    clearBag(); scriptAddItem(ITEM_MASTER_BALL, 1)
    local res, at, s = catchBattleWith("left", SPECIES_BELDUM, 5, ITEM_MASTER_BALL, nil, 3, SPECIES_WURMPLE)
    F.check("left: the right-hand Wurmple fainted first and one ball was thrown", s.leftFainted and s.throws == 1,
      string.format("koFirst=%s throws=%d", tostring(s.leftFainted), s.throws))
    checkBattleEnd("left", res, at, { OUT_CAUGHT })
    local after = census()
    F.check("left: the left-hand Beldum was the one caught",
      partyCount() == 3 and monAt(partyAddr(2)).species == SPECIES_BELDUM and after.total == s.census.total + 1
        and after.dups == 0 and (after.species[SPECIES_WURMPLE] or 0) == (s.census.species[SPECIES_WURMPLE] or 0),
      string.format("n=%d slot2=%s total %d -> %d", partyCount(), tostring(monAt(partyAddr(2)).species),
        s.census.total, after.total))
  end)

  scenario("catch full party and full PC", function()
    ensureParty(function()
      catchParty()
      for _ = 1, 4 do scriptGiveMon(SPECIES_POOCHYENA, 5, { MOVE_SPLASH }) end
    end)
    fillBoxes()
    fastBattles(true)
    local c = census()
    F.check("full: party of six and every box slot taken", partyCount() == 6 and c.total == 6 + BOX_SLOTS,
      string.format("n=%d total=%d", partyCount(), c.total))
    clearBag(); scriptAddItem(ITEM_MASTER_BALL, 1)
    local res, at, s = catchBattleWith("full", SPECIES_BELDUM, 5, ITEM_MASTER_BALL)
    F.check("full: no ball could be thrown with nowhere to put a catch", s.throws == 0 and s.leftFainted,
      string.format("throws=%d leftFainted=%s", s.throws, tostring(s.leftFainted)))
    checkBattleEnd("full", res, at, { OUT_RAN })
    local after = census()
    -- Fill PC Boxes Fast stamps one personality across every box slot, so duplicates are counted
    -- against that baseline rather than against zero.
    F.check("full: party and PC unchanged", after.total == c.total and after.dups == c.dups,
      string.format("total %d -> %d dups %d -> %d", c.total, after.total, c.dups, after.dups))
    F.check("full: the Master Ball is still in the Bag", itemQty(ITEM_MASTER_BALL) == 1)
  end)

  scenario("catch full party into PC", function()
    clearBoxes()
    ensureParty(function()
      catchParty()
      for _ = 1, 4 do scriptGiveMon(SPECIES_POOCHYENA, 5, { MOVE_SPLASH }) end
    end)
    fastBattles(true)
    clearBag(); scriptAddItem(ITEM_MASTER_BALL, 1)
    local res, at, s = catchBattleWith("topc", SPECIES_BELDUM, 5, ITEM_MASTER_BALL)
    checkBattleEnd("topc", res, at, { OUT_CAUGHT })
    local after = census()
    F.check("topc: the catch landed exactly once, in the party or the PC",
      partyCount() == 6 and after.total == s.census.total + 1 and after.dups == 0
        and (after.species[SPECIES_BELDUM] or 0) == 1,
      string.format("n=%d total %d -> %d dups=%d beldum=%d", partyCount(), s.census.total, after.total,
        after.dups, after.species[SPECIES_BELDUM] or 0))
    clearBoxes()
  end)

  -- Full party, room in the PC, and this time YES to "add it to your party": the party menu picks
  -- the member to box (slot 0, the cursor's starting row), its "send to the PC?" takes YES, the
  -- nickname prompt takes YES and the naming screen is confirmed with START then A.
  scenario("catch full party swap into party", function()
    clearBoxes()
    ensureParty(function()
      catchParty()
      for _ = 1, 4 do scriptGiveMon(SPECIES_POOCHYENA, 5, { MOVE_SPLASH }) end
    end)
    fastBattles(true)
    clearBag(); scriptAddItem(ITEM_MASTER_BALL, 1)
    local partyBefore = {}
    for k = 0, PARTY_SIZE - 1 do partyBefore[k] = monAt(partyAddr(k)).pid end
    local res, at, s = catchBattleWith("swap", SPECIES_BELDUM, 5, ITEM_MASTER_BALL, function(kind, n)
      if kind == "screen" then return ({ "A", "A", "Start", "A" })[n % 4 + 1] end
      return "A"
    end)
    checkBattleEnd("swap", res, at, { OUT_CAUGHT })
    local after = census()
    local inParty, left = {}, {}
    for k = 0, PARTY_SIZE - 1 do inParty[monAt(partyAddr(k)).pid] = true end
    for k = 0, PARTY_SIZE - 1 do if not inParty[partyBefore[k]] then left[#left + 1] = partyBefore[k] end end
    local beldumInParty = false
    for k = 0, PARTY_SIZE - 1 do if monAt(partyAddr(k)).species == SPECIES_BELDUM then beldumInParty = true end end
    F.check("swap: one catch added, nothing duplicated", after.total == s.census.total + 1 and after.dups == 0,
      string.format("total %d -> %d dups=%d", s.census.total, after.total, after.dups))
    F.check("swap: Beldum is in the party and exactly one member left it",
      partyCount() == 6 and beldumInParty and #left == 1,
      string.format("n=%d beldum=%s left=%d", partyCount(), tostring(beldumInParty), #left))
    F.check("swap: the member that left the party is in the PC", #left == 1 and after.pids[left[1]] == true)
    clearBoxes()
  end)

  -- The R last-used-ball shortcut after its display fell back to another ball. Catch with a
  -- Master Ball (gLastThrownBall = gBallToDisplay = Master Ball); next battle carry only Poke
  -- Balls, so the display falls back to the first ball in the pocket; then carry only a Master
  -- Ball again. The last thrown ball is back in the Bag and the shortcut has to offer it.
  scenario("R shortcut after the display fell back", function()
    ensureParty(catchParty)
    fastBattles(true)
    clearBag(); scriptAddItem(ITEM_MASTER_BALL, 1)
    local res, at, s = catchBattleWith("rs catch", SPECIES_BELDUM, 5, ITEM_MASTER_BALL)
    checkBattleEnd("rs catch", res, at, { OUT_CAUGHT })
    F.check("rs: the Master Ball is the last thrown ball", F.r16(S.gLastThrownBall) == ITEM_MASTER_BALL,
      "last=" .. F.r16(S.gLastThrownBall))

    ensureParty(catchParty)
    clearBag(); scriptAddItem(ITEM_POKE_BALL, 2)
    if F.check("rs fallback: a wild double started", startWildDouble("rs fallback", SPECIES_WURMPLE, 3, SPECIES_ZIGZAGOON, 3)) then
      local shown
      res, at = drive("rs fallback", 12000, {
        frame = function(i)
          if i % 10 == 0 then for _, b in ipairs({ 0, 2 }) do if bhp(b) > 0 then setBhp(b, bmax(b)) end end end
        end,
        key = function(b, kind, n)
          if kind == "action" and b == 0 and shown == nil then shown = F.r16(S.gBallToDisplay) end
          return runKey(b, kind, n)
        end,
      })
      F.check("rs fallback: with only Poke Balls the display fell back to them", shown == ITEM_POKE_BALL,
        "display=" .. tostring(shown))
      checkBattleEnd("rs fallback", res, at, { OUT_RAN })
    end

    ensureParty(catchParty)
    clearBag(); scriptAddItem(ITEM_MASTER_BALL, 1)
    res, at, s = catchBattleWith("rs again", SPECIES_BELDUM, 5, ITEM_MASTER_BALL)
    F.check("rs again: R threw the Master Ball once the left target was down", s.leftFainted and s.throws == 1,
      string.format("throws=%d display=%d last=%d", s.throws, F.r16(S.gBallToDisplay), F.r16(S.gLastThrownBall)))
    checkBattleEnd("rs again", res, at, { OUT_CAUGHT })
  end)

  -- The Bag from each player battler's menu in a double: open it, flip pockets, B out, and the
  -- battle screen has to come back promptly every time. Once with balls, once with an empty Bag.
  local function bagCase(tag, balls)
    ensureParty(catchParty)
    fastBattles(true)
    clearBag()
    if balls > 0 then scriptAddItem(ITEM_POKE_BALL, balls) end
    if not F.check(tag .. ": a wild double started", startWildDouble(tag, SPECIES_WURMPLE, 3, SPECIES_ZIGZAGOON, 3)) then return end
    local opened, slowest, visits, phase, since, pressedAt = { [0] = 0, [2] = 0 }, 0, 0, "menu", 0, 0
    local res, at = drive(tag, 20000, {
      frame = function(i)
        if i % 10 == 0 then for _, b in ipairs({ 0, 2 }) do if bhp(b) > 0 then setBhp(b, bmax(b)) end end end
        if phase == "opening" and not inBattle() then phase = "bag"; since = 0 end
        if phase == "bag" then
          since = since + 1
          if inBattle() then
            phase = "menu"; slowest = math.max(slowest, since - pressedAt); visits = visits + 1
          end
        end
      end,
      key = function(b, kind, n)
        if kind == "action" then
          if opened[b] < 1 then
            local k = steer(b, 1)
            if k == "A" then opened[b] = opened[b] + 1; phase = "opening"; since = 0; pressedAt = 0 end
            return k
          end
          -- Celebrate until both have been in the Bag, then the left one runs.
          return steer(b, (b == 0 and opened[2] >= 1) and 3 or 0)
        end
        if kind == "screen" then
          if since < 60 then return nil end
          if since < 120 then return (n % 2 == 0) and "Right" or "Left" end
          if pressedAt == 0 then pressedAt = since end
          return "B"
        end
        if kind == "move" then
          return moveTo(b, 1)
        end
        return runKey(b, kind, n)
      end,
    })
    F.check(tag .. ": the Bag was opened from both battlers' menus", opened[0] >= 1 and opened[2] >= 1 and visits >= 2,
      string.format("opened0=%d opened2=%d visits=%d", opened[0], opened[2], visits))
    F.check(tag .. ": B always got back to the battle within 400 frames of the first press", slowest > 0 and slowest < 400,
      "slowest=" .. slowest)
    checkBattleEnd(tag, res, at, { OUT_RAN })
    F.check(tag .. ": no ball used by opening and closing the Bag", itemQty(ITEM_POKE_BALL) == balls,
      "balls=" .. itemQty(ITEM_POKE_BALL))
  end
  scenario("bag in a double", function() bagCase("bag", 3) end)
  scenario("empty bag in a double", function() bagCase("empty bag", 0) end)

  -- Both player Pokemon faint in the same turn with two members on the bench: two forced
  -- replacements back to back, then the replacements win.
  scenario("both faint in one turn", function()
    ensureParty(function()
      scriptGiveMon(SPECIES_MAGIKARP, 5, { MOVE_SPLASH })
      scriptGiveMon(SPECIES_MAGIKARP, 5, { MOVE_SPLASH })
      scriptGiveMon(SPECIES_ZIGZAGOON, 10, { MOVE_FLAMETHROWER, MOVE_TACKLE })
      scriptGiveMon(SPECIES_POOCHYENA, 10, { MOVE_TACKLE })
    end)
    fastBattles(true)
    if not F.check("both faint: a wild double started", startWildDouble("bothfaint", SPECIES_POOCHYENA, 8, SPECIES_ZIGZAGOON, 8)) then return end
    local live, bothDown, phase = false, false, "sacrifice"
    local res, at = drive("bothfaint", 30000, {
      frame = function(i)
        if not live or not inBattle() then return end
        if bhp(0) == 0 and bhp(2) == 0 and not absent(0) and not absent(2) then bothDown = true end
        if phase == "sacrifice" and partyIndex(0) >= 2 and partyIndex(2) >= 2 then phase = "win" end
        if i % 5 == 0 then
          for _, b in ipairs({ 0, 2 }) do
            if phase == "sacrifice" and partyIndex(b) < 2 and bhp(b) > 1 then setBhp(b, 1) end
            if partyIndex(b) >= 2 and bhp(b) > 0 then setBhp(b, bmax(b)) end
          end
          for _, b in ipairs({ 1, 3 }) do
            if phase == "sacrifice" and bhp(b) > 0 then setBhp(b, bmax(b)) end
            if phase == "win" and bhp(b) > 1 then setBhp(b, 1) end
          end
        end
      end,
      key = function(b, kind, n)
        if kind == "action" then live = true; return steer(b, 0) end
        if kind == "screen" then return partyKey() end
        if kind == "move" then return moveTo(b, 0) end
        return fightKey(b, kind, n)
      end,
    })
    F.check("both faint: both player Pokemon were down at once", bothDown)
    F.check("both faint: both slots were refilled from the bench", phase == "win",
      string.format("slots %d,%d", partyIndex(0), partyIndex(2)))
    checkBattleEnd("both faint", res, at, { OUT_WON })
    F.check("both faint: the two Magikarp are still fainted, the bench is not",
      monHp(0) == 0 and monHp(1) == 0 and monHp(2) > 0 and monHp(3) > 0,
      string.format("hp=%d,%d,%d,%d", monHp(0), monHp(1), monHp(2), monHp(3)))
  end)

  -- The left Pokemon fainted with nobody to replace it, so the right-hand one throws: the ball
  -- comes from battler 2, not the usual thrower.
  scenario("catch by the right-hand Pokemon", function()
    ensureParty(catchParty)
    fastBattles(true)
    clearBag(); scriptAddItem(ITEM_MASTER_BALL, 1)
    local before = census()
    if not F.check("right throw: a wild double started", startWildDouble("rthrow", SPECIES_BELDUM, 5, SPECIES_WURMPLE, 3)) then return end
    local live, rTried, thrownBy, waitR = false, false, nil, 0
    local res, at = drive("rthrow", 20000, {
      frame = function(i)
        if not live then return end
        if F.r8(S.gChosenActionByBattler + 2) == ACTION_THROW_BALL then thrownBy = 2 end
        if i % 5 == 0 then
          if bhp(0) > 1 then setBhp(0, 1) end
          if bhp(2) > 0 then setBhp(2, bmax(2)) end
          if bhp(3) > 1 then setBhp(3, 1) end
          if bhp(1) > 0 then setBhp(1, bmax(1)) end
        end
      end,
      key = function(b, kind, n)
        if kind == "action" then
          live = true
          if b == 2 and absent(0) and (absent(3) or bhp(3) == 0) then
            if F.r8(S.gLastUsedBallMenuPresent) == 0 and waitR < 8 then waitR = waitR + 1; return nil end
            rTried = true; return "R"
          end
          return steer(b, 0)
        end
        if kind == "move" then return moveTo(b, (bhp(3) == 0 or absent(3)) and 1 or 0) end
        if kind == "target" then
          if F.r8(S.gMultiUsePlayerCursor) == 3 or bhp(3) == 0 or absent(3) then return "A" end
          return "Left"
        end
        if kind == "yesno" or kind == "text" then return "B" end
        return screenKey(n)
      end,
    })
    F.check("right throw: the right-hand Pokemon threw the ball", thrownBy == 2 and rTried,
      "thrownBy=" .. tostring(thrownBy))
    checkBattleEnd("right throw", res, at, { OUT_CAUGHT })
    local after = census()
    F.check("right throw: Beldum caught once", after.total == before.total + 1 and after.dups == 0
      and (after.species[SPECIES_BELDUM] or 0) == (before.species[SPECIES_BELDUM] or 0) + 1,
      string.format("total %d -> %d", before.total, after.total))
  end)

  -- A Potion picked from the Bag by the left Pokemon (for itself, the first row of the party
  -- panel) is removed from the Bag at selection (BagMenu_BattleApplyItem). If the right-hand
  -- Pokemon then presses B to go back to the left one, the controller must hand the Potion back
  -- (the B_ACTION_CANCEL_PARTNER refund), exactly once. Then the same use is let through, and the
  -- Potion must be spent and the Pokemon healed.
  scenario("potion then cancel partner", function()
    ensureParty(catchParty)
    fastBattles(true)
    clearBag(); scriptAddItem(ITEM_POTION, 3)
    if not F.check("potion: a wild double started", startWildDouble("potion", SPECIES_WURMPLE, 3, SPECIES_ZIGZAGOON, 3)) then return end
    local step, polls, qtyAtCancel, qtyAfterCancel, partnerHp0, healedHp = "bag", 0, -1, -1, 0, -1
    local cancelled, used = false, false
    local res, at = drive("potion", 20000, {
      frame = function(i)
        if bhp(2) > 0 then setBhp(2, bmax(2)) end
        -- Keep the left Pokemon hurt until the real use, so the Potion has something to heal.
        -- Both copies: the Bag checks the party struct, the battle reads gBattleMons.
        if (step == "bag" or step == "cancelled" or step == "bag2") and inBattle() and bhp(0) > 5 then
          setBhp(0, 5); F.w16(partyAddr(partyIndex(0)) + S.Pokemon.hp, 5)
        end
      end,
      key = function(b, kind, n)
        if kind == "action" and b == 0 then
          if step == "bag" or step == "bag2" then
            F.w8(S.gBagPosition + 5, 0)   -- open on the Items pocket
            polls = 0
            return steer(b, 1)
          end
          if step == "run" then return steer(b, 3) end
          return steer(b, 0)
        end
        if kind == "action" and b == 2 then
          if step == "bag" then
            step = "cancelled"; cancelled = true; qtyAtCancel = itemQty(ITEM_POTION); return "B"
          end
          if step == "cancelled" then qtyAfterCancel = itemQty(ITEM_POTION) end
          if step == "bag2" then step = "used"; partnerHp0 = bhp(0) end
          return steer(b, 0)
        end
        if kind == "screen" then
          polls = polls + 1
          -- Bag: A on the Potion, A on Use, A on the first row of the party panel, 40 frames
          -- apart so none lands while a panel animates; B out only if that did not take.
          if polls % 5 == 0 and polls <= 15 then return "A" end
          if polls > 30 then return "B" end
          return nil
        end
        if kind == "move" then return moveTo(b, 1) end
        return fightKey(b, kind, n)
      end,
      stop = function()
        if step == "cancelled" and qtyAfterCancel >= 0 then step = "bag2" end
        if step == "used" and F.r8(S.gActionSelectionCursor) ~= 255 and isAction(ctrl(0)) then
          used = true; healedHp = bhp(0); step = "run"
        end
        return false
      end,
    })
    F.check("potion: the Potion left the Bag when it was picked", qtyAtCancel == 2, "qty at cancel=" .. qtyAtCancel)
    F.check("potion: B on the partner's menu handed it back, once", cancelled and qtyAfterCancel == 3,
      "qty after cancel=" .. qtyAfterCancel)
    F.check("potion: used for real the second time, the Pokemon was healed", used and healedHp > partnerHp0,
      string.format("hp %d -> %d", partnerHp0, healedHp))
    checkBattleEnd("potion", res, at, { OUT_RAN })
    F.check("potion: exactly one Potion was spent", itemQty(ITEM_POTION) == 2, "qty=" .. itemQty(ITEM_POTION))
  end)

  -- 4. Running, and whiting out.
  scenario("run from wild double", function()
    ensureParty(catchParty)
    fastBattles(true)
    if not F.check("run: a wild double started", startWildDouble("run", SPECIES_WURMPLE, 3, SPECIES_ZIGZAGOON, 3)) then return end
    local res, at = drive("run", 12000, { key = runKey, frame = function(i)
      if i % 10 == 0 then for _, b in ipairs({ 0, 2 }) do if bhp(b) > 0 then setBhp(b, bmax(b)) end end end
    end })
    checkBattleEnd("run", res, at, { OUT_RAN })
  end)

  -- The right-hand Pokemon may not run from a wild double while the left one stands
  -- (IsRunningFromBattleImpossible). Pick RUN on it twice, which must be refused and hand the menu
  -- back, then B (cancel partner) to return to the left Pokemon, and run with that one.
  scenario("partner runs from wild double", function()
    ensureParty(catchParty)
    fastBattles(true)
    if not F.check("partner run: a wild double started", startWildDouble("prun", SPECIES_WURMPLE, 3, SPECIES_ZIGZAGOON, 3)) then return end
    local tries, refused, cancelled, leftMenus, onRight = 0, 0, false, 0, false
    local res, at = drive("prun", 12000, {
      frame = function(i)
        if i % 10 == 0 then for _, b in ipairs({ 0, 2 }) do if bhp(b) > 0 then setBhp(b, bmax(b)) end end end
      end,
      key = function(b, kind, n)
        if kind == "action" and b == 2 then
          if not onRight then
            onRight = true
            if tries > 0 then refused = refused + 1 end
          end
          if tries < 2 then
            local k = steer(b, 3)
            if k == "A" then tries = tries + 1; onRight = false end
            return k
          end
          cancelled = true
          return "B"
        end
        if kind == "action" and b == 0 then
          leftMenus = leftMenus + 1
          return steer(b, cancelled and 3 or 0)
        end
        if kind == "move" then
          return moveTo(b, 1)
        end
        return runKey(b, kind, n)
      end,
    })
    F.check("partner run: RUN on the right-hand Pokemon was refused and the menu came back",
      tries == 2 and refused >= 2, string.format("tries=%d refused=%d", tries, refused))
    F.check("partner run: B on the right-hand menu went back to the left Pokemon", cancelled and leftMenus >= 2,
      string.format("cancelled=%s leftMenus=%d", tostring(cancelled), leftMenus))
    checkBattleEnd("partner run", res, at, { OUT_RAN })
  end)

  -- The QoL B-button run shortcut set to flee at once (OPTIONS_RUN_SHORTCUT_INSTANT). In a double,
  -- B on the right-hand Pokemon's menu must still cancel back to the left one while that one
  -- stands; B on the left one flees. With the left one fainted and nobody to replace it, B on the
  -- right one is the flee.
  scenario("instant run shortcut in a double", function()
    ensureParty(catchParty)
    fastBattles(true)
    setRunShortcut(RUN_SHORTCUT_INSTANT)
    if not F.check("instant: a wild double started", startWildDouble("instant", SPECIES_WURMPLE, 3, SPECIES_ZIGZAGOON, 3)) then return end
    local rightB, leftAfter, leftB = false, 0, false
    local res, at = drive("instant", 12000, {
      frame = function(i)
        if i % 10 == 0 then for _, b in ipairs({ 0, 2 }) do if bhp(b) > 0 then setBhp(b, bmax(b)) end end end
      end,
      key = function(b, kind, n)
        if kind == "action" and b == 2 then
          if not rightB then rightB = true; return "B" end
          return steer(b, 0)
        end
        if kind == "action" and b == 0 then
          if rightB then leftAfter = leftAfter + 1; leftB = true; return "B" end
          return steer(b, 0)
        end
        if kind == "move" then return moveTo(b, 1) end
        return fightKey(b, kind, n)
      end,
    })
    F.check("instant: B on the right-hand menu went back to the left Pokemon instead of fleeing",
      rightB and leftAfter >= 1, string.format("rightB=%s leftMenusAfter=%d", tostring(rightB), leftAfter))
    checkBattleEnd("instant", res, at, { OUT_RAN })

    -- Left Pokemon down, no replacement: the right one's B flees.
    ensureParty(catchParty)
    if not F.check("instant alone: a wild double started", startWildDouble("instant2", SPECIES_WURMPLE, 3, SPECIES_ZIGZAGOON, 3)) then
      setRunShortcut(RUN_SHORTCUT_CURSOR); return
    end
    local live, fledFromRight = false, false
    res, at = drive("instant2", 20000, {
      frame = function(i)
        if live and i % 5 == 0 then
          if bhp(0) > 1 then setBhp(0, 1) end
          if bhp(2) > 0 then setBhp(2, bmax(2)) end
        end
      end,
      key = function(b, kind, n)
        if kind == "action" then
          live = true
          if b == 2 and absent(0) then fledFromRight = true; return "B" end
          return steer(b, 0)
        end
        if kind == "move" then return moveTo(b, 1) end
        return fightKey(b, kind, n)
      end,
    })
    F.check("instant alone: the left Pokemon fainted and B on the right one fled", fledFromRight)
    checkBattleEnd("instant alone", res, at, { OUT_RAN })
    setRunShortcut(RUN_SHORTCUT_CURSOR)
  end)

  scenario("white out in a double", function()
    ensureParty(function()
      scriptGiveMon(SPECIES_MAGIKARP, 5, { MOVE_SPLASH })
      scriptGiveMon(SPECIES_MAGIKARP, 5, { MOVE_SPLASH })
    end)
    fastBattles(true)
    setMoney(5000)
    local hg, hm = healMap()
    if not F.check("whiteout: a wild double started", startWildDouble("whiteout", SPECIES_BELDUM, 20, SPECIES_BELDUM, 20)) then return end
    local live = false
    local res, at = drive("whiteout", 20000, {
      frame = function(i)
        if live and i % 10 == 0 then
          for _, b in ipairs({ 0, 2 }) do if bhp(b) > 1 then setBhp(b, 1) end end
          for _, b in ipairs({ 1, 3 }) do if bhp(b) > 0 then setBhp(b, bmax(b)) end end
        end
      end,
      key = function(b, kind, n) if kind == "action" then live = true end return fightKey(b, kind, n) end,
    })
    checkBattleEnd("whiteout", res, at, { OUT_LOST })
    local healed = true
    for s = 0, partyCount() - 1 do if monHp(s) ~= monMaxHp(s) then healed = false end end
    F.check("whiteout: the party was healed", healed and partyCount() == 2,
      string.format("n=%d hp=%d/%d,%d/%d", partyCount(), monHp(0), monMaxHp(0), monHp(1), monMaxHp(1)))
    local m = F.money()
    F.check("whiteout: money went down and did not wrap", m < 5000 and m >= 0, "money=" .. m)
    F.check("whiteout: the player respawned on the last heal map", F.grp() == hg and F.mapn() == hm,
      string.format("at %d.%d heal %d.%d", F.grp(), F.mapn(), hg, hm))
  end)

  -- 5. Trainer double: the party faints down to one, forced and voluntary switches, then a
  -- level-up and an evolution at the end while the buttons are mashed.
  scenario("trainer double down to one", function()
    ensureParty(function()
      scriptGiveMon(SPECIES_CATERPIE, 6, { MOVE_TACKLE })
      scriptGiveMon(SPECIES_MAGIKARP, 5, { MOVE_SPLASH })
      scriptGiveMon(SPECIES_POOCHYENA, 5, { MOVE_SPLASH })
      scriptGiveMon(SPECIES_ZIGZAGOON, 5, { MOVE_SPLASH })
    end)
    fastBattles(true)
    setMoney(1000)
    F.check("trainer: party of four built", partyCount() == 4, "n=" .. partyCount())
    if not F.check("trainer: a trainer double started", startTrainerDouble("trainer")) then return end
    F.check("trainer: battle type is a trainer double",
      (F.battleFlags() & B_DOUBLE) ~= 0 and (F.battleFlags() & B_TRAINER) ~= 0,
      string.format("flags=0x%X battlers=%d", F.battleFlags(), F.battlers()))
    local live, phase = false, "sacrifice"
    local st = { voluntary = false, forced = 0, downToOne = false, absent2 = false, box = false, evo = false,
                 lastPartner = nil, partnerHp = 0, forcedB = 0 }
    local screenPolls = 0
    local res, at = drive("trainer", 40000, {
      frame = function(i)
        if F.r8(S.sLevelUpSummaryState) == 3 then st.box = true end
        if F.cb2() == (S.CB2_EvolutionSceneUpdate & ~1) then st.evo = true end
        if not live or not inBattle() then return end
        -- Caterpie (battler 0) must survive every hit: it is the one that levels and evolves. The
        -- trainers' Attack and Sp. Atk are pinned to 1 (struct BattlePokemon +2 and +8) so no hit
        -- is a one-frame KO, and its HP is topped up; a partner at 1 HP still faints to any hit.
        for _, b in ipairs({ 1, 3 }) do F.w16(bmon(b) + 2, 1); F.w16(bmon(b) + 8, 1) end
        if bhp(0) > 0 and partyIndex(0) == 0 then setBhp(0, bmax(0)) end
        local p = absent(2) and nil or partyIndex(2)
        if p ~= st.lastPartner and st.lastPartner ~= nil and p ~= nil then
          if st.partnerHp == 0 then st.forced = st.forced + 1 else st.voluntary = true end
        end
        if p ~= nil then st.lastPartner = p; st.partnerHp = bhp(2) end
        if phase == "sacrifice" and aliveNonEgg() == 1 then
          phase = "finish"; st.downToOne = true
          F.L(string.format("  trainer: down to one at frame %d", i))
        end
        if phase == "finish" and absent(2) then st.absent2 = true end
        if i % 10 == 0 then
          for _, b in ipairs({ 1, 3 }) do
            if phase == "sacrifice" and bhp(b) > 0 then setBhp(b, bmax(b)) end
            if phase == "finish" and bhp(b) > 1 then setBhp(b, 1) end
          end
          if phase == "sacrifice" and st.voluntary and bhp(2) > 1 then setBhp(2, 1) end
        end
      end,
      key = function(b, kind, n)
        if F.outcome() ~= 0 then return endMashKeys() end
        if kind == "action" then
          live = true
          if b == 2 and not st.voluntary and phase == "sacrifice" then return steer(b, 2) end
          return steer(b, 0)
        end
        if kind == "screen" then
          -- A forced replacement refuses B: press it three times first, and the menu must stay.
          if st.voluntary and st.partnerHp == 0 and screenPolls < 3 then
            screenPolls = screenPolls + 1
            st.forcedB = st.forcedB + 1
            return "B"
          end
          return partyKey()
        end
        screenPolls = 0
        return fightKey(b, kind, n)
      end,
    })
    F.check("trainer: B was pressed on a forced replacement menu", st.forcedB >= 3, "presses=" .. st.forcedB)
    F.check("trainer: a voluntary switch happened mid-double", st.voluntary)
    F.check("trainer: a fainted partner was replaced through the forced switch", st.forced >= 1, "forced=" .. st.forced)
    F.check("trainer: the party went down to its last Pokemon in battle", st.downToOne)
    F.check("trainer: the empty partner slot stayed empty with nobody left to send", st.absent2)
    checkBattleEnd("trainer", res, at, { OUT_WON })
    F.check("trainer: the level-up summary box came up in a double", st.box)
    F.check("trainer: the evolution scene ran", st.evo)
    local m0 = monAt(partyAddr(0))
    F.check("trainer: Caterpie evolved into Metapod", m0.species == SPECIES_METAPOD,
      "slot0 species=" .. tostring(m0.species))
    F.check("trainer: the fainted members stayed fainted and the count held",
      partyCount() == 4 and monHp(1) == 0 and monHp(2) == 0 and monHp(3) == 0,
      string.format("n=%d hp=%d,%d,%d", partyCount(), monHp(1), monHp(2), monHp(3)))
    F.check("trainer: prize money was paid", F.money() > 1000, "money=" .. F.money())
  end)

  -- The level-up and evolution again, this time on the RIGHT-hand Pokemon of a wild double after
  -- the left one fainted with nobody to replace it. Cmd_getexp always sends the EXP update
  -- through battler 0's controller, which is then an absent battler.
  scenario("right-hand Pokemon levels and evolves alone", function()
    ensureParty(function()
      scriptGiveMon(SPECIES_MAGIKARP, 5, { MOVE_SPLASH })
      scriptGiveMon(SPECIES_CATERPIE, 6, { MOVE_TACKLE })
    end)
    fastBattles(true)
    if not F.check("right evo: a wild double started", startWildDouble("rightevo", SPECIES_POOCHYENA, 12, SPECIES_ZIGZAGOON, 12)) then return end
    local live, phase, box, evo, alone = false, "sacrifice", false, false, false
    local res, at = drive("rightevo", 30000, {
      frame = function(i)
        if F.r8(S.sLevelUpSummaryState) == 3 then box = true end
        if F.cb2() == (S.CB2_EvolutionSceneUpdate & ~1) then evo = true end
        if not live or not inBattle() then return end
        for _, b in ipairs({ 1, 3 }) do F.w16(bmon(b) + 2, 1); F.w16(bmon(b) + 8, 1) end
        if bhp(2) > 0 then setBhp(2, bmax(2)) end
        if phase == "sacrifice" and absent(0) then phase = "finish"; alone = true end
        if i % 5 == 0 then
          if phase == "sacrifice" and bhp(0) > 1 then setBhp(0, 1) end
          for _, b in ipairs({ 1, 3 }) do
            if phase == "sacrifice" and bhp(b) > 0 then setBhp(b, bmax(b)) end
            if phase == "finish" and bhp(b) > 1 then setBhp(b, 1) end
          end
        end
      end,
      key = function(b, kind, n)
        if F.outcome() ~= 0 then return endMashKeys() end
        if kind == "action" then live = true; return steer(b, 0) end
        return fightKey(b, kind, n)
      end,
    })
    F.check("right evo: the left Pokemon fainted and its slot stayed empty", alone)
    checkBattleEnd("right evo", res, at, { OUT_WON })
    F.check("right evo: the level-up summary box came up", box)
    F.check("right evo: the evolution scene ran", evo)
    F.check("right evo: Caterpie evolved into Metapod in its own slot",
      monAt(partyAddr(1)).species == SPECIES_METAPOD and monAt(partyAddr(0)).species == SPECIES_MAGIKARP and monHp(0) == 0,
      string.format("slot0=%s hp=%d slot1=%s", tostring(monAt(partyAddr(0)).species), monHp(0),
        tostring(monAt(partyAddr(1)).species)))
  end)

  -- With the SHARED EXP option on (FLAG_QOL_SHARED_EXP, I_EXP_SHARE_FLAG), a benched Pokemon with
  -- four moves levels through the shared EXP and is offered a fifth at the
  -- end of a double, while A and the D-pad are mashed through the forget-a-move prompt and the
  -- move summary screen. Whatever the mash chose, the moves must stay four valid, distinct ones.
  scenario("move learning at the end of a double", function()
    ensureParty(function()
      scriptGiveMon(SPECIES_ZIGZAGOON, 10, { MOVE_FLAMETHROWER, MOVE_TACKLE })
      scriptGiveMon(SPECIES_POOCHYENA, 10, { MOVE_TACKLE })
      scriptGiveMon(SPECIES_MAGIKARP, 14, { MOVE_SPLASH, MOVE_CELEBRATE, MOVE_FLAMETHROWER, MOVE_PROTECT })
    end)
    fastBattles(true)
    setFlag(FLAG_QOL_SHARED_EXP, true)
    local lv0 = F.r8(partyAddr(2) + S.Pokemon.level)
    if not F.check("learn: a wild double started", startWildDouble("learn", SPECIES_POOCHYENA, 45, SPECIES_ZIGZAGOON, 45)) then return end
    local live = false
    local res, at = drive("learn", 40000, {
      frame = function(i)
        if not live or not inBattle() then return end
        for _, b in ipairs({ 1, 3 }) do F.w16(bmon(b) + 2, 1); F.w16(bmon(b) + 8, 1) end
        for _, b in ipairs({ 0, 2 }) do if bhp(b) > 0 then setBhp(b, bmax(b)) end end
        if i % 10 == 0 then for _, b in ipairs({ 1, 3 }) do if bhp(b) > 1 then setBhp(b, 1) end end end
      end,
      key = function(b, kind, n)
        if F.outcome() ~= 0 then return endMashKeys() end
        if kind == "action" then live = true; return steer(b, 0) end
        if kind == "move" then return moveTo(b, 0) end
        return fightKey(b, kind, n)
      end,
    })
    checkBattleEnd("learn", res, at, { OUT_WON })
    setFlag(FLAG_QOL_SHARED_EXP, false)
    local lv1 = F.r8(partyAddr(2) + S.Pokemon.level)
    local mv = monMoves(partyAddr(2))
    local distinct, valid = true, true
    for k = 1, 4 do
      if mv[k] == 0 or mv[k] >= 1000 then valid = false end
      for j = k + 1, 4 do if mv[k] == mv[j] then distinct = false end end
    end
    F.check("learn: the benched Magikarp levelled past 15 through the shared EXP", lv1 >= 15 and lv1 > lv0,
      string.format("level %d -> %d", lv0, lv1))
    F.check("learn: it still knows four valid, distinct moves", valid and distinct,
      string.format("moves=%d,%d,%d,%d", mv[1], mv[2], mv[3], mv[4]))
  end)

  F.check("target cursors were sampled", targetSamples > 0, "samples=" .. targetSamples)
  F.check("no target cursor rested on an absent or fainted battler", not targetBad, targetDetail)
  F.check("no Egg was ever sent into battle", not eggSeen, eggDetail)
  F.finish()
end)
