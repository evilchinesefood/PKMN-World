-- Kanto story props with a large follower out, all real input after the setup warps.
--
-- 1. Draw order in small houses. A Venusaur follower (32x32) walks a seeded 60-step path in the Cape
--    Brink house and three Three Island houses. Every frame the engine's own OAM sort key
--    (priority, subpriority, 159 - top y, sprite index; sprite.c BuildOamBuffer) is rebuilt for the
--    player and the follower: the follower may sort in front only when its feet are not above the
--    player's. A follower directly south of the player correctly covers the player's legs.
-- 2. The Celadon Dept. Store elevator: every floor, in a scrambled order, with A, B, Start, Select,
--    L, R and the D-pad spammed until the ride hands control back. Control must come back and the
--    dynamic warp must open on the chosen floor.
-- 3. The S.S. Anne departure (VAR_MAP_SCENE_VERMILION_CITY 1, the state the captain leaves): the
--    cutscene runs from the exterior arrival, the player lands in Vermilion, walks, and the follower
--    comes back out beside the player.
-- 4. Silph Co. 5F after Giovanni (FLAG_HIDE_SILPH_ROCKETS): the Card Key opens door 1, the player
--    walks through, saves, soft resets and continues on the far side, walks back through, opens door
--    2 and takes the west teleport pad to 3F, where the follower comes out next to the player.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "KantoPropsStress")

local MON, PARTY_SIZE = S.Pokemon.size, 6
local SPECIES_VENUSAUR = 3
local KANTO_FLAGS = 0xA40
local FLAG_HIDE_SILPH_ROCKETS = KANTO_FLAGS + 0x53
local FLAG_HIDE_CARD_KEY = KANTO_FLAGS + 0x192
local FLAG_SILPH_5F_DOOR_1, FLAG_SILPH_5F_DOOR_2 = KANTO_FLAGS + 0x280, KANTO_FLAGS + 0x281
local ITEM_CARD_KEY = 750
local VERMILION_SCENE_SLOT = 0x57                   -- VAR_MAP_SCENE_VERMILION_CITY, VAR_KANTO_SLICE(0x57)
local SILPH_G, SILPH_3F, SILPH_5F = 35, 49, 51
local DEPT_G, ELEVATOR_M = 44, 6
local USM_ICO_SAVE = 7
local SENTINEL = 0xBEEF
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local OBJ_EVENT_ID_FOLLOWER = 254

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function flagSet(id) return (F.r8(F.sb1() + S.SaveBlock1.flags + (id // 8)) & (1 << (id % 8))) ~= 0 end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end
local function d3(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local SCRIPT_BUF = S.gStringVar4 + 960
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
  for _ = 1, 200 do F.idle(4); if hasControl() then break end end
  F.idle(30)
end
local function setflag(id) runScript({ 0x29, id & 0xFF, id >> 8, 0x02 }) end
local function settle(tag)
  for i = 1, 900 do
    if F.reportCrash(tag) then return false end
    if hasControl() then F.idle(30); if hasControl() then return true end end
    if i % 15 == 0 then F.press("B", 2) else F.idle(1) end
  end
  F.shot(tag .. "_stuck")
  return false
end
local function waitMap(m, budget)
  for _ = 1, budget or 300 do if F.ow() and F.mapn() == m then F.idle(60); return true end F.idle(2) end
  return false
end
local function digits(n) n = n - 1; return n // 100, (n // 10) % 10, n % 10 end
local function giveMon(sp, level)
  for _ = 1, 3 do
    for off = 0, PARTY_SIZE * MON - 4, 4 do F.w32(S.gParties + off, 0) end
    F.w8(S.gPartiesCount, 0)
    F.dbg(); F.idle(30); F.bOut(4)
    F.dbg(); F.sel(3); F.sel(1); F.idle(20)
    F.spin(digits(sp)); F.idle(20)
    F.spin(digits(level)); F.idle(60); F.bOut(4)
    if F.r8(S.gPartiesCount) == 1 then return true end
    F.idle(60)
  end
  return false
end
local function followerIndex()
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == OBJ_EVENT_ID_FOLLOWER then return i end
  end
end
local function follower()
  local i = followerIndex()
  if not i then return end
  local b = S.gObjectEvents + i * S.ObjectEvent.stride
  return F.rs16(b + S.ObjectEvent.x) - 7, F.rs16(b + S.ObjectEvent.y) - 7, (F.r8(b + S.ObjectEvent.flags1) & 0x20) ~= 0
end
local function followerBeside(tag)
  local fx, fy, finv = follower()
  local px, py = F.pos()
  F.check(tag, fx and not finv and math.abs(fx - px) + math.abs(fy - py) == 1,
    string.format("player %d,%d follower %s,%s invisible=%s", px, py, tostring(fx), tostring(fy), tostring(finv)))
end

-- sprite.c BuildOamBuffer: key = priority << 30 | subpriority << 22 | (159 - oam.y) << 13 | index;
-- the smaller key is emitted first and drawn on top.
local SPRITE_ID, SPR_X, SPR_Y, SPR_X2, SPR_Y2, SPR_C2C_Y, SPR_FLAGS, SPR_SUBPRIO = 0x23, 0x20, 0x22, 0x24, 0x26, 0x29, 0x3E, 0x43
local function sortKey(objIdx)
  local sid = F.r8(S.gObjectEvents + objIdx * S.ObjectEvent.stride + SPRITE_ID)
  local s = S.gSprites + sid * S.Sprite.stride
  local top = F.rs16(s + SPR_Y) + F.rs16(s + SPR_Y2) + F.rs8(s + SPR_C2C_Y)
  local key = (((F.r16(s + 4) >> 10) & 3) << 30) | (F.r8(s + SPR_SUBPRIO) << 22) | (((159 - top) & 0x1FF) << 13) | sid
  return key, F.rs16(s + SPR_Y) + F.rs16(s + SPR_Y2), F.rs16(s + SPR_X) + F.rs16(s + SPR_X2), (F.r8(s + SPR_FLAGS) & 4) ~= 0
end
local inversions, scanned = 0, 0
local TAMPER = os.getenv("PW_TAMPER_SUBPRIORITY") ~= nil   -- control: pull the follower to the front
local function scanFrame(tag)
  local fi = followerIndex()
  if not fi then return end
  if TAMPER then
    local sid = F.r8(S.gObjectEvents + fi * S.ObjectEvent.stride + SPRITE_ID)
    F.w8(S.gSprites + sid * S.Sprite.stride + SPR_SUBPRIO, 0)
  end
  local pk, pfeet, px = sortKey(0)
  local fk, ffeet, fx, finv = sortKey(fi)
  if finv then return end
  scanned = scanned + 1
  if fk < pk and ffeet < pfeet - 2 and math.abs(fx - px) < 28 then
    inversions = inversions + 1
    if inversions <= 4 then F.shot("overdraw_" .. tag); F.L(string.format("  OVERDRAW %s feet P=%d F=%d", tag, pfeet, ffeet)) end
  end
end
local function scanStep(dir, tag)
  local x0, y0 = F.pos()
  for _ = 1, 30 do
    joypad.set({ [dir] = true }); emu.frameadvance(); scanFrame(tag)
    local x, y = F.pos()
    if x ~= x0 or y ~= y0 then break end
  end
  for _ = 1, 14 do joypad.set({ [dir] = true }); emu.frameadvance(); scanFrame(tag) end
  for _ = 1, 24 do joypad.set({}); emu.frameadvance(); scanFrame(tag) end
end

local function houseWalk(g, m, tag)
  local gh, gt, go = d3(g)
  local mh, mt, mo = d3(m)
  if not F.check(tag .. ": warp in", F.warpTo(gh, gt, go, mh, mt, mo, 0, 0, 0, g, m, tag)) then return end
  F.idle(40)
  local seed = g * 31 + m
  local dirs = { "Up", "Down", "Left", "Right" }
  scanStep("Up", tag); scanStep("Up", tag)
  for i = 1, 60 do
    seed = (seed * 1103515245 + 12345) % 2147483648
    scanStep(dirs[(seed >> 16) % 4 + 1], tag .. "_" .. i)
    if F.mapn() ~= m then break end
  end
  F.shot(tag .. "_end")
end

local function scriptMenuActive()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    if F.r8(a + S.Task.isActive) ~= 0 and (F.r32(a + S.Task.func) & 0xFFFFFFFE) == S.Task_HandleMultichoiceInput then return true end
  end
  return false
end
local FLOOR_MAP = { [0] = 4, 3, 2, 1, 0 }            -- elevator menu row -> Dept. Store map (5F..1F)
local spamKeys = { "A", "B", "Start", "Select", "Up", "Down", "L", "R" }
local spamSeed = 5
local function ride(row)
  local tag = "floor_row" .. row
  F.check(tag .. ": walk to the panel", F.route({ { 2, 4 }, { 0, 4 }, { 0, 3 } }, tag .. "_walk"), where())
  F.face("Up")
  F.press("A", 2)
  local live = false
  for _ = 1, 200 do if scriptMenuActive() then live = true; break end F.idle(2) end
  F.idle(10)
  F.check(tag .. ": the floor menu opens", live)
  for _ = 1, 12 do
    local c = F.mcur()
    if c == row then break end
    F.press(c > row and "Up" or "Down", 2); F.idle(10)
  end
  F.press("A", 2)
  local moving = 0
  for i = 1, 600 do
    if i > 30 and hasControl() then break end
    moving = moving + 1
    spamSeed = (spamSeed * 1103515245 + 12345) % 2147483648
    if i % 4 == 0 then F.press(spamKeys[(spamSeed >> 16) % #spamKeys + 1], 2) else F.idle(1) end
  end
  F.L(string.format("  %s: spammed for %d frames", tag, moving))
  F.check(tag .. ": control returns after the ride", settle(tag), where())
  for _ = 1, 3 do F.press("B", 2); F.idle(20) end
  F.check(tag .. ": walk to the doors", F.route({ { 2, 4 }, { 2, 5 } }, tag .. "_out"), where())
  F.press("Down", 8)
  for _ = 1, 300 do if F.ow() and F.mapn() ~= ELEVATOR_M then break end F.idle(2) end
  F.idle(60)
  F.check(tag .. ": the doors open on the chosen floor", F.grp() == DEPT_G and F.mapn() == FLOOR_MAP[row], where())
  F.step("Up")
  F.check(tag .. ": back into the elevator", waitMap(ELEVATOR_M), where())
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
local function useDoor(tag, flag)
  F.face("Left")
  F.press("A", 2)
  for _ = 1, 10 do F.idle(25); F.press("A", 2) end
  settle(tag)
  F.check(tag .. ": the Card Key opens it", flagSet(flag))
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  instantText()
  F.check("setup: a Venusaur follower", giveMon(SPECIES_VENUSAUR, 50))

  for _, h in ipairs({ { 72, 0, "cape_brink" }, { 66, 0, "three_house1" }, { 66, 4, "three_house2" }, { 66, 5, "three_house3" } }) do
    houseWalk(h[1], h[2], h[3])
  end
  F.check("draw order: frames scanned", scanned > 3000, "frames=" .. scanned)
  F.check("draw order: the follower never covers a player standing in front of it", inversions == 0, "frames=" .. inversions)

  F.check("warp to the Dept. Store 1F", F.warpTo(0, 4, 4, 0, 0, 0, 0, 0, 0, DEPT_G, 0, "dept"))
  instantText()
  F.check("walk into the elevator", F.route({ { 1, 14 }, { 1, 5 }, { 6, 5 }, { 6, 2 } }, "to_elev"), where())
  F.step("Up")
  F.check("in the elevator", waitMap(ELEVATOR_M), where())
  for _, row in ipairs({ 0, 3, 1, 4, 2, 0, 4 }) do ride(row) end

  F.w16(S.gSaveblock3 + S.SaveBlock3.regionVars + VERMILION_SCENE_SLOT * 2, 1)
  F.dbg(); F.sel(0); F.sel(1); F.idle(20)
  F.spin(d3(SILPH_G)); F.spin(0, 0, 4); F.spin(0, 0, 2)
  for i = 1, 3000 do
    F.idle(1)
    if i == 400 then F.shot("ss_anne_sailing") end
    if F.grp() == 37 and F.mapn() == 5 and hasControl() then break end
    if F.reportCrash("ss_anne") then break end
  end
  F.idle(60)
  F.check("S.S. Anne: the departure lands in Vermilion", F.grp() == 37 and F.mapn() == 5, where())
  F.check("S.S. Anne: the player walks on", F.step("Up") and F.step("Up"), where())
  F.idle(30)
  followerBeside("S.S. Anne: the follower comes back out beside the player")

  setflag(FLAG_HIDE_SILPH_ROCKETS)
  F.check("warp to Silph Co. 5F", F.warpTo(0, 3, 5, 0, 5, 1, 0, 0, 0, SILPH_G, SILPH_5F, "silph"))
  instantText()
  runScript({ 0x29, FLAG_HIDE_CARD_KEY & 0xFF, FLAG_HIDE_CARD_KEY >> 8, 0x44, ITEM_CARD_KEY & 0xFF, ITEM_CARD_KEY >> 8, 1, 0, 0x02 })
  F.check("Silph: walk to door 1", F.route({ { 28, 3 }, { 28, 6 }, { 17, 6 }, { 17, 8 }, { 10, 8 }, { 10, 9 }, { 9, 9 } }, "door1"), where())
  useDoor("Silph door 1", FLAG_SILPH_5F_DOOR_1)
  F.check("Silph: walk through door 1", F.step("Left") and F.step("Left") and F.step("Left"), where())
  local s = driveSave()
  F.check("Silph: save beyond the door", s == "done", s)
  for _ = 1, 8 do joypad.set({ A = true, B = true, Start = true, Select = true }); emu.frameadvance() end
  joypad.set({}); F.idle(60)
  F.check("Silph: continue", F.boot(nil, true) and F.grp() == SILPH_G and F.mapn() == SILPH_5F, where())
  F.idle(60)
  F.shot("silph_continued")
  F.check("Silph: door 1 stays open after Continue", F.step("Right") and F.step("Right") and F.step("Right") and F.step("Right"), where())
  F.check("Silph: walk to door 2", F.route({ { 10, 18 }, { 9, 18 } }, "door2"), where())
  useDoor("Silph door 2", FLAG_SILPH_5F_DOOR_2)
  F.check("Silph: walk to the west pad", F.route({ { 6, 18 }, { 6, 21 }, { 2, 21 } }, "pad"), where())
  F.step("Up")
  F.check("Silph: the pad lands on 3F", waitMap(SILPH_3F) and F.grp() == SILPH_G, where())
  local moved = false
  for _, dir in ipairs({ "Down", "Right", "Left", "Up", "Down", "Right" }) do
    if F.step(dir) then moved = true; F.idle(10); if F.step(dir) then break end end
  end
  F.check("Silph: walk off the pad", moved, where())
  F.idle(30)
  F.shot("silph_3f")
  followerBeside("Silph: the follower comes out beside the player on 3F")
  F.finish()
end)
