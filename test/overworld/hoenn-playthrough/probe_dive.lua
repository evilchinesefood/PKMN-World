-- Probe for water.lua: dive, swim and emerge by controller input.
--
--   python3 test/overworld/johto-playthrough/run.py --campaign hoenn \
--     --suite ../hoenn-playthrough/probe_dive.lua --out _pwtest/hoenn-dive
--
-- Needs <out>/ckpt_rock_smash.ss (a Hoenn campaign checkpoint: Lv100 Mewtwo and Rayquaza).
-- This tests navigation mechanics, not the story, so it takes shortcuts a story run would not:
-- the Balance and Mind badge flags (Surf and Dive) are written straight into the save, and the
-- debug menu warps to Mossdeep before each leg. Everything after the warp is joypad input.
local here = (debug.getinfo(1, 'S').source:sub(2)):match('^(.*[/\\])')
package.path = here .. '?.lua;' .. here .. '../johto-playthrough/?.lua;' .. here .. '../lua/?.lua;'
  .. assert(os.getenv('PW_PLAY_LUA')) .. '/?.lua;' .. package.path
local S = require('symbols')
local F = require('lib').new(S, 'HoennDive')
local N = require('nav')(F, S)
local C = require('pwconst')
local O = require('pwoff')
require('water')(F, N, C)
local L = F.L
N.region = { lo = 0, hi = 33 }
N.knowMove(C.MOVE_PSYSTRIKE, C.TYPE_PSYCHIC, 100)
N.knowMove(C.MOVE_AURA_SPHERE, C.TYPE_FIGHTING, 80)
N.knowMove(C.MOVE_ICE_BEAM, C.TYPE_ICE, 90)
N.knowMove(C.MOVE_FLAMETHROWER, C.TYPE_FIRE, 90)
N.knowMove(C.MOVE_EARTHQUAKE, C.TYPE_GROUND, 100)
N.knowMove(C.MOVE_DRAGON_CLAW, C.TYPE_DRAGON, 80)
N.knowMove(C.MOVE_EXTREME_SPEED, C.TYPE_NORMAL, 80)
N.knowMove(C.MOVE_THUNDERBOLT, C.TYPE_ELECTRIC, 90)

local function setFlag(id)
  local a = F.sb1() + O.sb1_flags + (id >> 3)
  F.w8(a, F.r8(a) | (1 << (id & 7)))
end
local function at(map) return N.mapName() == map end
local function took(line)
  for _, t in ipairs(N.waterTrail) do if t:find(line, 1, true) then return true end end
  return false
end
local function toMossdeep()
  N.settle()
  return F.warpTo(0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 6, 'mossdeep') and N.settle()
end

F.run(function()
  assert(N.restore('rock_smash'), 'checkpoint rock_smash in ' .. F.out)
  F.idle(30); N.debugHeal()
  setFlag(C.FLAG_BADGE05_GET); setFlag(C.FLAG_BADGE07_GET)
  N.canSurf, N.run = true, true

  F.check('warp to Mossdeep (leg 1)', toMossdeep())
  F.check('surf to Route 128', N.travel('Route128') and N.surfing())
  N.waterTrail = {}
  local ok = N.travel('SeafloorCavern_Entrance')
  L('  trail: ' .. table.concat(N.waterTrail, ' | '))
  F.check('Route 128 surface to Seafloor Cavern entrance by Dive', ok and at('SeafloorCavern_Entrance')
    and took('dive Route128') and took('-> Underwater_SeafloorCavern') and took('emerge Underwater_SeafloorCavern'),
    N.mapName())
  F.check('running back on after emerging', N.run and not N.underwater())
  F.shot('seafloor')

  F.check('warp to Mossdeep (leg 2)', toMossdeep())
  -- Via Route 127: nav's own route west from Mossdeep stops at the shore (a land-to-water map
  -- seam it cannot surf across), which is not what this probe is about.
  F.check('surf to Route 126', N.travel('Route127') and N.travel('Route126') and N.surfing())
  N.waterTrail = {}
  ok = N.travel('SootopolisCity')
  L('  trail: ' .. table.concat(N.waterTrail, ' | '))
  F.check('Route 126 surface to Sootopolis through the crater', ok and at('SootopolisCity')
    and took('dive Route126') and took('-> Underwater_SootopolisCity') and took('emerge Underwater_SootopolisCity'),
    N.mapName())
  F.shot('sootopolis')
  F.finish()
end)
