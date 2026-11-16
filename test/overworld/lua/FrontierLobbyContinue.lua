-- Save and Continue inside every Battle Frontier lobby, the three Battle Tents and the Trainer
-- Tower lobby, and a soft reset inside the Safari Zone.
--
-- Each lobby case walks in from the door, saves from the Start menu, soft resets and continues.
-- The map, tile and facing, the playing song, the follower (shown or hidden, and beside the
-- player) and control must come back as they were, and the player must walk. The Safari case
-- saves in the Hoenn entrance, enters through the attendant, walks until the step counter has
-- moved, checks the Safari Start menu offers no SAVE, then soft resets: Continue must land in the
-- entrance with Safari mode off and no Safari Balls.
--
-- PW_LOBBY_ONLY=<text> (runner --env) runs matching cases.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/FrontierLobbyContinue.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "FrontierLobbyContinue")

local USM_ICO_SAVE = 7
local SENTINEL = 0xFFFF
local CONTEXT_RUNNING = 0
local OBJ_EVENT_ID_FOLLOWER = 0xFE
local FLAG_SYS_POKEMON_GET = 0x948
local FLAG_SYS_SAFARI_MODE = 0x948 + 0x2C
local ITEM_SAFARI_BALL = 23
local ITEM_POKEBLOCK_CASE = 722
local ONLY = os.getenv("PW_LOBBY_ONLY")

local LOBBIES = {
  { "Battle Tower",    26, 5 },  { "Battle Dome",    26, 18 }, { "Battle Palace", 26, 22 },
  { "Battle Pyramid",  26, 25 }, { "Battle Arena",   26, 28 }, { "Battle Factory", 26, 31 },
  { "Battle Pike",     26, 34 }, { "Fallarbor Tent", 5, 1 },   { "Verdanturf Tent", 6, 0 },
  { "Slateport Tent",  9, 2 },   { "Trainer Tower",  36, 10, 1 },
}
local SAFARI = { entG = 23, entM = 0, zoneG = 26, zoneM = 3, warp = { 0, 2, 3, 0, 0, 0, 0, 0, 2 },
                 approach = { { 14, 4 }, { 9, 4 } }, trigger = "Left" }

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function warp(g, m, w, tag)
  local gh, gt, go = d(g)
  local mh, mt, mo = d(m)
  local wh, wt, wo = d(w)
  return F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, g, m, tag)
end
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function on(g, m) return F.grp() == g and F.mapn() == m end
local function sb1Flag(id, on_)
  local a, m = F.sb1() + S.SaveBlock1.flags + (id // 8), 1 << (id % 8)
  if on_ == nil then return (F.r8(a) & m) ~= 0 end
  F.w8(a, on_ and (F.r8(a) | m) or (F.r8(a) & ~m & 0xFF))
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
  for _ = 1, 400 do
    local s = playingSong()
    if s == last and s > 0 then same = same + 1 else same = 0 end
    if same >= 30 then return s end
    last = s
    F.idle(1)
  end
  return playingSong()
end

local function follower()
  for i = 0, 15 do
    local o = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(o) & 1) ~= 0 and F.r8(o + 8) == OBJ_EVENT_ID_FOLLOWER then
      local px, py = F.pos()
      local fx, fy = F.rs16(o + 0x10) - 7, F.rs16(o + 0x12) - 7
      local hidden = ((F.r8(o + 1) >> 5) & 1) == 1
      return hidden and "hidden" or ((math.abs(fx - px) + math.abs(fy - py) <= 1) and "beside" or string.format("away(%d,%d)", fx, fy))
    end
  end
  return "none"
end
local function facing()
  local o = S.gObjectEvents + F.r8(S.gPlayerAvatar + 5) * S.ObjectEvent.stride
  return F.r8(o + S.ObjectEvent.facing) & 0x0F
end
local function snapshot()
  local x, y = F.pos()
  return { g = F.grp(), m = F.mapn(), x = x, y = y, face = facing(), song = settledSong(), fol = follower() }
end
local function fmt(s)
  return string.format("%d/%d (%d,%d) face=%d song=%d follower=%s", s.g, s.m, s.x, s.y, s.face, s.song, s.fol)
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
  joypad.set({}); F.idle(60)
end

local function case(tag, body)
  if ONLY and not tag:find(ONLY, 1, true) then return end
  F.L("== " .. tag .. " ==")
  local ok, err = pcall(body)
  if not ok then F.check(tag .. ": ran without a Lua error", false, tostring(err)) end
end

local function stepAny()
  for _, dir in ipairs({ "Up", "Left", "Right", "Down" }) do
    if F.step(dir) then return dir end
  end
end
local BACK = { Up = "Down", Down = "Up", Left = "Right", Right = "Left" }

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  sb1Flag(FLAG_SYS_POKEMON_GET, true)
  F.dbg(); F.idle(60)
  for _ = 1, 2 do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(60)
  for _ = 1, 9 do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(200)
  for _ = 1, 16 do F.press("B", 3); F.idle(20) end
  F.check("setup: Set Party gave a party", F.r8(S.gPartiesCount) > 0)

  for _, l in ipairs(LOBBIES) do
    local name, g, m, w = l[1], l[2], l[3], l[4] or 0
    case(name, function()
      if not F.check(name .. ": warp in", warp(g, m, w, name), where()) then return end
      awaitControl(600)
      local moved = F.step("Up") and F.step("Up")
      F.L("  walked in: " .. tostring(moved) .. " " .. where())
      local before = snapshot()
      F.L("  before " .. fmt(before))
      F.shot((name:gsub(" ", "_")) .. "_before")
      if not F.check(name .. ": saved", driveSave() == "done") then return end
      softReset()
      if not F.check(name .. ": continued", F.boot(nil, true)) then return end
      F.check(name .. ": control after Continue", awaitControl(900), where())
      local after = snapshot()
      F.L("  after  " .. fmt(after))
      F.shot((name:gsub(" ", "_")) .. "_after")
      F.check(name .. ": same map, tile and facing", after.g == before.g and after.m == before.m
        and after.x == before.x and after.y == before.y and after.face == before.face, fmt(after))
      F.check(name .. ": the same music plays", after.song == before.song and after.song > 0,
        after.song .. " vs " .. before.song)
      F.check(name .. ": the follower comes back the same", after.fol == before.fol, after.fol .. " vs " .. before.fol)
      local dir = stepAny()
      F.check(name .. ": the player can walk", dir ~= nil, where())
      if dir then F.step(BACK[dir]) end
      F.check(name .. ": no crash", not F.crashScreen())
    end)
  end

  case("Safari soft reset", function()
    local z = SAFARI
    if not F.check("Safari: warp to the Hoenn entrance", warp(z.entG, z.entM, 2, "safari_ent"), where()) then return end
    awaitControl(600)
    -- The Hoenn attendant wants a Pokeblock case.
    local ptr, k = F.r32(S.gBagPockets + 4 * S.BagPocket.stride), F.r16(F.sb2() + S.SaveBlock2.encryptionKey)
    for sl = 0, F.pocketCap(4) - 1 do
      if F.r16(ptr + sl * 4) == 0 then F.w16(ptr + sl * 4, ITEM_POKEBLOCK_CASE); F.w16(ptr + sl * 4 + 2, 1 ~ k); break end
    end
    for _, p in ipairs(z.approach) do F.leg(p[1], p[2]) end
    local x0, y0 = F.pos()
    local saved = driveSave() == "done"
    F.check("Safari: saved in the entrance", saved)
    F.step(z.trigger)
    for _ = 1, 400 do
      F.press("A", 2); F.idle(18)
      if on(z.zoneG, z.zoneM) and F.ow() then break end
    end
    awaitControl(600)
    F.check("Safari: the attendant lets the player in", on(z.zoneG, z.zoneM) and sb1Flag(FLAG_SYS_SAFARI_MODE), where())
    local steps0 = F.r16(S.gSafariZoneStepCounter)
    for i = 1, 6 do F.step(i % 2 == 1 and "Down" or "Up") end
    local steps1, balls1 = F.r16(S.gSafariZoneStepCounter), F.r8(S.gNumSafariBalls)
    F.L(string.format("  steps %d -> %d, balls %d", steps0, steps1, balls1))
    F.check("Safari: the step counter moved", steps1 < steps0, steps0 .. " -> " .. steps1)
    F.press("Start", 2); F.idle(90)
    local hasSave = F.selectStartIcon(USM_ICO_SAVE)
    F.shot("safari_menu")
    for _ = 1, 6 do F.press("B", 2); F.idle(20) end
    F.check("Safari: the Start menu offers no SAVE inside the zone", not hasSave)
    awaitControl(300)
    softReset()
    if not F.check("Safari: continued", F.boot(nil, true)) then return end
    F.check("Safari: control after Continue", awaitControl(900), where())
    local x, y = F.pos()
    F.check("Safari: Continue lands where the entrance save was made",
      on(z.entG, z.entM) and x == x0 and y == y0, where())
    F.check("Safari: Safari mode is off", not sb1Flag(FLAG_SYS_SAFARI_MODE))
    local key = F.r16(F.sb2() + S.SaveBlock2.encryptionKey)
    local balls = 0
    local ptr = F.r32(S.gBagPockets + S.BagPocket.stride)
    for i = 0, F.pocketCap(1) - 1 do
      if F.r16(ptr + i * 4) == ITEM_SAFARI_BALL then balls = balls + (F.r16(ptr + i * 4 + 2) ~ key) end
    end
    F.check("Safari: no Safari Balls", balls == 0 and F.r8(S.gNumSafariBalls) == 0, "bag=" .. balls)
    F.check("Safari: the player can walk", stepAny() ~= nil, where())
  end)

  F.finish()
end)
