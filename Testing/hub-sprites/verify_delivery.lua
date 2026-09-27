-- Runs the UNMODIFIED development ROM and the prepared synthetic save.
local here=(debug.getinfo(1,"S").source:sub(2)):match("^(.*[/\\])") or ""
package.path=here.."../lua/?.lua;"..package.path
local S=require("symbols")
local F=require("lib").new(S,"HubSpritesDelivery")
local function npc(id,gfx)
  for i=0,15 do
    local b=S.gObjectEvents+i*S.ObjectEvent.stride
    if (F.r8(b)&1)~=0 and F.r8(b+S.ObjectEvent.localId)==id then
      return F.r16(b+S.ObjectEvent.graphicsId)==gfx and (F.r8(b+S.ObjectEvent.flags1)&0x60)==0
    end
  end
  return false
end
F.run(function()
  if not F.boot(100) then F.finish();return end
  F.check("prepared save starts in Hub",F.grp()==100 and F.mapn()==0)
  F.check("harbor master reachable",F.route({{3,13}},"harbor"))
  F.face("Down");F.check("FRLG sailor visible",npc(12,332));F.press("A",2);F.idle(100)
  F.shot("harbor_dialogue");F.check("harbor dialogue closes",F.dismiss(200))
  F.check("curator reachable",F.route({{6,13},{6,6},{22,6}},"curator"))
  F.face("Down");F.check("FRLG gentleman visible",npc(13,331));F.press("A",2);F.idle(100)
  F.shot("curator_dialogue");F.check("curator dialogue closes",F.dismiss(200))
  F.check("walk past nurse",F.route({{22,4},{6,4},{6,12},{14,12}},"nurse"))
  local visible=false
  for i=0,15 do
    local b=S.gObjectEvents+i*S.ObjectEvent.stride
    if (F.r8(b)&1)~=0 and F.r8(b+S.ObjectEvent.localId)==254 then
      visible=(F.r8(b+S.ObjectEvent.flags1)&0x60)==0
    end
  end
  F.check("follower remains visible beside nurse",visible)
  F.shot("nurse_follower");F.finish()
end)
