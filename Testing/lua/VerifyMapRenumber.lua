-- Issue #51's actual save hazard, proven rather than assumed.
--
-- v9 deleted MAP_GOLDENROD_CITY_DEPARTMENT_STORE_7FNIGHT (gMapGroup_IndoorGoldenrod index 11) and
-- MAP_MT_SILVER_SUMMIT_NIGHT (gMapGroup_MtSilver index 9). Neither was LAST in its group, so every
-- map after them renumbered down by one -- 17 maps and 3 maps respectively. mapNum is persisted in
-- five SaveBlock1 WarpDatas and in objectEvents[], so without a migration a pre-v9 save silently
-- re-points at the neighbouring room. For lastHealLocation that means whiting out somewhere the
-- player never healed.
--
-- The owner's real save cannot prove this: none of its warps are in either group, so the check is
-- VACUOUS there (VerifyOwnerSave says so). This suite uses a crafted save that IS, built by taking
-- the real save and writing pre-deletion indices into two warps, then recomputing the SaveBlock1
-- sector checksum (SaveBlock1 IS checksummed, unlike the SaveBlock3 banks):
--
--   lastHealLocation = 84/19  GoldenrodCity_RadioTower_1F, pre-deletion index
--   escapeWarp       = 97/11  Route28,                     pre-deletion index
--
-- Verified to discriminate: without MigrateDeletedTwinMaps() both read back unchanged (19 and 11).
--
--   Testing/mgba-run.sh Testing/lua/VerifyMapRenumber.lua pokemonworld.gba <crafted>.sav
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(require("symbols"), "VerifyMapRenumber")

local VIOLET_GROUP = 75          -- the crafted save still STARTS in Violet; only the warps moved
local HEAL_OFF, ESCAPE_OFF = 0x1C, 0x24

-- WarpData: 0 group, 1 num, 2 warpId, 3 pad, 4 x, 6 y
local function warp(off)
  local a = F.sb1() + off
  local g = F.r8(a)
  if g > 127 then g = g - 256 end
  return g, F.r8(a + 1)
end

F.run(function()
  if not F.boot(VIOLET_GROUP, true) then F.check("crafted save boots", false); F.finish(); return end

  local ver = F.r8(F.sb2() + S.SaveBlock2.saveVersion)
  F.check("saveVersion migrated to 9", ver == 9, "ver=" .. ver)

  -- Goldenrod: 19 sat after the deleted index 11, so it must now read 18.
  local hg, hn = warp(HEAL_OFF)
  F.check("lastHealLocation renumbered 84/19 -> 84/18", hg == 84 and hn == 18,
    ("%d/%d"):format(hg, hn))

  -- Mt Silver: 11 sat after the deleted index 9, so it must now read 10.
  local eg, en = warp(ESCAPE_OFF)
  F.check("escapeWarp renumbered 97/11 -> 97/10", eg == 97 and en == 10,
    ("%d/%d"):format(eg, en))

  -- Neither may land past the end of its now-shorter group (28 and 12 maps).
  F.check("both warps inside their shortened groups", hn < 28 and en < 12,
    ("goldenrod=%d/28 mtsilver=%d/12"):format(hn, en))

  F.finish()
end)
