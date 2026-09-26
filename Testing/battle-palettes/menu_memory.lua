-- Regression: menu returns must leave enough contiguous heap for a real terrain
-- animation. The merged baseline crashes allocating 13,024 bytes after one return.
package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local F,S,U,X,tap,hook,controller,action,exitBattle=require('bw_helpers')('BattleMenuMemory')
local function largestFreeBlock()
 local block=U.gHeap;local largest,count=0,0
 repeat
  if F.r16(block)&1==0 then largest=math.max(largest,F.r32(block+4)&0x3ffff) end
  block=F.r32(block+12);count=count+1;assert(count<300)
 until block==U.gHeap
 return largest
end
F.run(function()
 assert(F.boot(100));hook(202,0);hook(200,8,480);hook(201,22);hook(1,0,600);assert(action())
 local initial=largestFreeBlock()
 for i=1,3 do
  tap('Right');tap('A',1,240);tap('B',1,240);tap('Left')
  F.check('Bag return '..i..' reaches commands',controller('HandleInputChooseAction'))
  F.check('Bag return '..i..' retains contiguous animation memory',largestFreeBlock()>=initial)
  tap('Down');tap('A',1,180);tap('B',1,240);tap('Up')
  F.check('Party return '..i..' reaches commands',controller('HandleInputChooseAction'))
  F.check('Party return '..i..' retains contiguous animation memory',largestFreeBlock()>=initial)
 end
 tap('A');tap('A',1,900)
 F.check('Grassy Terrain animation does not exhaust memory',not F.reportCrash('terrain'))
 F.check('real terrain turn returns to commands',action())
 if controller('HandleInputChooseAction') then F.check('normal battle exit',exitBattle()) end
 F.finish()
end)
