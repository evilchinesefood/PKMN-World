-- A power cut on every frame of a save's flash write must load the previous save or the new one,
-- whole, and the next save must leave a clean file.
--
-- Each trial marks four places that sit in different flash sectors: SaveBlock2 (the seventh
-- player-name byte, sector 0), SaveBlock1 (the registered-item word and the player's tile),
-- the SaveBlock3 chunk (the last Johto flag byte) and the PC (the last box's wallpaper, the
-- last storage sector). It saves one marking from the Start menu, writes the other, saves again
-- and cuts the power when that write has run `off` frames, then boots and Continues. Every marker
-- must come back from the same save. A trial that kept the old save must say so on the main menu
-- only when the cut landed inside the write (SAVE_STATUS_ERROR, "previous save loaded"), and every
-- eighth trial saves once more after the recovery, reboots and must load that save with a clean
-- status.
--
-- PW_CUT_STEP=<n> (runner --env) samples every n-th frame offset (default 3, which fits the
-- default frame budget); PW_CUT_FROM / PW_CUT_TO bound the offsets. Every offset (PW_CUT_STEP=1)
-- needs about 650,000 frames: pass PW_MAX_FRAMES=1000000 as well.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/SaveWritePowerCut.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SaveWritePowerCut")

local HUB_GROUP = 100
local USM_ICO_SAVE = 7
local SENTINEL = 0xFFFF
local CONTEXT_SHUTDOWN = 2
local SAVE_STATUS_OK, SAVE_STATUS_ERROR = 1, 0xFF
local NAME_BYTE = 6
local JOHTO_FLAG_BYTE = S.SaveBlock3.johtoFlags + 127
local BOX_COUNT, BOX_SIZE = 14, 30
local WALLPAPERS = 4 + BOX_COUNT * BOX_SIZE * S.BoxPokemon.size + BOX_COUNT * 9
local STEP = tonumber(os.getenv("PW_CUT_STEP") or "") or 3
local FROM = tonumber(os.getenv("PW_CUT_FROM") or "") or 0
local TO = tonumber(os.getenv("PW_CUT_TO") or "")

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
           flag = F.r8(F.sb3() + JOHTO_FLAG_BYTE), wall = F.r8(wallpaperAddr()), x = x, y = y }
end
local function fmt(s)
  return string.format("name=%02X item=%04X flag=%02X wall=%d tile=(%d,%d)", s.name, s.item, s.flag, s.wall, s.x, s.y)
end
local function same(a, b)
  return a.name == b.name and a.item == b.item and a.flag == b.flag and a.wall == b.wall and a.x == b.x and a.y == b.y
end

-- Save from the Start menu; hook(frame) runs on each frame of the flash write and returns true to stop.
local function driveSave(hook)
  F.w16(S.gSaveAttemptStatus, SENTINEL)
  local c0 = F.r32(S.gSaveCounter)
  if not awaitControl(300) then return "nocontrol", 0 end
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_SAVE) then return "noicon", 0 end
  local writing = 0
  for i = 1, 3000 do
    local started = F.r32(S.gSaveCounter) ~= c0
    local done = F.r16(S.gSaveAttemptStatus) ~= SENTINEL
    if started and not done then
      if hook and hook(writing) then return "cut", writing end
      writing = writing + 1
    end
    if done then
      F.idle(30)
      for _ = 1, 6 do F.press("B", 2); F.idle(20) end
      return F.r16(S.gSaveAttemptStatus) == SAVE_STATUS_OK and "done" or "failed", writing
    end
    if i % 20 == 1 then joypad.set({ A = true }) else joypad.set({}) end
    emu.frameadvance()
  end
  return "timeout", writing
end

local function reboot(tag)
  client.reboot_core()
  F.idle(60)
  local ok = F.boot(nil, true)
  F.idle(30)
  if F.reportCrash(tag) then return false end
  return ok and awaitControl(600)
end

local function stepAside(n)
  local dir = (n % 2 == 0) and "Right" or "Left"
  if not F.step(dir) then F.step(dir == "Right" and "Left" or "Right") end
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  F.w16(F.sb2() + S.SaveBlock2.optionsU16, (F.r16(F.sb2() + S.SaveBlock2.optionsU16) & ~7) | 3)
  local walls = {}
  for i = 0, BOX_COUNT - 1 do walls[#walls + 1] = F.r8(F.r32(S.gPokemonStoragePtr) + WALLPAPERS + i) end
  F.L("  box wallpapers " .. table.concat(walls, ","))
  F.check("the wallpaper offset reads box wallpapers", walls[1] < 16 and walls[BOX_COUNT] < 16, table.concat(walls, ","))

  local status, span = driveSave()
  F.check("a full save measures the write", status == "done" and span > 0, status .. " span=" .. span)
  F.L(string.format("  the flash write spans %d frames", span))
  local last = TO or (span + 1)
  local tally = { old = 0, new = 0, mixed = 0 }
  local n = 0
  local offsets = {}
  for off = FROM, last, STEP do offsets[#offsets + 1] = off end
  if offsets[#offsets] ~= last then offsets[#offsets + 1] = last end
  for _, off in ipairs(offsets) do
    n = n + 1
    local tag = string.format("cut at frame %d", off)
    local v = 2 * off + 1
    mark(v)
    status = driveSave()
    if status ~= "done" then F.check(tag .. ": the first save landed", false, status); break end
    local old = read()
    stepAside(n)
    mark(v + 1)
    local new = read()
    status = driveSave(function(frame)
      if frame >= off then client.reboot_core(); return true end
      return false
    end)
    if not reboot(tag) then F.check(tag .. ": continued to the field", false); break end
    local got = read()
    local loaded = F.r16(S.gSaveFileStatus)
    local which = same(got, old) and "old" or (same(got, new) and "new" or "mixed")
    tally[which] = tally[which] + 1
    F.L(string.format("  %s (%s) -> %s status=%02X %s", tag, status, which, loaded, fmt(got)))
    F.check(tag .. ": one save came back whole", which ~= "mixed",
      "got " .. fmt(got) .. " old " .. fmt(old) .. " new " .. fmt(new))
    if which == "new" then
      F.check(tag .. ": the new save loads clean", loaded == SAVE_STATUS_OK, string.format("status=%02X", loaded))
    elseif status == "cut" and which == "old" then
      F.check(tag .. ": the old save loads as OK or as the previous save", loaded == SAVE_STATUS_OK or loaded == SAVE_STATUS_ERROR,
        string.format("status=%02X", loaded))
    end
    if n % 8 == 1 then
      mark(v + 2)
      local again = read()
      status = driveSave()
      F.check(tag .. ": a save after the recovery lands", status == "done", status)
      if not reboot(tag .. "_recovered") then F.check(tag .. ": continued after the recovery save", false); break end
      local back = read()
      F.check(tag .. ": the recovery save loads clean and whole", same(back, again) and F.r16(S.gSaveFileStatus) == SAVE_STATUS_OK,
        string.format("status=%02X %s", F.r16(S.gSaveFileStatus), fmt(back)))
    end
  end
  F.L(string.format("  trials=%d old=%d new=%d mixed=%d", n, tally.old, tally.new, tally.mixed))
  F.check("an early cut keeps the old save", tally.old > 0)
  F.check("a cut after the write keeps the new save", tally.new > 0)
  F.finish()
end)
