package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local S=require('symbols');local X=require('feature_symbols');local F=require('lib').new(S,'UIOptions')
local function tap(k,n) for i=1,(n or 1) do F.press(k,4);F.idle(90) end end
local function hook(c) F.w16(S.gSpecialVar_0x8004,c);F.w16(X.gSpecialVar_0x8005,0);F.w32(S.gMain+4,X.hook);F.idle(240) end
F.run(function() assert(F.boot(100));hook(0);hook(1);F.shot('entry');for frame=1,32 do F.idle(2);F.shot('animation_'..frame) end;F.idle(16);F.shot('motion');tap('Down',3);tap('Right');F.shot('frame_preview');tap('Down',4);F.shot('middle');tap('Down',4);F.shot('bottom');tap('B');tap('Start');tap('Right',4);tap('A');F.shot('save_prompt');F.check('no crash',not F.reportCrash('options'));F.finish() end)
