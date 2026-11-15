-- Flower Crown Eevee through the Celadon florist's real quest with a full party, then a save and
-- Continue. The gift must land in the first free PC slot, survive the reload unchanged, set its
-- collection mark, and a repeat gift must take the next slot instead of overwriting the first.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/FlowerCrownQuestStorage.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "FlowerCrownQuestStorage")

local FLAG_SYS_POKEMON_GET = 0x948
local FLAG_STARTED, FLAG_ONE, FLAG_TWO = 0xDE9, 0xDEA, 0xDEB
local FLAG_UNLOCKED, FLAG_COLLECTED = 0xDDF, 0xDD5
local CELADON_G, CELADON_M = 37, 6
local PER_BOX, BOX_MON, MON = 30, S.BoxPokemon.size, S.Pokemon.size

local function flag(id, value)
  local address, bit = F.sb1() + S.SaveBlock1.flags + id // 8, 1 << (id % 8)
  if value ~= nil then
    local old = F.r8(address)
    F.w8(address, value and (old | bit) or (old & ~bit & 0xFF))
  end
  return (F.r8(address) & bit) ~= 0
end

local function storage() return F.r32(S.gPokemonStoragePtr) end
local function boxSlot(n) return storage() + 4 + n * BOX_MON end
local function occupied(n) local a = boxSlot(n); return F.r32(a) ~= 0 or F.r32(a + 4) ~= 0 end
local function fingerprint(n)
  local a, out = boxSlot(n), {}
  for o = 0, BOX_MON - 4, 4 do out[#out + 1] = string.format("%08X", F.r32(a + o)) end
  return table.concat(out)
end
local function boxed()
  local n = 0
  for i = 0, 14 * PER_BOX - 1 do if occupied(i) then n = n + 1 end end
  return n
end
local function partyCount() return F.r8(S.gPartiesCount) end

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

local function talk(dir, tag, acceptGift)
  F.face(dir); F.press("A", 2); F.idle(30)
  for n = 1, 120 do
    if F.reportCrash("talk_" .. tag) then return false end
    if acceptGift and liveMenu() then
      F.shot(tag .. "_offer"); F.press("A", 2); F.idle(40); acceptGift = false
    elseif scriptIdle() and n > 2 then
      return true
    else
      F.press("A", 2); F.idle(30)
    end
  end
  F.shot(tag .. "_stuck")
  return false
end

local function save()
  F.w16(S.gSaveAttemptStatus, 0xFFFF)
  F.press("Start", 2); F.idle(60)
  assert(F.selectStartIcon(7), "Save action unavailable")
  F.press("A", 2); F.idle(90)
  for _ = 1, 12 do
    F.press("A", 2); F.idle(45)
    if F.r16(S.gSaveAttemptStatus) == 1 then break end
  end
  F.idle(120)
  for _ = 1, 20 do
    if scriptIdle() and F.ensureFree() then break end
    F.press("B", 2); F.idle(30)
  end
  return F.r16(S.gSaveAttemptStatus) == 1
end

F.run(function()
  assert(F.boot(100), "Fresh game did not boot")
  flag(FLAG_SYS_POKEMON_GET, true)
  F.dbg(); F.sel(2); F.sel(9); F.idle(120)
  for _ = 1, 10 do if F.ensureFree() then break end F.press("B", 3); F.idle(30) end
  for i = 1, 5 do
    for o = 0, MON - 4, 4 do F.w32(S.gParties + i * MON + o, F.r32(S.gParties + o)) end
  end
  F.w8(S.gPartiesCount, 6)
  local boxed0 = boxed()
  F.check("party full, PC empty", partyCount() == 6 and boxed0 == 0, string.format("party=%d boxed=%d", partyCount(), boxed0))

  assert(F.warpTo(0, 3, 7, 0, 0, 6, 0, 0, 1, CELADON_G, CELADON_M, "celadon"), "Celadon warp failed")
  F.dismiss(10)
  assert(F.route({ { 11, 15 }, { 20, 15 } }, "florist"), "Could not reach the florist")
  F.check("florist starts the delivery", talk("Down", "start") and flag(FLAG_STARTED))
  assert(F.route({ { 19, 15 }, { 19, 20 }, { 20, 20 } }, "resident2"), "Could not reach resident two")
  F.check("second resident takes flowers", talk("Right", "res2") and flag(FLAG_TWO))
  assert(F.route({ { 17, 23 } }, "resident1"), "Could not reach resident one")
  F.check("first resident takes flowers", talk("Down", "res1") and flag(FLAG_ONE))
  assert(F.route({ { 19, 23 }, { 19, 15 }, { 20, 15 } }, "florist_back"), "Could not return to the florist")
  F.check("florist gives the Eevee", talk("Down", "gift", true) and flag(FLAG_UNLOCKED))
  F.check("full party: Eevee lands in the first PC slot", occupied(0) and boxed() == 1 and partyCount() == 6,
    string.format("boxed=%d party=%d", boxed(), partyCount()))
  F.check("collection mark set", flag(FLAG_COLLECTED))
  local first = fingerprint(0)

  F.check("repeat gift accepted", talk("Down", "again", true))
  F.check("repeat gift takes the next slot", occupied(1) and boxed() == 2 and fingerprint(0) == first,
    string.format("boxed=%d", boxed()))
  local second = fingerprint(1)

  F.check("save completes", save())
  client.reboot_core()
  assert(F.boot(CELADON_G, true), "Continue did not reach Celadon")
  F.idle(120)
  F.check("Continue keeps both Eevee unchanged", boxed() == 2 and fingerprint(0) == first and fingerprint(1) == second,
    string.format("boxed=%d", boxed()))
  F.check("Continue keeps the party", partyCount() == 6)
  F.check("Continue keeps the collection mark", flag(FLAG_COLLECTED) and flag(FLAG_UNLOCKED))
  F.shot("continue")
  F.finish()
end)
