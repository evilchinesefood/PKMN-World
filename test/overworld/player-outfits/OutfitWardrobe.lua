local here=debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])') or ''
package.path=here..'?.lua;'..package.path
local gender=tonumber(os.getenv('PW_OUTFIT_GENDER') or '0')
local H=require('outfit_lib').new('OutfitWardrobe'..gender)
local F,S,O=H.F,H.S,H.O
local function outfit() return F.r16(F.sb1()+S.SaveBlock1.vars+(0x40FC-0x4000)*2) end
local function active() return F.r8(O.gPlayerOutfitPicker+2)~=0 end
local function preview() return F.r16(O.gPlayerOutfitPicker) end
local function tap(key) F.press(key,2);F.idle(20) end
local function open()
  assert(F.ow(),'wardrobe requires field control')
  F.face('Up');F.idle(12)
  for _=1,30 do
    if active() then F.idle(20);return end
    tap('A')
  end
  error('physical wardrobe did not open')
end
local function closed()
  for _=1,120 do if F.ow() and not active() then F.idle(30);return true end F.idle(4) end
  return false
end
local function field(tag,selection)
  F.check(tag..': saved selection',outfit()==selection)
  H.checkGraphics(tag,selection,gender)
  H.checkPalette(tag,H.slot(H.player()),H.E['OW_'..(gender==0 and 'Male' or 'Female')][selection+1],false)
  F.shot(tag)
end
F.run(function()
  assert(F.boot(100));H.invoke(0)
  H.invoke(7)
  F.check('legacy dynamic graphics IDs retain meaning',F.r16(H.X.gSpecialVar_0x8005)==7)
  H.invoke(1,gender*24+22,300)
  H.invoke(5,0,300);F.face('Up');F.idle(30)
  F.shot('wardrobe_before')
  open()
  F.check('opens on equipped regional black',preview()==22)
  F.shot('wardrobe_picker')
  tap('Left');tap('Down');tap('Left')
  F.check('several previews never commit',outfit()==22 and preview()==11)
  tap('B');F.check('cancel returns control',closed());field('cancel_preserved',22)
  open();F.check('reopen ignores canceled preview',preview()==22)
  tap('Down');tap('A');F.check('apply returns control',closed());field('apply_pink',23)
  open();tap('Down');F.check('red preview selected',preview()==18)
  tap('A');F.check('red apply returns control',closed());field('apply_regional_red',18)
  open();tap('Down');tap('B');F.check('cancel tint returns control',closed());field('cancel_to_red',18)
  open();tap('Right');F.check('original red preview selected',preview()==0)
  tap('A');F.check('original apply returns control',closed());field('apply_original_red',0)
  open();tap('Right');tap('Down');tap('A');assert(closed());field('apply_kanto_blue',7)
  H.invoke(4,0,1200)
  F.check('ordinary save succeeded',F.r16(H.X.gSpecialVar_0x8005)==1)
  client.reboot_core();F.idle(5);assert(F.boot(100,true),'saved wardrobe choice did not Continue')
  F.idle(120);field('continue_kanto_blue',7)
  open();F.check('Continue wardrobe highlights equipped choice',preview()==7)
  tap('B');F.check('final cancel returns control',closed())
  F.finish()
end)
