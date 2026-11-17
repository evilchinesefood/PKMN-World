-- An item ball walked into with a full pocket, then with room by spilling onto a new slot.
--
-- Sprout Tower 3F's Potion ball (7,16), reached on foot from the 2F stairs (11,16). The Items
-- pocket is filled in RAM: every slot holds an item and the Potion slot holds 999. A on the ball
-- with real input must say the bag is full, leave the ball, its flag and the 999 Potions alone,
-- and give control back. With one slot emptied, the same A must take the Potion: the 999 stack
-- stays, a second stack of 1 appears and the ball goes.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "ItemBallFullPocket")

local HUB_GROUP = 100
local CONTEXT_SHUTDOWN = 2
local REGION_JOHTO = 2
local ITEM_POTION = 28                       -- the ball script's setorcopyvar VAR_0x8000 value
local POCKET_ITEMS = 0
local SPROUT_3F = { g = 78, m = 8, w = 0 }
local BALL = { 7, 16 }

local function key16() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF end
local function pocket(p) return F.r32(S.gBagPockets + p * S.BagPocket.stride), F.pocketCap(p) end
local function setSlot(s, id, n)
  local ptr = pocket(POCKET_ITEMS)
  F.w16(ptr + s * 4, id); F.w16(ptr + s * 4 + 2, n ~ key16())
end
local function stacks(id)
  local ptr, cap = pocket(POCKET_ITEMS)
  local t = {}
  for s = 0, cap - 1 do
    if F.r16(ptr + s * 4) == id then t[#t + 1] = F.r16(ptr + s * 4 + 2) ~ key16() end
  end
  return t
end
local function fmtStacks(t) return "{" .. table.concat(t, ",") .. "}" end

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function backToControl()
  for _ = 1, 80 do
    if hasControl() then return true end
    F.press("B", 2); F.idle(20)
  end
  return hasControl()
end
local function decode(addr, max)
  local out = {}
  for i = 0, (max or 200) - 1 do
    local c = F.r8(addr + i)
    if c == 0xFF then break end
    if c == 0x00 then out[#out + 1] = " "
    elseif c >= 0xBB and c <= 0xD4 then out[#out + 1] = string.char(65 + c - 0xBB)
    elseif c >= 0xD5 and c <= 0xEE then out[#out + 1] = string.char(97 + c - 0xD5)
    elseif c == 0xAB then out[#out + 1] = "!"
    elseif c == 0xAD then out[#out + 1] = "."
    elseif c == 0xB4 then out[#out + 1] = "'"
    elseif c == 0xFE or c == 0xFA or c == 0xFB then out[#out + 1] = " "
    else out[#out + 1] = "~" end
  end
  return table.concat(out)
end
local function objectAt(x, y)
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.rs16(b + 0x10) == x + 7 and F.rs16(b + 0x12) == y + 7 then return true end
  end
  return false
end
local function interact(tag)
  F.w8(S.gStringVar4, 0xFF)
  local seen, last = {}, nil
  F.press("A", 2)
  for i = 1, 900 do
    local t = decode(S.gStringVar4)
    if t ~= last and t ~= "" then seen[#seen + 1] = t; last = t; F.L("  " .. tag .. ": " .. t) end
    if i > 30 and hasControl() then break end
    if i % 8 == 0 and F.reportCrash(tag) then break end
    joypad.set((i % 30 < 2) and { A = true } or {})
    emu.frameadvance()
  end
  joypad.set({})
  F.idle(20)
  F.shot(tag)
  return table.concat(seen, " | ")
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  local opt = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(opt, (F.r16(opt) & ~7) | 3)
  F.check("warp to Sprout Tower 3F", F.warpTo(0, 7, 8, 0, 0, 8, 0, 0, 0, SPROUT_3F.g, SPROUT_3F.m, "sprout3f"), where())
  F.w32(S.gCurrentRegion, REGION_JOHTO)
  F.w8(F.sb2() + S.SaveBlock2.currentRegion, REGION_JOHTO)
  F.check("walk beside the Potion ball", F.leg(BALL[1] + 1, BALL[2]), where())
  F.face("Left")
  F.check("the ball is there", objectAt(BALL[1], BALL[2]), where())

  local _, cap = pocket(POCKET_ITEMS)
  setSlot(0, ITEM_POTION, 999)
  for s = 1, cap - 1 do setSlot(s, ITEM_POTION + s, 1) end
  F.check("the Items pocket is full with 999 Potions", #stacks(ITEM_POTION) == 1 and stacks(ITEM_POTION)[1] == 999,
    string.format("cap=%d potions=%s", cap, fmtStacks(stacks(ITEM_POTION))))

  local said = interact("full")
  F.check("full: the game says the bag is full", said:find("full", 1, true) ~= nil, said)
  F.check("full: control returns", backToControl())
  F.check("full: the ball stays", objectAt(BALL[1], BALL[2]), where())
  F.check("full: still one stack of 999 Potions", fmtStacks(stacks(ITEM_POTION)) == "{999}", fmtStacks(stacks(ITEM_POTION)))

  setSlot(cap - 1, 0, 0)
  F.face("Left")
  said = interact("room")
  F.check("room: control returns", backToControl())
  F.check("room: the ball is taken", not objectAt(BALL[1], BALL[2]), said)
  F.check("room: 999 stays and a new stack of 1 appears", fmtStacks(stacks(ITEM_POTION)) == "{999,1}",
    fmtStacks(stacks(ITEM_POTION)))
  F.check("room: the player walks", F.step("Right"))
  F.finish()
end)
