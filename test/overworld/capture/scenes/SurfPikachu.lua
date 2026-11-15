-- Surfboard Pikachu: unlock and catch on Route 19, see it in the party and summary, then lead
-- with it into Reece's battle and use Surf. Route from SpecialPokemonCatchRecovery.lua.
local F, S, X = dofile(os.getenv("REC_TOOLS") .. "/Show.lua")("SurfPikachu")
local SP = X.SPECIES
local MOVE_SURF = 57

local function goToSurfboard()
  if not X.warpId(37, 7, 6, "fuchsia") then return false end
  F.dismiss(10)
  if not F.route({ { 25, 32 }, { 21, 32 }, { 21, 36 }, { 27, 36 }, { 27, 39 } }, "fuchsia_south") then return false end
  for _ = 1, 4 do if F.grp() == 37 and F.mapn() == 37 then break end F.step("Down") end
  local _, y = F.pos()
  return F.route({ { 15, y }, { 15, 8 }, { 9, 8 }, { 9, 12 }, { 12, 12 } }, "beach")
end

F.run(function()
  X.rec(false)
  assert(F.boot(100), "boot")
  X.instantText()
  X.flag(0x948, true)
  X.give(SP.squad, 3, 0)
  X.patch(0)
  F.check("lead is Squad Squirtle", X.count() == 1 and X.decode(0).species == SP.squad, X.party())
  X.setBalls(20)
  F.check("reached the Route 19 shore", goToSurfboard(), string.format("pos=(%d,%d)", F.pos()))
  X.normalText()
  F.idle(30)

  X.rec(true); X.mark("unlock")
  F.leg(11, 12); F.idle(20)
  X.talk("Up", true, 40)
  F.check("surfer unlocked it", X.flag(0xDDB))
  F.leg(12, 12); F.idle(10); F.leg(12, 11); F.idle(20)
  X.mark("encounter")
  local _, battle = X.talk("Right", true, 40)
  F.check("battle started", battle)
  F.check("action menu", X.awaitAction(45))
  F.idle(90)
  F.shot("battle_start")
  X.mark("throw")
  for _ = 1, 30 do
    F.press("R", 4); F.idle(260)
    if F.outcome() == 7 or not X.awaitAction(40) then break end
    F.idle(40)
  end
  for _ = 1, 600 do
    if X.liveMenu() then F.idle(40); F.press("B", 2); F.idle(30) end
    if not X.inBattle() and X.scriptIdle() then break end
    F.press("A", 2); F.idle(30)
  end
  F.idle(40)
  F.check("caught Surfboard Pikachu", F.outcome() == 7 and X.flag(0xDD1), "outcome=" .. F.outcome())
  F.check("in the party", X.count() == 2 and X.decode(1).species == SP.surfboard, X.party())

  X.mark("menus")
  F.check("party opens", X.openParty()); F.idle(60)
  X.tap("Down", 40); X.tap("A", 50); F.idle(30)
  X.tap("A", 90)                             -- Summary
  F.shot("summary_1"); F.idle(80)
  for p = 2, 4 do X.tap("Right", 80); F.shot("summary_" .. p); F.idle(40) end
  X.tap("B", 80)
  -- Back on the action list (Summary, Surf, Switch, ...): Switch, then the lead slot.
  for _ = 1, 10 do if F.rs8(S.sMenu + S.Menu.maxCursorPos) >= 4 then break end X.tap("A", 50) end
  X.tap("Down", 30); X.tap("Down", 40); X.tap("A", 60)
  X.tap("Up", 40); X.tap("A", 100)
  F.shot("switched"); F.idle(60)
  X.closeParty()
  F.check("Surfboard Pikachu leads", X.decode(0).species == SP.surfboard, X.party())
  local slot
  for i, m in ipairs(X.decode(0).moves) do if m == MOVE_SURF then slot = i - 1 end end
  F.check("knows Surf", slot ~= nil, X.party())
  X.patch(0)
  F.idle(60)

  X.mark("surf_battle")
  F.step("Up"); F.idle(10)
  for _ = 1, 300 do if X.inBattle() then break end F.press("A", 2); F.idle(30) end
  F.check("Reece battle", X.inBattle())
  local turns = 0
  while X.awaitAction(40) and turns < 12 do
    F.idle(40)
    X.fight(slot, 40)
    turns = turns + 1
  end
  F.check("won with Surf", X.finishBattle(30) and F.outcome() == 1, string.format("outcome=%d turns=%d", F.outcome(), turns))
  F.idle(60)
  X.rec(false)
  F.finish()
end)
