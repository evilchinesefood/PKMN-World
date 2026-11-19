-- Kanto NPCs that promise something on the Trainer Card.
--
-- Celadon Game Corner's POKéMON PRINTER sells a print of the party "on the back of your TRAINER
-- CARD" for 50, and Four Island's sticker man applies HALL OF FAME, EGG and link STICKERS "to the
-- TRAINER CARD". Each is driven with real input, then the card is opened from the Start menu and
-- flipped to its back. A promise is only allowed when the card shows it: the printer may charge
-- only if the back draws the party icons (BG3 tiles 224 to 319), and the sticker man may say a
-- STICKER was applied only if the back draws one (BG3 tiles 320 to 331). The setup seeds the wallet
-- and one Hall of Fame entry; every talk must hand control back with no crash screen.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/KantoTrainerCardExtras.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "KantoTrainerCardExtras")

local KANTO_G, GAME_CORNER_M = 44, 14
local SEVII_G, FOUR_ISLAND_HOUSE2_M = 67, 6
local USM_ICO_TRAINER = 5
local GAME_STAT_ENTERED_HOF = 10
local CONTEXT_RUNNING = 0
local BG3_MAP = 0x06000000 + 31 * 0x800
local BUF = S.gStringVar4 + 900

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function key32() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) end
local function setMoney(v) F.w32(F.sb1() + S.SaveBlock1.money, v ~ key32()) end
local function setGameStat(i, v) F.w32(F.sb1() + S.SaveBlock1.gameStats + i * 4, v ~ key32()) end

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end
local function scriptMenuActive()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    local fn = F.r32(a + S.Task.func) & 0xFFFFFFFE
    if F.r8(a + S.Task.isActive) ~= 0 and (fn == S.Task_HandleYesNoInput or fn == S.Task_HandleMultichoiceInput or fn == S.Task_CallYesOrNoCallback) then return true end
  end
  return false
end

local CH = { [0x00] = " ", [0x1B] = "e", [0xAB] = "!", [0xAC] = "?", [0xAD] = ".", [0xAE] = "-", [0xB0] = "...",
  [0xB4] = "'", [0xB8] = ",", [0xFA] = " ", [0xFB] = " ", [0xFE] = " " }
for i = 0, 25 do CH[0xBB + i] = string.char(65 + i); CH[0xD5 + i] = string.char(97 + i) end
for i = 0, 9 do CH[0xA1 + i] = string.char(48 + i) end
local function shownText()
  local s = {}
  for i = 0, 399 do
    local c = F.r8(S.gStringVar4 + i)
    if c == 0xFF then break end
    s[#s + 1] = CH[c] or "~"
  end
  return table.concat(s)
end
local Seen = { all = {} }
local function noteText()
  local t = shownText()
  if t ~= "" and t ~= Seen.last then Seen.last = t; Seen.all[#Seen.all + 1] = t end
end
local function heard() return table.concat(Seen.all, " | ") end
local function frames(n, keys) for _ = 1, n do joypad.set(keys or {}); emu.frameadvance(); noteText() end end

-- A through messages; at a menu pick row `want`. Ends when control returns.
local function talkThrough(facing, picks, tag)
  Seen.all, Seen.last = {}, nil
  F.w8(S.gStringVar4, 0xFF)
  F.face(facing)
  frames(2, { A = true }); frames(20)
  local p = 1
  for i = 1, 1500 do
    if i % 100 == 0 and F.reportCrash(tag) then return false end
    if hasControl() then frames(30); if hasControl() then return true end end
    if scriptMenuActive() then
      frames(10)
      local want = picks[p] or 1
      for _ = 1, 12 do
        local c = F.mcur()
        if c == want then break end
        frames(2, { [c > want and "Up" or "Down"] = true }); frames(8)
      end
      p = p + 1
      frames(2, { A = true }); frames(30)
    elseif i % 12 == 0 then frames(2, { A = true }) else frames(1) end
  end
  F.shot(tag .. "_stuck")
  return false
end

local function warp(g, n, x, y)
  local bytes = { 0x39, g, n, 0xFF, x & 0xFF, x >> 8, y & 0xFF, y >> 8, 0x27, 0x02 }
  for i, v in ipairs(bytes) do F.w8(BUF + i - 1, v) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, BUF)
  F.w8(S.sGlobalScriptContextStatus, 0)
  for _ = 1, 600 do
    F.idle(4)
    local px, py = F.pos()
    if F.grp() == g and F.mapn() == n and px == x and py == y and hasControl() then F.idle(30); instantText(); return true end
  end
  return false
end

-- Opens the card from the Start menu, flips it with A and counts BG3 cells on the back whose tile
-- falls in [lo, hi]; then closes the card.
local function cardBackTiles(lo, hi, tag)
  F.press("Start", 2); F.idle(40)
  if not F.selectStartIcon(USM_ICO_TRAINER) then F.shot(tag .. "_noicon"); return nil end
  F.press("A", 2)
  for _ = 1, 400 do F.idle(1); if not F.ow() then break end end
  F.idle(150)
  if F.ow() then return nil end
  F.shot(tag .. "_front")
  F.press("A", 2); F.idle(120)
  F.shot(tag .. "_back")
  local n = 0
  for y = 0, 19 do
    for x = 0, 29 do
      local t = F.r16(BG3_MAP + (y * 32 + x) * 2) & 0x3FF
      if t >= lo and t <= hi then n = n + 1 end
    end
  end
  for _ = 1, 3 do
    F.press("B", 2)
    for _ = 1, 200 do F.idle(1); if F.ow() then break end end
    if F.ow() then break end
  end
  F.idle(60)
  for _ = 1, 3 do F.press("B", 2); F.idle(20) end
  return n
end

local function walkable(tag)
  if F.reportCrash(tag) then return false end
  for _, d in ipairs({ { "Left", "Right" }, { "Up", "Down" }, { "Right", "Left" }, { "Down", "Up" } }) do
    if F.step(d[1]) then F.step(d[2]); return true end
  end
  return false
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  instantText()

  F.check("warp to the POKéMON PRINTER", warp(KANTO_G, GAME_CORNER_M, 16, 13), where())
  setMoney(1000)
  local done = talkThrough("Right", { 0, 0 }, "printer")
  F.shot("printer_done")
  local charged = 1000 - F.money()
  F.L("  printer heard: " .. heard())
  F.check("printer: control returns", done and walkable("printer"), where())
  local icons = cardBackTiles(224, 319, "printer_card")
  F.check("printer: the card opens and flips", icons ~= nil)
  F.check("printer: charges only for a print the card shows", charged == 0 or (icons or 0) > 0,
    string.format("charged=%d icon cells=%s", charged, tostring(icons)))

  setGameStat(GAME_STAT_ENTERED_HOF, 1)
  F.check("warp to the sticker man", warp(SEVII_G, FOUR_ISLAND_HOUSE2_M, 4, 5), where())
  done = talkThrough("Up", { 0, 0, 0 }, "sticker")
  F.shot("sticker_done")
  local said = heard()
  F.L("  sticker man heard: " .. said)
  F.check("sticker man: control returns", done and walkable("sticker"), where())
  local stickers = cardBackTiles(320, 331, "sticker_card")
  F.check("sticker man: the card opens and flips", stickers ~= nil)
  F.check("sticker man: no STICKER is applied that the card does not show",
    not said:find("applied to the TRAINER CARD", 1, true) or (stickers or 0) > 0,
    string.format("sticker cells=%s", tostring(stickers)))
  F.finish()
end)
