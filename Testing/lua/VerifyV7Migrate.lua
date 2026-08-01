-- The one test that could not be written after the fact (issue #59 step 0.5 + D5).
--
-- fixtures/v7.srm was harvested from the LAST pre-edit build (master f70b8854, ROM md5
-- e2972793): a fresh game debug-warped into OldaleTown's Pokemon Center 1F and manually
-- saved at (7,4), mid-room, so the saved mapView window covers BOTH the Town Map poster
-- and the escalator that this branch removed. No such save can be produced any more.
--
-- What it proves, in order:
--   1. SAVE_FORMAT_LAYOUT_MIN stayed 7: the v7 save LOADS (Continue works) instead of
--      being refused like the v3/v4/v5 fixtures.
--   2. The v7 -> v8 ladder step ran: saveVersion reads 8 in RAM after boot.
--   3. The stale mapView did NOT repaint the old room over the new layout: the live map
--      grid holds the terminal metatiles and the stair fills, not the poster / escalator.
--      This is the assertion that needs the fixture -- on any post-edit save mapView is
--      already clean and the check would pass vacuously.
--
-- Run (the fixture must be this ROM's battery save):
--   cp <repo>/pokemonworld.gba              BizHawk\MigChkV7.gba
--   cp Testing\lua\fixtures\v7.srm          BizHawk\GBA\SaveRAM\MigChkV7.SaveRAM
--   EmuHawk.exe BizHawk\MigChkV7.gba --lua=<repo>\Testing\lua\VerifyV7Migrate.lua
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(require("symbols"), "VerifyV7Migrate")

local SAVE_FORMAT_VERSION = 8
local MAPVIEW_OFF = 0x34            -- include/global.h: /*0x34*/ u16 mapView[0x100]

-- LAYOUT_POKEMON_CENTER_1F after the edit (ApplyMaps.py): the cells the stale
-- mapView would have repainted, with the metatile id each must now hold.
local CELLS = {
  { 11, 1, 743, "terminal screen" },
  { 11, 2, 751, "terminal pedestal" },
  { 12, 1, 531, "poster row-1 fill" },
  { 12, 0, 523, "poster row-0 fill" },
  { 0, 5, 544, "stair wall fill (0,5)" },
  { 1, 6, 514, "stair floor fill (1,6)" },
}

local function gridAt(x, y)
  local w = F.r32(S.gBackupMapLayout)                       -- s32 width
  local map = F.r32(S.gBackupMapLayout + 8)                 -- u16 *map
  return F.r16(map + ((x + 7) + w * (y + 7)) * 2) & 0x3FF   -- MAP_OFFSET = 7
end

F.run(function()
  -- boot() blind-presses A/Start: on a VALID save that walks the Continue path.
  if not F.boot(2, true) then F.check("v7 save boots", false); F.finish(); return end

  -- 1. The save LOADED: we are inside Oldale's Center at the harvested spot, not on a
  --    fresh new game in the hub (which is where a REFUSED save lands the boot mash).
  local x, y = F.pos()
  F.check("Continue landed inside the Center (v7 still loads)",
    F.grp() == 2 and F.mapn() == 2, ("grp=%d map=%d"):format(F.grp(), F.mapn()))
  F.check("player at the harvested save spot (7,4)", x == 7 and y == 4,
    ("pos=(%d,%d)"):format(x, y))

  -- 2. The ladder ran.
  local ver = F.r8(F.sb2() + S.SaveBlock2.saveVersion)
  F.check("saveVersion migrated 7 -> " .. SAVE_FORMAT_VERSION, ver == SAVE_FORMAT_VERSION,
    "ver=" .. ver)

  -- 3. The room renders the NEW layout. If the ladder step had not zeroed mapView,
  --    InitMapFromSavedGame's restore (which runs BEFORE the on-load script) would have
  --    painted the old poster and escalator back over these cells.
  for _, c in ipairs(CELLS) do
    local got = gridAt(c[1], c[2])
    F.check(("map grid (%d,%d) holds mt%d (%s)"):format(c[1], c[2], c[3], c[4]),
      got == c[3], "got mt" .. got)
  end

  -- The mapView itself must be clean in RAM as well (the ladder zeroed it, and
  -- ClearSavedMapView wipes it again after any restore).
  local dirty = 0
  for i = 0, 0xFF do
    if F.r16(F.sb1() + MAPVIEW_OFF + i * 2) ~= 0 then dirty = dirty + 1 end
  end
  F.check("SaveBlock1.mapView is zeroed", dirty == 0, "nonzero entries=" .. dirty)

  F.finish()
end)
