-- Story playthrough from a fresh save, by controller input. PW_CAMPAIGN picks the region's
-- beats.lua from test/overworld/<campaign>-playthrough/ (default johto).
--
-- Run through test/overworld/johto-playthrough/run.py. Each beat ends with a checkpoint
-- (a savestate in PW_OUT), so a failing beat can be fixed and resumed with PW_FROM=<beat>
-- instead of replaying the whole story; the final evidence run plays every beat in one go.
local here = (debug.getinfo(1, 'S').source:sub(2)):match('^(.*[/\\])')
local CAMPAIGN = os.getenv('PW_CAMPAIGN') or 'johto'
package.path = here .. '../' .. CAMPAIGN .. '-playthrough/?.lua;' .. here .. '?.lua;' .. here .. '../lua/?.lua;' .. assert(os.getenv('PW_PLAY_LUA')) .. '/?.lua;' .. package.path
local S = require('symbols')
local FROM, TO = os.getenv('PW_FROM'), os.getenv('PW_TO')
local F = require('lib').new(S, CAMPAIGN:sub(1, 1):upper() .. CAMPAIGN:sub(2) .. 'Play' .. (FROM and ('_from_' .. FROM) or ''))
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

-- Straight from the campaign's directory: require would fall back to Johto's beats on a typo.
local BEATS = assert(loadfile(here .. '../' .. CAMPAIGN .. '-playthrough/beats.lua'))()(F, N, C, log)

-- PW_LOSE=beat[:kind],... loses the first matching battle of each named beat on purpose, checks
-- what the game did about it, and plays the beat again. kind is trainer (default), wild, any, or a
-- TRAINER_ constant to single out one opponent. See N.throw in nav.lua for how the loss is forced.
local LOSE = {}
for tok in (os.getenv('PW_LOSE') or ''):gmatch('[^,]+') do
  local beat, kind = tok:match('^([^:]+):?(.*)$')
  LOSE[beat] = kind ~= '' and kind or 'trainer'
end

local function reportLoss(b)
  local t, x, y = N.threw, F.pos()
  local hp, full = {}, true
  for i = 0, N.partyCount() - 1 do
    local m = N.partyMon(i)
    hp[#hp + 1] = m.hp .. '/' .. m.maxHP
    full = full and m.hp == m.maxHP
  end
  L(string.format('  LOSS at %s, control back at %s (%d,%d) party %s money %d -> %d done=%s', t.map, N.mapName(), x, y,
    table.concat(hp, ' '), t.money, N.money(), tostring(b.done and b.done())))
  F.shot(b.name .. '_after_loss')
  F.check('loss ' .. b.name .. ': no crash screen', not F.reportCrash('loss_' .. b.name))
  F.check('loss ' .. b.name .. ': player in control', N.free())
  F.check('loss ' .. b.name .. ': party healed', full, table.concat(hp, ' '))
  if N.region then
    F.check('loss ' .. b.name .. ': still in the region', F.grp() >= N.region.lo and F.grp() <= N.region.hi, N.mapName())
  end
  N.threw = nil
end

local function playThrownBeat(b)
  if not LOSE[b.name] then return pcall(b.run) end
  N.throw = { kind = LOSE[b.name] }
  local ok, err = pcall(b.run)
  N.throw = nil
  if not N.threw then
    F.check('loss ' .. b.name .. ': a matching battle happened', false, ok and 'none' or tostring(err))
    return ok, err
  end
  if ok or err ~= N.LOSS_PLAYED then
    F.check('loss ' .. b.name .. ': the loss played out', false, ok and 'beat finished first' or tostring(err))
    N.threw = nil
    return ok, err
  end
  reportLoss(b)
  if b.done and b.done() then return true end
  L('  playing ' .. b.name .. ' again after the loss')
  return pcall(b.run)
end

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
  local retries = {}
  for i = start, #BEATS do
    local b = BEATS[i]
    L(string.format('BEAT %d/%d %s', i, #BEATS, b.name))
    local ok, err = playThrownBeat(b)
    if not ok then L('  beat error: ' .. tostring(err)) end
    local done = ok and (not b.done or b.done())
    -- One retry from the previous beat's checkpoint: that reloads the exact game state, so it
    -- only absorbs harness timing (a wandering Pokemon in a corridor). Every retry is reported.
    local prev = i > 1 and BEATS[i - 1].name
    if not done and prev and not os.getenv('PW_NO_RETRY') then
      L(string.format('  RETRY %s from checkpoint %s', b.name, prev))
      retries[#retries + 1] = b.name
      F.shot(b.name .. '_before_retry')
      if N.restore(prev) then
        F.idle(30); N.debugHeal()
        ok, err = pcall(b.run)
        if not ok then L('  beat error (retry): ' .. tostring(err)) end
        done = ok and (not b.done or b.done())
      end
    end
    log(b.name)
    if not F.check('beat ' .. b.name, done, ok and '' or tostring(err)) then
      F.reportCrash('beat_' .. b.name)
      break
    end
    topUp()
    N.checkpoint(b.name)
    if TO and b.name == TO then break end
  end
  L(string.format('TOTAL steps=%d trainer battles=%d wild=%d heals=%d retries=%d %s', N.steps, N.battles.trainer,
    N.battles.wild, N.heals or 0, #retries, table.concat(retries, ',')))
  F.finish()
end)
