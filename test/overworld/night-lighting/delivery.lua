-- Run on the unpatched delivery ROM with the lifecycle-generated synthetic save.
local here=debug.getinfo(1,"S").source:sub(2):match("^(.*[/\\])") or ""
package.path=here.."../lua/?.lua;"..package.path
local S=require("symbols")
local F=require("lib").new(S,"RegionalLightingDelivery")
F.run(function()
 F.check("prepared save continues on unpatched ROM",F.boot(75,true))
 F.idle(120)
 F.check("night lighting is live",F.r16(S.gTimeBlend+10)==0)
 local x,y=F.pos()
 F.press("Down",16);F.idle(60)
 local nx,ny=F.pos()
 F.check("player can walk after Continue",ny>y and nx==x)
 F.shot("night_continue")
 F.finish()
end)
