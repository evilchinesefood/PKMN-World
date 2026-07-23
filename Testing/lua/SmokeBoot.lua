-- Boot smoke + harness self-test: proves symbols.lua + lib.lua load and the core reads work on a
-- fresh build with NO hardcoded addresses. Evidence suite. Run:
--   EmuHawk.exe <rom> --lua=<repo>\Testing\lua\SmokeBoot.lua
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
  -- object dump proof: at least the player object is active
  local objs = F.objdump()
  F.check("object-event dump reads active objects", #objs >= 1, "#objs=" .. #objs)
  F.shot("hub")
  F.finish()
end)
