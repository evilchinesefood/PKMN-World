package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local F,S,U,X,tap,hook,controller,action,exitBattle=require('bw_helpers')('BattlePaletteRestoration')
local P=require('palette_symbols')
local function palette()
 local t={};for i=32,79 do t[#t+1]=F.r16(P.gPlttBufferUnfaded+i*2) end
 return table.concat(t,',')
end
local function record(tag,count)
 for i=1,count do F.idle(3);F.shot(tag..'_'..string.format('%03d',i)) end
end
local function restore(label,mode)
 hook(251,mode)
 F.check(label..' exact battlefield palette',F.r16(X.gSpecialVar_0x8005)==1)
 F.check(label..' preserves all other BG and OBJ colors',F.r16(U.gSpecialVar_0x8006)==1)
 F.check(label..' preserves gameplay environment',F.r16(U.gSpecialVar_0x8007)==1)
end
local function move(index,tag)
 assert(controller('HandleInputChooseAction'));tap('A')
 local c=F.r8(U.gMoveSelectionCursor)
 if (c&1)~=(index&1) then tap('Right') end
 if (c&2)~=(index&2) then tap('Down') end
 F.press('A',4);record(tag,160);F.check(tag..' finishes turn',action())
end
F.run(function()
 assert(F.boot(100));hook(202,0);hook(200,8,480);hook(201,22);hook(1,0,600);assert(action())
 local night=palette();F.shot('night_start')
 restore('initial staged restore',0);restore('initial full restore',1)
 hook(250,12) -- Deliberately advance the field clock after the snapshot.
 restore('clock changed staged restore',0);restore('clock changed full restore',1)
 F.check('entry colors frozen across clock change',palette()==night)
 tap('Right');F.press('A',4);record('bag_open',65)
 F.check('Bag opens',F.cb2()==S.CB2_BagMenuRun)
 F.press('B',4);record('bag_return',65);F.check('Bag returns',controller('HandleInputChooseAction'))
 F.check('Bag restores entry snapshot',palette()==night)
 tap('Left');tap('Down');tap('A',1,180);F.shot('party')
 F.check('Party opens',not controller('HandleInputChooseAction'))
 tap('B',1,240);F.check('Party returns',controller('HandleInputChooseAction'))
 F.check('Party restores entry snapshot',palette()==night)
 tap('Up')
 move(0,'grassy_terrain');local terrain=palette()
 F.check('real move activates terrain',F.r32(P.gFieldStatuses)~=0)
 F.check('terrain changes background',terrain~=night)
 restore('active terrain staged restore',0)
 F.check('staged restore retains terrain',palette()==terrain)
 for turn=1,4 do move(1,'splash_'..turn) end
 F.check('terrain expires through normal turns',F.r32(P.gFieldStatuses)==0)
 F.check('expiry restores exact night snapshot',palette()==night)
 F.shot('terrain_expired');restore('expired terrain staged restore',0)
 move(3,'shadow_ball');F.check('Shadow Ball background animation restores night snapshot',palette()==night)
 assert(exitBattle())
 -- Snow selects rock artwork without changing its original plain environment.
 hook(202,0);hook(200,5,480);hook(201,12);hook(1,0,600);assert(action())
 F.check('snow gameplay remains plain',F.r8(P.gBattleEnvironment)==9)
 restore('snow staged restore',0);restore('snow full restore',1)
 F.check('snow normal exit',exitBattle())
 for _,hour in ipairs({6,19}) do
  hook(202,0);hook(200,8,480);hook(201,hour);hook(1,0,600);assert(action())
  local entry=palette()
  tap('Right');tap('A',1,240);tap('B',1,240)
  F.check('hour '..hour..' Bag returns to commands',controller('HandleInputChooseAction'))
  F.check('hour '..hour..' Bag preserves entry colors',palette()==entry)
  tap('Left');tap('Down');tap('A',1,180);tap('B',1,240)
  F.check('hour '..hour..' Party returns to commands',controller('HandleInputChooseAction'))
  F.check('hour '..hour..' Party preserves entry colors',palette()==entry)
  F.check('hour '..hour..' normal exit',exitBattle())
 end
 F.finish()
end)
