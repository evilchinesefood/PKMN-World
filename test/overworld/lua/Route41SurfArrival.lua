-- Issue #289: exercise real field initialization at the Route 40 sea arrivals.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "Route41SurfArrival")
F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  for _, warp in ipairs({4, 8, 9}) do
    local ok = F.warpTo(0, 8, 7, 0, 0, 2, 0, warp // 10, warp % 10, 87, 2, "sea_arrival_" .. warp)
    F.check("Route 41 warp " .. warp, ok)
    if not ok then F.finish(); return end
    F.check("arrival " .. warp .. " starts surfing", (F.r8(S.gPlayerAvatar) & 8) ~= 0)
    local x, y = F.pos()
    F.check("arrival coordinates " .. warp, x == 33 + warp and y == 12)
    F.check("can surf south from arrival " .. warp, F.step("Down"))
    local nx, ny = F.pos()
    F.check("moved south at sea " .. warp, nx == x and ny > y)
  end
  F.finish()
end)
