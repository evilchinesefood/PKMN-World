package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local F,S,U,X,tap,hook,controller,action,exitBattle=require('bw_helpers')('BWTurns')
local function task(fn)
 for i=0,15 do local p=S.gTasks+i*40;if F.r8(p+4)~=0 and (F.r32(p)&~1)==fn then return true end end
 return false
end
F.run(function()
 assert(F.boot(100));hook(0);hook(4,0,300);hook(22);hook(1,0,600);assert(action())
 tap('A');tap('Right');tap('A',1,1)
 for i=1,180 do F.idle(3);F.shot('damage_'..string.format('%03d',i)) end
 F.check('damaging turn returns to commands',action())
 F.check('Sturdy leaves target at one HP',F.r16(X.gBattleMons+S.BattlePokemon.size+S.BattlePokemon.hp)==1)
 tap('A');tap('A',1,1)
 local levelBox=false
 for i=1,500 do
  F.idle(3)
  if F.r8(S.sLevelUpSummaryState)==3 then levelBox=true;F.shot('earned_level_summary') end
  if i%2==0 then F.shot('experience_'..string.format('%03d',i)) end
  if F.ow() then break end
  if i%16==0 then F.press('A',3) end
 end
 F.check('real victory returns to field',F.ow())
 F.check('EXP really earned a level',F.r8(S.gParties+S.Pokemon.level)==41)
 F.check('earned level uses World summary',levelBox)
 hook(0);hook(1,0,600);assert(action());hook(125);F.shot('poison_healthbox');tap('A');tap('A',1,300)
 for i=1,200 do if task(U.Task_HandleChooseMonInput) then break end;tap('A',1,12) end
 F.check('faint opens replacement party',task(U.Task_HandleChooseMonInput));F.shot('faint_party')
 F.idle(120);F.press('B',4);F.idle(45);tap('Down');F.L('replacement slot='..F.r8(U.gPartyMenu+9));F.shot('replacement_selected');tap('A',1,240);F.check('replacement returns to battle',action());F.shot('replacement');assert(exitBattle())
 hook(0);hook(22,1);hook(1,0,600);assert(action());hook(125);tap('A');tap('A',1,300)
 for i=1,400 do if F.ow() then break end;tap('A',1,16) end
 F.check('real loss returns through whiteout',F.ow());F.shot('whiteout_return');F.finish()
end)
