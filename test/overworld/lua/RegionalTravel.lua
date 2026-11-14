local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "RegionalTravel")

local HUB = {100, 0}
local centers = {
  {name="Kanto", g=39, m=4, x=7, y=8, attendant=11, standardG=37, standardM=5},
  {name="Johto", g=77, m=0, x=7, y=8, attendant=16, standardG=84, standardM=23},
  {name="Hoenn", g=2, m=2, x=7, y=8, attendant=21, standardG=9, standardM=9},
}
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
local function snapshot()
  return {
    party=bytes(S.gParties,600), count=count(), hp=hp(), identity=identity(party()),
    storage=bytes(F.r32(S.gPokemonStoragePtr),34144),
    bank=bytes(travelBank(),168),
    region=active(), live=F.r32(S.gCurrentRegion),
    recovery=bytes(F.sb1()+S.SaveBlock1.lastHealLocation,8),
    warp=bytes(S.sWarpDestination,8),
  }
end
local function sameSnapshot(a)
  local b=snapshot()
  for k,v in pairs(a) do if b[k]~=v then return false,k end end
  return true,"unchanged"
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
local function debugWarp(g,m,tag)
  local function digits(n) return n//100,(n//10)%10,n%10 end
  local gh,gt,go=digits(g);local mh,mt,mo=digits(m)
  return F.warpTo(gh,gt,go,mh,mt,mo,0,0,0,g,m,tag)
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
  if not F.route({{16,4},{x,4},{x,3}},tag.."_walk") then return false end
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
local function visitCenter(region)
  local c=centers[region]
  setActive(region)
  if not debugWarp(c.g,c.m,"seed_"..c.name) then return false end
  F.w16(centerAddress(region),0)
  local beforeHP=hp()
  if not F.leg(c.x,c.y-1) then return false end
  for _=1,10 do
    if not mapIs(c.g,c.m) then break end
    F.press("Down",16);F.idle(30)
  end
  F.idle(140)
  F.check(c.name.." exterior does not record a Center",not mapIs(c.g,c.m) and centerId(region)==0,where())
  F.press("Up",22);F.idle(140)
  local entered=mapIs(c.g,c.m)
  F.check(c.name.." entered Center through its door",entered,where())
  F.check(c.name.." entered Center is remembered without healing",centerId(region)~=0,"id="..centerId(region))
  F.check(c.name.." entry did not heal the party",hp()==beforeHP,"hp="..hp())
  F.shot(c.name.."_entered_center")
  return entered and centerId(region)~=0
end
local function saveReload(tag)
  local expected=snapshot()
  F.press("Start",2);F.idle(60)
  if not F.selectStartIcon(7) then F.check(tag.." Save action available",false);return false end
  for _=1,8 do F.press("A",2);F.idle(90) end
  F.idle(300);drain()
  client.reboot_core();F.idle(240)
  if not F.boot(nil,true) then F.check(tag.." Continue",false);return false end
  F.check(tag.." remembered teams survive real save and Continue",bytes(travelBank(),168)==expected.bank)
  F.check(tag.." current party identity and condition survive independently",count()==expected.count and hp()==expected.hp and identity(party())==expected.identity)
  F.check(tag.." storage survives real save and Continue",bytes(F.r32(S.gPokemonStoragePtr),34144)==expected.storage)
  F.check(tag.." active campaign survives",active()==expected.region)
  F.check(tag.." recovery survives",bytes(F.sb1()+S.SaveBlock1.lastHealLocation,8)==expected.recovery)
  return drain()
end
local function lossAfterResume(region)
  local c=centers[region]
  F.dbg();F.idle(50);F.sel(2);F.idle(50)
  for _=1,10 do F.press("Down",3);F.idle(16) end
  F.press("A",3);F.idle(180)
  for _=1,150 do if not F.ow() then break end F.idle(8) end
  local started=not F.ow()
  F.check("forced-loss battle started after resume",started)
  if not started then return false end
  for _=1,2200 do
    F.w8(S.gBattleOutcome,2)
    for i=0,5 do F.w16(party(i)+S.Pokemon.hp,0) end
    for i=0,math.min(F.battlers(),4)-1 do F.w16(S.gBattleMons+i*S.BattlePokemon.size+S.BattlePokemon.hp,0) end
    F.press("A",2);F.idle(2)
    if F.ow() and mapIs(c.g,c.m) and hp()>0 then
      drain();F.shot("whiteout_after_resume")
      F.check("forced loss returns to resumed region's Center",true,where())
      return true
    end
  end
  F.check("forced loss returns to resumed region's Center",false,where())
  return false
end

local function addSecondIndividual()
  putBytes(party(1),bytes(party(),100))
  clearIdentity(party(1))
  F.w8(S.gPartiesCount,2)
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
local function ferryBoard(row,tag)
  F.face("Down");F.press("A",2);F.idle(60)
  local ready=false
  for _=1,40 do
    if F.rs8(S.sMenu+S.Menu.maxCursorPos)==5 then ready=true;break end
    F.idle(10)
  end
  if not ready then F.shot(tag.."_missing_board");return false end
  for _=1,8 do
    if F.mcur()==row then F.shot(tag);F.press("A",2);F.idle(45);return true end
    F.press("Down",2);F.idle(12)
  end
  return false
end
local function ferryScenarios()
  F.check("ferry prerequisite has S.S.TICKET",giveTicket())
  flag(0x600F,true)
  var(0xA081,11)
  var(0xA0A8,0)
  setActive(2)
  addSecondIndividual()
  F.check("maiden voyage setup reaches Olivine port",debugWarp(88,8,"maiden_port"))
  F.check("walk to actual boarding sailor",F.route({{8,16}},"maiden_sailor"))
  F.face("Down");F.press("A",2);F.idle(60)
  F.check("accept maiden boarding confirmation",menu(0,"maiden_accept"))
  local boarded=awaitMap(95,0,"maiden_ship")
  F.check("maiden voyage boards the actual ship",boarded,where())
  if not boarded then return false end
  F.check("boarding captures Johto before onboard activity",F.r8(team(2)+48)==2)
  local originMemory=bytes(team(2),52)
  for i=0,99 do F.w8(party(1)+i,0) end
  F.w8(S.gPartiesCount,1)
  var(0xA0A8,6)
  F.check("approach actual ship exit sailor",F.leg(29,3))
  F.face("Up");F.press("A",2);F.idle(50)
  F.check("actual disembark reaches Vermilion port",awaitMap(43,8,"maiden_disembark"),where())
  F.check("disembark does not recapture changed onboard party",bytes(team(2),52)==originMemory)
  F.check("ferry carries current party into Kanto",active()==1 and count()==1)
  drain()
  F.check("walk to Vermilion return sailor",F.route({{8,16}},"return_sailor"))
  F.face("Down");F.press("A",2);F.idle(50)
  F.check("accept actual return ferry",menu(0,"return_accept"))
  F.check("return ferry uses Olivine port",awaitMap(88,8,"return_olivine"),where())
  F.check("return boarding records Kanto and carries party",F.r8(team(1)+48)==1 and active()==2 and count()==1)
  drain()
  F.check("reach Olivine board after maiden voyage",F.route({{8,16}},"frontier_sailor"))
  F.check("select real Frontier voyage",ferryBoard(4,"frontier_board"))
  F.check("Frontier ferry arrives at normal dock",awaitMap(26,4,"frontier_arrive"),where())
  local johtoBefore=bytes(team(2),52)
  F.check("Johto departure is recorded before Frontier",F.r8(team(2)+48)==1 and active()==2)
  addSecondIndividual()
  F.check("Frontier party change is distinct from departure memory",count()==2 and F.r8(team(2)+48)==1)
  drain()
  var(0x40D0,1)
  flag(0x344,true)
  F.check("walk to Frontier reception entrance",F.route({{26,66}},"frontier_reception_door"))
  F.press("Up",20);F.idle(120)
  F.check("enter actual Frontier reception",mapIs(26,50),where())
  F.check("walk through Frontier reception",F.route({{4,12},{3,12},{3,2},{4,2}},"frontier_reception"))
  F.press("Up",20);F.idle(120)
  F.check("leave actual Frontier reception",mapIs(26,4),where())
  F.check("walk to actual Frontier hub shuttle",F.route({{26,60},{25,60}},"frontier_shuttle"))
  F.face("Down");F.press("A",2);F.idle(50)
  F.check("accept neutral hub shuttle",menu(0,"frontier_shuttle_accept"))
  F.check("neutral shuttle reaches World Transit",awaitMap(100,0,"frontier_hub"),where())
  F.check("neutral shuttle does not overwrite Johto team",bytes(team(2),52)==johtoBefore)
  F.check("Frontier to hub to Hoenn keeps the current party",cross(3,1,1,"frontier_onward_hoenn") and count()==2)
  F.check("onward travel still preserves Johto source memory",bytes(team(2),52)==johtoBefore)
  return true
end

local function setFixtureSpeciesMoves(address,species,move)
  local w,o,key=monWords(address)
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
local function specialGateScenarios()
  if not mapIs(100,0) and not passToHub("special_gate_start") then return false end
  for slot=1,5 do for i=0,99 do F.w8(party(slot)+i,0) end end
  F.w8(S.gPartiesCount,1)
  -- Checkpoint and progress are prerequisites; every result is driven through the actual gate.
  local function attempt(region,id,g,m,safe,tag,choice)
    F.w16(centerAddress(region),id)
    local c=centers[region]
    local oldG,oldM=c.g,c.m
    c.g,c.m=safe and g or c.standardG,safe and m or c.standardM
    local ok=cross(region,choice or 1,0,tag)
    F.check(tag.." uses "..(safe and "remembered Center" or "standard fallback"),ok,where())
    F.check(tag.." keeps historical checkpoint",centerId(region)==id)
    c.g,c.m=oldG,oldM
    if not ok then return false end
    return passToHub(tag.."_out")
  end
  setFixtureSpeciesMoves(party(),7,57) -- Squirtle with Surf
  flag(0x953,true) -- Hoenn Surf badge must not unlock Johto.
  flag(0x63FB,false)
  if not attempt(2,43,90,4,false,"cianwood_wrong_campaign_badge") then return false end
  flag(0x63FB,true)
  if not attempt(2,43,90,4,true,"cianwood_destination_badge") then return false end
  -- The actual departure just recorded the Surf-capable individual. Box it and carry Caterpie.
  local remembered=identity(party())
  local storage=F.r32(S.gPokemonStoragePtr)+4
  putBytes(storage,bytes(party(),80))
  clearIdentity(party())
  setFixtureSpeciesMoves(party(),10,33)
  if not attempt(2,43,90,4,false,"cianwood_current_party_cannot_escape") then return false end
  -- The prior failed resume's actual departure captured Caterpie; restore only the earlier
  -- reference fixture so the next UI action tests the final recalled team, not its source party.
  F.w32(team(2),remembered);F.w16(team(2)+4,7);F.w8(team(2)+48,1)
  if not attempt(2,43,90,4,true,"cianwood_recalled_party_can_escape",0) then return false end
  F.check("checkpoint access used recalled individual",identity(party())==remembered)
  setFixtureSpeciesMoves(party(),6,19) -- Charizard with Fly
  flag(0x954,true)
  var(0x405E,1)
  if not attempt(3,8,15,2,false,"sootopolis_pending_scene") then return false end
  var(0x405E,6)
  if not attempt(3,8,15,2,true,"sootopolis_completed_scene") then return false end
  var(0xA04F,0)
  if not attempt(1,30,65,2,false,"sevii_without_network") then return false end
  var(0xA04F,5)
  if not attempt(1,30,65,2,true,"sevii_network_ready") then return false end
  for i=1,7 do flag(0xA4B+i,false) end
  if not attempt(1,25,47,0,false,"league_missing_badges") then return false end
  for i=1,7 do flag(0xA4B+i,true) end
  if not attempt(1,25,47,0,true,"league_admitted") then return false end
  setFixtureSpeciesMoves(party(),10,33)
  for i=0,7 do flag(0x94F+i,true) end
  if not attempt(3,16,16,10,true,"hoenn_league_without_water_or_flight") then return false end
  F.check("Hoenn League Hub Pass exit records party",F.r8(team(3)+48)==1 and F.r32(team(3))==identity(party()))
  flag(0x61E5,false)
  if not attempt(2,47,97,9,false,"silver_guard_closed") then return false end
  flag(0x61E5,true)
  if not attempt(2,47,97,9,true,"silver_guard_open") then return false end
  return true
end

local function tidalScenarios()
  setActive(3)
  flag(0x61,true) -- Stern's completed harbor scene enables the real shuttle.
  flag(0xA4A,true) -- Hoenn champion enables the ordinary S.S. Tidal destinations.
  flag(0x1D0,true) -- Met Scott: the ordinary destination board includes Frontier.
  flag(0x35C,false)
  addSecondIndividual()
  if not debugWarp(9,9,"tidal_direct_hub") then return false end
  if not F.route({{8,14},{8,11}},"tidal_hub_attendant") then return false end
  F.face("Up");F.press("A",2);F.idle(60)
  if not menu(0,"tidal_accept_direct_hub") then return false end
  local hub=awaitMap(100,0,"tidal_direct_hub_arrival")
  F.check("actual Slateport hub entry reaches World Transit",hub,where())
  F.check("actual Slateport hub entry captures Hoenn ordered party",hub and F.r8(team(3)+48)==2 and F.r32(team(3)+8)==identity(party(1)))
  if not hub then return false end
  for i=0,99 do F.w8(party(1)+i,0) end
  F.w8(S.gPartiesCount,1)
  if not debugWarp(9,9,"tidal_frontier_departure") then return false end
  if not F.route({{8,14},{8,11}},"tidal_ferry_attendant") then return false end
  F.face("Up");F.press("A",2);F.idle(60)
  if not menu(1,"tidal_decline_hub") then return false end
  if not menu(1,"tidal_select_frontier") then return false end
  if not menu(0,"tidal_confirm_frontier") then return false end
  local arrived=awaitMap(26,4,"tidal_normal_frontier_arrival")
  local x,y=F.pos()
  F.check("actual S.S. Tidal voyage uses normal Frontier dock",arrived and x==19 and y==67,where())
  F.check("accepted S.S. Tidal boarding captures changed Hoenn party",arrived and F.r8(team(3)+48)==1 and F.r32(team(3))==identity(party()))
  F.check("S.S. Tidal keeps Hoenn campaign ownership",active()==3)
  if not arrived then return false end
  local origin=bytes(team(3),52)
  addSecondIndividual()
  F.check("Hub Pass from neutral Frontier returns normally",passToHub("tidal_neutral_departure"))
  F.check("neutral return cannot replace S.S. Tidal departure memory",bytes(team(3),52)==origin)
  return true
end

F.run(function()
  if not F.boot(HUB[1]) then F.check("fresh boot",false);F.finish();return end
  flag(0xDCF,true)
  flag(0x51,true)
  flag(0xA4B,true)
  flag(0x63F8,true)
  flag(0x94F,true)
  flag(0x95F,true) -- visited Slateport, so the standard Hoenn arrival is its harbor
  F.w8(F.sb2()+S.SaveBlock2.introDoneBits,7)
  F.check("debug prerequisite creates one live Pokemon",setParty())
  F.w16(party()+S.Pokemon.hp,7)
  local oldItems=select(2,F.keyItemSlot(0xFFFF));local seen={}
  for _,id in ipairs(oldItems) do seen[id]=true end
  F.check("no historical team or checkpoint on fresh save",F.r8(team(1)+48)==0 and F.r8(team(2)+48)==0 and F.r8(team(3)+48)==0 and centerId(1)==0 and centerId(2)==0 and centerId(3)==0)
  local first=cross(3,1,1,"first_keep")
  F.check("no-memory current-party travel uses standard Hoenn arrival",first,where())
  if not first then F.finish();return end
  for _,id in ipairs(select(2,F.keyItemSlot(0xFFFF))) do if not seen[id] then hubPass=id end end
  F.check("first mature travel supplies a Hub Pass",hubPass~=nil)
  if not hubPass then F.finish();return end
  F.check("keep-current travel does not heal",hp()==7,"hp="..hp())
  F.check("keep-current arrival save and reload",saveReload("keep_current_arrival"))

  local recorded={}
  for region=1,3 do
    if not visitCenter(region) then F.check("Center visit setup completed",false);F.finish();return end
    if region==1 then F.check("Center entry without healing save and reload",saveReload("center_without_healing")) end
    recorded[region]=centerId(region)
    local before=bytes(team(region),52)
    local hash=snapshot()
    F.check(centers[region].name.." canceled Hub Pass stays put",passToHub("cancel_depart_"..region,1),where())
    F.check(centers[region].name.." canceled departure leaves memory",bytes(team(region),52)==before)
    F.check(centers[region].name.." canceled departure leaves party",bytes(S.gParties,600)==hash.party)
    F.check(centers[region].name.." accepted Hub Pass reaches hub",passToHub("depart_"..region),where())
    F.check(centers[region].name.." departure records actual ordered party",F.r8(team(region)+48)==1 and F.r32(team(region))==identity(party()))
    F.check(centers[region].name.." Center survives hub arrival",centerId(region)==recorded[region])
  end
  local shared=identity(party())
  F.check("one actual Pokemon is shared by three memories",shared~=0 and F.r32(team(1))==shared and F.r32(team(2))==shared and F.r32(team(3))==shared)
  F.check("real hub save and reload preserves departure state",saveReload("hub_departure"))

  for source=1,3 do
    F.check("enter source campaign "..source,cross(source,1,1,"source_"..source),where())
    F.check("depart source campaign "..source,passToHub("source_out_"..source),where())
    for destination=1,3 do
      if active()~=source then
        F.check("return to pair source "..source,cross(source,1,1,"reset_source_"..source..destination),where())
        F.check("capture pair source "..source,passToHub("reset_source_out_"..source..destination),where())
      end
      local choice=(source+destination)%2
      local arrival=(source+destination+1)%2
      local priorBank=bytes(travelBank(),168)
      local currentHP=hp()
      local ok=cross(destination,choice,arrival,"pair_"..source.."_"..destination)
      F.check("pair "..source.." to "..destination.." uses selected arrival",ok,where())
      if not ok then F.finish();return end
      F.check("pair "..source.." to "..destination.." claims destination campaign",active()==destination)
      F.check("pair "..source.." to "..destination.." preserves shared individual",count()==1 and identity(party())==shared)
      F.check("pair "..source.." to "..destination.." does not heal",hp()==currentHP)
      F.check("pair "..source.." to "..destination.." does not recapture hub party",bytes(travelBank(),168)==priorBank)
      if source==1 and destination==1 then F.check("successful recall save and reload",saveReload("successful_recall")) end
      F.check("pair "..source.." to "..destination.." departs normally",passToHub("pair_out_"..source..destination))
    end
  end

  local before=snapshot()
  F.check("open mature gate for cancellation",talkGate(2,"cancel_gate"))
  F.check("select regional team before cancel",menu(0,"cancel_team"))
  F.check("cancel at destination choice",menu(2,"cancel_destination",65))
  drain()
  local unchanged,field=sameSnapshot(before)
  F.check("canceled preview preserves party PC memory campaign destination and recovery",unchanged,field)
  F.check("canceled preview save and reload",saveReload("canceled_preview"))

  local saved=bytes(party(),100)
  putBytes(party(1),saved)
  clearIdentity(party(1))
  F.w8(S.gPartiesCount,2)
  F.check("fixture creates a distinct second current individual",identity(party(1))==0)
  F.check("keep current two-member party into Johto",cross(2,1,0,"two_members"))
  F.check("actual departure remembers two members",passToHub("two_members_out") and F.r8(team(2)+48)==2)
  local missingId=F.r32(team(2)+8)
  for i=0,99 do F.w8(party(1)+i,0) end
  F.w8(S.gPartiesCount,1)
  F.check("removed-member prerequisite does not edit remembered lineup",missingId~=0 and F.r8(team(2)+48)==2)
  F.check("partial recall requires and accepts explicit confirmation",cross(2,0,0,"partial_recall",true),where())
  F.check("partial recall carries only the available actual individual",count()==1 and identity(party())==shared)
  F.check("partial recall does not prematurely replace remembered lineup",F.r8(team(2)+48)==2)
  F.check("partial recall save and reload",saveReload("partial_recall"))
  F.check("forced whiteout after Center resume",lossAfterResume(2))
  F.check("ferries and neutral Frontier isolation",ferryScenarios())
  F.check("special checkpoint gates through actual hub choices",specialGateScenarios())
  F.check("S.S. Tidal and direct harbor entry",tidalScenarios())
  F.finish()
end)
