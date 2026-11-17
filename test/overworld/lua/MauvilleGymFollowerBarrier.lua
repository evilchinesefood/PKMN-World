-- A Mauville Gym switch turns electric barriers on. When the player stepped onto switch 2 from a
-- tile that one of those barriers covers, the following Pokemon was left standing on it, drawn
-- inside the beam, until the player's next step. Found by ChaosWalk.
--
-- With a Pikachu following, the suite walks into the gym from a fresh Hoenn state (switches
-- raised, VAR_MAUVILLE_GYM_STATE 0) and presses switch 2 at (4,12) twice with real input. West:
-- from (3,12), which the red vertical beam covers once the switch turns it on. Then switch 1 at
-- (0,15) puts the barriers back, and north: from (4,11), which the red horizontal beam covers.
-- After each press the barrier must be on under the follower's tile (control), the follower must
-- not be shown on that solid tile, and after one more step it must be back next to the player on a
-- passable tile. The gym trainers' defeat flags are set so their sight lines stay quiet.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/MauvilleGymFollowerBarrier.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "MauvilleGymFollowerBarrier")

local HUB_GROUP = 100
local OBJ_EVENT_ID_FOLLOWER = 0xFE
local SPECIES_PIKACHU = 25
local VAR_REPEL_STEP_COUNT = 0x4021
local VAR_MAUVILLE_GYM_STATE = 0x4093
local FLAG_MAUVILLE_GYM_BARRIERS_STATE = 0x63
local TRAINER_FLAGS_START = 0x500
local GYM_TRAINERS = { 191, 194, 323, 649, 802 } -- Kirk, Shawn, Ben, Vivian, Angelo
local METATILE_RedBeamV2_On = 0x249
local METATILE_RedBeamH3_On = 0x22A

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
local function setFlag(id) runScript({ 0x29, id & 0xFF, id >> 8, 0x02 }) end
local function setVar(id, v) local b = { 0x16 }; le16(b, id); le16(b, v); b[#b + 1] = 0x02; runScript(b) end
local function createMon(species, level)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(b, species); le16(b, level)
  le32(b, 0)
  b[#b + 1] = 0x02
  runScript(b)
end

local function var(id) return F.r16(F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2) end
local function flag(id) return (F.r8(F.sb1() + S.SaveBlock1.flags + (id >> 3)) >> (id & 7)) & 1 end
local function blockAt(x, y)
  local w = F.r32(S.gBackupMapLayout + S.BackupMapLayout.width)
  local p = F.r32(S.gBackupMapLayout + S.BackupMapLayout.map)
  return F.r16(p + 2 * ((x + 7) + (y + 7) * w))
end
local function solid(x, y) return ((blockAt(x, y) >> 10) & 3) ~= 0 end
local function follower()
  for i = 0, 15 do
    local o = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(o) & 1) ~= 0 and F.r8(o + 8) == OBJ_EVENT_ID_FOLLOWER then return o end
  end
end
local function followerState()
  local f = follower()
  if not f then return false, -1, -1 end
  return ((F.r8(f + 1) >> 5) & 1) == 0, F.rs16(f + S.ObjectEvent.x) - 7, F.rs16(f + S.ObjectEvent.y) - 7
end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == 2
end
local function waitControl()
  for _ = 1, 120 do if hasControl() then return true end F.idle(5) end
  return false
end

-- Step onto switch 2 from (fromX, fromY), the tile the barrier will cover, then check the follower.
local function pressFrom(tag, fromX, fromY, dir, barrier, nextDir)
  F.L("== " .. tag .. " ==")
  local px, py = F.pos()
  F.check(tag .. ": the player stands on the approach tile", px == fromX and py == fromY, string.format("(%d,%d)", px, py))
  local shown, fx, fy = followerState()
  F.check(tag .. ": the follower is out behind the player", shown and math.abs(fx - px) + math.abs(fy - py) == 1,
    string.format("follower (%d,%d) shown=%s", fx, fy, tostring(shown)))
  local before = var(VAR_MAUVILLE_GYM_STATE)
  F.step(dir)
  F.check(tag .. ": the switch script ran and released control", waitControl(),
    string.format("lock=%d script=%d", F.r8(S.sLockFieldControls), F.r8(S.sGlobalScriptContextStatus)))
  F.idle(60)
  px, py = F.pos()
  F.check(tag .. ": the player is on switch 2", px == 4 and py == 12, string.format("(%d,%d)", px, py))
  F.check(tag .. ": switch 2 was pressed", before ~= 2 and var(VAR_MAUVILLE_GYM_STATE) == 2,
    string.format("state %d -> %d", before, var(VAR_MAUVILLE_GYM_STATE)))
  F.check(tag .. ": the barrier is on over the approach tile", solid(fromX, fromY) and (blockAt(fromX, fromY) & 0x3FF) == barrier,
    string.format("block (%d,%d) = %04X", fromX, fromY, blockAt(fromX, fromY)))
  shown, fx, fy = followerState()
  F.shot(tag:gsub("%W", "_") .. "_pressed")
  F.check(tag .. ": the follower is not shown inside the barrier", not (shown and solid(fx, fy)),
    string.format("follower (%d,%d) shown=%s block=%04X", fx, fy, tostring(shown), fx >= 0 and blockAt(fx, fy) or 0))
  F.step(nextDir)
  F.idle(40)
  px, py = F.pos()
  shown, fx, fy = followerState()
  F.shot(tag:gsub("%W", "_") .. "_next_step")
  F.check(tag .. ": after one step the follower is back next to the player on a passable tile",
    shown and math.abs(fx - px) + math.abs(fy - py) == 1 and not solid(fx, fy),
    string.format("follower (%d,%d) shown=%s player (%d,%d)", fx, fy, tostring(shown), px, py))
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  createMon(SPECIES_PIKACHU, 30)
  F.check("a Pikachu leads the party", F.r8(S.gPartiesCount) >= 1)
  for _, id in ipairs(GYM_TRAINERS) do setFlag(TRAINER_FLAGS_START + id) end

  if not F.warpTo(0, 1, 0, 0, 0, 0, 0, 0, 0, 10, 0, "gym") then F.check("warped into Mauville Gym", false); F.finish(); return end
  setVar(VAR_REPEL_STEP_COUNT, 0x7FFF)
  F.check("the gym starts with every switch raised",
    var(VAR_MAUVILLE_GYM_STATE) == 0 and flag(FLAG_MAUVILLE_GYM_BARRIERS_STATE) == 0 and not solid(3, 12) and not solid(4, 11),
    string.format("state=%d alt=%d", var(VAR_MAUVILLE_GYM_STATE), flag(FLAG_MAUVILLE_GYM_BARRIERS_STATE)))

  F.check("walked to the west side of switch 2", F.route({ { 4, 16 }, { 2, 16 }, { 2, 12 }, { 3, 12 } }, "west"))
  pressFrom("west", 3, 12, "Right", METATILE_RedBeamV2_On, "Right")

  F.check("walked to switch 1", F.route({ { 5, 15 }, { 0, 15 } }, "switch1"))
  F.check("switch 1 put the barriers back", waitControl() and var(VAR_MAUVILLE_GYM_STATE) == 1
    and flag(FLAG_MAUVILLE_GYM_BARRIERS_STATE) == 0 and not solid(4, 11),
    string.format("state=%d alt=%d block(4,11)=%04X", var(VAR_MAUVILLE_GYM_STATE), flag(FLAG_MAUVILLE_GYM_BARRIERS_STATE), blockAt(4, 11)))

  F.check("walked to the north side of switch 2", F.route({ { 2, 13 }, { 5, 13 }, { 5, 11 }, { 4, 11 } }, "north"))
  pressFrom("north", 4, 11, "Down", METATILE_RedBeamH3_On, "Right")
  F.finish()
end)
