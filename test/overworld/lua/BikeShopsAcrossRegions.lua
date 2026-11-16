-- Rydel's Cycles (Mauville) and the Goldenrod bike shop share FLAG_RECEIVED_BIKE, so one shop bike
-- is the rule across Hoenn and Johto: Rydel swaps the bike the player holds, and the Goldenrod
-- clerk thanks a player who already has one. Goldenrod's first-visit setup cleared that flag (an
-- HnS reset of its own flag pool), so walking into Goldenrod after Rydel's gift let the clerk hand
-- over a Mach Bike beside Rydel's Acro Bike. The suite talks to Rydel for the Mach Bike and again to
-- switch it for the Acro Bike, walks into Goldenrod for the first time, talks to the Goldenrod clerk
-- and then to Rydel, and counts the bikes in the Bag after each talk.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/BikeShopsAcrossRegions.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BikeShopsAcrossRegions")

local HUB = 100
local MAUVILLE_BIKE_SHOP = { 10, 1 }
local GOLDENROD = { 83, 0 }
local GOLDENROD_BIKE_SHOP = { 84, 0 }
local ITEM_MACH_BIKE, ITEM_ACRO_BIKE = 707, 708
local FLAG_RECEIVED_BIKE = 0x5A
local VAR_GOLDENROD_CITY_STATE = 0xA083
local CONTEXT_RUNNING = 0

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function mapIs(m) return F.grp() == m[1] and F.mapn() == m[2] end
local function flagGet(id) return (F.r8(F.sb1() + S.SaveBlock1.flags + id // 8) >> (id % 8)) & 1 == 1 end
local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function warp(m, w, tag)
  local gh, gt, go = d(m[1]); local mh, mt, mo = d(m[2]); local wh, wt, wo = d(w)
  return F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, m[1], m[2], tag)
end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function waitControl(n)
  for _ = 1, n or 600 do if hasControl() then return true end; F.idle(1) end
  return hasControl()
end
-- The Bag stores each key item's quantity XORed with the low half of the encryption key.
local function qty(id)
  local key = F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF
  local ptr = F.r32(S.gBagPockets + 4 * S.BagPocket.stride)
  local n = 0
  for s = 0, F.pocketCap(4) - 1 do
    if F.r16(ptr + s * 4) == id then n = n + (F.r16(ptr + s * 4 + 2) ~ key) end
  end
  return n
end
local function bikes() return qty(ITEM_MACH_BIKE), qty(ITEM_ACRO_BIKE) end
local function bikeStr() local m, a = bikes(); return string.format("mach=%d acro=%d", m, a) end
-- Face the NPC, press A once, then answer every message, Yes/No and menu with A (Yes, first row)
-- until the script hands control back.
local function talk(dir, tag)
  F.face(dir)
  F.press("A", 2)
  local started = false
  for _ = 1, 120 do
    if not hasControl() then started = true; break end
    F.idle(1)
  end
  if not started then return false end
  for _ = 1, 400 do
    F.idle(20)
    if hasControl() then break end
    F.press("A", 2)
  end
  F.shot(tag)
  return waitControl(60)
end

F.run(function()
  if not F.boot(HUB) then F.check("boot", false); F.finish(); return end

  F.check("rydel: warped into Rydel's Cycles", warp(MAUVILLE_BIKE_SHOP, 0, "rydel"), where())
  F.idle(30)
  F.check("rydel: walked up to Rydel", F.leg(2, 6), where())
  F.check("rydel: talked to Rydel", talk("Up", "rydel_gift"))
  local m, a = bikes()
  F.check("rydel: Rydel gave the Mach Bike", m == 1 and a == 0, bikeStr())
  F.check("rydel: the shop bike is recorded", flagGet(FLAG_RECEIVED_BIKE))
  F.check("rydel: talked to Rydel again", talk("Up", "rydel_switch"))
  m, a = bikes()
  F.check("rydel: Rydel switched it for the Acro Bike", m == 0 and a == 1, bikeStr())

  F.check("goldenrod: warped into Goldenrod for the first time", warp(GOLDENROD, 0, "goldenrod"), where())
  for _ = 1, 30 do
    if waitControl(60) then break end
    F.press("B", 2)
  end
  F.check("goldenrod: the first-visit setup ran", F.r16(F.sb3() + S.SaveBlock3.regionVars
    + (VAR_GOLDENROD_CITY_STATE - 0xA000) * 2) >= 1)
  F.check("goldenrod: walking into Goldenrod keeps Rydel's bike recorded", flagGet(FLAG_RECEIVED_BIKE))

  F.check("clerk: warped into the Goldenrod bike shop", warp(GOLDENROD_BIKE_SHOP, 0, "clerk"), where())
  F.idle(30)
  F.check("clerk: walked up to the clerk", F.leg(4, 5), where())
  F.check("clerk: talked to the clerk", talk("Up", "goldenrod_clerk"))
  F.check("clerk: the clerk gives no second bike", qty(ITEM_MACH_BIKE) + qty(ITEM_ACRO_BIKE) == 1, bikeStr())

  F.check("swap: warped back into Rydel's Cycles", warp(MAUVILLE_BIKE_SHOP, 0, "swap"), where())
  F.idle(30)
  F.check("swap: walked up to Rydel", F.leg(2, 6), where())
  F.check("swap: talked to Rydel", talk("Up", "rydel_again"))
  m, a = bikes()
  F.check("swap: Rydel's switch still leaves one bike", m + a == 1, bikeStr())
  F.finish()
end)
