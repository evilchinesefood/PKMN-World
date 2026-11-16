-- Kanto's Cycling Road: enter through the Route 16 gate on foot (the gate puts the player on the
-- bike), try to get off with Select (FRLG refuses on the road), ride down onto Route 17, where the
-- slope carries the bike to its foot, save there from the Start menu, soft reset and continue.
-- After Continue the player must be on the same tile, still on the bike, with the same music and
-- control. The Hub Pass then leaves the road, and the road's flag must be cleared with the rest of
-- Fly's field state.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/CyclingRoadSaveContinue.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "CyclingRoadSaveContinue")

local HUB = { 100, 0 }
local GATE, ROUTE16, ROUTE17 = { 59, 1 }, { 37, 34 }, { 37, 35 }
local ITEM_BICYCLE = 706
local ITEM_HUB_PASS = 893
local FLAG_SYS_ON_CYCLING_ROAD = 0xDC6
local FLAG_GOT_BICYCLE = 0xA40 + 0x271
local MUS_RG_CYCLING = 494
local AVATAR_BIKE = 0x02 | 0x04
local USM_ICO_SAVE = 7
local SENTINEL = 0xFFFF
local CONTEXT_RUNNING = 0

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function mapIs(m) return F.grp() == m[1] and F.mapn() == m[2] end
local function flagGet(id) return (F.r8(F.sb1() + S.SaveBlock1.flags + id // 8) >> (id % 8)) & 1 == 1 end
local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function warp(g, m, w, tag)
  local gh, gt, go = d(g)
  local mh, mt, mo = d(m)
  local wh, wt, wo = d(w)
  return F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, g, m, tag)
end
local SCRIPT_BUF = S.gStringVar4 + 960
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
  F.idle(20)
end
local function createMon(species, level)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(b, species); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for _ = 1, 4 do le16(b, 0) end
  b[#b + 1] = 0x02
  runScript(b)
end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function onBike() return F.r8(S.gPlayerAvatar) & AVATAR_BIKE ~= 0 end
local function playingSong()
  local hdr = F.r32(S.gMPlayInfo_BGM)
  if hdr == 0 then return 0 end
  for id = 0, 900 do if F.r32(S.gSongTable + id * 8) == hdr then return id end end
  return -1
end
local function waitSong(want)
  for _ = 1, 240 do if playingSong() == want then return true end; F.idle(1) end
  return playingSong() == want
end
local function ride(dir, n)
  for _ = 1, n do
    local x0, y0 = F.pos()
    for _ = 1, 40 do
      joypad.set({ [dir] = true }); emu.frameadvance()
      local x, y = F.pos()
      if x ~= x0 or y ~= y0 then break end
    end
  end
  F.idle(20)
end
local function driveSave(holdB)
  F.w16(S.gSaveAttemptStatus, SENTINEL)
  if holdB then
    -- B holds the bike in place on the slope ("Press B to stay in place"); Start comes with it.
    for _ = 1, 60 do joypad.set({ B = true }); emu.frameadvance() end
    for _ = 1, 2 do joypad.set({ B = true, Start = true }); emu.frameadvance() end
    F.idle(60)
  else
    F.press("Start", 2); F.idle(60)
  end
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
local function slopePulls(tag)
  local _, y0 = F.pos()
  F.idle(90)
  local _, y1 = F.pos()
  F.check(tag .. ": the slope pulls the bike down", y1 > y0, string.format("y %d -> %d", y0, y1))
end

F.run(function()
  if not F.boot(HUB[1]) then F.check("boot", false); F.finish(); return end
  createMon(25, 30)
  runScript({ 0x44, ITEM_BICYCLE & 0xFF, ITEM_BICYCLE >> 8, 1, 0, 0x02 })
  runScript({ 0x44, ITEM_HUB_PASS & 0xFF, ITEM_HUB_PASS >> 8, 1, 0, 0x02 })
  F.w8(F.sb1() + S.SaveBlock1.flags + FLAG_GOT_BICYCLE // 8,
    F.r8(F.sb1() + S.SaveBlock1.flags + FLAG_GOT_BICYCLE // 8) | (1 << (FLAG_GOT_BICYCLE % 8)))
  F.w16(F.sb1() + S.SaveBlock1.registeredItem, ITEM_BICYCLE)
  -- Every Kanto trainer already beaten, so the road's bikers stand still and the ride is not cut
  -- short by a challenge.
  for i = 0, 79 do F.w8(F.sb3() + S.SaveBlock3.kantoTrainerFlags + i, 0xFF) end

  F.check("gate: warped to the Route 16 gate's east door", warp(GATE[1], GATE[2], 3, "gate"), where())
  F.idle(40)
  F.check("gate: walked across the gate on foot", F.leg(2, 12), where())
  F.press("Left", 30)
  for _ = 1, 300 do if mapIs(ROUTE16) and hasControl() then break end; F.idle(1) end
  F.check("route16: out on the Cycling Road", mapIs(ROUTE16), where())
  F.idle(60)
  F.check("route16: the gate put the player on the bike", onBike(), string.format("avatar=%02X", F.r8(S.gPlayerAvatar)))
  F.check("route16: the cycling music plays", waitSong(MUS_RG_CYCLING), "song=" .. playingSong())
  F.shot("route16_on_bike")

  -- FRLG refuses to let the player off the bike on the Cycling Road.
  F.press("Select", 2); F.idle(90)
  F.shot("route16_select_bike")
  for _ = 1, 10 do if hasControl() then break end; F.press("B", 2); F.idle(30) end
  F.check("route16: Select does not take the player off the bike here", onBike(),
    string.format("avatar=%02X", F.r8(S.gPlayerAvatar)))
  if not onBike() then F.press("Select", 2); F.idle(90) end

  ride("Left", 7); ride("Down", 7)
  for _ = 1, 600 do if mapIs(ROUTE17) then break end; joypad.set({ Down = true }); emu.frameadvance() end
  F.check("route17: rode onto the slope", mapIs(ROUTE17), where())
  F.idle(10)
  slopePulls("route17")
  -- Start is ignored while the slope carries the bike, so the save is made where it stops.
  for _ = 1, 300 do if hasControl() then break end; F.idle(1) end
  F.press("B", 2); F.idle(30)
  local songBefore = playingSong()
  local status = driveSave()
  F.check("route17: saved at the foot of the slope", status == "done", status)
  local gx, gy = F.pos()
  local saved = where()
  F.L(string.format("  at save: avatar=%02X savedMusic=%d song=%d", F.r8(S.gPlayerAvatar), F.r16(F.sb1() + 0x2C), songBefore))
  F.shot("route17_saved")

  softReset(); F.idle(60)
  F.check("continue: reached the field", F.boot(nil, true))
  F.idle(30)
  F.check("continue: same map and tile", where() == saved, where() .. " vs " .. saved)
  F.check("continue: still on the bike", onBike(), string.format("avatar=%02X", F.r8(S.gPlayerAvatar)))
  F.check("continue: the music playing at the save plays again", waitSong(songBefore), "song=" .. playingSong())
  F.shot("continue_slope")
  local ctl = false
  for _ = 1, 600 do if hasControl() then ctl = true; break end; F.idle(1) end
  F.L(string.format("  after continue: control=%s avatar=%02X lock=%d ctx=%d cb2=%08X savedMusic=%d", tostring(ctl),
    F.r8(S.gPlayerAvatar), F.r8(S.sLockFieldControls), F.r8(S.sGlobalScriptContextStatus), F.cb2(),
    F.r16(F.sb1() + 0x2C)))
  F.check("continue: control returns", ctl)
  F.L(string.format("  saved at (%d,%d)", gx, gy))
  for _ = 1, 600 do if hasControl() then break end; F.idle(1) end
  F.idle(120)

  -- Leaving the road any other way than its gates (the Hub Pass runs Fly's reset) must give the
  -- player back the right to get off the bike.
  F.w16(F.sb1() + S.SaveBlock1.registeredItem, ITEM_HUB_PASS)
  joypad.set({ B = true }); F.idle(10)
  F.press("Select", 2); F.idle(90)
  F.shot("hub_pass_prompt")
  for _ = 1, 30 do
    F.press("Up", 2); F.idle(6); F.press("A", 2); F.idle(30)
    if mapIs(HUB) then break end
  end
  for _ = 1, 400 do if mapIs(HUB) and hasControl() then break end; F.idle(1) end
  F.check("hub: the Hub Pass left the road", mapIs(HUB), where())
  F.check("hub: the Cycling Road flag is cleared", not flagGet(FLAG_SYS_ON_CYCLING_ROAD))
  F.finish()
end)
