-- A Johto champion who sails the S.S. Aqua to Vermilion carries a full party into Kanto before Oak
-- has handed out a starter. The Hub Pass and the same-region Kanto gate keep that party, and Oak's
-- lab must still give exactly one starter. Setup writes only the Johto post-League prerequisites
-- and the party; the voyage, the gate, Oak's trigger and the ball picks use real input.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "OaksLabFullParty")

local HUB = {100, 0}
local SLOTS = 14 * 30
local VAR_LAB = 0xA02E
local hubPass
local function where() local x,y=F.pos(); return string.format("%d/%d (%d,%d)",F.grp(),F.mapn(),x,y) end
local function mapIs(g,m) return F.grp()==g and F.mapn()==m end
local function active() return F.r8(F.sb2()+S.SaveBlock2.currentRegion) end
local function count() return F.r8(S.gPartiesCount) end
local function party(slot) return S.gParties+(slot or 0)*S.Pokemon.size end
local function box(slot) return F.r32(S.gPokemonStoragePtr)+4+slot*80 end
local function present(address) return (F.r8(address+19)&2)~=0 end
local function bytes(base,size)
  local result={}
  for i=0,size-1 do result[#result+1]=string.char(F.r8(base+i)) end
  return table.concat(result)
end
local function putBytes(base,value) for i=1,#value do F.w8(base+i-1,value:byte(i)) end end
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
local function setActive(region)
  F.w8(F.sb2()+S.SaveBlock2.currentRegion,region)
  F.w32(S.gCurrentRegion,region)
end
local function order(p)
  local o={}
  for i=0,3 do o[i]=F.r8(S.sSubstructOffsets+i*24+p%24)*3 end
  return o
end
-- Re-key a copied Pokemon to a new personality so every member is a distinct individual.
local function rekey(address,personality)
  local key=F.r32(address)~F.r32(address+4)
  local w={}
  for i=0,11 do w[i]=F.r32(address+32+i*4)~key end
  local o=order(F.r32(address))
  local sub={}
  for i=0,3 do sub[i]={w[o[i]],w[o[i]+1],w[o[i]+2]} end
  F.w32(address,personality)
  key=personality~F.r32(address+4)
  o=order(personality)
  for i=0,3 do for k=0,2 do F.w32(address+32+(o[i]+k)*4,sub[i][k+1]~key) end end
end
local function pids()
  local set,n={},0
  for i=0,5 do if present(party(i)) then set[F.r32(party(i))]=true;n=n+1 end end
  for i=0,SLOTS-1 do if present(box(i)) then set[F.r32(box(i))]=true;n=n+1 end end
  return set,n
end
local function newSince(before)
  local now,n=pids()
  local fresh=0
  for p in pairs(now) do if not before[p] then fresh=fresh+1 end end
  return fresh,n
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
  for _=1,260 do
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
-- Advance text with B (never re-talks) until the player has field control again.
local function settle(tag)
  for _=1,120 do
    if F.reportCrash(tag) then return false end
    if scriptMenuActive() then return true end
    F.press("B",2);F.idle(20)
    if F.ow() and F.ensureFree() then return true end
  end
  return false
end
local function pickBall(x,tag)
  local px,py=F.pos()
  if not F.route({{px,5},{x,5}},tag.."_walk") then return false end
  F.face("Up");F.press("A",2);F.idle(60)
  return menu(0,tag.."_yes",40)
end

F.run(function()
  if not F.boot(HUB[1]) then F.check("fresh boot",false);F.finish();return end
  local seen={}
  for _,id in ipairs(select(2,F.keyItemSlot(0xFFFF))) do seen[id]=true end
  F.check("walk to the Johto gate",F.route({{16,4},{16,3}},"johto_gate"))
  F.face("Up");F.press("A",3);F.idle(60)
  F.check("first gate crossing accepted",menu(0,"johto_yes"))
  for _=1,200 do if not mapIs(HUB[1],HUB[2]) and F.ow() then break end F.press("A",2);F.idle(14) end
  drain()
  for _,id in ipairs(select(2,F.keyItemSlot(0xFFFF))) do if not seen[id] then hubPass=id end end
  F.check("first crossing gives the Hub Pass",hubPass~=nil,where())

  F.dbg();F.idle(40);F.sel(2);F.idle(40)
  for _=1,9 do F.press("Down",3);F.idle(16) end
  F.press("A",3);F.idle(180)
  drain()
  local template=bytes(party(),100)
  for i=0,5 do putBytes(party(i),template);rekey(party(i),0xC0+i) end
  F.w8(S.gPartiesCount,6)
  -- Johto post-League prerequisites for Elm's S.S. Aqua; Kanto is untouched.
  F.check("S.S.TICKET prerequisite",giveTicket())
  flag(0x600F,true)
  var(0xA081,11)
  var(0xA0A8,0)
  setActive(2)
  F.check("Kanto starter not yet given",getVar(VAR_LAB)==0)

  F.check("reach Olivine port",debugWarp(88,8,"olivine_port"))
  F.check("walk to the boarding sailor",F.route({{8,16}},"olivine_sailor"))
  F.face("Down");F.press("A",2);F.idle(60)
  F.check("accept the maiden voyage",menu(0,"maiden_accept"))
  F.check("board the S.S. Aqua",awaitMap(95,0,"aboard"),where())
  var(0xA0A8,6)
  F.check("approach the exit sailor",F.leg(29,3))
  F.face("Up");F.press("A",2);F.idle(50)
  F.check("disembark at Vermilion",awaitMap(43,8,"vermilion_port"),where())
  drain()
  F.check("the voyage carries six into an active Kanto",active()==1 and count()==6,"active="..active().." count="..count())

  F.w16(F.sb1()+S.SaveBlock1.registeredItem,hubPass)
  F.press("Select",2);F.idle(90)
  F.check("Hub Pass from Vermilion",menu(0,"hub_pass") and awaitMap(HUB[1],HUB[2],"hub"),where())
  drain()
  F.check("walk to the Kanto gate",F.route({{16,4},{11,4},{11,3}},"kanto_gate"))
  F.face("Up");F.press("A",3);F.idle(60)
  F.check("same-region Kanto gate accepted",menu(0,"kanto_yes"))
  F.check("land in the Pallet bedroom",awaitMap(38,1,"bedroom"),where())
  drain()
  F.check("the gate keeps the full party",count()==6,"count="..count())

  F.check("reach Pallet Town",debugWarp(37,0,"pallet"))
  drain()
  F.check("walk toward Route 1",F.route({{6,8},{12,8},{12,2}},"pallet_north"))
  F.press("Up",16);F.idle(30)
  for _=1,400 do
    if getVar(VAR_LAB)==2 and F.ow() and not scriptMenuActive() then break end
    if F.reportCrash("oak_scene") then break end
    F.press("B",2);F.idle(14)
  end
  drain()
  F.check("Oak's starter scene opens with the full party",getVar(VAR_LAB)==2 and mapIs(38,3),where().." lab="..getVar(VAR_LAB))

  local before=pids()
  F.check("pick Bulbasaur and confirm",pickBall(8,"bulbasaur"))
  F.check("starter choice is answered",settle("after_bulbasaur"))
  if scriptMenuActive() then menu(1,"nickname_no",5) end
  F.idle(90);F.shot("after_nickname")
  for _=1,300 do
    if F.ow() and not scriptMenuActive() and F.ensureFree() then break end
    F.press("B",2);F.idle(14)
  end
  local fresh,total=newSince(before)
  F.shot("after_first_pick")
  F.check("the first pick gives exactly one starter",fresh==1,"new="..fresh.." total="..total)
  F.check("the first pick moves the story past the choice",getVar(VAR_LAB)>=3,"lab="..getVar(VAR_LAB))

  if getVar(VAR_LAB)==2 then
    pickBall(9,"squirtle")
    for _=1,300 do
      if F.ow() and not scriptMenuActive() and F.ensureFree() then break end
      F.press("B",2);F.idle(14)
    end
  end
  fresh,total=newSince(before)
  F.check("no second starter can be taken",fresh==1,"new="..fresh.." total="..total)
  F.finish()
end)
