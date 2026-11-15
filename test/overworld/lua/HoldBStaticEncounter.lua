-- Hold-B auto-run versus one-time static encounters. Holding B is the overworld run button, so a
-- player who runs up to the Power Plant's Electrode "item ball" and presses A is still holding B
-- when the battle starts. Auto-run is meant for ordinary random encounters; a scripted static
-- battle that treats RAN as resolved (the Electrode is removed for good) must not flee on its own.
-- Setup warps and gives a party; the walk, the A press and the held B are real input.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "HoldBStaticEncounter")

local POWER_PLANT = {35, 95}
local ELECTRODE_X, ELECTRODE_Y = 30, 38
local FLAG_HIDE_ELECTRODE_1 = 0xA40 + 0x85
local FLAG_FOUGHT_ELECTRODE_1 = 0xA40 + 0x2D0

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function flagGet(id)
  local a = F.sb1() + S.SaveBlock1.flags + id // 8
  return (F.r8(a) & (1 << (id % 8))) ~= 0
end
local function count() return F.r8(S.gPartiesCount) end
local function actionMenu()
  local fn = F.r32(S.gBattlerControllerFuncs) & 0xFFFFFFFE
  for _, a in ipairs(S.ActionInputFunctions) do if fn == (a & 0xFFFFFFFE) then return true end end
  return false
end
-- B held throughout, A tapped to page battle text (the intro message waits for a press), never
-- onto the action menu.
local function holdBTapA(frames, stop)
  for i = 1, frames do
    local tapA = (i % 40) < 3 and not actionMenu()
    joypad.set({ B = true, A = tapA or nil }); emu.frameadvance()
    if stop() then return true end
  end
  return false
end
local function electrodeShown()
  for _, o in ipairs(F.objdump()) do
    if o.x == ELECTRODE_X and o.y == ELECTRODE_Y then return true end
  end
  return false
end

local function debugParty()
  F.dbg(); F.idle(40); F.sel(2); F.idle(40)
  for _ = 1, 9 do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(180)
  for _ = 1, 30 do
    F.press("B", 2); F.idle(16)
    if F.ensureFree() then break end
  end
  return count() >= 1
end

-- Walk a leg; a random encounter on the way is fled by holding B (the auto-run this suite guards
-- must keep working for ordinary wild battles), then the leg resumes.
local wildFled, wildSeen = 0, 0
local function clearWild()
  if F.ow() then return true end
  wildSeen = wildSeen + 1
  holdBTapA(2400, F.ow)
  F.idle(60)
  if F.ow() then wildFled = wildFled + 1 end
  return F.ow()
end
local function walk(pts, tag)
  for _, p in ipairs(pts) do
    for _ = 1, 120 do
      if not clearWild() then F.shot(tag .. "_wildstuck"); return false end
      local x, y = F.pos()
      if x == p[1] and y == p[2] then break end
      local dir
      if x < p[1] then dir = "Right" elseif x > p[1] then dir = "Left"
      elseif y < p[2] then dir = "Down" else dir = "Up" end
      if not F.step(dir) and F.ow() then
        F.L(string.format("  walk %s blocked %s at %s", tag, dir, where()))
        F.shot(tag .. "_blocked"); return false
      end
    end
    local x, y = F.pos()
    if x ~= p[1] or y ~= p[2] then return false end
  end
  return true
end

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  F.check("setup: the debug party holds a Pokemon", debugParty(), "n=" .. count())
  F.check("setup: warped into the Power Plant",
    F.warpTo(0, 3, 5, 0, 9, 5, 0, 0, 0, POWER_PLANT[1], POWER_PLANT[2], "power_plant"), where())

  local route = {{4,37},{6,37},{6,28},{3,28},{3,23},{9,23},{9,19},{14,19},{14,22},{13,22},{13,26},
                 {17,26},{17,31},{15,31},{15,36},{17,36},{17,38},{29,38}}
  local arrived = walk(route, "to_electrode")
  F.check("walked to the tile west of Electrode 1", arrived, where())
  if not arrived then F.finish(); return end
  F.face("Right")
  F.check("Electrode 1 is standing there before the encounter", electrodeShown(),
    string.format("hide=%s fought=%s", tostring(flagGet(FLAG_HIDE_ELECTRODE_1)), tostring(flagGet(FLAG_FOUGHT_ELECTRODE_1))))
  F.shot("before")

  -- Run up holding B and press A on it, still holding B, as a running player does.
  for _ = 1, 20 do joypad.set({ B = true }); emu.frameadvance() end
  for _ = 1, 3 do joypad.set({ B = true, A = true }); emu.frameadvance() end
  local battle = false
  for _ = 1, 900 do
    joypad.set({ B = true }); emu.frameadvance()
    if not F.ow() and F.battlers() > 0 then battle = true; break end
  end
  F.check("the Electrode battle started", battle, string.format("cb2=%08X", F.cb2()))
  if not battle then F.finish(); return end

  -- Keep B held through the intro (paging its text with A) and past the first turn's start, where
  -- auto-run fires. The fixed game stops at the action menu instead.
  -- gBattleOutcome still holds the last battle's result here, so the end is the overworld coming back.
  local endedAlone = holdBTapA(1500, F.ow)
  local outcome = F.outcome()
  if not endedAlone then
    F.shot("action_menu_with_b_held")
    endedAlone = holdBTapA(300, F.ow)
    outcome = F.outcome()
  end
  F.check("held B does not flee the scripted static battle on its own", not endedAlone,
    string.format("outcome=%d ow=%s menu=%s", outcome, tostring(F.ow()), tostring(actionMenu())))

  -- Leave the battle by choosing RUN, then the script resolves the encounter its own way.
  if not endedAlone then
    F.idle(30)
    for _ = 1, 6 do
      F.press("Right", 2); F.idle(10); F.press("Down", 2); F.idle(10); F.press("A", 2); F.idle(90)
      if F.ow() then break end
    end
  end
  for _ = 1, 900 do
    F.idle(1)
    if F.ow() then break end
  end
  for _ = 1, 20 do F.press("B", 2); F.idle(20) end
  F.idle(120)
  F.shot("after")
  F.check("control returns after the Electrode encounter", F.ow() and F.ensureFree(), where())
  F.check("ordinary wild battles on the walk still fled on held B", wildFled == wildSeen,
    string.format("fled %d of %d", wildFled, wildSeen))
  F.finish()
end)
