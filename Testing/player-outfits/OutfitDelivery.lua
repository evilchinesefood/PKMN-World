-- Unmodified development ROM plus the synthetic BLACK/May shore save.
local here=debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])') or ''
package.path=here..'?.lua;'..package.path
local H=require('outfit_lib').new('OutfitDelivery')
local F,S=H.F,H.S
local function tap(key) F.press(key,2);F.idle(90) end
F.run(function()
  assert(F.boot(0,true),'prepared save did not boot')
  F.idle(120)
  F.check('Continue starts at Petalburg pond',F.grp()==0 and F.mapn()==0)
  F.check('Continue retains female BLACK',F.r8(F.sb2()+S.SaveBlock2.playerGender)==1
    and F.r16(F.sb1()+S.SaveBlock1.vars+(0x40FC-0x4000)*2)==4)
  H.checkPalette('delivery_ow',H.slot(H.player()),H.E.OW_Female[5],false)
  H.reflection('delivery',H.E.OW_Female[5]);F.shot('prepared_pond')
  tap('Start')
  local selected=false
  for _=1,20 do
    local p=F.r32(S.sUsmState)
    assert(p>=0x02000000 and p<0x02040000,'wheel state missing')
    if F.r8(p+11+F.r8(p+5)+F.r8(p+10))==5 then selected=true;break end
    tap('Right')
  end
  assert(selected,'trainer card icon missing');tap('A');F.idle(90)
  H.checkPalette('delivery_card',128,H.E.FrontPic_Female[5],true);F.shot('prepared_card')
  tap('B');tap('B');F.idle(90)
  F.check('card returns normal walking',F.ow() and F.step('Up') and F.step('Down'))
  H.checkPalette('delivery_return',H.slot(H.player()),H.E.OW_Female[5],false)
  F.shot('prepared_return');F.finish()
end)
