-- Save and Continue on spots the other Continue suites do not stand on: the middle of Route 119's
-- bridge on foot and on the Mach Bike, in Cianwood's rain, and on the Sootopolis Gym ice with part
-- of the floor cracked. Each case walks there with real input from a debug warp onto a door,
-- saves from the Start menu, soft resets or cuts the power, and continues. The map, tile, facing,
-- the player's elevation and avatar flags, the playing song, the weather, the follower, the
-- cracked ice metatiles and the ice row vars must come back, and the player must move on: across
-- the bridge, riding, or onto the next ice tile.
--
-- Later cases: the landing tile of a Route 2 ledge saved while the follower is still on the ledge
-- top behind the player; Route 113's ash with the walked grass cleared; Route 111's desert sandstorm
-- entered through its trigger; Sevii fog in the Lost Cave; the Trainer Hill lobby; Mahogany Gym's
-- ice at rest against a wall; two saves in a row and seeded mashes of the save Yes/No and
-- overwrite prompts; and a soft reset inside the Bug-Catching Contest, whose Start menu offers no
-- SAVE, back to the save made in the gate.
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
local ITEM_GO_GOGGLES, ITEM_SAFARI_BALL = 734, 23
local MUS_DESERT = 409
local WEATHER_FOG_HORIZONTAL, WEATHER_VOLCANIC_ASH, WEATHER_SANDSTORM = 6, 7, 8
local SPECIES_CATERPIE, SPECIES_RATTATA = 10, 19
local REGION_JOHTO = 2
local FLAG_SYS_POKEMON_GET = 0x948
local FLAG_SYS_BUG_CONTEST_MODE = 0x948 + 0x21
local VAR_BUG_CONTEST_STATE = 0xA080 + 0x0E

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
local function region() return F.r32(S.gCurrentRegion) end
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
local function flag(id) return (F.r8(F.sb1() + S.SaveBlock1.flags + (id // 8)) >> (id % 8)) & 1 == 1 end
local function followerXY()
  for i = 0, 15 do
    local o = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(o) & 1) ~= 0 and F.r8(o + 8) == OBJ_EVENT_ID_FOLLOWER then
      return F.rs16(o + 0x10) - 7, F.rs16(o + 0x12) - 7
    end
  end
end
local function setMoney(v) F.w32(F.sb1() + S.SaveBlock1.money, v ~ F.r32(F.sb2() + S.SaveBlock2.encryptionKey)) end
local function partyHash()
  local n = F.r8(S.gPartiesCount)
  local h = n
  for i = 0, n * S.Pokemon.size - 1, 4 do h = (h * 31 + F.r32(S.gParties + i)) & 0xFFFFFFFF end
  return h
end
local function at() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end

local function snapshot(extra, quick)
  local x, y = F.pos()
  local s = { grp = F.grp(), map = F.mapn(), x = x, y = y, facing = facing(), elevation = elevation(),
              avatar = avatar() & 0x1F, song = quick and playingSong() or settledSong(), weather = weather(),
              follower = follower(), region = region() }
  s.extra = extra and extra() or ""
  return s
end
local function fmt(s)
  return string.format("%d/%d (%d,%d) face=%d elev=%d avatar=%02X song=%d weather=%d follower=%s region=%d %s",
    s.grp, s.map, s.x, s.y, s.facing, s.elevation, s.avatar, s.song, s.weather, s.follower, s.region, s.extra)
end

-- Start is read only once the player stands still, so press it every other frame until the menu
-- has locked the field.
local function openStart()
  for _ = 1, 60 do
    F.press("Start", 1); F.idle(1)
    if F.r8(S.sLockFieldControls) ~= 0 then F.idle(60); return true end
  end
  return false
end
local function usmIcons()
  local p = F.r32(S.sUsmState)
  local t = {}
  if p < 0x02000000 or p >= 0x02040000 then return t end
  for i = 0, math.min(F.r8(p + 23), 12) - 1 do t[F.r8(p + 11 + i)] = true end
  return t
end

local function driveSave(onOpen)
  F.w16(S.gSaveAttemptStatus, SENTINEL)
  if not openStart() then return "nomenu" end
  if onOpen then onOpen() end
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
-- since it is respawned beside the player by the field callback. A quick save opens the menu on the
-- first frame the player can act and takes the snapshot with the menu open, so whatever was still
-- moving (a follower finishing a jump) is saved mid-movement.
local function saveContinue(tag, how, extra, quick)
  local before
  if not quick then
    awaitControl(300)
    before = snapshot(extra)
    F.shot(tag .. "_before")
  end
  local saved = driveSave(quick and function() before = snapshot(extra, true); F.shot(tag .. "_before") end)
  F.check(tag .. ": saved", saved == "done", saved)
  if not before then return false end
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
  F.check(tag .. ": same region", after.region == before.region, after.region .. " vs " .. before.region)
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

  -- Route 2: the Viridian Forest south gate is warp 2 at (5,51) and the ledge row is y 55. Start is
  -- pressed from the frame the player lands, so the follower is saved on the ledge top, two tiles
  -- back, before it jumps.
  case("ledge landing", function()
    if not warp(37, 20, 2, "ledge") then F.check("ledge: warp to Route 2", false); return end
    awaitControl(600)
    F.check("ledge: walked to the ledge", F.route({ { 5, 54 } }, "ledge"), at())
    F.idle(30)
    F.check("ledge: jumped the ledge", F.step("Down"), at())
    if not saveContinue("ledge", "soft", function()
      local fx, fy = followerXY()
      local px, py = F.pos()
      F.L(string.format("  player (%d,%d) follower (%s,%s)", px, py, tostring(fx), tostring(fy)))
      return ""
    end, true) then return end
    F.check("ledge: standing on the landing tile", select(2, F.pos()) == 56, at())
    F.check("ledge: the ledge stays one-way", not F.step("Up"), at())
    F.check("ledge: walks on", F.step("Down") and F.step("Down"), at())
    F.idle(40)
    local px, py = F.pos()
    local fx, fy = followerXY()
    F.check("ledge: the follower walks right behind", fx ~= nil and math.abs(fx - px) + math.abs(fy - py) == 1,
      string.format("player (%d,%d) follower (%s,%s)", px, py, tostring(fx), tostring(fy)))
  end)

  -- Route 113: the Glass Workshop door is warp 0 at (33,5); ash grass starts at x 36 on row 6.
  case("ash grass", function()
    if not warp(0, 28, 0, "ash") then F.check("ash: warp to Route 113", false); return end
    awaitControl(600)
    local function row()
      local t = {}
      for x = 35, 40 do t[#t + 1] = string.format("%03X", tileAt(x, 6)) end
      return "row6=" .. table.concat(t, ",")
    end
    local fresh = row()
    F.check("ash: walked into the ash", F.route({ { 38, 6 } }, "ash"), at())
    F.idle(60)
    local walked = row()
    F.L("  ash before " .. fresh .. " / walked " .. walked)
    F.check("ash: volcanic ash is falling", weather() == WEATHER_VOLCANIC_ASH, "weather=" .. weather())
    F.check("ash: the walked grass lost its ash", walked ~= fresh)
    if not saveContinue("ash", "power", row) then return end
    local t0 = tileAt(39, 6)
    F.check("ash: walks on", F.step("Right"), at())
    F.idle(60)
    F.check("ash: the next step still clears the ash", tileAt(39, 6) ~= t0,
      string.format("%03X -> %03X", t0, tileAt(39, 6)))
  end)

  -- Route 111: the Mirage Tower entrance is warp 3 at (19,58), inside the desert; the trigger at
  -- (14,61) wants the Go-Goggles and the one at (14,62) starts the desert music.
  case("desert sandstorm", function()
    addItem(ITEM_GO_GOGGLES, 1)
    if not warp(0, 26, 3, "desert") then F.check("desert: warp to Route 111", false); return end
    awaitControl(600)
    F.check("desert: walked to the sandstorm edge", F.route({ { 19, 60 }, { 14, 60 } }, "desert"), at())
    F.step("Down"); awaitControl(300)
    F.step("Down"); awaitControl(300)
    local x, y = F.pos()
    F.check("desert: through the Go-Goggles trigger", x == 14 and y == 62, at())
    F.check("desert: the sandstorm blows", weather() == WEATHER_SANDSTORM, "weather=" .. weather())
    F.check("desert: the desert music plays", settledSong() == MUS_DESERT, "song=" .. playingSong())
    if not saveContinue("desert", "soft") then return end
    F.check("desert: walks on", F.step("Up") or F.step("Down"), at())
  end)

  -- Five Island's Lost Cave Room 2 (fog, no objects): warp 0 at (5,1).
  case("sevii fog", function()
    if not warp(36, 14, 0, "lostcave") then F.check("lostcave: warp to the Lost Cave", false); return end
    awaitControl(600)
    F.route({ { 5, 3 } }, "lostcave")
    F.check("lostcave: in the fog", weather() == WEATHER_FOG_HORIZONTAL, "weather=" .. weather())
    if not saveContinue("lostcave", "soft") then return end
    F.check("lostcave: walks on", F.step("Down") or F.step("Right"), at())
  end)

  -- Trainer Hill: the lobby door is warp 0 at (9,16).
  case("trainer hill lobby", function()
    if not warp(26, 60, 0, "thill") then F.check("thill: warp to the Trainer Hill", false); return end
    awaitControl(600)
    F.check("thill: walked into the lobby", F.route({ { 9, 13 } }, "thill"), at())
    if not saveContinue("thill", "power") then return end
    F.check("thill: walks on", F.step("Right"), at())
  end)

  -- Mahogany Gym: the door is warp 0 at (12,28); ice fills x 5..8 of row 27, so a step west from
  -- (9,27) slides to the wall at (5,27), and a step north from there slides to (5,22).
  case("mahogany ice", function()
    if not warp(92, 0, 0, "mahogany") then F.check("mahogany: warp to the Mahogany Gym", false); return end
    awaitControl(600)
    F.check("mahogany: walked to the ice", F.route({ { 9, 27 } }, "mahogany"), at())
    F.step("Left")
    for _ = 1, 120 do if F.pos() == 5 then break end F.idle(1) end
    awaitControl(200)
    local x, y = F.pos()
    F.check("mahogany: slid to the wall", x == 5 and y == 27, at())
    if not saveContinue("mahogany", "soft") then return end
    F.step("Up")
    for _ = 1, 120 do if select(2, F.pos()) == 22 then break end F.idle(1) end
    awaitControl(200)
    x, y = F.pos()
    F.check("mahogany: slides north from the saved tile", x == 5 and y == 22, at())
  end)

  local function resetAndContinue(tag)
    softReset(); F.idle(60)
    local booted = F.boot(nil, true)
    F.check(tag .. ": continued to the field", booted)
    if not booted then return false end
    if F.reportCrash(tag) then F.check(tag .. ": no crash", false); return false end
    return F.check(tag .. ": control returns", awaitControl(600))
  end

  -- Each mash opens SAVE, then presses one of A (three times as likely), B, Up, Down or nothing for
  -- 1 to 4 frames at a time until the dialog hands control back: Yes or No on the save prompt, Yes
  -- or No on the overwrite prompt and the A that ends the saved message all get hit.
  local function mashSave(seed)
    local rng = seed
    local function rand(n) rng = (rng * 1103515245 + 12345) & 0x7FFFFFFF; return (rng >> 8) % n end
    F.w16(S.gSaveAttemptStatus, SENTINEL)
    if not openStart() or not F.selectStartIcon(USM_ICO_SAVE) then return "noicon" end
    F.press("A", 2)
    local keys = { "A", "A", "A", "B", "Up", "Down", false }
    for i = 1, 3000 do
      if i > 10 and hasControl() then
        local st = F.r16(S.gSaveAttemptStatus)
        return st == SENTINEL and "cancelled" or (st == 1 and "saved" or string.format("status %X", st))
      end
      local k = keys[rand(#keys) + 1]
      for _ = 1, 1 + rand(4) do joypad.set(k and { [k] = true } or {}); emu.frameadvance() end
      if F.reportCrash("mash") then return "crash" end
    end
    return "stuck"
  end

  -- The Trainer Hill lobby again, facing open floor, so a stray A after the dialog talks to nobody.
  case("two saves in a row", function()
    if F.grp() ~= 26 or F.mapn() ~= 60 then
      if not warp(26, 60, 0, "twice") then F.check("twice: warp to the Trainer Hill", false); return end
      awaitControl(600)
      F.route({ { 10, 13 } }, "twice")
    end
    awaitControl(300)
    local c0 = F.r32(S.gSaveCounter)
    setMoney(11111)
    local a = driveSave()
    setMoney(22222)
    local b = driveSave()
    F.check("twice: both saves completed", a == "done" and b == "done", a .. "/" .. b)
    F.check("twice: the save counter moved by two", F.r32(S.gSaveCounter) == c0 + 2,
      string.format("%d -> %d", c0, F.r32(S.gSaveCounter)))
    if not resetAndContinue("twice") then return end
    F.check("twice: the second save loaded", F.money() == 22222, "money=" .. F.money())

    local savedMoney = 22222
    for k, seed in ipairs({ 7, 1234, 99, 4242, 31337, 5, 2026, 88 }) do
      local tag = "mash seed " .. seed
      awaitControl(300)
      setMoney(30000 + k)
      local r = mashSave(seed)
      F.L(string.format("  %s: %s", tag, r))
      F.check(tag .. ": the dialog ends with a save or a cancel", r == "saved" or r == "cancelled", r)
      if r == "saved" then savedMoney = 30000 + k end
      F.check(tag .. ": the field is free afterwards", F.ensureFree(), at())
      if k % 2 == 0 then
        if not resetAndContinue(tag) then return end
        F.check(tag .. ": Continue loads the last completed save", F.money() == savedMoney,
          string.format("money=%d want %d", F.money(), savedMoney))
        F.check(tag .. ": walks after Continue", F.ensureFree(), at())
      end
    end
  end)

  -- The National Park gate (83/7): save beside the contest attendant, enter through her, find no
  -- SAVE on the Start menu, soft reset inside the park, and Continue in the gate before the contest.
  case("bug contest reset", function()
    local GATE_G, GATE_M, CONTEST_G, CONTEST_M = 83, 7, 83, 5
    local function setJohto()
      F.w32(S.gCurrentRegion, REGION_JOHTO)
      F.w8(F.sb2() + S.SaveBlock2.currentRegion, REGION_JOHTO)
    end
    local function contestState() return F.r16(F.sb3() + S.SaveBlock3.regionVars + (VAR_BUG_CONTEST_STATE - 0xA000) * 2) end
    local function inContest() return F.grp() == CONTEST_G and F.mapn() == CONTEST_M end
    local function enter()
      F.face("Left")
      F.press("A", 3); F.idle(40)
      for _ = 1, 400 do
        F.press("A", 2); F.idle(18)
        if inContest() and F.ow() and contestState() == 2 then break end
        if F.reportCrash("entry") then break end
      end
      for _ = 1, 20 do F.press("B", 3); F.idle(20) end
      return inContest() and flag(FLAG_SYS_BUG_CONTEST_MODE)
    end
    setFlag(FLAG_SYS_POKEMON_GET)
    if F.r8(S.gPartiesCount) < 2 then createMon(SPECIES_CATERPIE, 10) end
    if F.r8(S.gPartiesCount) < 3 then createMon(SPECIES_RATTATA, 12) end
    if not warp(GATE_G, GATE_M, 0, "contest") then F.check("contest: warp to the National Park gate", false); return end
    setJohto()
    awaitControl(600)
    F.check("contest: walked to the attendant", F.leg(4, 2), at())
    F.face("Left")
    local x, y = F.pos()
    local before = { n = F.r8(S.gPartiesCount), party = partyHash(), state = contestState(), x = x, y = y }
    F.check("contest: saved in the gate", driveSave() == "done")
    F.check("contest: entered the park through the attendant", enter(),
      string.format("at %s state=%d", at(), contestState()))
    F.check("contest: only the lead goes in", F.r8(S.gPartiesCount) == 1, "count=" .. F.r8(S.gPartiesCount))
    F.step("Up"); F.step("Up")
    F.check("contest: the Start menu opens in the park", openStart())
    local icons = usmIcons()
    F.shot("contest_menu")
    F.check("contest: the Start menu offers no SAVE", not icons[USM_ICO_SAVE])
    for _ = 1, 4 do F.press("B", 2); F.idle(20) end
    awaitControl(200)
    if not resetAndContinue("contest") then return end
    x, y = F.pos()
    F.check("contest: Continue lands in the gate on the saved tile",
      F.grp() == GATE_G and F.mapn() == GATE_M and x == before.x and y == before.y, at())
    F.check("contest: the whole team is back", F.r8(S.gPartiesCount) == before.n and partyHash() == before.party,
      string.format("count=%d", F.r8(S.gPartiesCount)))
    F.check("contest: contest mode is off", not flag(FLAG_SYS_BUG_CONTEST_MODE))
    F.check("contest: the contest state is the gate's", contestState() == before.state,
      contestState() .. " vs " .. before.state)
    F.check("contest: no contest balls in the bag", F.itemCount(ITEM_SAFARI_BALL) == 0)
    setJohto()
    F.check("contest: the attendant runs the contest again", enter(),
      string.format("at %s state=%d", at(), contestState()))
  end)

  F.finish()
end)
