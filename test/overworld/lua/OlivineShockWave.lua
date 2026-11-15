-- Olivine City's TM Shock Wave ball can be reached and picked up.
--
-- pokemonHnS gives TM Shock Wave from the Olivine Lighthouse ball and parks a second ball on the
-- same flag at Olivine (53,47), off the east edge of the 52-wide map. This tree rewired the
-- lighthouse ball to TM Bulk Up (#177) and moved the city ball to (48,69) to make Shock Wave
-- obtainable, but (48,69) is open sea inside a pocket (x 31..48, y 67..71) that rock walls seal:
-- x 29..30 on the west, row 66 on the north, and the port's rocks below. Only a Sky Charm landing
-- on the pocket's one dry rock reaches it. ValidateReachability.py flags it.
--
-- The ball now stands at (43,50), the reachable cell nearest the HnS position: the east end of
-- the lighthouse yard.
--
-- Segments (each starts from a debug warp to a coordinate, then uses real input):
--   west seam  surf down the channel beside the pier to (28,69); a step east into the pocket is refused
--   north seam surf to (35,65); a step south into the pocket is refused
--   collect    walk from the lighthouse yard to (42,50), face east, press A: TM Shock Wave is in the bag
-- The two seam segments pass on both sides; collect fails while the ball is still in the pocket.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/OlivineShockWave.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "OlivineShockWave")

local HUB_GROUP = 100
local OLIVINE_GROUP, OLIVINE_MAP = 87, 0
local ITEM_TM_SHOCK_WAVE = 615
local PLAYER_AVATAR_FLAG_SURFING = 1 << 3
local VAR_REPEL_STEP_COUNT = 0x4021

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end

local function surfing() return (F.r8(S.gPlayerAvatar) & PLAYER_AVATAR_FLAG_SURFING) ~= 0 end

local function giveLapras()
  F.dbg(); F.idle(60)
  for _ = 1, 3 do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(60)                           -- Give X…
  F.press("Down", 3); F.idle(16); F.press("A", 3); F.idle(60) -- Pokémon (Basic)
  F.spin(1, 3, 0)                                      -- SPECIES_LAPRAS = 131 (spinner min 1)
  F.spin(0, 9, 9)                                      -- level 100
  F.idle(90)
  F.bOut(4); F.idle(60)
end

-- Debug warp with sWarpDestination held at WARP_ID_NONE, so SetPlayerCoordsFromWarp takes x,y.
-- Arriving on water starts Surf.
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
      local px, py = F.pos()
      if F.ow() and F.grp() == OLIVINE_GROUP and F.mapn() == OLIVINE_MAP and px == x and py == y then
        F.idle(120)
        F.L(string.format("  WARP %s ok (%d,%d) surfing=%s", tag, px, py, tostring(surfing())))
        return true
      end
    end
    F.bOut(5)
  end
  F.shot(tag .. "_warpfail")
  return false
end

-- F.step holds the pad 14 frames past the coordinate change, a second tile at Surf speed.
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

local function walk(dir, n, tag)
  for i = 1, n do
    if not move(dir) then
      local x, y = F.pos()
      F.check(tag .. "_walk", false, string.format("blocked %s step %d at (%d,%d)", dir, i, x, y))
      return false
    end
  end
  return true
end

local function at(x, y)
  local px, py = F.pos()
  return F.grp() == OLIVINE_GROUP and F.mapn() == OLIVINE_MAP and px == x and py == y
end

-- Push into the wall for a while: the position must not change.
local function refused(dir, tag)
  local x0, y0 = F.pos()
  for _ = 1, 3 do move(dir) end
  local x, y = F.pos()
  F.shot(tag)
  return x == x0 and y == y0, string.format("(%d,%d) -> (%d,%d)", x0, y0, x, y)
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot", false); F.finish(); return end
  giveLapras()
  F.check("lapras_in_party", F.r8(S.gPartiesCount) >= 1, "gPartiesCount=" .. F.r8(S.gPartiesCount))
  F.w16(F.sb1() + S.SaveBlock1.vars + (VAR_REPEL_STEP_COUNT - 0x4000) * 2, 250)

  if warpToCoords(28, 65, "west") then
    F.check("west_surfing", surfing(), "surfing=" .. tostring(surfing()))
    if walk("Down", 4, "west") then
      F.check("west_reached_28_69", at(28, 69), string.format("(%d,%d)", F.pos()))
      F.check("west_step_into_pocket_refused", refused("Right", "west_seam"))
    end
  else
    F.check("west_arrived", false)
  end

  if warpToCoords(35, 64, "north") then
    F.check("north_surfing", surfing(), "surfing=" .. tostring(surfing()))
    if walk("Down", 1, "north") then
      F.check("north_reached_35_65", at(35, 65), string.format("(%d,%d)", F.pos()))
      F.check("north_step_into_pocket_refused", refused("Down", "north_seam"))
    end
  else
    F.check("north_arrived", false)
  end

  local before = F.itemCount(ITEM_TM_SHOCK_WAVE)
  if warpToCoords(39, 52, "yard") then
    F.check("yard_on_foot", not surfing(), "surfing=" .. tostring(surfing()))
    if walk("Up", 2, "yard") and walk("Right", 3, "yard") then
      F.check("yard_reached_42_50", at(42, 50), string.format("(%d,%d)", F.pos()))
      F.face("Right")
      F.shot("facing_ball_spot")
      F.press("A", 2); F.idle(90)
      for _ = 1, 12 do F.press("A", 2); F.idle(40) end
      for _ = 1, 6 do F.press("B", 2); F.idle(30) end
      F.shot("after_pickup")
      local after = F.itemCount(ITEM_TM_SHOCK_WAVE)
      F.check("tm_shock_wave_picked_up", after == before + 1, string.format("TM Shock Wave slots %d -> %d", before, after))
    end
  else
    F.check("yard_arrived", false)
  end

  F.finish()
end)
