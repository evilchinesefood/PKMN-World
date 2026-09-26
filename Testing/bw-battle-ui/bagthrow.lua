package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local F,S,U,X,tap,hook,controller,action,exitBattle=require('bw_helpers')('BWBagThrow')
F.run(function()
 assert(F.boot(100));hook(0);hook(4,0,300);hook(12);hook(1,0,600);assert(action());hook(126)
 tap('Right');tap('A',1,240);F.shot('balls_in_bag');tap('A');F.shot('ball_action');tap('A',1,540)
 for i=1,300 do if F.ow() then break end;tap('B',1,24) end
 F.check('Bag throw resolves capture and returns to field',F.ow());assert(F.ow());hook(13)
 F.check('Bag consumed the only Master Ball',F.r16(U.gSpecialVar_0x8006)==0)
 F.check('Bag capture stored the full-party catch',F.r16(X.gSpecialVar_0x8005)==1)
 F.finish()
end)
