-- Salvage check for a REAL mid-playthrough save across the v9 break.
--
-- v9 does three things a save can notice, and the owner's live save hits two of them:
--   1. Appends johtoTrainerFlags[] to SaveBlock3 (un-checksummed tail -> must be zeroed).
--   2. Deletes two mid-group maps (issue #51), renumbering 17 gMapGroup_IndoorGoldenrod and
--      3 gMapGroup_MtSilver mapNums. Persisted in 5 WarpDatas + objectEvents[].
--   3. Moves the Violet City and Route 32 heal coordinates. lastHealLocation stores the
--      COORDINATE and GetHealLocationIndexByWarpData matches on exact x/y, so a save holding
--      the old pair silently stops matching the table and keeps whiting out to the old tile.
--
-- Issue #51 explicitly accepted a save RESET for (2). This suite is the evidence that a
-- migration was written instead and that a real save survives it.
--
-- Run against the owner's battery save (never the repo copy in place -- mgba-run.sh copies it
-- into a temp dir, but pass a COPY anyway):
--   Testing/mgba-run.sh Testing/lua/VerifyOwnerSave.lua pokemonworld.gba <copy-of>.sav
--
-- Expected pre-migration state of that save (read straight out of the .srm):
--   saveVersion 7 | location VioletCity(75,6) warpId 2 | lastHealLocation VioletCity (30,18)
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(require("symbols"), "VerifyOwnerSave")

local SAVE_FORMAT_VERSION = 9

-- SaveBlock1 warp fields (include/global.h). WarpData is 8 bytes, and the three s8s are followed
-- by a PAD byte before the s16s align: 0 group, 1 num, 2 warpId, 3 pad, 4 x, 6 y. Reading x at +3
-- returns the coordinate shifted one byte left (39 reads as 9984), which looks like corruption.
local WARP = { location = 0x04, continueGameWarp = 0x0C, dynamicWarp = 0x14,
               lastHealLocation = 0x1C, escapeWarp = 0x24 }

-- Where the save under test is standing. A real save moves, so these are overridable rather than
-- pinned: PW_EXPECT_GRP/PW_EXPECT_MAP. Defaults are the .srm copy (Violet City); the live .sav is
-- 79/5, RuinsOfAlph_PuzzleAndRewardChambers.
local EXPECT_GROUP = tonumber(os.getenv("PW_EXPECT_GRP") or "") or 75
local EXPECT_MAP   = tonumber(os.getenv("PW_EXPECT_MAP") or "") or 6

-- Where the save HEALS is a separate fact from where it is STANDING - conflating them only
-- looked right because the .srm copy happened to be saved in Violet City itself.
local VIOLET_GROUP, VIOLET_NUM = 75, 6
local HEAL_NEW_X, HEAL_NEW_Y   = 39, 46   -- data/heal_locations.json, one tile below the PC door
local HEAL_OLD_X, HEAL_OLD_Y   = 30, 18   -- the SPROUT TOWER door tile this save still held

-- The two groups issue #51 renumbers. Nothing in a correctly migrated save may still point at a
-- mapNum past the end of either group.
local GOLDENROD_GROUP, GOLDENROD_MAPS = 84, 28   -- was 29 maps, index 11 deleted
local MTSILVER_GROUP,  MTSILVER_MAPS  = 97, 12   -- was 13 maps, index 9 deleted

local function warp(off)
  local a = F.sb1() + off
  local g, n = F.r8(a), F.r8(a + 1)
  if g > 127 then g = g - 256 end
  return g, n, F.r16(a + 4), F.r16(a + 6)
end

F.run(function()
  -- expectGroup MUST be this save's own group. boot() blind-presses A/Start until the group
  -- matches, so a wrong value does not fail fast -- it mashes for 120,000 frames, opens the
  -- Pokedex, and reports BOOT FAIL as though the save were unreadable.
  if not F.boot(EXPECT_GROUP, true) then F.check("owner save boots", false); F.finish(); return end

  -- 1. It LOADED. A refused save drops the boot mash onto a fresh new game in the hub (grp 100),
  --    so landing on the saved map is itself the proof the layout gate let this through.
  local g, n = F.grp(), F.mapn()
  F.check("save loaded on its saved map, not a fresh new game",
    g == EXPECT_GROUP and n == EXPECT_MAP, ("grp=%d map=%d want=%d/%d"):format(g, n, EXPECT_GROUP, EXPECT_MAP))

  -- 2. The ladder ran to v9.
  local ver = F.r8(F.sb2() + S.SaveBlock2.saveVersion)
  -- Source version is whatever the save was (the .srm copy is v7, the live .sav is v8); both
  -- must land on the current format.
  F.check("saveVersion migrated up to " .. SAVE_FORMAT_VERSION, ver == SAVE_FORMAT_VERSION,
    "ver=" .. ver)

  -- 3. The appended trainer bank is clean (a stale bit = a trainer that reads as pre-defeated).
  local dirty = 0
  for i = 0, 31 do
    if F.r8(F.sb3() + S.SaveBlock3.johtoTrainerFlags + i) ~= 0 then dirty = dirty + 1 end
  end
  F.check("johtoTrainerFlags bank zeroed", dirty == 0, "dirty bytes=" .. dirty)

  -- 4. lastHealLocation re-pointed off the Sprout Tower tile onto the PokeCenter one. This is
  --    the whole reason the owner's whiteout was landing outside Bellsprout Tower.
  local hg, hn, hx, hy = warp(WARP.lastHealLocation)
  F.check("lastHealLocation still Violet City", hg == VIOLET_GROUP and hn == VIOLET_NUM,
    ("grp=%d num=%d"):format(hg, hn))
  F.check("lastHealLocation moved off the Sprout Tower tile",
    not (hx == HEAL_OLD_X and hy == HEAL_OLD_Y), ("(%d,%d)"):format(hx, hy))
  F.check("lastHealLocation now the PokeCenter coordinate",
    hx == HEAL_NEW_X and hy == HEAL_NEW_Y, ("(%d,%d)"):format(hx, hy))

  -- 5. Every persisted warp names a map that still EXISTS. Deleting a mid-group map without
  --    migrating would leave one of these one past the end of its (now shorter) group, or
  --    silently pointing at its neighbour.
  local okAll, detail = true, {}
  for _, name in ipairs({ "location", "continueGameWarp", "dynamicWarp", "lastHealLocation", "escapeWarp" }) do
    local wg, wn = warp(WARP[name])
    local bad = (wg == GOLDENROD_GROUP and wn >= GOLDENROD_MAPS)
             or (wg == MTSILVER_GROUP  and wn >= MTSILVER_MAPS)
    if bad then okAll = false end
    detail[#detail + 1] = ("%s=%d/%d"):format(name, wg, wn)
  end
  F.check("no persisted warp points past the end of a renumbered group", okAll,
    table.concat(detail, " "))

  F.shot("owner_save_loaded")
  F.finish()
end)
