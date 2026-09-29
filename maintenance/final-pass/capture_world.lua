-- Capture unmodified production ROM scenes on a disposable fresh game.
local here=(debug.getinfo(1,'S').source:sub(2)):match('^(.*[/\\])') or ''
package.path=here..'../../test/overworld/lua/?.lua;'..package.path
local S=require('symbols');local F=require('lib').new(S,'ShowcaseWorld')
local scenes={
  {name="RegionHub",group=100,map=0,warp=0},
  {name="ViridianCity_Frlg",group=37,map=1,warp=0},
  {name="VermilionCity_Frlg",group=37,map=5,warp=0},
  {name="CeladonCity_Frlg",group=37,map=6,warp=0},
  {name="CherrygroveCity",group=75,map=1,warp=0},
  {name="EcruteakCity",group=85,map=0,warp=0},
  {name="OlivineCity",group=87,map=0,warp=0},
  {name="MossdeepCity",group=0,map=6,warp=0},
  {name="RustboroCity",group=0,map=3,warp=0},
  {name="FortreeCity",group=0,map=4,warp=0},
  {name="SootopolisCity",group=0,map=7,warp=0},
  {name="BattleFrontier_OutsideEast",group=26,map=14,warp=0},
  {name="RegionHub_2F",group=100,map=1,warp=0},
}
local function digits(n) return n//100,(n//10)%10,n%10 end
F.run(function()
 for i=1,6000 do if F.cb2()==S.MainCB2_WorldTitleScreen then break end;F.idle(1) end
 F.idle(100);F.check('World title visible',F.cb2()==S.MainCB2_WorldTitleScreen);F.shot('title')
 assert(F.boot(100))
 F.dbg();F.sel(2);F.sel(9);F.idle(180);F.bOut(6)
 F.check('synthetic showcase team exists',F.r8(S.gPartiesCount)>0)
 -- Set the disposable console clock to noon using the production RTC offset.
 local off=F.sb2()+S.SaveBlock2.localTimeOffset
 local h=F.rs8(S.gLocalTime+S.Time.hours);local m=F.rs8(S.gLocalTime+S.Time.minutes)
 local delta=((h*60+m)-(12*60+30))%(24*60)
 local minutes=F.rs8(off+S.Time.minutes)+(delta%60)
 local carry=minutes>=60 and 1 or 0
 F.w8(off+S.Time.minutes,minutes%60)
 F.w8(off+S.Time.hours,(F.rs8(off+S.Time.hours)+delta//60+carry)%24)
 F.w8(S.sHoursOverride,0);F.w16(S.gTimeUpdateCounter,0);F.idle(120)
 for _,s in ipairs(scenes) do
  local gh,gt,go=digits(s.group);local mh,mt,mo=digits(s.map);local wh,wt,wo=digits(s.warp)
  assert(F.warpTo(gh,gt,go,mh,mt,mo,wh,wt,wo,s.group,s.map,s.name))
  F.idle(120)
  F.press("B",3);F.idle(60)
  F.check(s.name..' loaded',F.grp()==s.group and F.mapn()==s.map)
  F.check(s.name..' no crash',not F.reportCrash(s.name))
  F.shot(s.name)
 end
 F.finish()
end)
