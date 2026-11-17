-- Champion and legendary battles draw the backgrounds #634 gave them.
--
-- GetBattleEnvironmentOverride (src/battle_bg.c) picks the Champion stadium for each region's
-- Champion class and the Groudon, Kyogre and Rayquaza backgrounds for those legendary battles.
-- PR #634 rendered that art offline only. Each case starts the battle through its real trigger:
-- the Hoenn and Kanto Champion rooms' entry scenes after a warp through the door, a talk to Johto's
-- Lance, the Terra and Marine Cave coord events, and a talk to the resting Rayquaza. State is
-- seeded the way the game leaves it (Sky Pillar state 2 with the cry done; Groudon and Kyogre
-- undefeated, so the caves' ON_TRANSITION scripts show them).
--
-- Oracle: BG palette banks 2-4 in gPlttBufferUnfaded equal the authored palette read from ROM.
-- Champion battles are lost on purpose (whiteout), so no Hall of Fame runs between cases.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/BattleBgSpecialScenes.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BattleBgSpecialScenes")

local HUB_GROUP = 100
local CONTEXT_SHUTDOWN = 2
local PKMN_SIZE, OFF_HP = S.Pokemon.size, S.Pokemon.hp
local BP_STRIDE, BP_HP = S.BattlePokemon.size, S.BattlePokemon.hp
local VAR_SKY_PILLAR_STATE, VAR_SKY_PILLAR_RAYQUAZA_CRY_DONE = 0x40CA, 0x40D7

local function pal(name) return { name = name, addr = S["gBattleEnvironmentPalette_" .. name] } end
local CHAMPION, GROUDON, KYOGRE, RAYQUAZA = pal("StadiumWallace"), pal("Groudon"), pal("Kyogre"), pal("Rayquaza")

local function setVar(id, v) F.w16(F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2, v) end

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

local function inBattle() return F.cb2() == (S.BattleMainCB2 & ~1) end

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
      if F.ow() and F.grp() == grp and F.mapn() == map and px == x and py == y then F.idle(90); return true end
    end
    F.bOut(5)
  end
  F.shot(tag .. "_warpfail")
  return false
end

local function bgPaletteIs(p)
  for i = 0, 47 do
    local got, want = F.r16(S.gPlttBufferUnfaded + 0x40 + i * 2), F.r16(p.addr + i * 2)
    if got ~= want then return false, string.format("color %d is %04X, %s has %04X", i, got, p.name, want) end
  end
  return true, p.name
end

local function zeroHp(side)
  for i = 0, 5 do
    local b = S.gParties + (side * 6 + i) * PKMN_SIZE
    if F.r16(b + OFF_HP) ~= 0 then F.w16(b + OFF_HP, 0) end
  end
  F.w16(S.gBattleMons + side * BP_STRIDE + BP_HP, 0)
end

-- Arrive, start the battle by `trigger`, check the field, then end the battle.
local function scene(tag, arrive, trigger, want, endSide)
  if not F.check(tag .. ": arrives", arrive(), string.format("%d/%d", F.grp(), F.mapn())) then return end
  trigger()
  if not F.check(tag .. ": the battle starts", pump(inBattle, "A", 4000, 20),
    string.format("cb2=%X flags=0x%X", F.cb2(), F.battleFlags())) then
    F.shot(tag .. "_nostart")
    return
  end
  F.idle(360)
  F.shot(tag)
  local ok, detail = bgPaletteIs(want)
  F.check(tag .. ": battlefield draws the " .. want.name .. " palette", ok, detail)
  zeroHp(endSide)
  F.check(tag .. ": control returns after the battle", pump(hasControl, "A", 9000, 15))
end

local function talk(dir) return function() F.face(dir); F.press("A", 2) end end
local function stepUp() return function() F.step("Up") end end
local function noop() end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot", false); F.finish(); return end
  F.check("palette symbols exported", CHAMPION.addr and GROUDON.addr and KYOGRE.addr and RAYQUAZA.addr)
  giveMon(258)
  F.check("a Pokemon in the party", F.r8(S.gPartiesCount) >= 1, "n=" .. F.r8(S.gPartiesCount))

  scene("groudon_terra_cave", function() return warpToCoords(24, 105, 17, 27, "terra") end, stepUp(), GROUDON, 1)
  scene("kyogre_marine_cave", function() return warpToCoords(24, 103, 9, 27, "marine") end, stepUp(), KYOGRE, 1)
  setVar(VAR_SKY_PILLAR_STATE, 2)
  setVar(VAR_SKY_PILLAR_RAYQUAZA_CRY_DONE, 1)
  scene("rayquaza_sky_pillar", function() return warpToCoords(24, 85, 14, 7, "sky") end, talk("Up"), RAYQUAZA, 1)

  -- The Johto room walks the player six tiles in from the door; then walk up to Lance and talk.
  scene("johto_champion_lance", function()
    return F.warpTo(0, 9, 9, 0, 0, 9, 0, 0, 0, 99, 9, "johto_champ") and pump(hasControl, nil, 600) and F.leg(6, 9)
  end, talk("Up"), CHAMPION, 0)
  scene("hoenn_champion_wallace", function() return F.warpTo(0, 1, 6, 0, 0, 4, 0, 0, 0, 16, 4, "hoenn_champ") end, noop, CHAMPION, 0)
  scene("kanto_champion_blue", function() return F.warpTo(0, 3, 5, 0, 7, 9, 0, 0, 0, 35, 79, "kanto_champ") end, noop, CHAMPION, 0)
  F.finish()
end)
