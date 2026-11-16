-- The Battle Net Little Cup room, driven with real input at the Hub 2F streak attendant.
--
-- CheckBattleNetRuleParty (src/battle_net.c) accepts a party whose every non-Egg member is level 5,
-- has no enabled pre-evolution and can still evolve. Each case builds a party, talks to the
-- attendant, picks LITTLE CUP and reads what happens: a refusal must print the Little Cup rule and
-- return to the menu with the party untouched; an accepted party must start a sim battle against
-- three level 5 opponents, and a win pays 2 BP. Pre-evolutions above #386 count (0829014ec0): Chansey
-- (Happiny) and Roselia (Budew) are refused, like Pikachu (Pichu).
--
-- PW_LC_ONLY=<text> (runner --env) runs matching cases.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/LittleCupRules.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "LittleCupRules")

local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local PARTY_SIZE = 6
local MON = S.Pokemon.size
local OFF_LEVEL = 0x54
local BP_STRIDE, BP_HP = S.BattlePokemon.size, S.BattlePokemon.hp
local B_OUTCOME_WON = 1
local MENU_LAST, ROW_LC, ROW_BYE = 4, 3, 4
local ONLY = os.getenv("PW_LC_ONLY")

local SP = {
  BULBASAUR = 1, IVYSAUR = 2, PIKACHU = 25, CHANSEY = 113, DITTO = 132, EEVEE = 133,
  PICHU = 172, MARILL = 183, AZURILL = 298, ROSELIA = 315, TOGEPI = 175,
  EEVEE_FLOWER_CROWN = S.SPECIES_EEVEE_FLOWER_CROWN or 1578,
}

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function maxRow() return F.r8(S.sMenu + S.Menu.maxCursorPos) end
local function cursor() return F.rs8(S.sMenu + S.Menu.cursorPos) end
local function forgetMenu() F.w8(S.sMenu + S.Menu.maxCursorPos, 0) end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0
    and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end

-- gStringVar4 holds the expanded text of the message on screen.
local function text()
  local out = {}
  for i = 0, 200 do
    local c = F.r8(S.gStringVar4 + i)
    if c == 0xFF then break end
    if c >= 0xBB and c <= 0xD4 then out[#out + 1] = string.char(65 + c - 0xBB)
    elseif c >= 0xD5 and c <= 0xEE then out[#out + 1] = string.char(97 + c - 0xD5)
    elseif c >= 0xA1 and c <= 0xAA then out[#out + 1] = string.char(48 + c - 0xA1)
    elseif c == 0xAD then out[#out + 1] = "."
    elseif c == 0xB8 then out[#out + 1] = ","
    else out[#out + 1] = " " end
  end
  return (table.concat(out):gsub("%s+", " "))
end

local SCRIPT_BUF = S.gStringVar4 + 960
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
end
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end

local function count() return F.r8(S.gPartiesCount) end
local function isEgg(i) return (F.r8(S.gParties + i * MON + 19) & 0x04) ~= 0 end
local function clearParty()
  for i = 0, PARTY_SIZE * MON - 1, 4 do F.w32(S.gParties + i, 0) end
  F.w8(S.gPartiesCount, 0)
end
local function createMon(species, level)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = PARTY_SIZE
  le16(b, species); le16(b, level)
  le32(b, 0)
  for _ = 1, 4 do le16(b, 0) end
  b[#b + 1] = 0x02
  runScript(b)
  for _ = 1, 60 do F.idle(2); if F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING then break end end
  F.idle(10)
end
local function task(fn)
  for j = 0, 15 do
    local t = S.gTasks + j * 40
    if F.r8(t + 4) ~= 0 and (F.r32(t) & ~1) == (fn & ~1) then return t end
  end
end
local function giveEgg(species)
  F.dbg(); F.idle(30)
  for _ = 1, 3 do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(50)
  for _ = 1, 3 do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(80)
  local t = task(S.DebugAction_Give_Pokemon_SelectId)
  if t then F.w16(t + 8 + 6, species); F.idle(4); F.press("A", 3); F.idle(40) end
  for _ = 1, 8 do F.press("B", 2); F.idle(20) end
  for _ = 1, 40 do if hasControl() then break end; F.press("B", 2); F.idle(20) end
  return t ~= nil
end

local function partyLevels()
  local t = {}
  for i = 0, count() - 1 do t[#t + 1] = (isEgg(i) and "egg" or tostring(F.r8(S.gParties + i * MON + OFF_LEVEL))) end
  return table.concat(t, ",")
end
local function partyHash()
  local h = count()
  for i = 0, count() * MON - 1, 4 do h = (h * 31 + F.r32(S.gParties + i)) & 0xFFFFFFFF end
  return h
end

local function awaitList(tag)
  for _ = 1, 80 do
    if maxRow() == MENU_LAST then F.idle(10); return true end
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
  F.press("A", 2); F.idle(20)
  return ok
end

local function awaitControl(budget)
  for i = 1, budget or 120 do
    if hasControl() then return true end
    F.press("B", 2); F.idle(20)
  end
  return hasControl()
end

local function scriptWarp(g, n, x, y)
  runScript({ 0x39, g, n, 0xFF, x & 0xFF, x >> 8, y & 0xFF, y >> 8, 0x27, 0x02 })
  for _ = 1, 400 do
    F.idle(4)
    if F.grp() == g and F.mapn() == n and F.ow() then return awaitControl(60) end
  end
  return false
end

-- Opponent A's party follows the player's in gParties.
local function opponentLevels()
  local t = {}
  for i = 0, 3 do
    local lv = F.r8(S.gParties + (PARTY_SIZE + i) * MON + OFF_LEVEL)
    if lv ~= 0 then t[#t + 1] = lv end
  end
  return t
end

-- Talk, pick LITTLE CUP, and follow the room to a refusal or a battle. Returns "refused" with the
-- message seen, or "won" / "battle_stuck".
local function tryRoom(tag)
  forgetMenu()
  F.face("Up"); F.press("A", 2); F.idle(30)
  if not awaitList(tag .. "_menu") then return "nomenu", "" end
  if not chooseRow(ROW_LC) then return "badrow", "" end
  local seen = ""
  for t = 1, 600 do
    if not F.ow() then break end
    local s = text()
    if s:find("LITTLE CUP", 1, true) then seen = s end
    if maxRow() == MENU_LAST then
      F.shot(tag .. "_refused")
      return "refused", seen
    end
    if t % 30 == 0 then F.press("A", 2) else F.idle(1) end
  end
  if F.ow() then return "neither", seen end
  for _ = 1, 400 do if F.battlers() > 0 then break end; F.idle(4) end
  F.idle(60)
  local lv = opponentLevels()
  F.shot(tag .. "_battle")
  for t = 1, 6000 do
    local n = F.battlers()
    for b = 1, n - 1, 2 do F.w16(S.gBattleMons + b * BP_STRIDE + BP_HP, 0) end
    F.w8(S.gBattleOutcome, B_OUTCOME_WON)
    F.press("A", t % 3 == 0 and 2 or 1); F.idle(1)
    if t % 120 == 0 and F.reportCrash(tag .. "_battle") then return "crash", "", lv end
    if F.ow() then break end
  end
  if not F.ow() then return "battle_stuck", "", lv end
  return F.outcome() == B_OUTCOME_WON and "won" or ("outcome" .. F.outcome()), "", lv
end

-- Back to the menu (noting the room's last message), then Bye.
local function leave(tag)
  local said = ""
  for _ = 1, 80 do
    local s = text()
    if s:find("RULESET", 1, true) or s:find("champion", 1, true) then said = s end
    if maxRow() == MENU_LAST then break end
    F.press("A", 2); F.idle(30)
  end
  if maxRow() == MENU_LAST then F.idle(10); chooseRow(ROW_BYE) end
  return awaitControl(120), said
end

local function case(tag, build, expect)
  if ONLY and not tag:find(ONLY, 1, true) then return end
  F.L("== " .. tag .. " ==")
  local ok, err = pcall(function()
    clearParty()
    build()
    local before, levels, n = partyHash(), partyLevels(), count()
    F.L("  party levels " .. levels)
    local bp0 = F.bp()
    local result, seen, opp = tryRoom((tag:gsub("[^%w]+", "_")))
    local back, said = leave(tag)
    F.L(string.format("  result=%s text=%q then %q opponents=%s bp %d -> %d", result, seen or "", said,
      opp and table.concat(opp, ",") or "-", bp0, F.bp()))
    if expect == "refused" then
      F.check(tag .. ": refused", result == "refused", result)
      F.check(tag .. ": the Little Cup rule is shown", seen:find("only Lv5", 1, true) ~= nil, seen)
      F.check(tag .. ": the party is unchanged", partyHash() == before and count() == n, partyLevels())
      F.check(tag .. ": no BP", F.bp() == bp0, F.bp() .. " vs " .. bp0)
    else
      F.check(tag .. ": a sim battle starts and is won", result == "won", result)
      local all5 = opp and #opp == 3
      for _, lv in ipairs(opp or {}) do if lv ~= 5 then all5 = false end end
      F.check(tag .. ": three level 5 opponents", all5, opp and table.concat(opp, ",") or "-")
      F.check(tag .. ": the win pays 2 BP and says so", F.bp() == bp0 + 2 and said:find("2 BATTLE POINTS", 1, true) ~= nil,
        string.format("%d vs %d, %q", F.bp(), bp0, said))
      F.check(tag .. ": the party count is unchanged", count() == n, partyLevels())
    end
    F.check(tag .. ": control returns", back, where())
  end)
  if not ok then F.check(tag .. ": ran without a Lua error", false, tostring(err)) end
end

local function mons(list) return function() for _, m in ipairs(list) do createMon(m[1], m[2]) end end end

F.run(function()
  if not F.check("boots to the hub", F.boot(100)) then F.finish(); return end
  F.w16(F.sb2() + S.SaveBlock2.optionsU16, (F.r16(F.sb2() + S.SaveBlock2.optionsU16) & 0xFFF8) | 3)
  if not F.check("warp to the Battle Net floor", scriptWarp(100, 1, 4, 6)) then F.finish(); return end

  case("Bulbasaur Lv5", mons({ { SP.BULBASAUR, 5 } }), "accepted")
  case("Bulbasaur Lv6", mons({ { SP.BULBASAUR, 6 } }), "refused")
  case("Bulbasaur Lv4", mons({ { SP.BULBASAUR, 4 } }), "refused")
  case("Ivysaur Lv5", mons({ { SP.IVYSAUR, 5 } }), "refused")
  case("Pichu Lv5", mons({ { SP.PICHU, 5 } }), "accepted")
  case("Pikachu Lv5", mons({ { SP.PIKACHU, 5 } }), "refused")
  case("Chansey Lv5", mons({ { SP.CHANSEY, 5 } }), "refused")
  case("Roselia Lv5", mons({ { SP.ROSELIA, 5 } }), "refused")
  case("Azurill Lv5", mons({ { SP.AZURILL, 5 } }), "accepted")
  case("Marill Lv5", mons({ { SP.MARILL, 5 } }), "refused")
  case("Ditto Lv5", mons({ { SP.DITTO, 5 } }), "refused")
  case("Eevee Lv5", mons({ { SP.EEVEE, 5 } }), "accepted")
  case("Flower Crown Eevee Lv5", mons({ { SP.EEVEE_FLOWER_CROWN, 5 } }), "refused")
  case("Bulbasaur and Ivysaur Lv5", mons({ { SP.BULBASAUR, 5 }, { SP.IVYSAUR, 5 } }), "refused")
  case("an Egg alone", function() giveEgg(SP.TOGEPI) end, "refused")
  case("an Egg and Bulbasaur Lv5", function() giveEgg(SP.TOGEPI); createMon(SP.BULBASAUR, 5) end, "accepted")

  F.finish()
end)
