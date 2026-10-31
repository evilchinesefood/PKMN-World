-- The fixture stages a Cut user and the first badge. Cut, movement and collection use controller input.
local here = (debug.getinfo(1, 'S').source:sub(2)):match('^(.*[/\\])')
package.path = here .. '?.lua;' .. here .. '../lua/?.lua;' .. assert(os.getenv('PW_PLAY_LUA')) .. '/?.lua;' .. package.path
local S = require('symbols')
local F = require('lib').new(S, 'NationalParkSootheBell')
local N = require('nav')(F, S)
local C = require('pwconst')

local function logBlockers(tag)
  local x, y = F.pos()
  F.L(string.format('%s player=(%d,%d) free=%s', tag, x, y, tostring(N.free())))
  for _, id in ipairs({ 21, 22 }) do
    local o = N.object(id)
    if o then
      F.L(string.format('ambient %d current=(%d,%d) previous=(%d,%d) trainerType=%d',
        id, o.x, o.y, o.px, o.py, o.trainerType))
    else
      F.L('ambient ' .. id .. ' is outside the active view')
    end
  end
  F.shot(tag)
end

local CORRIDOR = {
  { 26, 2 }, { 29, 2 }, { 29, 4 }, { 33, 4 }, { 33, 6 }, { 35, 6 },
  { 35, 8 }, { 37, 8 }, { 37, 10 }, { 39, 10 }, { 39, 14 },
}

local function walkTo(tx, ty)
  local blocked = 0
  for _ = 1, 80 do
    local x, y = F.pos()
    if x == tx and y == ty then return true end
    local dir = x < tx and 'Right' or x > tx and 'Left' or y < ty and 'Down' or 'Up'
    if F.step(dir) then
      N.settle({ limit = 1200 })
    else
      blocked = blocked + 1
      F.L(string.format('controller %s blocked at (%d,%d), attempt %d', dir, x, y, blocked))
      N.press('A', 3); N.idle(120)
      F.L(string.format('A while blocked battle=%s free=%s', tostring(N.inBattle()), tostring(N.free())))
      N.settle({ limit = 600 })
      if blocked == 10 then logBlockers('blocked_' .. dir); return false end
    end
  end
  return false
end

local function walkCorridor(reverse)
  for i = 1, #CORRIDOR do
    local point = CORRIDOR[reverse and (#CORRIDOR - i + 1) or i]
    if not walkTo(point[1], point[2]) then return false end
  end
  return true
end

F.run(function()
  if not F.check('fresh game boots', F.boot(100)) then F.finish(); return end
  F.w8(F.sb2() + S.SaveBlock2.currentRegion, 2)
  F.w32(S.gCurrentRegion, 2)
  local badge = C.FLAG_JOHTO_BADGE_1 - C.FLAG_JOHTO_BASE
  local addr = F.sb3() + S.SaveBlock3.johtoFlags + (badge >> 3)
  F.w8(addr, F.r8(addr) | (1 << (badge & 7)))
  assert(N.giveMon({ species = C.SPECIES_CHIKORITA, level = 100,
    moves = { C.MOVE_CUT, C.MOVE_TACKLE, C.MOVE_RAZOR_LEAF, C.MOVE_SYNTHESIS } }), 'fixture Cut user')
  N.setMetLevel(0, 5)
  N.knowMove(C.MOVE_CUT, C.TYPE_NORMAL, 50)
  N.knowMove(C.MOVE_TACKLE, C.TYPE_NORMAL, 40)
  N.knowMove(C.MOVE_RAZOR_LEAF, C.TYPE_GRASS, 55)
  if not F.check('enter National Park', F.warpTo(0, 8, 3, 0, 0, 4, 0, 0, 0, 83, 4, 'park')) then
    F.finish(); return
  end
  F.check('Soothe Bell starts uncollected', N.itemCount(C.ITEM_SOOTHE_BELL) == 0
    and not N.flag(C.FLAG_ITEM_NATIONAL_PARK_SOOTHE_BELL))
  if not F.check('reach and cut the tree', N.talk(11, { side = 1, attempts = 40 })) then
    logBlockers('cut_failed'); F.finish(); return
  end
  N.canCut = true
  if not F.check('walk through the cut opening', N.go(26, 2, { attempts = 20 })) then
    logBlockers('opening_failed'); F.finish(); return
  end
  local reached = walkCorridor(false)
  local x, y = F.pos()
  if not reached and x == 32 and y == 4 then
    reached = walkTo(32, 5) and walkTo(33, 5) and walkTo(33, 6)
    if reached then
      for i = 6, #CORRIDOR do
        if not walkTo(CORRIDOR[i][1], CORRIDOR[i][2]) then reached = false; break end
      end
    end
  end
  F.check('walk through the upper-right passage', reached)
  if reached then
    N.face(1); N.press('A', 3); N.idle(30); N.settle({ limit = 1800 })
  end
  F.check('collect exactly one Soothe Bell', N.itemCount(C.ITEM_SOOTHE_BELL) == 1)
  F.check('collection hides the item', N.flag(C.FLAG_ITEM_NATIONAL_PARK_SOOTHE_BELL))
  logBlockers('soothe_bell_result')
  F.check('return through the passage', reached and walkCorridor(true))
  F.check('player control returns', N.free() and F.ensureFree())
  F.finish()
end)
