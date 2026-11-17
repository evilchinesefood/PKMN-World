-- Map-name pop-up stress after #636 left src/map_name_popup.c Gen 8 only. In all three regions the
-- player walks back and forth across an outdoor map seam (Oldale/Route 103, Lavender/Route 10, New
-- Bark/Route 29) as fast as real steps allow, so each new pop-up arrives while the last one is still
-- sliding. Then a debug warp lands mid pop-up, and the pop-up is shown over rain (Olivine), a
-- thunderstorm (Lake of Rage) and falling ash (Mt Chimney). After every burst the pop-up task must
-- end on its own and leave the field's window registers as the map loader set them: WINOUT 0x0101,
-- WIN0H 0x00FF and BG0HOFS 0. A pop-up must also start for each new outdoor map. Screenshots are
-- taken while each pop-up is fully on screen. `--rtc 1704164400` runs it at 22:00 in-game.
--
-- Run via test/overworld/mgba-run.sh [--rtc <epoch>] test/overworld/lua/MapPopupStress.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "MapPopupStress")

local HUB_GROUP = 100
local REG_WINOUT = 0x0400004A
local WINOUT_FIELD = 0x0101
local GPU_WIN0H, GPU_BG0HOFS = 0x40, 0x10

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function warp(g, m, w, tag)
  local gh, gt, go = d(g)
  local mh, mt, mo = d(m)
  local wh, wt, wo = d(w)
  return F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, g, m, tag)
end

local function popupActive()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    if F.r8(a + S.Task.isActive) ~= 0 and (F.r32(a + S.Task.func) & ~1) == (S.Task_MapNamePopUpWindow & ~1) then
      return true
    end
  end
  return false
end
local function regs()
  return F.r16(REG_WINOUT), F.r16(S.sGpuRegBuffer + GPU_WIN0H), F.r16(S.sGpuRegBuffer + GPU_BG0HOFS)
end

-- Wait for the current pop-up to finish, then require the field registers back.
local function settle(tag)
  local frames = 0
  while popupActive() and frames < 900 do F.idle(1); frames = frames + 1 end
  F.idle(10)
  local winout, win0h, hofs = regs()
  F.check(tag .. ": the pop-up task ends by itself", not popupActive(), frames .. " frames")
  F.check(tag .. ": window registers are the field's again",
    winout == WINOUT_FIELD and win0h == 0x00FF and hofs == 0,
    string.format("WINOUT=%04X WIN0H=%04X BG0HOFS=%04X", winout, win0h, hofs))
  if F.reportCrash(tag) then F.check(tag .. ": no crash screen", false) end
end

-- A debug warp watched from the moment the destination is confirmed, since F.warpTo idles past the
-- whole pop-up. Returns arrived, popupSeen.
local function warpWatch(g, m, w, tag)
  F.dbg(); F.shot(tag .. "_debug_menu"); F.sel(0); F.sel(1); F.idle(20)
  F.spin(d(g)); F.spin(d(m)); F.spin(d(w))
  local seen, shotAt = false, nil
  for i = 1, 400 do
    if popupActive() and not seen then seen = true; shotAt = i + 45 end
    if shotAt and i == shotAt then F.shot(tag) end
    F.idle(1)
  end
  local arrived = F.grp() == g and F.mapn() == m
  F.check(tag .. ": warped in", arrived, string.format("%d/%d", F.grp(), F.mapn()))
  F.check(tag .. ": a pop-up starts", seen, string.format("%d/%d", F.grp(), F.mapn()))
  return arrived, seen
end

-- Watch a fresh arrival: the pop-up must start, and the shot is taken once it is fully on screen.
local function expectPopup(tag)
  local seen = false
  for _ = 1, 240 do if popupActive() then seen = true; break end; F.idle(1) end
  F.check(tag .. ": a pop-up starts", seen, string.format("%d/%d", F.grp(), F.mapn()))
  if seen then F.idle(45); F.shot(tag) end
  return seen
end

local CONTEXT_RUNNING = 0
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function awaitControl(budget)
  for i = 1, budget or 1200 do
    if hasControl() then return true end
    if i % 30 == 0 then F.press("B", 2) else F.idle(1) end
  end
  return hasControl()
end
local function walk(dir, n)
  for _ = 1, n do
    local moved = F.step(dir)
    for _ = 1, 6 do
      if moved then break end
      -- A wandering NPC can stand in the way; give it time to move on.
      awaitControl(); F.idle(60)
      moved = F.step(dir)
    end
    if not moved then F.shot("blocked_" .. dir); return false end
  end
  return true
end

-- Cross the seam between two maps `times` times, one step each way, without waiting.
local function thrash(tag, fwd, back, times, mapA, mapB)
  local onB, crossings = false, 0
  for i = 1, times do
    local dir = onB and back or fwd
    if not F.step(dir) then break end
    onB = not onB
    local want = onB and mapB or mapA
    if F.grp() == want[1] and F.mapn() == want[2] then crossings = crossings + 1 end
    if i == times // 2 then F.shot(tag .. "_mid_thrash") end
  end
  F.check(tag .. ": every step crossed the seam", crossings == times,
    string.format("%d of %d crossings, now %d/%d", crossings, times, F.grp(), F.mapn()))
  settle(tag .. " after " .. times .. " crossings")
end

local function seam(c)
  if not warp(c.grp, c.map, c.warp, c.tag) then
    F.check(c.tag .. ": warped in", false, string.format("%d/%d", F.grp(), F.mapn())); return
  end
  settle(c.tag .. " arrival")
  F.check(c.tag .. ": control after arriving", awaitControl(),
    string.format("lock=%d script=%08X", F.r8(S.sLockFieldControls), F.r32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr)))
  for _, leg in ipairs(c.path) do
    if not walk(leg[1], leg[2]) then
      local x, y = F.pos()
      F.check(c.tag .. ": walked to the seam", false, string.format("blocked going %s at (%d,%d)", leg[1], x, y)); return
    end
  end
  F.check(c.tag .. ": stepped across into " .. c.otherName, F.grp() == c.other[1] and F.mapn() == c.other[2],
    string.format("%d/%d", F.grp(), F.mapn()))
  expectPopup(c.tag .. "_" .. c.otherName)
  settle(c.tag .. " first crossing")
  F.step(c.back)
  expectPopup(c.tag .. "_back")
  thrash(c.tag, c.fwd, c.back, 10, { c.grp, c.map }, c.other)
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  F.idle(30)

  -- Oldale's first house door is warp 0 at (5,7); the exit step puts the player on (5,8). Route 101
  -- is avoided on purpose: before Birch's rescue its ON_FRAME script sets FLAG_HIDE_MAP_NAME_POPUP.
  seam({ tag = "hoenn", grp = 0, map = 10, warp = 0, path = { { "Right", 4 }, { "Up", 9 } },
    other = { 0, 18 }, otherName = "route103", fwd = "Up", back = "Down" })
  -- Lavender's Pokemon Center door is warp 1 at (6,5); the exit step puts the player on (6,6).
  -- Pallet is avoided on purpose: without a starter, its north exit runs Oak's lab scene.
  seam({ tag = "kanto", grp = 37, map = 4, warp = 1, path = { { "Right", 4 }, { "Up", 7 } },
    other = { 37, 28 }, otherName = "route10", fwd = "Up", back = "Down" })
  -- New Bark's player house door is warp 1 at (20,11); the exit step puts the player on (20,12).
  seam({ tag = "johto", grp = 75, map = 0, warp = 1, path = { { "Left", 21 } },
    other = { 75, 2 }, otherName = "route29", fwd = "Left", back = "Right" })

  -- A door warp while a pop-up is still on screen, with real input: leave Oldale's first house,
  -- and step straight back into its door while OLDALE TOWN slides in, then come out again.
  if warp(2, 0, 0, "oldale_house1") then
    awaitControl()
    local out = F.step("Down") and F.step("Down")
    for _ = 1, 120 do if F.grp() == 0 and F.mapn() == 10 then break end; joypad.set({ Down = true }); emu.frameadvance() end
    local up = false
    for _ = 1, 120 do if popupActive() then up = true; break end; F.idle(1) end
    F.check("door mid pop-up: OLDALE TOWN's pop-up starts on the way out", up, string.format("%d/%d", F.grp(), F.mapn()))
    F.idle(20)
    F.shot("door_mid_popup_before")
    for _ = 1, 60 do joypad.set({ Up = true }); emu.frameadvance(); if F.grp() == 2 then break end end
    for _ = 1, 120 do if F.grp() == 2 and F.mapn() == 0 then break end; F.idle(1) end
    F.check("door mid pop-up: the door warp took the player back inside", F.grp() == 2 and F.mapn() == 0,
      string.format("%d/%d", F.grp(), F.mapn()))
    settle("door mid pop-up, indoors")
    awaitControl()
    for _ = 1, 120 do if F.grp() == 0 and F.mapn() == 10 then break end; joypad.set({ Down = true }); emu.frameadvance() end
    up = false
    for _ = 1, 120 do if popupActive() then up = true; break end; F.idle(1) end
    F.check("door mid pop-up: the pop-up starts again outside", up)
    F.idle(45); F.shot("door_mid_popup_again")
    settle("door mid pop-up, outside again")
  end

  for _, w in ipairs({
    { "olivine_rain", 87, 0, 1 },
    { "lake_of_rage_thunder", 91, 4, 1 },
    { "mt_chimney_ash", 24, 12, 2 },
  }) do
    if warpWatch(w[2], w[3], w[4], w[1]) then settle(w[1]) end
    awaitControl()
  end
  F.finish()
end)
