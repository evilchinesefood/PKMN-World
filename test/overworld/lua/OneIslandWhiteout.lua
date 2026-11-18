-- A whiteout after healing at One Island lands in front of the nurse, not on the Battle Girl.
--
-- One Island's Pokemon Center is the one FRLG Center whose nurse stands at x=5. pokefirered's
-- SetWhiteoutRespawnWarpAndHealerNpc (src/heal_location.c) puts the player at (5,4) there, (13,12)
-- at Indigo Plateau and (8,5) at home, and (7,4) everywhere else. This tree reads the cell from
-- src/data/heal_locations.json, which carried Indigo Plateau's and Pallet's cells but not One
-- Island's, so the default (7,4) put the player on the Battle Girl who stands there, two cells right
-- of the nurse.
--
-- The suite walks into the Center through its door (its ON_TRANSITION sets the respawn point),
-- loses a debug battle and follows the whiteout to the field. The player must stand on (5,4), on no
-- other object's cell, with control back and the party healed.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/OneIslandWhiteout.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "OneIslandWhiteout")

local HUB_GROUP = 100
local CONTEXT_RUNNING = 0
local SPECIES_ABRA = 63
local ONE_ISLAND = { g = 37, m = 12 }
local CENTER = { g = 64, m = 0 }
local VAR_ONE_ISLAND_CENTER_SCENE, SCENE_DONE = 0xA04F, 7
local ROW_PARTY_MENU, ROW_BATTLE = 2, 10
local B_OUTCOME_LOST = 2
local LOCALID_FOLLOWER, LOCALID_PLAYER = 0xFE, 0xFF
local MAP_OFFSET = 7
local OE = S.ObjectEvent

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0
    and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function awaitControl(budget)
  for i = 1, budget or 600 do
    if hasControl() then return true end
    if i % 30 == 0 then F.press("B", 2) else F.idle(1) end
  end
  return hasControl()
end
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function mapIs(t) return F.grp() == t.g and F.mapn() == t.m end

local SCRIPT_BUF = S.gStringVar4 + 960
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
  F.idle(20)
end
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function createMon(species, level)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(b, species); le16(b, level)
  le32(b, 0)
  b[#b + 1] = 0x02
  runScript(b)
end
local function setVar(var, value)
  local b = { 0x16 }; le16(b, var); le16(b, value); b[#b + 1] = 0x02
  runScript(b)
end

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function warp(t, w, tag)
  local gh, gt, go = d(t.g)
  local mh, mt, mo = d(t.m)
  local wh, wt, wo = d(w)
  return F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, t.g, t.m, tag) and awaitControl(600)
end
local function through(dir, dest, tag)
  for _ = 1, 6 do
    F.press(dir, 16)
    for _ = 1, 120 do
      if mapIs(dest) and hasControl() then F.idle(20); return true end
      F.idle(2)
    end
  end
  F.shot(tag .. "_nowarp")
  return false
end

local function healthy()
  local mon = S.gParties
  local hp, max = F.r16(mon + S.Pokemon.hp), F.r16(mon + S.Pokemon.maxHP)
  return max > 0 and hp == max, string.format("hp=%d/%d", hp, max)
end
local function zeroHp()
  local mon = S.gParties
  if F.r16(mon + S.Pokemon.maxHP) ~= 0 then F.w16(mon + S.Pokemon.hp, 0) end
  local n = math.min(F.battlers(), 4)
  for i = 0, n - 1 do F.w16(S.gBattleMons + i * S.BattlePokemon.size + S.BattlePokemon.hp, 0) end
end

-- Objects other than the player and the follower standing on the player's cell.
local function sharers()
  local px, py = F.pos()
  local out = {}
  for i = 0, 15 do
    local a = S.gObjectEvents + i * OE.stride
    local id = F.r8(a + OE.localId)
    if (F.r8(a) & 1) ~= 0 and id ~= LOCALID_PLAYER and id ~= LOCALID_FOLLOWER
       and F.rs16(a + OE.x) - MAP_OFFSET == px and F.rs16(a + OE.y) - MAP_OFFSET == py then
      out[#out + 1] = string.format("localId=%d gfx=%d", id, F.r16(a + OE.graphicsId))
    end
  end
  return out
end

local function whiteOut()
  F.dbg(); F.idle(60)
  for _ = 1, ROW_PARTY_MENU do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(60)
  for _ = 1, ROW_BATTLE do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(30)
  local started = false
  for _ = 1, 800 do
    F.idle(8)
    if not F.ow() then started = true; break end
  end
  F.check("the debug battle started", started, string.format("cb2=0x%08X", F.cb2()))
  if not started then return false end
  for _ = 1, 400 do if F.battlers() > 0 then break end; F.idle(4) end
  for t = 1, 3000 do
    F.w8(S.gBattleOutcome, B_OUTCOME_LOST)
    zeroHp()
    F.press("A", t % 3 == 0 and 2 or 1); F.idle(1)
    if F.ow() and mapIs(CENTER) and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_RUNNING then break end
    if t % 60 == 0 and F.reportCrash("whiteout_" .. t) then return false end
  end
  F.shot("whiteout_scene")
  return true
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  F.w16(F.sb2() + S.SaveBlock2.optionsU16, (F.r16(F.sb2() + S.SaveBlock2.optionsU16) & ~7) | 3)
  createMon(SPECIES_ABRA, 20)
  setVar(VAR_ONE_ISLAND_CENTER_SCENE, SCENE_DONE)
  awaitControl(300)
  F.check("setup: one Pokemon", F.r8(S.gPartiesCount) == 1, "party=" .. F.r8(S.gPartiesCount))

  local inside = warp(ONE_ISLAND, 0, "one_island_door") and F.step("Down") and through("Up", CENTER, "center")
  F.check("walked into the One Island Pokemon Center", inside, where())
  if not inside then F.finish(); return end
  F.check("the battle away from the Center", warp(ONE_ISLAND, 0, "outside") and F.step("Down"), where())

  if not whiteOut() then F.finish(); return end
  F.L(string.format("  whiteout: arrived %s sharing=[%s]", where(), table.concat(sharers(), "; ")))
  F.check("whiteout: back in the One Island Pokemon Center", mapIs(CENTER), where())
  local x, y = F.pos()
  F.check("whiteout: the player stands in front of the nurse at (5,4)", x == 5 and y == 4, where())
  local shared = sharers()
  F.check("whiteout: no other object stands on the player's cell", #shared == 0, table.concat(shared, "; "))

  F.check("whiteout: control returns after the nurse", awaitControl(1800), where())
  F.shot("after_heal")
  local ok, hp = healthy()
  F.check("whiteout: the nurse healed the party", ok, hp)
  F.check("whiteout: the player can walk", F.ensureFree(), where())
  F.finish()
end)
