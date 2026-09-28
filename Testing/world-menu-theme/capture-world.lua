package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local mode=tonumber(os.getenv('PW_UI_MODE') or '37')
local F,S,U,X,tap,hook,close,tasks,windows=require('swsh_helpers')('WorldPanels'..mode)
F.run(function()
 assert(F.boot(100));hook(0);hook(mode,0,400);F.shot('entry');for frame=1,32 do F.idle(2);F.shot('animation_'..frame) end
 F.idle(16);F.shot('motion');
 F.check('BG3 visible',F.r16(0x4000000)&0x800~=0)
 if mode==37 then
  tap('Down');F.shot('selection');tap('Right');F.shot('contest');tap('Left');tap('A',1,180);F.shot('teach_confirmation');tap('B',1,180);F.shot('teach_cancel');tap('B',1,180);F.shot('exit_confirmation');tap('A',1,300);F.check('returns to field',F.ow())
 elseif mode==38 then
  tap('Down');F.shot('new_game_selected');tap('Down');tap('A',1,300);F.shot('options');tap('B',1,300);F.shot('main_return');F.check('background restored',F.r16(0x4000000)&0x800~=0)
 end
 F.check('no crash',not F.reportCrash('world panels'));F.finish()
end)
