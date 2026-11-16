-- Full challenges at the Battle Arena, Palace and Dome with real input, including a Rest with
-- Continue in the middle and a soft reset with no save. FactoryRentalStress.lua runs the Battle
-- Factory on the same driver (frontier_facility.lua).
--
-- Each case boots a fresh game, gives four Pokemon (Charizard leads, so it is the follower), warps
-- into the lobby and takes the Lv. 50 singles challenge through the attendant's real menus, the
-- party pick and the save. Battles are won with real input on the move menu while the opponents are
-- held at 1 HP and the player's battler is kept topped up (setup, not the thing under test). The
-- Factory rents three Pokemon and swaps one after the first win; the Dome picks two Pokemon before
-- each round.
--
-- "rest" cases pick Rest after the first win, which saves and returns to the title; Continue must
-- resume the paused challenge (frontier status PAUSED), and the challenge then runs to the end. The
-- player must end in the lobby with control, the party byte-identical to the one that entered (the
-- Factory's rentals gone), the win streak at the challenge length, the lowest Battle Point award for
-- the facility added, and the follower walking behind again.
--
-- "reset" cases soft reset with no save: on the Dome tourney tree before the second round (and, in
-- FactoryRentalStress, on the swap screen after the first win). Continue must land in the lobby with the
-- "didn't save" ending: streak 0, frontier status cleared, the party byte-identical, no BP.
--
-- `--env PW_CASE=<text>` runs the cases whose name contains the text.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/FrontierFacilityStress.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path

require("frontier_facility")("FrontierFacilityStress", {
  { name = "arena_rest", fac = "arena", mode = "rest" },
  { name = "palace_rest", fac = "palace", mode = "rest" },
  { name = "dome_rest", fac = "dome", mode = "rest" },
  { name = "dome_reset_on_tree", fac = "dome", mode = "reset" },
})
