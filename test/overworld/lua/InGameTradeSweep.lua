-- Every in-game trade, played through its own NPC with a full party.
--
-- 5ac8745870 removed the LeafGreen rows of src/data/trade.h; the table now holds four Hoenn,
-- nine Kanto and four Johto trades. Each case warps beside the trader with a six-Pokemon party:
-- Magikarp, an Egg of the requested species, two Magikarp, the requested species (level 20) and a
-- Magikarp. With real input it declines once, offers the Egg, offers a Magikarp, then offers the
-- requested Pokemon and mashes A, B, Start, L, R and the D-pad (never Select) through the trade
-- scene. Declining and both wrong offers must leave the party and the trade flag untouched. The
-- trade must put the promised species in slot 5 with a valid checksum, keep the other five
-- members (the Egg still an Egg), set the trade flag and return control. Talking again must not
-- open a picker. Kanto's traders pick from the party menu, the ingame_trade macro's from the
-- storage screen's party column.
--
-- PW_TRADE_ONLY=<text> runs matching trades, PW_TRADE_BASE=<n> reseeds the mash.
-- Run: test/overworld/mgba-run.sh test/overworld/lua/InGameTradeSweep.lua --env PW_MAX_FRAMES=900000

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "InGameTradeSweep")

local ONLY = os.getenv("PW_TRADE_ONLY")
local BASE = tonumber(os.getenv("PW_TRADE_BASE") or "") or 0x7EAD
local MON = S.Pokemon.size
local SPECIES_MAGIKARP = 129
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local PARTY_MENU_SLOT = 9
local CURSOR_AREA_IN_PARTY = 1
local WANT_SLOT = 4

-- Generated from data/maps/*/scripts.inc, map.json and src/data/trade.h.
local TRADES = {
  { tag = "seedot", map = { 11, 10 }, npc = { 6, 4 }, want = 280, give = 273, flag = 0x99 },
  { tag = "plusle", map = { 12, 0 }, npc = { 1, 3 }, want = 313, give = 311, flag = 0x9B },
  { tag = "horsea", map = { 7, 4 }, npc = { 4, 2 }, want = 371, give = 116, flag = 0x9A },
  { tag = "meowth", map = { 26, 48 }, npc = { 2, 4 }, want = 300, give = 52, flag = 0x9C },
  { tag = "mr_mime", map = { 49, 1 }, npc = { 7, 2 }, want = 63, give = 122, flag = 0xC88 },
  { tag = "jynx", map = { 41, 2 }, npc = { 2, 2 }, want = 61, give = 124, flag = 0xC8A },
  { tag = "nidoran", map = { 35, 30 }, npc = { 5, 6 }, want = 32, give = 29, flag = 0xC8B },
  { tag = "farfetchd", map = { 43, 4 }, npc = { 4, 4 }, want = 21, give = 83, flag = 0xC8D },
  { tag = "nidorinoa", map = { 56, 1 }, npc = { 7, 3 }, want = 33, give = 30, flag = 0xC91 },
  { tag = "lickitung", map = { 60, 1 }, npc = { 5, 3 }, want = 55, give = 108, flag = 0xC97 },
  { tag = "electrode", map = { 46, 2 }, npc = { 4, 6 }, want = 26, give = 101, flag = 0xCB4 },
  { tag = "tangela", map = { 46, 2 }, npc = { 10, 5 }, want = 48, give = 114, flag = 0xCB5 },
  { tag = "seel", map = { 46, 4 }, npc = { 11, 8 }, want = 77, give = 86, flag = 0xCB6 },
  { tag = "machop", map = { 84, 9 }, npc = { 13, 10 }, want = 96, give = 66, flag = 0x60C9 },
  { tag = "voltorb", map = { 88, 2 }, npc = { 4, 4 }, want = 98, give = 100, flag = 0x613F },
  { tag = "onix", map = { 78, 1 }, npc = { 7, 5 }, want = 69, give = 95, flag = 0x6030 },
  { tag = "mr_mime_emy", map = { 94, 2 }, npc = { 2, 4 }, want = 85, give = 122, flag = 0x61B1 },
}

local seed = BASE
local function rnd()
  seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
  return seed >> 8
end
local function seedFor(tag)
  local h = BASE & 0x7FFFFFFF
  for i = 1, #tag do h = ((h ~ tag:byte(i)) * 16777619) & 0x7FFFFFFF end
  return h
end

local SCRIPT_BUF = S.gStringVar4 + 960
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
end
local function createMon(species, level)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(b, species); le16(b, level)
  le32(b, 0)
  b[#b + 1] = 0x02
  runScript(b); F.idle(20)
end
local function giveEgg(species) local b = { 0x7A }; le16(b, species); b[#b + 1] = 0x02; runScript(b); F.idle(20) end

local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end
local function scriptIdle() return F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN end
local function hasControl() return F.ow() and F.r8(S.sLockFieldControls) == 0 and scriptIdle() end
local function settle()
  for _ = 1, 400 do if hasControl() then return true end F.press("B", 2); F.idle(10) end
  return hasControl()
end
local function inPartyMenu() return F.cb2() == (S.CB2_UpdatePartyMenu & ~1) end

local function flag(id)
  if id >= 0x6000 then
    return (F.r8(F.sb3() + S.SaveBlock3.johtoFlags + (id - 0x6000) // 8) >> (id % 8)) & 1 == 1
  end
  return (F.r8(F.sb1() + S.SaveBlock1.flags + id // 8) >> (id % 8)) & 1 == 1
end

local function slot(i) return S.gParties + i * MON end
local function order(p)
  local o = {}
  for i = 0, 3 do o[i] = F.r8(S.sSubstructOffsets + i * 24 + p % 24) * 3 end
  return o
end
local function words(a)
  local key = F.r32(a) ~ F.r32(a + 4)
  local w = {}
  for i = 0, 11 do w[i] = F.r32(a + 32 + i * 4) ~ key end
  return w, order(F.r32(a))
end
local function species(a) local w, o = words(a); return w[o[0]] & 0x7FF end
local function checksumOk(a)
  local w = words(a)
  local sum = 0
  for i = 0, 11 do sum = sum + (w[i] & 0xFFFF) + (w[i] >> 16) end
  return (sum & 0xFFFF) == F.r16(a + 28)
end
local function isEgg(i) return (F.r8(slot(i) + 19) & 0x04) ~= 0 end
local function partyState()
  local t = {}
  for i = 0, F.r8(S.gPartiesCount) - 1 do
    t[#t + 1] = string.format("%08X:%d%s", F.r32(slot(i)), species(slot(i)), isEgg(i) and "e" or "")
  end
  return table.concat(t, ",")
end

local function warpScript(g, n, x, y)
  local b = { 0x39, g, n, 0xFF }
  le16(b, x); le16(b, y); b[#b + 1] = 0x27; b[#b + 1] = 0x02
  runScript(b)
  for _ = 1, 400 do
    F.idle(4)
    if F.reportCrash("warp") then return false end
    if F.grp() == g and F.mapn() == n and F.ow() then return true end
  end
  return false
end

local SIDES = { { 0, 1, "Up" }, { -1, 0, "Right" }, { 1, 0, "Left" }, { 0, -1, "Down" } }

-- Warps beside the trader on the first side where A starts its script, and leaves the script
-- running at its first message. Returns the side used.
local function startTalk(t, side)
  local sides = side and { side } or SIDES
  for _, s in ipairs(sides) do
    if not warpScript(t.map[1], t.map[2], t.npc[1] + s[1], t.npc[2] + s[2]) then return nil end
    settle(); instantText()
    F.face(s[3])
    F.press("A", 2)
    for _ = 1, 40 do
      F.idle(1)
      if not scriptIdle() then return s end
    end
  end
  return nil
end

local function waitControl(maxPress, key)
  for _ = 1, maxPress do
    if hasControl() then return true end
    F.press(key, 2); F.idle(14)
  end
  return hasControl()
end

-- Kanto's traders open the party menu; the ingame_trade macro opens the storage screen
-- (OW_CHOOSE_FROM_PC_AND_PARTY), whose party column is reached with Left.
local function inStorage() return not F.ow() and not inPartyMenu() and F.r32(S.sStorage) ~= 0 end
local function inPicker() return inPartyMenu() or inStorage() end

-- Yes, then the picker. Returns true once a picker is up.
local function answerYes()
  for _ = 1, 200 do
    if inPicker() then F.idle(60); return true end
    if hasControl() then return false end
    F.press("A", 2); F.idle(16)
  end
  return inPicker()
end

local function pickSlot(target)
  local on
  if inPartyMenu() then
    for _ = 1, 14 do
      local s = F.rs8(S.gPartyMenu + PARTY_MENU_SLOT)
      if s == target then break end
      F.press(s < target and "Down" or "Up", 2); F.idle(16)
    end
    on = F.rs8(S.gPartyMenu + PARTY_MENU_SLOT) == target
  else
    for _ = 1, 8 do
      if F.r8(S.sCursorArea) == CURSOR_AREA_IN_PARTY then break end
      F.press("Left", 2); F.idle(30)
    end
    for _ = 1, 14 do
      local s = F.rs8(S.sCursorPosition)
      if F.r8(S.sCursorArea) ~= CURSOR_AREA_IN_PARTY or s == target then break end
      F.press(s < target and "Down" or "Up", 2); F.idle(30)
    end
    on = F.r8(S.sCursorArea) == CURSOR_AREA_IN_PARTY and F.rs8(S.sCursorPosition) == target
  end
  for _ = 1, 6 do
    if not inPicker() then break end
    F.press("A", 2); F.idle(40)
  end
  return on
end

local DIRS = { "Up", "Down", "Left", "Right" }
local function mashFrame()
  local t = {}
  for b, p in pairs({ A = 30, B = 25, Start = 8, L = 8, R = 8 }) do
    if rnd() % 100 < p then t[b] = true end
  end
  if t.R and t.Start then t.R = nil end
  if rnd() % 100 < 40 then t[DIRS[rnd() % 4 + 1]] = true end
  joypad.set(t)
  emu.frameadvance()
end

local function setupParty(want)
  for off = 0, 6 * MON - 4, 4 do F.w32(S.gParties + off, 0) end
  F.w8(S.gPartiesCount, 0)
  createMon(SPECIES_MAGIKARP, 10)
  giveEgg(want)
  createMon(SPECIES_MAGIKARP, 11)
  createMon(SPECIES_MAGIKARP, 12)
  createMon(want, 20)
  createMon(SPECIES_MAGIKARP, 13)
end

local function case(t)
  if ONLY and not t.tag:find(ONLY, 1, true) then return end
  seed = seedFor(t.tag)
  F.L(string.format("== %s == seed=%d", t.tag, seed))
  if not F.check(t.tag .. ": control before the case", settle()) then return end
  setupParty(t.want)
  local party0 = partyState()
  if not F.check(t.tag .. ": setup party of six with the Egg in slot 2 and the requested Pokemon in slot 5",
      F.r8(S.gPartiesCount) == 6 and isEgg(1) and species(slot(WANT_SLOT)) == t.want, party0) then return end
  F.check(t.tag .. ": trade flag starts clear", not flag(t.flag))

  local side = startTalk(t)
  if not F.check(t.tag .. ": the trader's script starts", side ~= nil, string.format("at %d.%d", F.grp(), F.mapn())) then
    F.shot(t.tag .. "_no_talk"); settle(); return
  end
  F.shot(t.tag .. "_offer")
  local menu = false
  for _ = 1, 120 do
    if hasControl() then break end
    if inPicker() then menu = true end
    F.press("B", 2); F.idle(14)
  end
  F.check(t.tag .. ": declining returns control without a picker", hasControl() and not menu)
  F.check(t.tag .. ": declining leaves party and flag", partyState() == party0 and not flag(t.flag), partyState())

  for _, wrong in ipairs({ { 1, "the Egg" }, { 0, "a Magikarp" } }) do
    if startTalk(t, side) and answerYes() then
      pickSlot(wrong[1])
      for _ = 1, 30 do if not inPicker() then break end F.press("B", 2); F.idle(20) end
      F.check(string.format("%s: offering %s returns control", t.tag, wrong[2]), waitControl(600, "B"))
      F.check(string.format("%s: offering %s trades nothing", t.tag, wrong[2]), partyState() == party0 and not flag(t.flag),
        partyState())
    else
      F.check(string.format("%s: Yes opened the picker for %s", t.tag, wrong[2]), false)
      settle()
    end
  end

  if not (startTalk(t, side) and answerYes()) then
    F.check(t.tag .. ": Yes opened the picker", false); settle(); return
  end
  F.shot(t.tag .. "_picker")
  local pids = {}
  for i = 0, 5 do pids[i] = F.r32(slot(i)) end
  F.check(t.tag .. ": cursor reached slot 5", pickSlot(WANT_SLOT))
  local leftField, crashed = false, false
  for i = 1, 9000 do
    if i % 10 == 0 and F.reportCrash(t.tag) then crashed = true; break end
    if not F.ow() and not inPicker() then leftField = true end
    if leftField and hasControl() then break end
    mashFrame()
  end
  joypad.set({})
  F.check(t.tag .. ": no crash in the trade", not crashed)
  F.check(t.tag .. ": the trade scene ran", leftField)
  F.check(t.tag .. ": control after the trade", settle())
  local party1 = partyState()
  F.L("  after: " .. party1)
  local kept = F.r8(S.gPartiesCount) == 6
  for i = 0, 5 do
    if i ~= WANT_SLOT then kept = kept and F.r32(slot(i)) == pids[i] end
  end
  F.check(t.tag .. ": the other five members are kept, the Egg still an Egg", kept and isEgg(1), party1)
  F.check(t.tag .. ": slot 5 holds the promised species with a valid checksum",
    species(slot(WANT_SLOT)) == t.give and checksumOk(slot(WANT_SLOT)) and not isEgg(WANT_SLOT),
    "species=" .. species(slot(WANT_SLOT)))
  F.check(t.tag .. ": trade flag set", flag(t.flag))
  F.shot(t.tag .. "_after")

  if startTalk(t, side) then
    local menu2 = false
    for _ = 1, 120 do
      if hasControl() then break end
      if inPicker() then menu2 = true end
      F.press("B", 2); F.idle(14)
    end
    F.check(t.tag .. ": talking again opens no picker", not menu2 and hasControl())
    F.check(t.tag .. ": talking again changes nothing", partyState() == party1, partyState())
  else
    F.check(t.tag .. ": the trader still talks after the trade", false)
  end
end

F.run(function()
  if not F.boot(100) then F.finish(); return end
  instantText()
  for _, t in ipairs(TRADES) do case(t) end
  F.check("no crash", not F.reportCrash("end"))
  F.finish()
end)
