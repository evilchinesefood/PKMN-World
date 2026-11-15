-- The special Pokemon rules, with real input: no evolution by any path, the themed move through
-- the Move Reminder, and no breeding at the Day Care.
--
-- Evolution: a Thunder Stone on each special Pikachu and every Eevee stone (Fire, Water, Thunder,
-- Leaf, Ice, Sun, Moon, Shiny) on Flower Crown Eevee from the Bag must do nothing and keep the
-- stone; Rare Candies past Squirtle's (16) and Totodile's (18) evolution levels must level them up
-- without an evolution scene; and a won battle with shared EXP must level Squad Squirtle and
-- Pirate Totodile past those levels without evolving them. Each path has an ordinary control that
-- does evolve (Pikachu with a Thunder Stone, Squirtle with a Rare Candy, Squirtle in the battle).
-- Move Reminder: Classic Cap Pikachu with one move must be offered Thunderbolt and learn it.
-- Day Care (Route 34): Classic Cap Pikachu with Ditto must get the "prefer to play with other
-- POKEMON" verdict and no Egg after 1600 steps; ordinary Pikachu with Ditto (control) gets one.
--
-- Special Pokemon come from the debug Give menu (the same species and level as the catalog; the
-- source NPCs are covered by FlowerCrownQuestStorage, SpecialPokemonStorageStress and
-- SpecialPokemonCatchRecovery). PW_RULES_ONLY=<text> runs the scenarios whose tag contains <text>.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/SpecialPokemonRules.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SpecialPokemonRules")

local ONLY = os.getenv("PW_RULES_ONLY")
local MON = S.Pokemon.size
local POCKET_ITEMS = 0
local USM_ICO_BAG = 2
local FLAG_SYS_POKEMON_GET, FLAG_SHARED_EXP, FLAG_PIRATE_UNLOCKED = 0x948, 0x21, 0xDE1
local ITEM = { candy = 102, fire = 211, water = 212, thunder = 213, leaf = 214, ice = 215, sun = 216, moon = 217, shiny = 218 }
local SP = { pikachu = 25, raichu = 26, squirtle = 7, wartortle = 8, ditto = 132, pidgey = 16, mewtwo = 150,
             classic = 1573, surfboard = 1574, balloons = 1575, squad = 1576, firefighter = 1577, flower = 1578, pirate = 1580 }
local MOVE_THUNDERBOLT = 85

local function flag(id, value)
  local address, bit = F.sb1() + S.SaveBlock1.flags + id // 8, 1 << (id % 8)
  if value ~= nil then
    local old = F.r8(address)
    F.w8(address, value and (old | bit) or (old & ~bit & 0xFF))
  end
  return (F.r8(address) & bit) ~= 0
end
local function tap(key, wait) F.press(key, 2); F.idle(wait or 20) end
local function warp(g, m, w, tag)
  return F.warpTo(g // 100, (g // 10) % 10, g % 10, m // 100, (m // 10) % 10, m % 10, 0, 0, w, g, m, tag)
end

-- Party slots, decrypted. words/so let a setup edit and re-encrypt with the same key.
local function partyCount() return F.r8(S.gPartiesCount) end
local function slot(i) return S.gParties + i * MON end
local function decode(i)
  local a = slot(i)
  local pers, otid = F.r32(a), F.r32(a + 4)
  local key = pers ~ otid
  local w = {}
  for k = 0, 11 do w[k] = F.r32(a + 32 + k * 4) ~ key end
  local so = {}
  for t = 0, 3 do so[t] = F.r8(S.sSubstructOffsets + t * 24 + pers % 24) * 3 end
  return {
    species = w[so[0]] & 0x7FF, level = F.r8(a + S.Pokemon.level),
    moves = { w[so[1]] & 0x7FF, (w[so[1]] >> 16) & 0x7FF, w[so[1] + 1] & 0x7FF, (w[so[1] + 1] >> 16) & 0x7FF },
    words = w, so = so, key = key,
  }
end
local function encode(i, m)
  local a, sum = slot(i), 0
  for k = 0, 11 do
    sum = sum + (m.words[k] & 0xFFFF) + ((m.words[k] >> 16) & 0xFFFF)
    F.w32(a + 32 + k * 4, (m.words[k] ~ m.key) & 0xFFFFFFFF)
  end
  F.w16(a + 28, sum & 0xFFFF)
end
local function describe(i)
  local m = decode(i)
  return string.format("[%d] species=%d level=%d moves=%d,%d,%d,%d", i, m.species, m.level, m.moves[1], m.moves[2], m.moves[3], m.moves[4])
end
local function zeroParty(from)
  for o = from * MON, 6 * MON - 4, 4 do F.w32(S.gParties + o, 0) end
  F.w8(S.gPartiesCount, from)
end
local function setExp(i, exp)
  local m = decode(i)
  m.words[m.so[0] + 1] = (m.words[m.so[0] + 1] & ~0x1FFFFF) | exp
  encode(i, m)
end

-- Debug Give X > Pokemon (Basic): four-digit species spinner, then level.
local function spin4(n)
  n = n - 1
  local d = { n // 1000, (n // 100) % 10, (n // 10) % 10, n % 10 }
  for _ = 1, 3 do tap("Right", 8) end
  for _ = 1, 3 do tap("Down", 8) end
  for i = 1, 4 do
    for _ = 1, d[i] do tap("Up", 8) end
    if i < 4 then tap("Left", 8) end
  end
  tap("A", 45)
end
local function giveMon(species, level)
  local n0 = partyCount()
  for _ = 1, 3 do
    F.dbg(); F.idle(30); F.bOut(4)
    F.dbg(); F.sel(3); F.sel(1); F.idle(20)
    spin4(species); F.idle(20)
    local l = level - 1
    F.spin(l // 100, (l // 10) % 10, l % 10); F.idle(60); F.bOut(4)
    if partyCount() == n0 + 1 and decode(n0).species == species and decode(n0).level == level then return true end
    zeroParty(n0)
    F.idle(60)
  end
  return false
end

local function liveMenu()
  for i = 0, S.Task.count - 1 do
    local task = S.gTasks + i * S.Task.stride
    local fn = F.r32(task + S.Task.func) & 0xFFFFFFFE
    if F.r8(task + S.Task.isActive) ~= 0 and (fn == S.Task_HandleYesNoInput or fn == S.Task_HandleMultichoiceInput) then
      return true
    end
  end
  return false
end
local function scriptIdle() return F.ow() and F.r8(S.sGlobalScriptContextStatus) == 2 end

-- Bag
local function qtyKey() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF end
local function setItems(id, qty)
  local ptr, cap = F.r32(S.gBagPockets + POCKET_ITEMS * S.BagPocket.stride), F.pocketCap(POCKET_ITEMS)
  for s = 0, cap - 1 do F.w16(ptr + s * 4, 0); F.w16(ptr + s * 4 + 2, qtyKey()) end
  if qty > 0 then F.w16(ptr, id); F.w16(ptr + 2, qty ~ qtyKey()) end
end
local function itemQty(id)
  local ptr, cap, n = F.r32(S.gBagPockets + POCKET_ITEMS * S.BagPocket.stride), F.pocketCap(POCKET_ITEMS), 0
  for s = 0, cap - 1 do if F.r16(ptr + s * 4) == id then n = n + (F.r16(ptr + s * 4 + 2) ~ qtyKey()) end end
  return n
end
local function inBag() return F.cb2() == (S.CB2_BagMenuRun & ~1) end
local function backToField()
  for _ = 1, 40 do
    if F.ow() then break end
    tap("B")
  end
  F.idle(30)
  return F.ow()
end

-- One of `item` on party slot 0 from the Bag, then A every 20 frames for 1500 frames (enough
-- for level-up text, a move prompt and a full evolution scene). Returns whether a scene ran.
local function useOnLead(item)
  setItems(item, 1)
  F.w8(S.gBagPosition + 5, POCKET_ITEMS)
  F.w16(S.gBagPosition + 8 + POCKET_ITEMS * 2, 0)
  F.w16(S.gBagPosition + 18 + POCKET_ITEMS * 2, 0)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_BAG) then return nil end
  F.press("A", 2)
  for _ = 1, 150 do if inBag() then break end F.idle(2) end
  if not inBag() then return nil end
  F.idle(30)
  tap("A", 40); tap("A", 60); tap("A", 20)          -- item, Use, party slot 0
  local evolved = false
  for i = 1, 1500 do
    if i % 8 == 0 and F.reportCrash("item") then break end
    if F.r32(S.sEvoStructPtr) ~= 0 then evolved = true elseif evolved and inBag() then break end
    joypad.set((i % 20 < 2) and { A = true } or {})
    emu.frameadvance()
  end
  joypad.set({})
  backToField()
  return evolved
end

local function scenario(tag, body)
  if ONLY and not tag:find(ONLY, 1, true) then return end
  F.L("== " .. tag .. " ==")
  body(tag)
  if not backToField() then F.check(tag .. ": back on the field", false) end
end

local function itemCase(tag, species, level, item, wantSpecies, wantLevel, wantEvolved)
  scenario(tag, function()
    zeroParty(0)
    if not giveMon(species, level) then F.check(tag .. ": debug Give made the Pokemon", false); return end
    local evolved = useOnLead(item)
    local m = decode(0)
    local kept = item ~= ITEM.candy and itemQty(item) or 0
    F.check(tag, evolved ~= nil and m.species == wantSpecies and m.level == wantLevel and evolved == wantEvolved
      and kept == ((item ~= ITEM.candy and not wantEvolved) and 1 or 0),
      string.format("%s evolutionScene=%s itemLeft=%d", describe(0), tostring(evolved), kept))
  end)
end

-- Shared EXP battle against Pirate Totodile with an obedient level 100 Mewtwo in front.
local function battleCase()
  scenario("battle exp", function(tag)
    zeroParty(0)
    flag(FLAG_SHARED_EXP, true)
    flag(FLAG_PIRATE_UNLOCKED, true)
    local ok = giveMon(SP.mewtwo, 100) and giveMon(SP.squad, 15) and giveMon(SP.squirtle, 15) and giveMon(SP.pirate, 17)
    F.check(tag .. ": party made", ok, "party=" .. partyCount())
    if not ok then return end
    local lead = decode(0)
    lead.words[lead.so[1]] = 89 | (53 << 16)                              -- Earthquake, Flamethrower
    lead.words[lead.so[1] + 2] = (lead.words[lead.so[1] + 2] & ~0xFFFF) | 10 | (15 << 8)
    lead.words[lead.so[3]] = (lead.words[lead.so[3]] & ~(0x7F << 16)) | (1 << 16)   -- met level 1: obeys
    encode(0, lead)
    setExp(1, 2534); setExp(2, 2534); setExp(3, 3797)                     -- 1 EXP short of 16 / 16 / 18
    if not warp(87, 0, 7, "olivine") then F.check(tag .. ": Olivine", false); return end
    F.dismiss(10)
    F.route({ { 15, 44 }, { 17, 44 }, { 17, 45 }, { 23, 45 }, { 23, 47 }, { 32, 47 }, { 32, 48 }, { 33, 48 }, { 33, 55 }, { 32, 55 } }, "dock")
    F.face("Up"); F.press("A", 2); F.idle(20)
    local battle = false
    for _ = 1, 300 do
      if F.cb2() == (S.BattleMainCB2 & ~1) then battle = true; break end
      tap("A", 20)
    end
    F.check(tag .. ": battle started", battle)
    if not battle then return end
    local scenes, wasEvo = 0, false
    for _ = 1, 6000 do
      local fn = F.r32(S.gBattlerControllerFuncs) & ~1
      local ready = false
      for _, p in ipairs(S.ActionInputFunctions) do if fn == p then ready = true end end
      local e = F.r32(S.sEvoStructPtr) ~= 0
      if e and not wasEvo then scenes = scenes + 1 end
      wasEvo = e
      if ready then
        F.idle(10)
        for _ = 1, 8 do                                                      -- cursor to FIGHT
          local c = F.r8(S.gActionSelectionCursor)
          if c == 0 then break end
          tap((c & 1) ~= 0 and "Left" or "Up", 14)
        end
        tap("A", 30)
        for _ = 1, 60 do if (F.r32(S.gBattlerControllerFuncs) & ~1) == S.HandleInputChooseMove then break end F.idle(2) end
        F.idle(20)
        for _ = 1, 4 do                                                      -- cursor to Earthquake
          local c = F.r8(S.gMoveSelectionCursor)
          if c == 0 then break end
          tap((c & 1) ~= 0 and "Left" or "Up", 12)
        end
        for _ = 1, 4 do
          tap("A", 30)
          if (F.r32(S.gBattlerControllerFuncs) & ~1) ~= S.HandleInputChooseMove then break end
        end
      elseif F.cb2() ~= (S.BattleMainCB2 & ~1) and not e and scriptIdle() then
        break
      else
        tap("A", 10)
      end
    end
    F.idle(60)
    for i = 0, 3 do F.L("  " .. describe(i)) end
    local squad, squirtle, pirate = decode(1), decode(2), decode(3)
    F.check(tag .. ": won", F.outcome() == 1, "outcome=" .. F.outcome())
    F.check(tag .. ": Squad Squirtle grew to 16 and did not evolve", squad.species == SP.squad and squad.level >= 16, describe(1))
    F.check(tag .. ": Pirate Totodile grew to 18 and did not evolve", pirate.species == SP.pirate and pirate.level >= 18, describe(3))
    F.check(tag .. ": control, the ordinary Squirtle became Wartortle", squirtle.species == SP.wartortle, describe(2))
    F.check(tag .. ": exactly one evolution scene ran", scenes == 1, "scenes=" .. scenes)
  end)
end

local function reminderCase()
  scenario("move reminder", function(tag)
    F.dbg(); F.sel(2); F.sel(9); F.idle(60); F.bOut(4)                    -- a lead for the box chooser
    zeroParty(1)
    if not giveMon(SP.classic, 5) then F.check(tag .. ": debug Give made the Pokemon", false); return end
    local m = decode(1)
    m.words[m.so[1]] = m.words[m.so[1]] & 0x7FF                            -- one move left
    m.words[m.so[1] + 1] = 0
    m.words[m.so[1] + 2] = m.words[m.so[1] + 2] & 0x7F
    encode(1, m)
    F.L("  before " .. describe(1))
    F.dbg(); F.sel(2); F.sel(0); F.idle(60)                              -- Party: Move Relearner script
    tap("A", 60); tap("A", 60); tap("A", 60); F.idle(60)                  -- Level Up Moves, choose
    tap("Left", 30); tap("A", 60); tap("A", 120); tap("A", 150)           -- party slot 1, Select
    F.shot("reminder_list")
    tap("A", 60)                                                         -- the first row
    for _ = 1, 8 do tap("A", 60) end
    for _ = 1, 20 do if scriptIdle() then break end tap("B", 40) end
    F.L("  after " .. describe(1))
    local after = decode(1)
    local knows = false
    for k = 1, 4 do if after.moves[k] == MOVE_THUNDERBOLT then knows = true end end
    F.check(tag .. ": Classic Cap Pikachu relearned Thunderbolt", knows, describe(1))
  end)
end

local function decodeText(addr)
  local out = {}
  for i = 0, 119 do
    local c = F.r8(addr + i)
    if c == 0xFF then break end
    if c == 0x00 or c == 0xFE then out[#out + 1] = " "
    elseif c >= 0xBB and c <= 0xD4 then out[#out + 1] = string.char(65 + c - 0xBB)
    elseif c >= 0xD5 and c <= 0xEE then out[#out + 1] = string.char(97 + c - 0xD5)
    else out[#out + 1] = "?" end
  end
  return table.concat(out)
end

-- struct DayCare: two 140-byte DaycareMon, then offspringPersonality and stepCounter (288 bytes,
-- as DaycareFullPartyEgg.lua uses it). All zero is an empty Day Care with no Egg pending.
local DAYCARE_BYTES = 288
local function emptyDayCare()
  local base = F.sb1() + S.SaveBlock1.daycare
  for o = 0, DAYCARE_BYTES - 4, 4 do F.w32(base + o, 0) end
end

local function dayCareCase(tag, first, wantEgg)
  scenario(tag, function()
    emptyDayCare()
    F.dbg(); F.sel(2); F.sel(9); F.idle(60); F.bOut(4)
    zeroParty(1)
    local ok = giveMon(first, 10) and giveMon(SP.ditto, 10) and giveMon(SP.pidgey, 10)
    F.check(tag .. ": party made", ok, "party=" .. partyCount())
    if not ok then return end
    -- The Ditto gets another trainer's ID (a traded Ditto), so a compatible pair rolls at 50%
    -- per 256 steps instead of 20% and the control's Egg cannot miss.
    local ditto = decode(2)
    F.w32(slot(2) + 4, F.r32(slot(2) + 4) ~ 0x00010001)
    ditto.key = F.r32(slot(2)) ~ F.r32(slot(2) + 4)
    encode(2, ditto)
    if not warp(81, 5, 0, "daycare") then F.check(tag .. ": Day Care", false); return end
    for _ = 1, 6 do tap("B", 30) end                                    -- not dismiss(): the door is underfoot
    F.route({ { 2, 4 }, { 2, 6 }, { 3, 6 } }, "counter")
    F.face("Down"); F.press("A", 2); F.idle(30)
    for _ = 1, 2 do                                                      -- slot 1 twice: the next one moves up
      for _ = 1, 30 do
        if F.cb2() ~= S.CB2_Overworld then break end
        tap("A", liveMenu() and 40 or 30)
      end
      F.idle(60); tap("Down", 30); tap("A", 60)
      for _ = 1, 4 do if F.ow() then break end tap("A", 40) end
    end
    for _ = 1, 20 do if scriptIdle() then break end tap("B", 30) end
    F.check(tag .. ": both deposited", partyCount() == 2, "party=" .. partyCount())
    F.route({ { 2, 6 }, { 2, 4 }, { 1, 4 } }, "exit")
    for _ = 1, 3 do if F.grp() == 80 then break end F.step("Left"); F.idle(60) end
    F.idle(60)
    F.route({ { 30, 32 }, { 30, 34 } }, "daycare_man")
    F.face("Right"); F.press("A", 2)
    for _ = 1, 20 do tap("A", 30); if scriptIdle() then break end end
    local verdict = decodeText(S.gStringVar4)
    F.L("  verdict: " .. verdict)
    local pending = function() return F.r32(F.sb1() + S.SaveBlock1.daycare + DAYCARE_BYTES - 8) ~= 0 end
    for n = 1, 800 do
      F.step("Up"); F.step("Down")
      if wantEgg and pending() then F.L(string.format("  Egg pending after %d steps", n * 2)); break end
    end
    F.check(tag .. (wantEgg and ": an Egg is pending" or ": no Egg is pending"), pending() == wantEgg)
    F.face("Right"); F.press("A", 2); F.idle(30)
    local egg = false
    for _ = 1, 20 do
      if liveMenu() then egg = true; tap("B", 40) end
      tap("A", 30)
      if scriptIdle() then break end
    end
    if wantEgg then
      F.check(tag .. ": the Day-Care Man offers the Egg", egg, verdict)
    else
      F.check(tag .. ": the Day-Care Man says they will not play together", verdict:find("prefer to play with other", 1, true) ~= nil, verdict)
      F.check(tag .. ": the Day-Care Man offers no Egg after 1600 steps", not egg)
    end
  end)
end

F.run(function()
  assert(F.boot(100), "Fresh game did not boot")
  local opt = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(opt, (F.r16(opt) & ~7) | 3)
  flag(FLAG_SYS_POKEMON_GET, true)

  itemCase("Classic Cap Pikachu + Thunder Stone: no evolution", SP.classic, 5, ITEM.thunder, SP.classic, 5, false)
  itemCase("Surfboard Pikachu + Thunder Stone: no evolution", SP.surfboard, 25, ITEM.thunder, SP.surfboard, 25, false)
  itemCase("Balloon Pikachu + Thunder Stone: no evolution", SP.balloons, 15, ITEM.thunder, SP.balloons, 15, false)
  for _, stone in ipairs({ "fire", "water", "thunder", "leaf", "ice", "sun", "moon", "shiny" }) do
    itemCase("Flower Crown Eevee + " .. stone .. " stone: no evolution", SP.flower, 20, ITEM[stone], SP.flower, 20, false)
  end
  itemCase("control: ordinary Pikachu + Thunder Stone evolves", SP.pikachu, 10, ITEM.thunder, SP.raichu, 10, true)
  itemCase("Squad Squirtle + Rare Candy to 16: no evolution", SP.squad, 15, ITEM.candy, SP.squad, 16, false)
  itemCase("Firefighter Squirtle + Rare Candy to 16: no evolution", SP.firefighter, 15, ITEM.candy, SP.firefighter, 16, false)
  itemCase("Pirate Totodile + Rare Candy to 18: no evolution", SP.pirate, 17, ITEM.candy, SP.pirate, 18, false)
  itemCase("control: ordinary Squirtle + Rare Candy to 16 evolves", SP.squirtle, 15, ITEM.candy, SP.wartortle, 16, true)
  battleCase()
  reminderCase()
  dayCareCase("day care: Classic Cap Pikachu + Ditto", SP.classic, false)
  dayCareCase("day care control: ordinary Pikachu + Ditto", SP.pikachu, true)
  F.finish()
end)
