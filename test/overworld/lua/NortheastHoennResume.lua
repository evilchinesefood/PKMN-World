-- Fortree and Lilycove sit on the land block north and east of Route 118. Its only land link,
-- Route 118, is cut by water, so leaving that block needs Surf or Fly. Resuming at either Center
-- with a party that can do neither strands the player there (only the Center PC or another Hub
-- Pass gets them out), so the gate must fall back to the standard arrival. A party that can Surf,
-- or Fly after the Feather Badge, still resumes there.
-- Setup writes badges, the remembered Center and the carried Pokemon's species and moves. The
-- gate's team, arrival and confirm choices and the Hub Pass use real input.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "NortheastHoennResume")

local HUB = {100, 0}
local HOENN, HOENN_ATTENDANT = 3, 21
local SLATEPORT_HARBOR = {9, 9}
local FORTREE = {id=5, g=12, m=2, name="Fortree"}
local LILYCOVE = {id=6, g=13, m=6, name="Lilycove"}
local FLAG_BADGE01_GET = 0x94F
local SPECIES_CHARIZARD, SPECIES_SQUIRTLE, SPECIES_CATERPIE = 6, 7, 10
local MOVE_FLY, MOVE_TACKLE, MOVE_SURF = 19, 33, 57
local hubPass
local function where() local x,y=F.pos(); return string.format("%d/%d (%d,%d)",F.grp(),F.mapn(),x,y) end
local function mapIs(g,m) return F.grp()==g and F.mapn()==m end
local function travelBank() return F.sb3()+S.SaveBlock3.regionalTravel end
local function centerAddress(region) return travelBank()+160+(region-1)*2 end
local function count() return F.r8(S.gPartiesCount) end
local function party(slot) return S.gParties+(slot or 0)*S.Pokemon.size end
local function flag(id,value)
  local a=F.sb1()+S.SaveBlock1.flags+id//8
  local bit=1<<(id%8)
  F.w8(a,value and (F.r8(a)|bit) or (F.r8(a)&(~bit&255)))
end
local function order(p)
  local o={}
  for i=0,3 do o[i]=F.r8(S.sSubstructOffsets+i*24+p%24)*3 end
  return o
end
-- One known move, no other moves, and the given species.
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
-- Waits until the player stands on one of the candidate maps; returns its index.
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
-- Keep-current team, then arrival 0 (resume) or 1 (standard). Returns the landing map index:
-- 1 for the remembered Center, 2 for Slateport Harbor.
local function crossHoenn(arrival,center,tag)
  if not F.route({{16,4},{HOENN_ATTENDANT,4},{HOENN_ATTENDANT,3}},tag.."_walk") then return nil end
  F.face("Up");F.press("A",3);F.idle(60)
  if not menu(1,tag.."_team") then return nil end
  if not menu(arrival,tag.."_arrival") then return nil end
  if not menu(0,tag.."_confirm") then return nil end
  return awaitAny({center or SLATEPORT_HARBOR,SLATEPORT_HARBOR},tag)
end

local function resume(center,species,move,expectCenter,tag)
  if not mapIs(HUB[1],HUB[2]) and not passToHub(tag.."_out") then
    F.check(tag..": Hub Pass back to the hub",false,where());return
  end
  setSpeciesMove(party(),species,move)
  F.w16(centerAddress(HOENN),center.id)
  local landed=crossHoenn(0,center,tag)
  local want=expectCenter and 1 or 2
  F.check(tag..(expectCenter and ": resumes at the "..center.name.." Center" or ": falls back to Slateport Harbor"),
    landed==want,where())
  F.check(tag..": keeps the remembered Center",F.r16(centerAddress(HOENN))==center.id)
end

F.run(function()
  if not F.boot(HUB[1]) then F.check("fresh boot",false);F.finish();return end
  flag(0xDCF,true)
  flag(0x51,true)
  F.w8(F.sb2()+S.SaveBlock2.introDoneBits,7)
  for badge=0,4 do flag(FLAG_BADGE01_GET+badge,true) end
  F.check("debug prerequisite creates one Pokemon",debugParty())
  local seen={}
  for _,id in ipairs(select(2,F.keyItemSlot(0xFFFF))) do seen[id]=true end
  F.check("first Hoenn trip reaches Slateport Harbor",crossHoenn(1,nil,"first")~=nil,where())
  for _,id in ipairs(select(2,F.keyItemSlot(0xFFFF))) do if not seen[id] then hubPass=id end end
  F.check("first trip supplies a Hub Pass",hubPass~=nil)
  if not hubPass then F.finish();return end

  -- Balance Badge, no Feather Badge: Surf is the only way off the block.
  resume(FORTREE,SPECIES_CATERPIE,MOVE_TACKLE,false,"fortree_no_surf")
  resume(LILYCOVE,SPECIES_CATERPIE,MOVE_TACKLE,false,"lilycove_no_surf")
  resume(FORTREE,SPECIES_SQUIRTLE,MOVE_SURF,true,"fortree_surf")
  resume(LILYCOVE,SPECIES_SQUIRTLE,MOVE_SURF,true,"lilycove_surf")
  -- Without the Feather Badge, a Fly user cannot fly out.
  resume(LILYCOVE,SPECIES_CHARIZARD,MOVE_FLY,false,"lilycove_fly_without_badge")
  flag(FLAG_BADGE01_GET+5,true)
  resume(LILYCOVE,SPECIES_CHARIZARD,MOVE_FLY,true,"lilycove_fly_with_badge")
  resume(FORTREE,SPECIES_CATERPIE,MOVE_TACKLE,false,"fortree_no_surf_after_feather")
  F.finish()
end)
