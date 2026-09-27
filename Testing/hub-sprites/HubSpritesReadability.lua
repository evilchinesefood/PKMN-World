local here=(debug.getinfo(1,"S").source:sub(2)):match("^(.*[/\\])") or ""
package.path=here.."?.lua;"..package.path
local H=require("hub_lib").new("HubSpritesReadability")
local F,S=H.F,H.S
-- Anchor is authored position; runtime x/y is written independently by census.
local targets={{"Route35_10_39",18,0},{"Route35_12_16",17,0},{"Route35_12_19",16,0},
 {"Route35_26_16",14,0},{"Route35_28_9",15,0},{"Route35_32_45",13,0},
 {"Park_14_47",19,22},{"Park_25_44",15,12},{"Park_29_44",16,12},{"Park_26_47",23,22}}
local function clock(hour)
  -- Set the synthetic save's clock so a map reload keeps this time. Debug hour
  -- overrides alone are cleared by the real warp path.
  local off=F.sb2()+S.SaveBlock2.localTimeOffset
  local h,m=F.rs8(S.gLocalTime+S.Time.hours),F.rs8(S.gLocalTime+S.Time.minutes)
  local delta=((h*60+m)-(hour*60+30))%(24*60)
  local mm=F.rs8(off+S.Time.minutes)+delta%60
  F.w8(off+S.Time.minutes,mm%60)
  F.w8(off+S.Time.hours,(F.rs8(off+S.Time.hours)+delta//60+mm//60)%24)
end
F.run(function()
  if not F.boot(100) then F.finish();return end
  H.invoke(12) -- only these synthetic-save trainers; all objects retain collision/movement
  for variant=0,2 do
    H.invoke(0,variant)
    for _,hour in ipairs({12,22}) do
      clock(hour)
      for i,t in ipairs(targets) do
        local tag=string.format("%s_follower%d_%02dh",t[1],variant,hour)
        H.invoke(10,i-1,240)
        F.check(tag..": actual day/night state",F.r8(S.gTimeOfDay)==(hour==22 and S.TimeOfDay.NIGHT or S.TimeOfDay.DAY))
        local x0,y0=F.pos()
        local walked=false
        for _,pair in ipairs({{"Left","Right"},{"Right","Left"},{"Up","Down"},{"Down","Up"}}) do
          if F.step(pair[1]) then
            F.step(pair[2]);local x,y=F.pos();walked=x==x0 and y==y0
            break
          end
        end
        F.check(tag..": player can walk beside capture target",walked)
        F.idle(30);H.census(tag);H.follower(tag,variant)
        local o=H.actor(t[2]);local expected=t[3]==0 or t[3]==hour
        F.check(tag..": target visibility matches its real hide flag",expected and o~=nil and o.visible or not expected and o==nil,
          o and string.format("id=%d runtime=(%d,%d) visible=%s",t[2],o.x,o.y,tostring(o.visible)) or "not active")
        F.shot(tag)
        -- Short unmodified live movement sample at the dense daytime route / southern park.
        if variant==1 and hour==12 and (i==2 or i==8) then
          for frame=1,120 do
            if frame%6==1 then client.screenshot(F.out..string.format("clip_%s_%03d.png",tag,frame)) end
            F.idle(1)
          end
        end
      end
    end
  end
  H.finish()
end)
