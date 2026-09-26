-- Run against the unpatched delivery ROM and prepared synthetic save.
package.path=assert(os.getenv('PW_PROBE_LIB'))..'/?.lua;'..package.path
local S=require('symbols');local F=require('lib').new(S,'SwShDelivery')
local function tap(k,n)for i=1,(n or 1)do F.press(k,4);F.idle(90)end end
F.run(function()
 F.check('prepared save boots in hub',F.boot(100));assert(F.ow())
 F.check('six prepared party members',F.r8(S.gPartiesCount)==6)
 F.check('money preserved',F.money()==999999)
 local x,y=F.pos();F.step('Down');F.idle(30);local nx,ny=F.pos()
 F.check('normal field movement',x~=nx or y~=ny);F.shot('prepared_hub')
 tap('Start');local opened=false
 for i=1,16 do
  local p=F.r32(S.sUsmState)
  assert(p>=0x2000000 and p<0x2040000,'start wheel unavailable')
  local selected=F.r8(p+11+F.r8(p+5)+F.r8(p+10))
  if selected==2 then tap('A');opened=true;break end
  tap('Right')
 end
 F.check('normal start wheel opens Bag',opened and F.cb2()==S.CB2_BagMenuRun)
 F.shot('prepared_bag');tap('Right',2);F.shot('prepared_tm_pocket')
 for i=1,8 do tap('B');if F.ow() then break end end
 F.check('normal Bag returns to field',F.ow());tap('B',3);F.check('field controls released',F.ensureFree())
 F.finish()
end)
