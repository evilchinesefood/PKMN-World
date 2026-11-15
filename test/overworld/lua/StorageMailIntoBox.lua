-- PC storage, Move Pokemon: a party Pokemon that holds Mail must never reach a box.
--
-- A letter lives in the party's mail slots and is linked from its holder, so the vanilla PC
-- refuses to close the party while a Mail holder is in hand ("Please remove the Mail"). The SwSh
-- PC keeps the party on screen and moves the cursor straight into the box, and nothing produced
-- that refusal any more: a Mail holder could be placed or shifted into a box, leaving its letter
-- orphaned in the mailbox and a Mail item on a box Pokemon with no mail index.
--
-- Setup gives three Bulbasaur through the debug menu; the second holds Orange Mail (letter in
-- mailbox slot 0, linked the way GiveMailToMonByItemId leaves it). Opening the PC (debug Access
-- PC), Move Pokemon, the cursor and every menu choice are real input:
--   1. control: the third Bulbasaur (no Mail) is moved Right into the box and put down with B;
--   2. the Mail holder is picked up with Move and pushed Right, then B is pressed until it is down;
--   3. the boxed Bulbasaur is picked up and Shifted with the Mail holder, which is pushed Right,
--      then put down in an empty party slot.
-- Each Right with the Mail holder in hand must keep the cursor in the party and show the refusal,
-- and the Mail holder must end in the party with its letter still linked.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/StorageMailIntoBox.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "StorageMailIntoBox")

local PARTY_SIZE, MON = 6, S.Pokemon.size
local BOXES, PER_BOX, BOX_MON = 14, 30, S.BoxPokemon.size
local BULBASAUR = 1
local ITEM_ORANGE_MAIL = 199
local MAIL_SIZE, MON_MAIL, MAIL_NONE = 36, 85, 0xFF
local PC_MENU_ROWS, PC_MOVE_MONS = 5, 0
local AREA_BOX, AREA_PARTY, AREA_TITLE = 0, 1, 2
local NO_SPRITE = 64

local function party(slot) return S.gParties + slot * MON end
local function boxSlot(box, slot) return F.r32(S.gPokemonStoragePtr) + 4 + (box * PER_BOX + slot) * BOX_MON end
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
local function openMoveMons()
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
  cursorTo(PC_MOVE_MONS); F.press("A", 2); F.idle(150)
  return not F.ow()
end

local function tap(k) F.press(k, 2); F.idle(14) end
local function area() return F.r8(S.sCursorArea) end
local function cursor() return F.r8(S.sCursorPosition) end
local function holding() return F.r8(S.sIsMonBeingMoved) ~= 0 end
local function messageUp() return F.r8(S.sMessageWindowSpriteIds) ~= NO_SPRITE end
local function goTo(want, pos)
  for _ = 1, 40 do
    if area() == want and cursor() == pos then return true end
    if want == AREA_PARTY then
      if area() == AREA_TITLE then tap("Down")
      elseif area() ~= AREA_PARTY then tap("Left")
      else tap(cursor() < pos and "Down" or "Up") end
    elseif area() == AREA_PARTY then tap("Right")
    elseif area() ~= AREA_BOX then tap("Down")
    else
      local r, c, tr, tc = cursor() // 6, cursor() % 6, pos // 6, pos % 6
      if r ~= tr then tap(r < tr and "Down" or "Up") else tap(c < tc and "Right" or "Left") end
    end
  end
  return area() == want and cursor() == pos
end

local function partySlotOf(pid)
  for i = 0, PARTY_SIZE - 1 do if F.r32(party(i)) == pid and pid ~= 0 then return i end end
  return nil
end
local function boxSlotOf(pid)
  for b = 0, BOXES - 1 do
    for s = 0, PER_BOX - 1 do
      if F.r32(boxSlot(b, s)) == pid then return b, s end
    end
  end
  return nil
end
local function firstEmptyPartySlot()
  for i = 0, PARTY_SIZE - 1 do if F.r32(party(i)) == 0 then return i end end
  return nil
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  instantText()
  F.check("setup: the debug Give made three Bulbasaur", giveParty(3, BULBASAUR, 10), "count=" .. F.r8(S.gPartiesCount))
  for i = 0, 15 do for b = 0, MAIL_SIZE - 1 do F.w8(mail(i) + b, 0) end end
  local text = letter(0x1234, ITEM_ORANGE_MAIL)
  putBytes(mail(0), text)
  for i = 0, 2 do F.w8(party(i) + MON_MAIL, MAIL_NONE) end
  setHeldItem(party(1), ITEM_ORANGE_MAIL)
  F.w8(party(1) + MON_MAIL, 0)
  local mailPid, plainPid = F.r32(party(1)), F.r32(party(2))

  local function mailHolderSafe(tag)
    local slot = partySlotOf(mailPid)
    local b, s = boxSlotOf(mailPid)
    F.check(tag .. ": the Mail holder is in the party, not in a box", slot ~= nil and b == nil,
      string.format("party=%s box=%s/%s", tostring(slot), tostring(b), tostring(s)))
    if slot then
      F.check(tag .. ": it still holds the Orange Mail, linked to its unchanged letter",
        heldItem(party(slot)) == ITEM_ORANGE_MAIL and F.r8(party(slot) + MON_MAIL) == 0
          and bytes(mail(0), MAIL_SIZE) == text,
        "held=" .. heldItem(party(slot)) .. " mail=" .. F.r8(party(slot) + MON_MAIL))
    end
  end
  local function pushRight(tag)
    tap("Right"); F.idle(20)
    F.shot(tag:gsub("%W", "_") .. "_right")
    F.check(tag .. ": Right kept the cursor in the party", area() == AREA_PARTY, "area=" .. area())
    F.check(tag .. ": the Please remove the Mail message is up", messageUp(), "spriteId=" .. F.r8(S.sMessageWindowSpriteIds))
    F.check(tag .. ": the Mail holder is still in hand", holding())
  end

  F.check("the Move Pokemon screen opened", openMoveMons())

  do
    local tag = "control"
    F.check(tag .. ": cursor on the third Bulbasaur", goTo(AREA_PARTY, 2))
    tap("A"); tap("A"); F.idle(20)
    F.check(tag .. ": Move picked it up", holding())
    tap("Right"); F.idle(20)
    F.check(tag .. ": Right moved the cursor into the box", area() == AREA_BOX, "area=" .. area())
    tap("B"); F.idle(40)
    local b, s = boxSlotOf(plainPid)
    F.check(tag .. ": B put it down in the box", not holding() and b == 0, string.format("box=%s/%s", tostring(b), tostring(s)))
  end

  do
    local tag = "Move"
    F.check(tag .. ": cursor on the Mail holder", goTo(AREA_PARTY, partySlotOf(mailPid) or 1))
    tap("A"); tap("A"); F.idle(20)
    F.check(tag .. ": Move picked it up", holding())
    pushRight(tag)
    for _ = 1, 3 do
      if not holding() then break end
      tap("B"); F.idle(40)
    end
    F.shot("move_after_b")
    mailHolderSafe(tag)
  end

  do
    local tag = "Shift"
    local b, s = boxSlotOf(plainPid)
    F.check(tag .. ": cursor on the boxed Bulbasaur", b == 0 and goTo(AREA_BOX, s or 0))
    tap("A"); tap("A"); F.idle(20)
    F.check(tag .. ": Move picked it up", holding())
    F.check(tag .. ": cursor on the Mail holder", goTo(AREA_PARTY, partySlotOf(mailPid) or 1))
    tap("A"); tap("A"); F.idle(40)
    F.check(tag .. ": Shift put the Mail holder in hand", holding() and partySlotOf(plainPid) ~= nil and partySlotOf(mailPid) == nil)
    pushRight(tag)
    tap("B"); F.idle(20)
    local empty = firstEmptyPartySlot()
    if area() == AREA_PARTY and empty then goTo(AREA_PARTY, empty) end
    for _ = 1, 3 do
      if not holding() then break end
      tap("B"); F.idle(40)
    end
    F.shot("shift_after_b")
    mailHolderSafe(tag)
  end

  F.check("no crash", not F.reportCrash("end"))
  F.finish()
end)
