-- Moving a held item onto a Pokemon that holds Mail must be refused.
--
-- A held Mail owns a letter in SaveBlock1.mail, linked from the holder's mail index. The party
-- menu's Item, Move (CursorCb_MoveItem, then CursorCb_MoveItemCallback in src/swsh_party_menu.c)
-- swaps two held items with SetMonData. A Mail holder never offers Move itself (its menu is Mail),
-- but it can be the target. Swapping onto it hands the Mail to a Pokemon with no mail index, so
-- Read looks up mail[255], and leaves the letter linked from a Pokemon that now holds the other
-- item, so its mailbox slot is never freed. Give refuses a Mail holder ("MAIL must be removed
-- before holding an item"), and Move must too.
--
-- Setup gives two Bulbasaur through the debug Give menu; the first holds a Potion. The party
-- menu, Item, Move and the target pick run with real input:
--
--   1. the second holds Orange Mail (letter in mailbox slot 0, linked): refused, nothing moves;
--   2. control, the second holds an Oran Berry: the two items switch.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/PartyMoveItemOntoMail.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "PartyMoveItemOntoMail")

local HUB_GROUP = 100
local PARTY_SIZE = 6
local MON = S.Pokemon.size
local USM_ICO_PARTY = 1
local BULBASAUR = 1
local ITEM_POTION, ITEM_ORAN_BERRY, ITEM_ORANGE_MAIL = 28, 520, 199
local MAIL_SIZE, MON_MAIL, MAIL_NONE = 36, 85, 0xFF

local function party(slot) return S.gParties + slot * MON end
local function mail(i) return F.sb1() + S.SaveBlock1.mail + i * MAIL_SIZE end

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
local function writeWords(a, w)
  local key = F.r32(a) ~ F.r32(a + 4)
  local sum = 0
  for i = 0, 11 do
    sum = (sum + (w[i] & 0xFFFF) + (w[i] >> 16)) & 0xFFFF
    F.w32(a + 32 + i * 4, w[i] ~ key)
  end
  F.w16(a + 28, sum)
end
local function heldItem(a) local w, o = words(a); return (w[o[0]] >> 16) & 0x3FF end
local function setHeldItem(a, item)
  local w, o = words(a)
  w[o[0]] = (w[o[0]] & ~(0x3FF << 16)) | (item << 16)
  writeWords(a, w)
end
local function checksumOk(a)
  local w = words(a)
  local sum = 0
  for i = 0, 11 do sum = sum + (w[i] & 0xFFFF) + (w[i] >> 16) end
  return (sum & 0xFFFF) == F.r16(a + 28)
end

local function bytes(base, size)
  local t = {}
  for i = 0, size - 1 do t[#t + 1] = string.char(F.r8(base + i)) end
  return table.concat(t)
end
local function putBytes(base, value) for i = 1, #value do F.w8(base + i - 1, value:byte(i)) end end
local function letter(seed, item)
  local w = {}
  for i = 0, 8 do w[#w + 1] = string.char((seed + i) & 255, (seed >> 8) & 255) end
  return table.concat(w) .. "PLAYER\255\255\0\0\0\0" .. string.char(BULBASAUR, 0, item & 255, item >> 8, 0, 0)
end

local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end

local function digits(n) n = n - 1; return n // 100, (n // 10) % 10, n % 10 end
local function giveTwo(species, level)
  for _ = 1, 3 do
    for off = 0, PARTY_SIZE * MON - 4, 4 do F.w32(S.gParties + off, 0) end
    F.w8(S.gPartiesCount, 0)
    F.dbg(); F.idle(30); F.bOut(4)
    for _ = 1, 2 do
      F.dbg(); F.sel(3); F.sel(1); F.idle(20)
      F.spin(digits(species)); F.idle(20)
      F.spin(digits(level)); F.idle(60); F.bOut(4)
    end
    if F.r8(S.gPartiesCount) == 2 and checksumOk(party(0)) and checksumOk(party(1)) then return true end
    F.idle(60)
  end
  return false
end

local function inParty() return F.cb2() == (S.CB2_UpdatePartyMenu & ~1) end
local function waitFor(pred, frames)
  for _ = 1, frames do
    if pred() then return true end
    F.idle(2)
  end
  return false
end

local function backToField()
  for _ = 1, 40 do
    if F.ow() then break end
    F.press("B", 2); F.idle(20)
  end
  F.idle(30)
  for _ = 1, 3 do F.press("B", 2); F.idle(20) end
  return F.ow()
end

-- Party menu, slot 0, Item, Move, then slot 1 and A.
local function moveSlot0ItemToSlot1(tag)
  local t = tag:gsub("%W", "_")
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_PARTY) then F.check(tag .. ": the party icon", false); return false end
  F.press("A", 2)
  if not waitFor(inParty, 150) then F.check(tag .. ": the party menu opened", false); return false end
  F.idle(40)
  F.press("A", 2); F.idle(40)          -- action list: Summary | Switch | Item | Follow | Nickname | Cancel
  F.press("Down", 2); F.idle(20)
  F.press("Down", 2); F.idle(20)
  F.shot(t .. "_item_row")
  F.press("A", 2); F.idle(40)          -- Item: Give | Take | Move | Cancel
  F.press("Down", 2); F.idle(20)
  F.press("Down", 2); F.idle(20)
  F.shot(t .. "_move_row")
  F.press("A", 2); F.idle(40)
  F.press("Down", 2); F.idle(30)
  F.shot(t .. "_target")
  F.press("A", 2); F.idle(60)
  F.shot(t .. "_after")
  for _ = 1, 2 do F.press("A", 2); F.idle(30) end
  F.check(tag .. ": no crash screen", not F.reportCrash(tag))
  return true
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  instantText()

  do
    local tag = "Potion onto a Mail holder"
    F.L("== " .. tag .. " ==")
    if not giveTwo(BULBASAUR, 10) then F.check(tag .. ": the debug Give made two Bulbasaur", false) else
      for i = 0, 15 do for b = 0, MAIL_SIZE - 1 do F.w8(mail(i) + b, 0) end end
      local text = letter(0x1234, ITEM_ORANGE_MAIL)
      putBytes(mail(0), text)
      setHeldItem(party(0), ITEM_POTION)
      F.w8(party(0) + MON_MAIL, MAIL_NONE)
      setHeldItem(party(1), ITEM_ORANGE_MAIL)
      F.w8(party(1) + MON_MAIL, 0)
      instantText()
      if moveSlot0ItemToSlot1(tag) then
        F.L(string.format("  after: slot0 held=%d mail=%d  slot1 held=%d mail=%d", heldItem(party(0)),
          F.r8(party(0) + MON_MAIL), heldItem(party(1)), F.r8(party(1) + MON_MAIL)))
        F.check(tag .. ": the first Bulbasaur still holds the Potion",
          heldItem(party(0)) == ITEM_POTION and F.r8(party(0) + MON_MAIL) == MAIL_NONE and checksumOk(party(0)),
          "held=" .. heldItem(party(0)) .. " mail=" .. F.r8(party(0) + MON_MAIL))
        F.check(tag .. ": the second still holds the Orange Mail, linked to its unchanged letter",
          heldItem(party(1)) == ITEM_ORANGE_MAIL and F.r8(party(1) + MON_MAIL) == 0 and bytes(mail(0), MAIL_SIZE) == text
            and checksumOk(party(1)),
          "held=" .. heldItem(party(1)) .. " mail=" .. F.r8(party(1) + MON_MAIL))
      end
    end
    if not backToField() then F.check(tag .. ": back on the field", false, string.format("cb2=%08X", F.cb2())) end
  end

  do
    local tag = "Potion onto a berry holder"
    F.L("== " .. tag .. " ==")
    if not giveTwo(BULBASAUR, 10) then F.check(tag .. ": the debug Give made two Bulbasaur", false) else
      setHeldItem(party(0), ITEM_POTION)
      F.w8(party(0) + MON_MAIL, MAIL_NONE)
      setHeldItem(party(1), ITEM_ORAN_BERRY)
      F.w8(party(1) + MON_MAIL, MAIL_NONE)
      instantText()
      if moveSlot0ItemToSlot1(tag) then
        F.L(string.format("  after: slot0 held=%d slot1 held=%d", heldItem(party(0)), heldItem(party(1))))
        F.check(tag .. ": the items switched", heldItem(party(0)) == ITEM_ORAN_BERRY and heldItem(party(1)) == ITEM_POTION
          and checksumOk(party(0)) and checksumOk(party(1)),
          "held=" .. heldItem(party(0)) .. "," .. heldItem(party(1)))
      end
    end
    if not backToField() then F.check(tag .. ": back on the field", false, string.format("cb2=%08X", F.cb2())) end
  end

  F.finish()
end)
