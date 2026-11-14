-- The planner must reach Ice Path B3F's ladder to B4F, warp 0 at (14,8), from the B1F ladder.
--
-- The ladder sits at elevation 3 on row 8; row 9 directly below it is an elevation-4 ledge the
-- game will not let the player step up from. A warp goal used to skip the elevation check, so the
-- planner walked onto that ledge, pushed north into the ladder forever and gave up: natural-mode
-- grinding from Blackthorn toward Route 44 stuck at (14,9) and fell back to Route 45. The real way
-- in is the ice slide up column 9 and along row 8.
--
-- Setup is staged (Johto region, a debug party for the wild Pokemon, a debug warp onto the B1F
-- ladder's B3F end); what is tested is the planner driving controller input.
--
--   python3 test/overworld/johto-playthrough/run.py --suite ice_path_ladder.lua
local here = (debug.getinfo(1, 'S').source:sub(2)):match('^(.*[/\\])')
package.path = here .. '?.lua;' .. here .. '../lua/?.lua;' .. assert(os.getenv('PW_PLAY_LUA')) .. '/?.lua;' .. package.path
local S = require('symbols')
local F = require('lib').new(S, 'JohtoIcePathLadder')
local N = require('nav')(F, S)
local C = require('pwconst')

F.run(function()
  if not F.check('fresh game boots', F.boot(100)) then F.finish(); return end
  F.w8(F.sb2() + S.SaveBlock2.currentRegion, 2)
  F.w32(S.gCurrentRegion, 2)
  assert(N.giveMon({ species = C.SPECIES_MEWTWO, level = 100,
    moves = { C.MOVE_PSYSTRIKE, C.MOVE_AURA_SPHERE, C.MOVE_ICE_BEAM, C.MOVE_FLAMETHROWER } }), 'fixture party')
  N.setMetLevel(0, 5)
  if not F.check('warp onto Ice Path B3F at the B1F ladder', F.warpTo(0, 9, 4, 0, 1, 0, 0, 0, 1, 94, 10, 'b3f')) then
    F.finish(); return
  end
  local x, y = F.pos()
  F.check('set down on the B1F ladder (14,21)', x == 14 and y == 21, string.format('(%d,%d)', x, y))
  F.check('travel reaches Ice Path B4F', N.travel('IcePath_B4F') and N.mapName() == 'IcePath_B4F',
    string.format('at %s (%d,%d)', N.mapName(), F.pos(), select(2, F.pos())))
  x, y = F.pos()
  F.check('arrive on the B4F ladder (21,18)', x == 21 and y == 18, string.format('(%d,%d)', x, y))
  F.check('player control returns', N.free() and F.ensureFree())
  F.finish()
end)
