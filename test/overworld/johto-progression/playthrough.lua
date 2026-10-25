-- Issue #357: fresh-save gameplay, using only controller input for progression.
local root=(debug.getinfo(1,'S').source:sub(2)):match('^(.*[/\\])')..'../lua/'
package.path = root .. '?.lua;' .. package.path
local S = require('symbols')
local F = require('lib').new(S, 'JohtoProgression357')
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
  for i=1,150 do F.press('B',2);F.idle(24);if F.r8(S.sGlobalScriptContextStatus)==2 then break end end
  log('starter');F.check('Elm gives one real starter',F.r8(S.gPartiesCount)==1)
  F.check('starter selection releases control',F.step('Down'))
  assert(F.leg(6,5));assert(F.leg(6,4));F.face('Up');F.press('A',2)
  for i=1,300 do F.press('B',2);F.idle(24);if F.r8(S.sGlobalScriptContextStatus)==2 then break end end
  log('elm_errand');F.check('Elm errand returns control',F.step('Down'))
  assert(F.leg(6,11));F.step('Down')
  for i=1,250 do F.press('B',2);F.idle(24);if F.r8(S.sGlobalScriptContextStatus)==2 then break end end
  F.press('Down',40);F.idle(180);log('lab_exit')
  F.check('starter and potion allow town return',F.grp()==75 and F.mapn()==0)
  assert(F.leg(10,12));assert(F.leg(0,12));F.press('Left',35);F.idle(90)
  log('route29');F.check('walk reaches Route 29',F.grp()==75 and F.mapn()==2)
  assert(F.leg(65,17))
  for i=1,300 do
    F.press(i%2==0 and 'Down' or 'Up',20);F.idle(4)
    if not F.ow() then break end
    -- Move south into the grass on (65,20) before pacing.
    if select(2,F.pos())<20 then F.press('Down',30);F.idle(4) end
  end
  F.idle(300);log('first_wild_battle')
  F.check('first wild battle starts naturally',not F.ow() and F.battlers()>0)
  for turn=1,120 do
    if F.ow() then break end
    for i=1,600 do
      if controller('HandleInputChooseAction') or F.ow() then break end
      F.press('B',2);F.idle(12)
    end
    if F.ow() then break end
    assert(controller('HandleInputChooseAction'),'battle command timeout')
    F.press('Up',2);F.idle(6);F.press('Left',2);F.idle(6);F.press('A',2);F.idle(60)
    assert(controller('HandleInputChooseMove'),'Fight must open move choice')
    local moves={}
    for i=0,3 do moves[i+1]=F.r16(S.gBattleMons+S.BattlePokemon.moves+i*2) end
    F.L('turn '..turn..' moves='..table.concat(moves,','))
    -- Choose Growl (45) without attacking; this lets the wild opponent earn the defeat.
    local slot
    for i=1,4 do if moves[i]==45 then slot=i-1 end end
    assert(slot,'starter must know Growl')
    local cur=F.r8(U.gMoveSelectionCursor)
    if (cur&1)~=(slot&1) then F.press((slot&1)==1 and 'Right' or 'Left',2);F.idle(6) end
    if (cur&2)~=(slot&2) then F.press((slot&2)==2 and 'Down' or 'Up',2);F.idle(6) end
    F.press('A',2);F.idle(90)
  end
  for i=1,300 do F.press('B',2);F.idle(20) end
  log('first_defeat_recovery')
  F.check('first battle is lost through real combat',F.outcome()==2,'outcome='..F.outcome())
  F.check('first defeat returns home',F.grp()==76 and F.mapn()==3)
  if not F.check('first defeat restores player control',F.step('Down')) then F.finish();return end
  -- Revisit the reported Mom interaction after the real defeat, then continue.
  F.face('Up');F.press('A',2);F.idle(20)
  F.check('post-defeat Mom dialogue starts',F.r8(S.sGlobalScriptContextStatus)~=2)
  for i=1,200 do F.press('B',2);F.idle(20) end
  F.check('post-defeat Mom dialogue completes',F.r8(S.sGlobalScriptContextStatus)==2 and F.step('Down'))
  assert(F.leg(9,7));F.step('Down');F.press('Down',30);F.idle(180)
  log('continued_after_defeat');F.check('progression continues outside home',F.grp()==75 and F.mapn()==0 and F.ensureFree())
  F.press('Start',2);F.idle(90);assert(F.selectStartIcon(7),'Save icon missing')
  F.press('A',2);F.idle(90);F.press('A',2);F.idle(90);F.press('A',2);F.idle(600)
  client.reboot_core();F.idle(240)
  F.check('real Johto save reloads in town',F.boot(75) and F.mapn()==0)
  F.check('starter persists across save reload',F.r8(S.gPartiesCount)==1)
  F.check('continued save returns movement control',F.ensureFree());log('johto_continue')
  F.finish()
end)
