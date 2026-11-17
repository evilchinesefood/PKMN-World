-- Save then Continue in a Flash-dark cave, standing on the arrow warp the player arrived on.
--
-- Dark Cave's Route 31 mouth (14,20) is an arrow warp: the player lands on it and leaves by pressing
-- Down on it. Two cases, each saved from the Start menu and continued:
--   1. dark, on the warp tile (soft reset): the map, tile, facing, song, follower and the dark
--      flash level come back, and Down on the tile still leaves for Route 31;
--   2. after FLASH from the party menu (power cut): FLAG_SYS_USE_FLASH and the lit flash level
--      come back, the player walks, and leaving for Route 31 (outdoors) turns Flash off.
-- Setup: a Mew that knows FLASH, the Zephyr and Hive Badges, a Repel count.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "ContinueDarkCave")

local HUB_GROUP = 100
local USM_ICO_SAVE, USM_ICO_PARTY = 7, 1
local SENTINEL = 0xFFFF
local CONTEXT_RUNNING = 0
local PARTY_SIZE = 6
local REGION_JOHTO = 2
local SPECIES_MEW, MOVE_FLASH = 151, 148
local ROW_FLASH = 1
local FLAG_JOHTO_BADGE_1, FLAG_JOHTO_BADGE_2 = 0x63F8, 0x63F9
local FLAG_SYS_POKEMON_GET, FLAG_SYS_USE_FLASH = 0x948, 0x948 + 0x28
local VAR_REPEL_STEP_COUNT = 0x4021
local SB1_FLASH_LEVEL = 0x30
local OBJ_EVENT_ID_FOLLOWER = 0xFE
local DARK_CAVE = { g = 94, m = 16, w = 0 }
local MOUTH = { 14, 20 }
local ROUTE31 = { g = 75, m = 4 }

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function warp(dst, tag)
  local gh, gt, go = d(dst.g)
  local mh, mt, mo = d(dst.m)
  local wh, wt, wo = d(dst.w)
  return F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, dst.g, dst.m, tag)
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
local function createMon(species, level, moves)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = PARTY_SIZE
  le16(b, species); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for k = 1, 4 do le16(b, moves[k] or 0) end
  b[#b + 1] = 0x02
  runScript(b); F.idle(20)
  return F.r8(S.gPartiesCount)
end

local function flagAddr(n)
  if n >= 0x6000 then return F.sb3() + S.SaveBlock3.johtoFlags + (n - 0x6000) // 8 end
  return F.sb1() + S.SaveBlock1.flags + n // 8
end
local function setFlag(n) local a = flagAddr(n); F.w8(a, F.r8(a) | (1 << (n % 8))) end
local function getFlag(n) return (F.r8(flagAddr(n)) & (1 << (n % 8))) ~= 0 end
local function prep()
  F.w32(S.gCurrentRegion, REGION_JOHTO)
  F.w8(F.sb2() + S.SaveBlock2.currentRegion, REGION_JOHTO)
  F.w16(F.sb1() + S.SaveBlock1.vars + (VAR_REPEL_STEP_COUNT - 0x4000) * 2, 250)
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function awaitControl(budget)
  for i = 1, budget or 600 do
    if hasControl() then return true end
    if i % 30 == 0 then F.press("B", 2) else F.idle(1) end
  end
  return hasControl()
end
local function playerObj() return S.gObjectEvents + F.r8(S.gPlayerAvatar + 5) * S.ObjectEvent.stride end
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
  return last
end

local function snapshot()
  local x, y = F.pos()
  return { grp = F.grp(), map = F.mapn(), x = x, y = y, facing = facing(), song = settledSong(),
           follower = follower(), flash = getFlag(FLAG_SYS_USE_FLASH), level = F.r8(F.sb1() + SB1_FLASH_LEVEL),
           region = F.r8(F.sb2() + S.SaveBlock2.currentRegion) }
end
local function fmt(s)
  return string.format("%d/%d (%d,%d) face=%d song=%d follower=%s flash=%s level=%d region=%d",
    s.grp, s.map, s.x, s.y, s.facing, s.song, s.follower, tostring(s.flash), s.level, s.region)
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

local function inPartyMenu()
  local c = F.cb2()
  return c == S.CB2_UpdatePartyMenu or c == S.CB2_InitPartyMenu or c == S.CB2_PartyMenuFromStartMenu
end
local function useFlash(tag)
  setFlag(FLAG_SYS_POKEMON_GET)
  awaitControl(300)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_PARTY) then return false end
  F.press("A", 3)
  for _ = 1, 240 do
    F.idle(4)
    if inPartyMenu() then break end
  end
  if not inPartyMenu() then return false end
  F.idle(40)
  F.press("A", 3); F.idle(50)
  for _ = 1, ROW_FLASH do F.press("Down", 2); F.idle(12) end
  F.press("A", 3)
  for t = 1, 300 do
    F.idle(4)
    if t > 40 and hasControl() then break end
  end
  F.shot(tag)
  return getFlag(FLAG_SYS_USE_FLASH)
end

local function saveAndContinue(tag, how)
  local before = snapshot()
  F.L("  before " .. fmt(before))
  local saved = driveSave()
  F.check(tag .. ": saved from the Start menu", saved == "done", saved)
  awaitControl(300)
  if how == "power" then client.reboot_core() else softReset() end
  F.idle(60)
  local booted = F.boot(nil, true)
  F.check(tag .. ": continued to the field", booted)
  if not booted then return before, nil end
  F.idle(30)
  F.check(tag .. ": no crash", not F.reportCrash(tag))
  local after = snapshot()
  F.L("  after  " .. fmt(after))
  F.shot(tag .. "_continued")
  F.check(tag .. ": same map, tile and facing", after.grp == before.grp and after.map == before.map
    and after.x == before.x and after.y == before.y and after.facing == before.facing, fmt(after))
  F.check(tag .. ": same song", after.song == before.song, after.song .. " vs " .. before.song)
  F.check(tag .. ": same follower", after.follower == before.follower, after.follower .. " vs " .. before.follower)
  F.check(tag .. ": same Flash state and flash level", after.flash == before.flash and after.level == before.level,
    fmt(after))
  F.check(tag .. ": same region", after.region == before.region, after.region .. " vs " .. before.region)
  F.check(tag .. ": control returns", awaitControl(600))
  return before, after
end

local function leaveDown(tag)
  F.face("Down")
  for _ = 1, 4 do
    joypad.set({ Down = true }); F.idle(20)
    if F.grp() ~= DARK_CAVE.g or F.mapn() ~= DARK_CAVE.m then break end
  end
  joypad.set({})
  for _ = 1, 200 do
    if F.grp() ~= DARK_CAVE.g or F.mapn() ~= DARK_CAVE.m then break end
    F.idle(2)
  end
  awaitControl(400)
  F.shot(tag)
  return F.grp() == ROUTE31.g and F.mapn() == ROUTE31.m
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  prep()
  F.check("a Mew that knows FLASH leads", createMon(SPECIES_MEW, 50, { MOVE_FLASH }) == 1)
  setFlag(FLAG_SYS_POKEMON_GET)
  setFlag(FLAG_JOHTO_BADGE_1)
  setFlag(FLAG_JOHTO_BADGE_2)

  F.L("== dark, on the warp tile ==")
  F.check("warp into Dark Cave", warp(DARK_CAVE, "darkcave"), string.format("%d/%d", F.grp(), F.mapn()))
  prep()
  awaitControl(300)
  local x, y = F.pos()
  F.check("standing on the Route 31 mouth", x == MOUTH[1] and y == MOUTH[2], string.format("(%d,%d)", x, y))
  F.check("the cave is dark", not getFlag(FLAG_SYS_USE_FLASH))
  F.shot("dark_before")
  local before, after = saveAndContinue("dark_warp_tile", "soft")
  if after then
    F.check("dark_warp_tile: Down on the mouth leaves for Route 31", leaveDown("dark_left"),
      string.format("%d/%d", F.grp(), F.mapn()))
  end

  F.L("== lit by FLASH ==")
  F.check("warp back into Dark Cave", warp(DARK_CAVE, "darkcave2"), string.format("%d/%d", F.grp(), F.mapn()))
  prep()
  F.check("FLASH lights the cave", useFlash("flash_used"))
  F.check("the player walks off the mouth", F.step("Up"))
  before, after = saveAndContinue("lit", "power")
  if after then
    F.check("lit: the cave is still lit", after.flash and after.level == before.level, fmt(after))
    F.check("lit: the player walks", F.step("Down"))
    F.check("lit: Down on the mouth leaves for Route 31", leaveDown("lit_left"),
      string.format("%d/%d", F.grp(), F.mapn()))
    F.check("lit: Route 31 turns Flash off", not getFlag(FLAG_SYS_USE_FLASH))
  end
  F.finish()
end)
