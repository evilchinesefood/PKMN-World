-- Verify the lifecycle-generated synthetic save on the unpatched delivery ROM.
local here=debug.getinfo(1,"S").source:sub(2):match("^(.*[/\\])") or ""
package.path=here.."../lua/?.lua;"..package.path
local S=require("symbols")
local F=require("lib").new(S,"ViridianArtDelivery")
F.run(function()
  F.check("unpatched ROM continues in Viridian",F.boot(37,true) and F.mapn()==1)
  F.idle(120)
  F.check("night lighting is active",F.r16(S.gTimeBlend+10)==0)
  F.check("player retains control",F.ensureFree())
  F.shot("night_continue")
  F.finish()
end)
