local here=(debug.getinfo(1,"S").source:sub(2)):match("^(.*[/\\])") or ""
package.path=here.."?.lua;"..package.path
local H=require("hub_lib").new("HubSpritesComparison")
local F=H.F
local after=os.getenv("PW_HUB_AFTER")=="1"
local function clip(tag,command,arg,frames)
  H.invoke(command,arg,1)
  for i=1,frames do
    if i%4==1 then client.screenshot(F.out..string.format("clip_%s_%03d.png",tag,i)) end
    F.idle(1)
  end
end
F.run(function()
  if not F.boot(100) then F.finish();return end
  H.invoke(0,2)
  for _,c in ipairs({{name="harbor",warp=1,id=12,dir=2},{name="curator",warp=2,id=13,dir=2}}) do
    H.invoke(1,c.warp,180)
    F.check(c.name..": step with follower",F.step("Right"));F.idle(30)
    H.census(c.name);H.follower(c.name,2)
    H.probe(c.id,c.name,after)
    F.shot(c.name.."_default")
    for dir=1,4 do
      H.invoke(4,c.id+dir*256,30)
      H.probe(c.id,c.name.."_facing_"..dir,after)
      F.shot(c.name.."_facing_"..dir)
    end
    clip(c.name.."_walk",8,c.id+c.dir*256,32)
    clip(c.name.."_return",8,c.id+(c.dir==1 and 2 or 1)*256,32)
    clip(c.name.."_shadow",9,c.id,48)
    H.probe(c.id,c.name.."_post_animation",after)
  end
  H.invoke(1,3,180)
  F.check("walk past nurse",F.step("Right"));F.idle(30)
  H.census("nurse");H.follower("nurse",2);F.shot("nurse_and_chansey")
  H.finish()
end)
