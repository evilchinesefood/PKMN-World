-- The Bug-Catching Contest with an Egg as the only party member. A Hub gate boxes the whole party
-- and a gift Egg can then be all it holds. The attendants validate the lead through remove5mons,
-- but a one-Pokemon party skipped that check, so the Egg went into the contest, where wild
-- battles are refused for a party that cannot fight and the day's contest was spent on nothing.
-- Setup gives the Egg with the debug Give Egg (ScriptGiveEgg, the call gift scripts use); talking
-- to both gate attendants is real input. Each must refuse, hand out no contest balls and leave the
-- Egg and the field alone.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/BugContestEggOnly.lua
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BugContestEggOnly")

local REGION_JOHTO = 2
local ITEM_SAFARI_BALL = 23
local SPECIES_TOGEPI = 175
local GATE_G, GATE_M = 83, 7
local CONTEST_G, CONTEST_M = 83, 5
local FLAG_SYS_POKEMON_GET = 0x948
local FLAG_SYS_BUG_CONTEST_MODE = 0x948 + 0x21
local ONLY = os.getenv("PW_EGG_GATE")

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function count() return F.r8(S.gPartiesCount) end
local function inContest() return F.grp() == CONTEST_G and F.mapn() == CONTEST_M end
local function isEgg(i) return (F.r8(S.gParties + i * S.Pokemon.size + 19) & 0x04) ~= 0 end
local function sb1Flag(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + (id // 8), 1 << (id % 8)
  if on == nil then return (F.r8(a) & m) ~= 0 end
  F.w8(a, on and (F.r8(a) | m) or (F.r8(a) & ~m & 0xFF))
end
local function setJohto()
  F.w32(S.gCurrentRegion, REGION_JOHTO)
  F.w8(F.sb2() + S.SaveBlock2.currentRegion, REGION_JOHTO)
end
local function scriptLive()
  local p = F.r32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr)
  return F.r8(S.sGlobalScriptContextStatus) ~= 2 and p >= 0x08000000 and p < 0x0A000000
end

local function task(fn)
  for j = 0, 15 do
    local t = S.gTasks + j * 40
    if F.r8(t + 4) ~= 0 and (F.r32(t) & ~1) == (fn & ~1) then return t end
  end
end
local function giveEgg(species)
  F.dbg(); F.idle(30)
  for _ = 1, 3 do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(50)
  for _ = 1, 3 do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(80)
  local t = task(S.DebugAction_Give_Pokemon_SelectId)
  if t then F.w16(t + 8 + 6, species); F.idle(4); F.press("A", 3); F.idle(40) end
  for _ = 1, 8 do F.press("B", 2); F.idle(20) end
  return t ~= nil
end

local function safariBalls()
  local key = F.r16(F.sb2() + S.SaveBlock2.encryptionKey)
  local ptr, n = F.r32(S.gBagPockets + S.BagPocket.stride), 0
  for i = 0, F.pocketCap(1) - 1 do
    if F.r16(ptr + i * 4) == ITEM_SAFARI_BALL then n = n + (F.r16(ptr + i * 4 + 2) ~ key) end
  end
  return n
end

local function free()
  for _ = 1, 60 do
    if F.ow() and not scriptLive() and F.r8(S.sLockFieldControls) == 0 then break end
    F.press("B", 3); F.idle(20)
  end
  return F.ow() and not scriptLive() and F.step("Down") and F.step("Up")
end

local function talk(tag, spot, dir)
  F.leg(spot[1], spot[2])
  F.face(dir)
  F.press("A", 3); F.idle(40)
  local calm = 0
  for _ = 1, 200 do
    if inContest() and F.ow() then break end
    if F.ow() and not scriptLive() and F.r8(S.sLockFieldControls) == 0 then
      calm = calm + 1
      if calm >= 4 then break end
      F.idle(20)
    else
      calm = 0
      F.press("A", 2); F.idle(20)
    end
  end
  F.shot(tag)
  F.check(tag .. ": the Egg stays out of the contest", not inContest() and not sb1Flag(FLAG_SYS_BUG_CONTEST_MODE), where())
  F.check(tag .. ": no contest balls are handed out", safariBalls() == 0, "safari=" .. safariBalls())
  F.check(tag .. ": the Egg is still the only party member", count() == 1 and isEgg(0), "count=" .. count())
  F.check(tag .. ": the field is free", free(), where())
  F.check(tag .. ": no crash", not F.crashScreen())
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  sb1Flag(FLAG_SYS_POKEMON_GET, true)
  F.check("setup: debug Give Egg ran", giveEgg(SPECIES_TOGEPI))
  F.check("setup: the party is one Egg", count() == 1 and isEgg(0), "count=" .. count())
  setJohto()

  if ONLY ~= "east" then
    if not F.warpTo(0, 8, 3, 0, 0, 7, 0, 0, 0, GATE_G, GATE_M, "gate_west") then
      F.check("warp to the National Park gate (Route 35 side)", false, where()); F.finish(); return
    end
    setJohto()
    talk("Route 35 attendant", { 4, 2 }, "Left")
    if inContest() or ONLY == "west" then F.finish(); return end
  end
  if (F.grp() ~= 100 and not F.warpTo(1, 0, 0, 0, 0, 0, 0, 0, 0, 100, 0, "hub")) or not F.warpTo(0, 8, 3, 0, 0, 7, 0, 0, 3, GATE_G, GATE_M, "gate_east") then
    F.check("warp to the National Park gate (Route 36 side)", false, where()); F.finish(); return
  end
  setJohto()
  talk("Route 36 attendant", { 38, 3 }, "Up")
  F.finish()
end)
