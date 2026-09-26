package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local F,S,U,X,tap,hook,controller,action,exitBattle=require('bw_helpers')('BWPreview')
local cases={'rain Weather Ball','sun Weather Ball','grassy Terrain Pulse','electric Terrain Pulse','Hidden Power','Pixilate','Normalize','Levitate','Mold Breaker','Ability Shield','Water Absorb','Flash Fire','Air Balloon'}
F.run(function()
 assert(F.boot(100));hook(0);hook(4,0,300);hook(1,0,600);assert(action());tap('A')
 for i,name in ipairs(cases) do
  hook(105,i-1,1)
  F.check(name..' effectiveness',F.r16(X.gSpecialVar_0x8005)==1)
  F.check(name..' type',F.r16(U.gSpecialVar_0x8006)==1)
  F.check(name..' leaves battle state unchanged',F.r16(U.gSpecialVar_0x8007)==1)
 end
 hook(106,0,1)
 F.check('all full move names fit fallback row',F.r16(X.gSpecialVar_0x8005)==0,'count='..F.r16(X.gSpecialVar_0x8005)..' last move='..F.r16(U.gSpecialVar_0x8006))
 tap('B');assert(action());assert(exitBattle());F.finish()
end)
