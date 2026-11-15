-- The Story overview row shows only the first line of each region's next action, so that line
-- must read as a whole instruction rather than the start of a sentence.
--
-- A fresh game is taken into each region's opening on foot (Pallet, New Bark, Littleroot), the
-- Story screen is opened through the Start menu with real input, and the action each of the three
-- overview rows prints is read from the live resolver results the screen draws from. Its first
-- line must end in '.', '!' or '?'. Before the fix the Kanto opening printed
-- "Meet Prof. Oak and choose". python3 test/overworld/story-progress/run.py checks the same rule
-- for every authored objective.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/StoryOverviewLine.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "StoryOverviewLine")

local USM_ICO_QUESTS = 6
local PROGRESS_STRIDE, OBJECTIVE_ACTION = 16, 12
local CHAR_NEWLINE, EOS = 0xFE, 0xFF
local TERMINAL = { [0xAB] = "!", [0xAC] = "?", [0xAD] = "." }

local function inStory() return F.cb2() == (S.CB2_Story & ~1) end
local function ascii(p)
  local t = {}
  for i = 0, 63 do local c = F.r8(p + i); if c == 0 then break end; t[#t + 1] = string.char(c) end
  return table.concat(t)
end
local GLYPHS = {}
for i = 0, 25 do GLYPHS[0xBB + i] = string.char(65 + i); GLYPHS[0xD5 + i] = string.char(97 + i) end
for i = 0, 9 do GLYPHS[0xA1 + i] = string.char(48 + i) end
GLYPHS[0x00] = " "; GLYPHS[0xAB] = "!"; GLYPHS[0xAC] = "?"; GLYPHS[0xAD] = "."; GLYPHS[0xB8] = ","

local function objective(row) return F.r32(S.sStoryProgress + row * PROGRESS_STRIDE) end
-- The overview row's text: the action up to its first line break.
local function overviewLine(row)
  local p = F.r32(objective(row) + OBJECTIVE_ACTION)
  local t, last = {}, nil
  for i = 0, 127 do
    local c = F.r8(p + i)
    if c == CHAR_NEWLINE or c == EOS then break end
    t[#t + 1] = GLYPHS[c] or "~"
    last = c
  end
  return table.concat(t), last
end

local function warp(g, n, x, y)
  local buf = S.gStringVar4 + 960
  local b = { 0x39, g, n, 0xFF, x & 0xFF, x >> 8, y & 0xFF, y >> 8, 0x27, 0x02 }
  for i, v in ipairs(b) do F.w8(buf + i - 1, v) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, buf)
  F.w8(S.sGlobalScriptContextStatus, 0)
  for _ = 1, 400 do
    F.idle(4)
    if F.grp() == g and F.mapn() == n and F.ow() then F.dismiss(20); return true end
  end
  return false
end

local function visit(tag, g, n, x, y, row, expectId)
  if not F.check(tag .. ": arrive", warp(g, n, x, y)) then return end
  F.press("Start", 2); F.idle(60)
  if not F.check(tag .. ": Story icon", F.selectStartIcon(USM_ICO_QUESTS)) then F.press("B", 2); F.idle(60); return end
  F.press("A", 2); F.idle(120)
  if not F.check(tag .. ": Story opens", inStory()) then return end
  F.check(tag .. ": opening objective", ascii(F.r32(objective(row))) == expectId, ascii(F.r32(objective(row))))
  for r = 0, 2 do
    local text, last = overviewLine(r)
    F.check(string.format("%s: row %d reads as a whole instruction", tag, r), TERMINAL[last] ~= nil,
      ascii(F.r32(objective(r))) .. ' "' .. text .. '"')
  end
  F.shot(tag)
  F.press("B", 2); F.idle(90); F.press("B", 2); F.idle(90)
  F.check(tag .. ": back on the field", F.dismiss(20))
end

F.run(function()
  if not F.check("boots to the hub", F.boot(100)) then F.finish(); return end
  visit("Pallet", 37, 0, 10, 8, 0, "kanto.starter")
  visit("New Bark", 75, 0, 10, 10, 1, "johto.elm")
  visit("Littleroot", 0, 9, 10, 10, 2, "hoenn.clock")
  F.finish()
end)
