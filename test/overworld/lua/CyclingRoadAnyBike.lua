-- Kanto's Cycling Road gates turned away any player who had not been given Kanto's Bicycle, even one
-- carrying the Mach or Acro Bike from Hoenn or Johto in the shared Bag. Owning any bike now counts,
-- and the gate puts the player on the bike they own. The suite walks across both gates on foot:
-- the Route 16 gate with only a Mach Bike, the Route 18 gate with only an Acro Bike, and the Route 16
-- gate again with no bike at all (still refused, as in FRLG).
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/CyclingRoadAnyBike.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "CyclingRoadAnyBike")

local HUB = 100
local GATE16, ROUTE16 = { 59, 1 }, { 37, 34 }
local GATE18, ROUTE18 = { 60, 0 }, { 37, 36 }
local ITEM_BICYCLE, ITEM_MACH_BIKE, ITEM_ACRO_BIKE = 706, 707, 708
local FLAG_GOT_BICYCLE = 0xA40 + 0x271
local AVATAR_MACH, AVATAR_ACRO = 0x02, 0x04
local CONTEXT_RUNNING = 0

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function mapIs(m) return F.grp() == m[1] and F.mapn() == m[2] end
local function flagGet(id) return (F.r8(F.sb1() + S.SaveBlock1.flags + id // 8) >> (id % 8)) & 1 == 1 end
local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function warp(m, w, tag)
  local gh, gt, go = d(m[1]); local mh, mt, mo = d(m[2]); local wh, wt, wo = d(w)
  return F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, m[1], m[2], tag)
end
local SCRIPT_BUF = S.gStringVar4 + 960
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
  F.idle(20)
end
local function addItem(id) runScript({ 0x44, id & 0xFF, id >> 8, 1, 0, 0x02 }) end
local function removeItem(id) runScript({ 0x45, id & 0xFF, id >> 8, 1, 0, 0x02 }) end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function avatar() return F.r8(S.gPlayerAvatar) end

-- Walk west across the gate's counter line on foot and out of its west door. A refused player is
-- walked back east by the guard; mash B through his lines until control returns.
local function crossGate(gate, route, entryWarp, row, tag)
  F.check(tag .. ": warped to the gate's east door", warp(gate, entryWarp, tag), where())
  F.idle(40)
  F.leg(2, row)
  for _ = 1, 40 do
    if hasControl() then break end
    F.press("B", 2); F.idle(20)
  end
  for _ = 1, 30 do
    if hasControl() then break end
    F.idle(10)
  end
  F.press("Left", 30)
  for _ = 1, 300 do if mapIs(route) and hasControl() then break end; F.idle(1) end
  F.idle(60)
  F.shot(tag)
end

F.run(function()
  if not F.boot(HUB) then F.check("boot", false); F.finish(); return end
  F.check("setup: no Kanto Bicycle", not flagGet(FLAG_GOT_BICYCLE) and F.itemCount(ITEM_BICYCLE) == 0)

  addItem(ITEM_MACH_BIKE)
  crossGate(GATE16, ROUTE16, 3, 12, "mach16")
  F.check("mach16: the Route 16 gate lets a Mach Bike owner onto the Cycling Road", mapIs(ROUTE16), where())
  F.check("mach16: the gate put the player on the Mach Bike", avatar() & AVATAR_MACH ~= 0,
    string.format("avatar=%02X", avatar()))

  removeItem(ITEM_MACH_BIKE)
  addItem(ITEM_ACRO_BIKE)
  crossGate(GATE18, ROUTE18, 1, 6, "acro18")
  F.check("acro18: the Route 18 gate lets an Acro Bike owner onto the Cycling Road", mapIs(ROUTE18), where())
  F.check("acro18: the gate put the player on the Acro Bike", avatar() & AVATAR_ACRO ~= 0,
    string.format("avatar=%02X", avatar()))

  removeItem(ITEM_ACRO_BIKE)
  crossGate(GATE16, ROUTE16, 3, 12, "nobike16")
  F.check("nobike16: with no bike the guard still turns the player away", mapIs(GATE16), where())
  F.check("nobike16: and the player is still on foot", avatar() & (AVATAR_MACH | AVATAR_ACRO) == 0,
    string.format("avatar=%02X", avatar()))
  F.finish()
end)
