-- Does the Johto Hall of Fame ceremony return to the field once the game has been saved?
--
-- The continuous run beat Lance, recorded FLAG_JOHTO_CHAMPION, and then sat in CB2_HallOfFame
-- for 120,000 frames while being fed A. audit_league.lua runs the same ceremony and passes.
--
-- The two runs differ in exactly one way that matters: the continuous run has already written a
-- save, at its mid-arc and late-arc checkpoints, before the ceremony writes its own. Party is
-- NOT the difference -- audit_helpers' boot() grants a Chikorita, so audit_league has a party
-- too. That left the save as the thing to test.
--
-- It matters because src/hall_of_fame.c's Task_Hof_TrySaveData has a dead end: when
-- TrySavingData(SAVE_HALL_OF_FAME) returns SAVE_STATUS_ERROR with damaged sectors it frees its
-- buffers and DestroyTask()s itself without installing another callback and without telling the
-- player. CB2_HallOfFame then remains the main callback with no task left to advance it, which
-- is a permanent hang on precisely the screen observed.
--
-- Both cases mirror audit_league's champion sequence exactly so the only variable is the save.
-- PW_HOF_CASE selects one: 'clean' or 'presaved'.
package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local H=require('audit_helpers')('JohtoHallOfFame');local F,S,A,C,tap,cmd,state,flag,finish=H.F,H.S,H.A,H.C,H.tap,H.cmd,H.state,H.flag,H.finish
local maps=require('story_maps')

-- Saving over an existing file adds an "there is already a save file" confirmation, so a fixed
-- number of A presses succeeds the first time and silently fails afterwards. Confirm until the
-- save counter actually moves, and report failure on the counter rather than on the presses.
local function saveThroughMenu()
 local before=F.r32(A.gSaveCounter)
 tap('Start');F.idle(60)
 if not F.selectStartIcon(7) then return false end
 for _=1,8 do
  tap('A',1,90)
  if F.r32(A.gSaveCounter)~=before then F.idle(300);return true end
 end
 F.idle(300)
 return F.r32(A.gSaveCounter)~=before
end

local function runCase(name)
 F.L('HOF CASE '..name)
 client.reboot_core();F.idle(120)
 -- No expected group: once a save exists the game Continues instead of landing in the hub.
 assert(F.boot(),name..': boot')
 cmd(0,0)
 F.w8(F.sb2()+S.SaveBlock2.currentRegion,2);F.w32(S.gCurrentRegion,2)
 F.L('  party count '..F.r8(S.gPartiesCount))
 cmd(4,C.VAR_LEAGUE_STATE,5)
 for i=0,7 do cmd(3,C.FLAG_JOHTO_BADGE_1+i) end
 cmd(4,C.VAR_ECRUTEAK_CITY_THEATER,8)

 if name=='presaved' or name=='manysaves' then
  -- Write save(s) first, as the continuous run's checkpoints do. 'manysaves' writes several so
  -- the save sectors have been cycled, which is the other way the continuous run differs.
  local p=maps.JohtoIndigoPlateau_PokemonCenter;cmd(1,p.g,p.m,20,12,300)
  local n=(name=='manysaves') and 3 or 1
  for i=1,n do F.check(string.format('%s: pre-ceremony save %d written',name,i),saveThroughMenu()) end
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
 for _,n in ipairs({'clean','presaved','manysaves'}) do
  if not only or only==n then runCase(n) end
 end
 F.finish()
end)
