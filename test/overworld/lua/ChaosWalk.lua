-- Chaos walk: seeded, goal-directed play through transition-dense places in all three regions,
-- with button noise on top of every step.
--
-- Each location starts from a debug warp onto one of its warps with a Lv100 party (Lapras leads
-- with Surf and Ice Beam, so a mashed A ends a fight) under a long Repel, every badge and the HM
-- tools, the Sky Pillar door open (as after the Cave of Origin, the only way into the pillar), and
-- the Mach Bike on Select (or the Sky Charm for the "sky" locations). A walker reads
-- the live map grid and the map header's warps, picks a random warp or open tile (any tile while
-- flying), plans a path and holds each step's direction, while a seeded noise source taps A, B,
-- Start, Select, L and R. It goes through doors, ladders, stairs, ice, spinners, warp pads and cave
-- mouths with menus, the bike and the flight toggling over the fades. After every map change,
-- walk and landing it waits for the field and checks: no crash screen, the game keeps running
-- (play time advances), the player object sits on the saved tile and on a passable block, and a
-- shown follower stands next to the player on a passable block, or waits on the ledge top two
-- tiles back after the player jumped down. Battles the walk starts are ended by the mash (foes at
-- 1 HP).
--
-- PW_CHAOS_ONLY=<text> runs matching locations, PW_CHAOS_BASE=<n> reseeds, PW_CHAOS_HOPS=<n> sets
-- the transitions per location (default 8) and PW_CHAOS_FRAMES=<n> its frame budget (12000).
-- PW_CHAOS_SAVE=<dir> keeps a savestate before each location, and PW_CHAOS_LOAD=<state> with
-- PW_CHAOS_ONLY replays one location from such a state. The whole battery needs the runner's
-- --env PW_MAX_FRAMES=900000.

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "ChaosWalk")

local HUB_GROUP = 100
local ONLY = os.getenv("PW_CHAOS_ONLY")
local BASE = tonumber(os.getenv("PW_CHAOS_BASE") or "") or 0xC4A05
local HOPS = tonumber(os.getenv("PW_CHAOS_HOPS") or "") or 8
local FRAMES = tonumber(os.getenv("PW_CHAOS_FRAMES") or "") or 12000
local OBJ_EVENT_ID_FOLLOWER = 0xFE
local VAR_REPEL_STEP_COUNT = 0x4021
local ITEM_MACH_BIKE = 707
local ITEM_SKY_CHARM = 891
local AVATAR_BIKES = 0x06
local FLAG_WALLACE_GOES_TO_SKY_PILLAR = 0x137
local MB_JUMP = { [0x38] = { 1, 0 }, [0x39] = { -1, 0 }, [0x3A] = { 0, -1 }, [0x3B] = { 0, 1 } }  -- MB_JUMP_EAST..SOUTH

local seed = BASE
local function rnd()
  seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
  return seed >> 8
end
local function seedFor(tag)
  local h = BASE & 0x7FFFFFFF
  for i = 1, #tag do h = ((h ~ tag:byte(i)) * 16777619) & 0x7FFFFFFF end
  return h
end

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
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function addItem(id, qty) runScript({ 0x44, id & 0xFF, id >> 8, qty & 0xFF, qty >> 8, 0x02 }) end
local function setFlag(id) runScript({ 0x29, id & 0xFF, id >> 8, 0x02 }) end
local function setVar(id, v) local b = { 0x16 }; le16(b, id); le16(b, v); b[#b + 1] = 0x02; runScript(b) end
local function createMon(species, level, moves)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(b, species); le16(b, level)
  if moves then
    le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
    for k = 1, 4 do le16(b, moves[k] or 0) end
  else
    le32(b, 0)
  end
  b[#b + 1] = 0x02
  runScript(b)
end

local function d3(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
-- On a spinner's stop tile the debug chord opens the Start menu instead, so a failed warp steps to
-- another tile (a spinner can carry a step straight back) and tries again.
local function warp(g, m, w, tag)
  local gh, gt, go = d3(g)
  local mh, mt, mo = d3(m)
  local wh, wt, wo = d3(w)
  for _ = 1, 3 do
    if F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, g, m, tag) then return true end
    for _ = 1, 6 do F.press("B", 2); F.idle(20) end
    local px, py = F.pos()
    F.L(string.format("  warp retry: cb2=%08X (%d,%d) avatar=%02X lock=%d script=%d", F.cb2(), px, py, F.r8(S.gPlayerAvatar),
      F.r8(S.sLockFieldControls), F.r8(S.sGlobalScriptContextStatus)))
    local x0, y0 = F.pos()
    for _, d in ipairs({ "Down", "Left", "Up", "Right" }) do
      F.step(d)
      local x, y = F.pos()
      if x ~= x0 or y ~= y0 then break end
    end
  end
  return false
end

local function tasks()
  local t = {}
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    if F.r8(a + S.Task.isActive) ~= 0 then t[#t + 1] = string.format("%08X", F.r32(a + S.Task.func)) end
  end
  return table.concat(t, ",")
end
local function state()
  return string.format("cb2=%08X tasks=[%s] grp=%d map=%d (%d,%d)", F.cb2(), tasks(), F.grp(), F.mapn(), F.pos())
end

local function inBattle() return F.cb2() == (S.BattleMainCB2 & ~1) end
local function assistBattle(i)
  for b = 0, F.battlers() - 1 do
    local a = S.gBattleMons + b * S.BattlePokemon.size
    local hp = F.r16(a + S.BattlePokemon.hp)
    if b % 2 == 1 and hp > 1 and i % 60 == 0 then F.w16(a + S.BattlePokemon.hp, 1) end
    if b % 2 == 0 and hp > 0 then
      F.w16(a + S.BattlePokemon.hp, F.r16(a + S.BattlePokemon.maxHP))
      F.w8(a + S.BattlePokemon.pp, 15)   -- a long walk runs the lead's first move dry
    end
  end
end

local frame, airFrames = 0, 0
local function noisyFrame(dir)
  frame = frame + 1
  if F.r8(S.sFlightActive) ~= 0 then airFrames = airFrames + 1 end
  local t = {}
  if dir then t[dir] = true end
  if inBattle() then
    assistBattle(frame)
    if frame % 8 < 2 then t.A = true end
  end
  if rnd() % 1000 < 60 then t.A = true end
  if rnd() % 1000 < 50 then t.B = true end
  if rnd() % 1000 < 12 then t.Start = true end
  if rnd() % 1000 < 12 then t.Select = true end
  if rnd() % 1000 < 12 then t.L = true end
  if rnd() % 1000 < 12 and not t.Start then t.R = true end
  if t.A and t.B and t.Start then t.Start = nil end
  joypad.set(t)
  emu.frameadvance()
end

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= 0
end

local function grid()
  local w = F.r32(S.gBackupMapLayout + S.BackupMapLayout.width)
  local h = F.r32(S.gBackupMapLayout + S.BackupMapLayout.height)
  local p = F.r32(S.gBackupMapLayout + S.BackupMapLayout.map)
  return w, h, p
end
local function blockAt(x, y)
  local w, h, p = grid()
  if p < 0x02000000 or w <= 0 or x + 7 < 0 or y + 7 < 0 or x + 7 >= w or y + 7 >= h then return -1 end
  return F.r16(p + 2 * ((x + 7) + (y + 7) * w))
end
local function passable(x, y) local b = blockAt(x, y); return b >= 0 and ((b >> 10) & 3) == 0 end
-- The behavior MapGridGetMetatileBehaviorAt reads. Kanto and Johto layouts split the tilesets at
-- 640, and a tileset with FRLG attributes stores them as u32.
local function behaviorAt(x, y)
  local id = blockAt(x, y) & S.Metatiles.idMask
  local layout = F.r32(S.gMapHeader + S.MapHeader.mapLayout)
  local split = (F.r8(layout + S.MapLayout.isFrlg) ~= 0 or F.r8(layout + S.MapLayout.isJohto) ~= 0)
    and S.Metatiles.inPrimaryFrlg or S.Metatiles.inPrimary
  local tileset = F.r32(layout + (id < split and S.MapLayout.primaryTileset or S.MapLayout.secondaryTileset))
  local attrs, n = F.r32(tileset + S.Tileset.metatileAttributes), id < split and id or id - split
  if (F.r8(tileset + S.Tileset.flags1) & S.Tileset.hasFrlgAttributesBit) ~= 0 then
    return F.r32(attrs + n * 4) & S.Metatiles.behaviorMaskFrlg
  end
  return F.r16(attrs + n * 2) & S.Metatiles.behaviorMask
end
-- When the player jumps a ledge, the follower walks onto the ledge top and waits there, two tiles
-- back, until the player's next step, which it follows with its own jump.
local function waitsOnLedgeTop(fx, fy, x, y)
  local dx, dy = x - fx, y - fy
  if math.abs(dx) + math.abs(dy) ~= 2 or (dx ~= 0 and dy ~= 0) then return false end
  local jump = MB_JUMP[behaviorAt(fx + dx // 2, fy + dy // 2)]
  return jump ~= nil and jump[1] == dx // 2 and jump[2] == dy // 2
end
local function flying() return F.r8(S.sFlightActive) ~= 0 end

local function warps()
  local ev = F.r32(S.gMapHeader + 4)
  local n, base = F.r8(ev + 1), F.r32(ev + 8)
  local t = {}
  for i = 0, n - 1 do
    local a = base + i * 8
    t[#t + 1] = { x = F.rs16(a), y = F.rs16(a + 2), id = i }
  end
  return t
end

local STEP = { Up = { 0, -1 }, Down = { 0, 1 }, Left = { -1, 0 }, Right = { 1, 0 } }
local ORDER = { "Up", "Down", "Left", "Right" }
local function plan(tx, ty, anywhere)
  local w, h = grid()
  local sx, sy = F.pos()
  local function key(x, y) return (y + 7) * w + (x + 7) end
  local prev, q, head = { [key(sx, sy)] = false }, { { sx, sy } }, 1
  while head <= #q and #q < 6000 do
    local x, y = q[head][1], q[head][2]; head = head + 1
    if x == tx and y == ty then
      local path, k = {}, key(x, y)
      while prev[k] do path[#path + 1] = prev[k].dir; k = prev[k].from end
      local r = {}
      for i = #path, 1, -1 do r[#r + 1] = path[i] end
      return r
    end
    for _, d in ipairs(ORDER) do
      local nx, ny = x + STEP[d][1], y + STEP[d][2]
      local k = key(nx, ny)
      local inside = nx >= -7 and ny >= -7 and nx < w - 7 and ny < h - 7
      if prev[k] == nil and inside and (passable(nx, ny) or (anywhere and blockAt(nx, ny) >= 0) or (nx == tx and ny == ty)) then
        prev[k] = { from = key(x, y), dir = d }
        q[#q + 1] = { nx, ny }
      end
    end
  end
end

local function objAt(localId)
  for i = 0, 15 do
    local o = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(o) & 1) ~= 0 and F.r8(o + 8) == localId then return o end
  end
end
local function playerObj() return S.gObjectEvents + F.r8(S.gPlayerAvatar + 5) * S.ObjectEvent.stride end
local function playTime()
  local sb2 = F.sb2()
  return F.r8(sb2 + 0x10) * 3600 + F.r8(sb2 + 0x11) * 60 + F.r8(sb2 + 0x12)
end

-- The field after a map change: wait for control without input, then check the player and the
-- follower. A follower hidden for a bike ride or forced movement is skipped.
local issues, frozen = 0, false
local function settleAndCheck(tag)
  if frozen then return end
  for _ = 1, 600 do
    if hasControl() then break end
    noisyFrame(nil)
  end
  if not hasControl() then return end
  local t0 = playTime()
  F.idle(40)
  if playTime() == t0 then
    issues = issues + 1
    F.shot(tag .. "_frozen")
    F.check(tag .. ": the game keeps running", false, string.format("play time stuck at %d; %s", t0, state()))
    frozen = true
    return
  end
  if not hasControl() or flying() then return end
  local x, y = F.pos()
  local b = blockAt(x, y)
  local p = playerObj()
  local px, py = F.rs16(p + S.ObjectEvent.x) - 7, F.rs16(p + S.ObjectEvent.y) - 7
  local where = string.format("%d/%d (%d,%d) block=%04X avatar=%02X", F.grp(), F.mapn(), x, y, b, F.r8(S.gPlayerAvatar))
  if px ~= x or py ~= y then
    issues = issues + 1
    F.check(tag .. ": the player object sits on the saved tile", false, string.format("obj (%d,%d) %s", px, py, where))
  end
  if ((b >> 10) & 3) ~= 0 then
    issues = issues + 1
    F.shot(tag .. "_wall")
    F.check(tag .. ": the player stands on a passable block", false, where)
  end
  local f = objAt(OBJ_EVENT_ID_FOLLOWER)
  if f and ((F.r8(f + 1) >> 5) & 1) == 0 and (F.r8(S.gPlayerAvatar) & AVATAR_BIKES) == 0 then
    local fx, fy = F.rs16(f + S.ObjectEvent.x) - 7, F.rs16(f + S.ObjectEvent.y) - 7
    local fb = blockAt(fx, fy)
    local dist = math.abs(fx - x) + math.abs(fy - y)
    local walled = ((fb >> 10) & 3) ~= 0 and dist ~= 0
    if (dist > 1 and not waitsOnLedgeTop(fx, fy, x, y)) or walled then
      issues = issues + 1
      F.shot(tag .. "_follower")
      F.check(tag .. ": a shown follower stands next to the player on a passable block", false,
        string.format("follower (%d,%d) block=%04X dist=%d; %s", fx, fy, fb, dist, where))
    end
  end
end

local function location(tag, g, m, w, sky)
  if frozen or (ONLY and not tag:find(ONLY, 1, true)) then return end
  seed = seedFor(tag)
  F.L(string.format("== %s == seed=%d", tag, seed))
  F.w16(F.sb1() + S.SaveBlock1.registeredItem, sky and ITEM_SKY_CHARM or ITEM_MACH_BIKE)
  if os.getenv("PW_CHAOS_SAVE") then client.savestate(os.getenv("PW_CHAOS_SAVE") .. "/" .. tag:gsub("%W", "_") .. "_pre.ss") end
  if not warp(g, m, w, tag) then F.check(tag .. ": warped in", false); return end
  local landings, wasFlying = 0, false
  setVar(VAR_REPEL_STEP_COUNT, 0x7FFF)
  local startIssues = issues
  local maps, hops, start = { string.format("%d/%d", F.grp(), F.mapn()) }, 0, frame
  local crashed = false
  local cur = F.grp() * 256 + F.mapn()
  while hops < HOPS and frame - start < FRAMES and not frozen do
    if F.reportCrash(tag) then crashed = true; break end
    if not F.ow() then
      noisyFrame(nil)
    else
      local x, y = F.pos()
      local cands = {}
      local air = flying()
      if air then
        local gw, gh = grid()
        for _ = 1, 4 do cands[#cands + 1] = { x = rnd() % (gw - 14), y = rnd() % (gh - 14) } end
      else
        for _, wp in ipairs(warps()) do if wp.x ~= x or wp.y ~= y then cands[#cands + 1] = wp end end
        -- Half the time wander to a random open tile instead, so spinners, ice and currents
        -- between the warps get ridden too.
        if #cands == 0 or rnd() % 2 == 0 then
          local gw, gh = grid()
          for _ = 1, 30 do
            local tx, ty = rnd() % (gw - 14), rnd() % (gh - 14)
            if passable(tx, ty) then cands = { { x = tx, y = ty } }; break end
          end
        end
      end
      local target = #cands > 0 and cands[rnd() % #cands + 1] or nil
      local path = target and plan(target.x, target.y, air) or nil
      if not path then
        for _ = 1, 20 do noisyFrame(ORDER[rnd() % 4 + 1]) end
      else
        for _, dir in ipairs(path) do
          local x0, y0 = F.pos()
          local moved = false
          for _ = 1, 24 do
            noisyFrame(dir)
            local fl = flying()
            if wasFlying and not fl then landings = landings + 1; settleAndCheck(tag .. " landing") end
            wasFlying = fl
            if F.grp() * 256 + F.mapn() ~= cur then break end
            local nx, ny = F.pos()
            if nx ~= x0 or ny ~= y0 then moved = true; break end
          end
          if F.grp() * 256 + F.mapn() ~= cur or not moved then break end
          for _ = 1, 10 do noisyFrame(dir) end
          if air and rnd() % 100 < 8 then break end
        end
        if not flying() and F.grp() * 256 + F.mapn() == cur then settleAndCheck(tag .. " walk") end
        if flying() then
          -- Try to land where the walk stopped; the charm refuses unlandable tiles.
          for _ = 1, 6 do noisyFrame(nil) end
          joypad.set({ Select = true }); emu.frameadvance(); frame = frame + 1
          for _ = 1, 40 do noisyFrame(nil) end
          if not flying() then landings = landings + 1; wasFlying = false; settleAndCheck(tag .. " landing") end
        elseif air == false and rnd() % 100 < 30 and F.ow() then
          joypad.set({ Select = true }); emu.frameadvance(); frame = frame + 1
        end
      end
    end
    local now = F.grp() * 256 + F.mapn()
    if now ~= cur then
      cur = now; hops = hops + 1
      maps[#maps + 1] = string.format("%d/%d", F.grp(), F.mapn())
      settleAndCheck(tag)
      if hops % 3 == 0 then F.shot(tag .. "_hop" .. hops) end
    end
  end
  F.L("  maps " .. table.concat(maps, " ") .. string.format(" hops=%d frames=%d landings=%d air=%d", hops, frame - start, landings, airFrames))
  airFrames = 0
  F.check(tag .. ": no crash", not crashed, state())
  if frozen then return end
  F.check(tag .. ": no field invariant broke", issues == startIssues, (issues - startIssues) .. " issue(s)")
  -- Back to the field: control held for a second with no input, B to dismiss anything left open.
  -- A battle the walk started may still have all of its turns to go: a two-trainer double on
  -- Route 118, met on the walk's last step, took 8,477 frames to hand back the field.
  local calm, still, last = 0, 0, ""
  for i = 1, 30000 do
    if hasControl() then calm = calm + 1 else calm = 0 end
    if calm >= 60 then break end
    if inBattle() then assistBattle(i) end
    local now = state()
    if now == last then still = still + 1 else still, last = 0, now end
    -- B, and A once three B presses have changed nothing, for messages that only take A (the
    -- Bag's error messages). A on every fourth press locked into a loop: A opened the Bag from the
    -- start menu, B closed it, and the next B fell in the fade before the start menu came back.
    local k = inBattle() and (i % 8 < 2 and "A" or nil)
      or ((not hasControl() and i % 30 < 2) and (still >= 90 and "A" or "B") or nil)
    joypad.set(k and { [k] = true } or {})
    emu.frameadvance()
  end
  if not hasControl() then
    F.shot(tag .. "_stuck")
    F.L(string.format("  stuck: battlers=%d flags=%08X outcome=%d ctrl=%08X", F.battlers(), F.battleFlags(), F.outcome(), F.r32(S.gBattlerControllerFuncs)))
    if os.getenv("PW_CHAOS_SAVE") then client.savestate(os.getenv("PW_CHAOS_SAVE") .. "/" .. tag:gsub("%W", "_") .. "_stuck.ss") end
  end
  F.check(tag .. ": back to the field", hasControl(), state())
end

local LOCATIONS = {
  { "johto ecruteak", 85, 0, 11 },
  { "johto olivine", 87, 0, 0 },
  { "johto goldenrod", 83, 0, 0 },
  { "johto ice path", 94, 7, 0 },
  { "kanto vermilion", 37, 5, 0 },
  { "kanto mt moon", 35, 2, 0 },
  { "kanto seafoam", 35, 86, 0 },
  { "kanto rocket hideout", 35, 43, 0 },
  { "kanto viridian gym", 39, 1, 0 },
  { "kanto saffron gym", 48, 3, 0 },
  { "kanto silph co", 35, 51, 0 },
  { "hoenn sootopolis", 0, 7, 0 },
  { "hoenn fortree", 0, 4, 0 },
  { "hoenn route119", 0, 34, 0 },
  { "hoenn granite cave", 24, 8, 0 },
  { "hoenn mossdeep gym", 14, 0, 0 },
  { "hoenn sky pillar", 24, 80, 0 },
  { "hoenn mauville gym", 10, 0, 0 },
  { "sky johto olivine", 87, 0, 0, true },
  { "sky johto goldenrod", 83, 0, 0, true },
  { "sky johto ecruteak", 85, 0, 11, true },
  { "sky kanto vermilion", 37, 5, 0, true },
  { "sky kanto celadon", 37, 6, 0, true },
  { "sky kanto cinnabar", 37, 8, 0, true },
  { "sky hoenn route119", 0, 34, 0, true },
  { "sky hoenn sootopolis", 0, 7, 0, true },
  { "sky hoenn lilycove", 0, 5, 0, true },
}

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  if os.getenv("PW_CHAOS_LOAD") then
    -- Replay the PW_CHAOS_ONLY location from the state a battery run saved before it.
    client.loadstate(os.getenv("PW_CHAOS_LOAD"))
    for _, l in ipairs(LOCATIONS) do location(l[1], l[2], l[3], l[4], l[5]) end
    F.finish(); return
  end
  for i = 0, 7 do setFlag(0x94F + i); setFlag(0xA40 + 0x0B + i); setFlag(0x6000 + 0x3F8 + i) end
  setFlag(FLAG_WALLACE_GOES_TO_SKY_PILLAR)
  for id = 875, 880 do addItem(id, 1) end
  addItem(ITEM_MACH_BIKE, 1)
  addItem(ITEM_SKY_CHARM, 1)
  createMon(131, 100, { 57, 58, 0, 0 })
  for _, sp in ipairs({ 130, 18, 68, 63, 260 }) do createMon(sp, 100) end
  F.check("party of six", F.r8(S.gPartiesCount) == 6, "n=" .. F.r8(S.gPartiesCount))

  for _, l in ipairs(LOCATIONS) do location(l[1], l[2], l[3], l[4], l[5]) end
  F.finish()
end)
