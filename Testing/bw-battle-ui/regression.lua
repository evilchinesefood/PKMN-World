package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local F,S,U,X,tap,hook,controller,action,exitBattle=require('bw_helpers')('BWRegression')
local function countTasks(fn)
 local n=0
 for i=0,15 do local p=S.gTasks+i*40
  if F.r8(p+4)~=0 and (not fn or (F.r32(p)&~1)==fn) then n=n+1 end
 end
 return n
end
local function heap()
 local p,n=U.gHeap,0
 for i=1,1024 do
  assert(p>=U.gHeap and p<U.gHeap+0x1c500,'heap link outside arena')
  assert(F.r16(p+2)==0xa3a3,'heap guard corrupted')
  if F.r16(p)&1~=0 then n=n+(F.r32(p+4)&0x3ffff) end
  p=F.r32(p+12);if p==U.gHeap then return n end
 end
 error('heap cycle')
end
local function palette(tag)
 for i=0,15 do if F.r16(U.sSpritePaletteTags+i*2)==tag then return i end end
 return nil
end
local function selectAction(n)
 local c=F.r8(S.gActionSelectionCursor)
 if c&1~=n&1 then tap(n&1==0 and 'Left' or 'Right') end
 if c&2~=n&2 then tap(n&2==0 and 'Up' or 'Down') end
 tap('A',1,240)
end
local function fieldClean(label)
 F.check(label..' cursor palette released',palette(0x9999)==nil)
 F.check(label..' shortcut palette released',palette(0xe723)==nil)
 F.check(label..' popup palette released',palette(0xd720)==nil)
end
F.run(function()
 assert(F.boot(100));hook(0);hook(1,0,600);assert(action())
 selectAction(0);hook(103,0,1)
 F.check('four expected effectiveness categories',F.r16(X.gSpecialVar_0x8005)==15)
 F.check('effectiveness does not consume RNG',F.r16(U.gSpecialVar_0x8006)==1)
 F.check('status moves omit effectiveness',F.r16(U.gSpecialVar_0x8007)==1)
 hook(102,1);F.shot('long_moves');hook(102,2);F.shot('status_empty_zero_pp');hook(102,0)
 local cursor=F.r8(U.gMoveSelectionCursor)
 tap('L');F.shot('details');tap('L')
 F.check('details preserve selected move',F.r8(U.gMoveSelectionCursor)==cursor and controller('HandleInputChooseMove'))
 hook(100,2,1)
 for i=1,50 do F.idle(3);F.shot(string.format('ability_%03d',i)) end
 F.check('ability popup released its palette',palette(0xd720)==nil)
 F.check('popup kept live info palette',palette(0xe723)~=nil)
 F.shot('info_after_popup');tap('B');assert(action())
 hook(104,0,1)
 F.check('cursor allocation failure is bounded',F.r16(X.gSpecialVar_0x8005)==1)
 F.check('move trigger allocation failure is bounded',F.r16(U.gSpecialVar_0x8006)==1)
 F.check('ball trigger allocation failure is bounded',F.r16(U.gSpecialVar_0x8007)==1)
 F.check('no assertion under sprite exhaustion',not F.reportCrash('pressure'))
 F.check('pressure cursor recovers',palette(0x9999)~=nil)
 F.check('pressure case exits normally',exitBattle());F.idle(240);fieldClean('pressure')
 local baseHeap,baseResources
 for i=1,30 do
  hook(1,i%2,600);F.check('cycle '..i..' commands',action())
  selectAction(1)
  F.check('cycle '..i..' bag owns input',countTasks(U.Task_BagMenu_HandleInput)==1)
  if i==1 then F.shot('bag') end
  tap('B',1,240);F.check('cycle '..i..' bag return',action())
  selectAction(0);F.check('cycle '..i..' moves',controller('HandleInputChooseMove'))
  tap('L');tap('L');tap('B');F.check('cycle '..i..' info return',action())
  F.check('cycle '..i..' field return',exitBattle());F.idle(240)
  fieldClean('cycle '..i)
  hook(21,0,30)
  local tiles=0
  for off=0,127 do local v=F.r8(U.sSpriteTileAllocBitmap+off);for b=0,7 do tiles=tiles+((v>>b)&1) end end
  local resources=F.r16(X.gSpecialVar_0x8005)..':'..F.r16(U.gSpecialVar_0x8006)..':'..F.r16(U.gSpecialVar_0x8007)..':'..tiles
  if i<=2 then baseResources=resources else F.check('cycle '..i..' stable sprites/tasks/printers/tiles',resources==baseResources,resources) end
  local h=heap();F.L('cycle '..i..' field heap='..h)
  if i<=2 then baseHeap=h else F.check('cycle '..i..' stable heap',h==baseHeap) end
 end
 hook(3,0,600);F.check('full partner commands',action());F.shot('partner_commands')
 selectAction(0);F.shot('partner_moves');tap('B');assert(action())
 selectAction(1);F.shot('partner_bag');tap('R');F.shot('partner_bag_right');tap('L');tap('B',1,240)
 F.check('partner bag return',action());F.check('partner returns to field',exitBattle())
 F.finish()
end)
