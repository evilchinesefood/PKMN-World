-- Ordinary, unmodified ROM plus the synthetic save made by lifecycle.lua.
local here = debug.getinfo(1,"S").source:sub(2):match("^(.*[/\\])") or ""
package.path = here.."../lua/?.lua;"..package.path
local S = require("symbols")
local F = require("lib").new(S,"WarmWindowsDelivery")
local function amber(tag)
  F.check(tag..": full night",F.r16(S.gTimeBlend+10)==0)
  -- Existing protected-light blend applied to the approved alternate RGB5.
  local wanted = {31|(28<<5)|(17<<10),31|(26<<5)|(14<<10),29|(23<<5)|(11<<10)}
  local okay=true
  for i=1,3 do
    local index=135+i
    okay=okay and (F.r16(S.gPlttBufferFaded+index*2)&0x7FFF)==wanted[i]
      and (F.r16(0x05000000+index*2)&0x7FFF)==wanted[i]
  end
  F.check(tag..": amber glass in hardware",okay)
end
F.run(function()
  assert(F.boot(75,true),"prepared save failed to boot")
  F.idle(120)
  F.check("prepared save starts in Cherrygrove",F.grp()==75 and F.mapn()==1)
  amber("Continue");F.shot("west_window")
  F.check("walk to middle house",F.route({{42,16},{42,17}},"middle_house"))
  F.shot("middle_window");amber("walking east")
  F.check("walk around east house",F.route({{46,17},{46,19},{50,19},{50,20}},"east_house"))
  F.shot("east_window");amber("east house")
  F.press("Start",2);F.idle(60);F.shot("menu")
  F.press("B",2);F.idle(120)
  F.check("menu closes and normal walking works",F.ensureFree())
  amber("menu return");F.finish()
end)
