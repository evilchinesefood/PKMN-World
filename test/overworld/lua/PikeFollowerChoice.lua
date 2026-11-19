-- The Pokemon the player chose to follow them must still be the chosen follower after a Battle Pike
-- challenge, on the shared driver pike_challenge.lua (see PikeChallengeStress.lua for the setup and
-- the checks every case makes).
--
-- The choice is a party slot (SaveBlock2.followerSlot) backed by the chosen Pokemon's identity. The
-- Pike stands the three entered Pokemon in for the party and puts the real party back from
-- SaveBlock1 when the challenge ends.
--   open_follower    Open Level; the chosen follower (party slot 4) is not entered, so it is missing
--                    from the party for the whole challenge.
--   pause_resume     the chosen follower is picked first, so it stands in party slot 1. After the
--                    second room the three-path attendant saves and quits, which writes the real
--                    party; Continue must resume the challenge with three Pokemon in the room.
-- After the challenge the chosen Pokemon must walk behind the player and followerSlot must name
-- party slot 4 again.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/PikeFollowerChoice.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path

require("pike_challenge")("PikeFollowerChoice", {
  { name = "open_follower", open = true, follow = 4 },
  { name = "pause_resume", follow = 4, picks = { 4, 1, 2 }, pauseAfter = 2 },
})
