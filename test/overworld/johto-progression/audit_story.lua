package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local H=require('audit_helpers')('JohtoStoryAudit');local F,S,A,C,tap,cmd,state,flag,finish=H.F,H.S,H.A,H.C,H.tap,H.cmd,H.state,H.flag,H.finish
local maps=require('story_maps')
local function var(n,v) cmd(4,assert(C[n],n),v) end
local function set(n) cmd(3,(assert(C[n],n))) end
local function clear(n) cmd(5,(assert(C[n],n))) end
local function warp(n,script,x,y)
 local m=maps[n];local o=script and assert(m.objects[script],script) or m
 cmd(1,m.g,m.m,x or o.x,y or o.y,300)
 F.check(n..' map entered',F.grp()==m.g and F.mapn()==m.m)
end
local function talk() F.face('Up');tap('A');return finish() end
local function checkState(n,v) F.check(n..' advanced to '..v,state(C[n])==v,'actual='..state(C[n])) end
local cases={}
cases.errand=function()
 var('VAR_CHERRYGROVE_CITY_STATE',1);var('VAR_NEWBARKTOWN_LABSTATE',2)
 set('FLAG_HIDE_MRPOKEMON');clear('FLAG_DELIVERED_EGG');set('FLAG_JOHTO_STARTER_CHOSEN')
 warp('Route30_MrPokemonsHouse');F.check('Mr Pokemon errand finishes',finish());checkState('VAR_CHERRYGROVE_CITY_STATE',2);checkState('VAR_NEWBARKTOWN_LABSTATE',4)
 warp('NewBarkTown_Lab');F.check('theft return finishes',finish());checkState('VAR_NEWBARKTOWN_LABSTATE',5)
 F.check('Egg return unlocks adventure',flag(C.FLAG_JOHTO_ADVENTURE_STARTED))
 F.check('Egg return returns movement',F.step('Down'))
 assert(F.leg(6,11));F.step('Down');F.idle(90);F.check('aide balls handoff finishes',finish());checkState('VAR_NEWBARKTOWN_LABSTATE',6)
end
cases.sprout=function()
 set('FLAG_HIDE_SPROUT_TOWER_SILVER');var('VAR_SPROUT_TOWER',1)
 warp('SproutTower_3F','SproutTower_3F_EventScript_SageLi');local ok,n=talk();F.check('Sage Li battle finishes',ok and n==1);F.check('Sage Li returns movement',F.step('Down'))
end
cases.egg=function()
 var('VAR_VIOLET_CITY_STATE',3);clear('FLAG_HIDE_VIOLET_CITY_AIDE');set('FLAG_JOHTO_BADGE_1')
 warp('VioletCity_PokemonCenter','VioletCity_PokemonCenter_EventScript_Aide');F.check('Violet Egg handoff finishes',talk());F.check('Togepi Egg received',flag(C.FLAG_RECEIVED_TOGEPI_EGG));F.check('aide returns movement',F.step('Down'))
end
cases.medicine=function()
 var('VAR_OLIVINE_CITY_STATE',4);clear('FLAG_HIDE_LIGHTHOUSE_JASMINE');cmd(6)
 local m=maps.OlivineCity_Lighthouse;cmd(7,m.g,m.m,14,0,300);assert(F.leg(156,10));F.check('Ampharos healing scene finishes',talk());checkState('VAR_OLIVINE_CITY_STATE',5);F.check('Ampharos healed',flag(C.FLAG_AMPHAROS_HEALED));F.check('lighthouse releases control',F.step('Down'))
end
cases.surf=function()
 var('VAR_ECRUTEAK_CITY_THEATER',1);clear('FLAG_HIDE_ECRUTEAK_ROCKET');clear('FLAG_HIDE_ECRUTEAK_CITY_THEATER_ZUKI');set('FLAG_HIDE_ECRUTEAK_CITY_THEATER_KIMONOS')
 warp('EcruteakCity_Theater','EcruteakCity_Theater_EventScript_Rocket');local ok,n=talk();F.check('theater Rocket scene finishes',ok and n==1);checkState('VAR_ECRUTEAK_CITY_THEATER',2)
 warp('EcruteakCity_Theater','EcruteakCity_Theater_EventScript_SurfGuy');F.check('Surf gift finishes',talk());checkState('VAR_ECRUTEAK_CITY_THEATER',3);F.check('Surf gift releases control',F.step('Down'))
end
cases.cut=function()
 var('VAR_ILEX_FOREST_FARFETCHD',2);clear('FLAG_HIDE_ILEX_FOREST_MASTER');clear('FLAG_HIDE_ILEX_FOREST_APPRENTICE')
 warp('IlexForest',nil,25,43);F.step('Right');F.check('charcoal master Cut handoff finishes',finish());checkState('VAR_ILEX_FOREST_FARFETCHD',3);F.check('Cut received',flag(C.FLAG_RECEIVED_HM_CUT));F.check('Cut handoff returns movement',F.step('Down'))
end
cases.sudowoodo=function()
 set('FLAG_JOHTO_BADGE_3');clear('FLAG_HIDE_SUDOWOODO')
 warp('GoldenrodCity_FlowerShop','GoldenrodCity_FlowerShop_EventScript_Owner');F.check('Squirt Bottle gift finishes',talk());F.check('Squirt Bottle received',flag(C.FLAG_RECEIVED_SQUIRTBOTTLE))
 warp('Route36','Route36_EventScript_SudoWoodo');local ok,n=talk();F.check('Sudowoodo encounter and reward finish',ok and n==1);F.check('Sudowoodo clears road',flag(C.FLAG_HIDE_SUDOWOODO));F.check('Sudowoodo returns movement',F.step('Down'))
end
cases.kurt=function()
 var('VAR_AZALEA_TOWN_STATE',1);clear('FLAG_HIDE_KURT_1');set('FLAG_HIDE_KURT_2')
 warp('AzaleaTown_KurtsHouse','AzaleaTown_KurtsHouse_EventScript_KurtBefore');F.check('Kurt opens Well and finishes',talk());F.check('Well Rocket removed',flag(C.FLAG_HIDE_AZALEA_TOWN_WELL_ROCKET));F.check('Kurt returns movement',F.step('Down'))
end
cases.beasts=function()
 var('VAR_ECRUTEAK_CITY_STATE',3);clear('FLAG_HIDE_BURNED_TOWER_BEASTS');clear('FLAG_HIDE_BURNED_TOWER_B1F_EUSINE')
 warp('BurnedTower_B1F',nil,16,12);F.check('beast release scene finishes',finish(1500));F.check('Morty gate unlocked',flag(C.FLAG_RELEASED_BEASTS));checkState('VAR_ECRUTEAK_CITY_STATE',4);F.check('beast release returns movement',F.step('Down'))
end
cases.pharmacy=function()
 var('VAR_OLIVINE_CITY_STATE',3)
 warp('CianwoodShop','CianwoodCity_EventScript_Pharmacist');F.check('pharmacy medicine handoff finishes',talk());checkState('VAR_OLIVINE_CITY_STATE',4);F.check('pharmacist returns movement',F.step('Down'))
end
cases.petrel=function()
 var('VAR_GOLDENROD_CITY_STATE',6);clear('FLAG_HIDE_GOLDENROD_RADIOTOWER_DIRECTOR');set('FLAG_HIDE_GOLDENROD_RADIOTOWER_PETREL');clear('FLAG_HIDE_GOLDENROD_ROCKETS')
 warp('GoldenrodCity_RadioTower_5F','GoldenrodCity_RadioTower_5F_EventScript_Petrel');local ok,n=talk();F.check('Petrel battle and basement key finish',ok and n==1);checkState('VAR_GOLDENROD_CITY_STATE',7);F.check('Petrel returns movement',F.step('Down'))
end
cases.director=function()
 var('VAR_GOLDENROD_CITY_STATE',9);clear('FLAG_HIDE_GOLDENROD_ROCKETS')
 warp('GoldenrodCity_UndergroundStorage','GoldenrodCity_UndergroundStorage_EventScript_Director');F.check('Director Card Key handoff finishes',talk());checkState('VAR_GOLDENROD_CITY_STATE',9);F.check('Director returns movement',F.step('Down'))
 warp('GoldenrodCity_RadioTower_3F',nil,25,10);F.check('earned Card Key opens shutter without locking',talk());F.check('Radio Tower gate opens',flag(C.FLAG_HIDE_RADIOTOWER_GATE))
end
cases.archer=function()
 var('VAR_GOLDENROD_CITY_STATE',9);clear('FLAG_HIDE_GOLDENROD_ROCKETS');set('FLAG_HIDE_GOLDENROD_RADIOTOWER_DIRECTOR');set('FLAG_HIDE_GOLDENROD_RADIOTOWER_PETREL')
 warp('GoldenrodCity_RadioTower_5F','GoldenrodCity_RadioTower_5F_EventScript_Archer');local ok,n=talk();F.check('Archer battle and Director wing scene finish',ok and n==1);checkState('VAR_GOLDENROD_CITY_STATE',10);F.check('Archer returns movement',F.step('Down'))
end
cases.whirlpool=function()
 var('VAR_MAHOGANY_TOWN_STATE',13);var('VAR_ELECTRODES_FAINTED',3);clear('FLAG_HIDE_ROCKETHIDEOUT2_LANCE_DRAGONITE')
 warp('MahoganyHideout_B2F',nil,13,17);F.step('Right');F.check('generator and Whirlpool handoff finish',finish(1500));checkState('VAR_ELECTRODES_FAINTED',4);checkState('VAR_MAHOGANY_TOWN_STATE',14);F.check('generator returns movement',F.step('Down'))
end
cases['elm-gift']=function()
 var('VAR_NEWBARKTOWN_LABSTATE',7);clear('FLAG_HIDE_NEWBARKTOWN_LAB_AIDE')
 warp('NewBarkTown_Lab','NewBarkTown_Lab_EventScript_Elm');F.check('Elm Master Ball handoff finishes',talk());checkState('VAR_NEWBARKTOWN_LABSTATE',8);F.check('Elm returns movement',F.step('Down'))
end
cases['ss-ticket']=function()
 var('VAR_NEWBARKTOWN_LABSTATE',10);clear('FLAG_HIDE_NEWBARKTOWN_LAB_AIDE')
 warp('NewBarkTown_Lab','NewBarkTown_Lab_EventScript_Elm');F.check('Elm SS ticket handoff finishes',talk());checkState('VAR_NEWBARKTOWN_LABSTATE',11);F.check('Elm returns movement',F.step('Down'))
end
for _,entry in ipairs({'top','left','right'}) do
 cases['den-'..entry]=function()
  var('VAR_BLACKTHORN_CITY_STATE',2);set('FLAG_HIDE_DRAGONS_DEN_SHRINE_CLAIR')
  if entry=='top' then warp('DragonsDen_Shrine',nil,6,16);F.step('Up')
  elseif entry=='left' then warp('DragonsDen_Shrine',nil,6,16);F.step('Left')
  else warp('DragonsDen_Shrine',nil,6,16);F.step('Right') end
  F.check('Den '..entry..' quiz and Clair scene finish',finish(1400));F.check('Den '..entry..' awards Rising Badge',flag(C.FLAG_JOHTO_BADGE_8));checkState('VAR_BLACKTHORN_CITY_STATE',3)
  F.check('Den '..entry..' returns movement',F.step('Down'))
 end
end
for _,choice in ipairs({1,2}) do
 cases['kimono-'..choice]=function()
  var('VAR_ECRUTEAK_CITY_THEATER',5);var('VAR_LUGIA_OR_HOOH',choice)
  set('FLAG_HIDE_ECRUTEAK_ROCKET');set('FLAG_HIDE_ECRUTEAK_CITY_THEATER_NPCS');clear('FLAG_HIDE_ECRUTEAK_CITY_THEATER_KIMONOS');clear('FLAG_HIDE_ECRUTEAK_CITY_THEATER_ZUKI')
  warp('EcruteakCity_Theater');F.step('Up');local ok,n=finish(2000);F.check('Kimono '..choice..' gauntlet finishes',ok);F.check('Kimono '..choice..' plays all five battles',n==5,'battles='..n);checkState('VAR_ECRUTEAK_CITY_THEATER',7);F.check('Kimono '..choice..' returns movement',F.step('Down'))
 end
end
F.run(function()
 local order={'errand','sprout','egg','cut','sudowoodo','kurt','beasts','pharmacy','medicine','surf','petrel','director','archer','whirlpool','elm-gift','ss-ticket','den-top','den-left','den-right','kimono-1','kimono-2'}
 for _,n in ipairs(order) do
  if not os.getenv('PW_AUDIT_STORY') or os.getenv('PW_AUDIT_STORY')==n then
   F.L('STORY '..n);client.reboot_core();F.idle(120);H.boot();cases[n]();F.shot(n..'_complete')
  end
 end
 F.finish()
end)
