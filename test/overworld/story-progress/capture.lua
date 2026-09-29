-- Disposable fixture enters the production renderer. Never touches an owner save.
package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local S=require('symbols');local X=require('story_symbols')
local F=require('lib').new(S,'StoryProgress')
local texts=require('story_texts')
local function tap(k) F.press(k,2);F.idle(90) end
local function hook(c,a)
  F.w16(S.gSpecialVar_0x8004,c);F.w16(X.gSpecialVar_0x8005,a or 0)
  F.w32(S.gMain+4,X.hook);F.idle(200)
end
local function open()return (F.cb2()&~1)==(X.CB2_Story&~1) end
F.run(function()
  F.check('fresh fixture boots',F.boot(100));if not F.ow() then F.finish();return end
  hook(0)
  local tooWide=0;local fields=0
  for _,o in ipairs(texts) do
    for _,ptr in ipairs(o.texts) do
      F.w16(X.gSpecialVar_0x8008,ptr&0xffff);F.w16(X.gSpecialVar_0x8009,ptr>>16)
      F.w16(S.gSpecialVar_0x8004,3);F.w32(S.gMain+4,X.hook);F.idle(2)
      local width=F.r16(S.gSpecialVar_Result)
      fields=fields+1
      if width>216 then tooWide=tooWide+1;F.L(o.id..' text too wide: '..width) end
    end
  end
  F.check('every compiled objective fits production font',fields==#texts*5 and fields>500 and tooWide==0,'fields='..fields)
  hook(1)
  F.check('production Story opens',open());F.check('active campaign selected',F.r8(X.sStoryRegion)==0);F.shot('overview')
  F.check('text and background layers visible',F.r16(0x04000000)&0x0900==0x0900)
  tap('A');F.shot('kanto_next');tap('Right');F.shot('kanto_where');tap('Right');F.shot('kanto_recap')
  tap('B');tap('Down');tap('A');F.check('Johto selected',F.r8(X.sStoryRegion)==1);F.shot('johto_next')
  tap('B');tap('Down');tap('A');F.check('Hoenn selected',F.r8(X.sStoryRegion)==2);F.shot('hoenn_next')
  tap('B');tap('B');F.check('screen closes to overworld',F.ow() and not open())
  hook(2);F.check('state unchanged after browsing',F.r16(S.gSpecialVar_Result)==1)
  for i=1,8 do hook(1);tap('B') end
  F.check('repeated visits return cleanly',F.ow() and not open())
  hook(2);F.check('repeat browsing preserves state',F.r16(S.gSpecialVar_Result)==1)
  hook(4)
  F.check('classic menu remains within screen',F.r8(S.gWindows+F.r8(X.sStartMenuWindowId)*12+4)<=18)
  local count=F.r8(X.sNumStartMenuActions)
  while F.r8(X.sStartMenuCursorPos)~=0 do tap('Down') end
  for i=1,count-1 do tap('Down') end
  F.check('classic menu reaches its last action with scrolling',count>8 and F.r8(X.sStartMenuCursorPos)==count-1 and F.r8(X.sStartMenuScrollOffset)==count-8)
  tap('Down');F.check('classic menu wraps from last to first',F.r8(X.sStartMenuCursorPos)==0 and F.r8(X.sStartMenuScrollOffset)==0)
  tap('Up');F.check('classic menu wraps from first to last',F.r8(X.sStartMenuCursorPos)==count-1 and F.r8(X.sStartMenuScrollOffset)==count-8)
  tap('Down')
  local story=false
  for i=1,count do
    local cursor=F.r8(X.sStartMenuCursorPos)
    local action=F.r8(X.sCurrentStartMenuActions+cursor)
    if action==16 then story=true;tap('A');break end
    tap('Down')
  end
  F.check('Story reachable from classic menu',story and open());F.shot('classic_story')
  tap('B');tap('B')
  F.check('classic caller restores menu/overworld',F.ow())
  hook(5);hook(1);F.shot('champion_overview');tap('A');F.shot('champion_next')
  F.check('Champion status retained with started optional chain',F.r8(X.sStoryProgress+8)==2 and F.r32(X.sStoryProgress+4)~=0)
  tap('Right');tap('Right');tap('Right');F.shot('optional_next')
  F.check('optional action page reachable',F.r8(X.sStoryPage)==3)
  tap('Right');F.shot('optional_why');F.check('optional prerequisite page reachable',F.r8(X.sStoryPage)==4)
  tap('Right');F.check('five-page detail wraps cleanly',F.r8(X.sStoryPage)==0)
  tap('B');tap('B');F.check('Champion/optional view returns cleanly',F.ow())
  F.finish()
end)
