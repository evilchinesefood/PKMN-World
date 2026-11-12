package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local S,X,M=require('symbols'),require('feature_symbols'),require('mechanics_symbols')
local F=require('lib').new(S,'SpecialPokemonMechanics')
local cases={
  {'seven acquisitions, boosted base stats, fresh individuals and regional identities',127},
  {'seven variants reject both breeding positions and every evolution mode',127},
  {'storage failure, retry, additive ownership and fresh encounter recovery',1023},
  {'legacy cap unchanged and ordinary breeding, evolution and HM behavior',63},
  {'all themed moves reappear once after forgetting and disappear when known',127},
  {'seven boosted calculated stat sets; ordinary species and legacy cap stay unchanged',127},
}
F.run(function()
  assert(F.boot(100),'fresh save did not reach overworld')
  for index,case in ipairs(cases) do
    assert(F.ow(),'mechanics fixture requires idle overworld')
    F.w16(S.gSpecialVar_0x8004,index-1)
    F.w16(M.gSpecialVar_0x8006,M.GetRelearnerLevelUpMoves&65535)
    F.w16(M.gSpecialVar_0x8007,M.GetRelearnerLevelUpMoves>>16)
    F.w16(S.gSpecialVar_Result,65535)
    F.w32(S.gMain+4,X.hook)
    F.idle(90)
    local result=F.r16(S.gSpecialVar_Result)
    F.L(string.format('command %d returned %04X, expected %04X',index-1,result,case[2]))
    F.check(case[1],result==case[2])
  end
  F.finish()
end)
