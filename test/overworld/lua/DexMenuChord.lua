-- A Pokedex menu row that starts a screen change must survive B or Start pressed on the same frame.
--
-- Both Pokedex START menus (the list and the search results) handle A, then on the same frame
-- handle START/B as "close the menu". Special Pokemon, Close Pokedex and Back to Pokedex begin a
-- fade to black and hand the task to their transition; a START or B pressed with that A handed the
-- task straight back to the list, so the fade finished on a black screen with the list still
-- taking input. Each case drives the real Pokedex from the field with real input, puts the cursor
-- on the row, presses A with B (or START) for the same two frames, and requires the row's own
-- destination 240 frames later on a screen that is not all black:
--
--   list menu:    Special Pokemon (A+B, A+START) opens the checklist; Close Pokedex (A+B) the field
--   search menu:  Special Pokemon (A+B) opens the checklist; Back to Pokedex (A+B) the full list;
--                 Close Pokedex (A+B) the field
--
-- Every case must then hand control back on the field.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/DexMenuChord.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "DexMenuChord")

local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local FLAG_SYS_POKEDEX_GET = 0x949
local FLAG_SYS_DEXNAV_GET = 0x948 + 0xBE
local USM_ICO_POKEDEX = 0
local SPECIES_PIKACHU, MOVE_THUNDER_SHOCK = 25, 84
local ROW_SPECIAL, ROW_CLOSE, ROW_SEARCH_BACK, ROW_SEARCH_CLOSE = 3, 4, 4, 5

local function cb2() return F.cb2() end
local function inDex() return cb2() == (S.CB2_Pokedex & ~1) end
local function inChecklist() return cb2() == (S.RunCollection & ~1) end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0
    and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
-- Nonzero colours in the faded palette buffer: 0 means everything on screen is black.
local function litColours()
  local n = 0
  for i = 0, 511 do if F.r16(S.gPlttBufferFaded + i * 2) ~= 0 then n = n + 1 end end
  return n
end

local function runScript(bytes)
  local buf = S.gStringVar4 + 960
  for i, b in ipairs(bytes) do F.w8(buf + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, buf)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
end
local function giveSeenMon()
  local b = { 0x23 }
  local function le16(v) b[#b + 1] = v & 0xFF; b[#b + 1] = (v >> 8) & 0xFF end
  local fn = S.ScrCmd_createmon | 1
  le16(fn & 0xFFFF); le16(fn >> 16)
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(SPECIES_PIKACHU); le16(10)
  le16(0); le16((1 << 1) | (1 << 2) | (1 << 3) | (1 << 4))
  le16(MOVE_THUNDER_SHOCK); le16(0); le16(0); le16(0)
  b[#b + 1] = 0x02
  runScript(b); F.idle(30)
end

local function awaitControl(tag)
  for _ = 1, 40 do
    if hasControl() then F.idle(10); return F.check(tag .. ": control returns on the field", true) end
    F.press("B", 2); F.idle(30)
  end
  return F.check(tag .. ": control returns on the field", false, string.format("cb2=%08X", cb2()))
end

local function openDex()
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_POKEDEX) then return false end
  F.press("A", 2)
  for _ = 1, 300 do F.idle(1); if inDex() then F.idle(120); return true end end
  return false
end

local function openSearchResults()
  F.press("Select", 2); F.idle(120)
  F.press("A", 2); F.idle(60)
  for _ = 1, 4 do F.press("Down", 2); F.idle(15) end
  F.press("A", 2); F.idle(240)
  F.press("A", 2); F.idle(240)
end

local function openMenuAt(row)
  F.press("Start", 2); F.idle(60)
  for _ = 1, 6 do F.press("Up", 2); F.idle(10) end
  for _ = 1, row do F.press("Down", 2); F.idle(10) end
end

local function chord(other)
  local keys = { A = true }
  keys[other] = true
  for _ = 1, 2 do joypad.set(keys); emu.frameadvance() end
  F.idle(240)
end

local function case(tag, search, row, other, expect)
  F.L("== " .. tag)
  if not F.check(tag .. ": the Pokedex opens", openDex()) then awaitControl(tag); return end
  if search then openSearchResults() end
  openMenuAt(row)
  chord(other)
  local lit, where = litColours(), string.format("cb2=%08X", cb2())
  F.shot(tag:gsub("%W+", "_"))
  if expect == "checklist" then
    F.check(tag .. ": the checklist opens", inChecklist(), where)
    F.press("B", 2); F.idle(200)
    F.check(tag .. ": B returns to the Pokedex", inDex() and litColours() > 0, string.format("cb2=%08X", cb2()))
  elseif expect == "list" then
    F.check(tag .. ": the full Pokedex list returns", inDex(), where)
  else
    F.check(tag .. ": the Pokedex closes", not inDex(), where)
  end
  F.check(tag .. ": the screen is not left black", lit > 0, lit .. " lit colours")
  awaitControl(tag)
end

F.run(function()
  if not F.check("boots to the hub", F.boot(100)) then F.finish(); return end
  for _, id in ipairs({ FLAG_SYS_POKEDEX_GET, FLAG_SYS_DEXNAV_GET }) do
    local a = F.sb1() + S.SaveBlock1.flags + id // 8
    F.w8(a, F.r8(a) | (1 << (id % 8)))
  end
  giveSeenMon()

  case("list menu Special Pokemon with B", false, ROW_SPECIAL, "B", "checklist")
  case("list menu Special Pokemon with START", false, ROW_SPECIAL, "Start", "checklist")
  case("list menu Close Pokedex with B", false, ROW_CLOSE, "B", "field")
  case("search menu Special Pokemon with B", true, ROW_SPECIAL, "B", "checklist")
  case("search menu Back to Pokedex with B", true, ROW_SEARCH_BACK, "B", "list")
  case("search menu Close Pokedex with B", true, ROW_SEARCH_CLOSE, "B", "field")
  F.finish()
end)
