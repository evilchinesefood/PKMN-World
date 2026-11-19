-- The Goldenrod Department Store elevator, which no suite rode. Each floor's (9,5) trigger and the
-- basement's (10,7) run one shared script: doors open, the player walks in, a floor list opens, and
-- the chosen floor's ON_FRAME table walks the player back out while VAR_ELEVATOR is 1.
--
-- With real input the suite rides from 1F to every floor and the basement, picks the floor it is
-- already on, cancels from the list and with B, and mashes seeded keys through the doors and the
-- warp fade. Every ride must land on the chosen floor below its elevator door with control back.
-- A later plain warp onto 4F must leave the player where it put them: a VAR_ELEVATOR left at 1
-- would walk them three tiles down.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/GoldenrodElevatorRides.lua
-- PW_SEED picks the mash sequence (default 1).

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "GoldenrodElevatorRides")

local CONTEXT_SHUTDOWN = 2
local BUF = S.gStringVar4 + 900
local GROUP = 84
local ROWS = { [0] = 9, 8, 7, 6, 5, 4, 2 }
local NAMES = { [2] = "B1F", [4] = "1F", [5] = "2F", [6] = "3F", [7] = "4F", [8] = "5F", [9] = "6F" }
local CANCEL_ROW = 7

local seed = tonumber(os.getenv("PW_SEED")) or 1
local function rand(n)
  seed = (seed * 1103515245 + 12345) % 2147483648
  return (seed >> 16) % n + 1
end
local PRE_MENU_KEYS = { "A", "B", "Up", "Down", "Left", "Right", "Start", "Select", "L", "R" }
local LOCKED_KEYS = { "A", "B", "Select", "L", "R" }

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function runScript(bytes)
  for i, v in ipairs(bytes) do F.w8(BUF + i - 1, v) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, BUF)
  F.w8(S.sGlobalScriptContextStatus, 0)
end
local function warp(n, x, y)
  runScript({ 0x39, GROUP, n, 0xFF, x & 0xFF, x >> 8, y & 0xFF, y >> 8, 0x27, 0x02 })
  for _ = 1, 600 do
    F.idle(4)
    local px, py = F.pos()
    if F.grp() == GROUP and F.mapn() == n and px == x and py == y and hasControl() then return true end
  end
  return false
end
local function exitTile(n) if n == 2 then return 10, 8 end return 9, 6 end
local function menuOpen()
  return F.r8(S.sMenu + S.Menu.maxCursorPos) == CANCEL_ROW
end

local function ride(tag, row, mash, useB)
  local from = F.mapn()
  local dest = (useB or row == CANCEL_ROW) and from or ROWS[row]
  F.w8(S.sMenu + S.Menu.cursorPos, 0)
  F.w8(S.sMenu + S.Menu.maxCursorPos, 0)
  local _, y0 = F.pos()
  F.step("Up")
  local _, y1 = F.pos()
  if not F.check(tag .. ": steps onto the elevator trigger", y1 == y0 - 1, string.format("y %d -> %d", y0, y1)) then return end
  local opened = false
  for i = 1, 900 do
    if menuOpen() then opened = true; break end
    joypad.set((mash and i % 4 == 0) and { [PRE_MENU_KEYS[rand(#PRE_MENU_KEYS)]] = true } or {})
    emu.frameadvance()
  end
  joypad.set({}); emu.frameadvance()
  if not F.check(tag .. ": floor list opens", opened, "") then return end
  F.shot(tag .. "_list")
  if useB then
    F.press("B", 2)
  else
    for _ = 1, 16 do
      local c = F.mcur()
      if c == row then break end
      F.press(c < row and "Down" or "Up", 2); F.idle(6)
    end
    F.check(tag .. ": cursor on row " .. row, F.mcur() == row, tostring(F.mcur()))
    F.press("A", 2)
  end
  local steady, crashed = 0, false
  for i = 1, 2400 do
    local onDest = F.grp() == GROUP and F.mapn() == dest
    if onDest and hasControl() then steady = steady + 1 else steady = 0 end
    if steady >= 30 then break end
    joypad.set((mash and not hasControl() and i % 3 == 0) and { [LOCKED_KEYS[rand(#LOCKED_KEYS)]] = true } or {})
    emu.frameadvance()
    if i % 60 == 0 and F.reportCrash(tag) then crashed = true; break end
  end
  joypad.set({})
  local x, y = F.pos()
  local ex, ey = exitTile(dest)
  F.L(string.format("  %s: %s -> map %d.%d at %d,%d", tag, NAMES[from] or "?", F.grp(), F.mapn(), x, y))
  F.check(tag .. ": lands on " .. (NAMES[dest] or "?"), F.grp() == GROUP and F.mapn() == dest, string.format("%d.%d", F.grp(), F.mapn()))
  F.check(tag .. ": stands below the elevator door", x == ex and y == ey, string.format("%d,%d", x, y))
  F.check(tag .. ": control returns, no crash", steady >= 30 and not crashed, "")
end

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  if not F.check("stand below the 1F elevator", warp(4, 9, 6)) then F.finish(); return end
  ride("1F_to_6F", 0, false)
  ride("6F_to_B1F", 6, true)
  ride("B1F_to_3F", 3, true)
  ride("3F_cancel", CANCEL_ROW, true)
  ride("3F_b_out", nil, false, true)
  ride("3F_to_3F", 3, false)
  ride("3F_to_1F", 5, true)
  ride("1F_to_2F", 4, true)
  ride("2F_to_4F", 2, false)
  ride("4F_to_5F", 1, true)
  F.check("plain warp onto 4F", warp(7, 12, 7))
  F.idle(120)
  local x, y = F.pos()
  F.check("4F: no elevator exit walk after a plain warp", F.mapn() == 7 and x == 12 and y == 7 and hasControl(),
    string.format("%d.%d at %d,%d", F.grp(), F.mapn(), x, y))
  F.finish()
end)
