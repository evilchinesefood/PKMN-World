-- Focused #378 actual boundary probes. Debug setup only; route crossings use real inputs.
-- Fixture party/identity edits establish sentinels; actual inputs cross boundaries.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "RegionalTravelBoundaries")

local HUB = {100, 0}
local centers = {
  {name="Kanto", g=39, m=4, x=7, y=8, attendant=11, standardG=37, standardM=5},
  {name="Johto", g=77, m=0, x=7, y=8, attendant=16, standardG=84, standardM=23},
  {name="Hoenn", g=2, m=2, x=7, y=8, attendant=21, standardG=9, standardM=9},
}
local function checkedRoute(points,tag)
 local ok=F.route(points,tag)
 F.check(tag.." route completed",ok)
 return ok
end
local hubPass
local function where() local x,y=F.pos(); return string.format("%d/%d (%d,%d)",F.grp(),F.mapn(),x,y) end
local function mapIs(g,m) return F.grp()==g and F.mapn()==m end
local function travelBank() return F.sb3()+S.SaveBlock3.regionalTravel end
local function team(region) return travelBank()+4+(region-1)*52 end
local function centerAddress(region) return travelBank()+160+(region-1)*2 end
local function centerId(region) return F.r16(centerAddress(region)) end
local function active() return F.r8(F.sb2()+S.SaveBlock2.currentRegion) end
local function count() return F.r8(S.gPartiesCount) end
local function party(slot) return S.gParties+(slot or 0)*S.Pokemon.size end
local function hp(slot) return F.r16(party(slot)+S.Pokemon.hp) end
local function bytes(base,size)
  local result={}
  for i=0,size-1 do result[#result+1]=string.char(F.r8(base+i)) end
  return table.concat(result)
end
local function putBytes(base,value)
  for i=1,#value do F.w8(base+i-1,value:byte(i)) end
end
local function flag(id,value)
  local base,offset
  if id>=0x6000 and id<0x6400 then base=F.sb3()+S.SaveBlock3.johtoFlags;offset=id-0x6000
  else base=F.sb1()+S.SaveBlock1.flags;offset=id end
  local a=base+offset//8
  local bit=1<<(offset%8)
  F.w8(a,value and (F.r8(a)|bit) or (F.r8(a)&(~bit&255)))
end
local function var(id,value)
  local a
  if id>=0xA000 then a=F.sb3()+S.SaveBlock3.regionVars+(id-0xA000)*2
  else a=F.sb1()+S.SaveBlock1.vars+(id-0x4000)*2 end
  F.w16(a,value)
end
local function setActive(region)
  F.w8(F.sb2()+S.SaveBlock2.currentRegion,region)
  F.w32(S.gCurrentRegion,region)
end
local function monWords(address)
  local key=F.r32(address)~F.r32(address+4)
  local words={}
  for i=0,11 do words[i]=F.r32(address+32+i*4)~key end
  local p=F.r32(address)%24
  local offsets={}
  for i=0,3 do offsets[i]=F.r8(S.sSubstructOffsets+i*24+p)*3 end
  return words,offsets,key
end
local function identity(address)
  local w,o=monWords(address)
  local a,b,c=w[o[0]],w[o[0]+1],w[o[0]+2]
  local d,e=w[o[1]+1],w[o[3]+2]
  return ((a>>26)&63)|(((b>>29)&7)<<6)|(((c>>30)&3)<<9)
      |(((d>>11)&31)<<11)|(((d>>27)&7)<<16)|(((e>>28)&1)<<19)
end
local function clearIdentity(address)
  local w,o,key=monWords(address)
  w[o[0]]=w[o[0]]&0x03FFFFFF
  w[o[0]+1]=w[o[0]+1]&0x1FFFFFFF
  w[o[0]+2]=w[o[0]+2]&0x3FFFFFFF
  w[o[1]+1]=w[o[1]+1]&0xC7FF07FF
  w[o[3]+2]=w[o[3]+2]&0xEFFFFFFF
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
local function menu(want,tag,maxA)
  for _=1,(maxA or 65) do
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
local function debugWarp(g,m,tag,warp)
  local function digits(n) return n//100,(n//10)%10,n%10 end
  local gh,gt,go=digits(g);local mh,mt,mo=digits(m)
  return F.warpTo(gh,gt,go,mh,mt,mo,0,0,warp or 0,g,m,tag)
end
local function setParty()
  F.dbg();F.idle(40);F.sel(2);F.idle(40)
  for _=1,9 do F.press("Down",3);F.idle(16) end
  F.press("A",3);F.idle(180)
  drain()
  return count()==1 and hp()>0
end
local function talkGate(region,tag)
  local x=centers[region].attendant
  if not checkedRoute({{16,4},{x,4},{x,3}},tag.."_walk") then return false end
  F.face("Up");F.press("A",3);F.idle(60)
  return true
end
local function cross(region,teamChoice,arrivalChoice,tag,partial)
  if not talkGate(region,tag) then return false end
  if not menu(teamChoice,tag.."_team") then return false end
  if not menu(arrivalChoice,tag.."_arrival",65) then return false end
  if partial and not menu(0,tag.."_partial",65) then return false end
  if not menu(0,tag.."_confirm",65) then return false end
  local c=centers[region]
  local g,m=c.standardG,c.standardM
  if arrivalChoice==0 and centerId(region)~=0 then g,m=c.g,c.m end
  return awaitMap(g,m,tag)
end
local function passToHub(tag,answer)
  F.w16(F.sb1()+S.SaveBlock1.registeredItem,hubPass)
  F.press("Select",2);F.idle(90)
  if not menu(answer or 0,tag.."_confirm") then return false end
  if answer==1 then return drain() end
  return awaitMap(HUB[1],HUB[2],tag)
end
local function addSecondIndividual()
  putBytes(party(1),bytes(party(),100))
  clearIdentity(party(1))
  F.w8(S.gPartiesCount,2)
end
local function giveItem(item)
  if F.keyItemSlot(item)>=0 then return true end
  local p=S.gBagPockets+4*S.BagPocket.stride
  local base=F.r32(p)
  for i=0,(F.r16(p+S.BagPocket.count)&1023)-1 do
    if F.r16(base+i*4)==0 then
      F.w16(base+i*4,item)
      F.w16(base+i*4+2,1~(F.r32(F.sb2()+S.SaveBlock2.encryptionKey)&65535))
      return F.keyItemSlot(item)>=0
    end
  end
  return false
end
local function seed(region,g,m,tag,warp)
 for i=0,99 do F.w8(party(1)+i,0) end
 F.w8(S.gPartiesCount,1)
 setActive(region)
 local entered=debugWarp(g,m,tag.."_seed",warp)
 F.check(tag.." seed map setup",entered)
 if not entered then return false end
 addSecondIndividual()
 local enteredHub=passToHub(tag.."_seed_A")
 F.check(tag.." seed Hub Pass accepted",enteredHub)
 if not enteredHub then return false end
 F.check(tag.." seed A records two members",F.r8(team(region)+48)==2)
 for i=0,99 do F.w8(party(1)+i,0) end
 F.w8(S.gPartiesCount,1)
 local returned=debugWarp(g,m,tag.."_mainland_B",warp)
 F.check(tag.." mainland B setup",returned)
 return returned
end
local function clearSecond()
 for i=0,99 do F.w8(party(1)+i,0) end
 F.w8(S.gPartiesCount,1)
end
local function state()
 return bytes(travelBank(),168)..bytes(party(),600)..bytes(F.sb1()+S.SaveBlock1.lastHealLocation,8)..bytes(F.sb1()+S.SaveBlock1.vars+(0x40B4-0x4000)*2,2)..string.char(active())
end
local function saveReload(tag)
 local expected=state()
 F.press("Start",2);F.idle(60)
 if not F.selectStartIcon(7) then return false end
 for _=1,8 do F.press("A",2);F.idle(90) end
 F.idle(300);drain()
 client.reboot_core();F.idle(240)
 return F.boot(nil,true) and drain() and state()==expected
end
local function verdict(region,tag)
 drain()
 F.check(tag.." accepted boundary captures party B",F.r8(team(region)+48)==1 and F.r32(team(region))==identity(party()),"memoryCount="..F.r8(team(region)+48).." partyCount="..count().." "..where())
 local expected=bytes(team(region),52)
 addSecondIndividual() -- neutral C differs from remembered B
 if tag=="tower_foot" then
  local walked=debugWarp(37,58,"tower_neutral_lobby_setup")
  F.check("Tower neutral lobby setup",walked)
  if walked then F.press("Up",32);F.idle(180) end
  F.check("Tower outdoor to lobby preserves B after neutral edits C",mapIs(36,10) and bytes(team(region),52)==expected,where())
 end
 if tag=="tent" then F.check("neutral facility save Continue preserves B and C",saveReload(tag)) end
 F.check(tag.." neutral Hub Pass works",passToHub(tag.."_hub"),where())
 F.check(tag.." hub preserves B snapshot",bytes(team(region),52)==expected,"memoryCount="..F.r8(team(region)+48))
end
F.run(function()
 if not F.boot(HUB[1]) then F.check("boot",false);F.finish();return end
 for _,v in ipairs({0xDCF,0x51,0xA4B,0x63F8,0x94F,0x95F}) do flag(v,true) end
 F.w8(F.sb2()+S.SaveBlock2.introDoneBits,7)
 F.check("party setup",setParty())
 local old=select(2,F.keyItemSlot(0xFFFF));local seen={};for _,id in ipairs(old) do seen[id]=true end
 if not cross(3,1,1,"initial") then F.check("initial",false);F.finish();return end
 for _,id in ipairs(select(2,F.keyItemSlot(0xFFFF))) do if not seen[id] then hubPass=id end end
 if not hubPass then F.check("pass",false);F.finish();return end
 flag(0x61,true);flag(0xA4A,true);flag(0x1D0,true);flag(0x35C,false);var(0x40D4,1);giveItem(727)
 for _,port in ipairs({{9,9,"slateport",true},{13,10,"lilycove",false}}) do
  local g,m,tag,offersHub=table.unpack(port)
  if seed(3,g,m,tag) and checkedRoute({{8,14},{8,11}},tag.."_attendant") then
   local function choose(answer)
    F.face("Up");F.press("A",2);F.idle(60)
    if offersHub and not menu(1,tag.."_decline_hub") then return false end
    return menu(0,tag.."_destination") and menu(answer,tag.."_answer")
   end
   local expected=state()
   F.check(tag.." No returns without departure",choose(1) and drain() and mapIs(g,m) and state()==expected)
   putBytes(party(1),bytes(party(),100));F.w8(S.gPartiesCount,2) -- duplicate identity
   expected=state();local x,y=F.pos()
   F.check(tag.." duplicate identity refuses before boarding",choose(0) and drain() and mapIs(g,m) and state()==expected and select(1,F.pos())==x and select(2,F.pos())==y)
   clearSecond()
   local ok=choose(0) and awaitMap(25,41,tag.."_retry")
   F.check(tag.." repaired retry boards normal cruise",ok,where())
   if ok then verdict(3,tag) end
  end
 end
 if seed(3,0,1,"tent") then
  checkedRoute({{19,20},{10,20},{10,13}},"tent_approach")
  F.check("tent setup stands outside mainland door",mapIs(0,1),where())
  putBytes(party(1),bytes(party(),100));F.w8(S.gPartiesCount,2)
  local expected=state()
  F.press("Up",32);F.idle(80);drain()
  F.check("tent duplicate identity refusal preserves source and party",mapIs(0,1) and select(1,F.pos())==10 and select(2,F.pos())==13 and state()==expected)
  clearSecond()
  F.press("Up",32);F.idle(180)
  local ok=mapIs(9,2);F.check("actual tent door entered",ok,where())
  if ok then verdict(3,"tent") end
 end
 if seed(3,0,26,"hill",4) then
  local ok=checkedRoute({{31,114}},"hill_approach")
  if ok then
   putBytes(party(1),bytes(party(),100));F.w8(S.gPartiesCount,2)
   local expected=state()
   F.press("Up",32);F.idle(80);drain()
   F.check("Hill duplicate identity refuses warp on source entry tile",mapIs(0,26) and select(1,F.pos())==31 and select(2,F.pos())==113 and state()==expected,where())
   clearSecond()
   F.press("Down",24);F.idle(60);checkedRoute({{31,114}},"hill_retry_position")
   F.press("Up",32);F.idle(180)
  end
  ok=mapIs(26,60);F.check("actual Trainer Hill door entered",ok,where())
  if ok then verdict(3,"hill") end
 end
 for _,mode in ipairs({"foot","bike","flight","sidejump"}) do
  local tag="tower_"..mode
  if seed(1,37,17,tag) then
   local ok=checkedRoute({{8,10},{8,5},{9,5},{9,0}},tag.."_walk")
   if ok then
    if mode=="foot" then
     local playerId=F.r8(S.gPlayerAvatar+5)
     local blocker
     for _,obj in ipairs(F.objdump()) do if obj.i~=playerId then blocker=S.gObjectEvents+obj.i*S.ObjectEvent.stride;break end end
     F.check("Tower object collision fixture available",blocker~=nil)
     if blocker then
      local original=bytes(blocker,S.ObjectEvent.stride)
      local expected=bytes(team(1),52)
      F.w8(blocker+1,F.r8(blocker+1)|1) -- freeze the existing NPC during this collision probe
      F.w8(blocker+0x0B,0)
      F.w16(blocker+0x10,16);F.w16(blocker+0x12,6)
      F.w16(blocker+0x14,16);F.w16(blocker+0x16,6)
      F.press("Up",32);F.idle(60)
      F.check("blocked Tower approach does not capture",mapIs(37,17) and select(2,F.pos())==0 and bytes(team(1),52)==expected)
      putBytes(blocker,original)
     end
    end
    if mode=="bike" or mode=="sidejump" then
     local item=mode=="bike" and 707 or 708
     giveItem(item);F.w16(F.sb1()+S.SaveBlock1.registeredItem,item)
     F.press("Select",2);F.idle(100)
     F.check(tag.." mounted",(F.r8(S.gPlayerAvatar)&6)~=0)
    elseif mode=="flight" then
     giveItem(891);flag(0xA4D,true) -- all Kanto sky access progression is fixture setup
     F.w16(F.sb1()+S.SaveBlock1.registeredItem,891)
     F.press("Select",2);F.idle(100);drain()
     F.check(tag.." free-flight active",F.r8(S.sFlightActive)==1)
    end
    F.check(tag.." approach preserves mainland memory A",F.r8(team(1)+48)==2)
    setActive(2) -- deliberately disagree with the physical Kanto source
    local function enter()
     if mode=="sidejump" then
      F.face("Right");F.idle(20)
      for _=1,2 do joypad.set({Up=true,B=true});emu.frameadvance() end
      local seen=false
      for _=1,80 do
       local obj=S.gObjectEvents+F.r8(S.gPlayerAvatar+5)*S.ObjectEvent.stride
       seen=seen or F.r8(obj+0x1C)==0x43 -- MOVEMENT_ACTION_JUMP_UP
       F.idle(1)
      end
      if count()==1 then F.check(tag.." directional side jump installed",seen) end
     else F.press("Up",32);F.idle(180) end
    end
    putBytes(party(1),bytes(party(),100));F.w8(S.gPartiesCount,2)
    local expected=state()
    enter();drain()
    F.check(tag.." refusal preserves source party memory and campaign",mapIs(37,17) and select(1,F.pos())==9 and select(2,F.pos())==0 and state()==expected,where())
    clearSecond()
    enter()
    ok=mapIs(37,58)
    F.check(tag.." actual connection retry",ok,where())
    F.check(tag.." physical Kanto capture leaves Johto campaign active",active()==2 and F.r8(team(1)+48)==1)
    if ok then verdict(1,tag) end
   end
  end
 end
 F.finish()
end)
