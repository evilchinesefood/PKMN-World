-- Johto standard arrival versus the Ilex Forest wall. Goldenrod's station sits north of Ilex
-- Forest's Cut tree and east of Route 36's Sudowoodo. Before the Ilex chain is done, a player
-- landed there cannot walk back to Azalea: Cut needs the Hive Badge and the Ilex gift, Sudowoodo
-- needs the Plain Badge. The gate must send that player home instead. Setup writes badges and
-- Azalea/Ilex/Goldenrod vars; the Hub Pass and gate menus use real input.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "JohtoGoldenrodArrival")

local HUB = {100, 0}
local JOHTO, HOENN = 2, 3
local gates = {
  {attendant=11, standardG=37, standardM=5},
  {attendant=16, standardG=84, standardM=23},
  {attendant=21, standardG=9, standardM=9},
}
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

local NEW_BARK_2F, GOLDENROD_STATION = {76, 4}, {84, 23}
local FLAG_JOHTO_BADGE = function(i) return 0x63F8+i end
local VAR_GOLDENROD_CITY_STATE, VAR_AZALEA_TOWN_STATE, VAR_ILEX_FOREST_FARFETCHD = 0xA083, 0xA08C, 0xA08D

local function setup()
  if not F.boot(HUB[1]) then return false end
  flag(0xDCF,true)
  flag(0x51,true)
  flag(0xA4B,true)
  flag(FLAG_JOHTO_BADGE(0),true)
  flag(0x94F,true)
  flag(0x95F,true) -- FLAG_VISITED_SLATEPORT_CITY: the Hoenn harbor arrival is open
  F.w8(F.sb2()+S.SaveBlock2.introDoneBits,7)
  if not debugParty() then return false end
  local seen={}
  for _,id in ipairs(select(2,F.keyItemSlot(0xFFFF))) do seen[id]=true end
  if not cross(HOENN,"first_keep") then return false end
  for _,id in ipairs(select(2,F.keyItemSlot(0xFFFF))) do if not seen[id] then hubPass=id end end
  return hubPass~=nil
end

-- Standard arrival through the real Johto gate; returns wherever the player lands.
local function standardJohto(tag)
  local x=gates[JOHTO].attendant
  if not F.route({{16,4},{x,4},{x,3}},tag.."_walk") then return nil end
  F.face("Up");F.press("A",3);F.idle(60)
  if not menu(1,tag.."_team") or not menu(1,tag.."_arrival") or not menu(0,tag.."_confirm") then return nil end
  for _=1,220 do
    if F.reportCrash(tag) then return nil end
    if not mapIs(HUB[1],HUB[2]) and F.ow() then F.idle(100);break end
    F.press("A",2);F.idle(14)
  end
  F.shot(tag.."_landed")
  return {F.grp(),F.mapn()}
end

local function state(badges,azalea,farfetchd,goldenrod)
  for i=0,7 do flag(FLAG_JOHTO_BADGE(i),badges[i]==true) end
  var(VAR_AZALEA_TOWN_STATE,azalea)
  var(VAR_ILEX_FOREST_FARFETCHD,farfetchd)
  var(VAR_GOLDENROD_CITY_STATE,goldenrod)
end

local function case(label,badges,azalea,farfetchd,goldenrod,want)
  F.check(label..": Hub Pass to the hub",passToHub(label:gsub("%W","_").."_out"),where())
  state(badges,azalea,farfetchd,goldenrod)
  local got=standardJohto(label:gsub("%W","_"))
  F.check(label,got~=nil and got[1]==want[1] and got[2]==want[2],
    string.format("landed %s want %d/%d", got and (got[1].."/"..got[2]) or "nowhere", want[1], want[2]))
end

F.run(function()
  local ok=setup()
  F.check("setup has a Hub Pass, Falkner's badge and one Pokemon",ok,where())
  if not ok then F.finish();return end
  case("Zephyr Badge only arrives home, south of Azalea",{[0]=true},0,0,0,NEW_BARK_2F)
  case("Hive Badge before Ilex Forest arrives home",{[0]=true,[1]=true},5,0,0,NEW_BARK_2F)
  case("Farfetch'd home but Cut not given arrives home",{[0]=true,[1]=true},6,2,0,NEW_BARK_2F)
  case("Ilex Forest finished arrives at Goldenrod",{[0]=true,[1]=true},7,3,0,GOLDENROD_STATION)
  case("Plain Badge arrives at Goldenrod",{[0]=true,[2]=true},0,0,5,GOLDENROD_STATION)
  F.finish()
end)
