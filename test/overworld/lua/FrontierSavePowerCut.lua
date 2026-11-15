-- A power cut during a Battle Frontier save must never cost the player the save before it.
--
-- SaveGameFrontier saves through TrySavingData(SAVE_LINK), which rewrote the current save slot in
-- place. A cut inside that write left the slot torn, so the next boot fell back to the other slot:
-- the save made BEFORE the last one. Every trial saves twice from the Start menu in the hub with
-- distinct markers (the seventh player-name byte in SaveBlock2, the registered-item word and the
-- tile in SaveBlock1, the last Johto flag byte in the SaveBlock3 chunk and the last box's
-- wallpaper in the PC), writes a third marking, seeds a paused Battle Tower challenge the way
-- `tower_save` leaves it and warps into the Tower lobby, where the attendant's ResumeChallenge
-- script runs SaveGameFrontier. The power is cut when that write has run `off` frames; after the
-- reboot the game must load the second Start-menu save or the Frontier save, whole, never the
-- first one. The first trial runs the Frontier save to completion and measures it.
--
-- PW_FSP_OFFSETS=<n> (runner --env) sets how many cut offsets spread over the write (default 8).
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/FrontierSavePowerCut.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "FrontierSavePowerCut")

local HUB_GROUP = 100
local GRP_TOWER, MAP_TOWER = 26, 5
local USM_ICO_SAVE = 7
local SENTINEL = 0xFFFF
local CONTEXT_SHUTDOWN = 2
local SAVE_STATUS_OK = 1
local FLAG_SYS_GAME_CLEAR, FLAG_HOENN_CHAMPION = 0x94C, 0xA4A
local CHALLENGE_STATUS_SAVING, CHALLENGE_STATUS_PAUSED = 1, 2
local SB2_CHALLENGE_STATUS = S.SaveBlock2.frontierChallengeStatus
local SB2_CHALLENGE_FLAGS, SB2_SELECTED_MONS, SB2_CUR_BATTLE_NUM = SB2_CHALLENGE_STATUS + 1, SB2_CHALLENGE_STATUS + 2, SB2_CHALLENGE_STATUS + 10
local VAR_FRONTIER_BATTLE_MODE, VAR_FRONTIER_FACILITY, VAR_TEMP_CHALLENGE_STATUS = 0x40CE, 0x40CF, 0x4000
local LOCALID_SINGLES = 1
local NAME_BYTE = 6
local JOHTO_FLAG_BYTE = S.SaveBlock3.johtoFlags + 127
local BOX_COUNT, BOX_SIZE = 14, 30
local WALLPAPERS = 4 + BOX_COUNT * BOX_SIZE * S.BoxPokemon.size + BOX_COUNT * 9
local OFFSETS = tonumber(os.getenv("PW_FSP_OFFSETS") or "") or 8

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function awaitControl(budget)
  for i = 1, budget or 600 do
    if hasControl() then return true end
    if i % 30 == 0 then F.press("B", 2) else F.idle(1) end
  end
  return hasControl()
end
local function varAddr(id) return F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2 end
local function flagSet(id)
  local a = F.sb1() + S.SaveBlock1.flags + id // 8
  F.w8(a, F.r8(a) | (1 << (id % 8)))
end
local function challengeStatus() return F.r8(F.sb2() + SB2_CHALLENGE_STATUS) end

local function wallpaperAddr() return F.r32(S.gPokemonStoragePtr) + WALLPAPERS + BOX_COUNT - 1 end
local function mark(v)
  F.w8(F.sb2() + NAME_BYTE, 0xA1 + v % 10)
  F.w16(F.sb1() + S.SaveBlock1.registeredItem, 0x5A00 + v % 256)
  F.w8(F.sb3() + JOHTO_FLAG_BYTE, v % 256)
  F.w8(wallpaperAddr(), v % 16)
end
local function read()
  local x, y = F.pos()
  return { name = F.r8(F.sb2() + NAME_BYTE), item = F.r16(F.sb1() + S.SaveBlock1.registeredItem),
           flag = F.r8(F.sb3() + JOHTO_FLAG_BYTE), wall = F.r8(wallpaperAddr()), x = x, y = y,
           grp = F.grp(), map = F.mapn() }
end
local function fmt(s)
  return string.format("name=%02X item=%04X flag=%02X wall=%d at %d/%d (%d,%d)", s.name, s.item, s.flag, s.wall,
    s.grp, s.map, s.x, s.y)
end
local function marks(a, b) return a.name == b.name and a.item == b.item and a.flag == b.flag and a.wall == b.wall end
local function same(a, b) return marks(a, b) and a.grp == b.grp and a.map == b.map and a.x == b.x and a.y == b.y end

local function driveSave()
  F.w16(S.gSaveAttemptStatus, SENTINEL)
  if not awaitControl(300) then return "nocontrol" end
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_SAVE) then return "noicon" end
  for i = 1, 3000 do
    if F.r16(S.gSaveAttemptStatus) ~= SENTINEL then
      F.idle(30)
      for _ = 1, 6 do F.press("B", 2); F.idle(20) end
      return F.r16(S.gSaveAttemptStatus) == SAVE_STATUS_OK and "done" or "failed"
    end
    if i % 20 == 1 then joypad.set({ A = true }) else joypad.set({}) end
    emu.frameadvance()
  end
  return "timeout"
end

local function reboot(tag)
  F.idle(60)
  local ok = F.boot(nil, true)
  F.idle(30)
  if F.reportCrash(tag) then return false end
  return ok
end

local function toHub(tag)
  if F.grp() ~= HUB_GROUP and not F.warpTo(1, 0, 0, 0, 0, 0, 0, 0, 0, HUB_GROUP, 0, tag) then return false end
  F.w8(F.sb2() + SB2_CHALLENGE_STATUS, 0)
  F.w8(F.sb2() + SB2_CHALLENGE_FLAGS, F.r8(F.sb2() + SB2_CHALLENGE_FLAGS) & ~(1 << 2))
  return awaitControl(600)
end

local function seedPausedTower()
  F.w8(F.sb2() + SB2_CHALLENGE_STATUS, CHALLENGE_STATUS_PAUSED)
  F.w8(F.sb2() + SB2_CHALLENGE_FLAGS, (F.r8(F.sb2() + SB2_CHALLENGE_FLAGS) & 0xFC) | (1 << 2))
  for i = 0, 2 do F.w16(F.sb2() + SB2_SELECTED_MONS + i * 2, i + 1) end
  F.w16(F.sb2() + SB2_CUR_BATTLE_NUM, 1)
  F.w16(varAddr(VAR_FRONTIER_BATTLE_MODE), 0)
  F.w16(varAddr(VAR_FRONTIER_FACILITY), 0)
end

-- Warp into the Tower lobby and press A through ResumeChallenge; cut the power `off` frames into
-- the SAVE_LINK write (nil runs it to the end). Returns how far the write got and how it ended.
local function frontierSave(off, tag)
  F.w16(S.gSaveAttemptStatus, SENTINEL)
  F.dbg(); F.sel(0); F.sel(1); F.idle(20)
  F.spin(d(GRP_TOWER)); F.spin(d(MAP_TOWER)); F.spin(0, 0, 0)
  local writing = 0
  for i = 1, 3000 do
    if F.reportCrash(tag) then return "crash", writing end
    F.w16(S.gSpecialVar_LastTalked, LOCALID_SINGLES)
    local saving = challengeStatus() == CHALLENGE_STATUS_SAVING
    local done = F.r16(S.gSaveAttemptStatus) ~= SENTINEL
    if done then return F.r16(S.gSaveAttemptStatus) == SAVE_STATUS_OK and "done" or "failed", writing end
    if saving then
      if off and writing >= off then client.reboot_core(); return "cut", writing end
      writing = writing + 1
    end
    if F.grp() == GRP_TOWER and i % 30 == 0 then joypad.set({ A = true }) else joypad.set({}) end
    emu.frameadvance()
  end
  return "timeout", writing
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  F.w16(F.sb2() + S.SaveBlock2.optionsU16, (F.r16(F.sb2() + S.SaveBlock2.optionsU16) & ~7) | 3)
  F.dbg(); F.sel(2); F.sel(9); F.idle(120); F.bOut(6)
  for _, sp in ipairs({ { 2, 5, 7 }, { 2, 5, 4 } }) do
    F.dbg(); F.sel(3); F.sel(1); F.idle(20); F.spin(sp[1], sp[2], sp[3]); F.idle(20); F.spin(0, 5, 0); F.idle(60); F.bOut(4)
  end
  F.check("a party of three or more", F.r8(S.gPartiesCount) >= 3, "n=" .. F.r8(S.gPartiesCount))
  flagSet(FLAG_SYS_GAME_CLEAR); flagSet(FLAG_HOENN_CHAMPION)

  local span, trial = nil, 0
  local results = { first = 0, second = 0, frontier = 0, mixed = 0 }
  local offs = { false }
  while trial < #offs do
    trial = trial + 1
    local off = offs[trial] or nil
    local tag = off and string.format("cut at frame %d", off) or "uncut Frontier save"
    if not toHub(tag .. "_hub") then F.check(tag .. ": back in the hub", false); break end
    local v = 3 * trial
    mark(v)
    local st = driveSave()
    if st ~= "done" then F.check(tag .. ": the first Start-menu save landed", false, st); break end
    local first = read()
    if not F.step((trial % 2 == 0) and "Left" or "Right") then F.step("Down") end
    mark(v + 1)
    st = driveSave()
    if st ~= "done" then F.check(tag .. ": the second Start-menu save landed", false, st); break end
    local second = read()
    mark(v + 2)
    local frontier = read()
    seedPausedTower()
    local how, wrote = frontierSave(off, tag)
    F.L(string.format("  %s: the Frontier save %s after %d frames", tag, how, wrote))
    if not off then
      F.check(tag .. ": the Frontier save completed", how == "done", how)
      span = wrote
      F.L(string.format("  the SAVE_LINK write spans %d frames", span))
      if span < 2 then F.check("the Frontier save has a measurable write", false, "span=" .. span); break end
      for k = 0, OFFSETS - 1 do offs[#offs + 1] = (span * k) // OFFSETS end
      offs[#offs + 1] = span - 1
      client.reboot_core()
    else
      F.check(tag .. ": the power was cut inside the write", how == "cut", how)
    end
    if not reboot(tag) then F.check(tag .. ": continued after the cut", false); break end
    local got = read()
    local loaded = F.r16(S.gSaveFileStatus)
    local which = same(got, second) and "second" or (marks(got, frontier) and "frontier")
                  or (same(got, first) and "first") or "mixed"
    results[which] = results[which] + 1
    F.L(string.format("  %s -> %s status=%02X %s", tag, which, loaded, fmt(got)))
    F.check(tag .. ": the last save or the Frontier save came back whole", which == "second" or which == "frontier",
      "got " .. fmt(got) .. " | first " .. fmt(first) .. " | second " .. fmt(second))
    if not off then F.check(tag .. ": the completed Frontier save loads", which == "frontier", which) end
  end
  F.L(string.format("  trials=%d second=%d frontier=%d first=%d mixed=%d", trial, results.second, results.frontier,
    results.first, results.mixed))
  F.check("the cuts were spread over the write", trial >= 3, "trials=" .. trial)
  F.finish()
end)
