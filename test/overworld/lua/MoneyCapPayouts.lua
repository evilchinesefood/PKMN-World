-- Money at its 999,999 cap where earlier suites did not reach: the Lake of Rage fisherman's two
-- payouts and Pay Day with an Amulet Coin.
--
-- Fisherman (after the Rocket event, real talk, Yes and party pick): a level 100 Magikarp pays
-- 100,000 and a smaller one 2,000. From 950,000 the big payout must stop at 999,999, and from
-- 999,999 the small one must leave it there; the money box must draw all six digits (screenshot)
-- and close. Pay Day: a level 100 Meowth holding an Amulet Coin uses Pay Day on a wild Pidgey with
-- the pot seeded to 40,000 after the battle starts, from 999,000 and from 999,999. The wallet must
-- end at 999,999, never wrap, and the "picked up" line must print the payout (as trainer prize
-- lines do at the cap).
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/MoneyCapPayouts.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "MoneyCapPayouts")

local PARTY_SIZE, MON = 6, S.Pokemon.size
local SPECIES_BULBASAUR, SPECIES_MAGIKARP = 1, 129
local VAR_MAHOGANY_TOWN_STATE = 0xA091
local HOUSE_G, HOUSE_M = 92, 8
local FISHER_APPROACH = { 5, 5 }   -- below the fisherman at (5,4)
local CONTEXT_SHUTDOWN = 2
local PARTY_MENU_SLOT = 9          -- struct PartyMenu.slotId

local SPECIES_MEOWTH, SPECIES_PIDGEY = 52, 16
local MOVE_PAY_DAY, ITEM_AMULET_COIN = 6, 466
local MAX_MONEY = 999999
local SEED = 40000
local CONTEXT_RUNNING = 0

local function party(slot) return S.gParties + slot * MON end
local function count() return F.r8(S.gPartiesCount) end

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
local function isEgg(a) return (F.r8(a + 19) & 4) ~= 0 end

local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end

local SCRIPT_BUF = S.gStringVar4 + 960
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function runScript(b)
  for i, v in ipairs(b) do F.w8(SCRIPT_BUF + i - 1, v) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, 0)
end

local function digits(n) n = n - 1; return n // 100, (n // 10) % 10, n % 10 end
local function giveMon(sp, level)
  local before = count()
  for _ = 1, 3 do
    F.dbg(); F.sel(3); F.sel(1); F.idle(20)
    F.spin(digits(sp)); F.idle(20)
    F.spin(digits(level)); F.idle(60); F.bOut(4)
    if count() == before + 1 and species(party(before)) == sp then return true end
    F.idle(60)
  end
  return false
end
local function clearParty()
  for off = 0, PARTY_SIZE * MON - 4, 4 do F.w32(S.gParties + off, 0) end
  F.w8(S.gPartiesCount, 0)
end

local function hasMagikarp()
  for i = 0, PARTY_SIZE - 1 do
    if F.r32(party(i)) ~= 0 and not isEgg(party(i)) and species(party(i)) == SPECIES_MAGIKARP then return true end
  end
  return false
end
local function inPartyMenu() return F.cb2() == (S.CB2_UpdatePartyMenu & ~1) end
local function scriptDone() return F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN end

-- Talk to the fisherman, answer Yes, pick party slot `slot`, then clear every message.
local function sell(slot, tag)
  if not F.leg(FISHER_APPROACH[1], FISHER_APPROACH[2]) then F.check(tag .. ": reached the fisherman", false); return end
  F.face("Up"); F.press("A", 2); F.idle(40)
  local picked = false
  for _ = 1, 300 do
    if inPartyMenu() then
      F.idle(30)
      for _ = 1, 10 do
        local s = F.rs8(S.gPartyMenu + PARTY_MENU_SLOT)
        if s == slot then break end
        F.press(s < slot and "Down" or "Up", 2); F.idle(16)
      end
      picked = F.rs8(S.gPartyMenu + PARTY_MENU_SLOT) == slot
      F.press("A", 2); F.idle(90)
      F.shot(tag:gsub("%W", "_") .. "_answer")
    elseif F.ow() and scriptDone() then
      break
    else
      F.press("A", 2); F.idle(30)
    end
  end
  F.idle(30)
  F.check(tag .. ": picked party slot " .. slot, picked)
  F.check(tag .. ": back in control", F.ow() and scriptDone())
end

local function giveMeowth()
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(b, SPECIES_MEOWTH); le16(b, 100)
  le32(b, 1 | (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  le16(b, ITEM_AMULET_COIN)
  le16(b, MOVE_PAY_DAY); le16(b, 0); le16(b, 0); le16(b, 0)
  b[#b + 1] = 0x02
  runScript(b); F.idle(30)
end

local function startWild()
  local b = { 0xB6 }; le16(b, SPECIES_PIDGEY); b[#b + 1] = 2; le16(b, 0); le16(b, 0); b[#b + 1] = 0; le16(b, 0)
  b[#b + 1] = 0xB7; b[#b + 1] = 0x02
  runScript(b)
  for _ = 1, 200 do F.idle(2); if F.cb2() == S.BattleMainCB2 then return true end end
  return false
end

local function actionReady()
  local fn = F.r32(S.gBattlerControllerFuncs) & ~1
  for _, p in ipairs(S.ActionInputFunctions) do if fn == p then return true end end
  return false
end

local function text()
  local t = {}
  for i = 0, 399 do
    local b = F.r8(S.gDisplayedStringBattle + i)
    if b == 255 then break end
    if b >= 161 and b <= 170 then t[#t + 1] = string.char(48 + b - 161)
    elseif b >= 187 and b <= 212 then t[#t + 1] = string.char(65 + b - 187)
    elseif b >= 213 and b <= 238 then t[#t + 1] = string.char(97 + b - 213)
    elseif b == 0 or b == 254 or b == 250 or b == 251 then t[#t + 1] = " " end
  end
  return table.concat(t)
end


local function setMoney(v) F.w32(F.sb1() + S.SaveBlock1.money, v ~ F.r32(F.sb2() + S.SaveBlock2.encryptionKey)) end

local function fisher(level, wallet, want, tag)
  clearParty()
  F.check(tag .. ": setup", giveMon(SPECIES_MAGIKARP, level) and giveMon(SPECIES_BULBASAUR, 20) and count() == 2)
  setMoney(wallet)
  sell(0, tag)
  F.check(tag .. ": the Magikarp was sold", count() == 1 and not hasMagikarp(), "count=" .. count())
  F.check(tag .. ": the wallet ends at " .. want, F.money() == want, wallet .. " -> " .. F.money())
end

local function payday(wallet, tag)
  clearParty()
  giveMeowth()
  F.check(tag .. ": Meowth is the only party member", count() == 1, "party=" .. count())
  setMoney(wallet)
  if not F.check(tag .. ": wild battle starts", startWild()) then return end
  local ready = false
  for _ = 1, 400 do
    if actionReady() then ready = true; break end
    F.press("A", 2); F.idle(10)
  end
  if not F.check(tag .. ": action menu reached", ready) then return end
  F.w16(S.gPaydayMoney, SEED)
  F.press("A", 2); F.idle(12)
  for _ = 1, 200 do if (F.r32(S.gBattlerControllerFuncs) & ~1) == S.HandleInputChooseMove then break end F.idle(1) end
  F.press("A", 2); F.idle(12)
  local printed
  for i = 1, 9000 do
    local n = text():match("picked up%D*(%d+)")
    if n and not printed then printed = tonumber(n); F.shot(tag:gsub("%W", "_") .. "_message") end
    if F.ow() then break end
    if actionReady() then
      -- The wild Pokemon moved first: pick Pay Day again on the next turn.
      F.press("A", 2); F.idle(12)
      for _ = 1, 200 do if (F.r32(S.gBattlerControllerFuncs) & ~1) == S.HandleInputChooseMove then break end F.idle(1) end
      F.press("A", 2); F.idle(12)
    elseif i % 20 == 0 then F.press("A", 2) end
    F.idle(1)
  end
  if not F.ow() then F.shot(tag:gsub("%W", "_") .. "_stuck") end
  F.check(tag .. ": battle returns to the field", F.ow(), string.format("cb2=%08X outcome=%d", F.cb2(), F.outcome()))
  F.check(tag .. ": the wallet stops at 999,999", F.money() == MAX_MONEY, wallet .. " -> " .. F.money())
  -- The hit itself adds 5 x level (500) to the seeded pot before the Amulet Coin doubles it.
  F.check(tag .. ": the line prints the doubled payout", printed == 2 * (SEED + 500), "printed=" .. tostring(printed))
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  instantText()
  F.w16(F.sb3() + S.SaveBlock3.regionVars + (VAR_MAHOGANY_TOWN_STATE - 0xA000) * 2, 14)
  F.check("warp: Lake of Rage fisherman's house", F.warpTo(0, 9, 2, 0, 0, 8, 0, 0, 0, HOUSE_G, HOUSE_M, "house"))
  instantText()
  fisher(100, 950000, MAX_MONEY, "big payout from 950,000")
  fisher(20, MAX_MONEY, MAX_MONEY, "small payout at 999,999")
  fisher(100, MAX_MONEY, MAX_MONEY, "big payout at 999,999")
  payday(999000, "Pay Day from 999,000")
  payday(MAX_MONEY, "Pay Day at 999,999")
  F.finish()
end)
