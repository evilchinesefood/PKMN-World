local here=debug.getinfo(1,"S").source:sub(2):match("^(.*[/\\])") or ""
package.path=here.."?.lua;"..package.path
local W=require("lighting_lib").new("RegionalLightingCapture")
local F,S=W.F,W.S
F.run(function()
  assert(F.boot(100),"boot failed"); W.invoke(0); W.invoke(3,0,1200)
  assert(F.r16(W.X.gSpecialVar_0x8005)==1,"base save failed")
  for i=tonumber(os.getenv("PW_FIRST_SCENE") or "1"),tonumber(os.getenv("PW_LAST_SCENE") or tostring(#W.scenes)) do
    if i>tonumber(os.getenv("PW_FIRST_SCENE") or "1") then
      client.reboot_core();F.idle(5);assert(F.boot(100,true),"fresh scene boot failed");W.invoke(0)
    end
    local name=W.go(i)
    for _,time in ipairs({{"noon",12,256},{"dusk",20,128},{"night",22,0}}) do
      W.clock(time[2])
      F.check(name.." "..time[1]..": clock blend",F.r16(S.gTimeBlend+10)==time[3])
      local hardware=true
      for c=1,207 do
        hardware=hardware and (F.r16(0x05000000+c*2)&0x7FFF)==(F.r16(S.gPlttBufferFaded+c*2)&0x7FFF)
      end
      F.check(name.." "..time[1]..": hardware palette",hardware)
      W.dump(name.."_"..time[1])
    end
  end
  F.finish()
end)
