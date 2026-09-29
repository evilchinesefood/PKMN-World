package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local F,S,U,X,tap,hook,close,tasks,windows=require('swsh_helpers')('SwShTransitions')
local baseline=os.getenv('PW_CAPTURE_BASELINE')=='1'
local function clip(tag,frames)
 for n=1,frames,4 do F.shot(tag..'_'..string.format('%03d',n));F.idle(4) end
end
F.run(function()
 assert(F.boot(100));hook(0)
 hook(3,0);tap('Right',3)
 F.press('Right',4);clip('conditions_enter',96)
 F.check('Conditions window active',F.r16(0x4000000)&0x6000~=0)
 F.press('Right',4);clip('conditions_leave',96)
 F.check('Conditions window cleared',F.r16(0x4000000)&0x6000==0)
 F.check('Conditions DMA stopped',F.r8(U.gScanlineEffect+21)==0)
 close('summary')
 hook(4);tap('A');tap('Up');tap('A');F.shot('box_menu');tap('Down');tap('A');F.shot('wallpaper_menu')
 tap('Down');F.press('A',4)
 local sawWallpaperFade=false;local badText=0
 for n=1,120 do
  if F.r32(U.gPaletteFade)==(baseline and 2 or 4) then sawWallpaperFade=true end
  for i=1,(baseline and 15 or 31) do if F.r16(0x5000000+i*2)~=F.r16(U.sSwShStorage_Pal+i*2) then badText=badText+1 end end
  if n%4==0 then F.shot('wallpaper_fade_'..string.format('%03d',n)) end
  F.idle(1)
 end
 F.check('wallpaper fade targets expected bank',sawWallpaperFade)
 F.check('wallpaper fade leaves text colors intact',badText==0,'changed samples='..badText)
 F.shot('wallpaper_changed');close('wallpaper')
 F.finish()
end)
