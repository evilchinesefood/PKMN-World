-- Boot smoke + harness self-test: proves symbols.lua + lib.lua load and the core reads work on a
-- fresh build with NO hardcoded addresses. Evidence suite.
--
-- Run against a THROWAWAY COPY — lib.new() now refuses anything not named Verify*/MigChk*/FixGen*,
-- because this suite blind-presses A and Start and BizHawk flushes SaveRAM on exit:
--   cp <repo>\pokemonworld.gba  BizHawk\Verify1.gba
--   make symbols                          # symbols.lua is bound to the ROM; make -j12 alone won't
--   EmuHawk.exe BizHawk\Verify1.gba --lua=<repo>\Testing\lua\SmokeBoot.lua
--
-- Exits non-zero on failure and drops _pwtest\SmokeBoot.PASS or .FAIL for a wrapper to stat.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(require("symbols"), "SmokeBoot")

F.run(function()
  -- bound both ends: gMain must be in IWRAM (0x03000000-0x03007FFF), CB2_Overworld in ROM
  -- (0x08000000-0x09FFFFFF). A garbage-but-above-threshold address would pass a lower-bound-only check.
  F.check("symbols loaded (gMain in IWRAM)", S.gMain ~= nil and S.gMain > 0x03000000 and S.gMain < 0x03008000)
  F.check("symbols loaded (CB2_Overworld in ROM)", S.CB2_Overworld ~= nil and S.CB2_Overworld > 0x08000000 and S.CB2_Overworld < 0x0A000000)
  if not F.boot(100) then F.check("boot to overworld", false); F.finish(); return end
  F.check("booted to the RegionHub (map group 100)", F.grp() == 100, "grp=" .. F.grp())
  F.check("fresh boot lands at hub crest (16,4)", select(1, F.pos()) == 16 and select(2, F.pos()) == 4,
    string.format("(%d,%d)", select(1, F.pos()), select(2, F.pos())))
  F.check("fresh boot party is empty", F.r8(S.gPartiesCount) == 0, "cnt=" .. F.r8(S.gPartiesCount))
  -- step proof: move one tile and confirm coords changed
  local x0, y0 = F.pos()
  local moved = false
  for _, d in ipairs({ "Down", "Up", "Left", "Right" }) do
    if F.step(d) then moved = true; break end
  end
  F.check("coordinate-verified step moves the player", moved and (select(1, F.pos()) ~= x0 or select(2, F.pos()) ~= y0))
  -- Object-dump proof, cross-validated against an UNRELATED symbol.
  --
  -- This used to be `#objs >= 1`, which passes against a WRONG gObjectEvents with probability
  -- ~1 - 2^-16: objdump keeps any of 16 structs whose byte 0 has bit 0 set, so pointing it at
  -- essentially any RAM yields a non-empty list. Near-zero discriminating power, inside the one
  -- suite whose whole job is proving the symbol table correct.
  --
  -- Agreement between two independently-resolved symbols is a real proof: the player is object
  -- index 0, and its (x-7, y-7) must equal the position read through gSaveBlock1Ptr. Both would
  -- have to be wrong in the same direction to pass.
  local objs = F.objdump()
  local player = nil
  for _, o in ipairs(objs) do if o.i == 0 then player = o end end
  local px, py = F.pos()
  F.check("gObjectEvents: player object index 0 is active", player ~= nil, "#objs=" .. #objs)
  F.check("gObjectEvents agrees with gSaveBlock1Ptr on player position",
    player ~= nil and player.x == px and player.y == py,
    player and string.format("obj=(%d,%d) sb1=(%d,%d)", player.x, player.y, px, py)
           or string.format("no player object; sb1=(%d,%d)", px, py))
  F.shot("hub")
  F.finish()
end)
