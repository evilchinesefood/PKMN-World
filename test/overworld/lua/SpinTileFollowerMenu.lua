-- A Start menu opened on the frame a spin tile stops the player, with a Pokemon following, could
-- freeze the game once the menu closed.
--
-- PlayerGoSpin (the FRLG spin tiles in Rocket Hideout and Viridian Gym) leaves COPY_MOVE_WALK_FAST
-- as the player's copyable movement. The follower's handler for it, like those for WALK_FASTER,
-- SLIDE, JUMP and JUMP_IN_PLACE, was a copy-the-player NPC routine: it took its direction from
-- GetCopyDirection with the follower's directionSequenceIndex, which is 0 for a follower, so the
-- direction was DIR_NONE, and GetCollisionAtCoords then called
-- gOppositeDirectionBlockedMetatileFuncs[-1], the word 7 in front of the table, sending the CPU into
-- the BIOS. The player's next step normally replaces the copyable movement first, and the follower
-- stays hidden while the forced-move flag is up, so it takes a menu opened on the landing frame
-- plus a screen that rebuilds the field (the Trainer Card here), which drops the flag but keeps
-- the copyable movement. Found by ChaosWalk mashing through the hideout.
--
-- With a Lapras following, the suite walks into Rocket Hideout B2F and steps Left onto the spinner
-- at (16,6), which carries the player through five more spinners to the stop tile (1,4). Start is
-- pressed on alternate frames once the player reaches (1,4), and both press phases are tried until
-- the menu opens on the landing frame with the spin's copyable movement still set. Cases: the menu
-- closed straight away (control), and the Trainer Card opened from it and backed out of, then the
-- menu closed. After each close the game must keep running (the play-time counter advances), the
-- player must step off the tile and the follower must come back next to the player.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/SpinTileFollowerMenu.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SpinTileFollowerMenu")

local HUB_GROUP = 100
local OBJ_EVENT_ID_FOLLOWER = 0xFE
local SPECIES_LAPRAS = 131
local COPY_MOVE_WALK_FAST = 3
local VAR_REPEL_STEP_COUNT = 0x4021
local USM_ICO_TRAINER = 5

local SCRIPT_BUF = S.gStringVar4 + 960
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, 0)
  F.idle(20)
end
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function setVar(id, v) local b = { 0x16 }; le16(b, id); le16(b, v); b[#b + 1] = 0x02; runScript(b) end
local function createMon(species, level)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(b, species); le16(b, level)
  le32(b, 0)
  b[#b + 1] = 0x02
  runScript(b)
end

local function playerObj() return S.gObjectEvents + F.r8(S.gPlayerAvatar + 5) * S.ObjectEvent.stride end
local function copyable() return F.r8(playerObj() + 0x22) end
local function playTime()
  local sb2 = F.sb2()
  return F.r8(sb2 + 0x11) * 60 + F.r8(sb2 + 0x12)
end
local function follower()
  for i = 0, 15 do
    local o = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(o) & 1) ~= 0 and F.r8(o + 8) == OBJ_EVENT_ID_FOLLOWER then return o end
  end
end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == 2
end

-- (16,6) spins the player left, then up at (11,6), left at (11,4), (9,4), (7,4) and (3,4), onto
-- the stop tile (1,4): a ride long enough that the follower has gone back into its ball.
local START_X, START_Y, STOP_X, STOP_Y = 17, 6, 1, 4
local function toStart(tag)
  if not F.warpTo(0, 3, 5, 0, 4, 3, 0, 0, 0, 35, 43, tag) then return false end
  setVar(VAR_REPEL_STEP_COUNT, 0x7FFF)
  F.idle(30)
  return F.route({ { 21, 5 }, { 17, 5 }, { START_X, START_Y } }, tag)
end

-- Ride to the stop tile, pressing Start on alternate frames (phase 0 or 1) once the player is on
-- it, until field controls lock. Returns where and with which copyable movement the menu opened.
local function rideAndOpen(phase)
  for i = 1, 300 do
    local t = {}
    if i <= 20 then t.Left = true end
    local px, py = F.pos()
    if px == STOP_X and py == STOP_Y and (i + phase) % 2 == 0 then t.Start = true end
    joypad.set(t)
    emu.frameadvance()
    if F.r8(S.sLockFieldControls) ~= 0 then
      local x, y = F.pos()
      joypad.set({})
      return true, x, y, copyable()
    end
  end
  joypad.set({})
  return false, -1, -1, -1
end

local function closeMenu()
  for _ = 1, 3 do F.press("B", 2); F.idle(20) end
end

local function afterClose(tag)
  local t0 = playTime()
  F.idle(120)
  local t1 = playTime()
  F.check(tag .. ": the game keeps running after the menu closes", t1 ~= t0, string.format("play time %d -> %d", t0, t1))
  local ok = false
  for _ = 1, 60 do if hasControl() then ok = true; break end F.idle(5) end
  F.check(tag .. ": control returns", ok, string.format("lock=%d script=%d", F.r8(S.sLockFieldControls), F.r8(S.sGlobalScriptContextStatus)))
  local stepped = F.step("Left")
  local x, y = F.pos()
  F.check(tag .. ": the player steps off the stop tile", stepped and x == STOP_X - 1 and y == STOP_Y, string.format("(%d,%d)", x, y))
  F.step("Up"); F.idle(40)
  local f = follower()
  local shown = f and ((F.r8(f + 1) >> 5) & 1) == 0
  local fx, fy = f and F.rs16(f + S.ObjectEvent.x) - 7 or -1, f and F.rs16(f + S.ObjectEvent.y) - 7 or -1
  local px, py = F.pos()
  F.check(tag .. ": the follower is back next to the player", shown and math.abs(fx - px) + math.abs(fy - py) == 1,
    string.format("follower (%d,%d) shown=%s player (%d,%d)", fx, fy, tostring(shown), px, py))
  F.shot(tag:gsub("%W", "_") .. "_after")
end

local function case(tag, inMenu)
  F.L("== " .. tag .. " ==")
  local opened, x, y, copy = false, -1, -1, -1
  for attempt = 0, 3 do
    if not toStart(tag) then F.check(tag .. ": reached the spinner run", false, string.format("(%d,%d)", F.pos())); return end
    if attempt == 0 then F.check(tag .. ": a follower is out", follower() ~= nil) end
    opened, x, y, copy = rideAndOpen(attempt % 2)
    F.L(string.format("  attempt %d: opened=%s at (%d,%d) copyable=%d", attempt, tostring(opened), x, y, copy))
    if opened and x == STOP_X and y == STOP_Y and copy == COPY_MOVE_WALK_FAST then break end
    if opened then closeMenu(); F.idle(60) end
  end
  F.check(tag .. ": the menu opened on the landing frame of the spin",
    opened and x == STOP_X and y == STOP_Y and copy == COPY_MOVE_WALK_FAST, string.format("(%d,%d) copyable=%d", x, y, copy))
  F.shot(tag:gsub("%W", "_") .. "_open")
  if inMenu then inMenu() end
  closeMenu()
  afterClose(tag)
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  createMon(SPECIES_LAPRAS, 50)
  F.check("a Lapras is in the party", F.r8(S.gPartiesCount) >= 1)

  case("menu closed at once")
  case("trainer card from the menu", function()
    F.idle(30)
    F.check("trainer card from the menu: the Trainer Card icon is on the menu", F.selectStartIcon(USM_ICO_TRAINER))
    F.press("A", 2); F.idle(120)
    F.press("B", 2); F.idle(150)
  end)
  F.finish()
end)
