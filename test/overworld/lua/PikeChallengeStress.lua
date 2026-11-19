-- Battle Pike challenges played with real input from the lobby attendant to the end, room by room,
-- on the shared driver pike_challenge.lua (PikeFollowerChoice.lua runs the follower cases on it).
--
-- Setup (not under test): a fresh game, six distinct Lv. 50 Pokemon, distinct held items on the three
-- that enter, and per case the follower choice and the Pike streak an earlier challenge leaves. The
-- challenge itself is real: the attendant's menus, the party screen pick, the save, the corridor, a
-- seeded walk to a door in each three-path room, every room's own script (battles, the heal rooms,
-- the status room, the wild grass, the Pike Queen), the exit doors and the lobby's ending. Battles are
-- won on the real move menu with the foes held at 1 HP and the player's battlers topped up.
--
-- Cases here:
--   lv50_doors       seven rooms at Lv. 50 with seeded doors.
--   queen            the streak one won challenge leaves, so the last room is the Pike Queen's; she
--                    must give the silver symbol and the award must add her 10 Battle Points.
--   reset_in_room    a soft reset with no save after the second room, with the chosen follower
--                    entered second. Continue lands in the lobby, whose attendant ends the challenge
--                    as unsaved: streak 0, record, total and Battle Points unchanged.
-- Every case ends in the lobby with control, the party byte-identical to the one that walked in
-- (held items included), the frontier status cleared, the streak, record, total and Battle Points
-- the ending earns, and the follower the player chose walking behind them.
--
-- `--env PW_CASE=<text>` runs the cases whose name contains the text; `--env PW_PIKE_SEED=<n>`
-- reseeds the door choices; `--env PW_PIKE_TRACE=1` logs the field state every 2,000 frames.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/PikeChallengeStress.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path

require("pike_challenge")("PikeChallengeStress", {
  { name = "lv50_doors" },
  { name = "queen", streak = 14 },
  { name = "reset_in_room", follow = 4, picks = { 2, 4, 3 }, resetAfter = 2 },
})
