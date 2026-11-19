-- The Pokemon the player chose with the party menu's Follow must still follow after a Battle Arena
-- or Battle Factory challenge, on the shared driver frontier_facility.lua (see
-- FrontierFacilityStress.lua). Setup writes followerSlot 4 (Pikachu) as a Continue would leave it.
-- The Arena challenge enters the other three Pokemon and the Factory rents three, so Pikachu is out
-- of the party for the challenge; one battle is won and the challenge is retired through the real
-- menus. Once the lobby has restored the party, Pikachu must walk behind the player and followerSlot
-- must still be 4.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/FrontierFollowerChoice.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path

require("frontier_facility")("FrontierFollowerChoice", {
  { name = "arena_retire_pikachu_follows", fac = "arena", mode = "retire", follow = 4 },
  { name = "factory_retire_pikachu_follows", fac = "factory", mode = "retire", follow = 4 },
})
