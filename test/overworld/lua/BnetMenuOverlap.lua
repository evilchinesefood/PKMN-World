-- Battle Net lists taller than six rows must not open over a message box.
--
-- A static multichoice at (0,0) with n rows covers tile rows 0..2n+1. The field message box
-- starts at tile row 14, so a list of seven or more rows lands on the message the script just
-- printed: the list hides the start of each text line and its bottom border cuts the first line.
-- The day-of-week and Kurt lists close the message first; this suite drives every Battle Net
-- list that tall with real input and reads the BG0 screen map while it is open. Outside the
-- list's own frame, tile rows 14..19 must be empty.
--
--   hub terminal (9,10):   Type Trainer pages 1, 2 and 3 (eight rows each)
--   2F director (2,2):     the starter-stone offer (eight rows)
--   2F stone vendor (6,2): both stone pages (seven rows each)
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/BnetMenuOverlap.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BnetMenuOverlap")

local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local REG_BG0CNT = 0x04000008
local BAND_TOP, BAND_BOTTOM = 14, 19

local function maxRow() return F.r8(S.sMenu + S.Menu.maxCursorPos) end
local function cursor() return F.rs8(S.sMenu + S.Menu.cursorPos) end
-- Only the row count: the open list returns cursorPos when A lands, so it must stay intact.
local function forgetMenu() F.w8(S.sMenu + S.Menu.maxCursorPos, 0) end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0
    and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end

local function listRect()
  local w = S.gWindows + F.r8(S.sMenu + S.Menu.windowId) * S.Window.stride
  local left, top = F.r8(w + S.Window.tilemapLeft), F.r8(w + S.Window.tilemapTop)
  return left - 1, top - 1, left + F.r8(w + S.Window.width), top + F.r8(w + S.Window.height)
end

-- BG0 entries in the message-box band that are not part of the open list's frame.
local function strayBandTiles()
  local base = 0x06000000 + ((F.r16(REG_BG0CNT) >> 8) & 0x1F) * 0x800
  local x0, y0, x1, y1 = listRect()
  local n = 0
  for y = BAND_TOP, BAND_BOTTOM do
    for x = 0, 29 do
      local inList = x >= x0 and x <= x1 and y >= y0 and y <= y1
      if not inList and (F.r16(base + (y * 32 + x) * 2) & 0x3FF) ~= 0 then n = n + 1 end
    end
  end
  return n
end

-- Advance the script with A until a list whose last row is `last` is open. The list's
-- static sMenu keeps the previous list's fields, so callers forget it before the trigger.
local function awaitList(last, tag)
  for _ = 1, 60 do
    if maxRow() == last then F.idle(10); return true end
    if F.reportCrash(tag) then return false end
    F.press("A", 2); F.idle(30)
  end
  F.shot(tag .. "_nolist")
  return false
end

local function chooseRow(row)
  for _ = 1, 16 do
    local c = cursor()
    if c == row then break end
    F.press(c < row and "Down" or "Up", 2); F.idle(10)
  end
  local ok = cursor() == row
  forgetMenu()
  F.press("A", 2); F.idle(30)
  return ok
end

local function checkList(tag, last)
  if not F.check(tag .. ": list opens", awaitList(last, tag)) then return false end
  local _, _, _, y1 = listRect()
  F.check(tag .. ": list reaches the message band", y1 >= BAND_TOP, "bottom row " .. y1)
  local stray = strayBandTiles()
  F.shot((tag:gsub(" ", "_")))
  F.check(tag .. ": no message box drawn beside the list", stray == 0, stray .. " stray tiles")
  return true
end

local function awaitControl(tag)
  for _ = 1, 60 do
    if hasControl() then F.idle(10); return F.check(tag .. ": control returns", true) end
    F.press("B", 2); F.idle(20)
  end
  return F.check(tag .. ": control returns", false)
end

local function warp(g, n, x, y)
  local SCRIPT = S.gStringVar4 + 960
  local b = { 0x39, g, n, 0xFF, x & 0xFF, x >> 8, y & 0xFF, y >> 8, 0x27, 0x02 }
  for i, v in ipairs(b) do F.w8(SCRIPT + i - 1, v) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
  for _ = 1, 400 do
    F.idle(4)
    if F.grp() == g and F.mapn() == n and F.ow() then return awaitControl("warp " .. g .. "." .. n) end
  end
  return false
end

local function talk(dir)
  forgetMenu()
  F.face(dir); F.press("A", 2); F.idle(30)
end

F.run(function()
  if not F.check("boots to the hub", F.boot(100)) then F.finish(); return end
  F.w16(F.sb2() + S.SaveBlock2.optionsU16, (F.r16(F.sb2() + S.SaveBlock2.optionsU16) & 0xFFF8) | 3)

  -- The hub terminal: Type Trainer opens three eight-row type pages.
  F.check("walk to the hub terminal", F.route({ { 6, 4 }, { 6, 10 }, { 9, 10 } }, "terminal"))
  talk("Up")
  if F.check("terminal menu opens", awaitList(2, "terminal")) then
    chooseRow(0)
    if checkList("type page 1", 7) then chooseRow(6) end
    if checkList("type page 2", 7) then chooseRow(6) end
    if checkList("type page 3", 7) then chooseRow(7) end
    if F.check("cancel returns to the terminal menu", awaitList(2, "terminal_again")) then chooseRow(2) end
  end
  awaitControl("terminal")

  -- The 2F director offers one starter-line stone from an eight-row list, twice.
  if F.check("warp to the Battle Net floor", warp(100, 1, 2, 4)) then
    for visit = 1, 2 do
      talk("Up")
      if checkList("starter stone offer " .. visit, 7) then
        forgetMenu(); F.press("B", 2); F.idle(30)
      end
      awaitControl("director " .. visit)
    end

    -- The stone vendor's two seven-row pages.
    F.check("step to the stone vendor", F.leg(6, 4))
    talk("Up")
    if checkList("vendor page 1", 6) then chooseRow(5) end
    if checkList("vendor page 2", 6) then chooseRow(6) end
    awaitControl("vendor")
  end
  F.finish()
end)
