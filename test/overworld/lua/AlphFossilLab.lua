-- The Ruins of Alph lab and Devon's Rustboro lab revive fossils on separate machines. The Alph
-- lab came from pokemonHnS reading and writing Hoenn's VAR_FOSSIL_RESURRECTION_STATE and
-- VAR_WHICH_FOSSIL_REVIVED, so on this cartridge the two regions shared one regenerator: a Helix
-- Fossil handed in at Alph left Devon's fossil scientist mute (his script knows only Lileep and
-- Anorith and fell through to `end`), and a Root Fossil handed in at Devon came back as a Lileep
-- from the Johto researcher.
--
-- With real input the suite hands a Helix Fossil to the Alph researcher, talks to Devon's fossil
-- scientist (who must give his usual greeting and leave the Helix alone), collects the Omanyte at
-- Alph, then hands a Root Fossil to Devon, checks the Alph researcher does not produce it, and
-- collects the Lileep at Devon. Last, a save made before the split (a Kabuto pending in the shared
-- pair, the only form an old save can hold) must still be collected at Alph.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/AlphFossilLab.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "AlphFossilLab")

local CONTEXT_SHUTDOWN = 2
local ITEM_HELIX_FOSSIL, ITEM_ROOT_FOSSIL = 165, 168
local VAR_FOSSIL_RESURRECTION_STATE, VAR_WHICH_FOSSIL_REVIVED = 0x40C4, 0x40C5
local SPECIES_OMANYTE, SPECIES_KABUTO, SPECIES_LILEEP = 138, 140, 345
local ALPH, DEVON = { 79, 3, 7, 3, "Up" }, { 11, 1, 13, 8, "Right" }
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
local function setvar(id, v) runScript({ 0x16, id & 0xFF, id >> 8, v & 0xFF, v >> 8, 0x02 }); settle() end
local function additem(id) runScript({ 0x44, id & 0xFF, id >> 8, 1, 0, 0x02 }); settle() end

local function warp(at)
  local g, n, x, y = at[1], at[2], at[3], at[4]
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

-- A through the lines (YES to "bring it back to life?"), B on the nickname question (NO).
local function talk(tag, at)
  if not F.check(tag .. ": stand before the scientist", warp(at)) then return {} end
  F.face(at[5])
  F.w8(S.gStringVar4, 0xFF)
  F.press("A", 2)
  local said, last = {}, nil
  for i = 1, 3000 do
    local s = shownText()
    if s ~= last then last = s; if #s > 0 then said[#said + 1] = s; F.L("  " .. tag .. ": " .. s) end end
    if i > 30 and hasControl() then break end
    local btn = nil
    if i % 24 == 0 then btn = s:find("nickname") and "B" or "A" end
    joypad.set(btn and { [btn] = true } or {})
    emu.frameadvance()
  end
  F.shot(tag)
  F.check(tag .. ": control returns", hasControl(), "")
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
local function partySpecies(slot)
  local a = S.gParties + slot * S.Pokemon.size
  local key = F.r32(a) ~ F.r32(a + 4)
  return (F.r32(a + 32 + order(F.r32(a))[0] * 4) ~ key) & 0x7FF
end
local function party() return F.r8(S.gPartiesCount) end

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

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  givePokemon(1, 3, 0, 0, 9, 9)
  F.check("party is one Lapras", party() == 1, "party=" .. party())

  additem(ITEM_HELIX_FOSSIL)
  local s = talk("alph_hand_in", ALPH)
  F.check("alph_hand_in: the Helix Fossil is handed over", saidAny(s, "handed the Helix Fossil"), "")
  s = talk("devon_while_alph_works", DEVON)
  F.check("devon_while_alph_works: Devon's scientist gives his greeting", saidAny(s, "resurrects"), #s .. " lines")
  F.check("devon_while_alph_works: Devon hands out nothing", party() == 1, "party=" .. party())
  s = talk("alph_collect", ALPH)
  F.check("alph_collect: Omanyte comes back at Alph", party() == 2 and partySpecies(1) == SPECIES_OMANYTE,
    "party=" .. party() .. " species=" .. partySpecies(1))

  additem(ITEM_ROOT_FOSSIL)
  s = talk("devon_hand_in", DEVON)
  F.check("devon_hand_in: the Root Fossil is handed over", saidAny(s, "handed the Root Fossil"), "")
  s = talk("alph_while_devon_works", ALPH)
  F.check("alph_while_devon_works: the Alph researcher hands out nothing", party() == 2,
    "party=" .. party() .. " species=" .. partySpecies(2))
  F.check("alph_while_devon_works: the Alph researcher gives his greeting", saidAny(s, "resurrects"), #s .. " lines")
  local before = party()
  s = talk("devon_collect", DEVON)
  F.check("devon_collect: Lileep comes back at Devon", party() == before + 1 and partySpecies(before) == SPECIES_LILEEP,
    before .. " -> " .. party() .. " species=" .. partySpecies(before))

  setvar(VAR_FOSSIL_RESURRECTION_STATE, 1)
  setvar(VAR_WHICH_FOSSIL_REVIVED, 4)
  before = party()
  s = talk("alph_old_save", ALPH)
  F.check("alph_old_save: a Kabuto pending from an older save comes back at Alph",
    party() == before + 1 and partySpecies(before) == SPECIES_KABUTO, before .. " -> " .. party() .. " species=" .. partySpecies(before))
  F.finish()
end)
