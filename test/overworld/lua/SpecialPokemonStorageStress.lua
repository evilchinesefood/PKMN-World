-- Special Pokémon gifts against a full party and a full PC, through the real Pallet Town NPC.
--
-- SpecialPokemonSources already proves a full party sends the gift to the PC. This suite fills the
-- PC as well: the gift must be refused with the stock "no more room" text, leave the party and
-- every box untouched and leave the collection mark unset. Freeing one box slot must then let the
-- very next gift land in that slot, and a repeat request with the PC full again must be refused
-- the same way instead of overwriting anything.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/SpecialPokemonStorageStress.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SpecialPokemonStorageStress")

local FLAG_SYS_POKEMON_GET = 0x948
local COLLECTED_CLASSIC_CAP = 0xDD0
local PALLET_G, PALLET_M = 37, 0
local TRAINER = { 19, 14 }
local BOXES, PER_BOX, BOX_MON = 14, 30, S.BoxPokemon.size
local MON = S.Pokemon.size

local function flag(id, value)
  local address, bit = F.sb1() + S.SaveBlock1.flags + id // 8, 1 << (id % 8)
  if value ~= nil then
    local old = F.r8(address)
    F.w8(address, value and (old | bit) or (old & ~bit & 0xFF))
  end
  return (F.r8(address) & bit) ~= 0
end

local function storage() return F.r32(S.gPokemonStoragePtr) end
local function boxSlot(box, slot) return storage() + 4 + (box * PER_BOX + slot) * BOX_MON end
local function occupied(address) return F.r32(address) ~= 0 or F.r32(address + 4) ~= 0 end

local function boxCount()
  local n = 0
  for box = 0, BOXES - 1 do
    for slot = 0, PER_BOX - 1 do if occupied(boxSlot(box, slot)) then n = n + 1 end end
  end
  return n
end

local function boxDigest()
  local sum = 0
  for box = 0, BOXES - 1 do
    for slot = 0, PER_BOX - 1 do
      local a = boxSlot(box, slot)
      sum = (sum * 31 + F.r32(a) + F.r32(a + 4) * 7) % 0x7FFFFFFF
    end
  end
  return sum
end

local function partyDigest()
  local sum = 0
  for i = 0, 5 do
    local a = S.gParties + i * MON
    sum = (sum * 31 + F.r32(a) + F.r32(a + 4) * 7) % 0x7FFFFFFF
  end
  return sum
end

local function partyCount() return F.r8(S.gPartiesCount) end

local function tapDown(n) for _ = 1, n do F.press("Down", 3); F.idle(16) end end

local function debugAction(path, tag)
  F.dbg(); F.idle(60)
  for i, row in ipairs(path) do
    tapDown(row); F.press("A", 3); F.idle(i == #path and 240 or 60)
  end
  for _ = 1, 8 do
    if F.ensureFree() then return true end
    F.press("B", 3); F.idle(30)
  end
  F.L("  debug action " .. tag .. " did not return to the field")
  return F.ensureFree()
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

-- Talk to the trainer, answer YES, then advance every message with A. Returns the screenshot tag
-- of the last message seen before control came back.
local function requestGift(tag)
  F.face("Up"); F.press("A", 2); F.idle(30)
  for _ = 1, 60 do
    if liveMenu() then break end
    F.press("A", 2); F.idle(30)
  end
  if not liveMenu() then F.shot(tag .. "_nooffer"); return false end
  F.shot(tag .. "_offer")
  F.press("A", 2); F.idle(60)
  for n = 1, 120 do
    if F.reportCrash("gift_" .. tag) then return false end
    if scriptIdle() then return true end
    if n == 2 then F.shot(tag .. "_reply") end
    F.press("A", 2); F.idle(30)
  end
  F.shot(tag .. "_stuck")
  return false
end

F.run(function()
  assert(F.boot(100), "Fresh game did not boot")
  flag(FLAG_SYS_POKEMON_GET, true)
  F.check("debug Set Party ran", debugAction({ 2, 9 }, "set_party") and partyCount() >= 1, "party=" .. partyCount())
  for i = 1, 5 do
    for o = 0, MON - 4, 4 do F.w32(S.gParties + i * MON + o, F.r32(S.gParties + o)) end
  end
  F.w8(S.gPartiesCount, 6)
  F.check("debug Fill PC Boxes Fast ran", debugAction({ 1, 1, 0 }, "fill_pc"))
  F.check("party and PC are both full", partyCount() == 6 and boxCount() == BOXES * PER_BOX,
    string.format("party=%d boxed=%d", partyCount(), boxCount()))

  assert(F.warpTo(0, 3, 7, 0, 0, 0, 0, 0, 0, PALLET_G, PALLET_M, "pallet"), "Pallet warp failed")
  F.dismiss(20)
  assert(F.route({ { 9, 8 }, { 9, 9 }, { 12, 9 }, { 12, 14 }, { 18, 14 }, { 18, 15 }, { TRAINER[1], TRAINER[2] + 1 } }, "trainer"),
    "Could not reach the classic cap trainer")

  local party0, boxes0 = partyDigest(), boxDigest()
  F.check("full party and PC: dialogue returns control", requestGift("full"))
  F.check("full party and PC: no Pokémon is added or overwritten",
    partyCount() == 6 and partyDigest() == party0 and boxDigest() == boxes0 and boxCount() == BOXES * PER_BOX,
    string.format("party=%d boxed=%d", partyCount(), boxCount()))
  F.check("full party and PC: collection stays unmarked", not flag(COLLECTED_CLASSIC_CAP))

  local freed = boxSlot(7, 13)
  for o = 0, BOX_MON - 4, 4 do F.w32(freed + o, 0) end
  F.check("one PC slot freed", boxCount() == BOXES * PER_BOX - 1)
  F.check("one free slot: dialogue returns control", requestGift("one_slot"))
  F.check("one free slot: the gift fills exactly that slot", occupied(freed) and boxCount() == BOXES * PER_BOX
    and partyCount() == 6 and partyDigest() == party0, string.format("boxed=%d", boxCount()))
  F.check("one free slot: collection marked", flag(COLLECTED_CLASSIC_CAP))

  local boxes1 = boxDigest()
  F.check("PC full again: repeat request returns control", requestGift("repeat_full"))
  F.check("PC full again: nothing is overwritten", boxDigest() == boxes1 and partyDigest() == party0
    and boxCount() == BOXES * PER_BOX and partyCount() == 6)
  F.check("player can still walk after the refusals", F.ensureFree())
  F.shot("completed")
  F.finish()
end)
