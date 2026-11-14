-- Start, and Select with each field item registered, pressed on every frame of a ledge jump and
-- of walking through a door.
-- The player stands north of Route 102's ledge and holds Down until the jump starts; on frame k the key
-- is pressed once, the menu or prompt it opens is backed out with B, and the run waits for
-- control. Each run must land on a walkable tile north or south of the ledge (never on the
-- ledge row), with the player object on the saved tile, controls unlocked, no script running,
-- no crash, and one step south working afterwards when the player is still north.
-- Covered: the Mach and Acro Bikes (getting on mid-jump), the Hub Pass (confirm declined),
-- the Sky Charm (takeoff mid-jump), and Start. Setup uses a script warp, a script giveitem and
-- RAM writes for the registered item and a badge; the jumps use real input.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "LedgeSelectStress")

local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local ROUTE102 = { 0, 17 }
local NORTH, LEDGE_Y, SOUTH = { 21, 5 }, 6, { 21, 7 }
local ITEM_MACH_BIKE, ITEM_ACRO_BIKE, ITEM_SKY_CHARM, ITEM_HUB_RETURN = 707, 708, 891, 893
local FLAG_BADGE06_GET = 0x948 + 0xC
local ONLY = os.getenv and os.getenv("PW_LEDGE_ONLY") or nil
local OFFSETS = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 20, 22, 24, 26, 28, 32, 36 }

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function flag(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + (id // 8), 1 << (id % 8)
  F.w8(a, on and (F.r8(a) | m) or (F.r8(a) & ~m & 0xFF))
end

local SCRIPT_BUF = S.gStringVar4 + 960
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
end
local function settle(budget, tag)
  for i = 1, budget or 400 do
    if F.reportCrash(tag or "settle") then return false end
    if hasControl() then F.idle(20); if hasControl() then return true end end
    if i % 3 == 0 then F.press("B", 2) else F.idle(2) end
  end
  return false
end
local function warp(g, n, x, y)
  local b = { 0x39, g, n, 0xFF }
  le16(b, x); le16(b, y)
  b[#b + 1] = 0x27; b[#b + 1] = 0x02
  runScript(b)
  for _ = 1, 400 do
    F.idle(4)
    if F.reportCrash("warp") then return false end
    if F.grp() == g and F.mapn() == n and F.ow() then return settle() end
  end
  return false
end
local function addItem(id)
  local b = { 0x44 }; le16(b, id); le16(b, 1); b[#b + 1] = 0x02
  runScript(b); F.idle(10); settle()
end

local function avatarFlags() return F.r8(S.gPlayerAvatar) end
local function flying() return F.r8(S.sFlightActive) ~= 0 end
local function playerObj()
  local id = F.r8(S.gPlayerAvatar + 5)
  local a = S.gObjectEvents + id * 0x24
  return F.rs16(a + 0x10) - 7, F.rs16(a + 0x12) - 7
end
local function where()
  local x, y = F.pos()
  local ox, oy = playerObj()
  return string.format("%d/%d (%d,%d) obj=(%d,%d) avatar=%02X flying=%s lock=%d ctx=%d", F.grp(), F.mapn(), x, y,
    ox, oy, avatarFlags(), tostring(flying()), F.r8(S.sLockFieldControls), F.r8(S.sGlobalScriptContextStatus))
end

-- Back to the north tile on foot: Select gets off a bike, and the warp ends a flight.
local function reset()
  if (avatarFlags() & 6) ~= 0 then F.press("Select", 2); settle() end
  if not warp(ROUTE102[1], ROUTE102[2], NORTH[1], NORTH[2]) then return false end
  local x, y = F.pos()
  return x == NORTH[1] and y == NORTH[2] and (avatarFlags() & 1) == 1
end

local function jump(key, k)
  for i = 0, 60 do
    local _, y = F.pos()
    local t = { Down = y == NORTH[2] or nil }
    if i == k then t[key] = true end
    joypad.set(t)
    emu.frameadvance()
    if F.reportCrash("jump") then return false end
  end
  joypad.set({})
  emu.frameadvance()
  return true
end

local function run(name, key, k)
  local tag = string.format("%s f%d", name, k)
  if not reset() then F.check(tag .. ": reset to the ledge", false, where()); return end
  if not jump(key, k) then F.check(tag .. ": no crash", false, where()); return end
  local ok = settle(900, tag)
  F.check(tag .. ": control returns", ok, where())
  if not ok then F.shot(tag:gsub("%W", "_")); return end
  local x, y = F.pos()
  local ox, oy = playerObj()
  F.check(tag .. ": still on Route 102", F.grp() == ROUTE102[1] and F.mapn() == ROUTE102[2], where())
  if flying() then
    -- A takeoff before the jump hovers over the ledge, which a flight may cross but not land on;
    -- one after the landing stays on the south tile. No takeoff may happen in the air.
    F.check(tag .. ": a flight begins only on the ground", x == NORTH[1]
      and (y == NORTH[2] or y == SOUTH[2] or (y == LEDGE_Y and k == 0)), where())
    F.check(tag .. ": object on the saved tile", ox == x and oy == y, where())
    return
  end
  F.check(tag .. ": not left on the ledge row", y ~= LEDGE_Y and x == NORTH[1]
    and (y == NORTH[2] or y == SOUTH[2]), where())
  F.check(tag .. ": object on the saved tile", ox == x and oy == y, where())
  if y == NORTH[2] then
    for _ = 1, 50 do
      local _, yy = F.pos()
      joypad.set({ Down = yy == NORTH[2] or nil })
      emu.frameadvance()
    end
    joypad.set({})
    local landed = settle(300, tag .. "_retry")
    local _, y2 = F.pos()
    F.check(tag .. ": the jump still works afterwards", landed and y2 == SOUTH[2], where())
  end
end

-- The same keys on every frame of walking into Petalburg's west house: before the door opens,
-- while it opens, during the walk in and the fade. The player must end up either outside on the
-- approach tile or inside on the house's entry tile, with control and a matching object.
local PETALBURG, HOUSE1 = { 0, 0 }, { 8, 2 }
local APPROACH, DOOR, ENTRY = { 10, 20 }, { 10, 19 }, { 3, 8 }
local DOOR_OFFSETS = { 0, 1, 2, 3, 4, 6, 8, 10, 12, 14, 16, 18, 20, 24, 28, 32, 36, 40, 44, 48, 56, 64, 72, 80 }

local function door(name, key, k)
  local tag = string.format("%s door f%d", name, k)
  if (avatarFlags() & 6) ~= 0 then F.press("Select", 2); settle() end
  if not warp(PETALBURG[1], PETALBURG[2], APPROACH[1], APPROACH[2]) then
    F.check(tag .. ": reset to the door", false, where()); return
  end
  for i = 0, 120 do
    local x, y = F.pos()
    local t = { Up = (F.grp() == PETALBURG[1] and F.mapn() == PETALBURG[2] and y == APPROACH[2]) or nil }
    if i == k then t[key] = true end
    joypad.set(t)
    emu.frameadvance()
    if F.reportCrash(tag) then F.check(tag .. ": no crash", false, where()); return end
  end
  joypad.set({})
  local ok = settle(900, tag)
  F.check(tag .. ": control returns", ok, where())
  if not ok then F.shot(tag:gsub("%W", "_")); return end
  local x, y = F.pos()
  local ox, oy = playerObj()
  local outside = F.grp() == PETALBURG[1] and F.mapn() == PETALBURG[2] and x == APPROACH[1] and y == APPROACH[2]
  local inside = F.grp() == HOUSE1[1] and F.mapn() == HOUSE1[2] and x == ENTRY[1] and y == ENTRY[2]
  F.check(tag .. ": outside on the approach or inside on the entry", outside or inside or (flying() and k == 0), where())
  F.check(tag .. ": object on the saved tile", ox == x and oy == y, where())
end

local CASES = {
  { name = "Start", key = "Start" },
  { name = "Mach Bike", key = "Select", item = ITEM_MACH_BIKE },
  { name = "Acro Bike", key = "Select", item = ITEM_ACRO_BIKE },
  { name = "Hub Pass", key = "Select", item = ITEM_HUB_RETURN },
  { name = "Sky Charm", key = "Select", item = ITEM_SKY_CHARM },
}

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  F.dbg(); F.idle(40); F.sel(2); F.idle(40)
  for _ = 1, 9 do F.press("Down", 2); F.idle(12) end
  F.press("A", 2); F.idle(180); F.bOut(6); F.idle(60)
  F.check("setup party", F.r8(S.gPartiesCount) > 0, "n=" .. F.r8(S.gPartiesCount))
  if not F.check("warp to Route 102", warp(ROUTE102[1], ROUTE102[2], NORTH[1], NORTH[2]), where()) then
    F.finish(); return
  end
  flag(FLAG_BADGE06_GET, true)
  for _, c in ipairs(CASES) do if c.item then addItem(c.item) end end
  for _, c in ipairs(CASES) do
    if not ONLY or c.name:find(ONLY, 1, true) then
      if c.item then F.w16(F.sb1() + S.SaveBlock1.registeredItem, c.item) end
      for _, k in ipairs(OFFSETS) do run(c.name, c.key, k) end
      for _, k in ipairs(DOOR_OFFSETS) do door(c.name, c.key, k) end
    end
  end
  F.finish()
end)
