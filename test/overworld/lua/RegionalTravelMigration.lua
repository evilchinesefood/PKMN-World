local here=(debug.getinfo(1,"S").source:sub(2)):match("^(.*[/\\])") or ""
package.path=here.."?.lua;"..package.path
local S=require("symbols")
local F=require("lib").new(S,"RegionalTravelMigration")
local expectedBox="c75d29ea323305abbce9dadaddd9ffcde3e90202c1bfc5c3ffffff00bad90000f592d041f36e2c41f56e2c41ac6e1941ab6c7243ff610469f56fc8100a91d37ef56e2c413f162c41b52c635df56e2d77"
local function bank() return F.sb3()+S.SaveBlock3.regionalTravel end
local function center() return F.r16(bank()+164) end
local function exactBox()
  for i=0,79 do
    if F.r8(S.gParties+i)~=tonumber(expectedBox:sub(i*2+1,i*2+2),16) then return false,i end
  end
  return true,"all 80 bytes match the clean v10 individual"
end
F.run(function()
  if not F.boot(2,true) then F.check("supported dirty v10 save loads",false);F.finish();return end
  local x,y=F.pos()
  F.check("Continue preserves the real saved Center location",F.grp()==2 and F.mapn()==2 and x==7 and y==4)
  F.check("migration reaches current save format",F.r8(F.sb2()+S.SaveBlock2.saveVersion)==S.SAVE_FORMAT_VERSION)
  F.check("identity allocation begins at one",F.r32(bank())==1)
  local empty=true
  for i=4,167 do if F.r8(bank()+i)~=0 then empty=false end end
  F.check("dirty appended bytes become empty teams and checkpoints",empty)
  local same,detail=exactBox()
  F.check("migration clears legacy identity bits without changing the original Pokemon",same,tostring(detail))
  F.check("Continue inside a Center does not fabricate an entered checkpoint",center()==0)
  F.shot("legacy_continue_no_history")
  F.check("walk to Center exit",F.leg(7,7))
  F.press("Down",20);F.idle(140)
  F.check("walking outside still leaves checkpoint empty",center()==0 and not (F.grp()==2 and F.mapn()==2))
  F.press("Up",22);F.idle(140)
  F.check("subsequent actual Center entry records a checkpoint",F.grp()==2 and F.mapn()==2 and center()~=0)
  F.check("Center entry does not invent a team memory",F.r8(bank()+4+2*52+48)==0)
  F.shot("legacy_actual_entry")
  F.finish()
end)
