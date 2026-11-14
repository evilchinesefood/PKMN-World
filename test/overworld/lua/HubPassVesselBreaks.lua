-- Hub Pass used aboard a ship whose story scene finishes on the way off it.
-- S.S. Anne: after the captain teaches Cut, the departure scene plays when the player steps onto
-- the dock. A Hub Pass from inside the ship skips that walk, so the scene must still play, and
-- release the player, when they come back through the Vermilion ticket check from the town side.
-- S.S. Aqua: a Hub Pass mid maiden voyage leaves the voyage state partway; the Olivine sailor
-- must offer the voyage again and the ship must still reach Vermilion.
-- Setup writes flags, vars and a debug Pokemon and uses debug warps to the ports. Gate travel,
-- the Hub Pass, the ticket check walk and the ferry conversations use real input.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "HubPassVesselBreaks")

local HUB = {100, 0}
local KANTO, JOHTO, HOENN = 1, 2, 3
local gates = {
  {attendant=11, standardG=37, standardM=5},
  {attendant=16, standardG=84, standardM=23},
  {attendant=21, standardG=9, standardM=9},
}
local VERMILION = {37, 5}
local SS_ANNE_EXTERIOR, SS_ANNE_CORRIDOR = {35, 4}, {35, 5}
local OLIVINE_PORT, SS_AQUA, VERMILION_PORT = {88, 8}, {95, 0}, {43, 8}
local VAR_MAP_SCENE_VERMILION_CITY = 0xA057
local FLAG_GOT_SS_TICKET = 0xA40 + 0x234
local VAR_NEWBARKTOWN_LABSTATE, VAR_SSAQUA_STATE = 0xA081, 0xA0A8
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
local function debugWarp(g,m,tag)
  local function digits(n) return n//100,(n//10)%10,n%10 end
  local gh,gt,go=digits(g);local mh,mt,mo=digits(m)
  return F.warpTo(gh,gt,go,mh,mt,mo,0,0,0,g,m,tag)
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

local function setup()
  if not F.boot(HUB[1]) then return false end
  flag(0xDCF,true)
  flag(0x51,true)
  flag(0xA4B,true)
  flag(0x63F8,true)
  F.w16(F.sb3()+S.SaveBlock3.regionVars+0x8C*2,7) -- VAR_AZALEA_TOWN_STATE: past Ilex, so Johto arrives at Goldenrod
  flag(0x94F,true)
  F.w8(F.sb2()+S.SaveBlock2.introDoneBits,7)
  if not debugParty() then return false end
  local seen={}
  for _,id in ipairs(select(2,F.keyItemSlot(0xFFFF))) do seen[id]=true end
  if not cross(HOENN,"first_keep") then return false end
  for _,id in ipairs(select(2,F.keyItemSlot(0xFFFF))) do if not seen[id] then hubPass=id end end
  return hubPass~=nil and giveTicket()
end

local function ssAnne()
  F.check("Hub Pass to the hub before Kanto",passToHub("anne_out"))
  F.check("Kanto arrival in Vermilion",cross(KANTO,"anne_in"),where())
  var(VAR_MAP_SCENE_VERMILION_CITY,1)
  flag(FLAG_GOT_SS_TICKET,true)
  F.check("S.S. Anne corridor after the captain's Cut",debugWarp(SS_ANNE_CORRIDOR[1],SS_ANNE_CORRIDOR[2],"anne_corridor"))
  drain()
  F.check("Hub Pass works aboard the S.S. Anne",passToHub("anne_pass"),where())
  F.check("departure scene is still pending",getVar(VAR_MAP_SCENE_VERMILION_CITY)==1,"var="..getVar(VAR_MAP_SCENE_VERMILION_CITY))
  F.check("Kanto return lands north of the ticket check",cross(KANTO,"anne_back"),where())
  local x,y=F.pos()
  F.check("return arrival tile",x==22 and y==32,where())
  local walked=F.step("Down")
  F.check("ticket check admits the ticket holder",walked,where())
  if walked then F.idle(60);drain() end
  for _=1,3 do
    if mapIs(SS_ANNE_EXTERIOR[1],SS_ANNE_EXTERIOR[2]) then break end
    F.press("Down",8);F.idle(40)
  end
  F.check("walk onto the S.S. Anne dock",mapIs(SS_ANNE_EXTERIOR[1],SS_ANNE_EXTERIOR[2]) or getVar(VAR_MAP_SCENE_VERMILION_CITY)>=2,where())
  local released=false
  for _=1,120 do
    if F.reportCrash("anne_scene") then break end
    if getVar(VAR_MAP_SCENE_VERMILION_CITY)==3 and mapIs(VERMILION[1],VERMILION[2]) and awaitControl("anne_release",200) then released=true;break end
    F.idle(30)
  end
  F.shot("anne_after_scene")
  F.check("departure scene plays and returns the player to Vermilion",released,where().." var="..getVar(VAR_MAP_SCENE_VERMILION_CITY))
  F.check("player can walk after the departure scene",released and (F.step("Up") or F.step("Left") or F.step("Right")),where())
end

local function ssAqua()
  drain()
  F.check("Hub Pass to the hub before Johto",passToHub("aqua_out"))
  flag(0x600F,true)
  var(VAR_NEWBARKTOWN_LABSTATE,11)
  var(VAR_SSAQUA_STATE,0)
  F.check("Johto arrival",cross(JOHTO,"aqua_in"),where())
  F.check("Olivine port",debugWarp(OLIVINE_PORT[1],OLIVINE_PORT[2],"aqua_port"))
  F.check("walk to the boarding sailor",F.route({{8,16}},"aqua_sailor"))
  F.face("Down");F.press("A",2);F.idle(60)
  F.check("accept the maiden voyage",menu(0,"aqua_accept"))
  F.check("maiden voyage boards the S.S. Aqua",awaitMap(SS_AQUA[1],SS_AQUA[2],"aqua_board"),where())
  drain()
  var(VAR_SSAQUA_STATE,3)
  F.check("Hub Pass works mid voyage",passToHub("aqua_pass"),where())
  F.check("voyage state is left partway",getVar(VAR_SSAQUA_STATE)==3,"state="..getVar(VAR_SSAQUA_STATE))
  F.check("Johto return",cross(JOHTO,"aqua_back"),where())
  F.check("Olivine port again",debugWarp(OLIVINE_PORT[1],OLIVINE_PORT[2],"aqua_port2"))
  F.check("walk to the boarding sailor again",F.route({{8,16}},"aqua_sailor2"))
  F.face("Down");F.press("A",2);F.idle(60)
  F.check("the sailor offers the maiden voyage again",menu(0,"aqua_accept2"))
  F.check("second boarding reaches the S.S. Aqua",awaitMap(SS_AQUA[1],SS_AQUA[2],"aqua_board2"),where())
  F.check("voyage restarts from the beginning",getVar(VAR_SSAQUA_STATE)==1,"state="..getVar(VAR_SSAQUA_STATE))
  drain()
  var(VAR_SSAQUA_STATE,6)
  F.check("approach the exit sailor",F.leg(29,3))
  F.face("Up");F.press("A",2);F.idle(50)
  F.check("the restarted voyage still reaches Vermilion",awaitMap(VERMILION_PORT[1],VERMILION_PORT[2],"aqua_disembark"),where())
end

F.run(function()
  local ok=setup()
  F.check("setup has a Hub Pass, an S.S. Ticket and one Pokemon",ok,where())
  if not ok then F.finish();return end
  ssAnne()
  ssAqua()
  F.finish()
end)
