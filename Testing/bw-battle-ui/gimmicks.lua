package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local F,S,U,X,tap,hook,controller,action,exitBattle=require('bw_helpers')('BWGimmicks')
F.run(function()
 assert(F.boot(100));hook(0);hook(4,0,300)
 for mode=0,1 do
  hook(8,mode);hook(1,0,600);assert(action());tap('A')
  hook(108,0,1);local gimmick=F.r16(X.gSpecialVar_0x8005)
  F.check('mode '..mode..' has usable gimmick',gimmick~=0);F.shot('trigger_'..mode)
  tap('Start');hook(108,0,1)
  F.check('mode '..mode..' selected',F.r16(U.gSpecialVar_0x8006)==1);F.shot('selected_'..mode)
  tap('L');F.shot('details_'..mode);tap('L')
  tap('Start');hook(108,0,1)
  F.check('mode '..mode..' cancelled',F.r16(U.gSpecialVar_0x8006)==0);F.shot('cancelled_'..mode)
  tap('Start');tap('A',1,1)
  for i=1,220 do F.idle(3);if i%2==0 then F.shot('activation_'..mode..'_'..string.format('%03d',i)) end end
  F.check('mode '..mode..' returned to commands',action());hook(109,gimmick,1)
  F.check('mode '..mode..' consumed original mechanic',F.r16(X.gSpecialVar_0x8005)==1)
  assert(exitBattle());hook(0)
 end
 F.finish()
end)
