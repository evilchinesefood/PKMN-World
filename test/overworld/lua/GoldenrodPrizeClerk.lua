-- Goldenrod Game Corner's Pokemon prize clerk, which no suite drove. Without a Coin Case she ran
-- Mauville's coin-desk refusal ("Okay, you wanted some COINS for the games? But you don't have a
-- COIN CASE..."), the wrong counter's line, while her own "Oh? You don't have a COIN CASE." sat
-- unused in the map script.
--
-- With real input the suite asks her for a prize with no Coin Case, then with one: 0 and 119 coins
-- must refuse Abra and keep the coins, exactly 120 must buy it, a NO at "is what you want?" must
-- charge nothing, and with a full party a Dratini must cost 5,500 and go to box 1 with the PC
-- notice. Each line she prints is read from gStringVar4; coins, party and box from RAM.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/GoldenrodPrizeClerk.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "GoldenrodPrizeClerk")

local CONTEXT_SHUTDOWN = 2
local ITEM_COIN_CASE = 718
local SPECIES_ABRA, SPECIES_DRATINI = 63, 147
local CLERK = { 84, 12, 16, 4 }
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
local function additem(id)
  runScript({ 0x44, id & 0xFF, id >> 8, 1, 0, 0x02 })
  for _ = 1, 300 do F.idle(1); if F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN then return end end
end
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

local function key16() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF end
local function coins() return F.r16(F.sb1() + S.SaveBlock1.coins) ~ key16() end
local function setCoins(v) F.w16(F.sb1() + S.SaveBlock1.coins, v ~ key16()) end
local function party() return F.r8(S.gPartiesCount) end

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

local function order(p)
  local o = {}
  for i = 0, 3 do o[i] = F.r8(S.sSubstructOffsets + i * 24 + p % 24) * 3 end
  return o
end
local function monSpecies(a)
  local key = F.r32(a) ~ F.r32(a + 4)
  return (F.r32(a + 32 + order(F.r32(a))[0] * 4) ~ key) & 0x7FF
end
local function boxSpecies(slot) return monSpecies(F.r32(S.gPokemonStoragePtr) + 4 + slot * S.BoxPokemon.size) end

-- Talk to the clerk, pick `row` once the prize list is up, then A through (YES) or B at the
-- "is what you want?" question when `decline`; B always answers the nickname question.
local function ask(tag, row, decline)
  if not F.check(tag .. ": stand before the clerk", warp(CLERK)) then return {} end
  F.face("Up")
  F.w8(S.gStringVar4, 0xFF)
  F.w8(S.sMenu + S.Menu.maxCursorPos, 0)
  F.press("A", 2)
  local said, last, chose = {}, nil, false
  for i = 1, 3000 do
    local s = shownText()
    if s ~= last then last = s; if #s > 0 then said[#said + 1] = s; F.L("  " .. tag .. ": " .. s) end end
    if i > 30 and hasControl() then break end
    local btn = nil
    if row and not chose and F.r8(S.sMenu + S.Menu.maxCursorPos) == 5 then
      F.idle(30)
      for _ = 1, row do F.press("Down", 2); F.idle(10) end
      F.press("A", 2); chose = true
    elseif i % 20 == 0 then
      local l = s:lower()
      btn = (l:find("nickname") or (decline and l:find("what you want"))) and "B" or "A"
    end
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

  local s = ask("no_coin_case", nil, false)
  F.check("no_coin_case: she says there is no Coin Case", saidAny(s, "Oh? You don't have a COIN CASE"), table.concat(s, " | "))
  F.check("no_coin_case: she does not answer as the coin desk", not saidAny(s, "wanted some COINS"), "")
  F.check("no_coin_case: nothing given", party() == 1, "party=" .. party())

  additem(ITEM_COIN_CASE)
  for _, c in ipairs({ 0, 119 }) do
    setCoins(c)
    local tag = "abra_with_" .. c
    s = ask(tag, 0, false)
    F.check(tag .. ": refused for want of coins", saidAny(s, "need more coins"), "")
    F.check(tag .. ": coins kept", coins() == c, "coins=" .. coins())
    F.check(tag .. ": nothing given", party() == 1, "party=" .. party())
  end

  setCoins(120)
  s = ask("abra_with_120", 0, false)
  F.check("abra_with_120: Abra is handed over", saidAny(s, "got Abra"), "")
  F.check("abra_with_120: exactly 120 coins taken", coins() == 0, "coins=" .. coins())
  F.check("abra_with_120: Abra joins the party", party() == 2 and monSpecies(S.gParties + S.Pokemon.size) == SPECIES_ABRA,
    "party=" .. party())

  setCoins(9999)
  s = ask("porygon_declined", 4, true)
  F.check("porygon_declined: no charge for a NO", coins() == 9999, "coins=" .. coins())
  F.check("porygon_declined: nothing given", party() == 2, "party=" .. party())

  for _ = 1, 4 do givePokemon(0, 1, 5, 0, 0, 4) end
  F.check("party is full", party() == 6, "party=" .. party())
  s = ask("dratini_full_party", 3, false)
  F.check("dratini_full_party: 5,500 coins taken", coins() == 4499, "coins=" .. coins())
  F.check("dratini_full_party: the PC notice is shown", saidAny(s, "transferred to"), "")
  F.check("dratini_full_party: Dratini is in box 1", boxSpecies(0) == SPECIES_DRATINI, "species=" .. boxSpecies(0))
  F.finish()
end)
