-- Isolated capture ROM only; real production screens with deterministic RAM fixtures.
package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local S=require('symbols');local X=require('feature_symbols')
local F=require('lib').new(S,'VisualFeatures')
local after=X.SpriteCB_AmbientRipple~=nil
local function tap(k,n) for i=1,(n or 1) do F.press(k,2);F.idle(110) end end
local function hook(command,arg,wait)
  F.w16(S.gSpecialVar_0x8004,command);F.w16(X.gSpecialVar_0x8005,arg or 0)
  F.w32(S.gMain+4,X.hook);F.idle(wait or 240)
end
local function close(tag)
  for i=1,8 do tap('B');if F.ow() and F.r32(S.sUsmState)==0 then break end end
  F.check(tag..' returns to overworld',F.ow())
  if not F.ow() then
    F.L(string.format('cb2=%08x mapHandler=%08x',F.cb2(),F.r32(X.sFieldRegionMapHandler)))
    F.reportCrash(tag);F.shot('failed_return')
  end
  assert(F.ow(),tag..' failed to return; refusing to inject another screen')
end
local function rings()
  if not after then return 0 end
  local n=0
  for i=0,63 do
    local p=S.gSprites+i*S.Sprite.stride
    if (F.r16(p+S.Sprite.inUse)&1)~=0 and (F.r32(p+0x1C)&~1)==X.SpriteCB_AmbientRipple then n=n+1 end
  end
  return n
end
local function dexPalette(tag)
  if not after then return end
  local ok=true
  for i=64,95 do if F.r16(S.gPlttBufferUnfaded+i*2)~=0 then ok=false end end
  F.check(tag..' unused banks4/5 deterministic',ok)
end
F.run(function()
  F.check('boot ready',F.boot(100))
  if not F.ow() then F.finish();return end
  hook(0)
  for _,frame in ipairs({0,1,19}) do
    hook(1,frame);F.shot('options_frame'..(frame+1));close('options frame'..(frame+1))
    F.check('saved frame selection retained',((F.r16(F.sb2()+0x14)>>3)&31)==frame)
  end
  hook(5,0)
  F.press('Start',2);F.idle(100);F.shot('wheel_normal')
  local st=F.r32(S.sUsmState);F.check('wheel allocated',st>=0x02000000 and st<0x02040000)
  tap('Select');F.shot('wheel_move');F.check('wheel enters MOVE',F.r32(st+24)==1)
  tap('Select');F.shot('wheel_done');F.check('wheel exits MOVE',F.r32(st+24)==0);close('wheel')
  hook(3);F.shot('card_front');tap('R');F.shot('card_region2');tap('R');F.shot('card_region3')
  tap('A');F.shot('card_back');tap('A');F.shot('card_front_return');close('card')
  hook(4);F.shot('dex_list');dexPalette('dex list')
  tap('A');F.shot('dex_detail');dexPalette('dex detail')
  for _,page in ipairs({'area','stats','evo','cry','size'}) do tap('Right');F.shot('dex_'..page) end
  close('dex')
  hook(4);tap('Select');F.shot('dex_search');tap('A');tap('Down',5);tap('A',2);F.shot('dex_search_results');dexPalette('dex results');close('dex search')
  local names={'petalburg','violet','fuchsia','route119'}
  local ids={{0,0},{75,6},{37,7},{0,34}}
  for index,name in ipairs(names) do
    hook(20,index-1,300)
    if index==4 then hook(6,3,300) end -- explicit WEATHER_RAIN fixture
    F.check(name..' warp',F.grp()==ids[index][1] and F.mapn()==ids[index][2])
    F.check(name..' controllable overworld',F.ow())
    local peak=0;local frames=0
    for i=1,600 do
      F.idle(1);local n=rings();peak=math.max(peak,n)
      if n>0 then frames=frames+1 end
      if i==180 or i==360 then F.shot(name..'_water_'..i) end
    end
    F.L(name..' peak rings='..peak..' frames with rings='..frames)
    if after then F.check(name..' visible ambient rings',peak>0);F.check(name..' cap',peak<=5) end
    if index<4 then
      hook(2,os.getenv('PW_CONTROL') and 1 or 0);F.shot(name..'_field_map');close(name..' map')
      hook(7);F.shot(name..'_fly_map');close(name..' fly map')
      hook(3);F.shot(name..'_card');close(name..' card')
    end
    F.check(name..' no crash screen',not F.reportCrash(name))
  end
  F.finish()
end)
