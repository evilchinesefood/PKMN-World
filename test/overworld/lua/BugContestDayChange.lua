-- The Bug-Catching Contest across day changes, on the emulator's running RTC.
--
-- The contest is once per day: its end sets FLAG_DAILY_BUG_CONTEST_COMPLETED (0829014ec0), both
-- attendants refuse while it is set, and ClearDailyFlags clears it when DoTimeBasedEvents sees a
-- new day. The contest clock is a frame count (8 minutes), checked when the player steps.
--
-- One run, with the clock set to 23:38 as New Bark's wall clock sets it (the offset, not the RTC):
--   1. A contest before midnight, retired with a catch. Prize, parked party back, daily flag set,
--      the attendant refuses.
--   2. Save in the gate, wait there until the RTC passes midnight, soft reset and Continue the
--      pre-midnight save. The new day must clear the flag, and the attendant lets the player in.
--   3. That contest runs out its clock (the player walks until "Time's up"): the limit must fire
--      at 8 minutes of frames, then judging, prize, party, flag and refusal as above.
--   4. The local clock is wound to 23:57 two days on (the day change clears the flag), a third
--      contest starts, the RTC rolls over midnight while it runs, and its clock runs out. The new
--      day's flag must be set by the end and the attendant must refuse.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/BugContestDayChange.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BugContestDayChange")

local REGION_JOHTO = 2
local GATE_G, GATE_M = 83, 7
local CONTEST_G, CONTEST_M = 83, 5
local USM_ICO_SAVE = 7
local SENTINEL = 0xFFFF
local CONTEXT_RUNNING = 0
local FLAG_SYS_POKEMON_GET = 0x948
local FLAG_SYS_BUG_CONTEST_MODE = 0x948 + 0x21
local FLAG_SYS_CLOCK_SET = 2429
local VAR_DAYS, VAR_REPEL_STEP_COUNT = 0x4040, 0x4021
local VAR_BUG_CONTEST_STATE = 0xA080 + 0x0E
local DAILY_CONTEST_BIT = 0xC1
local LIMIT_FRAMES = 60 * 60 * 8
local SPECIES_WEEDLE = 13
local PRIZES = { 217, 216, 214, 211, 213, 212, 520, 514, 521, 516, 517, 518, 515 }

local function count() return F.r8(S.gPartiesCount) end
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function inContest() return F.grp() == CONTEST_G and F.mapn() == CONTEST_M end
local function atGate() return F.grp() == GATE_G and F.mapn() == GATE_M end
local function state() return F.r16(F.sb3() + S.SaveBlock3.regionVars + (VAR_BUG_CONTEST_STATE - 0xA000) * 2) end
local function vblank() return F.r32(S.gMain + 0x20) end
local function sb1Flag(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + (id // 8), 1 << (id % 8)
  if on == nil then return (F.r8(a) & m) ~= 0 end
  F.w8(a, on and (F.r8(a) | m) or (F.r8(a) & ~m & 0xFF))
end
local function var(id, v)
  local a = F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2
  if v == nil then return F.r16(a) end
  F.w16(a, v)
end
local function daily()
  return (F.r8(F.sb3() + S.SaveBlock3.johtoFlags + DAILY_CONTEST_BIT // 8) & (1 << (DAILY_CONTEST_BIT % 8))) ~= 0
end
local function setJohto()
  F.w32(S.gCurrentRegion, REGION_JOHTO)
  F.w8(F.sb2() + S.SaveBlock2.currentRegion, REGION_JOHTO)
end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0
    and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end

local function now()
  local t = S.gLocalTime
  return F.rs16(t + S.Time.days), F.rs8(t + S.Time.hours), F.rs8(t + S.Time.minutes), F.rs8(t + S.Time.seconds)
end
local function clock()
  local d, h, m, s = now()
  return string.format("day %d %02d:%02d:%02d", d, h, m, s)
end
-- gLocalTime = RTC - localTimeOffset; move the offset so the local clock reads the target.
local function windTo(days, h, m)
  local o = F.sb2() + S.SaveBlock2.localTimeOffset
  local function secs(d, hh, mm, ss) return ((d * 24 + hh) * 60 + mm) * 60 + ss end
  local d0, h0, m0, s0 = now()
  local off = secs(F.rs16(o), F.rs8(o + 2), F.rs8(o + 3), F.rs8(o + 4))
  local rtc = secs(d0, h0, m0, s0) + off
  local new = rtc - secs(days, h, m, 0)
  local nd = new // 86400
  local r = new - nd * 86400
  F.w16(o, nd & 0xFFFF); F.w8(o + 2, r // 3600); F.w8(o + 3, (r % 3600) // 60); F.w8(o + 4, r % 60)
end

local function bagQty(id)
  local key = F.r16(F.sb2() + S.SaveBlock2.encryptionKey)
  local n = 0
  for p = 0, 4 do
    local ptr = F.r32(S.gBagPockets + p * S.BagPocket.stride)
    for i = 0, F.pocketCap(p) - 1 do
      if F.r16(ptr + i * 4) == id then n = n + (F.r16(ptr + i * 4 + 2) ~ key) end
    end
  end
  return n
end
local function prizes() local n = 0; for _, id in ipairs(PRIZES) do n = n + bagQty(id) end; return n end

-- The parked party, identified by each member's first 32 bytes (personality, OT, nickname).
local function partyPrint()
  local t = { tostring(count()) }
  for i = 0, count() - 1 do
    local b = S.gParties + i * S.Pokemon.size
    for k = 0, 28, 4 do t[#t + 1] = string.format("%08X", F.r32(b + k)) end
  end
  return table.concat(t, ":")
end

local function text()
  local out = {}
  for i = 0, 160 do
    local c = F.r8(S.gStringVar4 + i)
    if c == 0xFF then break end
    if c >= 0xBB and c <= 0xD4 then out[#out + 1] = string.char(65 + c - 0xBB)
    elseif c >= 0xD5 and c <= 0xEE then out[#out + 1] = string.char(97 + c - 0xD5)
    else out[#out + 1] = " " end
  end
  return (table.concat(out):gsub("%s+", " "))
end

local function tapDown(n) for _ = 1, n do F.press("Down", 3); F.idle(16) end end
local function drain(tries)
  for i = 1, tries or 40 do
    F.press("B", 3); F.idle(20)
    if i % 5 == 0 and F.ensureFree() then return true end
  end
  return F.ensureFree()
end
local function give(sp)
  F.dbg(); F.idle(60)
  tapDown(3); F.press("A", 3); F.idle(50)
  tapDown(1); F.press("A", 3); F.idle(40)
  F.press("Right", 2); F.idle(10)
  for _ = 1, (sp // 10) % 10 do F.press("Up", 2); F.idle(8) end
  F.press("Left", 2); F.idle(10)
  for _ = 1, sp % 10 - 1 do F.press("Up", 2); F.idle(8) end
  F.press("A", 3); F.idle(30)
  F.press("A", 3); F.idle(80)
  for _ = 1, 10 do F.press("B", 3); F.idle(20) end
  drain(20)
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

-- Talk to the west attendant from (4,2). Returns "entered", or "refused" with the text seen.
local function talkAttendant()
  -- (5,2) is wall: come up from row 3.
  local x = F.pos()
  local reached = F.leg(x, 3) and F.leg(4, 3) and F.leg(4, 2)
  F.L("  to the attendant: reached=" .. tostring(reached) .. " at " .. where())
  F.face("Left"); F.press("A", 3); F.idle(40)
  local seen = ""
  for i = 1, 400 do
    local s = text()
    if s:find("Contest is over", 1, true) then seen = s end
    if inContest() and F.ow() then break end
    if seen ~= "" and hasControl() then break end
    F.press("A", 2); F.idle(18)
  end
  if inContest() then
    drain(30)
    return sb1Flag(FLAG_SYS_BUG_CONTEST_MODE) and "entered" or "inside_without_mode", seen
  end
  drain(20)
  return seen ~= "" and "refused" or "neither", seen
end

-- Walk two tiles back and forth until the contest's clock rings, then report the frames since
-- entry. The limit is checked on steps, so the player keeps stepping.
local function waitTimesUp(start, tag)
  local dirs = { "Left", "Right" }
  for i = 1, 4000 do
    if state() == 3 or text():find("Time s up", 1, true) then
      return vblank() - start
    end
    if F.reportCrash(tag) then return nil end
    var(VAR_REPEL_STEP_COUNT, 200)
    if not F.step(dirs[i % 2 + 1]) then F.press("A", 2); F.idle(20) end
  end
  return nil
end

-- From "Time's up" or a retire: choose party slot 1 (the catch), sit through judging and walk
-- back to the gate.
local function judgeAndReturn(tag)
  for _ = 1, 1500 do
    if atGate() and F.ow() and not sb1Flag(FLAG_SYS_BUG_CONTEST_MODE) and hasControl() then break end
    if F.reportCrash(tag .. "_judging") then return false end
    if F.cb2() == (S.CB2_UpdatePartyMenu & ~1) then
      F.idle(30); F.press("Down", 2); F.idle(20); F.press("A", 2); F.idle(40)
      if F.cb2() == (S.CB2_UpdatePartyMenu & ~1) then F.press("A", 2); F.idle(40) end
    else
      F.press("A", 2); F.idle(18)
    end
  end
  drain(30)
  return atGate() and not sb1Flag(FLAG_SYS_BUG_CONTEST_MODE)
end

local function contest(name, retire)
  local party0, prize0 = partyPrint(), prizes()
  local result, seen = talkAttendant()
  if not F.check(name .. ": the attendant lets the player in (" .. clock() .. ")", result == "entered", result .. " " .. seen) then
    return false
  end
  local start = F.r32(S.sBugContestStartTime)
  F.L("  entered " .. clock() .. " at " .. where())
  give(SPECIES_WEEDLE)
  F.check(name .. ": the catch joins the contest party", count() == 2, "count=" .. count())
  if retire then
    F.leg(13, 48); F.step("Down")
  else
    local frames = waitTimesUp(start, name)
    F.L(string.format("  time's up after %s frames at %s", tostring(frames), clock()))
    F.check(name .. ": the clock rings at 8 minutes of frames", frames ~= nil
      and frames >= LIMIT_FRAMES and frames < LIMIT_FRAMES + 600, tostring(frames))
  end
  F.check(name .. ": judging returns the player to the gate", judgeAndReturn(name), where())
  F.shot(name:gsub("[^%w]+", "_") .. "_back")
  F.check(name .. ": the parked party is back unchanged", partyPrint() == party0,
    "count=" .. count())
  F.check(name .. ": one prize reached the bag", prizes() == prize0 + 1, prize0 .. " -> " .. prizes())
  F.check(name .. ": the Safari Balls are gone", bagQty(23) == 0, "balls=" .. bagQty(23))
  F.check(name .. ": the day's flag is set", daily())
  local again, said = talkAttendant()
  F.check(name .. ": the attendant refuses a second contest today (" .. clock() .. ")",
    again == "refused" and said:find("Today", 1, true) ~= nil, again .. " " .. said)
  return true
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  setJohto()
  sb1Flag(FLAG_SYS_POKEMON_GET, true)
  F.dbg(); F.idle(60); tapDown(2); F.press("A", 3); F.idle(60); tapDown(9); F.press("A", 3); F.idle(240)
  drain(20)
  F.check("setup: debug Set Party ran", count() >= 1, "count=" .. count())
  -- What New Bark's wall clock leaves (InitTimeBasedEvents): the flag and today's day number.
  sb1Flag(FLAG_SYS_CLOCK_SET, true)
  windTo((now()), 23, 38)
  var(VAR_DAYS, (now()))
  F.L("  clock set at " .. clock())
  local day0 = now()
  local ok = F.warpTo(0, 8, 3, 0, 0, 7, 0, 0, 0, GATE_G, GATE_M, "gate")
  setJohto()
  if not F.check("warp to the National Park gate", ok, where()) then F.finish(); return end

  contest("before midnight", true)
  F.check("the first contest ended before midnight", (now()) == day0, clock())

  F.check("save in the gate", driveSave() == "done")
  for _ = 1, 400 do
    if (now()) ~= day0 then break end
    F.idle(300)
  end
  F.L("  midnight passed: " .. clock())
  for _ = 1, 8 do joypad.set({ A = true, B = true, Start = true, Select = true }); emu.frameadvance() end
  joypad.set({}); F.idle(60)
  if not F.check("continued the pre-midnight save", F.boot(GATE_G, true)) then F.finish(); return end
  F.idle(60)
  F.L("  continued at " .. clock() .. " days var=" .. var(VAR_DAYS))
  F.check("Continue on the new day clears the day's flag", not daily(), clock())
  F.check("Continue on the new day records it", var(VAR_DAYS) == (now()), var(VAR_DAYS) .. " vs " .. (now()))
  contest("after Continue", false)

  local d = now()
  windTo(d + 1, 23, 57)
  F.L("  wound to " .. clock())
  F.warpTo(1, 0, 0, 0, 0, 0, 0, 0, 0, 100, 0, "hub")
  ok = F.warpTo(0, 8, 3, 0, 0, 7, 0, 0, 0, GATE_G, GATE_M, "gate2")
  setJohto()
  F.check("back at the gate on the wound clock", ok, where())
  F.check("the wound day change clears the flag", not daily(), clock())
  local before = now()
  contest("across midnight", false)
  F.check("the third contest crossed midnight", (now()) == before + 1, clock())

  F.check("no crash", not F.crashScreen())
  F.finish()
end)
