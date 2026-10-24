-- One continuous Johto save, played in story order with no reboot between beats.
--
-- Every other case in this directory reboots the core, warps straight to one beat and hand-sets
-- that beat's prerequisites. That proves each script works in isolation; it cannot see anything
-- that only goes wrong once state has accumulated, which is where the reported freezes live.
--
-- This suite boots ONE save and never reboots it (except at the deliberate save/Continue
-- checkpoints, which reload that same save). Beats run in the order a player meets them.
--
-- Before each beat it asks whether the prerequisite state is ALREADY satisfied by the beats that
-- ran before it. When it is not, that is recorded as a chain gap -- the progression chain does
-- not carry the player from one beat to the next on its own -- and the prerequisite is then
-- staged so the run can continue and keep hunting for freezes. Chain gaps are reported, not
-- asserted: a beat whose trigger is a walk-on tile this suite does not walk is an expected gap,
-- so a human reads the list rather than the suite failing on it.
--
-- What IS asserted at every beat: no crash screen, the script runs to completion, the overworld
-- script context comes back free, player control returns, and the beat's own post-state advanced.
package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local H=require('audit_helpers')('JohtoContinuous');local F,S,A,C,tap,cmd,state,flag,finish,free=H.F,H.S,H.A,H.C,H.tap,H.cmd,H.state,H.flag,H.finish,H.free
local maps=require('story_maps');local gyms=require('gym_cases')

local function var(n,v) cmd(4,assert(C[n],n),v) end
-- The extra parentheses matter: assert() returns value AND message, and cmd()'s next parameter
-- is a u16 write, so the bare form passes the constant's NAME as the next argument.
local function set(n) cmd(3,(assert(C[n],n))) end
local function clear(n) cmd(5,(assert(C[n],n))) end
local function trainer(id)
 local p,n
 if id>=1727 then p=F.sb3()+S.SaveBlock3.johtoTrainerFlags;n=id-1727
 else p=F.sb1()+S.SaveBlock1.flags;n=0x500+id end
 return F.r8(p+n//8)&(1<<(n%8))~=0
end

local gaps={}
-- Record, rather than assert, that the chain did not carry us here by itself.
local function need(beat,what,satisfied,stage)
 if satisfied() then return end
 gaps[#gaps+1]=beat..': '..what
 F.L('  CHAIN GAP '..beat..': '..what..' was not set by the preceding beats; staging it')
 stage()
end
local function needVar(beat,name,want)
 need(beat,name..'='..want,function() return state(C[name])==want end,function() var(name,want) end)
end
local function needFlag(beat,name)
 need(beat,name,function() return flag(C[name]) end,function() set(name) end)
end

local function warp(n,script,x,y)
 local m=maps[n];local o=script and assert(m.objects[script],script) or m
 cmd(1,m.g,m.m,x or o.x,y or o.y,300)
 return F.check(n..' entered',F.grp()==m.g and F.mapn()==m.m)
end
local function talk() F.face('Up');tap('A');return finish() end

-- Every beat funnels through here so no beat can forget the four invariants.
--
-- control: how to prove the player got control back. The default is a step south, but Chuck's
-- arena is boxed in by unpushed boulders, so a step there proves nothing about control and
-- fails for reasons that have nothing to do with the beat. 'menu' opens the Start menu instead,
-- which needs exactly the same field control without needing a free tile.
-- Opening Start alone is not proof: the menu is an overlay task and the callback stays
-- CB2_Overworld. Entering a submenu is what actually leaves the overworld callback, so that is
-- what gets asserted -- the same technique audit_gyms.lua uses for Chuck.
local function controlViaMenu()
 tap('Start');F.idle(60)
 if not F.selectStartIcon(1) then return false end
 tap('A',1,180)
 local left=not F.ow()
 tap('B');tap('B');F.idle(90)
 return left
end
local function beat(name,body,control)
 F.L('BEAT '..name)
 F.check(name..': no crash on arrival',not F.reportCrash(name..'_arrival'))
 local ok=body()
 F.check(name..': script finishes',ok)
 if not ok then F.shot(name..'_stuck');return false end
 F.check(name..': no crash after script',not F.reportCrash(name..'_after'))
 F.check(name..': script context free',free())
 F.check(name..': control returns',control=='menu' and controlViaMenu() or F.step('Down'))
 return true
end

-- Save through the real menu, reboot, Continue, and prove the save survived mid-arc.
--
-- The expected group is READ before saving rather than written in here. A checkpoint can fall on
-- an indoor map, and a hard-coded group is the usual cause of a spurious BOOT FAIL -- the suite
-- then blames the save for a mismatch it invented itself.
local function checkpoint(tag)
 local wantGroup,wantMap=F.grp(),F.mapn()
 F.L(string.format('CHECKPOINT %s saving in %d/%d',tag,wantGroup,wantMap))
 tap('Start');F.idle(60)
 if not F.check(tag..': Save icon present',F.selectStartIcon(7)) then return false end
 tap('A',1,90);tap('A',1,90);tap('A',1,90);F.idle(600)
 client.reboot_core();F.idle(240)
 -- Boot with no expected group. A save can legitimately sit on a staircase or door tile, and
 -- Continue then resumes and immediately warps, so demanding the exact saved map makes the
 -- blind boot loop mash A until it wanders into a menu -- which is what it did. What this
 -- checkpoint is really for is that the save survives and comes back interactive.
 if not F.check(tag..': Continue boots',F.boot()) then return false end
 F.L(string.format('  %s saved in %d/%d, continued in %d/%d',tag,wantGroup,wantMap,F.grp(),F.mapn()))
 F.check(tag..': Continue returns control',F.ensureFree())
 F.check(tag..': no crash after Continue',not F.reportCrash(tag..'_continue'))
 -- The save reloads SaveBlock pointers, so re-assert the region the fixture commands key off.
 F.w8(F.sb2()+S.SaveBlock2.currentRegion,2);F.w32(S.gCurrentRegion,2)
 F.shot(tag..'_continue')
 return true
end

local function gym(index)
 local c=gyms[index]
 -- Chuck's arena is walled in by unpushed boulders; prove control through the menu instead.
 return beat('gym-'..c.name,function()
  cmd(1,c.g,c.m,c.x,c.y,360)
  if not F.check(c.name..' positioned beside leader',F.grp()==c.g and F.mapn()==c.m) then return false end
  local ok,n=talk()
  F.check(c.name..' battle reaches the command menu',n and n>=1)
  if not ok then return false end
  -- Whitney's badge comes from a SECOND conversation, which only unlocks after her exit
  -- trigger fires. Walking into that trigger takes a first unconditional step south; dropping
  -- it leaves her at state 3 and no badge is ever awarded.
  if c.name=='Whitney' then
   F.check('Whitney reaches her crying state',state(0xa083)==3)
   if not F.step('Down') then return false end
   finish()
   if state(0xa083)==3 then F.step('Down');finish();F.idle(40);finish() end
   if state(0xa083)==3 then F.step('Up');F.idle(45);F.step('Down');F.idle(90);finish() end
   F.check('Whitney exit advances badge state',state(0xa083)==4)
   if F.leg(c.x,c.y) then talk() end
  end
  for _,id in ipairs(c.trainers) do F.check(c.name..' subordinate cleared '..id,trainer(id)) end
  local clean=true
  for _,id in ipairs(c.hoenn) do if trainer(id) then clean=false end end
  F.check(c.name..' leaves the Hoenn Gym trainers alone',clean)
  if c.name=='Clair' then F.check('Clair opens Dragons Den',state(0xa0ab)==2)
  else F.check(c.name..' awards its badge',flag(c.badge)) end
  return true
 end,c.name=='Chuck' and 'menu' or nil)
end

F.run(function()
 assert(F.boot(100),'fresh hub boot')
 F.w8(F.sb2()+S.SaveBlock2.currentRegion,2);F.w32(S.gCurrentRegion,2)
 -- A player arrives in Johto with a starter and nothing else. Grant exactly that.
 cmd(0,tonumber(os.getenv('PW_CONTINUOUS_SPECIES')) or 0)
 set('FLAG_SYS_POKEMON_GET')
 F.check('run starts with a party',F.r8(S.gPartiesCount)>0)

 -- ---- New Bark and the errand -------------------------------------------------------------
 beat('errand-mr-pokemon',function()
  needVar('errand-mr-pokemon','VAR_CHERRYGROVE_CITY_STATE',1)
  needVar('errand-mr-pokemon','VAR_NEWBARKTOWN_LABSTATE',2)
  needFlag('errand-mr-pokemon','FLAG_HIDE_MRPOKEMON')
  needFlag('errand-mr-pokemon','FLAG_JOHTO_STARTER_CHOSEN')
  clear('FLAG_DELIVERED_EGG')
  if not warp('Route30_MrPokemonsHouse') then return false end
  local ok=finish()
  F.check('errand advances Cherrygrove',state(C.VAR_CHERRYGROVE_CITY_STATE)==2)
  F.check('errand advances the lab',state(C.VAR_NEWBARKTOWN_LABSTATE)==4)
  return ok
 end)
 beat('errand-theft-return',function()
  if not warp('NewBarkTown_Lab') then return false end
  local ok=finish()
  F.check('theft return advances the lab',state(C.VAR_NEWBARKTOWN_LABSTATE)==5)
  F.check('Egg return unlocks the adventure',flag(C.FLAG_JOHTO_ADVENTURE_STARTED))
  return ok
 end)

 -- ---- Violet ------------------------------------------------------------------------------
 beat('sprout-tower',function()
  needVar('sprout-tower','VAR_SPROUT_TOWER',1)
  needFlag('sprout-tower','FLAG_HIDE_SPROUT_TOWER_SILVER')
  if not warp('SproutTower_3F','SproutTower_3F_EventScript_SageLi') then return false end
  local ok,n=talk()
  F.check('Sage Li battle happens',n and n==1)
  return ok
 end)
 gym(1) -- Falkner
 beat('togepi-egg',function()
  needVar('togepi-egg','VAR_VIOLET_CITY_STATE',3)
  needFlag('togepi-egg','FLAG_JOHTO_BADGE_1')
  clear('FLAG_HIDE_VIOLET_CITY_AIDE')
  if not warp('VioletCity_PokemonCenter','VioletCity_PokemonCenter_EventScript_Aide') then return false end
  local ok=talk()
  F.check('Togepi Egg received',flag(C.FLAG_RECEIVED_TOGEPI_EGG))
  return ok
 end)

 -- ---- Azalea ------------------------------------------------------------------------------
 beat('kurt-slowpoke-well',function()
  needVar('kurt-slowpoke-well','VAR_AZALEA_TOWN_STATE',1)
  clear('FLAG_HIDE_KURT_1');set('FLAG_HIDE_KURT_2')
  if not warp('AzaleaTown_KurtsHouse','AzaleaTown_KurtsHouse_EventScript_KurtBefore') then return false end
  local ok=talk()
  F.check('Well Rocket removed',flag(C.FLAG_HIDE_AZALEA_TOWN_WELL_ROCKET))
  return ok
 end)
 gym(2) -- Bugsy
 beat('ilex-cut',function()
  needVar('ilex-cut','VAR_ILEX_FOREST_FARFETCHD',2)
  clear('FLAG_HIDE_ILEX_FOREST_MASTER');clear('FLAG_HIDE_ILEX_FOREST_APPRENTICE')
  if not warp('IlexForest',nil,25,43) then return false end
  F.step('Right')
  local ok=finish()
  F.check('Cut received',flag(C.FLAG_RECEIVED_HM_CUT))
  F.check('Ilex advances',state(C.VAR_ILEX_FOREST_FARFETCHD)==3)
  return ok
 end)

 -- ---- Goldenrod ---------------------------------------------------------------------------
 gym(3) -- Whitney
 beat('sudowoodo',function()
  needFlag('sudowoodo','FLAG_JOHTO_BADGE_3')
  clear('FLAG_HIDE_SUDOWOODO')
  if not warp('GoldenrodCity_FlowerShop','GoldenrodCity_FlowerShop_EventScript_Owner') then return false end
  if not talk() then return false end
  F.check('Squirt Bottle received',flag(C.FLAG_RECEIVED_SQUIRTBOTTLE))
  if not warp('Route36','Route36_EventScript_SudoWoodo') then return false end
  local ok,n=talk()
  F.check('Sudowoodo is a battle',n and n==1)
  F.check('Sudowoodo clears the road',flag(C.FLAG_HIDE_SUDOWOODO))
  return ok
 end)

 if not checkpoint('mid-arc') then F.finish();return end

 -- ---- Ecruteak ----------------------------------------------------------------------------
 beat('burned-tower-beasts',function()
  needVar('burned-tower-beasts','VAR_ECRUTEAK_CITY_STATE',3)
  clear('FLAG_HIDE_BURNED_TOWER_BEASTS');clear('FLAG_HIDE_BURNED_TOWER_B1F_EUSINE')
  if not warp('BurnedTower_B1F',nil,16,12) then return false end
  local ok=finish(1500)
  F.check('beasts released',flag(C.FLAG_RELEASED_BEASTS))
  F.check('Ecruteak advances',state(C.VAR_ECRUTEAK_CITY_STATE)==4)
  return ok
 end)
 gym(4) -- Morty
 beat('theater-surf',function()
  needVar('theater-surf','VAR_ECRUTEAK_CITY_THEATER',1)
  clear('FLAG_HIDE_ECRUTEAK_ROCKET');clear('FLAG_HIDE_ECRUTEAK_CITY_THEATER_ZUKI')
  set('FLAG_HIDE_ECRUTEAK_CITY_THEATER_KIMONOS')
  if not warp('EcruteakCity_Theater','EcruteakCity_Theater_EventScript_Rocket') then return false end
  local ok,n=talk()
  F.check('theater Rocket is a battle',n and n==1)
  F.check('theater advances',state(C.VAR_ECRUTEAK_CITY_THEATER)==2)
  if not ok then return false end
  if not warp('EcruteakCity_Theater','EcruteakCity_Theater_EventScript_SurfGuy') then return false end
  ok=talk()
  F.check('Surf granted',state(C.VAR_ECRUTEAK_CITY_THEATER)==3)
  return ok
 end)

 -- ---- Cianwood and Olivine ----------------------------------------------------------------
 beat('cianwood-pharmacy',function()
  needVar('cianwood-pharmacy','VAR_OLIVINE_CITY_STATE',3)
  if not warp('CianwoodShop','CianwoodCity_EventScript_Pharmacist') then return false end
  local ok=talk()
  F.check('medicine collected',state(C.VAR_OLIVINE_CITY_STATE)==4)
  return ok
 end)
 gym(5) -- Chuck
 beat('lighthouse-ampharos',function()
  needVar('lighthouse-ampharos','VAR_OLIVINE_CITY_STATE',4)
  clear('FLAG_HIDE_LIGHTHOUSE_JASMINE');cmd(6)
  local m=maps.OlivineCity_Lighthouse;cmd(7,m.g,m.m,14,0,300)
  if not F.check('lighthouse entered',F.grp()==m.g and F.mapn()==m.m) then return false end
  if not F.leg(156,10) then return false end
  local ok=talk()
  F.check('Ampharos healed',flag(C.FLAG_AMPHAROS_HEALED))
  F.check('Olivine advances',state(C.VAR_OLIVINE_CITY_STATE)==5)
  return ok
 end)
 gym(6) -- Jasmine

 -- ---- Mahogany ----------------------------------------------------------------------------
 gym(7) -- Pryce, the reported battle-start crash
 beat('rocket-generator',function()
  needVar('rocket-generator','VAR_MAHOGANY_TOWN_STATE',13)
  needVar('rocket-generator','VAR_ELECTRODES_FAINTED',3)
  clear('FLAG_HIDE_ROCKETHIDEOUT2_LANCE_DRAGONITE')
  if not warp('MahoganyHideout_B2F',nil,13,17) then return false end
  F.step('Right')
  local ok=finish(1500)
  F.check('generator shut down',state(C.VAR_ELECTRODES_FAINTED)==4)
  F.check('Mahogany advances',state(C.VAR_MAHOGANY_TOWN_STATE)==14)
  return ok
 end)

 -- ---- Radio Tower -------------------------------------------------------------------------
 beat('radio-petrel',function()
  needVar('radio-petrel','VAR_GOLDENROD_CITY_STATE',6)
  clear('FLAG_HIDE_GOLDENROD_RADIOTOWER_DIRECTOR');set('FLAG_HIDE_GOLDENROD_RADIOTOWER_PETREL')
  clear('FLAG_HIDE_GOLDENROD_ROCKETS')
  if not warp('GoldenrodCity_RadioTower_5F','GoldenrodCity_RadioTower_5F_EventScript_Petrel') then return false end
  local ok,n=talk()
  F.check('Petrel is a battle',n and n==1)
  F.check('Goldenrod advances to 7',state(C.VAR_GOLDENROD_CITY_STATE)==7)
  return ok
 end)
 beat('radio-director',function()
  needVar('radio-director','VAR_GOLDENROD_CITY_STATE',9)
  clear('FLAG_HIDE_GOLDENROD_ROCKETS')
  if not warp('GoldenrodCity_UndergroundStorage','GoldenrodCity_UndergroundStorage_EventScript_Director') then return false end
  if not talk() then return false end
  if not warp('GoldenrodCity_RadioTower_3F',nil,25,10) then return false end
  local ok=talk()
  F.check('Card Key opens the shutter',flag(C.FLAG_HIDE_RADIOTOWER_GATE))
  return ok
 end)
 beat('radio-archer',function()
  needVar('radio-archer','VAR_GOLDENROD_CITY_STATE',9)
  set('FLAG_HIDE_GOLDENROD_RADIOTOWER_DIRECTOR');set('FLAG_HIDE_GOLDENROD_RADIOTOWER_PETREL')
  if not warp('GoldenrodCity_RadioTower_5F','GoldenrodCity_RadioTower_5F_EventScript_Archer') then return false end
  local ok,n=talk()
  F.check('Archer is a battle',n and n==1)
  F.check('Goldenrod advances to 10',state(C.VAR_GOLDENROD_CITY_STATE)==10)
  return ok
 end)

 if not checkpoint('late-arc') then F.finish();return end

 -- ---- Blackthorn --------------------------------------------------------------------------
 gym(8) -- Clair
 beat('dragons-den',function()
  needVar('dragons-den','VAR_BLACKTHORN_CITY_STATE',2)
  set('FLAG_HIDE_DRAGONS_DEN_SHRINE_CLAIR')
  if not warp('DragonsDen_Shrine',nil,6,16) then return false end
  F.step('Up')
  local ok=finish(1400)
  F.check('Rising Badge awarded',flag(C.FLAG_JOHTO_BADGE_8))
  F.check('Blackthorn advances',state(C.VAR_BLACKTHORN_CITY_STATE)==3)
  return ok
 end)

 -- ---- Kimono girls and Elm's gifts --------------------------------------------------------
 beat('kimono-gauntlet',function()
  needVar('kimono-gauntlet','VAR_ECRUTEAK_CITY_THEATER',5)
  var('VAR_LUGIA_OR_HOOH',1)
  set('FLAG_HIDE_ECRUTEAK_ROCKET');set('FLAG_HIDE_ECRUTEAK_CITY_THEATER_NPCS')
  clear('FLAG_HIDE_ECRUTEAK_CITY_THEATER_KIMONOS');clear('FLAG_HIDE_ECRUTEAK_CITY_THEATER_ZUKI')
  if not warp('EcruteakCity_Theater') then return false end
  F.step('Up')
  local ok,n=finish(2000)
  F.check('all five Kimono battles play',n==5,'battles='..tostring(n))
  F.check('theater reaches 7',state(C.VAR_ECRUTEAK_CITY_THEATER)==7)
  return ok
 end)
 beat('elm-master-ball',function()
  needVar('elm-master-ball','VAR_NEWBARKTOWN_LABSTATE',7)
  clear('FLAG_HIDE_NEWBARKTOWN_LAB_AIDE')
  if not warp('NewBarkTown_Lab','NewBarkTown_Lab_EventScript_Elm') then return false end
  local ok=talk()
  F.check('lab advances to 8',state(C.VAR_NEWBARKTOWN_LABSTATE)==8)
  return ok
 end)
 beat('elm-ss-ticket',function()
  needVar('elm-ss-ticket','VAR_NEWBARKTOWN_LABSTATE',10)
  clear('FLAG_HIDE_NEWBARKTOWN_LAB_AIDE')
  if not warp('NewBarkTown_Lab','NewBarkTown_Lab_EventScript_Elm') then return false end
  local ok=talk()
  F.check('lab advances to 11',state(C.VAR_NEWBARKTOWN_LABSTATE)==11)
  return ok
 end)

 -- ---- The Johto League --------------------------------------------------------------------
 needVar('league','VAR_LEAGUE_STATE',1)
 for i=0,7 do cmd(3,C.FLAG_JOHTO_BADGE_1+i) end
 var('VAR_ECRUTEAK_CITY_THEATER',8)

 -- Walk in through the real door rather than warping into Will's Room. Every other League test
 -- here warps straight into the rooms, which is exactly why none of them could see that the
 -- Plateau Centre's only approach tile to that door was occupied by an NPC on every save.
 beat('league-entrance',function()
  local r=maps.Route27
  cmd(1,r.g,r.m,25,23,300)
  if not F.check('Route 27 entered',F.grp()==r.g and F.mapn()==r.m) then return false end
  if not F.check('first-steps trigger stepped on',F.step('Down')) then return false end
  if not finish(900) then return false end
  F.check('Route 27 clears the League approach',flag(C.FLAG_HIDE_LEAGUE_BLACKBELT))
  local p=maps.JohtoIndigoPlateau_PokemonCenter
  cmd(1,p.g,p.m,32,6,300)
  if not F.check('Plateau Centre entered',F.grp()==p.g and F.mapn()==p.m) then return false end
  -- Climb the corridor to the door at (32,2); stepping onto it triggers the warp.
  for _=1,6 do
   local _,y=F.pos()
   if y<=2 then break end
   if not F.step('Up') then break end
  end
  local x,y=F.pos()
  F.L(string.format('  stopped at (%d,%d) on the way to the door',x,y))
  F.idle(180)
  local w=maps.JohtoPokemonLeague_WillsRoom
  F.check('walking the door reaches Will\'s Room',F.grp()==w.g and F.mapn()==w.m,
    string.format('at %d/%d, wanted %d/%d',F.grp(),F.mapn(),w.g,w.m))
  return true
 end)
 local elite={
  {'JohtoPokemonLeague_WillsRoom','JohtoPokemonLeague_WillsRoom_EventScript_Will'},
  {'JohtoPokemonLeague_KogasRoom','JohtoPokemonLeague_KogasRoom_EventScript_Koga'},
  {'JohtoPokemonLeague_BrunosRoom','JohtoPokemonLeague_BrunosRoom_EventScript_Bruno'},
  {'JohtoPokemonLeague_KarensRoom','JohtoPokemonLeague_KarensRoom_EventScript_Karen'},
 }
 for i,c in ipairs(elite) do
  beat('league-'..c[1]:gsub('JohtoPokemonLeague_',''),function()
   local m=maps[c[1]];cmd(7,m.g,m.m,i==2 and 1 or 0,0,360)
   if not finish() then return false end
   local o=m.objects[c[2]]
   if not F.leg(o.x,o.y) then return false end
   F.face('Up');tap('A')
   local ok,n=finish(1500)
   F.check(c[1]..' is a battle',n and n==1)
   F.check(c[1]..' advances the League',state(C.VAR_LEAGUE_STATE)==i+1)
   return ok
  end)
 end
 beat('league-champion',function()
  local m=maps.JohtoPokemonLeague_ChampionsRoom;cmd(7,m.g,m.m,0,0,360)
  if not finish() then return false end
  local o=m.objects.JohtoPokemonLeague_WillsRoom_EventScript_Lance
  if not F.leg(o.x,o.y) then return false end
  F.face('Up');tap('A')
  local ok,n=finish(2500)
  F.check('Lance is a battle',n and n==1)
  F.check('Johto Champion recorded',flag(C.FLAG_JOHTO_CHAMPION))
  return ok
 end)

 -- The Hall of Fame sets New Bark as the respawn, which is the whiteout freeze's own trigger.
 F.check('champion save Continues',checkpoint('champion'))
 F.check('Johto Champion persists',flag(C.FLAG_JOHTO_CHAMPION))
 F.shot('champion_end')

 F.L(string.format('CHAIN GAPS: %d',#gaps))
 for _,g in ipairs(gaps) do F.L('  gap '..g) end
 F.finish()
end)
