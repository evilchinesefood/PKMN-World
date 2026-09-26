package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local S=require('symbols');local X=require('feature_symbols')
local F=require('lib').new(S,'VisualPaletteControls')
local function hook(c,a)
  F.w16(S.gSpecialVar_0x8004,c);F.w16(X.gSpecialVar_0x8005,a or 0)
  F.w32(S.gMain+4,X.hook);F.idle(240)
end
local function checkPalette(label)
  local clean=true
  for i=64,95 do if F.r16(S.gPlttBufferUnfaded+2*i)~=0 then clean=false end end
  F.check(label..' clears unused banks',clean)
end
F.run(function()
  assert(F.boot(100));hook(0)
  hook(4,1);F.shot('regional_list');checkPalette('regional list')
  F.press('A',8);F.idle(120);F.shot('regional_info');checkPalette('regional info')
  for i=1,5 do F.press('B',8);F.idle(120);if F.ow() then break end end
  F.check('regional dex returns',F.ow())
  hook(4,0);F.shot('national_restored');checkPalette('national restored')
  F.finish()
end)
