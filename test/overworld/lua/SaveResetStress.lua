-- A save interrupted by a reset must load as either the old save or the new one, never as a
-- corrupt file, a new game, or a mix of the two.
--
-- Each round changes the money and the lead's nickname, saves from the Start menu, and resets at
-- a chosen moment: a power cut (core reset) on every frame the flash write spans, and the
-- A+B+Start+Select soft reset at the save prompt, during the write, after a warp, mid gate
-- crossing and after a battle. The reboot then continues the file and compares money, party
-- bytes and location against the two snapshots the round straddles.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/SaveResetStress.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SaveResetStress")

local HUB_GROUP = 100
local USM_ICO_SAVE = 7
local SENTINEL = 0xFFFF
local SAVE_OK, SAVE_ERROR = 1, 0xFF
local NICK = 8

local function setMoney(v)
  F.w32(F.sb1() + S.SaveBlock1.money, v ~ F.r32(F.sb2() + S.SaveBlock2.encryptionKey))
end

local function partyHash()
  local n = F.r8(S.gPartiesCount)
  local h = n
  for i = 0, n * S.Pokemon.size - 1, 4 do
    h = (h * 31 + F.r32(S.gParties + i)) & 0xFFFFFFFF
  end
  return h
end

local function snapshot()
  local x, y = F.pos()
  return { money = F.money(), party = partyHash(), n = F.r8(S.gPartiesCount),
           grp = F.grp(), map = F.mapn(), x = x, y = y }
end

local function fmt(s)
  if not s then return "nil" end
  return string.format("money=%d party=%08X n=%d at %d/%d (%d,%d)", s.money, s.party, s.n, s.grp, s.map, s.x, s.y)
end

local function same(a, b)
  return a.money == b.money and a.party == b.party and a.n == b.n
     and a.grp == b.grp and a.map == b.map and a.x == b.x and a.y == b.y
end

-- Each round gets its own money and lead nickname, so the two snapshots a reset straddles differ.
local function mark(k)
  setMoney(10000 + k)
  F.w8(S.gParties + NICK, 0xBB + (k % 26))
end

local function openSave()
  F.press("Start", 2); F.idle(60)
  return F.selectStartIcon(USM_ICO_SAVE)
end

-- Drive the Start-menu save, calling hook(frame, writing) every frame. A hook returning true
-- stops the drive (it has reset the machine). Returns "done", "stopped" or "timeout", plus the
-- number of frames the flash write spanned.
local function driveSave(hook)
  F.w16(S.gSaveAttemptStatus, SENTINEL)
  local c0 = F.r32(S.gSaveCounter)
  if not openSave() then return "noicon", 0 end
  local writing = 0
  for i = 1, 3000 do
    local started = F.r32(S.gSaveCounter) ~= c0
    local done = F.r16(S.gSaveAttemptStatus) ~= SENTINEL
    if started and not done then writing = writing + 1 end
    if hook and hook(i, started, done) then return "stopped", writing end
    if done then
      F.idle(30)
      for _ = 1, 6 do F.press("B", 2); F.idle(20) end
      return "done", writing
    end
    if i % 20 == 1 then joypad.set({ A = true }) else joypad.set({}) end
    emu.frameadvance()
  end
  return "timeout", writing
end

local function softReset(frames)
  for _ = 1, frames or 8 do
    joypad.set({ A = true, B = true, Start = true, Select = true }); emu.frameadvance()
  end
  joypad.set({})
end

local function reboot(tag)
  F.idle(60)
  local ok = F.boot(nil, true)
  F.idle(60)
  if F.reportCrash(tag) then return false end
  return ok
end

local function verifyLoad(tag, old, new)
  local status = F.r8(S.gSaveFileStatus)
  local s = snapshot()
  local which = (old and same(s, old)) and "old" or ((new and same(s, new)) and "new" or "neither")
  F.L(string.format("  [%s] status=%d loaded %s -> %s", tag, status, fmt(s), which))
  F.check(tag .. ": the save loaded", status == SAVE_OK or status == SAVE_ERROR, "status=" .. status)
  F.check(tag .. ": the file is the old or the new save", which ~= "neither",
    "loaded " .. fmt(s) .. " old " .. fmt(old) .. " new " .. fmt(new))
  return which, s
end

local function giveMon(h, t, o)
  F.dbg(); F.sel(3); F.sel(1); F.idle(20)
  F.spin(h, t, o); F.idle(20); F.spin(0, 2, 0); F.idle(60); F.bOut(4)
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  giveMon(2, 5, 4)
  giveMon(0, 2, 5)
  F.check("party of two", F.r8(S.gPartiesCount) == 2, "n=" .. F.r8(S.gPartiesCount))
  -- Instant text: the save dialog's pacing is shortest here.
  F.w8(F.sb2() + 0x14, (F.r8(F.sb2() + 0x14) & ~7) | 3)

  local k = 1
  mark(k)
  local status = driveSave()
  F.check("baseline save completed", status == "done" and F.r16(S.gSaveAttemptStatus) == SAVE_OK, status)
  local saved = snapshot()
  F.L("  baseline " .. fmt(saved))

  -- Measure the write: how many emulated frames sit between the counter bump and the result.
  k = k + 1; mark(k)
  local want = snapshot()
  local span
  status, span = driveSave()
  F.check("measured save completed", status == "done", status)
  F.L("  the flash write spans " .. span .. " frames")
  saved = want

  -- Power cut on every frame of the write, plus the frames either side of it.
  local offsets = {}
  for o = 0, span + 2, math.max(1, span // 20) do offsets[#offsets + 1] = o end
  for o = math.max(0, span - 3), span + 2 do offsets[#offsets + 1] = o end
  local counts = { old = 0, new = 0, neither = 0 }
  for _, off in ipairs(offsets) do
    k = k + 1; mark(k)
    local new = snapshot()
    local seen = -1
    status = driveSave(function(_, started)
      if not started then return false end
      seen = seen + 1
      if seen >= off then client.reboot_core(); return true end
      return false
    end)
    local tag = "power cut " .. off .. " frames into the write"
    if not reboot(tag) then
      F.check(tag .. ": rebooted to the field", false)
      break
    end
    local which, s = verifyLoad(tag, saved, new)
    counts[which] = counts[which] + 1
    saved = (which == "new") and new or saved
    if which == "neither" then saved = s end
  end
  F.L(string.format("  power cuts: old=%d new=%d neither=%d", counts.old, counts.new, counts.neither))
  F.check("a power cut early in the write keeps the old file", counts.old > 0 or span == 0)
  F.check("a cut after the write completes keeps the new file", counts.new > 0)

  -- Soft reset at the Yes/No prompt: nothing was written, the old file must load.
  k = k + 1; mark(k)
  local new = snapshot()
  status = driveSave(function(i)
    if i == 25 then softReset(); return true end
    return false
  end)
  if reboot("soft reset at the save prompt") then
    local which = verifyLoad("soft reset at the save prompt", saved, new)
    F.check("soft reset at the prompt keeps the old file", which == "old", which)
  end

  -- Soft reset held through the write: the write cannot be interrupted, the new file must load.
  k = k + 1; mark(k)
  new = snapshot()
  status = driveSave(function(_, started)
    if started then softReset(20); return true end
    return false
  end)
  if reboot("soft reset during the write") then
    local which = verifyLoad("soft reset during the write", saved, new)
    F.check("soft reset during the write keeps the new file", which == "new", which)
    if which == "new" then saved = new end
  end

  -- Soft reset in the Hub right after a completed save.
  k = k + 1; mark(k)
  new = snapshot()
  status = driveSave()
  F.check("hub save completed", status == "done", status)
  softReset()
  if reboot("soft reset in the hub after a save") then
    local which = verifyLoad("soft reset in the hub after a save", saved, new)
    F.check("hub reset keeps the fresh save", which == "new", which)
    if which == "new" then saved = new end
  end

  -- Soft reset during a warp's fade, on every few frames after the warp starts.
  for _, off in ipairs({ 5, 30, 90 }) do
    if not F.ensureFree() then F.dismiss(10) end
    k = k + 1; mark(k)
    new = snapshot()
    status = driveSave()
    if status == "done" then saved = new end
    F.dbg(); F.sel(0); F.sel(1); F.idle(20)
    F.spin(0, 0, 3); F.spin(0, 0, 0); F.spin(0, 0, 0)
    F.idle(off)
    softReset()
    local tag = "soft reset " .. off .. " frames into a warp"
    if reboot(tag) then
      local which = verifyLoad(tag, saved, nil)
      F.check(tag .. ": the pre-warp save loads", which == "old", which)
    end
  end

  -- Save right after a warp lands, then reset: the post-warp location must load.
  F.dbg(); F.sel(0); F.sel(1); F.idle(20)
  F.spin(0, 0, 3); F.spin(0, 0, 0); F.spin(0, 0, 0)
  F.idle(240)
  local landed = F.grp() ~= HUB_GROUP
  F.check("debug warp left the hub", landed, string.format("grp=%d map=%d", F.grp(), F.mapn()))
  if not F.ensureFree() then F.dismiss(10) end
  k = k + 1; mark(k)
  new = snapshot()
  status = driveSave()
  F.check("post-warp save completed", status == "done", status)
  softReset()
  if reboot("save after a warp") then
    local which = verifyLoad("save after a warp", saved, new)
    F.check("the post-warp save loads at the new map", which == "new", which)
    if which == "new" then saved = new end
  end

  -- Soft reset mid gate crossing: the crossing boxes the party in RAM before the warp, so a reset
  -- partway must bring back the hub save with the party still carried.
  for _, off in ipairs({ 1, 20, 60 }) do
    if F.grp() ~= HUB_GROUP then F.warpTo(1, 0, 0, 0, 0, 0, 0, 0, 0, HUB_GROUP, 0, "hub") end
    if not F.ensureFree() then F.dismiss(10) end
    k = k + 1; mark(k)
    new = snapshot()
    status = driveSave()
    if status == "done" then saved = new end
    local tag = "soft reset " .. off .. " frames into a gate crossing"
    if not F.route({ { 16, 4 }, { 11, 4 }, { 11, 3 } }, "gate") then
      F.check(tag .. ": reached the gate", false)
      break
    end
    F.face("Up")
    local boxed = -1
    for i = 1, 600 do
      if i % 16 == 1 then joypad.set({ A = true }) else joypad.set({}) end
      emu.frameadvance()
      if F.r8(S.gPartiesCount) == 0 and boxed < 0 then boxed = i end
      if boxed >= 0 and i - boxed >= off then break end
    end
    F.L(string.format("  %s: party boxed at frame %d, grp=%d", tag, boxed, F.grp()))
    F.check(tag .. ": the crossing boxed the party", boxed >= 0)
    softReset()
    if reboot(tag) then
      local which = verifyLoad(tag, saved, nil)
      F.check(tag .. ": the hub save loads with its party", which == "old" and F.r8(S.gPartiesCount) == 2, which)
    end
  end

  -- Save straight after a battle returns to the field, then reset.
  if not F.ensureFree() then F.dismiss(10) end
  F.dbg(); F.sel(0); F.sel(10)
  local fought = false
  for i = 1, 9000 do
    if F.battleFlags() ~= 0 and not F.ow() then fought = true end
    if fought and F.ow() then break end
    if F.reportCrash("battle") then break end
    if i % 12 == 1 then joypad.set({ A = true }) else joypad.set({}) end
    emu.frameadvance()
  end
  F.check("the scripted wild battle ran and returned to the field", fought and F.ow())
  F.idle(60)
  if not F.ensureFree() then F.dismiss(10) end
  k = k + 1; mark(k)
  new = snapshot()
  status = driveSave()
  F.check("post-battle save completed", status == "done", status)
  softReset()
  if reboot("save after a battle") then
    local which = verifyLoad("save after a battle", saved, new)
    F.check("the post-battle save loads", which == "new", which)
    if which == "new" then saved = new end
  end

  F.L(string.format("SUMMARY rounds=%d span=%d final %s", k, span, fmt(saved)))
  F.finish()
end)
