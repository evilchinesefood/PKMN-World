-- Checking a Mail item from the Bag must open the blank letter and come back without a crash.
--
-- The Bag's Check action on a Mail item runs CB2_CheckMail (src/item_use.c), which hands
-- ReadMail a letter to show. ReadMail keeps the pointer for the life of the screen and reads the
-- letter's species on later frames (the mon icon step, and the exit). Each case puts one Mail in
-- the Items pocket, opens the Bag with real input, picks Check, holds the letter open, closes it
-- with B, and requires: no crash screen at any point, the Bag back with the Mail still in it,
-- and the field back.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/BagCheckMail.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BagCheckMail")

local HUB_GROUP = 100
local USM_ICO_BAG = 2
local POCKET_ITEMS = 0
local MAILS = {
  { "Orange Mail", 199 }, { "Harbor Mail", 200 }, { "Bead Mail", 205 }, { "Dream Mail", 208 },
  { "Retro Mail", 210 },
}

local function pocketPtr(p) return F.r32(S.gBagPockets + p * S.BagPocket.stride) end
local function qtyKey() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF end
local function countItem(id)
  local n, ptr, cap = 0, pocketPtr(POCKET_ITEMS), F.pocketCap(POCKET_ITEMS)
  for s = 0, cap - 1 do
    if F.r16(ptr + s * 4) == id then n = n + (F.r16(ptr + s * 4 + 2) ~ qtyKey()) end
  end
  return n
end
local function setPocket(p, id, qty)
  local ptr, cap = pocketPtr(p), F.pocketCap(p)
  for s = 0, cap - 1 do F.w16(ptr + s * 4, 0); F.w16(ptr + s * 4 + 2, qtyKey()) end
  if qty > 0 then F.w16(ptr, id); F.w16(ptr + 2, qty ~ qtyKey()) end
end

local function inBag() return F.cb2() == (S.CB2_BagMenuRun & ~1) end
local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end

local function openBagOnFirstItem()
  F.w8(S.gBagPosition + 5, POCKET_ITEMS)
  F.w16(S.gBagPosition + 8 + POCKET_ITEMS * 2, 0)
  F.w16(S.gBagPosition + 18 + POCKET_ITEMS * 2, 0)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_BAG) then return false end
  F.press("A", 2)
  for _ = 1, 150 do
    if inBag() then return true end
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
  return F.ow()
end

-- Advance `n` frames with `keys` held for the first two, checking for a crash screen throughout.
local function run(tag, n, keys)
  for i = 1, n do
    if i % 4 == 0 and F.reportCrash(tag) then joypad.set({}); return false end
    joypad.set((i <= 2 and keys) or {})
    emu.frameadvance()
  end
  return true
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  instantText()

  for _, m in ipairs(MAILS) do
    local tag, id = "Check " .. m[1], m[2]
    F.L("== " .. tag .. " ==")
    setPocket(POCKET_ITEMS, id, 1)
    if not openBagOnFirstItem() then
      F.check(tag .. ": the bag opened", false)
    else
      local ok = run(tag, 30, nil)
        and run(tag, 40, { A = true })     -- action menu: Check | Give / Toss | Cancel
        and run(tag, 240, { A = true })    -- Check: the letter opens
      if ok then F.shot(tag:gsub("%W", "_") .. "_open") end
      local left = false
      for _ = 1, 6 do
        if not ok or inBag() then break end
        ok = run(tag, 90, { B = true })
        left = inBag()
      end
      F.check(tag .. ": no crash screen while the letter was open", ok)
      F.check(tag .. ": B closed the letter back to the Bag", ok and left, string.format("cb2=%08X", F.cb2()))
      F.check(tag .. ": the Mail is still in the Bag", countItem(id) == 1, "count=" .. countItem(id))
    end
    if not backToField() then
      for _ = 1, 4 do joypad.set({ Start = true }); emu.frameadvance(); joypad.set({}); F.idle(20) end
      F.check(tag .. ": back on the field", backToField(), string.format("cb2=%08X", F.cb2()))
    end
  end

  F.finish()
end)
