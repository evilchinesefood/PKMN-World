-- The CARD KEY's description must not name Kanto's Silph Co. when Johto's Radio Tower Director gives it.
-- The BASEMENT KEY (Wattson in Hoenn, Petrel in Johto) must not name New Mauville either.
--
-- ITEM_CARD_KEY is one item for both regions: Kanto's ball on Silph Co. 5F and the Director in
-- Goldenrod's Underground Storage. Its description said "A card-type door key used in Silph Co's
-- office.", and OW_SHOW_ITEM_DESCRIPTIONS prints it in the obtain box over the Director's give.
-- Setup reveals the Director (FLAG_HIDE_GOLDENROD_ROCKETS clear, as the Radio Tower takeover leaves
-- it) with the basement grunts already beaten. The walk, the talk, the obtain box and the Bag run
-- with real input.
--   1. The obtain box text (gStringVar1, where ScriptShowItemDescription formats it) names no
--      Silph Co. and reads as a door key.
--   2. The Key Items pocket shows the CARD KEY's description (screenshot).
--   3. With the BASEMENT KEY in the pocket as either give leaves it, the Bag shows its description
--      (screenshot; the Bag formats it into a stack buffer, so the screenshot is the oracle).
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "CardKeyDescription")

local HUB_GROUP = 100
local STORAGE = { 84, 25 }
local CONTEXT_SHUTDOWN = 2
local ITEM_CARD_KEY, ITEM_BASEMENT_KEY = 750, 736
local POCKET_KEY_ITEMS = 4
local USM_ICO_BAG = 2
local FLAG_HIDE_GOLDENROD_ROCKETS = 0x60DD
local JOHTO_TRAINER_FLAG_BYTES = 32

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end
local function clearJohtoFlag(id)
  local o = id - 0x6000
  local a = F.sb3() + S.SaveBlock3.johtoFlags + o // 8
  F.w8(a, F.r8(a) & (~(1 << (o % 8)) & 255))
end

local function decode(addr, max)
  local out = {}
  for i = 0, (max or 200) - 1 do
    local c = F.r8(addr + i)
    if c == 0xFF then break end
    if c == 0x00 then out[#out + 1] = " "
    elseif c >= 0xBB and c <= 0xD4 then out[#out + 1] = string.char(65 + c - 0xBB)
    elseif c >= 0xD5 and c <= 0xEE then out[#out + 1] = string.char(97 + c - 0xD5)
    elseif c >= 0xA1 and c <= 0xAA then out[#out + 1] = string.char(48 + c - 0xA1)
    elseif c == 0xAB then out[#out + 1] = "!"
    elseif c == 0xAD then out[#out + 1] = "."
    elseif c == 0xAE then out[#out + 1] = "-"
    elseif c == 0xB4 then out[#out + 1] = "'"
    elseif c == 0xFE or c == 0xFA or c == 0xFB then out[#out + 1] = " "
    else out[#out + 1] = "~" end
  end
  return table.concat(out)
end

local function holdKeyItem(id)
  local base = F.r32(S.gBagPockets + POCKET_KEY_ITEMS * S.BagPocket.stride)
  for i = 0, F.pocketCap(POCKET_KEY_ITEMS) - 1 do
    if F.r16(base + i * 4) == 0 then
      F.w16(base + i * 4, id)
      F.w16(base + i * 4 + 2, 1 ~ (F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF))
      return F.itemCount(id) == 1
    end
  end
  return false
end

local function inBag() return F.cb2() == (S.CB2_BagMenuRun & ~1) end
local function openKeyItemsOn(slot)
  F.w8(S.gBagPosition + 5, POCKET_KEY_ITEMS)
  F.w16(S.gBagPosition + 8 + POCKET_KEY_ITEMS * 2, slot)
  F.w16(S.gBagPosition + 18 + POCKET_KEY_ITEMS * 2, 0)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_BAG) then return false end
  F.press("A", 2)
  for _ = 1, 150 do
    if inBag() then F.idle(60); return true end
    F.idle(2)
  end
  return false
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  instantText()
  clearJohtoFlag(FLAG_HIDE_GOLDENROD_ROCKETS)
  for i = 0, JOHTO_TRAINER_FLAG_BYTES - 1 do F.w8(F.sb3() + S.SaveBlock3.johtoTrainerFlags + i, 0xFF) end
  F.check("no CARD KEY yet", F.itemCount(ITEM_CARD_KEY) == 0)
  F.check("warp to the Underground Storage", F.warpTo(0, 8, 4, 0, 2, 5, 0, 0, 0, STORAGE[1], STORAGE[2], "storage"), where())
  instantText()
  F.check("walk to the Director", F.route({ { 11, 2 }, { 11, 5 }, { 14, 5 }, { 14, 8 } }, "director"), where())
  F.face("Left")
  F.w8(S.gStringVar1, 0xFF)
  F.press("A", 2)

  local box, shot = "", false
  for i = 1, 3000 do
    if i % 8 == 0 and F.reportCrash("director") then break end
    local t = decode(S.gStringVar1)
    if box == "" and t:find("key", 1, true) then
      box = t; F.L("  obtain box: " .. t)
      F.idle(20); F.shot("obtain_box"); shot = true
    end
    if i > 120 and hasControl() then break end
    joypad.set(i % 40 < 2 and { A = true } or {})
    emu.frameadvance()
  end
  joypad.set({})
  F.check("the Director gave the CARD KEY", F.itemCount(ITEM_CARD_KEY) == 1, "copies=" .. F.itemCount(ITEM_CARD_KEY))
  F.check("the obtain box showed a description", shot and box ~= "", box)
  F.check("the description names no Silph Co.", box ~= "" and not box:find("Silph", 1, true), box)
  F.check("the description reads as a door key", box:find("door", 1, true) ~= nil, box)
  F.check("control back", hasControl(), where())

  local function bagShot(id, tag)
    local slot = F.keyItemSlot(id)
    F.check("open the Bag on the " .. tag, slot >= 0 and openKeyItemsOn(slot), "slot=" .. slot)
    F.shot("bag_" .. tag:gsub("%W", "_"))
    for _ = 1, 20 do
      if F.ow() then break end
      F.press("B", 2); F.idle(20)
    end
    F.check("back on the field from the " .. tag, F.ow())
  end
  bagShot(ITEM_CARD_KEY, "CARD KEY")
  F.check("BASEMENT KEY in the Key Items pocket", holdKeyItem(ITEM_BASEMENT_KEY))
  bagShot(ITEM_BASEMENT_KEY, "BASEMENT KEY")
  F.finish()
end)
