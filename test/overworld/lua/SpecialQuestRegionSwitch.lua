-- The Vermilion Fan Club's Squad Squirtle task must survive a Hub Pass and two region switches
-- in the middle, and pay out exactly one Squad Squirtle per accepted gift.
--
-- With real input: cross to Kanto, start the task with the organizer, find the first Squirtle,
-- Hub Pass to the hub, cross to Johto, Hub Pass back, cross to Kanto, find the second Squirtle,
-- then collect the gift and decline the repeat offer. Setup writes travel flags and uses the debug
-- party; the quest flags only ever come from the NPC scripts.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/SpecialQuestRegionSwitch.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SpecialQuestRegionSwitch")

local HUB = {100, 0}
local KANTO, JOHTO, HOENN = 1, 2, 3
local gates = {
  {attendant=11, standardG=37, standardM=5},
  {attendant=16, standardG=84, standardM=23},
  {attendant=21, standardG=9, standardM=9},
}
local VERMILION, FAN_CLUB = {37, 5}, {43, 3}
local LOCALID_ORGANIZER, LOCALID_SQUAD_ONE, LOCALID_SQUAD_TWO = 7, 9, 10
local FLAG_STARTED, FLAG_ONE, FLAG_TWO = 0xDE4, 0xDE5, 0xDE6
local FLAG_UNLOCKED, FLAG_COLLECTED = 0xDDD, 0xDD3
local SPECIES_SQUIRTLE_SQUAD = 1576
local BOX_SLOTS, BOX_MON = 14 * 30, S.BoxPokemon.size
local hubPass

local function where() local x,y=F.pos(); return string.format("%d/%d (%d,%d)",F.grp(),F.mapn(),x,y) end
local function mapIs(m) return F.grp()==m[1] and F.mapn()==m[2] end
local function flag(id,value)
  local base,offset
  if id>=0x6000 and id<0x6400 then base=F.sb3()+S.SaveBlock3.johtoFlags;offset=id-0x6000
  else base=F.sb1()+S.SaveBlock1.flags;offset=id end
  local a,bit=base+offset//8,1<<(offset%8)
  if value~=nil then F.w8(a,value and (F.r8(a)|bit) or (F.r8(a)&(~bit&255))) end
  return (F.r8(a)&bit)~=0
end
local function region() return F.r8(S.gCurrentRegion) end
local function questFlags()
  return string.format("started=%s one=%s two=%s unlocked=%s collected=%s",tostring(flag(FLAG_STARTED)),
    tostring(flag(FLAG_ONE)),tostring(flag(FLAG_TWO)),tostring(flag(FLAG_UNLOCKED)),tostring(flag(FLAG_COLLECTED)))
end

local GROWTH_SLOT = { [0]=0,0,0,0,0,0,1,1,2,3,2,3,1,1,2,3,2,3,1,1,2,3,2,3 }
local function speciesAt(mon)
  if (F.r8(mon+19)&2)==0 then return 0 end
  local key=F.r32(mon)~F.r32(mon+4)
  return (F.r16(mon+32+GROWTH_SLOT[F.r32(mon)%24]*12)~(key&0xFFFF))&0x7FF
end
local function squads()
  local n=0
  for i=0,F.r8(S.gPartiesCount)-1 do if speciesAt(S.gParties+i*S.Pokemon.size)==SPECIES_SQUIRTLE_SQUAD then n=n+1 end end
  local box=F.r32(S.gPokemonStoragePtr)+4
  for i=0,BOX_SLOTS-1 do if speciesAt(box+i*BOX_MON)==SPECIES_SQUIRTLE_SQUAD then n=n+1 end end
  return n
end

local function scriptIdle() return F.ow() and F.r8(S.sGlobalScriptContextStatus)==2 end
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
local function awaitMap(m,tag)
  for _=1,220 do
    if mapIs(m) then F.idle(100);return true end
    if F.reportCrash(tag) then return false end
    F.press("A",2);F.idle(14)
  end
  F.shot(tag.."_failed")
  return false
end
local function debugParty()
  F.dbg();F.idle(40);F.sel(2);F.idle(40)
  for _=1,9 do F.press("Down",3);F.idle(16) end
  F.press("A",3);F.idle(180)
  drain()
  return F.r8(S.gPartiesCount)==1
end
local function cross(r,tag)
  local x=gates[r].attendant
  if not F.route({{16,4},{x,4},{x,3}},tag.."_walk") then return false end
  F.face("Up");F.press("A",3);F.idle(60)
  if not menu(1,tag.."_team") then return false end
  if not menu(1,tag.."_arrival") then return false end
  if not menu(0,tag.."_confirm") then return false end
  return awaitMap({gates[r].standardG,gates[r].standardM},tag)
end
local function passToHub(tag)
  for attempt=1,3 do
    drain()
    F.w16(F.sb1()+S.SaveBlock1.registeredItem,hubPass)
    F.press("Select",2);F.idle(90)
    if menu(0,tag.."_confirm"..attempt) then return awaitMap(HUB,tag) end
  end
  return false
end

-- Talks to an object and drives its script to the end with B, answering a Yes/No with `answer`.
local function talkTo(dir,tag,answer)
  F.face(dir);F.press("A",2);F.idle(20)
  if scriptIdle() then return false end
  for n=1,400 do
    if F.reportCrash(tag) then return false end
    if answer~=nil and scriptMenuActive() then
      F.idle(12);F.shot(tag.."_offer")
      F.press(answer and "A" or "B",2);F.idle(40);answer=nil
    elseif scriptIdle() and n>3 then
      return true
    else
      F.press("B",2);F.idle(20)
    end
  end
  F.shot(tag.."_stuck")
  return false
end

local function objectAt(localId)
  for i=0,15 do
    local b=S.gObjectEvents+i*S.ObjectEvent.stride
    if (F.r8(b)&1)~=0 and F.r8(b+S.ObjectEvent.localId)==localId then
      return F.rs16(b+S.ObjectEvent.x)-7,F.rs16(b+S.ObjectEvent.y)-7
    end
  end
end
-- The two Squirtle wander, so chase the live position and talk once standing next to one.
local function talkWanderer(localId,flagId,tag)
  local sides={{0,-1,"Down"},{0,1,"Up"},{-1,0,"Right"},{1,0,"Left"}}
  for attempt=1,12 do
    local ox,oy=objectAt(localId)
    if not ox then return false end
    local side=sides[(attempt-1)%4+1]
    F.leg(ox+side[1],oy+side[2])
    local px,py=F.pos()
    ox,oy=objectAt(localId)
    local dx,dy=ox-px,oy-py
    if math.abs(dx)+math.abs(dy)==1 then
      local dir=dx==1 and "Right" or dx==-1 and "Left" or dy==1 and "Down" or "Up"
      if talkTo(dir,tag) and flag(flagId) then return true end
    end
  end
  F.shot(tag.."_chase_failed")
  return false
end

-- From the Kanto arrival tile around the harbor water to the Fan Club door, on row 18 to stay
-- clear of the second Squirtle's wander box.
local TO_FAN_CLUB = {{24,32},{24,30},{35,30},{35,24},{34,24},{34,20},{33,20},{33,18},{12,18}}
local function enterFanClub(tag)
  local x,y=F.pos()
  local path=(y>=24) and TO_FAN_CLUB or {{x,18},{12,18}}
  if not F.route(path,tag.."_walk") then return false end
  for _=1,3 do
    if mapIs(FAN_CLUB) then break end
    F.press("Up",8);F.idle(80)
  end
  F.idle(60)
  return mapIs(FAN_CLUB) and F.route({{5,9},{9,9},{9,8}},tag.."_organizer")
end
local function leaveFanClub(tag)
  if not F.route({{9,9},{5,9},{5,10}},tag.."_door") then return false end
  for _=1,3 do
    if mapIs(VERMILION) then break end
    F.press("Down",8);F.idle(80)
  end
  F.idle(60)
  return mapIs(VERMILION) and drain()
end

local function setup()
  if not F.boot(HUB[1]) then return false end
  flag(0xDCF,true)
  flag(0x51,true)
  flag(0xA4B,true)
  flag(0x63F8,true)
  flag(0x63F9,true) -- the Hive Badge: the Cut gift counts as past Ilex only with it
  F.w16(F.sb3()+S.SaveBlock3.regionVars+0x8C*2,7) -- VAR_AZALEA_TOWN_STATE: past Ilex, so Johto arrives at Goldenrod
  flag(0x94F,true)
  flag(0x95F,true) -- visited Slateport, so the standard Hoenn arrival is its harbor
  F.w8(F.sb2()+S.SaveBlock2.introDoneBits,7)
  if not debugParty() then return false end
  local seen={}
  for _,id in ipairs(select(2,F.keyItemSlot(0xFFFF))) do seen[id]=true end
  if not cross(KANTO,"first_kanto") then return false end
  for _,id in ipairs(select(2,F.keyItemSlot(0xFFFF))) do if not seen[id] then hubPass=id end end
  return hubPass~=nil
end

F.run(function()
  local ok=setup()
  F.check("setup reaches Vermilion with a Hub Pass and one Pokemon",ok and mapIs(VERMILION),where())
  if not ok then F.finish();return end
  drain()

  F.check("walk into the Fan Club to the organizer",enterFanClub("in1"),where())
  F.check("organizer starts the task",talkTo("Up","start") and flag(FLAG_STARTED) and not flag(FLAG_ONE),questFlags())
  F.check("back out to Vermilion",leaveFanClub("out1"),where())
  F.check("first Squirtle found",talkWanderer(LOCALID_SQUAD_ONE,FLAG_ONE,"squad_one"),questFlags())

  F.check("Hub Pass to the hub mid-task",passToHub("pass1"),where())
  F.check("cross to Johto",cross(JOHTO,"johto") and region()==JOHTO,where().." region="..region())
  F.check("Johto keeps the task state",flag(FLAG_STARTED) and flag(FLAG_ONE) and not flag(FLAG_TWO) and not flag(FLAG_UNLOCKED),questFlags())
  drain()
  F.check("Hub Pass back from Johto",passToHub("pass2"),where())
  F.check("cross back to Kanto",cross(KANTO,"kanto") and region()==KANTO,where().." region="..region())
  F.check("Kanto keeps the task state",flag(FLAG_STARTED) and flag(FLAG_ONE) and not flag(FLAG_TWO) and not flag(FLAG_UNLOCKED),questFlags())
  drain()

  F.check("walk from the arrival to the Squirtle",F.route({table.unpack(TO_FAN_CLUB,1,#TO_FAN_CLUB-1)},"to_squad_two")
    and F.route({{16,18}},"to_squad_two_row"),where())
  F.check("second Squirtle found after the switch",talkWanderer(LOCALID_SQUAD_TWO,FLAG_TWO,"squad_two"),questFlags())
  local before,party=squads(),F.r8(S.gPartiesCount)
  F.check("walk back to the organizer",enterFanClub("in2"),where())
  F.check("organizer gives Squad Squirtle",talkTo("Up","gift",true) and flag(FLAG_UNLOCKED) and flag(FLAG_COLLECTED),questFlags())
  F.check("exactly one Squad Squirtle arrives",squads()==before+1 and F.r8(S.gPartiesCount)==party+1,
    string.format("squads %d -> %d, party %d -> %d",before,squads(),party,F.r8(S.gPartiesCount)))
  F.check("declining the repeat offer gives nothing",talkTo("Up","decline",false) and squads()==before+1,
    string.format("squads=%d",squads()))
  F.shot("done")
  F.finish()
end)
