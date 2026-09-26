-- Unpatched production ROM plus the generated synthetic Route101 save.
package.path=assert(os.getenv('PW_PROBE_LIB'))..'/?.lua;'..package.path
local S=require('symbols');local F=require('lib').new(S,'BWDelivery')
local function tap(k) F.press(k,4);F.idle(90) end
F.run(function()
 F.check('prepared save boots in Route101',F.boot(0));assert(F.ow())
 F.check('six prepared party members',F.r8(S.gPartiesCount)==6);F.shot('prepared_route')
 tap('Start');local opened=false
 for i=1,16 do
  local p=F.r32(S.sUsmState);assert(p>=0x2000000 and p<0x2040000)
  local selected=F.r8(p+11+F.r8(p+5)+F.r8(p+10))
  if selected==2 then tap('A');opened=true;break end
  tap('Right')
 end
 F.check('normal wheel opens Bag',opened and F.cb2()==S.CB2_BagMenuRun);F.shot('prepared_bag')
 for i=1,8 do tap('B');if F.ow() then break end end
 F.check('normal Bag returns to the field wheel',F.ow())
 -- Bag restores the start-menu wheel; its callback is also CB2_Overworld.
 tap('B')
 F.check('normal controls released',F.ensureFree());F.shot('prepared_controls')
 F.finish()
end)
