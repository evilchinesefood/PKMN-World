local S=require('symbols');local X=require('feature_symbols');local U=require('swsh_symbols')
return function(name)
 local F=require('lib').new(S,name)
 local function tap(k,n,delay) for i=1,(n or 1) do F.press(k,4);F.idle(delay or 90) end end
 local function tasks(fn)
  local n=0
  for i=0,15 do local p=S.gTasks+i*40
   if F.r8(p+4)~=0 and (F.r32(p)&~1)==(fn&~1) then n=n+1 end
  end
  return n
 end
 local function hook(c,a,wait)
  assert(F.ow() and tasks(U.Task_PCMainMenu)==0,'fixture would replace a live screen')
  F.w16(S.gSpecialVar_0x8004,c);F.w16(X.gSpecialVar_0x8005,a or 0);F.w32(S.gMain+4,X.hook);F.idle(wait or 240)
 end
 local function close(tag)
  for i=1,15 do
   tap('B')
   if F.ow() and tasks(U.Task_PCMainMenu)==0 then tap('B',3);break end
  end
  F.check(tag..' returns to field',F.ow() and tasks(U.Task_PCMainMenu)==0)
  assert(F.ow(),tag..' did not return');assert(not F.reportCrash(tag))
 end
 local function windows(tag)
  local checked,bad=0,0
  for w=0,31 do
   local p=U.gWindows+w*12;local bg=F.r8(p);local buf=F.r32(p+8)
   if bg<4 and buf>=0x2000000 and buf<0x2040000 then
    local x,y,width,height=F.r8(p+1),F.r8(p+2),F.r8(p+3),F.r8(p+4)
    local base=F.r16(p+6);local cnt=F.r16(0x4000008+bg*2)
    local map=0x6000000+((cnt>>8)&31)*0x800
    -- Only mapped windows are visible; several alternative layouts share VRAM intentionally.
    local screenHeight=(cnt>>14)&2~=0 and 512 or 256
    local top=(y*8-F.r16(U.sGpuRegBuffer+0x12+bg*4))%screenHeight
    if width>0 and height>0 and top<160 and (F.r16(map+(y*32+x)*2)&0x3ff)==base then
     local gfx=0x6000000+((cnt>>2)&3)*0x4000+base*32
     checked=checked+1
     local failures=0
     for i=0,width*height*32-1 do if F.r8(buf+i)~=F.r8(gfx+i) then failures=failures+1 end end
     if failures>0 then F.L('window mismatch '..w..' bg='..bg..' base='..base..' bytes='..failures) end
     bad=bad+failures
    end
   end
  end
  F.check(tag..' visible text tiles intact',checked>0 and bad==0,'windows='..checked..' mismatched bytes='..bad)
 end
 local function summaryClean(tag)
  for _,n in ipairs({'Task_PrintConditionsPage','Task_PrintInfoPage','Task_PrintSkillsPage','Task_PrintBattleMoves','Task_PrintContestMoves','Task_PrintMemoPage','Task_ShowEffectTilemap'}) do
   F.check(tag..' no '..n,tasks(U[n])==0)
  end
  F.check(tag..' summary state freed',F.r32(U.sMonSummaryScreen)==0)
  F.check(tag..' scanline DMA stopped',F.r8(U.gScanlineEffect+21)==0)
 end
 local function heap()
  local p,n=U.gHeap,0
  for i=1,1024 do
   assert(p>=U.gHeap and p<U.gHeap+0x1c500,'heap link outside arena')
   assert(F.r16(p+2)==0xa3a3,'heap guard corrupted')
   if F.r16(p)&1~=0 then n=n+(F.r32(p+4)&0x3ffff) end
   p=F.r32(p+12);if p==U.gHeap then return n end
  end
  error('heap chain does not terminate')
 end
 return F,S,U,X,tap,hook,close,tasks,windows,summaryClean,heap
end
