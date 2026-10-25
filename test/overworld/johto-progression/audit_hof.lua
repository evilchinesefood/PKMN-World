-- Hall of Fame must finish with ordinary parties and with the unhatched Violet gift Egg.
-- The Egg's missing frontAnimFrames previously selected an END-only dummy animation that
-- never signaled completion. Save-history cases also verify ceremony save/reload behavior.
package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local H=require('audit_helpers')('JohtoHallOfFame');local F,S,A,C,tap,cmd,state,flag,finish=H.F,H.S,H.A,H.C,H.tap,H.cmd,H.state,H.flag,H.finish
local maps=require('story_maps')

-- Saving over an existing file adds an "there is already a save file" confirmation, so a fixed
-- number of A presses succeeds the first time and silently fails afterwards. Confirm until the
-- save counter actually moves, and report failure on the counter rather than on the presses.
local function saveThroughMenu()
 local before=F.r32(A.gSaveCounter)
 tap('B');F.idle(30)            -- clear anything still on screen before opening the menu
 tap('Start');F.idle(90)
 if not F.selectStartIcon(7) then return false end
 -- Saving over an existing file adds a confirmation, and the counter only moves once the write
 -- completes, so be patient and watch the counter rather than counting presses.
 for _=1,16 do
  tap('A',1,120)
  if F.r32(A.gSaveCounter)~=before then F.idle(360);return true end
 end
 F.idle(360)
 return F.r32(A.gSaveCounter)~=before
end

local function runCase(name)
 F.L('HOF CASE '..name)
 client.reboot_core();F.idle(120)
 -- No expected group: once a save exists the game Continues instead of landing in the hub.
 assert(F.boot(),name..': boot')
 cmd(0,0)
 F.w8(F.sb2()+S.SaveBlock2.currentRegion,2);F.w32(S.gCurrentRegion,2)
 if name=='egg' then
  cmd(4,C.VAR_VIOLET_CITY_STATE,3)
  cmd(3,C.FLAG_JOHTO_BADGE_1)
  cmd(5,C.FLAG_HIDE_VIOLET_CITY_AIDE)
  local m=maps.VioletCity_PokemonCenter
  local o=m.objects.VioletCity_PokemonCenter_EventScript_Aide
  cmd(1,m.g,m.m,o.x,o.y,300);F.face('Up');tap('A')
  F.check('egg: gift scene finishes',finish())
  F.check('egg: gift received',flag(C.FLAG_RECEIVED_TOGEPI_EGG))
  F.check('egg: party has starter and Egg',F.r8(S.gPartiesCount)==2)
 end
 F.L('  party count '..F.r8(S.gPartiesCount))
 cmd(4,C.VAR_LEAGUE_STATE,5)
 for i=0,7 do cmd(3,C.FLAG_JOHTO_BADGE_1+i) end
 cmd(4,C.VAR_ECRUTEAK_CITY_THEATER,8)

 if name=='presaved' or name=='manysaves' then
  -- Write save(s) first, as the continuous run's checkpoints do. 'manysaves' writes several so
  -- the save sectors have been cycled, which is the other way the continuous run differs.
  local p=maps.JohtoIndigoPlateau_PokemonCenter;cmd(1,p.g,p.m,20,12,300)
  -- Assert the aggregate, not each attempt: the point of 'manysaves' is that the save sectors
  -- were cycled several times before the ceremony, and one flaky confirmation should not fail
  -- a case that is really about the count.
  local n=(name=='manysaves') and 3 or 1
  local before=F.r32(A.gSaveCounter)
  local landed=0
  for _=1,n do if saveThroughMenu() then landed=landed+1 end end
  F.L(string.format('  %s: %d of %d save attempts landed, counter %d -> %d',
    name,landed,n,before,F.r32(A.gSaveCounter)))
  -- Require every attempt: this case exists to put several saves on the cartridge, so one
  -- landing out of three would run the ceremony without the history it means to test.
  F.check(string.format('%s: all %d pre-ceremony saves landed',name,n),landed==n,
    string.format('%d landed, counter %d -> %d',landed,before,F.r32(A.gSaveCounter)))
  F.L(string.format('  before ceremony: gSaveCounter=%d gDamagedSaveSectors=%d',
    F.r32(A.gSaveCounter),F.r32(A.gDamagedSaveSectors)))
 end

 local m=maps.JohtoPokemonLeague_ChampionsRoom;cmd(7,m.g,m.m,0,0,360)
 if not F.check(name..': Champion room entered',finish()) then return end
 local o=m.objects.JohtoPokemonLeague_WillsRoom_EventScript_Lance
 if not F.check(name..': reached Lance',F.leg(o.x,o.y)) then return end
 F.face('Up');tap('A')
 local ok,n=finish(5000)
 F.check(name..': Lance is a battle',n and n==1)
 F.check(name..': ceremony returns to the field',ok,
   ok and '' or string.format('stuck cb2=%08x map=%d/%d',F.cb2(),F.grp(),F.mapn()))
 F.check(name..': Johto Champion recorded',flag(C.FLAG_JOHTO_CHAMPION))
 -- Task_Hof_TrySaveData's error path frees its buffers and DestroyTask()s itself with no
 -- replacement callback, which leaves CB2_HallOfFame spinning with nothing to advance it.
 -- Read the flag that selects that path rather than inferring it.
 F.L(string.format('  %s ended at map %d/%d cb2=%08x gDamagedSaveSectors=%d gSaveCounter=%d',
   name,F.grp(),F.mapn(),F.cb2(),F.r32(A.gDamagedSaveSectors),F.r32(A.gSaveCounter)))
 F.shot('hof_'..name)
end

F.run(function()
 local only=os.getenv('PW_HOF_CASE')
 for _,n in ipairs({'clean','egg','presaved','manysaves'}) do
  if not only or only==n then runCase(n) end
 end
 F.finish()
end)
