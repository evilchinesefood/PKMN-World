-- New-game intro: gender choice, then a slow walk through all 24 outfits (4 styles x 6 colors).
-- REC_GENDER=girl picks GIRL. Driver patterns from test/overworld/lua/PromptSafetyEvIv.lua.
local F, S, X = dofile(os.getenv("REC_TOOLS") .. "/Show.lua")("Intro")
local GIRL = os.getenv("REC_GENDER") == "girl"
local PICK = tonumber(os.getenv("REC_PICK") or "13")

local function findWin(left, top, w, h)
  for i = 0, 31 do
    local b = S.gWindows + i * S.Window.stride
    if F.r8(b + S.Window.tilemapLeft) == left and F.r8(b + S.Window.tilemapTop) == top
       and F.r8(b + S.Window.width) == w and F.r8(b + S.Window.height) == h then return i end
  end
end
local function taskIs(fn)
  for i = 0, 15 do
    local b = S.gTasks + i * S.Task.stride
    if F.r8(b + S.Task.isActive) ~= 0 and (F.r32(b + S.Task.func) & ~1) == (fn & ~1) then return true end
  end
  return false
end
local function picker() return F.r8(S.gPlayerOutfitPicker + 2) ~= 0 end
local function sel() return F.r16(S.gPlayerOutfitPicker) end
local function gender() return F.r8(F.sb2() + S.SaveBlock2.playerGender) end
local function palette() return F.r16(F.sb1() + S.SaveBlock1.vars + (0x40FC - 0x4000) * 2) end
local function genderMenu() return findWin(18, 9, 9, 4) or taskIs(S.Task_OakSpeech_HandleGenderInput) end
local function naming() return F.cb2() == S.CB2_NamingScreen end

local function skipTitle()
  for f = 1, 90000 do
    if F.cb2() == S.CB2_NewGameScene then F.idle(20); return true end
    local p = f % 30
    if p < 3 then F.press("A", 1) elseif p >= 15 and p < 17 then F.press("Start", 1) else F.idle(1) end
  end
  return false
end

local function browse()
  X.mark("outfits")
  F.idle(70)
  local seen = { [sel()] = true }
  for style = 0, 3 do
    if style > 0 then X.tap("Right", 2); F.idle(50); seen[sel()] = true end
    for _ = 1, 5 do
      X.tap(style % 2 == 0 and "Down" or "Up", 2); F.idle(42)
      seen[sel()] = true
      F.shot(string.format("outfit_%02d", sel()))
    end
  end
  local n = 0
  for _ in pairs(seen) do n = n + 1 end
  F.check("browsed every outfit", n == 24, "seen=" .. n)
  -- walk to PICK = style * 6 + color from the last cell (style 3, color 0)
  local style, color = PICK // 6, PICK % 6
  for _ = style, 2 do X.tap("Left", 30) end
  for _ = 1, color do X.tap("Down", 30) end
  F.idle(60)
  F.check("preview on the chosen outfit", sel() == PICK, "sel=" .. sel())
  X.tap("A", 30)
  for _ = 1, 100 do if not picker() then break end F.idle(4) end
  F.check("outfit committed", palette() == PICK, "palette=" .. palette())
end

F.run(function()
  X.rec(false)
  F.idle(60)
  F.check("title skipped", skipTitle())
  local done, sawGender = false, false
  for f = 1, 200000 do
    if F.ow() then break end
    if naming() then
      X.rec(false)
      F.idle(20); F.press("Start", 2); F.idle(20); F.press("A", 2); F.idle(30)
      for _ = 1, 40 do if not naming() then break end F.press("A", 2); F.idle(8) end
      X.rec(true)
    elseif picker() and not done then
      X.rec(true)
      browse(); done = true
    elseif genderMenu() and not sawGender then
      X.rec(true); X.mark("gender")
      F.idle(60)
      if GIRL then X.tap("Down", 50) end
      F.idle(30)
      X.tap("A", 20)
      sawGender = true
    elseif genderMenu() then
      F.press("A", 2); F.idle(8)
    else
      for i = 1, 6 do
        if (not done and picker()) or (not sawGender and genderMenu()) then break end
        joypad.set(i <= 2 and { A = true } or {}); emu.frameadvance()
      end
    end
  end
  F.check("gender", gender() == (GIRL and 1 or 0), "gender=" .. gender())
  X.mark("field")
  for _ = 1, 60 do if F.ensureFree() then break end F.press("B", 3); F.idle(30) end
  F.idle(60)
  for _, d in ipairs({ "Down", "Down", "Left", "Left", "Up", "Right", "Right" }) do F.step(d) end
  F.face("Down"); F.idle(90)
  F.shot("field")
  X.rec(false)
  F.finish()
end)
