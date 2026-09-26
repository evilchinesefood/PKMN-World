package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local F,S,U,X,tap,hook,controller,action,exitBattle=require('bw_helpers')('BWPressure')
local function palette(tag)
 for i=0,15 do if F.r16(U.sSpritePaletteTags+i*2)==tag then return i end end
end
F.run(function()
 assert(F.boot(100));hook(0);hook(4,0,300);hook(1,1,600);assert(action())
 hook(121,0,1);local preserved=true
 for i=1,120 do
  F.idle(2);preserved=preserved and (F.r16(U.sGpuRegBuffer+0x4c)&255)==0x43
  if i%4==0 then F.shot('popups_'..string.format('%03d',i)) end
 end
 F.check('two popups preserve background mosaic',preserved)
 F.check('two popups restore prior object mosaic',F.r16(U.sGpuRegBuffer+0x4c)==0x1243)
 F.check('both popups release shared palette',palette(0xd720)==nil)
 hook(121,0,30);hook(121,1,1)
 F.check('early popup cleanup restores mosaic',F.r16(U.sGpuRegBuffer+0x4c)==0x1243)
 F.check('early popup cleanup frees palette',palette(0xd720)==nil)
 hook(122,0,30)
 F.check('task exhaustion returns without assertion',not F.reportCrash('tasks'))
 F.check('task exhaustion leaves no popup palette',palette(0xd720)==nil)
 hook(123,0,60)
 F.check('palette exhaustion rejects cursor safely',F.r16(X.gSpecialVar_0x8005)==1)
 F.check('palette exhaustion rejects info trigger safely',F.r16(U.gSpecialVar_0x8006)==1)
 F.check('palette exhaustion rejects ball trigger safely',F.r16(U.gSpecialVar_0x8007)==1)
 F.check('palette exhaustion returns without assertion',not F.reportCrash('palettes'))
 F.check('battle exits after resource pressure',exitBattle());F.finish()
end)
