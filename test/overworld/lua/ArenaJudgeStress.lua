-- Battle Arena challenges where every matchup runs its three turns to the referee's judgment.
-- The shared driver (frontier_facility.lua, see FrontierFacilityStress.lua) takes the Lv. 50
-- challenge with real input; in judge mode it holds every battler at full HP instead of putting the
-- foes at 1 HP, so no Pokemon faints from damage and the referee decides each matchup on Mind, Skill
-- and Body. The battles are fought on the real move menu and the judgments, wins and losses fall
-- where the AI and the referee put them; the challenge ends when the player has lost a battle or won
-- seven. The second case runs the same challenge at Instant text speed. The third holds only the
-- foes at full HP, so the player's Pokemon take damage, lose judgments, faint and are replaced
-- through the in-battle party screen until the challenge is lost or won.
--
-- Each case must end in the lobby with control, the party byte-identical to the one that entered,
-- the frontier status cleared, the win streak equal to the battles won, Battle Points only for a
-- won challenge, the follower back behind the player, and every battle must have reached the
-- referee at least once. Screenshots of the judgment window are saved for review.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/ArenaJudgeStress.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path

require("frontier_facility")("ArenaJudgeStress", {
  { name = "arena_judged", fac = "arena", judge = true },
  { name = "arena_judged_instant", fac = "arena", judge = true, instant = true },
  { name = "arena_judged_weak", fac = "arena", judge = "weak" },
})
