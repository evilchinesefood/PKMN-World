-- One real wild battle per battle background. Each case stands on the tile, or inside the map,
-- that should select it, and checks the battlefield palette banks against the authored palette.
package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local F,S,U,X,tap,hook,controller,action,exitBattle=require('bw_helpers')('BattleBackgrounds')
local P=require('palette_symbols')
local function matches(symbol)
 local rom=assert(P['gBattleEnvironmentPalette_'..symbol],symbol)
 for i=0,47 do if F.r16(P.gPlttBufferUnfaded+64+i*2)~=F.r16(rom+i*2) then return false end end
 return true
end
-- {fixture location index, name, authored palette}
local cases={
 {0,'tall_grass','TallGrass'},{1,'long_grass','LongGrass'},{2,'sand','Sand'},{3,'water','Water'},
 {4,'pond','PondWater'},{5,'underwater','Underwater'},{6,'mountain','Rock'},{7,'cave','Cave'},
 {8,'plain','Plain'},{9,'building','Building'},{10,'frlg_indoor','Building'},
 {11,'gym_hoenn','BuildingGym'},{12,'gym_johto','BuildingGym'},{13,'aqua','BuildingAqua'},
 {14,'frontier','Frontier'},
 {15,'sidney','StadiumSidney'},{16,'phoebe','StadiumPhoebe'},{17,'glacia','StadiumGlacia'},{18,'drake','StadiumDrake'},
 {19,'lorelei','StadiumGlacia'},{20,'bruno_kanto','StadiumSidney'},{21,'agatha','StadiumPhoebe'},{22,'lance','StadiumDrake'},
 {23,'will','StadiumGlacia'},{24,'koga','StadiumPhoebe'},{25,'bruno_johto','StadiumSidney'},{26,'karen','StadiumDrake'},
}
F.run(function()
 assert(F.boot(100));hook(202,0)
 for _,v in ipairs(cases) do
  hook(207,v[1],480);hook(201,12);F.check(v[2]..' field',F.ow())
  hook(1,0,600);assert(action());F.shot(v[2])
  F.L('ENVIRONMENT '..v[2]..' '..F.r8(P.gBattleEnvironment))
  F.check(v[2]..' draws the '..v[3]..' palette',matches(v[3]))
  F.check(v[2]..' returns to field',exitBattle())
 end
 F.finish()
end)
