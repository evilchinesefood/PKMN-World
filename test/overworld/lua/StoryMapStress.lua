-- Spam the Story destination map in every region and page at several story stages, including
-- sequence-broken ones and a post-champion save. Every visit must come back to the same Story
-- page, keep the heap and task count steady and leave save data untouched.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/StoryMapStress.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "StoryMapStress")

local function tap(k) F.press(k, 2); F.idle(90) end
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

local function flag(id, value)
  local address, bit = F.sb1() + S.SaveBlock1.flags + id // 8, 1 << (id % 8)
  local old = F.r8(address)
  F.w8(address, value and (old | bit) or (old & ~bit & 0xFF))
end

local function setVar(v, n)
  local addr = v >= 0xa000 and F.sb3() + S.SaveBlock3.regionVars + (v - 0xa000) * 2
    or F.sb1() + S.SaveBlock1.vars + (v - 0x4000) * 2
  F.w16(addr, n)
end

local function snapshot()
  local out = {}
  for _, range in ipairs({ { F.sb1() + S.SaveBlock1.flags + 4, 514 }, { F.sb3() + S.SaveBlock3.regionVars, 768 },
    { F.sb3() + S.SaveBlock3.johtoFlags, 128 }, { S.gParties, 600 }, { S.gPartiesCount, 1 },
    { F.sb2() + S.SaveBlock2.currentRegion, 1 }, { S.gCurrentRegion, 4 } }) do
    for i = 0, range[2] - 1 do out[#out + 1] = string.char(F.r8(range[1] + i)) end
  end
  return table.concat(out)
end

local function enter()
  tap("Start")
  assert(F.selectStartIcon(6), "Story missing from graphical menu")
  tap("A"); assert(inStory(), "Story renderer not entered")
end

local function close()
  for _ = 1, 4 do
    if F.ow() then break end
    tap("B")
  end
  for _ = 1, 10 do if F.ensureFree() then break end F.press("B", 2); F.idle(30) end
  return F.ow()
end

local KEYS = { "A", "Up", "Down", "Left", "Right", "L", "R", "Start", "Select", "A", "A" }
local seed = 11

local function spamMap(tag)
  local region, page = F.r8(S.sStoryRegion), F.r8(S.sStoryPage)
  F.press("A", 2)
  local left = false
  for _ = 1, 120 do
    F.idle(2)
    if not inStory() then left = true; break end
  end
  if not left then return false, "map did not open" end
  F.idle(60)
  for i = 1, 240 do
    seed = (seed * 1103515245 + 12345) % 2147483648
    if i % 2 == 0 then joypad.set({ [KEYS[seed % #KEYS + 1]] = true }) else joypad.set({}) end
    emu.frameadvance()
  end
  if F.reportCrash("map_" .. tag) then return false, "crash" end
  F.shot(tag)
  F.press("B", 4)
  for _ = 1, 200 do
    F.idle(2)
    if inStory() then break end
  end
  F.idle(60)
  if not inStory() then
    local tasks = {}
    for i = 0, S.Task.count - 1 do
      local t = S.gTasks + i * S.Task.stride
      if F.r8(t + S.Task.isActive) ~= 0 then tasks[#tasks + 1] = string.format("%08X", F.r32(t + S.Task.func)) end
    end
    local fade = {}
    for i = 0, 11 do fade[#fade + 1] = string.format("%02X", F.r8(0x02031fc8 + i)) end
    F.L(string.format("  stuck: cb2=%08X tasks=%s fade=%s", F.cb2(), table.concat(tasks, ","), table.concat(fade)))
    F.shot(tag .. "_stuck")
    for retry = 1, 5 do
      F.press("B", 4); F.idle(120)
      if inStory() then F.L("  recovered after B retry " .. retry); break end
    end
    return false, "did not return to Story"
  end
  if F.r8(S.sStoryRegion) ~= region or F.r8(S.sStoryPage) ~= page then
    return false, string.format("region %d->%d page %d->%d", region, F.r8(S.sStoryRegion), page, F.r8(S.sStoryPage))
  end
  return true, ""
end

local function sweep(stage)
  local before = snapshot()
  enter()
  local baseHeap = heap()
  local ok, visits = true, 0
  for region = 0, 2 do
    tap("A")
    for page = 0, 4 do
      if F.r8(S.sStoryPage) ~= page then break end
      local good, why = spamMap(string.format("%s_r%d_p%d", stage, region, page))
      visits = visits + 1
      if not good then
        ok = false
        F.L(string.format("  %s region %d page %d: %s", stage, region, page, why))
        break
      end
      tap("R")
      if F.r8(S.sStoryPage) == 0 then break end
    end
    if not ok then break end
    tap("B"); tap("Down")
  end
  F.check(stage .. ": every map visit returns to its Story page", ok, "visits=" .. visits)
  F.check(stage .. ": heap steady across visits", heap() == baseHeap, string.format("%d -> %d", baseHeap, heap()))
  F.check(stage .. ": field returns", close())
  local after, diff = snapshot(), ""
  for i = 1, #after do
    if after:byte(i) ~= before:byte(i) then diff = string.format("byte %d %02X->%02X", i - 1, before:byte(i), after:byte(i)); break end
  end
  F.check(stage .. ": save data untouched", after == before, diff)
end

F.run(function()
  assert(F.boot(100), "Fresh game did not boot")
  flag(0xDC7, true) -- FLAG_OPENED_START_MENU: the first Start press sets it, outside the Story code
  sweep("fresh_hub")

  F.w8(F.sb2() + S.SaveBlock2.introDoneBits, F.r8(F.sb2() + S.SaveBlock2.introDoneBits) | 7)
  setVar(0xa02e, 5); setVar(0xa081, 2); setVar(0x4092, 6)
  sweep("mid_story")

  for i = 0, 7 do flag(0x94F + i, true) end
  flag(0xA49, true)
  setVar(0xa02e, 0); setVar(0x4092, 0)
  sweep("sequence_broken")

  flag(0xA48, true); flag(0xA4A, true)
  sweep("all_champion")
  F.finish()
end)
