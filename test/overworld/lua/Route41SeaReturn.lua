-- The Route 40/41 strait must be crossable in both directions.
--
-- Route 40's water-arrow row (12..20,60) drops the player at Route 41 (37..45,12), and that was the
-- only way across: Route 41 row 11 (x 37..45) and Route 40 row 61 (x 12..20) were plain ocean tiles
-- with the collision bit set, an invisible wall on both sides of the strait. Once on Cianwood's side a
-- player could not surf back, Fly only unlocks at Jasmine's badge, and that badge needs the Secret
-- Potion from Cianwood -- a softlock for anyone without Teleport (found by the full Johto playthrough,
-- test/overworld/johto-playthrough/). This walks the strait north, from a sea arrival to Route 40
-- above the arrow row, by controller input.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "Route41SeaReturn")
local ROUTE40, ROUTE41 = 1, 2   -- gMapGroup_JohtoOlivine: OlivineCity, Route40, Route41, ...
F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  local ok = F.warpTo(0, 8, 7, 0, 0, 2, 0, 0, 8, 87, ROUTE41, "sea_arrival")
  F.check("warp to the Route 41 sea arrival", ok)
  if not ok then F.finish(); return end
  F.check("arrival is surfing", (F.r8(S.gPlayerAvatar) & 8) ~= 0)
  local x0, y0 = F.pos()
  F.check("arrival at (41,12)", x0 == 41 and y0 == 12, string.format("(%d,%d)", x0, y0))
  F.check("can surf north off the arrival row", F.step("Up"))
  for _ = 1, 40 do
    if F.mapn() == ROUTE40 then break end
    if not F.step("Up") then break end
  end
  F.check("Route 41's north edge leads onto Route 40", F.grp() == 87 and F.mapn() == ROUTE40,
    string.format("map %d.%d (%d,%d)", F.grp(), F.mapn(), F.pos(), select(2, F.pos())))
  for _ = 1, 20 do
    local _, y = F.pos()
    if y <= 59 then break end
    if not F.step("Up") then break end
  end
  local x, y = F.pos()
  F.check("surf past Route 40's arrow row toward Olivine", F.mapn() == ROUTE40 and y <= 59,
    string.format("(%d,%d)", x, y))
  F.check("still surfing", (F.r8(S.gPlayerAvatar) & 8) ~= 0)
  F.finish()
end)
