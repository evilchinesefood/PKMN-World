package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local F,S,U,X,tap,hook,controller,action,exitBattle=require('bw_helpers')('BWHealthbox')
F.run(function()
 assert(F.boot(100));hook(0);hook(4,0,300);hook(1,0,600);assert(action())
 for b=0,1 do
  hook(114,b,60)
  F.check('Illusion break clears long nickname, side '..b,F.r16(X.gSpecialVar_0x8005)==1)
  F.check('Illusion shows disguise gender and actual level, side '..b,F.r16(U.gSpecialVar_0x8006)==1)
 end
 hook(115,0,1);F.idle(60);F.shot('scope_reveal')
 F.check('scope reveal preserves commands',controller('HandleInputChooseAction'))
 tap('A');F.check('scope reveal preserves move screen',controller('HandleInputChooseMove'));F.shot('scope_reveal_moves')
 tap('B');assert(exitBattle());F.finish()
end)
