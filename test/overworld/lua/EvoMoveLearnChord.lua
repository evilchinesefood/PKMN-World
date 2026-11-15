-- A and B pressed on the same frame at the evolution scene's "forget a move?" prompt must act once.
--
-- With the cursor on YES, Task_EvolutionScene's A branch set the next state to the move-select
-- screen and began a fade to black, then a separate B branch on the same frame overwrote that
-- state with the NO path while the fade ran on. The rest of the scene ("did not learn", which waits
-- for a press) then played on a black screen. This drives the real flow: a Rare Candy from the bag
-- levels Ivysaur 31 to 32, it evolves into Venusaur, Venusaur tries to learn Petal Blizzard with
-- four moves known, and on the prompt A and B go down together for one frame. The summary's
-- move-select screen must open, the screen must not sit black, and choosing the first move there
-- must teach Petal Blizzard.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/EvoMoveLearnChord.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "EvoMoveLearnChord")

local HUB_GROUP = 100
local MON = S.Pokemon.size
local SPECIES_IVYSAUR, SPECIES_VENUSAUR = 2, 3
local ITEM_RARE_CANDY, POCKET_ITEMS = 102, 0
local MOVE_PETAL_BLIZZARD = 572
local USM_ICO_BAG = 2
-- Task_EvolutionScene: tState is data[0], tLearnMoveState data[6] (src/evolution_scene.c).
local EVOSTATE_REPLACE_MOVE = 22
local MVSTATE_HANDLE_YES_NO, MVSTATE_HANDLE_MOVE_SELECT = 4, 6

local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end

local function decode(a)
  local key = F.r32(a) ~ F.r32(a + 4)
  local w = {}
  for i = 0, 11 do w[i] = F.r32(a + 32 + i * 4) ~ key end
  local pers = F.r32(a)
  local function at(k) return F.r8(S.sSubstructOffsets + k * 24 + pers % 24) * 3 end
  local s0, s1 = at(0), at(1)
  return {
    species = w[s0] & 0x7FF,
    level = F.r8(a + S.Pokemon.level),
    moves = { w[s1] & 0x7FF, (w[s1] >> 16) & 0x7FF, w[s1 + 1] & 0x7FF, (w[s1 + 1] >> 16) & 0x7FF },
  }
end
local function describe(m)
  return string.format("sp=%d lv=%d moves=%d,%d,%d,%d", m.species, m.level, m.moves[1], m.moves[2], m.moves[3], m.moves[4])
end
local function knows(m, move)
  for k = 1, 4 do if m.moves[k] == move then return true end end
  return false
end

local function qtyKey() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF end
local function pocketPtr(p) return F.r32(S.gBagPockets + p * S.BagPocket.stride) end
local function setPocket(p, id, qty)
  local ptr = pocketPtr(p)
  for s = 0, F.pocketCap(p) - 1 do F.w16(ptr + s * 4, 0); F.w16(ptr + s * 4 + 2, qtyKey()) end
  F.w16(ptr, id); F.w16(ptr + 2, qty ~ qtyKey())
end
local function candies()
  local ptr = pocketPtr(POCKET_ITEMS)
  return F.r16(ptr) == ITEM_RARE_CANDY and (F.r16(ptr + 2) ~ qtyKey()) or 0
end

local function zeroParty()
  for off = 0, 6 * MON - 4, 4 do F.w32(S.gParties + off, 0) end
  F.w8(S.gPartiesCount, 0)
end
-- Give X(3) -> Pokemon (Basic)(1); both spinners count up from 1, so enter value - 1.
local function digits(n) n = n - 1; return n // 100, (n // 10) % 10, n % 10 end
local function giveMon(species, level)
  F.dbg(); F.sel(3); F.sel(1); F.idle(20)
  F.spin(digits(species)); F.idle(20)
  F.spin(digits(level)); F.idle(60); F.bOut(4)
end

local function inBag() local c = F.cb2(); return c == (S.CB2_Bag & ~1) or c == (S.CB2_BagMenuRun & ~1) end
local function openBagOnFirstItem()
  F.w8(S.gBagPosition + 5, POCKET_ITEMS)
  F.w16(S.gBagPosition + 8 + POCKET_ITEMS * 2, 0)
  F.w16(S.gBagPosition + 18 + POCKET_ITEMS * 2, 0)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_BAG) then return false end
  F.press("A", 2)
  for _ = 1, 150 do if F.cb2() == (S.CB2_BagMenuRun & ~1) then return true end F.idle(2) end
  return false
end

local function evoTask()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    if F.r8(a + S.Task.isActive) ~= 0 and (F.r32(a + S.Task.func) & ~1) == (S.Task_EvolutionScene & ~1) then
      return a
    end
  end
  return nil
end
local function taskData(t, i) return F.r16(t + S.Task.data + i * 2) end
local function atPrompt(t)
  return t and taskData(t, 0) == EVOSTATE_REPLACE_MOVE and taskData(t, 6) == MVSTATE_HANDLE_YES_NO
end

local function litColours()
  local n = 0
  for i = 0, 511 do if F.r16(S.gPlttBufferFaded + i * 2) ~= 0 then n = n + 1 end end
  return n
end

-- B out of everything back to the field, with an A now and then off the field and out of the bag
-- for a message that waits on a press.
local function recover()
  for i = 1, 3000 do
    if F.reportCrash("recover") then return false end
    if F.ow() and i % 60 == 0 and F.ensureFree() then return true end
    if i % 24 < 2 then
      local useA = (i // 24) % 3 == 2 and not F.ow() and not inBag()
      joypad.set({ [useA and "A" or "B"] = true })
    else
      joypad.set({})
    end
    emu.frameadvance()
  end
  return false
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  instantText()

  zeroParty()
  giveMon(SPECIES_IVYSAUR, 31)
  local before = decode(S.gParties)
  F.L("  given: " .. describe(before))
  local full = before.moves[4] ~= 0 and not knows(before, MOVE_PETAL_BLIZZARD)
  if not F.check("setup: Ivysaur 31 with four moves, Petal Blizzard not among them",
      before.species == SPECIES_IVYSAUR and before.level == 31 and full, describe(before)) then
    F.finish(); return
  end
  setPocket(POCKET_ITEMS, ITEM_RARE_CANDY, 5)

  if not F.check("the bag opens on the Rare Candy", openBagOnFirstItem() and candies() == 5) then F.finish(); return end
  F.idle(30)
  F.press("A", 2); F.idle(40)   -- the candy's action menu; Use is the first row
  F.press("A", 2); F.idle(60)   -- Use: party select on slot 0
  F.press("A", 2); F.idle(60)   -- slot 0: how many (5 in the bag, 1 by default)
  F.press("A", 2)               -- confirm one

  -- A only, and never once the move prompt's own states begin: B alone would cancel the
  -- evolution, and an A that lands on the prompt would answer it.
  local t, reached = nil, false
  for i = 1, 6000 do
    t = evoTask()
    if atPrompt(t) then reached = true; break end
    local onPrompt = t and taskData(t, 0) == EVOSTATE_REPLACE_MOVE and taskData(t, 6) >= 3
    joypad.set((i % 24 < 2 and not onPrompt) and { A = true } or {})
    emu.frameadvance()
  end
  if not F.check("Venusaur's forget-a-move prompt comes up", reached,
      string.format("cb2=%08X %s", F.cb2(), describe(decode(S.gParties)))) then
    F.finish(); return
  end
  F.idle(20)
  F.check("the prompt's cursor is on YES", F.r8(S.gBattleCommunication + 1) == 0)
  F.shot("prompt")

  joypad.set({ A = true, B = true }); emu.frameadvance()
  local opened = false
  for _ = 1, 240 do
    joypad.set({}); emu.frameadvance()
    local now = evoTask()
    if now and taskData(now, 6) == MVSTATE_HANDLE_MOVE_SELECT and F.cb2() ~= (S.CB2_EvolutionSceneUpdate & ~1) then
      opened = true
    end
  end
  local lit = litColours()
  F.shot("after_chord")
  F.check("A+B on YES opens the move-select screen", opened, string.format("cb2=%08X", F.cb2()))
  F.check("the screen is not left black", lit > 0, lit .. " lit colours")

  -- A on the first move chooses it; everything after is B out.
  F.press("A", 2); F.idle(60)
  F.check("control returns to the field", recover(), string.format("cb2=%08X", F.cb2()))
  local after = decode(S.gParties)
  F.L("  after: " .. describe(after))
  F.check("Ivysaur became Venusaur at 32", after.species == SPECIES_VENUSAUR and after.level == 32, describe(after))
  F.check("Venusaur learned Petal Blizzard over its first move",
    after.moves[1] == MOVE_PETAL_BLIZZARD and after.moves[2] == before.moves[2]
      and after.moves[3] == before.moves[3] and after.moves[4] == before.moves[4], describe(after))
  F.check("exactly one Rare Candy was spent", candies() == 4, "candies=" .. candies())
  F.finish()
end)
