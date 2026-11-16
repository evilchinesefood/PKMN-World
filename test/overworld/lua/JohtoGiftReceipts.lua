-- Johto's scripted Pokemon gifts announce themselves. The pokemonHnS port dropped the call to
-- HnS's Common_EventScript_GiftMon / GiftMonNamed at six gifts and kept only the full-party
-- branch, so Bill's Eevee, Kirk's Shuckie, Randy's Kenya and the Dragon's Den elder's Dratini
-- joined the party with no fanfare and no "received" line, and the Karate King's Tyrogue and the
-- elder's basic Dratini went to a PC box without a word when the party was full.
--
-- With real input the suite talks to each giver, answering YES to their offers and NO to the
-- nickname prompt, and records every message the game prints. Party-room gifts first (Bill, Kirk,
-- Randy, the elder after a perfect quiz), then with a full party of six the two gifts that can go
-- to a box (Kiyo after his defeat, the elder after a quiz with a wrong answer). State is seeded the
-- way the story leaves it: Bill shown, FLAG_BEAT_KIYO, VAR_BLACKTHORN_CITY_STATE 4 and the quiz var.
-- Species names print in mixed case in this build, so the lines are compared case-blind.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/JohtoGiftReceipts.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "JohtoGiftReceipts")

local CONTEXT_SHUTDOWN = 2
local FLAG_HIDE_GOLDENROD_BILL, FLAG_BEAT_KIYO, FLAG_GOT_DRATINI = 0x60D8, 0x60EC, 0x6162
local VAR_BLACKTHORN_CITY_STATE, VAR_DRAGONS_DEN_QUIZ = 0xA0AB, 0xA0AD
local SPECIES_TYROGUE, SPECIES_DRATINI = 236, 147
local BUF = S.gStringVar4 + 900

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
local function settle() for _ = 1, 300 do F.idle(1); if F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN then return end end end
local function setflag(id) runScript({ 0x29, id & 0xFF, id >> 8, 0x02 }); settle() end
local function clearflag(id) runScript({ 0x2A, id & 0xFF, id >> 8, 0x02 }); settle() end
local function setvar(id, v) runScript({ 0x16, id & 0xFF, id >> 8, v & 0xFF, v >> 8, 0x02 }); settle() end

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

-- A through the giver's lines (YES to the offer), B on the nickname question (NO).
local function converse(tag)
  local seen, said, last = {}, {}, nil
  for i = 1, 4000 do
    local s = shownText()
    if s ~= last then
      last = s
      if not seen[s] and #s > 0 then seen[s] = true; said[#said + 1] = s; F.L("  " .. tag .. " says: " .. s) end
    end
    if i > 30 and hasControl() then break end
    local btn = nil
    if i % 24 == 0 then btn = s:find("nickname") and "B" or "A" end
    joypad.set(btn and { [btn] = true } or {})
    emu.frameadvance()
  end
  return said
end
local function saidAny(said, pattern)
  for _, s in ipairs(said) do if s:lower():find(pattern:lower(), 1, true) then return true end end
  return false
end

local function order(p)
  local o = {}
  for i = 0, 3 do o[i] = F.r8(S.sSubstructOffsets + i * 24 + p % 24) * 3 end
  return o
end
local function monSpecies(a)
  local key = F.r32(a) ~ F.r32(a + 4)
  local o = order(F.r32(a))
  return (F.r32(a + 32 + o[0] * 4) ~ key) & 0x7FF
end
local function party() return F.r8(S.gPartiesCount) end
local function boxSpecies(slot) return monSpecies(F.r32(S.gPokemonStoragePtr) + 4 + slot * S.BoxPokemon.size) end

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

local function gift(tag, g, n, x, y, received, toBox)
  local before = party()
  if not F.check(tag .. ": stand before the giver", warp(g, n, x, y)) then return end
  F.face("Up")
  F.w8(S.gStringVar4, 0xFF)
  F.press("A", 2)
  local said = converse(tag)
  F.shot(tag)
  F.check(tag .. ": the gift is announced", saidAny(said, received), #said .. " messages")
  if toBox then
    F.check(tag .. ": the full party stays at six", party() == 6, "party=" .. party())
    F.check(tag .. ": the PC notice names the box", saidAny(said, "transferred to"), "")
  else
    F.check(tag .. ": the Pokemon joins the party", party() == before + 1, before .. " -> " .. party())
  end
  F.check(tag .. ": control returns", hasControl(), "")
end

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  givePokemon(1, 3, 0, 0, 9, 9)
  F.check("party is one Lapras", party() == 1, "party=" .. party())

  clearflag(FLAG_HIDE_GOLDENROD_BILL)
  gift("bill", 84, 1, 5, 5, "received EEVEE")
  gift("kirk", 90, 3, 4, 5, "received SHUCKLE")
  gift("randy", 83, 6, 3, 6, "received SPEAROW")
  setvar(VAR_BLACKTHORN_CITY_STATE, 4)
  setvar(VAR_DRAGONS_DEN_QUIZ, 0)
  gift("elder_perfect", 94, 14, 6, 10, "received DRATINI")

  givePokemon(0, 1, 5, 0, 0, 4)
  F.check("party is full", party() == 6, "party=" .. party())
  setflag(FLAG_BEAT_KIYO)
  gift("kiyo_full", 92, 12, 16, 5, "received TYROGUE", true)
  F.check("kiyo_full: Tyrogue is in box 1", boxSpecies(0) == SPECIES_TYROGUE, "species=" .. boxSpecies(0))
  clearflag(FLAG_GOT_DRATINI)
  setvar(VAR_DRAGONS_DEN_QUIZ, 1)
  gift("elder_full", 94, 14, 6, 10, "received DRATINI", true)
  F.check("elder_full: Dratini is in box 1", boxSpecies(1) == SPECIES_DRATINI, "species=" .. boxSpecies(1))
  F.finish()
end)
