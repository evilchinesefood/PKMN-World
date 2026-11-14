-- Pay Day payout message against the real wallet delta.
-- gPaydayMoney is a u16 pot capped at 65535, but Cmd_givepaydaymoney multiplies it by the money
-- multiplier (Amulet Coin or Luck Incense, Happy Hour) before paying, so the payout can exceed
-- 65535. The "picked up" line must print the amount actually added to the wallet.
-- Setup: a level 100 Meowth holding an Amulet Coin knows only Pay Day and faces a level 2 wild
-- Pidgey. The pot is seeded to 40000 after the battle starts, standing in for many earlier Pay
-- Day uses in a long battle. Move choice and the post-battle messages use real input.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "PayDayMoneyText")

local SPECIES_MEOWTH, SPECIES_PIDGEY = 52, 16
local MOVE_PAY_DAY, ITEM_AMULET_COIN = 6, 466
local SEED, WALLET = 40000, 1000
local CONTEXT_RUNNING = 0

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

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  giveMeowth()
  F.check("Meowth is the only party member", F.r8(S.gPartiesCount) == 1, "party=" .. F.r8(S.gPartiesCount))
  F.w32(F.sb1() + S.SaveBlock1.money, WALLET ~ F.r32(F.sb2() + S.SaveBlock2.encryptionKey))
  if not F.check("wild battle starts", startWild()) then F.finish(); return end
  local ready = false
  for _ = 1, 400 do
    if actionReady() then ready = true; break end
    F.press("A", 2); F.idle(10)
  end
  if not F.check("action menu reached", ready) then F.finish(); return end
  F.w16(S.gPaydayMoney, SEED)
  F.press("A", 2); F.idle(12)
  for _ = 1, 200 do if (F.r32(S.gBattlerControllerFuncs) & ~1) == S.HandleInputChooseMove then break end F.idle(1) end
  F.press("A", 2); F.idle(12)
  local printed
  for i = 1, 3000 do
    local shown = text()
    local n = shown:match("picked up%D*(%d+)")
    if n and not printed then printed = tonumber(n); F.shot("payday_message") end
    if F.ow() then break end
    if i % 20 == 0 then F.press("A", 2) end
    F.idle(1)
  end
  F.check("battle returns to the field", F.ow())
  local delta = F.money() - WALLET
  F.check("Amulet Coin doubled a payout past the u16 range", delta >= 2 * SEED, "delta=" .. delta)
  F.check("Pay Day message was shown", printed ~= nil)
  F.check("Pay Day message prints the wallet delta", printed == delta, "printed=" .. tostring(printed) .. " delta=" .. delta)
  F.finish()
end)
