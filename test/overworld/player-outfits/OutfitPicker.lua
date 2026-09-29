local here=debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])') or ''
package.path=here..'?.lua;'..package.path
local gender=tonumber(os.getenv('PW_OUTFIT_GENDER') or '0')
local H=require('outfit_lib').new('OutfitPicker'..gender)
local F,S,O=H.F,H.S,H.O
local function outfit() return F.r16(F.sb1()+S.SaveBlock1.vars+(0x40FC-0x4000)*2) end
F.run(function()
  local reached=false
  for _=1,90000 do
    if F.cb2()==S.CB2_NewGameScene then reached=true;break end
    F.press('A',2);F.idle(8);F.press('Start',2);F.idle(8)
  end
  assert(reached,'new game scene missing')
  local picked=false
  for _=1,10000 do
    if H.task(S.Task_OakSpeech_HandleGenderInput) then
      F.idle(10)
      if gender==1 and F.mcur()==0 then F.press('Down',2);F.idle(10) end
      F.press('A',2);F.idle(20)
    elseif F.cb2()==S.CB2_NamingScreen then
      F.idle(80);F.press('Start',2);F.idle(30);F.press('A',2);F.idle(60)
    elseif H.task(S.Task_OakSpeech_HandleOutfitInput) then
      F.idle(10)
      F.check('selected gender',F.r8(F.sb2()+S.SaveBlock2.playerGender)==gender)
      local p=F.r32(O.sOakSpeechResources)
      -- src/oak_speech.c OakSpeechResources: four pointers, 16 bytes of
      -- scalar fields, and 0x2400 bytes of existing buffers precede this ID.
      assert(p>=0x02000000 and p<0x02040000 and F.r8(p+0x2421)==1)
      local id=F.r8(p+0x2420)
      for n=0,5 do
        if n>0 then F.press('Down',2);F.idle(12) end
        F.check('picker cursor '..n,F.mcur()==n and outfit()==n)
        H.checkPalette('picker_'..n,H.slot(id),H.E['FrontPic_'..(gender==0 and 'Male' or 'Female')][n+1],true)
        F.shot('picker_'..n)
      end
      F.press('B',2);F.idle(12)
      F.check('B stays on pink preview',H.task(S.Task_OakSpeech_HandleOutfitInput)~=nil and outfit()==5)
      for _=1,5 do F.press('Up',2);F.idle(12) end
      F.check('return to RED',F.mcur()==0 and outfit()==0)
      H.checkPalette('picker_red_restored',H.slot(id),H.E['FrontPic_'..(gender==0 and 'Male' or 'Female')][1],true)
      for _=1,4 do F.press('Down',2);F.idle(12) end
      F.press('A',2);F.idle(30);picked=true
    elseif F.ow() then break
    else F.press('A',2);F.idle(6) end
  end
  F.check('picker confirmed into game',picked and F.ow() and outfit()==4)
  if F.ow() then
    H.checkPalette('picker_persisted_ow',H.slot(H.player()),H.E['OW_'..(gender==0 and 'Male' or 'Female')][5],false)
    F.shot('picker_persisted_hub')
  end
  F.finish()
end)
