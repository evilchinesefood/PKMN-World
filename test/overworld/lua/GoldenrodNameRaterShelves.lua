-- The two bookshelves in Goldenrod's Name Rater house asked "Would you like to toggle the Unique
-- Shiny Colors setting?" and, on YES, said "Shiny Colors Toggled! View your setting at the
-- CHALLENGE VIEWER at any PC." pokemonHnS wired them to its randomizer's ToggleShinyColors. This
-- game has neither the setting nor a Challenge Viewer, the special was a no-op stub, and the
-- legacy-content removal deleted the call but kept the offer.
--
-- With real input the suite reads each shelf from the floor below it, answers YES when a Yes/No box
-- opens, reads the second shelf twice at Instant text, and checks every line the game prints.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/GoldenrodNameRaterShelves.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "GoldenrodNameRaterShelves")

local CONTEXT_SHUTDOWN = 2
local BUF = S.gStringVar4 + 900
local GROUP, NUM = 84, 14
local SHELF_TEXT = "It's filled with all sorts of books."
local TEXT_SPEED_INSTANT = 3

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
local function warp(x, y)
  runScript({ 0x39, GROUP, NUM, 0xFF, x & 0xFF, x >> 8, y & 0xFF, y >> 8, 0x27, 0x02 })
  for _ = 1, 600 do
    F.idle(4)
    local px, py = F.pos()
    if F.grp() == GROUP and F.mapn() == NUM and px == x and py == y and hasControl() then F.idle(30); return true end
  end
  return false
end
local function walkTo(x)
  for _ = 1, 4 do
    local px = F.pos()
    if px == x then return true end
    F.step(px < x and "Right" or "Left")
  end
  return (F.pos()) == x
end

local CH = {}
for i = 0, 9 do CH[0xA1 + i] = string.char(48 + i) end
for i = 0, 25 do CH[0xBB + i] = string.char(65 + i); CH[0xD5 + i] = string.char(97 + i) end
CH[0x00] = " "; CH[0xAB] = "!"; CH[0xAC] = "?"; CH[0xAD] = "."; CH[0xB4] = "'"; CH[0xB8] = ","; CH[0x1B] = "E"
local function shownText()
  local s = {}
  for i = 0, 239 do
    local c = F.r8(S.gStringVar4 + i)
    if c == 0xFF then break end
    s[#s + 1] = CH[c] or " "
  end
  return (table.concat(s):gsub("%s+", " "))
end

local function readShelf(tag)
  F.face("Up")
  F.w8(S.gStringVar4, 0xFF)
  F.press("A", 2)
  local said, last = {}, nil
  for i = 1, 2400 do
    local s = shownText()
    if s ~= last then last = s; if #s > 0 then said[#said + 1] = s; F.L("  " .. tag .. ": " .. s) end end
    if i == 50 then F.shot(tag) end
    if i > 30 and hasControl() then break end
    joypad.set((i % 24 == 0) and { A = true } or {})
    emu.frameadvance()
  end
  local all = table.concat(said, " | ")
  F.check(tag .. ": offers no shiny colour setting", not all:find("Shiny", 1, true), all:sub(1, 120))
  F.check(tag .. ": names no Challenge Viewer", not all:find("CHALLENGE", 1, true), "")
  F.check(tag .. ": reads as a bookshelf", all == SHELF_TEXT, all:sub(1, 120))
  F.check(tag .. ": control returns", hasControl(), "")
end

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  if not F.check("stand below the left shelf", warp(0, 2)) then F.finish(); return end
  readShelf("left_shelf")
  F.check("step to the right shelf", walkTo(1))
  readShelf("right_shelf")
  local opt = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(opt, (F.r16(opt) & ~7) | TEXT_SPEED_INSTANT)
  readShelf("right_shelf_again")
  F.finish()
end)
