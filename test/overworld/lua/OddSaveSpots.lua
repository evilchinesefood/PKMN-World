-- Save and Continue on spots the other Continue suites do not stand on: the middle of Route 119's
-- bridge on foot and on the Mach Bike, in Cianwood's rain, and on the Sootopolis Gym ice with part
-- of the floor cracked. Each case walks there with real input from a debug warp onto a door,
-- saves from the Start menu, soft resets or cuts the power, and continues. The map, tile, facing,
-- the player's elevation and avatar flags, the playing song, the weather, the follower, the
-- cracked ice metatiles and the ice row vars must come back, and the player must move on: across
-- the bridge, riding, or onto the next ice tile.
--
-- PW_OSS_ONLY=<text> (runner --env) runs only the matching cases.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/OddSaveSpots.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "OddSaveSpots")

local HUB_GROUP = 100
local USM_ICO_SAVE = 7
local SENTINEL = 0xFFFF
local CONTEXT_RUNNING = 0
local SPECIES_LAPRAS = 131
local ITEM_MACH_BIKE = 707
local MUS_CYCLING = 403
local AVATAR_MACH = 1 << 1
local OBJ_EVENT_ID_FOLLOWER = 0xFE
local W_CURR = 0x210
local VAR_ICE_ROWS = { 0x4008, 0x4009, 0x400A }   -- VAR_TEMP_8..A: rows 17..19
local ONLY = os.getenv("PW_OSS_ONLY")

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function warp(g, m, w, tag)
  local gh, gt, go = d(g)
  local mh, mt, mo = d(m)
  local wh, wt, wo = d(w)
  return F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, g, m, tag)
end

local SCRIPT_BUF = S.gStringVar4 + 960
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
end
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function createMon(species, level)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(b, species); le16(b, level)
  le32(b, 0)
  b[#b + 1] = 0x02
  runScript(b); F.idle(20)
  return F.r8(S.gPartiesCount)
end
local function addItem(id, qty)
  runScript({ 0x44, id & 0xFF, id >> 8, qty & 0xFF, qty >> 8, 0x02 }); F.idle(10)
end

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0
    and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function awaitControl(budget)
  for i = 1, budget or 600 do
    if hasControl() then return true end
    if i % 30 == 0 then F.press("B", 2) else F.idle(1) end
  end
  return hasControl()
end

local function avatar() return F.r8(S.gPlayerAvatar) end
local function playerObj() return S.gObjectEvents + F.r8(S.gPlayerAvatar + 5) * S.ObjectEvent.stride end
local function elevation() return F.r8(playerObj() + 0x0B) & 0xF end
local function facing() return F.r8(playerObj() + S.ObjectEvent.facing) & 0xF end
local function follower()
  for i = 0, 15 do
    local o = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(o) & 1) ~= 0 and F.r8(o + 8) == OBJ_EVENT_ID_FOLLOWER then
      return ((F.r8(o + 1) >> 5) & 1) == 1 and "hidden" or "shown"
    end
  end
  return "none"
end
local function playingSong()
  local hdr = F.r32(S.gMPlayInfo_BGM)
  if hdr == 0 then return 0 end
  for id = 0, 900 do
    if F.r32(S.gSongTable + id * 8) == hdr then return id end
  end
  return -1
end
local function settledSong()
  local last, same = -2, 0
  for _ = 1, 600 do
    local s = playingSong()
    if s == last and s > 0 then same = same + 1 else same = 0 end
    if same >= 30 then return s end
    last = s
    F.idle(1)
  end
  return playingSong()
end
local function weather() return F.r8(S.gWeather + W_CURR) end
local function tileAt(x, y)
  local w = F.r32(S.gBackupMapLayout + S.BackupMapLayout.width)
  local p = F.r32(S.gBackupMapLayout + S.BackupMapLayout.map)
  if p < 0x02000000 or w <= 0 then return -1 end
  return F.r16(p + 2 * ((x + 7) + (y + 7) * w)) & 0x3FF
end
local function setFlag(id)
  local a = F.sb1() + S.SaveBlock1.flags + (id // 8)
  F.w8(a, F.r8(a) | (1 << (id % 8)))
end
local function var(id) return F.r16(F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2) end

local function snapshot(extra)
  local x, y = F.pos()
  local s = { grp = F.grp(), map = F.mapn(), x = x, y = y, facing = facing(), elevation = elevation(),
              avatar = avatar() & 0x1F, song = settledSong(), weather = weather(), follower = follower() }
  s.extra = extra and extra() or ""
  return s
end
local function fmt(s)
  return string.format("%d/%d (%d,%d) face=%d elev=%d avatar=%02X song=%d weather=%d follower=%s %s",
    s.grp, s.map, s.x, s.y, s.facing, s.elevation, s.avatar, s.song, s.weather, s.follower, s.extra)
end

local function driveSave()
  F.w16(S.gSaveAttemptStatus, SENTINEL)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_SAVE) then return "noicon" end
  for i = 1, 3000 do
    if F.r16(S.gSaveAttemptStatus) ~= SENTINEL then
      F.idle(30)
      for _ = 1, 6 do F.press("B", 2); F.idle(20) end
      return F.r16(S.gSaveAttemptStatus) == 1 and "done" or "failed"
    end
    if i % 20 == 1 then joypad.set({ A = true }) else joypad.set({}) end
    emu.frameadvance()
  end
  return "timeout"
end
local function softReset()
  for _ = 1, 8 do joypad.set({ A = true, B = true, Start = true, Select = true }); emu.frameadvance() end
  joypad.set({})
end

-- Save, reset, Continue, and compare. The follower is compared after control returns and a beat,
-- since it is respawned beside the player by the field callback.
local function saveContinue(tag, how, extra)
  awaitControl(300)
  local before = snapshot(extra)
  F.shot(tag .. "_before")
  F.check(tag .. ": saved", driveSave() == "done")
  if how == "power" then client.reboot_core() else softReset() end
  F.idle(60)
  local booted = F.boot(nil, true)
  F.check(tag .. ": continued to the field", booted)
  if not booted then return false end
  if F.reportCrash(tag) then F.check(tag .. ": no crash", false); return false end
  F.check(tag .. ": control returns", awaitControl(600))
  F.idle(60)
  local after = snapshot(extra)
  F.shot(tag .. "_after")
  F.L("  before " .. fmt(before))
  F.L("  after  " .. fmt(after))
  F.check(tag .. ": same map, tile and facing", after.grp == before.grp and after.map == before.map
    and after.x == before.x and after.y == before.y and after.facing == before.facing, fmt(after))
  F.check(tag .. ": same elevation", after.elevation == before.elevation,
    after.elevation .. " vs " .. before.elevation)
  F.check(tag .. ": same avatar state", after.avatar == before.avatar,
    string.format("%02X vs %02X", after.avatar, before.avatar))
  F.check(tag .. ": same song", after.song == before.song, after.song .. " vs " .. before.song)
  F.check(tag .. ": same weather", after.weather == before.weather, after.weather .. " vs " .. before.weather)
  F.check(tag .. ": same follower state", after.follower == before.follower,
    after.follower .. " vs " .. before.follower)
  F.check(tag .. ": same puzzle state", after.extra == before.extra, after.extra)
  return true
end

local function case(tag, body)
  if ONLY and not tag:find(ONLY, 1, true) then return end
  F.L("== " .. tag .. " ==")
  local ok, err = pcall(body)
  if not ok then F.check(tag .. ": ran without a Lua error", false, tostring(err)) end
end

-- Route 119: the Weather Institute door is warp 0 at (6,32); the bridge spans x 16..20 on rows 33
-- and 34 over water at elevation 1, between banks at elevation 4. The Aqua grunts and the rival
-- stand on the way until the Weather Institute is cleared; their hide flags say it was.
local FLAG_HIDE_ROUTE_119_TEAM_AQUA, FLAG_HIDE_ROUTE_119_RIVAL_ON_BIKE = 0x37A, 0x39B
local function toBridge(tag)
  setFlag(FLAG_HIDE_ROUTE_119_TEAM_AQUA); setFlag(FLAG_HIDE_ROUTE_119_RIVAL_ON_BIKE)
  if not warp(0, 34, 0, tag) then F.check(tag .. ": warp to Route 119", false); return false end
  awaitControl(600)
  local ok = F.route({ { 6, 34 }, { 15, 34 }, { 18, 34 } }, tag)
  F.check(tag .. ": walked onto the bridge", ok, string.format("(%d,%d)", F.pos()))
  return ok
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  F.check("a Lapras leads", createMon(SPECIES_LAPRAS, 30) == 1)
  addItem(ITEM_MACH_BIKE, 1)

  case("bridge on foot", function()
    if not toBridge("bridge") then return end
    F.check("bridge: standing at elevation 4 over the water", elevation() == 4, "elev=" .. elevation())
    if not saveContinue("bridge", "soft") then return end
    F.check("bridge: the water below stays out of reach", not F.step("Down"), string.format("(%d,%d)", F.pos()))
    F.check("bridge: walks on across", F.route({ { 21, 34 } }, "bridge_across"), string.format("(%d,%d)", F.pos()))
    F.check("bridge: and back over it", F.route({ { 15, 34 } }, "bridge_back"), string.format("(%d,%d)", F.pos()))
  end)

  case("mach bike on the bridge", function()
    if not toBridge("bike") then return end
    F.w16(F.sb1() + S.SaveBlock1.registeredItem, ITEM_MACH_BIKE)
    F.press("Select", 2); F.idle(60)
    F.check("bike: mounted the Mach Bike", (avatar() & AVATAR_MACH) ~= 0, string.format("avatar=%02X", avatar()))
    local song
    for _ = 1, 20 do
      song = playingSong()
      if song == MUS_CYCLING then break end
      F.idle(30)
    end
    F.check("bike: the cycling music took over", song == MUS_CYCLING, "song=" .. tostring(song))
    if not saveContinue("bike", "power") then return end
    F.check("bike: still riding", (avatar() & AVATAR_MACH) ~= 0, string.format("avatar=%02X", avatar()))
    F.check("bike: rides on across", F.route({ { 21, 34 } }, "bike_across"), string.format("(%d,%d)", F.pos()))
    F.press("Select", 2); F.idle(60)
    F.check("bike: gets off", (avatar() & AVATAR_MACH) == 0, string.format("avatar=%02X", avatar()))
  end)

  case("cianwood rain", function()
    if not warp(89, 0, 0, "cianwood") then F.check("warp to Cianwood", false); return end
    awaitControl(600)
    F.step("Down")
    F.check("cianwood: it is raining", weather() ~= 0 and weather() ~= 2, "weather=" .. weather())
    if not saveContinue("cianwood", "soft") then return end
    F.check("cianwood: walks on", F.step("Right") or F.step("Up"), string.format("(%d,%d)", F.pos()))
  end)

  -- Sootopolis Gym 1F: the door is warp 0 at (8,25); the first ice field is x 7..9, rows 17..19.
  case("sootopolis ice mid-puzzle", function()
    if not warp(15, 0, 0, "sootopolis") then F.check("warp to the Sootopolis Gym", false); return end
    awaitControl(600)
    local function ice()
      local t = {}
      for y = 17, 19 do for x = 7, 9 do t[#t + 1] = string.format("%03X", tileAt(x, y)) end end
      return string.format("ice=%s rows=%04X/%04X/%04X", table.concat(t, ","),
        var(VAR_ICE_ROWS[1]), var(VAR_ICE_ROWS[2]), var(VAR_ICE_ROWS[3]))
    end
    local before = ice()
    local ok = F.route({ { 8, 20 }, { 8, 19 }, { 7, 19 }, { 7, 18 } }, "sootopolis")
    F.check("sootopolis: walked onto the ice", ok, string.format("(%d,%d)", F.pos()))
    F.idle(30)
    local cracked = ice()
    F.L("  ice before " .. before .. " / cracked " .. cracked)
    F.check("sootopolis: the ice cracked under the steps", cracked ~= before)
    if not saveContinue("sootopolis", "soft", ice) then return end
    F.check("sootopolis: steps onto the next ice tile", F.step("Right"), string.format("(%d,%d)", F.pos()))
  end)

  F.finish()
end)
