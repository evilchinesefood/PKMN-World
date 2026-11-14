-- Before Surf, Mr. Briney's boat is the only way between the west mainland and Slateport until
-- Rusturf Tunnel opens, and that takes Rock Smash and Wattson's badge. In the original game the
-- player first reaches Slateport on his boat, after his house-to-Dewford voyage. The standard
-- Hoenn arrival (Slateport Harbor) used Roxanne's badge alone, so it put a player east of Rusturf
-- Tunnel before that voyage, and any east arrival left Briney at his house on Route 104, out of
-- reach. Dewford and Brawly were then cut off until Wattson.
-- Setup writes badges, Briney's dock, visited towns, the remembered Center and one debug Pokemon.
-- The gate's team, arrival and confirm choices and the Hub Pass use real input.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BrineyEastArrival")

local HUB = {100, 0}
local HOENN, HOENN_ATTENDANT = 3, 21
local SLATEPORT_HARBOR = {9, 9}
local SLATEPORT_CENTER = {id=2, g=9, m=11}
local LITTLEROOT_BEDROOMS = {{1, 1}, {1, 3}}
local FLAG_RECEIVED_POKENAV = 0xBC
local FLAG_RUSTURF_TUNNEL_OPENED = 0xC7
local FLAG_SYS_POKEMON_GET = 0x948
local FLAG_HOENN_DYNAMO_BADGE = 0x951
local FLAG_VISITED_DEWFORD, FLAG_VISITED_SLATEPORT = 0x959, 0x95F
local FLAG_HIDE_ROUTE104_BRINEY, FLAG_HIDE_HOUSE_BRINEY = 0x2E2, 0x2E3
local FLAG_HIDE_DEWFORD_BRINEY, FLAG_HIDE_ROUTE109_BRINEY = 0x2E4, 0x2E5
local FLAG_HIDE_ROUTE104_BOAT, FLAG_HIDE_DEWFORD_BOAT, FLAG_HIDE_ROUTE109_BOAT = 0x2E6, 0x2E7, 0x2E8
local FLAG_HIDE_HOUSE_PEEKO = 0x371
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
  local a=F.sb1()+S.SaveBlock1.flags+id//8
  return a,1<<(id%8)
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
        if c==want then
          F.shot(tag)
          for _=1,4 do
            F.press("A",2)
            for _=1,30 do
              if not scriptMenuActive() then F.idle(30);return true end
              F.idle(1)
            end
          end
          return false
        end
        F.press(c>want and "Up" or "Down",2);F.idle(12)
      end
      return false
    end
    F.press("A",2);F.idle(25)
  end
  F.shot(tag.."_nomenu")
  return false
end
local function awaitAny(candidates,tag)
  for _=1,220 do
    for i,c in ipairs(candidates) do
      if mapIs(c[1] or c.g,c[2] or c.m) then F.idle(100);return i end
    end
    if F.reportCrash(tag) then return nil end
    F.press("A",2);F.idle(14)
  end
  F.shot(tag.."_failed")
  return nil
end
local function debugParty()
  F.dbg();F.idle(40);F.sel(2);F.idle(40)
  for _=1,9 do F.press("Down",3);F.idle(16) end
  F.press("A",3);F.idle(180)
  drain()
  return count()==1
end
local function passToHub(tag)
  for attempt=1,3 do
    drain()
    F.w16(F.sb1()+S.SaveBlock1.registeredItem,hubPass)
    F.press("Select",2);F.idle(90)
    if menu(0,tag.."_confirm"..attempt) then return awaitAny({HUB},tag)~=nil end
  end
  return false
end
-- Keep-current team, then arrival 0 (resume) or 1 (standard).
local function crossHoenn(arrival,dests,tag)
  if not F.route({{16,4},{HOENN_ATTENDANT,4},{HOENN_ATTENDANT,3}},tag.."_walk") then return false end
  F.face("Up");F.press("A",3);F.idle(60)
  if not menu(1,tag.."_team") then return false end
  if not menu(arrival,tag.."_arrival") then return false end
  if not menu(0,tag.."_confirm") then return false end
  return awaitAny(dests,tag)
end

-- The hide flags EventScript_MoveMrBriney* write for each dock (data/event_scripts.s).
local DOCKS = {
  house = {show={FLAG_HIDE_ROUTE104_BOAT,FLAG_HIDE_HOUSE_BRINEY,FLAG_HIDE_HOUSE_PEEKO},
           hide={FLAG_HIDE_DEWFORD_BRINEY,FLAG_HIDE_DEWFORD_BOAT,FLAG_HIDE_ROUTE109_BRINEY,FLAG_HIDE_ROUTE109_BOAT}},
  dewford = {show={FLAG_HIDE_DEWFORD_BRINEY,FLAG_HIDE_DEWFORD_BOAT},
             hide={FLAG_HIDE_ROUTE109_BRINEY,FLAG_HIDE_ROUTE109_BOAT,FLAG_HIDE_ROUTE104_BRINEY,FLAG_HIDE_ROUTE104_BOAT,FLAG_HIDE_HOUSE_BRINEY,FLAG_HIDE_HOUSE_PEEKO}},
  route109 = {show={FLAG_HIDE_ROUTE109_BRINEY,FLAG_HIDE_ROUTE109_BOAT},
              hide={FLAG_HIDE_ROUTE104_BRINEY,FLAG_HIDE_ROUTE104_BOAT,FLAG_HIDE_HOUSE_BRINEY,FLAG_HIDE_HOUSE_PEEKO,FLAG_HIDE_DEWFORD_BRINEY,FLAG_HIDE_DEWFORD_BOAT}},
}
local function dock(name)
  for _,id in ipairs(DOCKS[name].show) do flag(id,false) end
  for _,id in ipairs(DOCKS[name].hide) do flag(id,true) end
end
local function dockedAt(name)
  for _,id in ipairs(DOCKS[name].show) do if flagGet(id) then return false end end
  for _,id in ipairs(DOCKS[name].hide) do if not flagGet(id) then return false end end
  return true
end
local function brineyState()
  local at="nowhere"
  for name in pairs(DOCKS) do if dockedAt(name) then at=name end end
  return string.format("docked=%s var=%d",at,varGet(VAR_BRINEY_LOCATION))
end


local function setup(dockName,location,center,slateport)
  dock(dockName);var(VAR_BRINEY_LOCATION,location)
  flag(FLAG_VISITED_SLATEPORT,slateport);flag(FLAG_VISITED_DEWFORD,slateport)
  F.w16(centerAddress(HOENN),center)
end

F.run(function()
  if not F.boot(HUB[1]) then F.check("fresh boot",false);F.finish();return end
  flag(0xDCF,true)
  flag(0x51,true)
  flag(FLAG_HOENN_STONE_BADGE,true)
  flag(FLAG_RECEIVED_POKENAV,true)
  flag(FLAG_SYS_POKEMON_GET,true)
  flag(FLAG_DEFEATED_PETALBURG_GYM,false)
  F.w8(F.sb2()+S.SaveBlock2.introDoneBits,7)
  F.check("debug prerequisite creates one Pokemon",debugParty())

  -- Roxanne beaten and Devon's errand taken: Briney waits at his house for the first voyage.
  setup("house",1,0,false)
  F.check("Rusturf Tunnel is still closed",not flagGet(FLAG_RUSTURF_TUNNEL_OPENED))
  F.check("no Dynamo Badge, so Rock Smash is locked",not flagGet(FLAG_HOENN_DYNAMO_BADGE))
  local seen={}
  for _,id in ipairs(select(2,F.keyItemSlot(0xFFFF))) do seen[id]=true end
  local first=crossHoenn(1,{LITTLEROOT_BEDROOMS[1],LITTLEROOT_BEDROOMS[2],SLATEPORT_HARBOR},"before_voyage")
  for _,id in ipairs(select(2,F.keyItemSlot(0xFFFF))) do if not seen[id] then hubPass=id end end
  F.check("first trip supplies a Hub Pass",hubPass~=nil)
  if not first or not hubPass then F.check("standard arrival lands",false,where());F.finish();return end
  F.check("before Briney's first voyage the standard arrival lands at home, west of Rusturf Tunnel",
    first<=2,where())
  F.check("Briney still waits at his house for the first voyage",dockedAt("house"),brineyState())

  -- He sailed the player to Dewford and on to Slateport, then home again from Dewford.
  F.check("Hub Pass back after the first arrival",passToHub("out_first"))
  setup("house",1,0,true)
  local harbor=crossHoenn(1,{SLATEPORT_HARBOR},"standard_after_voyage")
  F.check("after Slateport is reached the standard arrival lands at Slateport Harbor",harbor~=nil,where())
  if harbor then
    F.check("Slateport Harbor arrival docks Briney at Route 109",dockedAt("route109"),brineyState())
    F.check("the Littleroot respawn still returns Briney to his house",
      varGet(VAR_BRINEY_LOCATION)==1,brineyState())
  end

  F.check("Hub Pass back after the harbor",passToHub("out_harbor"))
  setup("house",1,SLATEPORT_CENTER.id,true)
  local center=crossHoenn(0,{SLATEPORT_CENTER},"resume_slateport")
  F.check("Slateport Center resume lands in that Center",center~=nil,where())
  if center then
    F.check("Slateport Center resume docks Briney at Route 109",dockedAt("route109"),brineyState())
    F.check("Slateport Center resume returns Briney to Route 109",varGet(VAR_BRINEY_LOCATION)==3,brineyState())
  end

  -- Briney sailed the player to Dewford before Steven's letter, so Slateport is not reached yet.
  F.check("Hub Pass back after Slateport",passToHub("out_slateport"))
  setup("dewford",2,0,false)
  flag(FLAG_VISITED_DEWFORD,true)
  local home=crossHoenn(1,{LITTLEROOT_BEDROOMS[1],LITTLEROOT_BEDROOMS[2],SLATEPORT_HARBOR},"standard_from_dewford")
  F.check("before Slateport is reached a Dewford visit still arrives at home",home~=nil and home<=2,where())
  F.check("the home arrival docks Briney at Route 104",dockedAt("house"),brineyState())
  F.check("no crash",not F.crashScreen())
  F.finish()
end)
