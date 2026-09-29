-- Production Start entry, all regions/hub, paging, purity and save/Continue.
local here=(debug.getinfo(1,'S').source:sub(2)):match('^(.*[/\\])') or ''
package.path=here..'?.lua;'..package.path
local S=require('symbols');local F=require('lib').new(S,'StoryProgress')
local function tap(k) F.press(k,2);F.idle(90) end
local function open() return (F.cb2()&~1)==(S.CB2_Story&~1) end
local function ascii(p)
  local t={}
  for i=0,95 do local c=F.r8(p+i);if c==0 then return table.concat(t) end;t[#t+1]=string.char(c) end
  error('objective ID lacks terminator')
end
local function id(i) return ascii(F.r32(F.r32(S.sStoryProgress+i*16))) end
local function heap()
  local p,total=S.gHeap,0
  for i=1,1024 do
    assert(p>=S.gHeap and p<S.gHeap+0x1c500,'heap link outside arena')
    assert(F.r16(p+2)==0xa3a3,'heap guard corrupted')
    if F.r16(p)&1~=0 then total=total+(F.r32(p+4)&0x3ffff) end
    p=F.r32(p+12);if p==S.gHeap then return total end
  end
  error('heap chain does not terminate')
end
local function enter()
  tap('Start')
  assert(F.selectStartIcon(6),'Story missing from graphical menu')
  tap('A');assert(open(),'Story renderer not entered')
end
local function close() tap('B');tap('B');assert(F.ow(),'Story did not return to field') end
local function setVar(v,n)
  local addr=v>=0xa000 and F.sb3()+S.SaveBlock3.regionVars+(v-0xa000)*2
    or F.sb1()+S.SaveBlock1.vars+(v-0x4000)*2
  F.w16(addr,n)
end
local function snapshot()
  local out={}
  for _,range in ipairs({{F.sb1()+S.SaveBlock1.flags+4,514},
    {F.sb3()+S.SaveBlock3.regionVars,768},{F.sb3()+S.SaveBlock3.johtoFlags,128},
    {S.gParties,600},{S.gPartiesCount,1},{F.sb2()+S.SaveBlock2.currentRegion,1},
    {S.gCurrentRegion,4},{F.sb1()+S.SaveBlock1.vars+(0x40f8-0x4000)*2,2}}) do
    for i=0,range[2]-1 do out[#out+1]=string.char(F.r8(range[1]+i)) end
  end
  return table.concat(out)
end
local function digits(n)return n//100%10,n//10%10,n%10 end
local function warp(g,m,r)
  F.w8(F.sb2()+S.SaveBlock2.currentRegion,r);F.w32(S.gCurrentRegion,r)
  local gh,gt,go=digits(g);local mh,mt,mo=digits(m)
  assert(F.warpTo(gh,gt,go,mh,mt,mo,0,0,0,g,m,'story_'..g),'warp failed')
  F.dismiss(20)
end
F.run(function()
  F.check('boots to hub',F.boot(100));if not F.ow() then F.finish();return end
  enter()
  F.check('fresh hub has deliberate Kanto default',F.r8(S.sStoryRegion)==0)
  F.check('fresh campaigns stay undiscovered',id(0)=='kanto.not_started' and id(1)=='johto.not_started' and id(2)=='hoenn.not_started')
  F.shot('fresh_overview');close()
  -- Supported mid-story RAM fixture; no real save is used.
  F.w8(F.sb2()+S.SaveBlock2.introDoneBits,F.r8(F.sb2()+S.SaveBlock2.introDoneBits)|7)
  setVar(0xa02e,5);setVar(0xa081,2);setVar(0x4092,6)
  local expected={}
  local baselineHeap
  for _,map in ipairs({{39,4,1},{77,0,2},{2,2,3},{100,0,1},{39,4,1}}) do
    warp(map[1],map[2],map[3])
    local before=snapshot()
    enter()
    F.check('active campaign default in '..map[1],F.r8(S.sStoryRegion)==map[3]-1)
    local current={id(0),id(1),id(2)}
    if #expected==0 then expected=current end
    F.check('regional objectives survive travel '..map[1],table.concat(current)==table.concat(expected))
    tap('A');tap('R');F.check('detail paging works',F.r8(S.sStoryPage)==1)
    tap('L');tap('Down');tap('Down');tap('Down')
    F.check('all regions review without travel',F.r8(S.sStoryRegion)==map[3]-1)
    tap('B');close()
    F.check('browsing preserves campaign/party/flags '..map[1],snapshot()==before)
    local value=heap()
    if map[1]==39 and not baselineHeap then baselineHeap=value
    elseif map[1]==39 then F.check('repeat same-map heap restored',value==baselineHeap) end
  end
  -- Save through the real menu, reboot, Continue, then resolve existing progress.
  tap('Start');assert(F.selectStartIcon(7),'Save missing');tap('A');tap('A');tap('A');F.idle(600)
  client.reboot_core();F.idle(240)
  F.check('Continue returns to saved region',F.boot(39))
  enter();F.check('Continue derives same objectives',table.concat({id(0),id(1),id(2)})==table.concat(expected))
  close()
  F.finish()
end)
