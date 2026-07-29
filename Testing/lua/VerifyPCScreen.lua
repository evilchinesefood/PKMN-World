-- VerifyPCScreen.lua — issue #47: the building-PC screen animation.
--
-- Two bugs, one code path, both invisible to the build:
--
--   1. Johto centres wrote gTileset_Building's ids (PC_Off 0x004 / PC_On 0x005) into
--      gTileset_Johto_Building, because the metatile was chosen by REGION and Johto is
--      "not Kanto". Johto's mt 5 is a plain wall with behaviour MB_NORMAL, so the screen
--      drew garbage AND the tile stopped being a PC — which is why the reported symptom
--      was "couldn't access it again until I left and came back". A map reload restores
--      the original blockdata, which is exactly why it looked intermittent.
--   2. RegionHub's PC never animated: IsBuildingPCTile passed isFrlg = FALSE hardcoded,
--      so the hub's u32 attributes were read as u16 and its PC reported behaviour 0x5A
--      instead of MB_PC (0x83). Neither detector fired.
--
-- Asserting on SCREENSHOTS would prove nothing here (the wrong metatile still draws
-- *something*), so every check reads the live map grid and the real behaviour bits.
--
-- The load-bearing assertion is the one that would FAIL on the old build: mt 5 must never
-- appear at a Johto PC tile, and the tile must still be MB_PC after the PC is closed.

local here = (debug.getinfo(1, "S").source:match("@(.*[\\/])") or "")
package.path = here .. "?.lua;" .. package.path

local S = require("symbols")
local F = require("lib").new(S, "VerifyPCScreen")

local MB_PC = 0x83
local OFF = S.BackupMapLayout.mapOffset

-- Live map grid. gBackupMapLayout is { s32 width; s32 height; u16 *map; } and the grid
-- carries the MAP_OFFSET border, so a map coord (x,y) sits at (x+7, y+7).
local function tileAt(x, y)
  local w = F.r32(S.gBackupMapLayout + S.BackupMapLayout.width)
  local p = F.r32(S.gBackupMapLayout + S.BackupMapLayout.map)
  if p < 0x02000000 or w <= 0 then return -1 end
  return F.r16(p + 2 * ((x + OFF) + (y + OFF) * w)) & 0x3FF
end

-- Walk up to the PC, face it, and sample the tile every few frames across the whole
-- 5-flicker animation. Returns the set of metatile ids the screen tile actually took.
--
-- `path` is explicit waypoints: leg() is a greedy axis-first walk, not a pathfinder, and both
-- of these PCs sit behind furniture that a straight line runs into.
-- Tags must stay free of ':' — they become Windows filenames via shot().
local function usePC(path, tx, ty, tag)
  if not F.route(path, tag .. "_approach") then
    F.check(tag .. " reached the PC", false, "route blocked")
    return {}, {}
  end
  F.face("Up")
  local seen, order = {}, {}
  local function sample()
    local t = tileAt(tx, ty)
    if not seen[t] then seen[t] = 0; order[#order + 1] = t end
    seen[t] = seen[t] + 1
  end
  sample()
  F.press("A", 2)
  -- PCTurnOnEffect flickers on a 6-frame cadence, 5 times, then the menu opens.
  for _ = 1, 90 do sample(); F.idle(2) end
  F.L(("%s: screen tile took ids %s"):format(tag, table.concat(order, ", ")))
  return seen, order
end

local function main()
  F.boot(100)

  ------------------------------------------------------------------ hub (bug 2)
  -- RegionHub PC is at (17,9); the player reads it from (17,10). The direct line south from the
  -- crest is walled, and the y=7 concourse is occupied by NPCs at (10,7) and (12,7) — object
  -- events block movement but are invisible to a collision-only path check, so these waypoints
  -- go along y=6 and drop to the hall at x=9.
  local hubSeen = usePC({ { 16, 6 }, { 9, 6 }, { 9, 7 }, { 8, 7 }, { 8, 8 }, { 6, 8 },
                          { 6, 12 }, { 17, 12 }, { 17, 10 } }, 17, 9, "hub")
  F.shot("hub_pc")
  F.check("hub PC tile starts as the unlit PC metatile 98", hubSeen[98] ~= nil)
  F.check("hub PC screen LIGHTS UP (mt 99 appears) — this never happened before the fix",
          hubSeen[99] ~= nil and hubSeen[99] > 0,
          "the hub read its u32 attributes as u16, saw behaviour 0x5A, and skipped the effect entirely")
  F.check("hub PC never writes Hoenn's ids", hubSeen[4] == nil and hubSeen[5] == nil)

  -- Close the PC and prove the tile came back as a usable PC, not a wall.
  F.dismiss(60)
  F.idle(60)
  F.check("hub PC tile is back to 98 after closing", tileAt(17, 9) == 98,
          "tile = " .. tileAt(17, 9))

  ---------------------------------------------------------------- Johto (bug 1)
  -- Cherrygrove City Pokémon Center = MAP_CHERRYGROVE_CITY_POKEMON_CENTER, group 77 num 0.
  F.warpTo(0, 7, 7, 0, 0, 0, 0, 0, 0, 77, 0, "warp to Cherrygrove PC")
  F.idle(120)
  F.check("arrived at Cherrygrove City Pokemon Center", F.grp() == 77 and F.mapn() == 0,
          ("group=%d num=%d"):format(F.grp(), F.mapn()))

  -- Arrival warp is the door at (7,8); the counter forces the approach up the left side first.
  local jSeen = usePC({ { 7, 4 }, { 11, 4 }, { 11, 2 } }, 11, 1, "johto")
  F.shot("johto_pc")
  F.check("Johto PC tile starts as the unlit PC metatile 98", jSeen[98] ~= nil)
  F.check("★ Johto PC NEVER writes Hoenn's METATILE_Building_PC_On (5) or _Off (4)",
          jSeen[5] == nil and jSeen[4] == nil,
          "this is the reported bug: mt 5 in gTileset_Johto_Building is a plain MB_NORMAL wall")
  F.check("Johto PC screen lights up with its own tileset's mt 99", jSeen[99] ~= nil)

  F.dismiss(60)
  F.idle(60)
  local after = tileAt(11, 1)
  F.check("★ Johto PC tile is still the PC metatile after closing (98)", after == 98,
          "tile = " .. after .. " — mt 5 here is what made the PC unusable until a map reload")

  -- The actual user-visible regression: does it still work a SECOND time, without leaving?
  -- Asserted by re-running the turn-on effect rather than by opening the menu: Text_BootUpPC is
  -- an MSGBOX_DEFAULT that waits for a button, so a single A lands on the message and not on the
  -- multichoice, and a menu-liveness check would be measuring press timing rather than the fix.
  -- The screen relighting requires IsPlayerInFrontOfPC to have accepted the tile again, which is
  -- exactly what the old build could not do once it had written mt 5 there.
  local again = usePC({ { 11, 2 } }, 11, 1, "johto_reopen")
  F.shot("johto_pc_reopen")
  F.check("★ the PC still works immediately, without leaving and re-entering the map",
          again[99] ~= nil,
          "the reported symptom was that the second interaction did nothing")
  F.dismiss(60)

  F.finish()
end

F.run(main)
