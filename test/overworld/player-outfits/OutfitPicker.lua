local here=debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])') or ''
package.path=here..'?.lua;'..package.path
local gender=tonumber(os.getenv('PW_OUTFIT_GENDER') or '0')
local H=require('outfit_lib').new('OutfitPicker'..gender)
local F,S,O=H.F,H.S,H.O
local function outfit() return F.r16(F.sb1()+S.SaveBlock1.vars+(0x40FC-0x4000)*2) end
local function active() return F.r8(O.gPlayerOutfitPicker+2)~=0 end
local function preview() return F.r16(O.gPlayerOutfitPicker) end
local function tap(key) F.press(key,2);F.idle(16) end
local function palettes(tag,selection)
  local suffix=gender==0 and 'Male' or 'Female'
  local trainer=F.r8(O.gPlayerOutfitPicker+5)
  local overworld=F.r8(O.gPlayerOutfitPicker+6)
  F.check(tag..': both previews own sprites',trainer<64 and overworld<64 and trainer~=overworld)
  H.checkPalette(tag..'_trainer',H.slot(trainer),H.E['FrontPic_'..suffix][selection+1],true)
  H.checkPalette(tag..'_small',H.slot(overworld),H.E['OW_'..suffix][selection+1],true)
end
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
      if gender==1 and F.mcur()==0 then tap('Down') end
      tap('A')
    elseif F.cb2()==S.CB2_NamingScreen then
      F.idle(80);tap('Start');tap('A');F.idle(60)
    elseif active() then
      F.idle(10)
      F.check('selected gender',F.r8(F.sb2()+S.SaveBlock2.playerGender)==gender)
      F.check('intro starts original red',preview()==0)
      local committed=outfit()
      for style=0,3 do
        if style>0 then tap('Right') end
        for color=0,5 do
          if color>0 then tap('Down') end
          local selection=style*6+color
          F.check('preview catalog '..selection,preview()==selection and outfit()==committed)
          palettes('picker_'..selection,selection)
          F.shot('picker_'..selection)
        end
        if style<3 then tap('Down') end
      end
      tap('B')
      F.check('intro B preserves preview without commit',active() and preview()==23 and outfit()==committed)
      tap('Down')
      F.check('regional red restored',preview()==18 and outfit()==committed)
      palettes('picker_red_restored',18)
      for _=1,4 do tap('Down') end
      tap('A');F.idle(30);picked=true
    elseif F.ow() then break
    else F.press('A',2);F.idle(6) end
  end
  F.check('regional choice confirmed into game',picked and F.ow() and outfit()==22)
  if F.ow() then
    F.idle(120)
    H.checkGraphics('intro persists garment',22,gender)
    H.checkPalette('picker_persisted_ow',H.slot(H.player()),H.E['OW_'..(gender==0 and 'Male' or 'Female')][23],false)
    F.shot('picker_persisted_hub')
  end
  F.finish()
end)
