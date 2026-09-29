local here=debug.getinfo(1,"S").source:sub(2):match("^(.*[/\\])") or ""
package.path=here.."../night-lighting/?.lua;"..package.path
local W=require("lighting_lib").new("ViridianTransitionsCapture")
local F,S=W.F,W.S
local scenes={{"west_entry",16,18},{"central_junction",22,21},{"east_loop",37,28},
              {"south_approach",22,33},{"south_verge",35,33}}
F.run(function()
  assert(F.boot(100),"boot failed")
  W.invoke(0)
  for i,scene in ipairs(scenes) do
    W.invoke(1,i-1,360)
    local x,y=F.pos()
    assert(F.ow() and x==scene[2] and y==scene[3],"wrong capture position: "..scene[1])
    for _,time in ipairs({{"noon",12,256},{"dusk",20,128},{"night",22,0}}) do
      W.clock(time[2])
      W.invoke(4)
      F.check(scene[1].." "..time[1]..": clock",F.r16(S.gTimeBlend+10)==time[3])
      F.check(scene[1].." "..time[1]..": visible follower",F.r16(W.X.gSpecialVar_0x8005)==1)
      local hardware=true
      for c=1,207 do
        hardware=hardware and F.r16(0x05000000+c*2)==F.r16(S.gPlttBufferFaded+c*2)
      end
      F.check(scene[1].." "..time[1]..": hardware palette",hardware)
      W.dump(scene[1].."_"..time[1])
    end
  end
  F.finish()
end)
