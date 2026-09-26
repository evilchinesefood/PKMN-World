-- Capture normal move-info and SwSh Bag transitions without a game-side hook.
package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local F,S,U,X,tap,hook,controller,action,exitBattle=require('bw_helpers')('BWMotion')
local frame=0
local function record(key,frames)
 if key then F.press(key,4) end
 for i=1,frames do
  F.idle(3);frame=frame+1;F.shot(string.format('menus_%03d',frame))
 end
end
F.run(function()
 assert(F.boot(100));hook(0);hook(4,0,300);hook(1,0,600);assert(action())
 tap('A');tap('Right');local selected=F.r8(U.gMoveSelectionCursor)
 F.shot('menu_poster');record(nil,15);record('L',30);record('L',25)
 F.check('details restore selected move',controller('HandleInputChooseMove') and F.r8(U.gMoveSelectionCursor)==selected)
 record('B',20);F.check('move cancel restores commands',controller('HandleInputChooseAction'))
 tap('Right');record('A',80)
 F.check('SwSh Bag owns the screen',F.cb2()==S.CB2_BagMenuRun)
 record('B',80);F.check('Bag restores commands',controller('HandleInputChooseAction'))
 F.check('normal exit restores field',exitBattle());F.finish()
end)
