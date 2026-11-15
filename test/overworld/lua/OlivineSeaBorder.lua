-- Olivine City's sea corners draw sea, not a square of forest.
--
-- Olivine is 52x72 with three connections: Route 40 on the left (covers x < 0), Olivine Port
-- Outside below at offset 5 (covers x 5..36 at y >= 72) and Route 39 above. Nothing covers
-- x 0..4 or x >= 37 below the city, or x >= 52 beside it, so the camera draws Olivine's border
-- there. The border was four tree metatiles, so surfing in the south-west or south-east corner
-- showed a hard-edged block of forest in open sea (the worldB2 campaign at Olivine (4,71)).
-- Route 40, the port and Route 41 all use deep-sea metatile 0x051 as their border.
--
-- Getting into place uses a debug warp to a coordinate (sWarpDestination's warp id is held at
-- WARP_ID_NONE, so SetPlayerCoordsFromWarp takes its x,y); arriving on water starts Surf. The last
-- steps into each corner are real input, so the field camera draws the corner as it scrolls.
--
-- The campaign saw the south-west block seven tiles wide, not five, because it swam in from
-- Route 40. CameraMove's MoveMapViewToBackup copies the old map's view into the new map's grid,
-- MAPGRID_UNDEFINED cells included, so Route 40's uncovered cells overwrite the port connection
-- at x 5..6 and draw Olivine's border too. The crossing is driven here as its own segment.
--
-- Oracle: for every uncovered cell on screen (gBackupMapLayout holds MAPGRID_UNDEFINED there),
-- the eight tile entries the camera wrote to the BG tilemap buffers must match those of an open
-- sea cell on the same screen (a covered cell whose metatile behaviour is MB_OCEAN_WATER and
-- whose collision is clear).
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/OlivineSeaBorder.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "OlivineSeaBorder")

local HUB_GROUP = 100
local OLIVINE_GROUP, OLIVINE_MAP, OLIVINE_W, OLIVINE_H = 87, 0, 52, 72
local ROUTE40_MAP = 1
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

local function warpToCoords(grp, map, x, y, tag)
  for _ = 1, 4 do
    F.dbg(); F.sel(0); F.sel(1); F.idle(20)
    F.spin(d(grp)); F.spin(d(map))
    F.press("A", 2)
    for _ = 1, 400 do
      F.w8(S.sWarpDestination + 2, 0xFF)
      F.w16(S.sWarpDestination + 4, x)
      F.w16(S.sWarpDestination + 6, y)
      F.idle(1)
      local px, py = F.pos()
      if F.ow() and F.grp() == grp and F.mapn() == map and px == x and py == y then
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

-- Live layout readers: the same tables MapGridGetMetatileBehaviorAt resolves through.
local function layout() return F.r32(S.gMapHeader + S.MapHeader.mapLayout) end

local function behaviorOf(metatile)
  local L = layout()
  local split = (F.r8(L + S.MapLayout.isFrlg) ~= 0 or F.r8(L + S.MapLayout.isJohto) ~= 0)
    and S.Metatiles.inPrimaryFrlg or S.Metatiles.inPrimary
  local ts, idx = F.r32(L + S.MapLayout.primaryTileset), metatile
  if metatile >= split then ts, idx = F.r32(L + S.MapLayout.secondaryTileset), metatile - split end
  local attrs = F.r32(ts + S.Tileset.metatileAttributes)
  if (F.r8(ts + S.Tileset.flags1) & S.Tileset.hasFrlgAttributesBit) ~= 0 then
    return F.r32(attrs + idx * 4) & S.Metatiles.behaviorMaskFrlg
  end
  return F.r16(attrs + idx * 2) & S.Metatiles.behaviorMask
end

local function gridBlock(x, y)
  local width = F.r32(S.gBackupMapLayout)
  local map = F.r32(S.gBackupMapLayout + 8)
  return F.r16(map + ((x + MAP_OFFSET) + (y + MAP_OFFSET) * width) * 2)
end

-- MapPosToBgTilemapOffset, then the 2x2 entries DrawMetatile wrote on all three layers.
local function drawnSignature(x, y)
  local px, py = F.pos()
  local dx, dy = (x + MAP_OFFSET - px) * 2, (y + MAP_OFFSET - py) * 2
  if dx < 0 or dx >= 32 or dy < 0 or dy >= 32 then return nil end
  local tx = (dx + F.r8(S.sFieldCameraOffset + 2)) % 32
  local ty = (dy + F.r8(S.sFieldCameraOffset + 3)) % 32
  local off = ty * 32 + tx
  local parts = {}
  for _, buf in ipairs({ S.gOverworldTilemapBuffer_Bg3, S.gOverworldTilemapBuffer_Bg2, S.gOverworldTilemapBuffer_Bg1 }) do
    local base = F.r32(buf)
    for _, o in ipairs({ 0, 1, 32, 33 }) do
      parts[#parts + 1] = string.format("%04X", F.r16(base + (off + o) * 2))
    end
  end
  return table.concat(parts, ".")
end

-- On screen: 15 columns centred on the player, rows from 4 above to 6 below.
local function screenCells()
  local px, py = F.pos()
  local cells = {}
  for y = py - 4, py + 6 do
    for x = px - 7, px + 7 do cells[#cells + 1] = { x, y } end
  end
  return cells
end

local function inMap(x, y) return x >= 0 and x < OLIVINE_W and y >= 0 and y < OLIVINE_H end

local function auditCorner(tag, expected)
  local sea, seaKinds, gap, notSea = {}, 0, 0, {}
  local covered = 0
  for _, c in ipairs(screenCells()) do
    local x, y = c[1], c[2]
    local blk = gridBlock(x, y)
    if blk ~= MAPGRID_UNDEFINED then
      covered = covered + 1
      local mt = blk & S.Metatiles.idMask
      if behaviorOf(mt) == S.MetatileBehavior.OCEAN_WATER and ((blk >> 10) & 3) == 0 then
        local sig = drawnSignature(x, y)
        if sig and not sea[sig] then sea[sig] = true; seaKinds = seaKinds + 1 end
      end
    end
  end
  local uncoveredOutsideGap = 0
  for _, c in ipairs(screenCells()) do
    local x, y = c[1], c[2]
    if gridBlock(x, y) == MAPGRID_UNDEFINED then
      if expected(x, y) then
        gap = gap + 1
        local sig = drawnSignature(x, y)
        if not (sig and sea[sig]) then notSea[#notSea + 1] = string.format("(%d,%d)=%s", x, y, tostring(sig)) end
      else
        uncoveredOutsideGap = uncoveredOutsideGap + 1
      end
    end
  end
  local px, py = F.pos()
  F.L(string.format("  %s at (%d,%d): covered=%d seaSignatures=%d uncovered gap cells=%d not sea=%d",
    tag, px, py, covered, seaKinds, gap, #notSea))
  F.check(tag .. "_screen_has_open_sea", seaKinds > 0, "seaSignatures=" .. seaKinds)
  F.check(tag .. "_uncovered_cells_lie_in_the_corner", gap > 0 and uncoveredOutsideGap == 0,
    string.format("gap=%d elsewhere=%d", gap, uncoveredOutsideGap))
  F.check(tag .. "_uncovered_cells_draw_sea", gap > 0 and #notSea == 0,
    string.format("%d/%d not sea%s", #notSea, gap, #notSea > 0 and (": " .. notSea[1]) or ""))
end

-- F.step holds the pad 14 frames past the coordinate change, which is a second tile at Surf
-- speed. Release as soon as the move starts and let it finish.
local function surfStep(dir)
  local x0, y0 = F.pos()
  for _ = 1, 30 do
    joypad.set({ [dir] = true }); emu.frameadvance()
    local x, y = F.pos()
    if x ~= x0 or y ~= y0 then F.idle(20); return true end
  end
  F.idle(4)
  return false
end

local USM_ICO_BAG = 2

local function bagRoundTrip()
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_BAG) then return false end
  F.press("A", 2)
  local left = false
  for _ = 1, 150 do
    if not F.ow() then left = true; break end
    F.idle(2)
  end
  F.idle(60)
  for _ = 1, 40 do
    if F.ow() then break end
    F.press("B", 2); F.idle(20)
  end
  F.idle(60)
  F.press("B", 2); F.idle(60)                          -- close the start menu the Bag returns to
  return left and F.ow()
end

local function walk(dir, n, tag)
  for i = 1, n do
    if not surfStep(dir) then
      local x, y = F.pos()
      F.check(tag .. "_walk", false, string.format("blocked %s step %d at (%d,%d)", dir, i, x, y))
      return false
    end
  end
  return true
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot", false); F.finish(); return end
  giveLapras()
  F.check("lapras_in_party", F.r8(S.gPartiesCount) >= 1, "gPartiesCount=" .. F.r8(S.gPartiesCount))
  F.w16(F.sb1() + S.SaveBlock1.vars + (VAR_REPEL_STEP_COUNT - 0x4000) * 2, 250)

  if not warpToCoords(OLIVINE_GROUP, OLIVINE_MAP, 8, 69, "olivine_sw") then
    F.check("olivine_sw_arrived", false); F.finish(); return
  end
  F.check("surfing_in_sw_pocket", surfing(), "surfing=" .. tostring(surfing()))
  if walk("Left", 4, "sw") and walk("Down", 2, "sw") then
    local x, y = F.pos()
    F.check("sw_reached_4_71", x == 4 and y == 71, string.format("(%d,%d)", x, y))
    F.shot("sw_corner")
    auditCorner("sw", function(gx, gy) return gx >= 0 and gx <= 4 and gy >= OLIVINE_H end)
  end

  if not warpToCoords(OLIVINE_GROUP, ROUTE40_MAP, 31, 39, "route40_se") then
    F.check("route40_se_arrived", false); F.finish(); return
  end
  if walk("Right", 7, "cross") then
    local x, y = F.pos()
    F.check("crossed_into_olivine_4_71", F.grp() == OLIVINE_GROUP and F.mapn() == OLIVINE_MAP and x == 4 and y == 71,
      string.format("map %d.%d (%d,%d)", F.grp(), F.mapn(), x, y))
    -- Until something redraws the whole view, those cells still show what Route 40 drew. The
    -- campaign's redraw was a wild battle; a Bag round trip is the same DrawWholeMapView.
    F.check("bag_round_trip_redraws_field", bagRoundTrip(), "ow=" .. tostring(F.ow()))
    F.shot("sw_corner_after_crossing")
    auditCorner("cross", function(gx, gy) return gx >= 0 and gx <= 6 and gy >= OLIVINE_H end)
  end

  if not warpToCoords(OLIVINE_GROUP, OLIVINE_MAP, 46, 68, "olivine_se") then
    F.check("olivine_se_arrived", false); F.finish(); return
  end
  if walk("Down", 3, "se") then
    local x, y = F.pos()
    F.check("se_reached_46_71", x == 46 and y == 71, string.format("(%d,%d)", x, y))
    F.shot("se_corner")
    auditCorner("se", function(gx, gy) return (gx >= 37 and gy >= OLIVINE_H) or gx >= OLIVINE_W end)
  end

  F.finish()
end)
