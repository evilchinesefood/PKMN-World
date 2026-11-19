-- The Battle Factory's other modes on the shared driver (frontier_facility.lua, see
-- FrontierFacilityStress.lua): a Lv. 50 doubles challenge that turns down every swap until the last
-- one, before the seventh battle, and an Open Level singles challenge with a Rest after the first win.
-- Each must rent three Pokemon, win all seven battles with real input, end in the lobby with the party
-- byte-identical, the frontier status cleared, the mode's own streak at 7 and its first Battle Point
-- award (doubles 4, singles 3) added, and the follower back. The doubles swap must change the first
-- party slot by the seventh battle.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/FactoryModesStress.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path

require("frontier_facility")("FactoryModesStress", {
  { name = "factory_doubles_swap_last", fac = "factory_doubles", mode = "full", swapLast = true },
  { name = "factory_open_rest", fac = "factory", mode = "rest", open = true },
})
