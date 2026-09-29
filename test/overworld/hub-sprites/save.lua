local here=(debug.getinfo(1,"S").source:sub(2)):match("^(.*[/\\])") or ""
package.path=here.."?.lua;"..package.path
local H=require("hub_lib").new("HubSpritesSave")
local F=H.F
F.run(function()
  if not F.boot(100) then F.finish();return end
  H.invoke(0,0);H.invoke(1,1,180)
  F.check("walk on ordinary floor",F.step("Right"));F.idle(30)
  H.follower("delivery",0);H.probe(12,"delivery harbor",true)
  H.invoke(6,0,1200)
  local X=require("hub_symbols")
  F.check("synthetic save written",F.r16(X.gSpecialVar_0x8005)==1)
  client.reboot_core();F.idle(5)
  F.check("prepared save reloads",F.boot(100))
  F.check("normal walking after reload",F.ensureFree())
  H.follower("reloaded delivery",0)
  F.shot("ready_to_play")
  H.finish()
end)
