-- A party holding nothing but an Egg must not walk into a battle it cannot fight.
--
-- A Hub gate boxes the whole party, and a gift Egg can then become the only party member.
-- Eggs count toward the party size, so guards written as "party size is 0" let an Egg-only
-- party through. This suite builds that party with the debug Give Egg (ScriptGiveEgg, the call
-- gift scripts use), stands on Route 29, and walks into a generated overworld encounter. The
-- contact and everything after it are the game's own code. The encounter must not start a battle
-- with no usable Pokemon, the game must not crash, and the player must get control back.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/OweEggOnlyParty.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "OweEggOnlyParty")

local CONTEXT_SHUTDOWN = 2
local SPECIES_TOGEPI = 175
local OE = S.ObjectEvent
local OWE_FIRST, OWE_LAST = 249, 252

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0
    and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end

local function task(fn)
  for j = 0, 15 do
    local t = S.gTasks + j * 40
    if F.r8(t + 4) ~= 0 and (F.r32(t) & ~1) == (fn & ~1) then return t end
  end
end

local function giveEgg(species)
  F.dbg(); F.idle(30)
  for _ = 1, 3 do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(50)
  for _ = 1, 3 do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(80)
  local t = task(S.DebugAction_Give_Pokemon_SelectId)
  if t then F.w16(t + 8 + 6, species); F.idle(4); F.press("A", 3); F.idle(40) end
  for _ = 1, 8 do F.press("B", 2); F.idle(20) end
  return t ~= nil
end

local function playerObj() return S.gObjectEvents + F.r8(S.gPlayerAvatar + 5) * OE.stride end

local function findOWE()
  for i = 0, 15 do
    local b = S.gObjectEvents + i * OE.stride
    local id = F.r8(b + OE.localId)
    if F.r8(b) & 1 == 1 and id >= OWE_FIRST and id <= OWE_LAST then return b end
  end
end

local function placeAt(b, x, y)
  for _, off in ipairs({ OE.x - 4, OE.x, OE.x + 4 }) do
    F.w16(b + off, x + 7); F.w16(b + off + 2, y + 7)
  end
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  F.check("a fresh game starts with no party", F.r8(S.gPartiesCount) == 0, "party=" .. F.r8(S.gPartiesCount))
  F.check("debug Give Egg ran", giveEgg(SPECIES_TOGEPI))
  F.check("the party is one Egg", F.r8(S.gPartiesCount) == 1, "party=" .. F.r8(S.gPartiesCount))
  -- MAP_ROUTE29 = (2 | (75 << 8)), warp 0
  F.check("warp to Route 29", F.warpTo(0, 7, 5, 0, 0, 2, 0, 0, 0, 75, 2, "route29"))
  F.idle(60)
  F.check("a free field on arrival", hasControl())

  local owe
  for k = 1, 60 do
    F.w8(S.sOWESpawnCountdown, 0)
    owe = findOWE()
    if owe then break end
    F.step(k % 2 == 0 and "Left" or "Right")
  end
  F.check("a generated encounter spawned", owe ~= nil)
  if not owe then F.finish(); return end

  F.check("stand on the path below the gate", F.leg(34, 12), string.format("(%d,%d)", F.pos()))
  local px, py = F.pos()
  placeAt(owe, px, py + 1)
  F.idle(2)
  local sawScript, sawBattle, crashed = false, false, false
  -- The encounter keeps wandering, so hold it on the tile until the player's step reaches it.
  for f = 1, 60 do
    if hasControl() then placeAt(owe, px, py + 1) end
    joypad.set({ Down = true }); emu.frameadvance()
    if F.r32(S.gSpecialVar_LastTalked) & 0xFFFF == F.r8(owe + OE.localId) and not hasControl() then sawScript = true; break end
  end
  joypad.set({})
  F.check("walking into it started the encounter script", sawScript)

  local back = false
  for f = 1, 3000 do
    if f % 15 == 0 then F.press("B", 2) else F.idle(1) end
    if not F.ow() then sawBattle = true end
    if f % 60 == 0 and F.reportCrash("egg_only_" .. f) then crashed = true; break end
    if f > 120 and hasControl() then back = true; break end
  end
  F.shot("after_contact")
  F.check("no crash screen", not crashed)
  F.check("no battle with an Egg-only party", not sawBattle,
    string.format("cb2=%08X battlers=%d outcome=%d", F.cb2(), F.battlers(), F.outcome()))
  F.check("the player has control again", back,
    string.format("cb2=%08X lock=%d script=%d", F.cb2(), F.r8(S.sLockFieldControls), F.r8(S.sGlobalScriptContextStatus)))
  F.finish()
end)
