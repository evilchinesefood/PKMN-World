package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local mode=tonumber(os.getenv('PW_BATTLE_MODE') or '0')
local F,S,U,X,tap,hook,close,tasks,windows=require('swsh_helpers')('SwShBattle'..mode)
local function action()
 for i=1,400 do
  if (F.r32(U.gBattlerControllerFuncs)&~1)==U.HandleInputChooseAction then return true end
  tap('A',1,12)
 end
 return false
end
local function bag()
 local c=F.r8(S.gActionSelectionCursor)
 if c&2~=0 then tap('Up') end
 if c&1==0 then tap('Right') end
 tap('A',1,300)
 F.check('battle bag input owns task',tasks(U.Task_BagMenu_HandleInput)==1)
 assert(tasks(U.Task_BagMenu_HandleInput)==1)
end
F.run(function()
 assert(F.boot(100));hook(0)
 if mode==2 then hook(17,0,600) else hook(13,mode,600) end
 F.check('battle ready',action());F.check('battler count',F.battlers()==(mode==0 and 2 or 4))
 if mode==2 then F.check('partner battle',F.battleFlags()&0x400040==0x400040) end
 F.shot('battle');bag();F.shot('bag')
 if mode==2 then tap('R');F.check('partner page selected',F.r8(U.sMultiFullPage)==1);F.shot('partner_team');tap('L');F.check('player page restored',F.r8(U.sMultiFullPage)==0);F.shot('player_team') end
 tap('B',1,300);F.check('cancel restores battle action',action());F.shot('cancel_return')
 bag();tap('A',2);F.shot('item_target');tap('A',1,300)
 -- The battle action consumes one item and resumes the correct battler's turn.
 F.check('using item resumes battle',action());F.shot('item_return')
 F.check('lead is alive after healing',F.r16(S.gParties+S.Pokemon.hp)>1)
 -- End only this disposable fight after checking its real menu return.
 F.w8(S.gBattleOutcome,1)
 for i=1,180 do if F.ow() then break end;tap('A',1,20) end
 F.check('battle exit reaches field',F.ow());assert(not F.reportCrash('battle exit'))
 F.finish()
end)
