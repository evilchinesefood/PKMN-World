-- The uncovered sea corners of Cherrygrove City, Route 26 and Route 34 never reach the screen.
--
-- In each of these pokemonHnS maps the sea runs off an edge that no connection covers, so the
-- camera would draw the map's tree or rock border there. Screenshots of forest or rock squares in
-- open sea came from debug warps into water the player cannot reach: rocks and fences seal it.
-- ValidateBorderTerrain.py floods every map from its warps and checks the same thing on the data.
-- This suite checks it on the engine: it surfs or walks to the reachable cell nearest each
-- corner, asserts that the step past the seal is blocked, and asserts that no cell on screen is
-- MAPGRID_UNDEFINED, so the border is not drawn anywhere the player can look.
--
--   Cherrygrove: rocks at x 2..7 fence the west channel; the rock line at y 25 fences the bay.
--   Route 26: rock staircases (29..30,59..60)/(27..28,61..62) and (18..19,70..71)/(16..17,72..73)
--             and the rock line at y 74..76 fence the south-east bay and the bottom rows.
--   Route 27: the rock line at y 33 fences the sea below it, which leads into Route 26's bay.
--   Route 34: the fence at x 24 and Goldenrod's harbour wall fence the strip at y 0..1.
--
-- Getting into place uses a debug warp to a reachable coordinate (sWarpDestination's warp id is
-- held at WARP_ID_NONE, so SetPlayerCoordsFromWarp takes its x,y); arriving on water starts Surf.
-- The last steps and every seal probe are real input. The screen is 15 columns by 4.5 rows either
-- side of the player; the half rows at dy = -5 and +5 are included.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/JohtoSealedSea.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "JohtoSealedSea")

local HUB_GROUP = 100
local CHERRYGROVE = { 75, 1 }
local ROUTE26 = { 98, 0 }
local ROUTE27 = { 98, 4 }
local ROUTE34 = { 80, 2 }
local MAP_OFFSET = 7
local MAPGRID_UNDEFINED = 0x3FF
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

local function warpToCoords(map, x, y, tag)
  local grp, num = map[1], map[2]
  for _ = 1, 4 do
    F.dbg(); F.sel(0); F.sel(1); F.idle(20)
    F.spin(d(grp)); F.spin(d(num))
    F.press("A", 2)
    for _ = 1, 400 do
      F.w8(S.sWarpDestination + 2, 0xFF)
      F.w16(S.sWarpDestination + 4, x)
      F.w16(S.sWarpDestination + 6, y)
      F.idle(1)
      local px, py = F.pos()
      if F.ow() and F.grp() == grp and F.mapn() == num and px == x and py == y then
        F.idle(120)
        F.L(string.format("  WARP %s ok (%d,%d) surfing=%s", tag, px, py, tostring(surfing())))
        return true
      end
    end
    F.bOut(5)
  end
  F.shot(tag .. "_warpfail")
  F.check(tag .. "_arrived", false)
  return false
end

local function gridBlock(x, y)
  local width = F.r32(S.gBackupMapLayout)
  local map = F.r32(S.gBackupMapLayout + 8)
  return F.r16(map + ((x + MAP_OFFSET) + (y + MAP_OFFSET) * width) * 2)
end

-- F.step holds the pad 14 frames past the coordinate change, which is a second tile at Surf
-- speed. Release as soon as the move starts and let it finish.
local function move(dir)
  local x0, y0 = F.pos()
  for _ = 1, 30 do
    joypad.set({ [dir] = true }); emu.frameadvance()
    local x, y = F.pos()
    if x ~= x0 or y ~= y0 then F.idle(20); return true end
  end
  F.idle(4)
  return false
end

local function walk(path, tag)
  for _, leg in ipairs(path) do
    for i = 1, leg[2] do
      if not move(leg[1]) then
        local x, y = F.pos()
        F.check(tag .. "_walk", false, string.format("blocked %s step %d at (%d,%d)", leg[1], i, x, y))
        return false
      end
    end
  end
  return true
end

local function atCell(map, x, y, tag)
  local px, py = F.pos()
  local ok = F.grp() == map[1] and F.mapn() == map[2] and px == x and py == y
  F.check(tag .. "_reached", ok, string.format("map %d.%d (%d,%d)", F.grp(), F.mapn(), px, py))
  return ok
end

local function sealed(dir, tag)
  local x0, y0 = F.pos()
  local moved = move(dir)
  local x, y = F.pos()
  F.check(tag .. "_seal_blocks_" .. dir, not moved and x == x0 and y == y0,
    string.format("(%d,%d) -> (%d,%d)", x0, y0, x, y))
end

local function noBorderOnScreen(tag)
  local px, py = F.pos()
  local undefined, first = 0, nil
  for y = py - 5, py + 5 do
    for x = px - 7, px + 7 do
      if gridBlock(x, y) == MAPGRID_UNDEFINED then
        undefined = undefined + 1
        first = first or string.format("(%d,%d)", x, y)
      end
    end
  end
  F.check(tag .. "_no_undefined_cell_on_screen", undefined == 0,
    string.format("undefined=%d%s", undefined, first and (" first " .. first) or ""))
end

local function probe(seg)
  if not warpToCoords(seg.map, seg.from[1], seg.from[2], seg.tag) then return end
  if not walk(seg.path, seg.tag) or not atCell(seg.map, seg.at[1], seg.at[2], seg.tag) then return end
  F.shot(string.format("%s_%d_%d", seg.tag, seg.at[1], seg.at[2]))
  noBorderOnScreen(seg.tag)
  for _, dir in ipairs(seg.seals) do sealed(dir, seg.tag) end
  noBorderOnScreen(seg.tag .. "_after_probes")
end

local SEGMENTS = {
  { tag = "cherrygrove_west", map = CHERRYGROVE, from = { 12, 10 }, path = { { "Left", 5 } }, at = { 7, 10 }, seals = { "Left" } },
  { tag = "cherrygrove_south", map = CHERRYGROVE, from = { 12, 22 }, path = { { "Left", 4 }, { "Down", 2 } }, at = { 8, 24 }, seals = { "Down" } },
  { tag = "route26_bay_seam", map = ROUTE26, from = { 26, 60 }, path = { { "Right", 2 } }, at = { 28, 60 }, seals = { "Right", "Down" } },
  { tag = "route26_beach_seam", map = ROUTE26, from = { 12, 72 }, path = { { "Right", 3 }, { "Down", 1 } }, at = { 15, 73 }, seals = { "Right", "Down" } },
  { tag = "route27_rock_line", map = ROUTE27, from = { 100, 30 }, path = { { "Down", 2 } }, at = { 100, 32 }, seals = { "Down" } },
  { tag = "route34_fence", map = ROUTE34, from = { 25, 3 }, path = { { "Up", 3 } }, at = { 25, 0 }, seals = { "Left" } },
}

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot", false); F.finish(); return end
  giveLapras()
  F.check("lapras_in_party", F.r8(S.gPartiesCount) >= 1, "gPartiesCount=" .. F.r8(S.gPartiesCount))
  F.w16(F.sb1() + S.SaveBlock1.vars + (VAR_REPEL_STEP_COUNT - 0x4000) * 2, 250)
  for _, seg in ipairs(SEGMENTS) do probe(seg) end
  F.finish()
end)
