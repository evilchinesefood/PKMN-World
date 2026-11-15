-- Open every regional map surface from places the maps were never drawn for: World Transit, the
-- Battle Frontier, Sevii, caves and islands with no map section. At each stop the Story
-- destination map is opened once cleanly for a screenshot, then the Story, Fly and PokeNav maps
-- are opened with keys mashed through their fades. Each must come back to a settled field without
-- a crash screen or a heap change.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/RegionMapAnywhereStress.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "RegionMapAnywhereStress")

local FLAG_SYS_POKEMON_GET, FLAG_SYS_POKENAV_GET, FLAG_OPENED_START_MENU = 0x948, 0x94A, 0xDC7
local USM_POKENAV, USM_QUESTS = 3, 6
local VAR_REPEL_STEP_COUNT = 0x4021

local function flag(id, value)
  local address, bit = F.sb1() + S.SaveBlock1.flags + id // 8, 1 << (id % 8)
  local old = F.r8(address)
  F.w8(address, value and (old | bit) or (old & ~bit & 0xFF))
end

local function inStory() return (F.cb2() & ~1) == (S.CB2_Story & ~1) end

local function heap()
  local p, total = S.gHeap, 0
  for _ = 1, 1024 do
    assert(p >= S.gHeap and p < S.gHeap + 0x1c500, "heap link outside arena")
    assert(F.r16(p + 2) == 0xa3a3, "heap guard corrupted")
    if F.r16(p) & 1 ~= 0 then total = total + (F.r32(p + 4) & 0x3ffff) end
    p = F.r32(p + 12); if p == S.gHeap then return total end
  end
  error("heap chain does not terminate")
end

local seed = 23
local function mash(frames, keys)
  for i = 1, frames do
    seed = (seed * 1103515245 + 12345) % 2147483648
    if i % 2 == 0 then joypad.set({ [keys[seed % #keys + 1]] = true }) else joypad.set({}) end
    emu.frameadvance()
  end
end

local ALL = { "A", "B", "Start", "Select", "Up", "Down", "Left", "Right", "L", "R" }
local NO_A = { "B", "Start", "Select", "Up", "Down", "Left", "Right", "L", "R" }
local NAV = { "Start", "Select", "Up", "Down", "Left", "Right", "L", "R" }

local function settled()
  local function quiet() return F.ow() and F.r8(S.sGlobalScriptContextStatus) == 2 and F.r32(S.sUsmMemory) == 0 end
  if not quiet() then return false end
  F.idle(20)
  return quiet()
end

local function backToField(tag)
  for _ = 1, 40 do
    if F.reportCrash(tag) then return false end
    if settled() then return true end
    F.press("B", 2); F.idle(40)
  end
  F.shot(tag .. "_nofield")
  return false
end

local function setVar(v, n)
  local addr = v >= 0xa000 and F.sb3() + S.SaveBlock3.regionVars + (v - 0xa000) * 2
    or F.sb1() + S.SaveBlock1.vars + (v - 0x4000) * 2
  F.w16(addr, n)
end

local function waitLeaveStory()
  for _ = 1, 90 do
    if not inStory() then return true end
    F.idle(2)
  end
  return false
end

local function waitStory()
  for _ = 1, 150 do
    if inStory() then return true end
    if F.reportCrash("wait_story") then return false end
    F.idle(2)
  end
  return false
end

local function storyMap(tag)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_QUESTS) then F.L("  " .. tag .. ": Story icon missing"); F.press("B", 2); F.idle(30); return false end
  F.press("A", 2); F.idle(90)
  if not inStory() then F.shot(tag .. "_nostory"); return false end
  F.press("A", 2); F.idle(40)
  F.press("A", 2)
  if not waitLeaveStory() then F.shot(tag .. "_nomap"); return false end
  F.idle(60)
  F.shot(tag .. "_story_map")
  F.press("A", 2); F.idle(30)
  F.shot(tag .. "_story_info")
  F.press("B", 2)
  if not waitStory() then F.shot(tag .. "_noreturn"); return false end
  F.idle(30)
  F.press("A", 2)
  mash(36, ALL)
  if waitLeaveStory() then
    mash(160, ALL)
    if F.reportCrash(tag .. "_map") then return false end
  end
  F.press("B", 2)
  mash(30, { "B", "A", "Start", "Select" })
  return backToField(tag .. "_story")
end

local function flyMap(tag)
  F.dbg(); F.sel(0); F.sel(0)
  local opened = false
  for _ = 1, 120 do
    if F.cb2() == (S.CB2_FlyMap & ~1) then opened = true; break end
    if F.reportCrash(tag .. "_flyopen") then return false end
    F.idle(2)
  end
  if not opened then F.shot(tag .. "_nofly"); return backToField(tag .. "_flyfail") and false end
  mash(30, NAV)
  F.idle(60)
  mash(200, NAV)
  if F.reportCrash(tag .. "_fly") then return false end
  F.shot(tag .. "_fly_map")
  F.press("B", 2)
  mash(24, NO_A)
  return backToField(tag .. "_fly")
end

local function pokenavMap(tag)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_POKENAV) then F.L("  " .. tag .. ": PokeNav icon missing"); F.press("B", 2); F.idle(30); return false end
  F.press("A", 2); F.idle(150)
  F.press("A", 2)
  mash(40, NAV)
  F.idle(90)
  mash(200, NAV)
  if F.reportCrash(tag .. "_nav") then return false end
  F.shot(tag .. "_pokenav_map")
  F.press("B", 2)
  mash(30, NO_A)
  return backToField(tag .. "_nav")
end

local STOPS = {
  { "hub", nil },
  { "pallet", { 0, 3, 7, 0, 0, 0, 37, 0 } },
  { "cerulean_cave", { 0, 3, 5, 0, 7, 2, 35, 72 } },
  { "safari", { 0, 3, 5, 0, 6, 3, 35, 63 } },
  { "one_island", { 0, 3, 7, 0, 1, 2, 37, 12 } },
  { "new_bark", { 0, 7, 5, 0, 0, 0, 75, 0 } },
  { "ice_path", { 0, 9, 4, 0, 0, 7, 94, 7 } },
  { "littleroot", { 0, 0, 0, 0, 0, 9, 0, 9 } },
  { "granite_cave", { 0, 2, 4, 0, 0, 7, 24, 7 } },
  { "frontier", { 0, 2, 6, 0, 0, 4, 26, 4 } },
  { "faraway", { 0, 2, 6, 0, 5, 6, 26, 56 } },
  { "navel_rock", { 0, 2, 6, 0, 6, 6, 26, 66 } },
}

F.run(function()
  assert(F.boot(100), "Fresh game did not boot")
  flag(FLAG_OPENED_START_MENU, true)
  flag(FLAG_SYS_POKEMON_GET, true)
  flag(FLAG_SYS_POKENAV_GET, true)
  F.w8(F.sb2() + S.SaveBlock2.introDoneBits, F.r8(F.sb2() + S.SaveBlock2.introDoneBits) | 7)
  setVar(0xa02e, 5); setVar(0xa081, 2); setVar(0x4092, 6)
  F.dbg(); F.sel(2); F.sel(9); F.idle(120)
  for _ = 1, 10 do if F.ensureFree() then break end F.press("B", 3); F.idle(30) end
  for _, stop in ipairs(STOPS) do
    local tag, w = stop[1], stop[2]
    local arrived = true
    F.w16(F.sb1() + S.SaveBlock1.vars + (VAR_REPEL_STEP_COUNT - 0x4000) * 2, 250)
    if w then
      arrived = F.warpTo(w[1], w[2], w[3], w[4], w[5], w[6], 0, 0, 0, w[7], w[8], tag)
      if arrived then backToField(tag .. "_arrive") end
    end
    if not arrived then
      F.L("  SKIP " .. tag .. ": warp did not land")
    else
      F.shot(tag .. "_field")
      local baseHeap = heap()
      F.check(tag .. ": Story map returns to the field", storyMap(tag))
      F.check(tag .. ": Fly map returns to the field", flyMap(tag))
      F.check(tag .. ": PokeNav map returns to the field", pokenavMap(tag))
      F.check(tag .. ": menus leave the heap as they found it", heap() == baseHeap, string.format("%d -> %d", baseHeap, heap()))
    end
  end
  F.finish()
end)
