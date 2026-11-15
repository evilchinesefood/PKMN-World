-- SELECT with one usable registered key item must use it, even when an earlier wheel slot names
-- a key item that has left the Bag.
--
-- The key item wheel (I_KEY_ITEM_WHEEL, UseRegisteredKeyItemOnField in src/swsh_item_menu.c)
-- counts the registered items still in the Bag. With exactly one, it uses that item directly. A
-- registered key item can leave the Bag (Devon Parts handed over, a ticket taken), and its slot
-- stays registered. SELECT must still reach the one that is left.
--
-- Setup warps to Petalburg City, adds a Mach Bike with the additem script command, and writes the
-- wheel slots the way ItemMenu_Register leaves them. SELECT runs with real input:
--
--   1. control: only the Mach Bike registered, in slot 0: SELECT mounts it;
--   2. slot 0 names Devon Parts, which is not in the Bag, slot 1 the Mach Bike: SELECT mounts it.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/SelectWheelStaleSlot.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SelectWheelStaleSlot")

local HUB_GROUP = 100
local PETALBURG = { 0, 0 }
local ITEM_MACH_BIKE, ITEM_DEVON_PARTS = 707, 733
local AVATAR_MACH_BIKE = 1 << 1

local function slotAddr(i) return F.sb1() + S.SaveBlock1.registeredItem + i * 2 end
local function setSlots(items) for i = 0, 3 do F.w16(slotAddr(i), items[i + 1] or 0) end end
local function onBike() return (F.r8(S.gPlayerAvatar) & AVATAR_MACH_BIKE) ~= 0 end

local SCRIPT_BUF = S.gStringVar4 + 960
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, 0)
  F.idle(20)
end
local function addItem(id, qty) runScript({ 0x44, id & 0xFF, id >> 8, qty & 0xFF, qty >> 8, 0x02 }) end

local function dismount()
  for _ = 1, 3 do
    if not onBike() then return true end
    F.press("Select", 2); F.idle(90)
    for _ = 1, 4 do F.press("B", 2); F.idle(20) end
  end
  return not onBike()
end

local function selectAndWatch(tag)
  F.press("Select", 2)
  local mounted = false
  for i = 1, 150 do
    F.idle(1)
    if onBike() then mounted = true; break end
    if i == 60 then F.shot(tag:gsub("%W", "_") .. "_after_select") end
  end
  F.check(tag .. ": no crash screen", not F.reportCrash(tag))
  for _ = 1, 4 do F.press("B", 2); F.idle(20) end
  return mounted
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  if not F.warpTo(0, 0, 0, 0, 0, 0, 0, 0, 0, PETALBURG[1], PETALBURG[2], "petalburg") then
    F.check("warp to Petalburg City", false); F.finish(); return
  end
  F.idle(60)
  addItem(ITEM_MACH_BIKE, 1)
  F.check("setup: a Mach Bike in the Bag and no Devon Parts",
    F.itemCount(ITEM_MACH_BIKE) == 1 and F.itemCount(ITEM_DEVON_PARTS) == 0,
    string.format("bike=%d parts=%d", F.itemCount(ITEM_MACH_BIKE), F.itemCount(ITEM_DEVON_PARTS)))

  do
    local tag = "Only the Mach Bike registered"
    F.L("== " .. tag .. " ==")
    setSlots({ ITEM_MACH_BIKE })
    F.check(tag .. ": SELECT mounts the Mach Bike", selectAndWatch(tag))
    F.check(tag .. ": back on foot", dismount())
  end

  do
    local tag = "Devon Parts gone from slot 0, Mach Bike in slot 1"
    F.L("== " .. tag .. " ==")
    setSlots({ ITEM_DEVON_PARTS, ITEM_MACH_BIKE })
    F.check(tag .. ": SELECT mounts the Mach Bike", selectAndWatch(tag))
    F.check(tag .. ": the Mach Bike is still registered", F.r16(slotAddr(1)) == ITEM_MACH_BIKE, "slot1=" .. F.r16(slotAddr(1)))
    F.check(tag .. ": back on foot", dismount())
  end

  F.finish()
end)
