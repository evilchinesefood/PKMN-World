-- Johto NPCs name Johto places. Three lines named Hoenn ones: Goldenrod Game Corner's coin clerk
-- runs Mauville's script and greeted "This is MAUVILLE GAME CORNER.", the Johto Safari Zone gate's
-- welcome attendant runs Route 121's and promised Pokemon "rarely seen in HOENN.", and Johto
-- Victory Road's Owen said the tough kid "is from PETALBURG CITY." pokemonHnS had reworded the
-- first two in its copies of the shared scripts; the region merge kept Emerald's wording.
--
-- With real input the suite talks to each of them (Owen after his defeat flag, as the battle leaves
-- it, with a Lapras in the party so he talks rather than refusing an empty party) and reads the
-- line the game prints.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/JohtoPlaceNames.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "JohtoPlaceNames")

local CONTEXT_SHUTDOWN = 2
local TRAINER_OWEN_JT = 0x6F7
local BUF = S.gStringVar4 + 900
local HOENN = { "MAUVILLE", "HOENN", "PETALBURG" }

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
local function settrainerflag(id)
  runScript({ 0x61, id & 0xFF, id >> 8, 0x02 })
  for _ = 1, 300 do F.idle(1); if F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN then return end end
end
local function warp(g, n, x, y)
  runScript({ 0x39, g, n, 0xFF, x & 0xFF, x >> 8, y & 0xFF, y >> 8, 0x27, 0x02 })
  for _ = 1, 600 do
    F.idle(4)
    local px, py = F.pos()
    if F.grp() == g and F.mapn() == n and px == x and py == y and hasControl() then F.idle(30); return true end
  end
  return false
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
  return table.concat(s)
end

local function givePokemon(sh, st, so, lh, lt, lo)
  F.dbg(); F.idle(60)
  for _ = 1, 3 do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(60)
  F.press("Down", 3); F.idle(16)
  F.press("A", 3); F.idle(60)
  F.spin(sh, st, so)
  F.spin(lh, lt, lo)
  F.idle(90)
  F.bOut(4); F.idle(60)
end

local function talk(tag, g, n, x, y, expect)
  if not F.check(tag .. ": stand before the NPC", warp(g, n, x, y)) then return end
  F.face("Up")
  F.w8(S.gStringVar4, 0xFF)
  F.press("A", 2)
  local said, last = {}, nil
  for i = 1, 2500 do
    local s = shownText()
    if s ~= last then last = s; if #s > 0 then said[#said + 1] = s; F.L("  " .. tag .. ": " .. s) end end
    if i == 40 then F.shot(tag) end
    if i > 30 and hasControl() then break end
    joypad.set((i % 24 == 0) and { B = true } or {})
    emu.frameadvance()
  end
  local all = table.concat(said, " | ")
  local wrong = nil
  for _, w in ipairs(HOENN) do if all:find(w, 1, true) then wrong = w end end
  F.check(tag .. ": names no Hoenn place", wrong == nil, wrong or "")
  F.check(tag .. ": says " .. expect, all:find(expect, 1, true) ~= nil, all:sub(1, 120))
  F.check(tag .. ": control returns", hasControl(), "")
end

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  givePokemon(1, 3, 0, 0, 9, 9)
  talk("goldenrod_coin_clerk", 84, 12, 3, 4, "GOLDENROD GAME CORNER")
  talk("johto_safari_attendant", 96, 2, 15, 5, "rarely seen in JOHTO")
  settrainerflag(TRAINER_OWEN_JT)
  talk("victory_road_owen", 99, 2, 43, 15, "NEW BARK TOWN")
  F.finish()
end)
