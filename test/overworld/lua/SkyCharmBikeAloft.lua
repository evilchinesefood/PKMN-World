-- The Mach Bike and the Acro Bike must refuse to mount while the Sky Charm flight is airborne.
--
-- The Sky Charm refuses to take off from a bike (CanUseOverworldFlight needs the player on foot),
-- but the bike accepted the reverse order. Select over the sea mounted the bike in mid-air: the
-- rider swapped to the cycling sprite on the mount, the cycling theme started and was stored as
-- the saved music, and landing put the player on foot with the cycling theme still playing. It
-- kept playing after battles and menus until the next map change.
--
-- In Olivine City with the Storm Badge (Johto badge 5), the Sky Charm and each bike are given by an injected
-- `additem`; every press is Select with the item registered. Per bike: take off on the pier,
-- fly north over the sea, press Select with the bike (refused: still flying, on foot, same
-- sprite, the map music playing and no saved music), land on the pier, check the music on foot,
-- then mount and dismount the bike on the pier as a control.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/SkyCharmBikeAloft.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SkyCharmBikeAloft")

local HUB_GROUP = 100
local OLIVINE_GROUP, OLIVINE_MAP = 87, 0
local ITEM_SKY_CHARM, ITEM_MACH_BIKE, ITEM_ACRO_BIKE = 891, 707, 708
local FLAG_JOHTO_BADGE_5 = 0x63FC
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local AVATAR_ON_FOOT, AVATAR_MACH_BIKE, AVATAR_ACRO_BIKE = 1 << 0, 1 << 1, 1 << 2
local SAVED_MUSIC = 0x2C
local HEADER_MUSIC = 0x10

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function flying() return F.r8(S.sFlightActive) ~= 0 end
local function avatar() return F.r8(S.gPlayerAvatar) end
local function playerGfx() return F.r16(S.gObjectEvents + F.r8(S.gPlayerAvatar + 5) * S.ObjectEvent.stride + S.ObjectEvent.graphicsId) end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function song()
  local hdr = F.r32(S.gMPlayInfo_BGM)
  if hdr == 0 then return 0 end
  for id = 0, 1000 do if F.r32(S.gSongTable + id * 8) == hdr then return id end end
  return -1
end
local function savedMusic() return F.r16(F.sb1() + SAVED_MUSIC) end
local function mapMusic() return F.r16(S.gMapHeader + HEADER_MUSIC) end
local function where()
  local x, y = F.pos()
  return string.format("(%d,%d) flying=%s avatar=%02X gfx=%d song=%d saved=%d map=%d", x, y, tostring(flying()),
    avatar(), playerGfx(), song(), savedMusic(), mapMusic())
end
local function at(x, y)
  local px, py = F.pos()
  return F.grp() == OLIVINE_GROUP and F.mapn() == OLIVINE_MAP and px == x and py == y
end

local SCRIPT_BUF = S.gStringVar4 + 960
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
  for _ = 1, 200 do
    F.idle(4)
    if hasControl() then break end
  end
  F.idle(30)
end
local function addItem(id) runScript({ 0x44, id & 0xFF, id >> 8, 1, 0, 0x02 }) end

local function warpToCoords(x, y, tag)
  for _ = 1, 4 do
    F.dbg(); F.sel(0); F.sel(1); F.idle(20)
    F.spin(d(OLIVINE_GROUP)); F.spin(d(OLIVINE_MAP))
    F.press("A", 2)
    for _ = 1, 400 do
      F.w8(S.sWarpDestination + 2, 0xFF)
      F.w16(S.sWarpDestination + 4, x)
      F.w16(S.sWarpDestination + 6, y)
      F.idle(1)
      if F.ow() and at(x, y) then
        F.idle(120)
        F.L("  WARP " .. tag .. " ok " .. where())
        return true
      end
    end
    F.bOut(5)
  end
  F.shot(tag .. "_warpfail")
  return false
end

local function move(dir)
  local x0, y0 = F.pos()
  for _ = 1, 30 do
    joypad.set({ [dir] = true }); emu.frameadvance()
    local x, y = F.pos()
    if x ~= x0 or y ~= y0 then F.idle(24); return true end
  end
  F.idle(10)
  return false
end

-- Register the item, press Select and wait for control, dismissing a refusal with B.
local function select(item)
  F.w16(F.sb1() + S.SaveBlock1.registeredItem, item)
  F.press("Select", 2); F.idle(150)
  for _ = 1, 10 do
    if hasControl() then break end
    F.press("B", 2); F.idle(40)
  end
  F.idle(60)
end

local function bikeCase(name, item, bikeFlag)
  F.L("== " .. name .. " ==")
  if flying() then select(ITEM_SKY_CHARM) end
  if not at(19, 66) and not warpToCoords(19, 66, name .. "_pier") then F.check(name .. ": on the pier", false); return end
  local walkSong = song()
  select(ITEM_SKY_CHARM)
  F.check(name .. ": took off", flying(), where())
  move("Up"); move("Left")
  F.check(name .. ": over the sea at (18,65)", flying() and at(18, 65), where())
  local gfx = playerGfx()

  select(item)
  F.shot(name:gsub(" ", "") .. "_aloft")
  F.L("  after Select aloft " .. where())
  F.check(name .. ": refused aloft, still flying on foot",
    flying() and (avatar() & AVATAR_ON_FOOT) ~= 0 and (avatar() & bikeFlag) == 0, where())
  F.check(name .. ": the rider keeps the flight sprite", playerGfx() == gfx, playerGfx() .. " vs " .. gfx)
  F.check(name .. ": the map music still plays aloft", song() == walkSong and savedMusic() == 0, where())

  move("Right")
  select(ITEM_SKY_CHARM)
  F.idle(120)
  F.L("  landed " .. where())
  F.check(name .. ": landed on the pier at (19,65)", not flying() and at(19, 65), where())
  F.check(name .. ": on foot with the map music after landing",
    (avatar() & (AVATAR_MACH_BIKE | AVATAR_ACRO_BIKE)) == 0 and song() == walkSong and savedMusic() == 0, where())

  select(item)
  F.check(name .. ": control, the bike mounts on the pier", (avatar() & bikeFlag) ~= 0 and savedMusic() ~= 0, where())
  select(item)
  F.idle(120)
  F.check(name .. ": control, dismounting restores the map music",
    (avatar() & AVATAR_ON_FOOT) ~= 0 and song() == walkSong and savedMusic() == 0, where())
  move("Down")
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot", false); F.finish(); return end
  if not F.check("warp to the pier", warpToCoords(19, 66, "pier")) then F.finish(); return end
  runScript({ 0x29, FLAG_JOHTO_BADGE_5 & 0xFF, FLAG_JOHTO_BADGE_5 >> 8, 0x02 })
  addItem(ITEM_SKY_CHARM); addItem(ITEM_MACH_BIKE); addItem(ITEM_ACRO_BIKE)
  bikeCase("Mach Bike", ITEM_MACH_BIKE, AVATAR_MACH_BIKE)
  bikeCase("Acro Bike", ITEM_ACRO_BIKE, AVATAR_ACRO_BIKE)
  F.finish()
end)
