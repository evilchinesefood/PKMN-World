-- Using a TM from the Bag asks "Teach <move> to a POKeMON?" and, on Yes, keeps that message up over
-- the Bag's in-place party select (SWSH_ITEM_MENU_ACTION_IN_BAG). Cancelling the select with B
-- must take the message down: the item list owns that corner, and a stale message window covered
-- the description, followed the player to other pockets and was cut through by the next screen.
--
-- A debug-made Bulbasaur leads, the TM pocket holds TM01 and the Items pocket a Revive. With real
-- input the suite opens the Bag on the TM, Uses it, answers Yes and presses B, then switches to the
-- Items pocket and starts a Give of the Revive. The message window (ITEMWIN_MESSAGE's template in
-- gWindows) must be up during the select (control) and gone after B and during the Give.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/BagTMCancelMessage.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BagTMCancelMessage")

local HUB_GROUP = 100
local MON = S.Pokemon.size
local USM_ICO_BAG = 2
local POCKET_ITEMS, POCKET_TMS = 0, 2
local BULBASAUR = 1
local ITEM_REVIVE, ITEM_TM01 = 33, 582
local WINDOW_STRIDE, WINDOWS_MAX = 12, 32

local function pocketPtr(p) return F.r32(S.gBagPockets + p * S.BagPocket.stride) end
local function qtyKey() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF end
local function setPocket(p, id, qty)
  local ptr, cap = pocketPtr(p), F.pocketCap(p)
  for s = 0, cap - 1 do F.w16(ptr + s * 4, 0); F.w16(ptr + s * 4 + 2, qtyKey()) end
  F.w16(ptr, id); F.w16(ptr + 2, qty ~ qtyKey())
end

-- The Bag's message window: bg 0 at (2,15), 26x4, base block 367 (sItemWindowTemplates). The
-- main template list carries an identical, always-allocated WIN_MESSAGE, so the item message is
-- up when a second window with that template exists.
local function messageWindowUp()
  local n = 0
  for i = 0, WINDOWS_MAX - 1 do
    local w = S.gWindows + i * WINDOW_STRIDE
    if F.r8(w) == 0 and F.r8(w + 1) == 2 and F.r8(w + 2) == 15 and F.r8(w + 4) == 4
      and F.r16(w + 6) == 367 and F.r32(w + 8) ~= 0 then
      n = n + 1
    end
  end
  return n > 1, n
end

local function inBag() return F.cb2() == (S.CB2_BagMenuRun & ~1) end
local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end

local function giveMon()
  for _ = 1, 3 do
    for off = 0, 6 * MON - 4, 4 do F.w32(S.gParties + off, 0) end
    F.w8(S.gPartiesCount, 0)
    F.dbg(); F.idle(30); F.bOut(4)
    F.dbg(); F.sel(3); F.sel(1); F.idle(20)
    F.spin(0, 0, 0); F.idle(20)
    F.spin(0, 0, 9); F.idle(60); F.bOut(4)
    if F.r8(S.gPartiesCount) == 1 then return true end
    F.idle(60)
  end
  return false
end

local function openBag(pocket)
  F.w8(S.gBagPosition + 5, pocket)
  for p = 0, 4 do
    F.w16(S.gBagPosition + 8 + p * 2, 0)
    F.w16(S.gBagPosition + 18 + p * 2, 0)
  end
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_BAG) then return false end
  F.press("A", 2)
  for _ = 1, 150 do
    if inBag() then F.idle(40); return true end
    F.idle(2)
  end
  return false
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  instantText()
  if not giveMon() then F.check("setup: the debug Give made a Pokemon", false); F.finish(); return end
  setPocket(POCKET_TMS, ITEM_TM01, 1)
  setPocket(POCKET_ITEMS, ITEM_REVIVE, 3)

  if not openBag(POCKET_TMS) then F.check("the bag opened on the TM pocket", false); F.finish(); return end
  F.press("A", 2); F.idle(40)          -- action menu, Use selected
  F.press("A", 2); F.idle(60)          -- Use: "Booted up a TM."
  F.press("A", 2); F.idle(50)          -- "It contained Focus Punch."
  F.press("A", 2); F.idle(50)          -- "Teach Focus Punch to a POKeMON?" Yes/No
  F.shot("teach_prompt")
  F.press("A", 2); F.idle(60)          -- Yes: the party select opens under the prompt
  F.shot("party_select")
  F.L(string.format("  message-template windows during the select: %d", select(2, messageWindowUp())))
  F.check("control: the prompt is up over the party select", messageWindowUp())
  F.press("B", 2); F.idle(60)          -- cancel the select
  F.shot("after_cancel")
  F.check("still in the Bag after cancelling", inBag(), string.format("cb2=%08X", F.cb2()))
  F.L(string.format("  message-template windows after B: %d", select(2, messageWindowUp())))
  F.check("cancelling the TM's party select takes the prompt down", not messageWindowUp())

  F.press("Left", 2); F.idle(30); F.press("Left", 2); F.idle(40)
  F.shot("items_pocket")
  F.check("the Items pocket shows no stale prompt", not messageWindowUp())
  F.press("A", 2); F.idle(40)
  F.press("Right", 2); F.idle(20)
  F.press("A", 2); F.idle(60)          -- Give: party select
  F.shot("give_select")
  F.check("the Revive's Give select shows no stale prompt", not messageWindowUp())
  F.press("B", 2); F.idle(40)
  for _ = 1, 20 do
    if F.ow() then break end
    F.press("B", 2); F.idle(20)
  end
  F.check("back on the field", F.ow())
  F.check("no crash screen", not F.crashScreen())
  F.finish()
end)
