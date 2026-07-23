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

  -- A fresh new-game fixture never crosses a region gate, so migration leaves currentRegion at
  -- exactly REGION_NONE (0). Assert the exact value, not a range — a range accepts a migration bug
  -- that corrupts it to any other in-range region.
  local region = F.r8(sb2 + S.SaveBlock2.currentRegion)
  F.check("currentRegion is exactly REGION_NONE (0)", region == 0, "region=" .. region)

  -- One value per un-checksummed SaveBlock3 bank, read via the generated symbol table (single
  -- source of truth with the C struct) — never raw literals. A fresh new-game fixture has no region
  -- progress, so every bank reads its clean/empty value after migration. These are EXACT checks so
  -- a layout shift or a broken ladder step FAILs loudly (a range check would pass on drift).
  local SB3 = S.SaveBlock3
  F.check("clearedObstacleCount is 0 (v4->v5 field zeroed)", F.r16(sb3 + SB3.clearedObstacleCount) == 0,
    "count=" .. F.r16(sb3 + SB3.clearedObstacleCount))

  local usmCount = F.r8(sb3 + SB3.usmSaved + 12)  -- usmSaved.items[12] then u8 count
  F.check("usmSaved count is sane (0..12)", usmCount >= 0 and usmCount <= 12, "count=" .. usmCount)

  local johtoByte = F.r8(sb3 + SB3.johtoFlags)          -- first johtoFlags byte
  F.check("johtoFlags bank readable + empty (no Johto progress)", johtoByte == 0, "byte0=" .. johtoByte)

  local kantoByte = F.r8(sb3 + SB3.kantoTrainerFlags)   -- first kantoTrainerFlags byte
  F.check("kantoTrainerFlags bank readable + empty (no Kanto defeats)", kantoByte == 0, "byte0=" .. kantoByte)

  -- regionVars: a Johto slice cell is exactly 0 on a fresh fixture (no region-var progress, and the
  -- v5->v6 rebase copies from a zero SaveBlock1.vars source). An exact 0 catches drift; a "u16 in
  -- range" check is a tautology (a u16 read is ALWAYS in [0,0xFFFF]) and verifies nothing.
  local jVar = F.r16(sb3 + SB3.regionVars + 0x100 * 2)  -- a Johto-slice regionVars cell
  F.check("regionVars Johto-slice cell is 0 (no region-var progress)", jVar == 0, "cell=" .. jVar)

  F.shot("migrated")
  F.finish()
end)
