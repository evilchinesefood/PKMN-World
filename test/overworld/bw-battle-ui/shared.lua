package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local F,S,U,X,tap,hook,controller,action,exitBattle=require('bw_helpers')('BWShared')
local function tasks(fn)
 local n=0
 for i=0,15 do local p=S.gTasks+i*40
  if F.r8(p+4)~=0 and (F.r32(p)&~1)==fn then n=n+1 end
 end
 return n
end
F.run(function()
 assert(F.boot(100));hook(0);hook(4,0,300);hook(1,0,600);assert(action())
 tap('Down');tap('A',1,240)
 F.check('battle party owns input',tasks(U.Task_HandleChooseMonInput)==1);F.shot('battle_party')
 tap('A');F.shot('party_context');tap('Down');tap('A',1,240)
 F.check('battle Summary opened',F.r32(U.sMonSummaryScreen)~=0);F.shot('summary')
 for i=1,5 do tap('Right');F.shot('summary_page_'..i) end
 tap('B',1,240)
 tap('B') -- Summary returns to the selected Pokémon's context menu.
 F.check('Summary returned to party',F.r32(U.sMonSummaryScreen)==0 and tasks(U.Task_HandleChooseMonInput)==1)
 tap('B',1,240);F.check('party returned to battle',action());F.shot('party_return')
 assert(exitBattle());hook(5,0,1)
 local sawHatch=false;local sawMessage=false
 for i=1,600 do
  F.idle(3)
  if (F.r32(S.gMain+4)&~1)==U.CB2_EggHatch then
   sawHatch=true
   local p=F.r32(U.sEggHatchData)
   if p~=0 and F.r8(p+2)>=6 and not sawMessage then sawMessage=true;F.shot('hatch_message') end
  end
  if i%12==0 then F.shot('hatch_'..string.format('%03d',i)) end
  if sawHatch and F.ow() then break end
  if i>400 then tap('B',1,2) end
 end
 F.check('actual hatch callback ran',sawHatch)
 F.check('hatch returned to field',F.ow());assert(F.ow())
 hook(7);F.check('hatched Eevee is not an egg',F.r16(X.gSpecialVar_0x8005)==133 and F.r16(U.gSpecialVar_0x8006)==0)
 hook(6,0,1)
 local sawTrade=false
 for i=1,2400 do
  F.idle(3)
  sawTrade=sawTrade or (F.r32(S.gMain+4)&~1)==U.CB2_InGameTrade
  if i%24==0 then F.shot('trade_'..string.format('%04d',i)) end
  if sawTrade and F.ow() then break end
  if i%20==0 then tap('A',1,1) end
 end
 F.check('actual trade animation ran',sawTrade)
 F.check('trade returned to field',F.ow());assert(F.ow())
 hook(7);F.check('trade received Magikarp',F.r16(X.gSpecialVar_0x8005)==129)
 hook(1,0,600);F.check('battle reopens after shared scenes',action());F.shot('battle_after_shared');assert(exitBattle())
 F.finish()
end)
