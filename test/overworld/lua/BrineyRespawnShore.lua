-- Before Surf, Mr. Briney's boat is the only link between the west mainland (Littleroot, Petalburg,
-- Rustboro, Route 104), Dewford and Route 109 (Slateport). A whiteout or Teleport moves him to
-- VAR_BRINEY_LOCATION, which vanilla records at every Center visit, so he always returns to the
-- shore of the respawn point. The World Transit gate sets the respawn without a Center visit, so
-- the gate must dock him on the shore the player lands on and record a return point on the
-- respawn's shore. Otherwise the player is cut off from his boat until Rusturf Tunnel opens.
-- Setup writes badges, Briney's dock, the remembered Center and the carried Pokemon's species and
-- move, and stands in for Briney's voyage by rewriting his dock flags and debug-warping to Dewford.
-- The gate's team, arrival and confirm choices, the Hub Pass and Teleport use real input.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BrineyRespawnShore")

local HUB = {100, 0}
local HOENN, HOENN_ATTENDANT = 3, 21
local SLATEPORT_HARBOR = {9, 9}
local PETALBURG_CENTER = {id=1, g=8, m=4}
local DEWFORD_TOWN = {0, 11}
local LITTLEROOT_HOUSES = {{1, 0}, {1, 2}, {0, 9}}
local SPECIES_ABRA, MOVE_TELEPORT = 63, 100
local FLAG_RECEIVED_POKENAV = 0xBC
local FLAG_SYS_POKEMON_GET = 0x948
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
local function order(p)
  local o={}
  for i=0,3 do o[i]=F.r8(S.sSubstructOffsets+i*24+p%24)*3 end
  return o
end
local function setSpeciesMove(address,species,move)
  local key=F.r32(address)~F.r32(address+4)
  local w={}
  for i=0,11 do w[i]=F.r32(address+32+i*4)~key end
  local o=order(F.r32(address))
  w[o[0]]=(w[o[0]]&0xFFFFF800)|species
  w[o[1]]=(w[o[1]]&0xF800F800)|move
  w[o[1]+1]=w[o[1]+1]&0xF800F800
  local checksum=0
  for i=0,11 do
    checksum=(checksum+(w[i]&65535)+(w[i]>>16))&65535
    F.w32(address+32+i*4,w[i]~key)
  end
  F.w16(address+28,checksum)
end

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
local function crossHoenn(arrival,dest,tag)
  if not F.route({{16,4},{HOENN_ATTENDANT,4},{HOENN_ATTENDANT,3}},tag.."_walk") then return false end
  F.face("Up");F.press("A",3);F.idle(60)
  if not menu(1,tag.."_team") then return false end
  if not menu(arrival,tag.."_arrival") then return false end
  if not menu(0,tag.."_confirm") then return false end
  return awaitAny({dest},tag)~=nil
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

local function inPartyMenu()
  local c=F.cb2()
  return c==S.CB2_UpdatePartyMenu or c==S.CB2_InitPartyMenu or c==S.CB2_PartyMenuFromStartMenu
end
local function openParty()
  for _=1,4 do
    F.press("Start",2);F.idle(90)
    if F.selectStartIcon(1) then
      F.press("A",3)
      for _=1,240 do F.idle(4);if inPartyMenu() then F.idle(40);return true end end
    end
    for _=1,6 do F.press("B",3);F.idle(20) end
  end
  return false
end
-- A on slot 0, Down onto TELEPORT (row 1), then YES through the confirmation.
local function teleport(tag)
  if not openParty() then F.shot(tag.."_noparty");return nil end
  F.press("A",3);F.idle(50)
  F.press("Down",2);F.idle(12)
  F.shot(tag.."_row")
  F.press("A",3);F.idle(40)
  for _=1,40 do
    F.press("Up",2);F.idle(6)
    F.press("A",2);F.idle(16)
    if not inPartyMenu() then break end
  end
  return awaitAny(LITTLEROOT_HOUSES,tag)
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
  setSpeciesMove(S.gParties,SPECIES_ABRA,MOVE_TELEPORT)

  -- A Hub Pass used on Dewford left Briney docked there; he last saw a Center from Dewford.
  dock("dewford");var(VAR_BRINEY_LOCATION,2)
  F.w16(centerAddress(HOENN),0)
  local seen={}
  for _,id in ipairs(select(2,F.keyItemSlot(0xFFFF))) do seen[id]=true end
  local standard=crossHoenn(1,SLATEPORT_HARBOR,"standard")
  F.check("standard Hoenn arrival reaches Slateport Harbor",standard,where())
  for _,id in ipairs(select(2,F.keyItemSlot(0xFFFF))) do if not seen[id] then hubPass=id end end
  F.check("first trip supplies a Hub Pass",hubPass~=nil)
  if not standard or not hubPass then F.finish();return end
  F.check("standard arrival docks Briney at Route 109, beside Slateport",dockedAt("route109"),brineyState())
  F.check("standard arrival returns Briney to his house on a Littleroot respawn",
    varGet(VAR_BRINEY_LOCATION)==1,brineyState())

  -- Briney sails the player from Route 109 to Dewford. The voyage keeps VAR_BRINEY_LOCATION.
  dock("dewford")
  if not F.warpTo(0,0,0,0,1,1,0,0,0,DEWFORD_TOWN[1],DEWFORD_TOWN[2],"dewford") then
    F.check("debug warp to Dewford",false,where());F.finish();return
  end
  drain()
  local landed=teleport("teleport_dewford")
  F.check("Teleport from Dewford lands at the Littleroot respawn",landed~=nil,where())
  F.check("after Teleport Briney's boat waits at Route 104, a walk from Littleroot",
    dockedAt("house"),brineyState())

  -- He last saw a Center from Petalburg, then sailed the player to Dewford. Resuming at Petalburg
  -- must bring him back to Route 104, not Route 109 across the uncut Rusturf Tunnel.
  F.check("Hub Pass back to the hub",passToHub("out_littleroot"))
  dock("dewford");var(VAR_BRINEY_LOCATION,1)
  F.w16(centerAddress(HOENN),PETALBURG_CENTER.id)
  local west=crossHoenn(0,PETALBURG_CENTER,"resume_petalburg")
  F.check("Petalburg Center resume lands in that Center",west,where())
  if west then
    F.check("Petalburg resume docks Briney at Route 104",dockedAt("house"),brineyState())
    F.check("Petalburg resume returns Briney to Route 104",varGet(VAR_BRINEY_LOCATION)==1,brineyState())
  end
  F.check("no crash",not F.crashScreen())
  F.finish()
end)
