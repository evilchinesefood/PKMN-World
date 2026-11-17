-- A Sky Charm landing leaves the player at the landing tile's elevation, so the first step obeys
-- the elevation rules.
--
-- StartOverworldFlight sets the player to ELEVATION_TRANSITION so CanLandOverworldFlight's
-- collision test accepts ground at any height. Landing left it there, and ELEVATION_TRANSITION
-- matches every tile, so the first step off a shore went onto the water on foot; the water's
-- elevation then stuck and the player walked across the sea without Surf. A landing tile at
-- surf level (an elevation-1 tile whose behaviour is not water, such as Olivine's 0x050 sea tile
-- at (36,70)) or at a transition or bridge elevation gives the player no ground level to pick up.
--
-- Segments, in Olivine City with the Storm Badge (Johto badge 5) and the Sky Charm on Select:
--   shore    take off on the pier, land on (19,65), step west: the step onto the sea is refused
--   sea tile fly to (36,70): landing there is refused and the player is still flying
--   yard     fly to the lighthouse yard (39,52), land, step north on land (control)
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/SkyCharmLanding.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SkyCharmLanding")

local HUB_GROUP = 100
local OLIVINE_GROUP, OLIVINE_MAP = 87, 0
local ITEM_SKY_CHARM = 891
local FLAG_JOHTO_BADGE_5 = 0x63FC
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local PLAYER_AVATAR_FLAG_SURFING = 1 << 3

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function surfing() return (F.r8(S.gPlayerAvatar) & PLAYER_AVATAR_FLAG_SURFING) ~= 0 end
local function flying() return F.r8(S.sFlightActive) ~= 0 end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function where()
  local x, y = F.pos()
  return string.format("(%d,%d) flying=%s surfing=%s", x, y, tostring(flying()), tostring(surfing()))
end
local function at(x, y)
  local px, py = F.pos()
  return F.grp() == OLIVINE_GROUP and F.mapn() == OLIVINE_MAP and px == x and py == y
end

local SCRIPT_BUF = S.gStringVar4 + 960
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
  for _ = 1, 200 do
    F.idle(4)
    if hasControl() then break end
  end
  F.idle(30)
end

local function warpToCoords(x, y, tag)
  for _ = 1, 4 do
    F.dbg(); F.sel(0); F.sel(1); F.idle(20)
    F.spin(d(OLIVINE_GROUP)); F.spin(d(OLIVINE_MAP))
    F.press("A", 2)
    for _ = 1, 400 do
      F.w8(S.sWarpDestination + 2, 0xFF)
      F.w16(S.sWarpDestination + 4, x)
      F.w16(S.sWarpDestination + 6, y)
      F.idle(1)
      if F.ow() and at(x, y) then
        F.idle(120)
        F.L("  WARP " .. tag .. " ok " .. where())
        return true
      end
    end
    F.bOut(5)
  end
  F.shot(tag .. "_warpfail")
  return false
end

local function move(dir)
  local x0, y0 = F.pos()
  for _ = 1, 30 do
    joypad.set({ [dir] = true }); emu.frameadvance()
    local x, y = F.pos()
    if x ~= x0 or y ~= y0 then F.idle(24); return true end
  end
  F.idle(10)
  return false
end
local function walk(dir, n) for _ = 1, n do if not move(dir) then return false end end return true end

-- Press Select (the Sky Charm) and wait for control; dismiss a refusal message with B.
local function skyCharm()
  F.press("Select", 2); F.idle(150)
  for _ = 1, 10 do
    if hasControl() then break end
    F.press("B", 2); F.idle(40)
  end
  F.idle(20)
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot", false); F.finish(); return end
  if not F.check("warp_to_pier", warpToCoords(19, 66, "pier")) then F.finish(); return end
  runScript({ 0x29, FLAG_JOHTO_BADGE_5 & 0xFF, FLAG_JOHTO_BADGE_5 >> 8, 0x02 })                 -- setflag; end
  runScript({ 0x44, ITEM_SKY_CHARM & 0xFF, ITEM_SKY_CHARM >> 8, 1, 0, 0x02 })                  -- additem; end
  F.w16(F.sb1() + S.SaveBlock1.registeredItem, ITEM_SKY_CHARM)

  skyCharm()
  F.check("shore_took_off", flying(), where())
  walk("Up", 1)
  skyCharm()
  F.check("shore_landed_on_19_65", not flying() and at(19, 65), where())
  move("Left")
  F.shot("shore_step_west")
  F.check("shore_step_onto_sea_refused", at(19, 65), where())

  if not flying() then skyCharm() end
  F.check("sea_tile_took_off", flying(), where())
  local fx, fy = F.pos()
  walk("Right", 36 - fx); walk("Down", 70 - fy)
  F.check("sea_tile_over_36_70", at(36, 70), where())
  skyCharm()
  F.shot("sea_tile_landing")
  F.check("sea_tile_landing_refused", flying() and at(36, 70), where())

  if not flying() then skyCharm() end
  fx, fy = F.pos()
  walk("Up", fy - 52); walk("Right", 39 - fx)
  F.check("yard_over_39_52", flying() and at(39, 52), where())
  skyCharm()
  F.check("yard_landed", not flying() and at(39, 52), where())
  F.check("yard_step_north_on_land", move("Up") and at(39, 51), where())
  F.shot("yard_after_step")

  F.finish()
end)
