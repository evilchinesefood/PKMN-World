-- Battles that end with both sides fainting, and Struggle, with one Pokemon in front of two Eggs.
--
-- Explosion and Perish Song can knock out the player's last Pokemon on the same turn as the
-- foe's. The engine scores that as a draw (gBattleOutcome 3), which the overworld treats as a
-- defeat. Each case starts a real scripted wild battle (setwildbattle, dowildbattle) at Instant
-- text and 2x Money Loss and requires: the battle ends in a draw, the player whites out to the
-- field with control back and no crash screen, the wallet is charged the 2x defeat amount, and
-- the party is still the same Pokemon and two Eggs with the Pokemon healed.
-- A Struggle case empties every PP mid-battle against a foe left with only Splash, and requires
-- the battle to be won, the lead to have taken damage (only Struggle's recoil can do that), and
-- the field to come back.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/DoubleKoWhiteout.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "DoubleKoWhiteout")

local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local PARTY_SIZE = 6
local OUT_WON, OUT_DREW = 1, 3
local SPECIES_ELECTRODE, SPECIES_MAGIKARP, SPECIES_TOGEPI, SPECIES_MISDREAVUS, SPECIES_MEWTWO = 101, 129, 175, 200, 150
local MOVE_TACKLE, MOVE_SPLASH, MOVE_EXPLOSION, MOVE_PERISH_SONG = 33, 150, 153, 195
local RATE_2X = 3
local BM = S.BattlePokemon

local function inBattle() return F.cb2() == (S.BattleMainCB2 & ~1) end
local function partyAddr(s) return S.gParties + s * S.Pokemon.size end
local function partyCount() return F.r8(S.gPartiesCount) end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0
    and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end

local function monAt(slot)
  local b = partyAddr(slot)
  local pid = F.r32(b)
  local key = pid ~ F.r32(b + 4)
  local w0 = F.r32(b + 32 + F.r8(S.sSubstructOffsets + (pid % 24)) * 12) ~ key
  return w0 & 0x7FF, (F.r8(b + 19) & 4) ~= 0
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

-- createmon for the player into the first free slot, moves pinned, player OT.
local function giveMon(species, level, moves)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = PARTY_SIZE
  le16(b, species); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for k = 1, 4 do le16(b, moves[k] or 0) end
  b[#b + 1] = 0x02
  local before = partyCount()
  runScript(b); F.idle(20)
  return partyCount() == before + 1
end
local function giveEgg(species)
  local b = { 0x7A }; le16(b, species); b[#b + 1] = 0x02
  local before = partyCount()
  runScript(b); F.idle(20)
  return partyCount() == before + 1
end

local function wipeParty()
  F.w8(S.gPartiesCount, 0)
  for s = 0, PARTY_SIZE - 1 do
    for o = 0, S.Pokemon.size - 1, 4 do F.w32(partyAddr(s) + o, 0) end
  end
end

local function options() return F.sb2() + S.SaveBlock2.optionsU16 end
local function setMoney(v)
  F.w32(F.sb1() + S.SaveBlock1.money, v ~ F.r32(F.sb2() + S.SaveBlock2.encryptionKey))
end

local function startWild(species, level)
  local b = { 0xB6 }
  le16(b, species); b[#b + 1] = level; le16(b, 0)
  le16(b, 0); b[#b + 1] = 0; le16(b, 0)
  b[#b + 1] = 0xB7
  b[#b + 1] = 0x02
  runScript(b)
  for i = 1, 1500 do
    F.idle(1)
    if inBattle() and F.battlers() >= 2 then F.idle(4); return true end
  end
  return false
end

local function bpp(b, slot) return F.r8(S.gBattleMons + b * BM.size + BM.pp + slot) end

-- Fight with the move the policy picks; A and B alternate through text and prompts.
local function fight(tag, policy, budget)
  local outcome, sawText = 0, {}
  for f = 1, budget do
    if inBattle() then
      local o = F.outcome()
      if o ~= 0 then outcome = o end
      local cursor = policy(f)
      if cursor then F.w8(S.gMoveSelectionCursor, cursor) end
      if f % 12 == 0 then F.press("A", 2) else F.idle(1) end
    elseif F.ow() then
      if hasControl() then return outcome, true end
      if f % 20 == 0 then F.press("A", 2) else F.idle(1) end
    else
      if f % 20 == 0 then F.press("A", 2) else F.idle(1) end
    end
    if f % 120 == 0 and F.reportCrash(tag) then return outcome, false end
  end
  return outcome, false
end

local function scenario(name, lead, wild, policy, expectOutcome, onStart)
  F.L("-- " .. name)
  F.ensureFree()
  wipeParty()
  local built = giveMon(lead.species, lead.level, lead.moves) and giveEgg(SPECIES_TOGEPI) and giveEgg(SPECIES_TOGEPI)
  if not F.check(name .. ": party built", built and partyCount() == 3) then return end
  local maxHp = F.r16(partyAddr(0) + S.Pokemon.maxHP)
  setMoney(10000)
  if not F.check(name .. ": wild battle starts", startWild(wild.species, wild.level)) then F.shot(name .. "_nostart"); return end
  if onStart then onStart() end
  local outcome, back = fight(name, policy, 30000)
  F.check(name .. string.format(": outcome %d", expectOutcome), outcome == expectOutcome, "outcome=" .. outcome)
  F.check(name .. ": field and control come back", back, string.format("cb2=%08X lock=%d ctx=%d",
    F.cb2(), F.r8(S.sLockFieldControls), F.r8(S.sGlobalScriptContextStatus)))
  F.check(name .. ": no crash screen", not F.reportCrash(name))
  local s0, e0 = monAt(0)
  local s1, e1 = monAt(1)
  local s2, e2 = monAt(2)
  F.check(name .. ": party is the lead and two Eggs", partyCount() == 3 and s0 == lead.species and not e0 and e1 and e2
    and s1 == SPECIES_TOGEPI and s2 == SPECIES_TOGEPI,
    string.format("count=%d %d/%s %d/%s %d/%s", partyCount(), s0, tostring(e0), s1, tostring(e1), s2, tostring(e2)))
  return maxHp
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  F.w16(options(), (F.r16(options()) & ~7) | 3 | (1 << 9) | (1 << 10))
  local rates = F.sb2() + S.SaveBlock2.ratesU16
  F.w16(rates, (F.r16(rates) & ~S.SaveBlock2.moneyLossMask) | (RATE_2X << 8))

  for _, c in ipairs({
    { name = "Explosion", lead = { species = SPECIES_ELECTRODE, level = 50, moves = { MOVE_EXPLOSION } },
      policy = function() return 0 end },
    { name = "Perish Song", lead = { species = SPECIES_MISDREAVUS, level = 50, moves = { MOVE_PERISH_SONG, MOVE_SPLASH } },
      policy = function() return bpp(0, 0) > 0 and 0 or 1 end,
      start = function() F.w8(S.gBattleMons + BM.pp, 1) end },
  }) do
    local maxHp = scenario(c.name, c.lead, { species = SPECIES_MAGIKARP, level = 5 }, c.policy, OUT_DREW, c.start)
    if maxHp then
      local hp = F.r16(partyAddr(0) + S.Pokemon.hp)
      F.check(c.name .. ": whiteout healed the lead", hp == maxHp and hp > 0, string.format("hp=%d/%d", hp, maxHp))
      local money = F.money()
      -- No badges: 8 per level of the strongest party member (50), doubled by 2x Money Loss.
      F.check(c.name .. ": the draw charged 800 defeat money", money == 9200, "money=" .. money)
      F.L(string.format("  %s: money 10000 -> %d at %d/%d", c.name, money, F.grp(), F.mapn()))
    end
  end

  local struggled = false
  local maxHp = scenario("Struggle", { species = SPECIES_MEWTWO, level = 100, moves = { MOVE_TACKLE, MOVE_SPLASH } },
    { species = SPECIES_MAGIKARP, level = 60 },
    function()
      if inBattle() and F.battlers() >= 2 then
        F.w8(S.gBattleMons + BM.pp, 0); F.w8(S.gBattleMons + BM.pp + 1, 0)
        for k = 0, 3 do F.w16(S.gBattleMons + BM.size + BM.moves + 2 * k, k == 0 and MOVE_SPLASH or 0) end
        struggled = struggled or F.r16(S.gBattleMons + BM.hp) < F.r16(S.gBattleMons + BM.maxHP)
      end
      return 0
    end, OUT_WON)
  if maxHp then
    F.check("Struggle: recoil landed on the lead", struggled)
  end
  F.finish()
end)
