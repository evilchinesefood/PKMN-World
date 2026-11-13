-- Synthetic team/items; production screens rendered by the current ROM.
package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local F,S,U,X,tap,hook,close,tasks,windows=require('swsh_helpers')('ShowcaseMenus')
F.run(function()
 assert(F.boot(100));hook(0)
 hook(33);F.shot('party');windows('party');close('party')
 hook(1);F.shot('bag');windows('bag');close('bag')
 hook(3);F.shot('summary');windows('summary');close('summary')
 assert(F.warpTo(0,0,0,0,1,6,0,0,0,0,16,'Route101'));F.idle(180)
 hook(35);F.shot('dexnav');close('dexnav')
 F.finish()
end)
