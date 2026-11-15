local F, S, X = dofile(os.getenv("REC_TOOLS") .. "/Show.lua")("Followers")
local SP = X.SPECIES
local CAST = { SP.surfboard, SP.balloons, SP.squad, SP.pirate, SP.flower, SP.classic }

local function walk(dir, n) for _ = 1, n do F.step(dir) end end

F.run(function()
  X.rec(false)
  assert(F.boot(100), "boot")
  X.instantText()
  X.flag(0x948, true)
  for _, sp in ipairs(CAST) do X.give(sp, 3, 0) end
  F.check("six specials in the party", X.count() == 6, X.party())
  X.normalText()
  F.check("Pallet", X.warp(37, 0, 10, 8))
  F.idle(60)
  for i = 0, X.count() - 1 do
    X.rec(true); X.mark("follow_" .. i)
    F.check("party opens " .. i, X.openParty())
    F.idle(40)
    X.follow(i, 24)
    F.idle(20)
    F.press("B", 2); F.idle(50); F.press("B", 2); F.idle(30)
    for _ = 1, 10 do if F.ensureFree() then break end F.press("B", 2); F.idle(20) end
    walk("Left", 3); walk("Right", 5)
    F.face("Left"); F.idle(10)
    F.press("A", 2); F.idle(80)
    for _ = 1, 6 do if X.scriptIdle() then break end F.press("A", 2); F.idle(50) end
    F.shot("follower_" .. i)
    walk("Left", 2)
    F.idle(20)
  end
  X.rec(false)
  F.finish()
end)
