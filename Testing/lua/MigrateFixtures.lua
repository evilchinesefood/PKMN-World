-- Save-format LAYOUT GATE guard rail (issue #20 / folded #21, repurposed for #24's v7 break).
--
-- WHAT CHANGED (2026-07-24): save format v7 RESHAPED SaveBlock1 (bag Items 30->60, Key Items
-- 30->99, item PC 50->150). Owner decision was new-saves-only, so src/save.c now refuses any save
-- older than SAVE_FORMAT_LAYOUT_MIN outright instead of migrating it.
--
-- That makes the whole v0..v6 migration ladder UNREACHABLE, and with it the thing this suite used
-- to assert. Rather than delete a suite that can no longer pass, it now tests what actually has to
-- hold — and it is a stronger property than the one it replaced:
--
--   A pre-v7 fixture must be REFUSED, not half-loaded.
--
-- That refusal is the whole point of the gate. Growing bag/pcItems shifts every later SaveBlock1
-- field by 796 bytes, but both live in SaveBlock1 CHUNK 0 and SAVEBLOCK_CHUNK only varies the LAST
-- chunk's size — so chunks 0-2 keep size 3968, their stored checksums still match the flash bytes,
-- and a legacy save loads "successfully" into the shifted layout with silently misaligned flags
-- and vars. Only chunk 3 fails. The checksum is NOT a gate; SAVE_FORMAT_LAYOUT_MIN is, and this
-- suite is what proves it is wired up.
--
-- Run against any pre-v7 fixture (v3/v4/v5 all work — they are all below the floor):
--   cp <repo>\pokemonworld.gba  BizHawk\MigChk.gba
--   make symbols                          -- symbols.lua is ROM-bound; lib.new() rejects a mismatch
--   cp Testing\lua\fixtures\v3.srm  BizHawk\GBA\SaveRAM\MigChk.SaveRAM   (raw 131072-byte body)
--   EmuHawk.exe BizHawk\MigChk.gba --lua=<repo>\Testing\lua\MigrateFixtures.lua
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(require("symbols"), "MigrateFixtures")

-- Must match SAVE_FORMAT_LAYOUT_MIN in include/constants/global.h.
local LAYOUT_MIN = 7

F.run(function()
  -- boot() blind-presses A/Start, so on a refused save it walks the NEW GAME path rather than
  -- Continue. Either way it must reach the overworld without crashing — a gate that hangs or
  -- crashes on a legacy save is no better than one that half-loads it.
  if not F.boot() then F.check("legacy fixture does not crash the boot path", false); F.finish(); return end
  F.check("legacy fixture reaches the overworld without crashing", F.ow())

  local sb2, sb3 = F.sb2(), F.sb3()

  -- The decisive assertion. Whatever save is live after boot, it must NOT be the pre-v7 fixture:
  -- either the gate refused it and we are on a fresh new game (stamped current), or something is
  -- wrong. A saveVersion below the floor here means a legacy save was let through.
  local ver = F.r8(sb2 + S.SaveBlock2.saveVersion)
  F.check("no pre-v7 save is live after boot (layout gate held)", ver >= LAYOUT_MIN, "ver=" .. ver)

  -- Cross-check on the reshaped side. A half-loaded legacy save is exactly the failure mode the
  -- gate exists to prevent, and its signature is garbage in the shifted region banks. On a fresh
  -- new game these read clean, so a non-zero here means legacy bytes survived into the new layout.
  local SB3 = S.SaveBlock3
  local johtoByte = F.r8(sb3 + SB3.johtoFlags)
  F.check("johtoFlags bank is clean (no legacy bytes in the shifted layout)", johtoByte == 0,
    "byte0=" .. johtoByte)

  local kantoByte = F.r8(sb3 + SB3.kantoTrainerFlags)
  F.check("kantoTrainerFlags bank is clean", kantoByte == 0, "byte0=" .. kantoByte)

  local jVar = F.r16(sb3 + SB3.regionVars + 0x100 * 2)  -- a Johto-slice regionVars cell
  F.check("regionVars Johto-slice cell is 0", jVar == 0, "cell=" .. jVar)

  -- The v7 obstacle bitfield stamps its generated-table hash on load (ResyncClearedObstacleTable).
  -- Zero would mean that never ran, which is how obstacle bits silently drift after a map edit.
  local hash = F.r32(sb3 + SB3.obstacleTableHash)
  F.check("obstacle table hash is stamped (not 0)", hash ~= 0, string.format("hash=0x%08X", hash))

  -- Fresh save: nothing cut or smashed yet.
  local bits0 = F.r8(sb3 + SB3.clearedObstacleBits)
  F.check("cleared-obstacle bits start empty", bits0 == 0, "byte0=" .. bits0)

  F.shot("gated")
  F.finish()
end)
