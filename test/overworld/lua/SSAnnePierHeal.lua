-- Party HP across the Vermilion pier and the S.S. Anne. A damaged party walks the ticket check and
-- the pier, boards the ship, and later walks the pier again into the departure scene. Gate travel,
-- the Hub Pass and every walk use real input; setup writes flags, vars, a debug Pokemon and its HP.
-- No step heals: the only heal on this route is the opt-in 1F Room 6 woman, inherited from FRLG.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SSAnnePierHeal")

local HUB = {100, 0}
local KANTO, HOENN = 1, 3
local gates = {
  {attendant=11, standardG=37, standardM=5},
  {attendant=16, standardG=84, standardM=23},
  {attendant=21, standardG=9, standardM=9},
}
local VERMILION = {37, 5}
local SS_ANNE_EXTERIOR, SS_ANNE_CORRIDOR = {35, 4}, {35, 5}
local VAR_MAP_SCENE_VERMILION_CITY = 0xA057
local FLAG_GOT_SS_TICKET = 0xA40 + 0x234
local hubPass
local function where() local x,y=F.pos(); return string.format("%d/%d (%d,%d)",F.grp(),F.mapn(),x,y) end
local function mapIs(g,m) return F.grp()==g and F.mapn()==m end
local function count() return F.r8(S.gPartiesCount) end
local function flag(id,value)
  local base,offset
  if id>=0x6000 and id<0x6400 then base=F.sb3()+S.SaveBlock3.johtoFlags;offset=id-0x6000
  else base=F.sb1()+S.SaveBlock1.flags;offset=id end
  local a=base+offset//8
  local bit=1<<(offset%8)
  F.w8(a,value and (F.r8(a)|bit) or (F.r8(a)&(~bit&255)))
end
local function varAddr(id)
  if id>=0xA000 then return F.sb3()+S.SaveBlock3.regionVars+(id-0xA000)*2 end
  return F.sb1()+S.SaveBlock1.vars+(id-0x4000)*2
end
local function var(id,value) F.w16(varAddr(id),value) end
local function getVar(id) return F.r16(varAddr(id)) end

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
local function awaitMap(g,m,tag)
  for _=1,220 do
    if mapIs(g,m) then F.idle(100);return true end
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
  return count()==1
end
local function cross(region,tag)
  local x=gates[region].attendant
  if not F.route({{16,4},{x,4},{x,3}},tag.."_walk") then return false end
  F.face("Up");F.press("A",3);F.idle(60)
  if not menu(1,tag.."_team") then return false end
  if not menu(1,tag.."_arrival") then return false end
  if not menu(0,tag.."_confirm") then return false end
  return awaitMap(gates[region].standardG,gates[region].standardM,tag)
end
local function passToHub(tag)
  for attempt=1,3 do
    drain()
    F.w16(F.sb1()+S.SaveBlock1.registeredItem,hubPass)
    F.press("Select",2);F.idle(90)
    if menu(0,tag.."_confirm"..attempt) then return awaitMap(HUB[1],HUB[2],tag) end
  end
  return false
end
local function giveTicket()
  if F.keyItemSlot(727)>=0 then return true end
  local p=S.gBagPockets+4*S.BagPocket.stride
  local base=F.r32(p)
  for i=0,F.r32(p+S.BagPocket.count)-1 do
    if F.r16(base+i*4)==0 then
      F.w16(base+i*4,727)
      F.w16(base+i*4+2,1~(F.r32(F.sb2()+S.SaveBlock2.encryptionKey)&65535))
      return F.keyItemSlot(727)>=0
    end
  end
  return false
end
-- Presses nothing while a script runs; true once the player can walk again.
local function awaitControl(tag,frames)
  for _=1,frames//10 do
    if F.reportCrash(tag) then return false end
    if F.ow() and not scriptMenuActive() and F.r8(S.sLockFieldControls)==0 then return true end
    F.idle(10)
  end
  return false
end

local function hp() return F.r16(S.gParties+S.Pokemon.hp) end
local function maxHp() return F.r16(S.gParties+S.Pokemon.maxHP) end
local function hurt() F.w16(S.gParties+S.Pokemon.hp,1) end

local function setup()
  if not F.boot(HUB[1]) then return false end
  flag(0xDCF,true)
  flag(0x51,true)
  flag(0xA4B,true)
  flag(0x63F8,true)
  flag(0x94F,true)
  F.w8(F.sb2()+S.SaveBlock2.introDoneBits,7)
  if not debugParty() then return false end
  local seen={}
  for _,id in ipairs(select(2,F.keyItemSlot(0xFFFF))) do seen[id]=true end
  if not cross(HOENN,"first_keep") then return false end
  for _,id in ipairs(select(2,F.keyItemSlot(0xFFFF))) do if not seen[id] then hubPass=id end end
  return hubPass~=nil and giveTicket()
end

local function walkPier(tag)
  local walked=F.step("Down")
  if walked then F.idle(60);drain() end
  for _=1,4 do
    if mapIs(SS_ANNE_EXTERIOR[1],SS_ANNE_EXTERIOR[2]) then return true end
    F.press("Down",8);F.idle(40)
  end
  F.shot(tag.."_pier")
  return mapIs(SS_ANNE_EXTERIOR[1],SS_ANNE_EXTERIOR[2])
end

local function boarding()
  F.check("Hub Pass to the hub before Kanto",passToHub("board_out"))
  var(VAR_MAP_SCENE_VERMILION_CITY,0)
  flag(FLAG_GOT_SS_TICKET,true)
  F.check("Kanto arrival in Vermilion",cross(KANTO,"board_in"),where())
  hurt()
  F.check("party hurt before the pier",hp()==1 and maxHp()>1,string.format("hp=%d/%d",hp(),maxHp()))
  F.check("ticket check and pier reach the S.S. Anne dock",walkPier("board"),where())
  F.check("walking the pier does not heal",hp()==1,string.format("hp=%d/%d",hp(),maxHp()))
  for _=1,12 do
    if mapIs(SS_ANNE_CORRIDOR[1],SS_ANNE_CORRIDOR[2]) then break end
    if not F.step("Down") then F.press("Down",8);F.idle(40) end
  end
  F.idle(60);drain()
  F.check("gangway boards the S.S. Anne",mapIs(SS_ANNE_CORRIDOR[1],SS_ANNE_CORRIDOR[2]),where())
  F.check("boarding does not heal",hp()==1,string.format("hp=%d/%d",hp(),maxHp()))
end

local function departure()
  F.check("Hub Pass from the ship",passToHub("depart_out"),where())
  F.check("Hub Pass from the ship does not heal",hp()==1,string.format("hp=%d/%d",hp(),maxHp()))
  var(VAR_MAP_SCENE_VERMILION_CITY,1)
  F.check("Kanto return to Vermilion",cross(KANTO,"depart_in"),where())
  F.check("gate arrival on the pier does not heal",hp()==1,string.format("hp=%d/%d",hp(),maxHp()))
  F.check("pier reaches the dock after the captain's Cut",walkPier("depart") or getVar(VAR_MAP_SCENE_VERMILION_CITY)>=2,where())
  local released=false
  for _=1,120 do
    if F.reportCrash("depart_scene") then break end
    if getVar(VAR_MAP_SCENE_VERMILION_CITY)==3 and mapIs(VERMILION[1],VERMILION[2]) and awaitControl("depart_release",200) then released=true;break end
    F.idle(30)
  end
  F.shot("after_departure")
  F.check("departure scene returns the player to Vermilion",released,where().." var="..getVar(VAR_MAP_SCENE_VERMILION_CITY))
  F.check("departure scene does not heal",hp()==1,string.format("hp=%d/%d",hp(),maxHp()))
end

F.run(function()
  local ok=setup()
  F.check("setup has a Hub Pass, an S.S. Ticket and one Pokemon",ok,where())
  if not ok then F.finish();return end
  boarding()
  departure()
  F.finish()
end)
