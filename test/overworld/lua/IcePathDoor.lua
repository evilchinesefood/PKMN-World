-- Route 44's Ice Path door must be enterable.
--
-- The door, warp 0 at (68,12), can only be entered from (68,13): (67,12) and (69,12) are cliff.
-- A scenery Pidgeotto (object 24, flag 0, never moves) was placed exactly on (68,13) when the
-- static overworld Pokemon were re-pointed in July -- its upstream tile, (68,9), is inside the
-- cliff -- so the only land route to Blackthorn and the eighth badge was shut. Found by the Johto
-- playthrough (test/overworld/johto-playthrough/). Arrives on the door tile by debug warp, then
-- walks off it and back into it.
-- (The warp sets the player down on (68,13) even with the Pidgeotto there, so the check is the walk back.)
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "IcePathDoor")
F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  local ok = F.warpTo(0, 9, 1, 0, 0, 3, 0, 0, 0, 91, 3, "route44_door")
  F.check("warp to Route 44's Ice Path door", ok)
  if not ok then F.finish(); return end
  local x, y = F.pos()
  -- A door warp sets the player down one tile out, on (68,13) itself.
  F.check("set down in front of the door", x == 68 and y == 13, string.format("(%d,%d)", x, y))
  F.check("step back from the door", F.step("Down"))
  F.check("walk up to the door again", F.step("Up"), string.format("at (%d,%d)", F.pos(), select(2, F.pos())))
  F.press("Up", 40); F.idle(240)
  F.check("walking into the door enters the Ice Path", F.grp() == 94 and F.mapn() == 7,
    string.format("map %d.%d", F.grp(), F.mapn()))
  F.finish()
end)
