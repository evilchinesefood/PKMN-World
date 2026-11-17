-- The Hall of Fame and what follows it in all three regions, mashed. #636 deleted the FRLG title
-- screen and FRLG credits; the endgame credits themselves were dropped on purpose in f167155ff9
-- (2026-07-14), so every region now soft resets to the title after the induction screen: Hoenn and
-- Johto through GameClear and the Emerald Hall of Fame (StartCredits), Kanto through EnterHallOfFame
-- and the FRLG Hall of Fame (SetWarpsToRollCredits). Each case enters the region's Hall of Fame room
-- through a debug warp, lets the room's own ON_FRAME script start the ceremony, and mashes a seeded
-- stream of single buttons (A, B, Start, Select, L, R, the D-pad) until the game is back at the
-- copyright screen, intro, title or main menu. It then continues the file from the title with real
-- input and checks where it lands (the region's continue warp), the region, the party, that no crash
-- screen came up, that control returns (Kanto plays its post-league Oak rating scene first) and that
-- the player can walk. Three more Hoenn cases soft reset (A+B+Start+Select) at different points of
-- the Hall of Fame screen, holding the chord through the save (which disables the reset); Continue
-- must then load either the hub save made before the induction (the reset beat the save) or the
-- respawn, never anywhere else.
--
-- PW_HOF_ONLY=<text> runs only matching cases. PW_HOF_SEED=<n> reseeds the mash.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/HofCreditsMash.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "HofCreditsMash")

local HUB_GROUP = 100
local ROW_PARTY_MENU, ROW_SET = 2, 9
local REGION_VARS_START = 0xA000
local VAR_LEAGUE_STATE = 0xA080 + 0x3B
local CONTEXT_RUNNING = 0
local USM_ICO_SAVE = 7
local SENTINEL = 0xFFFF
local ONLY = os.getenv("PW_HOF_ONLY")
local SEED = tonumber(os.getenv("PW_HOF_SEED") or "") or 636

local BUTTONS = { "A", "B", "Start", "Select", "L", "R", "Up", "Down", "Left", "Right" }

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function warp(g, m, w, tag)
  local gh, gt, go = d(g)
  local mh, mt, mo = d(m)
  local wh, wt, wo = d(w)
  return F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, g, m, tag)
end

local function tapDown(n) for _ = 1, n do F.press("Down", 3); F.idle(16) end end
local function setParty()
  F.dbg(); F.idle(60)
  tapDown(ROW_PARTY_MENU); F.press("A", 3); F.idle(60)
  tapDown(ROW_SET); F.press("A", 3); F.idle(180)
  for _ = 1, 6 do F.press("B", 3); F.idle(20) end
end

-- Every case can reset while the Hall of Fame saves, so a real save must exist first; otherwise the
-- interrupted first save leaves NEW GAME as the only row.
local function driveSave()
  F.w16(S.gSaveAttemptStatus, SENTINEL)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_SAVE) then return "noicon" end
  for i = 1, 3000 do
    if F.r16(S.gSaveAttemptStatus) ~= SENTINEL then
      F.idle(30)
      for _ = 1, 6 do F.press("B", 2); F.idle(20) end
      return F.r16(S.gSaveAttemptStatus) == 1 and "done" or "failed"
    end
    if i % 20 == 1 then joypad.set({ A = true }) else joypad.set({}) end
    emu.frameadvance()
  end
  return "timeout"
end

local function regionVarSet(id, v) F.w16(F.sb3() + S.SaveBlock3.regionVars + (id - REGION_VARS_START) * 2, v) end
-- SaveBlock2.currentRegion stays REGION_NONE until the first hub gate-cross, which a debug warp
-- never makes, so read the runtime region the map load resynced.
local function region() return F.r8(S.gCurrentRegion) end
local function partyHash()
  local n = F.r8(S.gPartiesCount)
  local h = n
  for i = 0, n * S.Pokemon.size - 1, 4 do h = (h * 31 + F.r32(S.gParties + i)) & 0xFFFFFFFF end
  return h
end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function awaitControl(budget)
  for i = 1, budget or 3000 do
    if hasControl() then return true end
    if i % 30 == 0 then F.press("B", 2) else F.idle(1) end
  end
  return hasControl()
end

local rngState = SEED
local function rnd(n)
  rngState = (rngState * 1103515245 + 12345) & 0x7FFFFFFF
  return rngState % n
end

local function cb2() return F.cb2() end
local function isHof(c)
  return c == S.CB2_DoHallOfFameScreen or c == S.CB2_DoHallOfFameScreenFrlg
    or c == S.CB2_HallOfFame or c == S.CB2_HofIdle
end
local function isFrontEnd(c)
  return c == S.MainCB2_Intro or c == S.CB2_InitCopyrightScreenAfterBootup
    or c == S.MainCB2_WorldTitleScreen or c == S.CB2_InitMainMenu or c == S.CB2_MainMenu
    or c == S.CB2_InitTitleScreen
end

-- Mash single buttons until the game reaches the front end. softResetAt, when given, presses
-- A+B+Start+Select on that frame of the Hall of Fame screen instead of waiting for the end.
local function mashToFrontEnd(tag, budget, softResetAt)
  local seen = { hof = false, hofFrames = 0, credits = false }
  local f, nextCrashCheck, nextShot = 0, 600, 2000
  while f < budget do
    local c = cb2()
    if isHof(c) then
      seen.hofStart = seen.hofStart or f
      seen.hof = true
      seen.hofFrames = f - seen.hofStart
      if softResetAt and seen.hofFrames >= softResetAt then
        F.shot(tag .. "_hof_before_reset")
        -- Saving disables the soft reset (gSoftResetDisabled), so hold the chord until it bites.
        local held = 0
        repeat
          joypad.set({ A = true, B = true, Start = true, Select = true }); emu.frameadvance()
          held = held + 1
        until held >= 10 and (not isHof(cb2()) or held >= 3000)
        joypad.set({}); f = f + held
        seen.resetHeld = held
        softResetAt = nil
        seen.softReset = true
      end
    end
    if c == S.CB2_Credits then seen.credits = true end
    if isFrontEnd(c) then seen.frontEnd = c; break end
    if f >= nextCrashCheck then
      nextCrashCheck = nextCrashCheck + 600
      if F.noteCrash(tag .. "_mash" .. f) then break end
    end
    if f >= nextShot then nextShot = nextShot + 2000; F.shot(string.format("%s_mash_%05d", tag, f)) end
    local hold = 2 + rnd(5)
    local btn = BUTTONS[rnd(#BUTTONS) + 1]
    for _ = 1, hold do joypad.set({ [btn] = true }); emu.frameadvance() end
    local gap = rnd(6)
    for _ = 1, gap do joypad.set({}); emu.frameadvance() end
    f = f + hold + gap
  end
  joypad.set({})
  seen.frames = f
  return seen
end

-- From the intro, title or main menu, Continue the file with plain input.
local function continueFromFrontEnd(tag)
  for _ = 1, 3000 do
    local c = cb2()
    if c == S.MainCB2_WorldTitleScreen or c == S.CB2_MainMenu then break end
    if c == S.MainCB2_Intro then F.press("Start", 2) end
    F.idle(1)
  end
  if cb2() == S.MainCB2_WorldTitleScreen then
    F.idle(120); F.press("Start", 2)
  end
  for _ = 1, 600 do if cb2() == S.CB2_MainMenu then break end F.idle(1) end
  F.idle(90)
  F.shot(tag .. "_main_menu")
  if cb2() ~= S.CB2_MainMenu then return false end
  F.press("A", 2) -- CONTINUE is the first row whenever a save exists
  for _ = 1, 3000 do if F.ow() then break end F.idle(1) end
  return F.ow()
end

local function case(tag, body)
  if ONLY and not tag:find(ONLY, 1, true) then return end
  F.L("== " .. tag .. " ==")
  local ok, err = pcall(body)
  if not ok then F.check(tag .. ": ran without a Lua error", false, tostring(err)) end
end

-- One region: warp into its Hall of Fame, mash, continue, check the landing.
local function induct(c)
  if not warp(c.grp, c.map, 0, c.tag .. "_hof") then
    F.check(c.tag .. ": warped into the Hall of Fame", false, string.format("grp=%d map=%d", F.grp(), F.mapn()))
    return
  end
  local party = partyHash()
  local n = F.r8(S.gPartiesCount)
  F.shot(c.tag .. "_hof_room")
  local seen = mashToFrontEnd(c.tag, c.budget, c.softResetAt)
  F.L(string.format("  %s: hof=%s (%d frames) credits=%s frontEnd=%08X after %d frames",
    c.tag, tostring(seen.hof), seen.hofFrames, tostring(seen.credits), seen.frontEnd or 0, seen.frames))
  F.check(c.tag .. ": the Hall of Fame screen ran", seen.hof)
  if c.softResetAt then
    F.check(c.tag .. ": the soft reset fired in the Hall of Fame", seen.softReset == true and (seen.resetHeld or 0) < 3000,
      "held " .. tostring(seen.resetHeld) .. " frames")
  end
  if c.credits ~= nil then
    F.check(c.tag .. (c.credits and ": the credits rolled" or ": no credits roll"), seen.credits == c.credits)
  end
  F.check(c.tag .. ": mashing ends at the intro, title or main menu", seen.frontEnd ~= nil,
    string.format("cb2=%08X after %d frames", cb2(), seen.frames))
  if F.reportCrash(c.tag .. "_after_mash") then F.check(c.tag .. ": no crash screen", false); return end
  if not seen.frontEnd then F.shot(c.tag .. "_stuck"); return end
  F.shot(c.tag .. "_front_end")
  local continued = continueFromFrontEnd(c.tag)
  F.check(c.tag .. ": Continue reaches the field", continued, string.format("cb2=%08X", cb2()))
  if not continued then return end
  F.idle(60)
  local x, y = F.pos()
  F.shot(c.tag .. "_continued")
  local prev = c.prevSave
  local atPrev = prev and F.grp() == prev.g and F.mapn() == prev.m and x == prev.x and y == prev.y
  if atPrev then F.L("  " .. c.tag .. ": the reset beat the Hall of Fame save; Continue loads the previous save") end
  F.check(c.tag .. (prev and ": Continue lands at the respawn or the previous save"
      or ": Continue lands at the post-league respawn"),
    atPrev or (F.grp() == c.landGrp and F.mapn() == c.landMap and x == c.landX and y == c.landY),
    string.format("at %d/%d (%d,%d), want %d/%d (%d,%d)", F.grp(), F.mapn(), x, y, c.landGrp, c.landMap, c.landX, c.landY))
  if atPrev then
    F.check(c.tag .. ": party is the saved one", F.r8(S.gPartiesCount) == prev.n, "n=" .. F.r8(S.gPartiesCount))
    return
  end
  F.check(c.tag .. ": region is " .. c.region, region() == c.regionId, "region=" .. region())
  F.check(c.tag .. ": party survived the induction", F.r8(S.gPartiesCount) == n and n > 0,
    string.format("n=%d before=%d", F.r8(S.gPartiesCount), n))
  F.L(string.format("  party hash %08X -> %08X (GameClear heals and ribbons, so it may change)", party, partyHash()))
  -- Kanto's post-league Oak rating scene plays here on purpose and takes about 1,100 frames.
  local ctl = awaitControl(3000)
  F.check(c.tag .. ": control returns", ctl, string.format("lock=%d status=%d script=%08X",
    F.r8(S.sLockFieldControls), F.r8(S.sGlobalScriptContextStatus), F.r32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr)))
  F.shot(c.tag .. "_control")
  local moved = false
  for _ = 1, 3 do
    moved = F.step("Down") or F.step("Up") or F.step("Left") or F.step("Right")
    if moved then break end
    awaitControl(1500)
  end
  F.check(c.tag .. ": the player can walk", moved, string.format("at %d/%d", F.grp(), F.mapn()))
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  F.idle(40)
  setParty()
  F.check("Set Party published a party", F.r8(S.gPartiesCount) ~= 0)
  F.check("save in the hub before any induction", driveSave() == "done")
  local hx, hy = F.pos()
  local saved = { g = F.grp(), m = F.mapn(), x = hx, y = hy, n = F.r8(S.gPartiesCount) }
  local male = F.r8(F.sb2() + S.SaveBlock2.playerGender) == 0

  case("hoenn", function()
    induct({ tag = "hoenn", grp = 16, map = 11, budget = 60000, credits = false,
      landGrp = 1, landMap = male and 1 or 3, landX = 4, landY = 2, region = "Hoenn", regionId = 3 })
  end)
  for _, at in ipairs({ 2, 40, 400 }) do
    case("hoenn soft reset in the Hall of Fame +" .. at, function()
      induct({ tag = "hoenn_reset" .. at, grp = 16, map = 11, budget = 60000, softResetAt = at, prevSave = saved,
        landGrp = 1, landMap = male and 1 or 3, landX = 4, landY = 2, region = "Hoenn", regionId = 3 })
    end)
  end
  case("johto", function()
    regionVarSet(VAR_LEAGUE_STATE, 6)
    induct({ tag = "johto", grp = 99, map = 10, budget = 60000, credits = false,
      landGrp = 75, landMap = 0, landX = 20, landY = 12, region = "Johto", regionId = 2 })
  end)
  case("kanto", function()
    induct({ tag = "kanto", grp = 35, map = 80, budget = 30000, credits = false,
      landGrp = 37, landMap = 0, landX = 6, landY = 8, region = "Kanto", regionId = 1 })
  end)
  F.finish()
end)
