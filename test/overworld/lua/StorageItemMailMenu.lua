-- PC storage, Move Items, A on a party Pokemon that holds Mail.
--
-- Mail cannot be taken, bagged or switched in the PC, so the item menu has no row for a Mail
-- holder. The menu must not open at all. Before the fix it opened with zero rows, and A then ran
-- the first row left over from the previous menu: a stale Give handed the Mail holder the item
-- given last (a copy, so the item was cloned and the letter orphaned), and a stale Give from the
-- Bag replaced the Mail with a Bag item.
--
-- Setup gives three Bulbasaur through the debug menu, puts a Potion on the first and Orange Mail on
-- the second (letter in mailbox slot 0, linked the way GiveMailToMonByItemId leaves it). Opening
-- the PC (debug Access PC), Move Items, the cursor and every menu choice are real input:
--   1. Take the Potion, Give it to the third Bulbasaur, then A, A on the Mail holder.
--   2. Open the first Bulbasaur's Give menu and close it with B, then A, A on the Mail holder.
-- Both times the Mail and its letter must stay put, no item may be copied and the Bag must not open.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/StorageItemMailMenu.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "StorageItemMailMenu")

local PARTY_SIZE, MON = 6, S.Pokemon.size
local BULBASAUR = 1
local ITEM_POTION, ITEM_ORANGE_MAIL = 28, 199
local MAIL_SIZE, MON_MAIL, MAIL_NONE = 36, 85, 0xFF
local PC_MENU_ROWS, PC_MOVE_ITEMS = 5, 3
local AREA_BOX, AREA_PARTY, AREA_TITLE = 0, 1, 2

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
local function giveParty(n, species, level)
  for _ = 1, 3 do
    for off = 0, PARTY_SIZE * MON - 4, 4 do F.w32(S.gParties + off, 0) end
    F.w8(S.gPartiesCount, 0)
    F.dbg(); F.idle(30); F.bOut(4)
    for _ = 1, n do
      F.dbg(); F.sel(3); F.sel(1); F.idle(20)
      F.spin(digits(species)); F.idle(20)
      F.spin(digits(level)); F.idle(60); F.bOut(4)
    end
    local ok = F.r8(S.gPartiesCount) == n
    for i = 0, n - 1 do ok = ok and checksumOk(party(i)) end
    if ok then return true end
    F.idle(60)
  end
  return false
end

local function menuMax() return F.rs8(S.sMenu + S.Menu.maxCursorPos) end
local function pcMenuLive() return F.ow() and menuMax() == PC_MENU_ROWS - 1 end
local function cursorTo(row)
  for _ = 1, 8 do
    if F.mcur() == row then return true end
    F.press(F.mcur() < row and "Down" or "Up", 2); F.idle(12)
  end
  return F.mcur() == row
end
local function openMoveItems()
  if not pcMenuLive() then
    F.w8(S.sMenu + 2, 0); F.w8(S.sMenu + S.Menu.maxCursorPos, 0)
    F.dbg(); F.idle(60)
    F.press("Down", 3); F.idle(16); F.press("A", 3); F.idle(60)
    F.press("A", 3); F.idle(60)
    for _ = 1, 200 do
      if pcMenuLive() then break end
      F.press("A", 2); F.idle(18)
    end
    if not pcMenuLive() then return false end
    F.idle(30)
  end
  cursorTo(PC_MOVE_ITEMS); F.press("A", 2); F.idle(150)
  return not F.ow()
end
-- B, then No at "Continue Box operations?", back to the storage menu.
local function closeToPcMenu()
  for _ = 1, 30 do
    if F.ow() then break end
    F.press("B", 2); F.idle(30)
    F.press("Down", 2); F.idle(12); F.press("A", 2); F.idle(60)
  end
  for _ = 1, 60 do
    if pcMenuLive() then return true end
    F.idle(5)
  end
  return pcMenuLive()
end

local function tap(k) F.press(k, 2); F.idle(14) end
local function area() return F.r8(S.sCursorArea) end
local function cursor() return F.r8(S.sCursorPosition) end
local function toPartySlot(slot)
  for _ = 1, 30 do
    if area() == AREA_PARTY and cursor() == slot then return true end
    if area() == AREA_TITLE then tap("Down")
    elseif area() ~= AREA_PARTY then tap("Left")
    else tap(cursor() < slot and "Down" or "Up") end
  end
  return area() == AREA_PARTY and cursor() == slot
end

local function potionsHeld()
  local n = 0
  for i = 0, 2 do if heldItem(party(i)) == ITEM_POTION then n = n + 1 end end
  return n
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  instantText()
  F.check("setup: the debug Give made three Bulbasaur", giveParty(3, BULBASAUR, 10), "count=" .. F.r8(S.gPartiesCount))
  local text = letter(0x1234, ITEM_ORANGE_MAIL)
  local function seed(firstItem)
    for i = 0, 15 do for b = 0, MAIL_SIZE - 1 do F.w8(mail(i) + b, 0) end end
    putBytes(mail(0), text)
    for i = 0, 2 do F.w8(party(i) + MON_MAIL, MAIL_NONE); setHeldItem(party(i), 0) end
    setHeldItem(party(0), firstItem)
    setHeldItem(party(1), ITEM_ORANGE_MAIL)
    F.w8(party(1) + MON_MAIL, 0)
  end
  seed(ITEM_POTION)
  local bagPotions = F.itemCount(ITEM_POTION)

  local function mailIntact(tag)
    F.check(tag .. ": the second Bulbasaur still holds the Orange Mail, linked to its unchanged letter",
      heldItem(party(1)) == ITEM_ORANGE_MAIL and F.r8(party(1) + MON_MAIL) == 0
        and bytes(mail(0), MAIL_SIZE) == text and checksumOk(party(1)),
      "held=" .. heldItem(party(1)) .. " mail=" .. F.r8(party(1) + MON_MAIL))
  end

  F.check("the Move Items screen opened", openMoveItems())
  local pcCb2 = F.cb2()

  do
    local tag = "after a Give"
    F.check(tag .. ": cursor on the first Bulbasaur", toPartySlot(0))
    tap("A"); F.shot("potion_menu")
    tap("A"); F.idle(30)
    F.check(tag .. ": Take put the Potion in hand", heldItem(party(0)) == 0, "held=" .. heldItem(party(0)))
    F.check(tag .. ": cursor on the third Bulbasaur", toPartySlot(2))
    tap("A"); F.shot("give_menu")
    tap("A"); F.idle(30)
    F.check(tag .. ": Give put the Potion on the third Bulbasaur", heldItem(party(2)) == ITEM_POTION,
      "held=" .. heldItem(party(2)))
    F.check(tag .. ": cursor on the Mail holder", toPartySlot(1))
    tap("A"); F.shot("mail_holder_A")
    tap("A"); F.idle(40); F.shot("mail_holder_AA")
    mailIntact(tag)
    F.check(tag .. ": the Potion was not copied", potionsHeld() == 1 and F.itemCount(ITEM_POTION) == bagPotions,
      "held potions=" .. potionsHeld())
  end

  F.check("back at the storage menu", closeToPcMenu())
  seed(0)
  F.check("the Move Items screen opened again", openMoveItems())
  pcCb2 = F.cb2()

  do
    local tag = "after a closed Give from the Bag"
    F.check(tag .. ": cursor on the first Bulbasaur", toPartySlot(0))
    tap("A"); F.shot("bag_give_menu")
    tap("B"); F.idle(20)
    F.check(tag .. ": cursor on the Mail holder", toPartySlot(1))
    tap("A")
    tap("A"); F.idle(90); F.shot("mail_holder_bag")
    F.check(tag .. ": the Bag did not open", F.cb2() == pcCb2, string.format("cb2=%08X", F.cb2()))
    for _ = 1, 20 do
      if F.cb2() == pcCb2 then break end
      F.press("B", 2); F.idle(30)
    end
    mailIntact(tag)
  end

  F.check("no crash", not F.reportCrash("end"))
  F.finish()
end)
