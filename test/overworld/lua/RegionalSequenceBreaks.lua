-- Sequence breaks through the World Transit gate's "resume at the last Pokemon Center" choice.
-- Before Surf, Mr. Briney's boat is the only way back to Dewford. A Hub Pass used on Dewford leaves
-- him docked there, so the standard Hoenn arrival (Slateport Harbor) brings him to Route 109 first.
-- Resuming at any other remembered Hoenn Center lands the player on the same mainland and must do
-- the same, while resuming at Dewford's own Center must leave him where he is.
-- Setup writes badges, Briney's dock, the remembered Center and one debug Pokemon. The gate's
-- team, arrival and confirm choices and the Hub Pass use real input.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "RegionalSequenceBreaks")

local HUB = {100, 0}
local HOENN, HOENN_ATTENDANT = 3, 21
local SLATEPORT_HARBOR = {9, 9}
local SLATEPORT_CENTER = {id=2, g=9, m=11}
local MAUVILLE_CENTER = {id=3, g=10, m=5}
local DEWFORD_CENTER = {id=11, g=3, m=1}
local FLAG_HIDE_DEWFORD_BRINEY, FLAG_HIDE_DEWFORD_BOAT = 0x2E4, 0x2E7
local FLAG_HIDE_ROUTE109_BRINEY, FLAG_HIDE_ROUTE109_BOAT = 0x2E5, 0x2E8
local FLAG_DEFEATED_PETALBURG_GYM = 0x4F4
local FLAG_HOENN_STONE_BADGE = 0x94F
local VAR_BRINEY_LOCATION = 0x4096
local hubPass

local function where() local x,y=F.pos(); return string.format("%d/%d (%d,%d)",F.grp(),F.mapn(),x,y) end
local function mapIs(g,m) return F.grp()==g and F.mapn()==m end
local function travelBank() return F.sb3()+S.SaveBlock3.regionalTravel end
local function centerAddress(region) return travelBank()+160+(region-1)*2 end
local function count() return F.r8(S.gPartiesCount) end
local function flagAddress(id)
  local base,offset
  if id>=0x6000 and id<0x6400 then base=F.sb3()+S.SaveBlock3.johtoFlags;offset=id-0x6000
  else base=F.sb1()+S.SaveBlock1.flags;offset=id end
  return base+offset//8,1<<(offset%8)
end
local function flag(id,value)
  local a,bit=flagAddress(id)
  F.w8(a,value and (F.r8(a)|bit) or (F.r8(a)&(~bit&255)))
end
local function flagGet(id) local a,bit=flagAddress(id); return (F.r8(a)&bit)~=0 end
local function varAddress(id) return F.sb1()+S.SaveBlock1.vars+(id-0x4000)*2 end
local function var(id,value) F.w16(varAddress(id),value) end
local function varGet(id) return F.r16(varAddress(id)) end
local function drain()
  for _=1,30 do
    F.press("B",2); F.idle(16)
    if F.ensureFree() then return true end
  end
  return false
end
local function scriptMenuActive()
  for i=0,S.Task.count-1 do
    local a=S.gTasks+i*S.Task.stride
    local fn=F.r32(a+S.Task.func)&0xFFFFFFFE
    if F.r8(a+S.Task.isActive)~=0 and (fn==S.Task_HandleYesNoInput or fn==S.Task_HandleMultichoiceInput or fn==S.Task_CallYesOrNoCallback) then return true end
  end
  return false
end
local function menu(want,tag)
  for _=1,65 do
    if F.reportCrash(tag) then return false end
    if scriptMenuActive() then
      F.idle(12)
      for _=1,10 do
        local c=F.mcur()
        if c==want then F.shot(tag);F.press("A",2);F.idle(45);return true end
        F.press(c>want and "Up" or "Down",2);F.idle(12)
      end
      return false
    end
    F.press("A",2);F.idle(25)
  end
  return false
end
local function awaitMap(g,m,tag)
  for _=1,220 do
    if mapIs(g,m) then F.idle(100);return true end
    if F.reportCrash(tag) then return false end
    F.press("A",2);F.idle(14)
  end
  F.shot(tag.."_failed")
  return false
end
local function setParty()
  F.dbg();F.idle(40);F.sel(2);F.idle(40)
  for _=1,9 do F.press("Down",3);F.idle(16) end
  F.press("A",3);F.idle(180)
  drain()
  return count()==1
end
-- arrival 0 resumes at the remembered Center, 1 takes the standard regional arrival.
local function crossHoenn(arrival,dest,tag)
  if not F.route({{16,4},{HOENN_ATTENDANT,4},{HOENN_ATTENDANT,3}},tag.."_walk") then return false end
  F.face("Up");F.press("A",3);F.idle(60)
  if not menu(1,tag.."_team") then return false end
  if not menu(arrival,tag.."_arrival") then return false end
  if not menu(0,tag.."_confirm") then return false end
  return awaitMap(dest[1] or dest.g,dest[2] or dest.m,tag)
end
local function passToHub(tag)
  F.w16(F.sb1()+S.SaveBlock1.registeredItem,hubPass)
  F.press("Select",2);F.idle(90)
  if not menu(0,tag.."_confirm") then return false end
  return awaitMap(HUB[1],HUB[2],tag)
end
-- Briney sailed the player back to Dewford and is docked there; Norman is not beaten, so no Surf.
local function dockBrineyAtDewford()
  flag(FLAG_HIDE_DEWFORD_BRINEY,false);flag(FLAG_HIDE_DEWFORD_BOAT,false)
  flag(FLAG_HIDE_ROUTE109_BRINEY,true);flag(FLAG_HIDE_ROUTE109_BOAT,true)
  flag(FLAG_DEFEATED_PETALBURG_GYM,false)
  var(VAR_BRINEY_LOCATION,2)
end
local function brineyAtRoute109(returnTo)
  return flagGet(FLAG_HIDE_DEWFORD_BRINEY) and flagGet(FLAG_HIDE_DEWFORD_BOAT)
     and not flagGet(FLAG_HIDE_ROUTE109_BRINEY) and not flagGet(FLAG_HIDE_ROUTE109_BOAT)
     and varGet(VAR_BRINEY_LOCATION)==(returnTo or 3)
end
local function brineyAtDewford()
  return not flagGet(FLAG_HIDE_DEWFORD_BRINEY) and not flagGet(FLAG_HIDE_DEWFORD_BOAT)
     and flagGet(FLAG_HIDE_ROUTE109_BRINEY) and flagGet(FLAG_HIDE_ROUTE109_BOAT)
     and varGet(VAR_BRINEY_LOCATION)==2
end
local function brineyState()
  return string.format("dewford=%s/%s route109=%s/%s var=%d",
    tostring(not flagGet(FLAG_HIDE_DEWFORD_BRINEY)),tostring(not flagGet(FLAG_HIDE_DEWFORD_BOAT)),
    tostring(not flagGet(FLAG_HIDE_ROUTE109_BRINEY)),tostring(not flagGet(FLAG_HIDE_ROUTE109_BOAT)),
    varGet(VAR_BRINEY_LOCATION))
end

local function resumeAt(center,name)
  dockBrineyAtDewford()
  F.w16(centerAddress(HOENN),center.id)
  local ok=crossHoenn(0,center,"resume_"..name)
  F.check(name.." Center resume lands in that Center",ok,where())
  return ok
end

F.run(function()
  if not F.boot(HUB[1]) then F.check("fresh boot",false);F.finish();return end
  flag(0xDCF,true)
  flag(0x51,true)
  flag(FLAG_HOENN_STONE_BADGE,true)
  F.w8(F.sb2()+S.SaveBlock2.introDoneBits,7)
  F.check("debug prerequisite creates one Pokemon",setParty())

  -- The first mature Hoenn trip supplies the Hub Pass; it also proves the standard-arrival contract.
  local before={}
  for _,id in ipairs(select(2,F.keyItemSlot(0xFFFF))) do before[id]=true end
  dockBrineyAtDewford()
  F.w16(centerAddress(HOENN),0)
  local first=crossHoenn(1,SLATEPORT_HARBOR,"standard")
  F.check("standard Hoenn arrival reaches Slateport Harbor",first,where())
  if not first then F.finish();return end
  -- The standard arrival respawns in Littleroot, so a whiteout or Teleport must send him home.
  F.check("standard arrival brings Briney to Route 109",brineyAtRoute109(1),brineyState())
  for _,id in ipairs(select(2,F.keyItemSlot(0xFFFF))) do if not before[id] then hubPass=id end end
  F.check("first mature trip supplies a Hub Pass",hubPass~=nil)
  if not hubPass then F.finish();return end

  F.check("Hub Pass back to the hub",passToHub("out_standard"))
  if resumeAt(SLATEPORT_CENTER,"Slateport") then
    F.check("Slateport Center resume brings Briney to Route 109",brineyAtRoute109(),brineyState())
  end

  F.check("Hub Pass back after Slateport",passToHub("out_slateport"))
  if resumeAt(MAUVILLE_CENTER,"Mauville") then
    F.check("Mauville Center resume brings Briney to Route 109",brineyAtRoute109(),brineyState())
  end

  F.check("Hub Pass back after Mauville",passToHub("out_mauville"))
  if resumeAt(DEWFORD_CENTER,"Dewford") then
    F.check("Dewford Center resume leaves Briney docked at Dewford",brineyAtDewford(),brineyState())
  end

  -- After Norman the player can Surf to Dewford, so the resume leaves Briney alone.
  F.check("Hub Pass back after Dewford",passToHub("out_dewford"))
  flag(FLAG_DEFEATED_PETALBURG_GYM,true)
  F.w16(centerAddress(HOENN),SLATEPORT_CENTER.id)
  flag(FLAG_HIDE_DEWFORD_BRINEY,false);flag(FLAG_HIDE_DEWFORD_BOAT,false)
  flag(FLAG_HIDE_ROUTE109_BRINEY,true);flag(FLAG_HIDE_ROUTE109_BOAT,true)
  var(VAR_BRINEY_LOCATION,2)
  local late=crossHoenn(0,SLATEPORT_CENTER,"resume_after_norman")
  F.check("post-Norman Slateport resume lands in that Center",late,where())
  if late then F.check("post-Norman resume leaves Briney docked at Dewford",brineyAtDewford(),brineyState()) end
  F.finish()
end)
