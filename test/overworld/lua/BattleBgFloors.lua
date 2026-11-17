-- Gym Leader battles draw the Leader stadium floor in every region.
--
-- PR #634 gave Leader battles the stadium art (BATTLE_ENVIRONMENT_LEADER). GetBattleEnvironmentOverride
-- picks it from the opponent's trainer class, so each region's Leader class must be listed there:
-- TRAINER_CLASS_LEADER (Hoenn), TRAINER_CLASS_LEADER_JOHTO and TRAINER_CLASS_LEADER_FRLG (Kanto).
-- A Leader whose class is missing falls through to the Gym map scene and fights on the same
-- building floor as the gym's junior trainers.
--
-- Each case warps beside the trainer, faces them and presses A, so the real talk or sight trigger
-- starts the battle. Oracle: BG palette banks 2-4 in gPlttBufferUnfaded equal the authored palette
-- the battle should select (Leader stadium for Leaders, the Gym building palette for a gym's
-- junior trainer). Both palettes are read from the ROM, so the check follows the art.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/BattleBgFloors.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BattleBgFloors")

local HUB_GROUP = 100
local CONTEXT_SHUTDOWN = 2
local PKMN_SIZE, OFF_HP = S.Pokemon.size, S.Pokemon.hp
local BP_STRIDE, BP_HP = S.BattlePokemon.size, S.BattlePokemon.hp
local BATTLE_TYPE_TRAINER = 0x8

local LEADER = { name = "StadiumLeader", addr = S.gBattleEnvironmentPalette_StadiumLeader }
local GYM = { name = "BuildingGym", addr = S.gBattleEnvironmentPalette_BuildingGym }

-- {tag, map group, map num, stand x, stand y, facing, expected palette}
local CASES = {
  { "hoenn_leader_roxanne", 11, 3, 5, 3, "Up", LEADER },
  { "johto_leader_bugsy", 81, 0, 11, 7, "Up", LEADER },
  -- Beating Brock marks his junior trainer beaten too, so the control fight comes first.
  { "kanto_gym_trainer_liam", 40, 2, 3, 9, "Up", GYM },
  { "kanto_leader_brock", 40, 2, 6, 6, "Up", LEADER },
}

local function giveMon(species)
  local h, t, o = species // 100, (species // 10) % 10, species % 10
  F.dbg(); F.sel(3); F.sel(1); F.idle(20)
  F.spin(h, t, o); F.idle(20); F.spin(0, 5, 0); F.idle(60); F.bOut(4)
end

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0
    and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end

local function pump(pred, key, frames, every)
  for i = 1, frames do
    if pred() then return true end
    if F.reportCrash("pump") then return false end
    if key and i % (every or 20) == 0 then F.press(key, 2) else F.idle(1) end
  end
  return pred()
end

local function warpToCoords(grp, map, x, y, tag)
  for _ = 1, 4 do
    F.dbg(); F.sel(0); F.sel(1); F.idle(20)
    F.spin(d(grp)); F.spin(d(map))
    F.press("A", 2)
    for _ = 1, 400 do
      F.w8(S.sWarpDestination + 2, 0xFF)
      F.w16(S.sWarpDestination + 4, x)
      F.w16(S.sWarpDestination + 6, y)
      F.idle(1)
      local px, py = F.pos()
      if F.ow() and F.grp() == grp and F.mapn() == map and px == x and py == y then
        F.idle(120)
        return true
      end
    end
    F.bOut(5)
  end
  F.shot(tag .. "_warpfail")
  return false
end

local function bgPaletteIs(pal)
  for i = 0, 47 do
    if F.r16(S.gPlttBufferUnfaded + 0x40 + i * 2) ~= F.r16(pal.addr + i * 2) then
      return false, string.format("color %d is %04X, %s has %04X", i,
        F.r16(S.gPlttBufferUnfaded + 0x40 + i * 2), pal.name, F.r16(pal.addr + i * 2))
    end
  end
  return true, pal.name
end

local function winBattle()
  for i = 0, 5 do
    local b = S.gParties + (6 + i) * PKMN_SIZE
    if F.r16(b + OFF_HP) ~= 0 then F.w16(b + OFF_HP, 0) end
  end
  F.w16(S.gBattleMons + BP_STRIDE + BP_HP, 0)
end

local function fight(c)
  local tag, grp, map, x, y, dir, want = c[1], c[2], c[3], c[4], c[5], c[6], c[7]
  if not F.check(tag .. ": stands beside the trainer", warpToCoords(grp, map, x, y, tag)) then return end
  F.face(dir)
  F.press("A", 2)
  local started = pump(function() return F.cb2() == (S.BattleMainCB2 & ~1) end, "A", 4000, 20)
  if not F.check(tag .. ": a trainer battle starts", started and (F.battleFlags() & BATTLE_TYPE_TRAINER) ~= 0,
    string.format("ow=%s battlers=%d flags=0x%X", tostring(F.ow()), F.battlers(), F.battleFlags())) then
    F.shot(tag .. "_nostart")
    return
  end
  F.idle(360)
  F.shot(tag)
  local ok, detail = bgPaletteIs(want)
  F.check(tag .. ": battlefield draws the " .. want.name .. " palette", ok, detail)
  winBattle()
  F.check(tag .. ": control returns after the battle", pump(hasControl, "A", 6000, 15))
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot", false); F.finish(); return end
  F.check("palette symbols exported", LEADER.addr ~= nil and GYM.addr ~= nil)
  giveMon(258)
  F.check("a Pokemon in the party", F.r8(S.gPartiesCount) >= 1, "n=" .. F.r8(S.gPartiesCount))
  for _, c in ipairs(CASES) do fight(c) end
  F.finish()
end)
