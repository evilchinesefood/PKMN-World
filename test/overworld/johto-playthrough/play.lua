-- Johto story playthrough from a fresh save, by controller input.
--
-- Run through test/overworld/johto-playthrough/run.py. Each beat ends with a checkpoint
-- (a savestate in PW_OUT), so a failing beat can be fixed and resumed with PW_FROM=<beat>
-- instead of replaying the whole story; the final evidence run plays every beat in one go.
local here = (debug.getinfo(1, 'S').source:sub(2)):match('^(.*[/\\])')
package.path = here .. '?.lua;' .. here .. '../lua/?.lua;' .. assert(os.getenv('PW_PLAY_LUA')) .. '/?.lua;' .. package.path
local S = require('symbols')
local FROM, TO = os.getenv('PW_FROM'), os.getenv('PW_TO')
local F = require('lib').new(S, 'JohtoPlay' .. (FROM and ('_from_' .. FROM) or ''))
local N = require('nav')(F, S)
local C = require('pwconst')
local L = F.L
N.battleDebug = os.getenv('PW_BATTLE_DEBUG') ~= nil

N.knowMove(C.MOVE_PSYSTRIKE, C.TYPE_PSYCHIC, 100)
N.knowMove(C.MOVE_AURA_SPHERE, C.TYPE_FIGHTING, 80)
N.knowMove(C.MOVE_ICE_BEAM, C.TYPE_ICE, 90)
N.knowMove(C.MOVE_FLAMETHROWER, C.TYPE_FIRE, 90)
N.knowMove(C.MOVE_EARTHQUAKE, C.TYPE_GROUND, 100)
N.knowMove(C.MOVE_DRAGON_CLAW, C.TYPE_DRAGON, 80)
N.knowMove(C.MOVE_EXTREME_SPEED, C.TYPE_NORMAL, 80)
N.knowMove(C.MOVE_THUNDERBOLT, C.TYPE_ELECTRIC, 90)

local function log(tag)
  local x, y = F.pos()
  local m = N.partyMon(0)
  L(string.format('== %s: %s (%d,%d) party=%d lead=L%d %d/%d steps=%d battles=%d/%d', tag, N.mapName(), x, y,
    N.partyCount(), m.level, m.hp, m.maxHP, N.steps, N.battles.trainer, N.battles.wild))
  F.shot(tag)
end

-- Heal between beats when the lead is worn down (a documented concession, see README).
local function topUp()
  local m = N.partyMon(0)
  if m.maxHP > 0 and m.hp * 2 < m.maxHP then L('  topUp: lead at ' .. m.hp .. '/' .. m.maxHP); N.debugHeal() end
end

local BEATS = require('beats')(F, N, C, log)

F.run(function()
  local start = 1
  if FROM then
    for i, b in ipairs(BEATS) do if b.name == FROM then start = i + 1 end end
    assert(start > 1, 'unknown checkpoint ' .. FROM)
    assert(N.restore(FROM), 'could not restore checkpoint ' .. FROM)
    F.idle(30)
    N.debugHeal()   -- the in-memory heal bookkeeping does not survive a restore
  else
    assert(F.boot(100), 'fresh hub boot')
    F.check('fresh save has empty party', N.partyCount() == 0)
  end
  for i = start, #BEATS do
    local b = BEATS[i]
    L(string.format('BEAT %d/%d %s', i, #BEATS, b.name))
    local ok, err = pcall(b.run)
    if not ok then L('  beat error: ' .. tostring(err)) end
    local done = ok and (not b.done or b.done())
    log(b.name)
    if not F.check('beat ' .. b.name, done, ok and '' or tostring(err)) then
      F.reportCrash('beat_' .. b.name)
      break
    end
    topUp()
    N.checkpoint(b.name)
    if TO and b.name == TO then break end
  end
  L(string.format('TOTAL steps=%d trainer battles=%d wild=%d', N.steps, N.battles.trainer, N.battles.wild))
  F.finish()
end)
