-- #398: an overworld wild Pokemon that touched the player's follower has to walk around whatever
-- stands between it and the player. In Rusturf Tunnel the Hiker stood at (30,13) after his battle,
-- between the encounter at (30,12) and the player at (30,14). The approach lined up on x every step,
-- so it side-stepped and walked straight back behind him forever, and the game froze.
--
--   python3 test/overworld/johto-playthrough/run.py --campaign hoenn \
--     --suite ../hoenn-playthrough/owe_approach_around_blocker.lua \
--     --resume-dir <prior Hoenn case>
--
-- Needs ckpt_route103.ss in the --resume-dir (a Hoenn campaign checkpoint with a party). The debug
-- menu warps to Rusturf Tunnel. Contact is real: the player walks into a generated encounter. While
-- the encounter script waits on `lock`, the encounter is moved to (30,12) with the frozen one's
-- wandering movement type, and the Hiker to (30,13).
local here = (debug.getinfo(1, 'S').source:sub(2)):match('^(.*[/\\])')
package.path = here .. '?.lua;' .. here .. '../johto-playthrough/?.lua;' .. here .. '../lua/?.lua;'
  .. assert(os.getenv('PW_PLAY_LUA')) .. '/?.lua;' .. package.path
local S = require('symbols')
local F = require('lib').new(S, 'OweApproachAroundBlocker')
local N = require('nav')(F, S)
local O = require('pwoff')
local P = require('pwsym')
local C = require('pwconst')
N.region = { lo = 0, hi = 33 }

local function base(i) return S.gObjectEvents + i * O.oe_size end
local function coords(i)
  local b = base(i)
  return F.r16(b + O.oe_currentCoords) - 7, F.r16(b + O.oe_currentCoords + 2) - 7
end
local function setCoords(i, x, y)
  local b = base(i)
  for _, off in ipairs({ O.oe_currentCoords, O.oe_previousCoords }) do
    F.w16(b + off, x + 7); F.w16(b + off + 2, y + 7)
  end
end
local function generated()
  for _, o in ipairs(N.objects()) do
    if o.localId >= 249 and o.localId <= 252 and not o.invisible then return o end
  end
end
local function playerId() return F.r8(P.gPlayerAvatar + O.pa_objectEventId) end
local function at(x, y) return function(px, py) return px == x and py == y end end

F.run(function()
  assert(N.restore('route103', os.getenv('PW_RESUME_DIR')), 'checkpoint route103 in --resume-dir')
  F.idle(30); N.debugHeal()
  F.check('warp to Rusturf Tunnel', F.warpTo(0, 2, 4, 0, 0, 4, 0, 0, 1, 24, 4, 'rusturf') and N.settle())

  local owe
  for k = 1, 40 do
    owe = generated()
    if owe then break end
    N.walk(at(k % 2 == 0 and 30 or 23, 14), { tag = 'pace for a spawn', attempts = 10 })
  end
  F.check('a generated encounter spawned in the tunnel', owe ~= nil)
  if not owe then F.finish(); return end
  F.check('player stands at (30,14)', N.walk(at(30, 14), { tag = 'freeze tile' }) and N.settle(), string.format('%d,%d', coords(playerId())))
  N.face(2)   -- up
  local hiker = N.object(9)
  F.check('the Hiker is on the map', hiker ~= nil)
  if not hiker then F.finish(); return end

  setCoords(owe.i, 30, 13)
  F.idle(2)
  local script, moved = P.InteractWithOverworldWildEncounter & ~1, false
  for _ = 1, 240 do
    joypad.set({ Up = true }); emu.frameadvance()
    local pc = F.r32(S.sGlobalScriptContext + 8)
    if F.r8(S.sGlobalScriptContextStatus) ~= 2 and pc >= script and pc < script + 0x40 then
      setCoords(owe.i, 30, 12)
      F.w8(base(owe.i) + O.oe_movementType, C.MOVEMENT_TYPE_WANDER_AROUND_OWE)
      setCoords(hiker.i, 30, 13)
      moved = true
      break
    end
    if N.inBattle() then break end
  end
  joypad.set({})
  F.check('touching it starts the encounter script', moved, N.inBattle() and 'battle began first' or '')
  if not moved then F.finish(); return end

  local started = false
  for _ = 1, 120 do
    F.idle(1)
    if N.activeTask(P.Task_OWEApproachForBattle) then started = true; break end
  end
  F.check('the approach starts from (30,12), the Hiker in between', started, string.format('encounter at %d,%d', coords(owe.i)))
  local frames, ox, oy = 0, nil, nil
  while frames < 1800 and N.activeTask(P.Task_OWEApproachForBattle) do
    ox, oy = coords(owe.i)
    F.idle(5); frames = frames + 5
  end
  local px, py = coords(playerId())
  local follower
  for i = 0, 15 do
    if F.r8(base(i)) & 1 == 1 and F.r8(base(i) + O.oe_localId) == 254 then
      local fx, fy = coords(i)
      follower = { x = fx, y = fy }
    end
  end
  local function nextTo(x, y) return ox and math.abs(ox - x) + math.abs(oy - y) == 1 end
  local adjacent = nextTo(px, py) or (follower and nextTo(follower.x, follower.y))
  F.check('the approach ends', not N.activeTask(P.Task_OWEApproachForBattle), frames .. ' frames, encounter at ' .. tostring(ox) .. ',' .. tostring(oy))
  F.check('the encounter walked around the Hiker to the player or follower', adjacent,
    string.format('encounter %s,%s player %d,%d follower %s', tostring(ox), tostring(oy), px, py, follower and (follower.x .. ',' .. follower.y) or 'none'))
  local began = false
  for _ = 1, 120 do
    if N.inBattle() then began = true; break end
    F.idle(5)
  end
  F.check('its battle starts', began)
  if began then
    N.battle()
    F.check('back in control after the battle', N.settle() and N.free(), N.mapName())
  end
  F.finish()
end)
