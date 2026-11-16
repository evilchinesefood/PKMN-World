-- A Battle Factory challenge with real input: rent three Pokemon, swap one after the first win, Rest
-- after the first win and Continue, run all seven battles; and a soft reset on the swap screen with no
-- save. The driver and the assertions are shared with FrontierFacilityStress.lua (see its header);
-- the Factory cases also check that three rentals replaced the party and that the swap traded the
-- first rental. Split out because the two together exceed the runner's 300,000-frame cap.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/FactoryRentalStress.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path

require("frontier_facility")("FactoryRentalStress", {
  { name = "factory_rest", fac = "factory", mode = "rest" },
  { name = "factory_reset_on_swap", fac = "factory", mode = "reset" },
})
