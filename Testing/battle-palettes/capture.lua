package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local F,S,U,X,tap,hook,controller,action,exitBattle=require('bw_helpers')('BattlePaletteCapture')
local P=require('palette_symbols')
local function colors(banks)
 local t={}
 for _,b in ipairs(banks) do for i=0,15 do t[#t+1]=F.r16(P.gPlttBufferUnfaded+b*32+i*2) end end
 return table.concat(t,',')
end
F.run(function()
 assert(F.boot(100));hook(202,0)
 local ui
 local cases={{0,12,'ice_1f'},{1,12,'ice_b1f'},{2,12,'ice_b2f'},{3,12,'ice_b3f'},{4,12,'ice_b4f'},
  {5,12,'snow_day'},{6,12,'summit_day'},{7,12,'granite'},
  {8,12,'hoenn_day'},{8,22,'hoenn_night'},{9,12,'johto_day'},{9,22,'johto_night'},
  {10,12,'kanto_day'},{10,22,'kanto_night'},{8,6,'hoenn_morning'},{8,19,'hoenn_evening'},
  {5,22,'snow_night'}}
 for _,v in ipairs(cases) do
  hook(200,v[1],480);hook(201,v[2]);F.check(v[3]..' field',F.ow());F.shot(v[3]..'_field')
  hook(1,0,600);assert(action());F.shot(v[3]..'_commands');tap('A');F.shot(v[3]..'_moves')
  local p=colors({0,1,10,11,12,13});if ui then F.check(v[3]..' UI unchanged',p==ui) else ui=p end
  F.L('PALETTE '..v[3]..' '..colors({2,3,4}))
  F.L('UI '..v[3]..' '..colors({0,1,10,11,12,13,14}))
  F.L('OBJ '..v[3]..' '..colors({16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31}))
  F.L('ENVIRONMENT '..v[3]..' '..F.r8(P.gBattleEnvironment))
  if P.sBattlePresentationCaptured then F.check(v[3]..' captured',F.r8(P.sBattlePresentationCaptured)==1) end
  tap('B');F.check(v[3]..' returns to field',exitBattle())
  if P.sBattlePresentationCaptured then F.check(v[3]..' clears capture',F.r8(P.sBattlePresentationCaptured)==0) end
 end
 for _,loc in ipairs({0,5}) do for variant=1,2 do
  hook(202,variant);hook(200,loc,480);hook(201,12);hook(1,0,600);assert(action())
  F.shot(string.format('contrast_%d_%d',loc,variant));F.check('contrast return',exitBattle())
 end end
 F.finish()
end)
