-- The BW battle UI's last-used-ball icon bounces when R + D-pad cycles the ball, and the menu can
-- hide while it bounces: R released and A on FIGHT on the next frames. The bounce task must not
-- create the next ball's icon after the window is gone (0829014ec0), or an orphan ball icon stays
-- on screen through move selection and the rest of the battle.
--
-- A wild Pidgey battle starts by setwildbattle/dowildbattle with Poke, Great and Ultra Balls in the
-- Bag. At the action menu, with real input, the suite holds R, taps Right (the bounce starts),
-- releases R, and presses A d frames later for d = 0..12, then B back to the action menu. The
-- in-use sprite count in move selection must equal the count with the menu hidden normally (A
-- with no cycling), and the action menu's count must return to its baseline after every round.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/LastBallBounceHide.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "LastBallBounceHide")

local MON = S.Pokemon.size
local SPECIES_PIDGEY, SPECIES_MEWTWO = 16, 150
local BALLS = { 1, 2, 3 }

local function digits(n) n = n - 1; return n // 100, (n // 10) % 10, n % 10 end
local function inBattle() return F.cb2() == (S.BattleMainCB2 & ~1) end
local function ctrl(b) return F.r32(S.gBattlerControllerFuncs + b * 4) & ~1 end
local function actionMenu()
  for _, p in ipairs(S.ActionInputFunctions) do if ctrl(0) == (p & ~1) then return true end end
  return false
end
local function moveMenu() return ctrl(0) == (S.HandleInputChooseMove & ~1) end
local function spritesInUse()
  local n = 0
  for i = 0, S.Sprite.count - 1 do
    if F.r8(S.gSprites + i * S.Sprite.stride + S.Sprite.inUse) & 1 ~= 0 then n = n + 1 end
  end
  return n
end

local SCRIPT_BUF = S.gStringVar4 + 960
local function runScript(b)
  for i, v in ipairs(b) do F.w8(SCRIPT_BUF + i - 1, v) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, 0)
end

local function waitFor(pred, n) for _ = 1, n or 300 do if pred() then return true end F.idle(1) end return pred() end

local function settleAction()
  waitFor(actionMenu, 400)
  F.idle(40)
  return spritesInUse()
end

-- A on FIGHT, then B back. Returns the sprite count seen in move selection.
local function fightAndBack(tag, shot)
  local inMove = waitFor(moveMenu, 200)
  F.idle(60)
  local n = spritesInUse()
  if shot then F.shot(tag .. "_moves") end
  F.press("B", 2)
  return inMove, n
end

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  for off = 0, 6 * MON - 4, 4 do F.w32(S.gParties + off, 0) end
  F.w8(S.gPartiesCount, 0)
  F.dbg(); F.idle(30); F.bOut(4)
  F.dbg(); F.sel(3); F.sel(1); F.idle(20); F.spin(digits(SPECIES_MEWTWO)); F.idle(20); F.spin(0, 5, 0); F.idle(60); F.bOut(4)
  F.check("setup: a lead", F.r8(S.gPartiesCount) == 1)
  for _, ball in ipairs(BALLS) do
    runScript({ 0x44, ball, 0, 5, 0, 0x02 }); F.idle(30)       -- additem ball, 5; end
  end
  F.check("setup: three ball types in the Bag", F.itemCount(1) == 1 and F.itemCount(2) == 1 and F.itemCount(3) == 1)
  runScript({ 0xB6, SPECIES_PIDGEY, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0xB7, 0x02 })
  F.check("a wild battle started", waitFor(function() return inBattle() and F.battlers() >= 2 end, 1500))
  local function toAction()
    for _ = 1, 600 do if actionMenu() then return true end; F.press("A", 2); F.idle(6) end
    return actionMenu()
  end
  F.check("the action menu is up", toAction())
  local base = settleAction()
  F.shot("action_menu")

  -- Control: hide the menu with a plain A.
  F.press("A", 2)
  local ok0, plain = fightAndBack("plain", true)
  F.check("control: A on FIGHT reaches move selection", ok0)
  local back0 = settleAction()
  F.L(string.format("  baseline action=%d moves=%d back=%d", base, plain, back0))

  local bad = {}
  for d = 0, 12 do
    for _ = 1, 12 do joypad.set({ R = true }); emu.frameadvance() end
    for _ = 1, 2 do joypad.set({ R = true, Right = true }); emu.frameadvance() end
    joypad.set({}); emu.frameadvance()
    for _ = 1, d do joypad.set({}); emu.frameadvance() end
    F.press("A", 2)
    local inMove, n = fightAndBack("d" .. d, d == 2)
    local back = settleAction()
    if not inMove then
      bad[#bad + 1] = string.format("d=%d no move menu (cb2=%08X)", d, F.cb2())
      toAction()
      back = settleAction()
    elseif n ~= plain or back ~= back0 then
      bad[#bad + 1] = string.format("d=%d moves=%d back=%d", d, n, back)
    end
    if F.reportCrash("d" .. d) then bad[#bad + 1] = "crash"; break end
  end
  F.shot("after_rounds")
  F.check("no orphan ball icon after hiding the menu mid-bounce", #bad == 0, table.concat(bad, "; "))
  F.check("no crash screen", not F.crashScreen())
  F.finish()
end)
