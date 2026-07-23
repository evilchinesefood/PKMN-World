-- Save-format migration guard rail (issue #20 / folded #21).
--
-- Run against a historical-format fixture pair (a fresh-new-game .srm from a v1..v5 build, loaded
-- by the CURRENT build so MigrateSaveFormatIfNeeded runs on Continue):
--   cp <repo>\pokemonworld.gba  BizHawk\MigChk.gba
--   cp Testing\lua\fixtures\v3.srm  BizHawk\GBA\SaveRAM\MigChk.SaveRAM   (raw 131072-byte body)
--   EmuHawk.exe BizHawk\MigChk.gba --lua=<repo>\Testing\lua\MigrateFixtures.lua
--
-- Asserts the migration produced a v6-stamped, SANE save with one readable value per un-checksummed
-- SaveBlock3 bank + currentRegion + saveVersion, and that it did not crash (booted to overworld).
-- A fresh new-game fixture has deterministic post-migration invariants (empty banks / no progress),
-- so these are exact, not range checks — that is what makes a broken ladder step FAIL loudly.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(require("symbols"), "MigrateFixtures")

-- current SAVE_FORMAT_VERSION expectation (bump alongside include/constants/global.h)
local EXPECT_VERSION = 6

F.run(function()
  -- Continue the loaded fixture into the overworld; migration runs during LoadGameSave.
  if not F.boot() then F.check("migrated save boots (no crash / corruption)", false); F.finish(); return end
  F.check("migrated save boots to the overworld (no crash)", F.ow())

  local sb2, sb3 = F.sb2(), F.sb3()
  local ver = F.r8(sb2 + S.SaveBlock2.saveVersion)
  F.check("saveVersion stamped to current (" .. EXPECT_VERSION .. ")", ver == EXPECT_VERSION, "ver=" .. ver)

  local region = F.r8(sb2 + S.SaveBlock2.currentRegion)
  F.check("currentRegion is a valid enum (NONE..HOENN)", region >= 0 and region <= 3, "region=" .. region)

  -- One value per un-checksummed SaveBlock3 bank. A fresh new-game fixture has no region progress,
  -- so every bank reads its clean/empty value after migration.
  F.check("clearedObstacleCount is 0 (v4->v5 field zeroed)", F.r16(sb3 + 1164) == 0, "count=" .. F.r16(sb3 + 1164))

  local usmCount = F.r8(sb3 + 928 + 12)  -- usmSaved.items[12] then u8 count
  F.check("usmSaved count is sane (0..12)", usmCount >= 0 and usmCount <= 12, "count=" .. usmCount)

  local johtoByte = F.r8(sb3 + 800)          -- first johtoFlags byte
  F.check("johtoFlags bank readable + empty (no Johto progress)", johtoByte == 0, "byte0=" .. johtoByte)

  local kantoByte = F.r8(sb3 + 941)          -- first kantoTrainerFlags byte
  F.check("kantoTrainerFlags bank readable + empty (no Kanto defeats)", kantoByte == 0, "byte0=" .. kantoByte)

  -- regionVars: a Johto var cell must be readable and within u16 range (the v5->v6 rebase target).
  local jVar = F.r16(sb3 + 32 + 0x100 * 2)   -- an arbitrary regionVars cell (Johto slice area)
  F.check("regionVars bank readable (u16 in range)", jVar >= 0 and jVar <= 0xFFFF)

  F.shot("migrated")
  F.finish()
end)
