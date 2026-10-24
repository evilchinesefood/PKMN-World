-- Issue #357: fresh-save gameplay, using only controller input for progression.
local root=(debug.getinfo(1,'S').source:sub(2)):match('^(.*[/\\])')..'../lua/'
package.path = root .. '?.lua;' .. package.path
local S = require('symbols')
local F = require('lib').new(S, 'JohtoNicknameAudit')
local U=dofile(assert(os.getenv('PW_357_SYMBOLS'),'run via johto-progression/run.py'))
local function controller(fn) return (F.r32(U.gBattlerControllerFuncs)&~1)==(U[fn]&~1) end
local function log(tag)
  F.L(string.format('%s map=%d/%d pos=(%d,%d) cb2=%08x script=%08x status=%d',
    tag,F.grp(),F.mapn(),F.pos(),select(2,F.pos()),F.cb2(),F.r32(S.sGlobalScriptContext+8),F.r8(S.sGlobalScriptContextStatus)))
  F.shot(tag)
end
local function mash(n)
  for i=1,n do F.press('A',2);F.idle(20) end
end
F.run(function()
  assert(F.boot(100),'fresh hub boot')
  F.check('fresh save has empty party',F.r8(S.gPartiesCount)==0)
  assert(F.leg(16,3));F.face('Up');F.press('A',2);for i=1,500 do F.press('A',2);F.idle(20);if F.grp()==76 then break end end;F.idle(200)
  log('johto_arrival')
  F.check('Johto attendant arrives in bedroom',F.grp()==76 and F.mapn()==4)
  F.check('bedroom player control',F.ensureFree())
  -- Leave the bed via its west edge, then approach the mandatory clock trigger.
  assert(F.leg(0,6));assert(F.leg(0,4));assert(F.leg(10,4));F.step('Up')
  for i=1,600 do
    F.press('Up',2);F.idle(4);F.press('A',2);F.idle(30)
    if F.ow() and F.r8(S.sGlobalScriptContextStatus)==2 then break end
  end
  -- A reading of the wall clock can open on the last confirmation; B closes it.
  F.press('B',2);F.idle(180);log('clock_completed')
  F.check('clock setup returns to field',F.ow())
  F.step('Left');F.press('Left',30);F.idle(180);log('downstairs')
  F.check('stairs reach first floor',F.grp()==76 and F.mapn()==3)
  F.step('Down')
  for i=1,600 do
    F.press('B',2);F.idle(20)
    if F.ow() and F.r8(S.sGlobalScriptContextStatus)==2 then break end
  end
  log('mom_intro')
  F.check('Mom intro returns control',F.step('Down'))
  assert(F.leg(9,7));F.step('Down');F.press('Down',30);F.idle(180)
  log('newbark_town');F.check('home exit reaches town',F.grp()==75 and F.mapn()==0)
  -- Arrival narration, then Elm's front door.
  for i=1,80 do F.press('B',2);F.idle(20) end
  assert(F.leg(10,12));assert(F.leg(10,10));F.press('Up',40);F.idle(180)
  log('elm_lab');F.check('Elm lab entered',F.grp()==76 and F.mapn()==0)
  -- Elm's errand introduction and real starter selection.
  F.leg(6,7)
  for i=1,700 do
    F.press('A',2);F.idle(24)
    if F.ow() and F.r8(S.sGlobalScriptContextStatus)==2 then break end
  end
  log('elm_intro');F.check('Elm intro completed',F.r8(S.sGlobalScriptContextStatus)==2)
  assert(F.leg(6,5));assert(F.leg(8,5));F.face('Up');F.press('A',2)
  for i=1,600 do
    F.press('A',2);F.idle(24)
    if F.r8(S.gPartiesCount)>0 then break end
  end
  for i=1,500 do
    if F.cb2()==S.CB2_NamingScreen then break end
    F.press('A',2);F.idle(24)
  end
  F.check('starter nickname screen opens',F.cb2()==S.CB2_NamingScreen)
  F.idle(90);F.press('Start',2);F.idle(30);F.press('A',2);F.idle(240)
  for i=1,120 do F.press('B',2);F.idle(20) end
  log('nickname_completed')
  F.check('nickname returns to field',F.ow())
  F.check('nickname releases player control',F.step('Down'))
  F.finish()
end)
