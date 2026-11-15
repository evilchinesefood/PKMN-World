-- World Transit wardrobe with a special follower out: open, browse styles and colors, apply,
-- walk. Route and picker reads from OutfitPickerStress.lua.
local F, S, X = dofile(os.getenv("REC_TOOLS") .. "/Show.lua")("Wardrobe")
local function active() return F.r8(S.gPlayerOutfitPicker + 2) ~= 0 end
local function sel() return F.r16(S.gPlayerOutfitPicker) end

F.run(function()
  X.rec(false)
  assert(F.boot(100), "boot")
  X.instantText()
  X.flag(0x948, true)
  X.give(X.SPECIES.balloons, 3, 0)
  X.normalText()
  F.check("reached the wardrobe", F.route({ { 9, 4 }, { 9, 6 }, { 8, 6 }, { 8, 8 }, { 7, 8 } }, "wardrobe"))
  F.idle(60)
  X.rec(true); X.mark("wardrobe")
  F.face("Up"); F.idle(30)
  for _ = 1, 40 do if active() then break end F.press("A", 2); F.idle(30) end
  F.check("wardrobe opens", active())
  F.idle(80); F.shot("open")
  local path = { "Right", "Down", "Down", "Right", "Down", "Right", "Up", "Up", "Left" }
  for _, k in ipairs(path) do X.tap(k, 50); F.shot("sel_" .. sel()) end
  F.idle(40)
  local pick = sel()
  X.tap("A", 40)
  for _ = 1, 200 do if not active() and X.scriptIdle() then break end F.idle(4) end
  F.idle(60)
  F.check("applied", F.r16(F.sb1() + S.SaveBlock1.vars + (0x40FC - 0x4000) * 2) == pick, "pick=" .. pick)
  for _, d in ipairs({ "Down", "Right", "Right", "Right", "Down", "Left", "Left" }) do F.step(d) end
  F.face("Down"); F.idle(60); F.shot("after")
  X.rec(false)
  F.finish()
end)
