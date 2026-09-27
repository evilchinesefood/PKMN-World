local here=debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])') or ''
package.path=here..'?.lua;'..package.path
local H=require('outfit_lib').new('OutfitSurfaces')
local F,S,O=H.F,H.S,H.O
F.run(function()
  assert(F.boot(100));H.invoke(0)
  local backTag=F.r16(H.X.gSpecialVar_0x8005)
  for n=0,11 do
    local gender=n<6 and 'Male' or 'Female'
    local outfit=n%6+1
    local tag=string.format('outfit_%02d',n)
    H.invoke(1,n,300);H.clock(12)
    F.check(tag..': walk along shore',F.step('Up') and F.step('Down'));F.face('Down');F.idle(30)
    H.checkPalette(tag..'_ow',H.slot(H.player()),H.E['OW_'..gender][outfit],false)
    H.reflection(tag,H.E['OW_'..gender][outfit]);F.shot(tag..'_pond')
    if outfit>=4 then
      H.clock(22);F.check(tag..': night active',F.r8(S.gTimeOfDay)==S.TimeOfDay.NIGHT)
      H.checkPalette(tag..'_night',H.slot(H.player()),H.E['OW_'..gender][outfit],false)
      H.reflection(tag..'_night',H.E['OW_'..gender][outfit]);F.shot(tag..'_night');H.clock(12)
    end
    H.invoke(2,0,180)
    H.checkPalette(tag..'_card',128,H.E['FrontPic_'..gender][outfit],true);F.shot(tag..'_card')
    F.press('B',2);F.idle(180);assert(F.ow(),'card failed to close')
    H.checkPalette(tag..'_card_return',H.slot(H.player()),H.E['OW_'..gender][outfit],false)
    H.invoke(3,0,1)
    local found=false
    for frame=1,600 do
      local pal
      for i=0,15 do if F.r16(S.sSpritePaletteTags+i*2)==backTag+(n<6 and 1 or 2) then pal=i end end
      if pal and not found then
        F.idle(2)
        local count=0
        for id=0,63 do
          if (F.r8(H.sprite(id)+S.Sprite.inUse)&1)~=0 and H.slot(id)==256+pal*16 then count=count+1 end
        end
        F.check(tag..': one live sprite owns trainer palette',count==1)
        H.checkPalette(tag..'_sendout',256+pal*16,H.E['BackPic_'..gender][outfit],true)
        found=true
      end
      if found and frame%3==0 then F.shot(tag..'_throw_'..string.format('%03d',frame)) end
      if found and not pal then break end
      F.press('A',1);F.idle(3)
    end
    F.check(tag..': sendout observed',found)
    F.check(tag..': battle returns control',H.exitBattle())
    H.checkPalette(tag..'_battle_return',H.slot(H.player()),H.E['OW_'..gender][outfit],false)
  end
  H.invoke(1,10,300);H.clock(12);F.face('Down');F.idle(30)
  H.invoke(4,0,1200);F.check('synthetic review save written',F.r16(H.X.gSpecialVar_0x8005)==1)
  local group,map=F.grp(),F.mapn()
  client.reboot_core();F.idle(5);assert(F.boot(group,true),'prepared save failed to reload')
  F.idle(120);F.check('Continue restores pond map',F.grp()==group and F.mapn()==map)
  F.check('Continue restores female BLACK',F.r8(F.sb2()+S.SaveBlock2.playerGender)==1
    and F.r16(F.sb1()+S.SaveBlock1.vars+(0x40FC-0x4000)*2)==4)
  H.checkPalette('continue',H.slot(H.player()),H.E.OW_Female[5],false)
  H.reflection('continue',H.E.OW_Female[5]);F.shot('continue')
  F.check('Continue restores walking',F.step('Up') and F.step('Down'))
  F.finish()
end)
