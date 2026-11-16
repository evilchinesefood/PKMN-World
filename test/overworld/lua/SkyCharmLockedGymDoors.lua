-- Cinnabar's and Viridian's gym doors are locked only by a coord trigger on the tile in front of
-- them, which turns the player back until the Secret Key (Cinnabar) or the seventh badge (Viridian).
-- The Sky Charm, which Kanto unlocks at the third badge, skips coord events while flying, and it
-- could land on that very tile, so one press of Up walked into the gym. A landing now refuses a
-- tile whose coord trigger would fire there. With Kanto's third badge and the Sky Charm, the suite
-- flies to each door, tries to land in front of it, then lands beside that tile and walks in.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/SkyCharmLockedGymDoors.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SkyCharmLockedGymDoors")

local HUB = 100
local CINNABAR, CINNABAR_GYM = { 37, 8 }, { 46, 0 }
local VIRIDIAN, VIRIDIAN_GYM = { 37, 1 }, { 39, 1 }
local ITEM_SKY_CHARM = 891
local FLAG_KANTO_BADGE_3 = 0xA40 + 0x0D
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2

local function mapIs(m) return F.grp() == m[1] and F.mapn() == m[2] end
local function flying() return F.r8(S.sFlightActive) ~= 0 end
local function where()
  local x, y = F.pos()
  return string.format("%d/%d (%d,%d) flying=%s", F.grp(), F.mapn(), x, y, tostring(flying()))
end
local function flagSet(id) local a = F.sb1() + S.SaveBlock1.flags + id // 8; F.w8(a, F.r8(a) | (1 << (id % 8))) end
local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function warp(m, w, tag)
  local gh, gt, go = d(m[1]); local mh, mt, mo = d(m[2]); local wh, wt, wo = d(w)
  return F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, m[1], m[2], tag)
end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local SCRIPT_BUF = S.gStringVar4 + 960
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
  for _ = 1, 200 do
    F.idle(4)
    if hasControl() then break end
  end
  F.idle(30)
end
local function move(dir)
  local x0, y0 = F.pos()
  local g0, m0 = F.grp(), F.mapn()
  for _ = 1, 30 do
    joypad.set({ [dir] = true }); emu.frameadvance()
    local x, y = F.pos()
    if x ~= x0 or y ~= y0 or F.grp() ~= g0 or F.mapn() ~= m0 then F.idle(24); return true end
  end
  F.idle(10)
  return false
end
local function skyCharm()
  F.press("Select", 2); F.idle(150)
  for _ = 1, 10 do
    if hasControl() then break end
    F.press("B", 2); F.idle(40)
  end
  F.idle(20)
end
local function flyTo(tx, ty)
  for _ = 1, 80 do
    local x, y = F.pos()
    if x == tx and y == ty then return true end
    if x < tx then move("Right") elseif x > tx then move("Left")
    elseif y < ty then move("Down") else move("Up") end
  end
  local x, y = F.pos()
  return x == tx and y == ty
end
-- Walk up into the door and wait for whatever answers: the gym's map or the lock's script.
local function walkUp()
  for _ = 1, 40 do joypad.set({ Up = true }); emu.frameadvance() end
  for _ = 1, 400 do
    if hasControl() then break end
    if F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_SHUTDOWN then F.press("B", 2) end
    F.idle(10)
  end
  F.idle(60)
end

-- side: where to land beside the lock tile ("Down" lands south of it, "Left" west of it), and the
-- way back onto it.
local BACK = { Down = "Up", Left = "Right" }
local function door(town, gym, doorX, doorY, side, tag)
  F.check(tag .. ": warped into town", warp(town, 0, tag), where())
  F.idle(30)
  skyCharm()
  F.check(tag .. ": took off", flying(), where())
  F.check(tag .. ": flew to the tile in front of the gym door", flyTo(doorX, doorY + 1), where())
  skyCharm()
  F.shot(tag .. "_land_at_door")
  F.check(tag .. ": the Sky Charm refuses to land on the door's lock tile", flying(), where())
  if not flying() then
    walkUp()
    F.shot(tag .. "_walked_in")
    F.check(tag .. ": the gym stays locked", not mapIs(gym), where())
    return
  end
  move(side)
  skyCharm()
  F.check(tag .. ": landed beside the lock tile", not flying(), where())
  if side ~= "Down" then move(BACK[side]) end
  walkUp()
  F.shot(tag .. "_walk_up")
  F.check(tag .. ": walking up meets the lock", not mapIs(gym), where())
end

F.run(function()
  if not F.boot(HUB) then F.check("boot", false); F.finish(); return end
  flagSet(FLAG_KANTO_BADGE_3)
  runScript({ 0x44, ITEM_SKY_CHARM & 0xFF, ITEM_SKY_CHARM >> 8, 1, 0, 0x02 })
  F.w16(F.sb1() + S.SaveBlock1.registeredItem, ITEM_SKY_CHARM)
  door(CINNABAR, CINNABAR_GYM, 20, 4, "Down", "cinnabar")
  door(VIRIDIAN, VIRIDIAN_GYM, 36, 10, "Left", "viridian")
  F.finish()
end)
