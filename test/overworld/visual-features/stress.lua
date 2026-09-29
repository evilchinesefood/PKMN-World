-- Disposable capture ROM only. Production menus, battles, weather and sprites.
package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local S=require('symbols');local X=require('feature_symbols')
local F=require('lib').new(S,'VisualStress')
local after=X.SpriteCB_AmbientRipple~=nil
local function hook(c,a,n)
  F.w16(S.gSpecialVar_0x8004,c);F.w16(X.gSpecialVar_0x8005,a or 0)
  F.w32(S.gMain+4,X.hook);F.idle(n or 240)
end
local function tap(k) F.press(k,8);F.idle(80) end
local function close()
  for i=1,10 do tap('B');if F.ow() then return end end
  error('screen did not return to overworld')
end
local function resources()
  local sprites,rings,tiles,pals,heap=0,0,0,0,0
  for i=0,63 do
    local p=S.gSprites+i*S.Sprite.stride
    if F.r16(p+S.Sprite.inUse)&1~=0 then
      sprites=sprites+1
      if after and (F.r32(p+0x1c)&~1)==X.SpriteCB_AmbientRipple then rings=rings+1 end
    end
  end
  for i=0,127 do local b=F.r8(X.sSpriteTileAllocBitmap+i);for k=0,7 do tiles=tiles+((b>>k)&1) end end
  local ambient=false
  for i=0,15 do local tag=F.r16(X.sSpritePaletteTags+2*i);if tag~=0xffff then pals=pals+1 end;if tag==0x1015 then ambient=true end end
  local p=X.gHeap
  for i=1,1024 do
    assert(p>=X.gHeap and p<X.gHeap+0x1c500,'heap chain outside owned arena')
    assert(F.r16(p+2)==0xa3a3,'heap header corrupted')
    if F.r16(p)&1~=0 then heap=heap+(F.r32(p+4)&0x3ffff) end
    p=F.r32(p+12);if p==X.gHeap then break end
    assert(i<1024,'heap list did not terminate')
  end
  return {sprites=sprites-rings,tiles=tiles-rings*4,pals=pals-(ambient and 1 or 0),heap=heap,rings=rings}
end
local function logResources(tag,r)
  F.L(string.format('%s sprites=%d tiles=%d palettes=%d heap=%d rings=%d',tag,r.sprites,r.tiles,r.pals,r.heap,r.rings))
end
local function setHour(hour)
  local off=F.sb2()+S.SaveBlock2.localTimeOffset
  local h,m=F.rs8(S.gLocalTime+S.Time.hours),F.rs8(S.gLocalTime+S.Time.minutes)
  local delta=((h*60+m)-(hour*60+30))%(24*60)
  local nm=F.rs8(off+S.Time.minutes)+delta%60
  F.w8(off+S.Time.minutes,nm%60)
  F.w8(off+S.Time.hours,(F.rs8(off+S.Time.hours)+delta//60+nm//60)%24)
  F.w8(S.sHoursOverride,0);F.w16(S.gTimeUpdateCounter,0);F.idle(120)
end
local function actionPrompt()
  local text={}
  for i=0,80 do
    local b=F.r8(S.gDisplayedStringBattle+i)
    if b==255 then break end
    if b>=0xbb and b<=0xd4 then text[#text+1]=string.char(b-0xbb+65)
    elseif b>=0xd5 and b<=0xee then text[#text+1]=string.char(b-0xd5+65)
    elseif b==0 then text[#text+1]=' ' end
  end
  return table.concat(text):find('WHAT WILL',1,true)~=nil
end
F.run(function()
  assert(F.boot(100),'boot failed');hook(0)
  if not os.getenv('PW_SAVE_ONLY') then
  local reference
  for cycle=1,50 do
    hook(20,0,300);assert(F.ow(),'pond warp failed')
    local kind=cycle%5
    if kind==0 then
      hook(8,0,600)
      F.check('battle '..cycle..' entered',not F.ow())
      if cycle==5 then F.shot('battle_entered') end
      for i=1,100 do
        if actionPrompt() then break end
        tap('A')
      end
      assert(actionPrompt(),'action prompt did not open')
      tap('B')
      F.check('battle '..cycle..' Run selected',F.r8(S.gActionSelectionCursor)==3)
      tap('A')
      for i=1,40 do if F.ow() then break end;tap('A') end
      if not F.ow() then F.shot('battle_failed_return') end
      assert(F.ow(),'wild battle did not return')
      F.check('battle '..cycle..' fled normally',F.outcome()==4)
    elseif kind==1 then hook(1);close()
    elseif kind==2 then hook(2);close()
    elseif kind==3 then hook(3);tap('R');tap('L');close()
    else hook(20,1,300);hook(20,0,300) end
    -- Same map, position and post-load state for every allocation comparison.
    hook(20,0,300)
    local r=resources();logResources('cycle '..cycle,r)
    if reference then
      F.check('cycle '..cycle..' heap stable',r.heap==reference.heap)
      F.check('cycle '..cycle..' sprites/tiles/palettes stable',r.sprites==reference.sprites and r.tiles==reference.tiles and r.pals==reference.pals)
    else reference=r end
  end
  F.shot('after_50_transitions')
  hook(20,3,300);hook(6,3,300);hook(9,0,1);setHour(22)
  F.step('Right');F.idle(90);F.step('Left');F.idle(90)
  local peak,oweFrames,followers=0,0,0
  local previous=F.r32(S.gMain+0x24);local missed=0
  for frame=1,1800 do
    F.idle(1)
    local r=resources();peak=math.max(peak,r.rings)
    local v=F.r32(S.gMain+0x24);if v==previous then missed=missed+1 end;previous=v
    local owe=false
    for i=0,15 do
      local p=S.gObjectEvents+i*S.ObjectEvent.stride
      if F.r8(p)&1~=0 then
        local id=F.r8(p+S.ObjectEvent.localId)
        if id==0xfe and F.r8(p+S.ObjectEvent.flags1)&0x20==0 then followers=followers+1 end
        if (F.r16(p+S.ObjectEvent.graphicsId)&0x4000)~=0 and id~=0xfe then owe=true end
      end
    end
    if owe then oweFrames=oweFrames+1 end
    if frame%4==0 then client.screenshot(F.out..string.format('rain_%04d.png',frame//4)) end
    if not F.ow() then error('stress scene unexpectedly entered another screen') end
  end
  F.check('30 seconds stable overworld',F.ow())
  F.check('follower visible during rain',followers>0)
  F.check('OWE visible during rain',oweFrames>0)
  if after then F.check('ambient visible during rain',peak>0 and peak<=5) end
  F.L(string.format('30-second metrics peakRings=%d oweFrames=%d followerFrames=%d unchangedVblankCounter=%d',peak,oweFrames,followers,missed))
  end
  -- A synthetic fresh-save fixture, never the owner save.
  hook(20,0,300);hook(9,250);setHour(14);hook(10,0,1)
  for i=1,3600 do if F.ow() then break end;F.idle(1) end
  F.L(string.format('save callback=%08x',F.cb2()))
  F.L('save status='..F.r16(X.gSpecialVar_0x8005))
  F.check('prepared playtest save written',F.r16(X.gSpecialVar_0x8005)==1)
  F.shot('prepared_save');F.finish()
end)
