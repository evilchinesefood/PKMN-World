local here=debug.getinfo(1,"S").source:sub(2):match("^(.*[/\\])") or ""
package.path=here.."?.lua;"..package.path
local W=require("lighting_lib").new("RegionalLightingLifecycle")
local F,S=W.F,W.S
local function tap(key) F.press(key,2);F.idle(60) end
local function snapshot()
  local values={}
  for i=0,207 do values[i]=F.r16(S.gPlttBufferUnfaded+i*2) end
  return values
end
local function restored(values,label)
  local ok=true
  for i=0,207 do ok=ok and values[i]==F.r16(S.gPlttBufferUnfaded+i*2) end
  F.check(label..": daylight/alternate sources restored",ok)
  F.check(label..": night blend restored",F.r16(S.gTimeBlend+10)==0)
end
local function battlePrompt()
  local text={}
  for i=0,80 do
    local b=F.r8(S.gDisplayedStringBattle+i);if b==255 then break end
    if b>=0xBB and b<=0xD4 then text[#text+1]=string.char(b-0xBB+65)
    elseif b>=0xD5 and b<=0xEE then text[#text+1]=string.char(b-0xD5+65)
    elseif b==0 then text[#text+1]=" " end
  end
  return table.concat(text):find("WHAT WILL",1,true)~=nil
end
F.run(function()
  assert(F.boot(100),"boot failed");W.invoke(0)
  for i,name in ipairs({"Hoenn","Kanto","Johto"}) do
    W.invoke(4,i-1,360);W.clock(22)
    local group,map=F.grp(),F.mapn();local values=snapshot()
    tap("Start");tap("Right");tap("Left");tap("B");F.idle(120)
    F.check(name..": menu closes",F.ow());restored(values,name.." menu")
    F.press("Up",90);F.idle(240)
    F.check(name..": normal door entry",F.ow() and (F.grp()~=group or F.mapn()~=map))
    F.shot(name.."_inside")
    F.press("Down",90);F.idle(240)
    F.check(name..": normal door exit",F.ow() and F.grp()==group and F.mapn()==map)
    restored(values,name.." door");W.dump(name.."_door_return")
    W.invoke(2,0,600)
    F.check(name..": real battle entered",not F.ow())
    for _=1,100 do if battlePrompt() then break end;tap("A") end
    assert(battlePrompt(),"battle prompt missing")
    tap("B");F.check(name..": Run selected",F.r8(S.gActionSelectionCursor)==3);tap("A")
    for _=1,40 do if F.ow() then break end;tap("A") end
    assert(F.ow(),"battle return failed");F.idle(120)
    F.check(name..": escaped normally",F.outcome()==4);restored(values,name.." battle")
    W.invoke(3,0,1200);F.check(name..": save written",F.r16(W.X.gSpecialVar_0x8005)==1)
    client.reboot_core();F.idle(5);assert(F.boot(group,true),"night save failed to reload")
    F.idle(120);F.check(name..": Continue returns to the same town",F.grp()==group and F.mapn()==map)
    restored(values,name.." Continue");W.dump(name.."_continue")
  end
  F.finish()
end)
