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
local NO_RETRY = os.getenv('PW_NO_RETRY') ~= nil
local REGION = ({ kanto = 1, johto = 2, hoenn = 3 })[CAMPAIGN]
assert(REGION or CAMPAIGN == 'world', 'unknown campaign')
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
  if N.natural then return end
  local m = N.partyMon(0)
  if m.maxHP > 0 and m.hp * 2 < m.maxHP then L('  topUp: lead at ' .. m.hp .. '/' .. m.maxHP); N.debugHeal() end
end

-- PW_NATURAL=1: natural-difficulty play, see README.md. Installed before the beats load, so a
-- campaign can tell.
local Nat
if os.getenv('PW_NATURAL') then
  Nat = require('natural')(F, N, S, here)
  Nat.install()
end

-- Straight from the campaign's directory: require would fall back to Johto's beats on a typo.
local BEATS = assert(loadfile(here .. '../' .. CAMPAIGN .. '-playthrough/beats.lua'))()(F, N, C, log)
if Nat then BEATS = Nat.patchBeats(BEATS) end

-- PW_LOSE=beat[:kind],... loses the first matching battle of each named beat on purpose, checks
-- what the game did about it, and plays the beat again. kind is trainer (default), wild, any, or a
-- TRAINER_ constant to single out one opponent. See N.throw in nav.lua for how the loss is forced.
local LOSE = {}
for tok in (os.getenv('PW_LOSE') or ''):gmatch('[^,]+') do
  local beat, kind = tok:match('^([^:]+):?(.*)$')
  assert(not LOSE[beat], 'duplicate loss selection: ' .. beat)
  LOSE[beat] = { kind = kind ~= '' and kind or 'trainer', state = 'selected' }
end

local function reportLoss(b, partyBefore)
  local t, x, y = N.threw, F.pos()
  local valid = true
  local function check(label, good, detail)
    valid = F.check('loss ' .. b.name .. ': ' .. label, good, detail) and valid
  end
  check('observed player-loss outcome', t.outcome == C.B_OUTCOME_LOST, tostring(t.outcome))
  if valid then LOSE[b.name].state = 'observed-loss' end
  local expectedRegion = REGION or t.activeCampaign
  check('active campaign preserved', expectedRegion and F.r8(F.sb2() + S.SaveBlock2.currentRegion) == expectedRegion)
  check('current region preserved', expectedRegion and F.r32(S.gCurrentRegion) == expectedRegion)
  -- Birch's rescue starts with no party and hands one over before the battle; a tag battle shrinks
  -- the party while it runs. The larger of the two counts is the party the player should get back.
  local party = math.max(partyBefore, t.party)
  local hp, full = {}, true
  for i = 0, N.partyCount() - 1 do
    local m = N.partyMon(i)
    hp[#hp + 1] = m.hp .. '/' .. m.maxHP
    full = full and m.hp == m.maxHP
  end
  L(string.format('  LOSS at %s opponent=%s, control back at %s (%d,%d) party %s money %d -> %d done=%s', t.map, tostring(t.opponent), N.mapName(), x, y,
    table.concat(hp, ' '), t.money, N.money(), tostring(b.done and b.done())))
  F.shot(b.name .. '_after_loss')
  check('no crash screen', not F.reportCrash('loss_' .. b.name))
  check('player in control', N.free())
  check('party healed', full, table.concat(hp, ' '))
  check('whole party back', N.partyCount() == party, N.partyCount() .. ' of ' .. party)
  if b.loss and b.loss.check then
    local good, detail = b.loss.check(t)
    check('story state', good, detail or '')
  end
  if N.region then
    check('still in the region', F.grp() >= N.region.lo and F.grp() <= N.region.hi, N.mapName())
  end
  N.threw = nil
  if valid then LOSE[b.name].state = 'recovered' end
  return valid
end

-- Walk to where the beat began. The planner has no Fly or cable car, so a respawn across the map
-- may need the debug warp, which leaves the story state the loss produced untouched.
local function walkBack(map, x, y)
  L(string.format('  walking back to %s (%d,%d)', map, x, y))
  local walked = pcall(function() assert(N.travel(map, { tile = { x, y } })) end)
  if not (walked and N.mapName() == map) then
    local m, digit = require('pwmaps')[map], function(n, place) return (n // place) % 10 end
    L('  planner could not get there; debug warp to ' .. map)
    if Nat then Nat.stats.warps = Nat.stats.warps + 1 end
    if not F.warpTo(digit(m.g, 100), digit(m.g, 10), digit(m.g, 1), digit(m.m, 100), digit(m.m, 10), digit(m.m, 1), 0, 0, 0, m.g, m.m, 'replay') then
      return false
    end
    N.settle()
    pcall(N.go, x, y)
    N.settle()
  end
  -- Don't insist on the start tile: walking onto it can trip a pad or a trigger, and it can sit
  -- behind a door the warp skipped. Beats open with their own travel and their done check decides.
  local px, py = F.pos()
  if px ~= x or py ~= y then L(string.format('  replaying from (%d,%d), the beat began at (%d,%d)', px, py, x, y)) end
  return N.mapName() == map
end

-- Play a beat again after a loss, from wherever the loss left us.
local function replayAfterLoss(b, index, startMap, startX, startY)
  if b.loss and b.loss.replay then
    L('  playing the rest of ' .. b.name .. ' after the loss')
    return pcall(b.loss.replay)
  end
  local from = b.loss and b.loss.replayFrom
  if from then
    local first
    for i = 1, index - 1 do if BEATS[i].name == from then first = i end end
    assert(first, 'no such replayFrom beat: ' .. from)
    for i = first, index - 1 do
      L('  replaying ' .. BEATS[i].name .. ' after the loss')
      local good, why = pcall(BEATS[i].run)
      if not good then return false, why end
      if BEATS[i].done and not BEATS[i].done() then return false, BEATS[i].name .. ' did not finish on replay' end
    end
  elseif N.mapName() ~= startMap and not walkBack(startMap, startX, startY) then
    return false, 'could not get back to ' .. startMap
  end
  L('  playing ' .. b.name .. ' again after the loss')
  return pcall(b.run)
end

-- Natural play: a whiteout is a real loss. Grind and go again, up to a limit, from the beat's start.
local function playNaturalBeat(b, index)
  local startMap, startX, startY = N.mapName(), F.pos()
  local preOk, preErr = pcall(Nat.beforeBeat, b)
  if not preOk and preErr ~= N.WHITEOUT then return false, preErr end
  -- A beat assumes it starts where the last one ended; a Center trip must not change that.
  if N.mapName() ~= startMap and not Nat.anywhere(b.name) and not walkBack(startMap, startX, startY) then
    return false, 'could not get back to ' .. startMap
  end
  local ok, err = pcall(b.run)
  local attempts = 0
  while not ok and err == N.WHITEOUT do
    attempts = attempts + 1
    L(string.format('NAT whiteout %d in %s (%s)', attempts, b.name, tostring(N.mapName())))
    if attempts > (tonumber(os.getenv('PW_NATURAL_ATTEMPTS')) or 6) then return false, 'gave up after ' .. attempts .. ' whiteouts' end
    local lossOk, lossErr = pcall(Nat.afterLoss, b, attempts)
    if not lossOk and lossErr ~= N.WHITEOUT then return false, lossErr end
    ok, err = replayAfterLoss(b, index, startMap, startX, startY)
  end
  Nat.afterBeat(b, ok and (not b.done or b.done()))
  return ok, err
end

local function playThrownBeat(b, index)
  if not LOSE[b.name] then return pcall(b.run) end
  local kind = LOSE[b.name].kind
  local random = kind == 'wild' or kind:sub(1, 8) == 'SPECIES_'
  local prev = index > 1 and BEATS[index - 1].name
  local startMap, startX, startY = N.mapName(), F.pos()
  local ok, err, wild0, partyBefore
  for try = 0, (random and prev and not NO_RETRY) and 3 or 0 do
    if try > 0 then
      -- A random encounter is luck: a beat can cross its grass without one. Reload the previous
      -- checkpoint and start the beat some frames later, which reshuffles the encounters.
      L(string.format('  no wild battle in %s; replaying from checkpoint %s, %d frames later', b.name, prev, 17 * try))
      if not N.restore(prev) then break end
      F.idle(30 + 17 * try); N.debugHeal()
      startMap, startX, startY = N.mapName(), F.pos()
    end
    wild0, partyBefore = N.battles.wild, N.partyCount()
    N.throw = { kind = kind }
    ok, err = pcall(b.run)
    N.throw = nil
    if N.threw or not ok then break end
  end
  if not N.threw then
    F.check('loss ' .. b.name .. ': a matching battle happened', false,
      ok and string.format('none (%d wild battles in the last try)', N.battles.wild - wild0) or tostring(err))
    return ok, err
  end
  LOSE[b.name].state = 'injected'
  if ok or err ~= N.LOSS_PLAYED then
    F.check('loss ' .. b.name .. ': the loss played out', false, ok and 'beat finished first' or tostring(err))
    F.check('loss ' .. b.name .. ': no crash screen', not F.reportCrash('loss_' .. b.name))
    N.threw = nil
    return ok, err
  end
  if not reportLoss(b, partyBefore) then return false, 'loss recovery assertions failed' end
  if b.done and b.done() then return true end
  -- A loss sends the player away. Rooms that reset on a loss restart from loss.replayFrom; anything
  -- else walks back to where the beat began.
  return replayAfterLoss(b, index, startMap, startX, startY)
end

F.run(function()
  -- A misspelt PW_LOSE beat would otherwise pass without losing anything.
  local known = {}
  for i, b in ipairs(BEATS) do known[b.name] = i end
  assert(not TO or known[TO], 'PW_TO names no such beat: ' .. tostring(TO))
  assert(not FROM or known[FROM], 'PW_FROM names no such beat: ' .. tostring(FROM))
  assert(not (FROM and TO) or known[FROM] < known[TO], 'stop must follow resumed checkpoint')
  for name in pairs(LOSE) do
    assert(known[name], 'PW_LOSE names no such beat: ' .. name)
    assert(not TO or known[name] <= known[TO], 'selected loss is after requested stop: ' .. name)
    assert(not FROM or known[name] > known[FROM], 'selected loss is before resumed start: ' .. name)
  end
  local reachedStop = not TO
  local start = 1
  if FROM then
    for i, b in ipairs(BEATS) do if b.name == FROM then start = i + 1 end end
    assert(start > 1, 'unknown checkpoint ' .. FROM)
    assert(N.restore(FROM, os.getenv('PW_RESUME_DIR')), 'could not restore checkpoint ' .. FROM)
    F.idle(30)
    N.debugHeal()   -- the in-memory heal bookkeeping does not survive a restore
  else
    assert(F.boot(100), 'fresh hub boot')
    F.check('fresh save has empty party', N.partyCount() == 0)
  end
  local retries = {}
  if Nat then
    Nat.setup()
    if FROM then Nat.loadCheckpoint(FROM, os.getenv('PW_RESUME_DIR')); N.run = true end
  end
  for i = start, #BEATS do
    local b = BEATS[i]
    L(string.format('BEAT %d/%d %s', i, #BEATS, b.name))
    local ok, err
    if Nat then ok, err = playNaturalBeat(b, i) else ok, err = playThrownBeat(b, i) end
    if not ok then L('  beat error: ' .. tostring(err)) end
    local done = ok and (not b.done or b.done())
    -- One retry from the previous beat's checkpoint: that reloads the exact game state, so it
    -- only absorbs harness timing (a wandering Pokemon in a corridor). Every retry is reported.
    local prev = i > 1 and BEATS[i - 1].name
    if not done and prev and not NO_RETRY and not LOSE[b.name] then
      L(string.format('  RETRY %s from checkpoint %s', b.name, prev))
      retries[#retries + 1] = b.name
      F.shot(b.name .. '_before_retry')
      if N.restore(prev) then
        F.idle(30); N.debugHeal()
        if Nat then Nat.loadCheckpoint(prev) end
        if Nat then ok, err = playNaturalBeat(b, i) else ok, err = pcall(b.run) end
        if not ok then L('  beat error (retry): ' .. tostring(err)) end
        done = ok and (not b.done or b.done())
      end
    end
    log(b.name)
    if not F.check('beat ' .. b.name, done, ok and '' or tostring(err)) then
      F.reportCrash('beat_' .. b.name)
      break
    end
    if LOSE[b.name] and LOSE[b.name].state == 'recovered' then
      LOSE[b.name].state = 'completed'
      F.check('loss ' .. b.name .. ': selected beat completed after recovery', true)
    end
    topUp()
    N.checkpoint(b.name)
    if Nat then Nat.saveCheckpoint(b.name) end
    if TO and b.name == TO then reachedStop = true; break end
  end
  F.check('requested stop reached', reachedStop, TO or 'complete campaign')
  for name, loss in pairs(LOSE) do
    F.check('selected loss ' .. name .. ' completed', loss.state == 'completed', loss.state)
  end
  if Nat then Nat.report() end
  L(string.format('TOTAL steps=%d trainer battles=%d wild=%d heals=%d retries=%d %s', N.steps, N.battles.trainer,
    N.battles.wild, N.heals or 0, #retries, table.concat(retries, ',')))
  F.finish()
end)
