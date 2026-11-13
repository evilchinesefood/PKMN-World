-- The Hub Pass works inside Oak's lab after the starter pick, before the rival's tutorial battle.
-- Coming back through the Kanto gate must not let that battle be skipped. Only the Pallet Town warp
-- is debug; the gate, Oak's scene, the pick, the Hub Pass and the walk out use real input.
-- KantoGateRivalBattleViaJohto.lua sets KANTO_RIVAL_VIA so the trip goes through Johto first: that
-- return is a real cross, which boxes the party, so the remembered starter has to come back.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local VIA = rawget(_G, "KANTO_RIVAL_VIA")
local F = require("lib").new(S, VIA and "KantoGateRivalBattleViaJohto" or "KantoGateRivalBattle")

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

local function mash(tag,until_)
  for _=1,600 do
    if until_() then return true end
    if F.reportCrash(tag) then return false end
    if scriptMenuActive() then menu(1,tag.."_no",3) end
    F.press(F.ow() and "B" or "A",2);F.idle(14)
  end
  return until_()
end
local function crossAt(x,tag)
  if not F.route({{16,4},{x,4},{x,3}},tag.."_walk") then return false end
  F.face("Up");F.press("A",3);F.idle(60)
  if not menu(0,tag.."_yes") then return false end
  for _=1,200 do if not mapIs(HUB[1],HUB[2]) and F.ow() then break end F.press("A",2);F.idle(14) end
  F.idle(60)
  return not mapIs(HUB[1],HUB[2])
end
local function crossKanto(tag) return crossAt(11,tag) end

F.run(function()
  if not F.boot(HUB[1]) then F.check("fresh boot",false);F.finish();return end
  local seen={}
  for _,id in ipairs(select(2,F.keyItemSlot(0xFFFF))) do seen[id]=true end
  F.check("first Kanto gate crossing",crossKanto("first"),where())
  drain()
  for _,id in ipairs(select(2,F.keyItemSlot(0xFFFF))) do if not seen[id] then hubPass=id end end
  F.check("first crossing gives the Hub Pass",hubPass~=nil)
  F.check("reach Pallet Town",debugWarp(37,0,"pallet"))
  drain()
  F.check("walk toward Route 1",F.route({{6,8},{12,8},{12,2}},"pallet_north"))
  F.press("Up",16);F.idle(30)
  mash("oak_scene",function() return getVar(VAR_LAB)==2 and F.ow() and not scriptMenuActive() and mapIs(38,3) end)
  drain()
  F.check("Oak's starter scene is open",getVar(VAR_LAB)==2 and mapIs(38,3),where().." lab="..getVar(VAR_LAB))
  F.check("pick Bulbasaur and confirm",pickBall(8,"bulbasaur"))
  mash("rival_pick",function() return getVar(VAR_LAB)==3 and F.ow() and not scriptMenuActive() end)
  drain()
  F.check("starter taken, rival battle still ahead",getVar(VAR_LAB)==3 and count()==1 and mapIs(38,3),where().." lab="..getVar(VAR_LAB).." count="..count())

  F.w16(F.sb1()+S.SaveBlock1.registeredItem,hubPass)
  F.press("Select",2);F.idle(90)
  F.check("Hub Pass out of the lab",menu(0,"hub_pass") and awaitMap(HUB[1],HUB[2],"hub"),where())
  drain()
  if VIA then
    F.check("cross into Johto",crossAt(16,"johto") and active()==2,where().." region="..active())
    drain()
    F.check("Johto took the Kanto party into the PC",count()==0,"count="..count())
    F.press("Select",2);F.idle(90)
    F.check("Hub Pass out of Johto",menu(0,"hub_pass_johto") and awaitMap(HUB[1],HUB[2],"hub_johto"),where())
    drain()
    F.check("cross back into Kanto",crossKanto("return"),where())
  else
    F.check("same-region Kanto gate",crossKanto("return"),where())
  end
  drain()
  F.shot("return_landing")
  F.check("the gate returns to the lab while the rival battle is pending",mapIs(38,3),where())
  F.check("the starter came back with the player",count()==1,"count="..count())
  local battled=false
  F.press("Down",16)
  for _=1,900 do
    if not F.ow() then battled=true end
    if getVar(VAR_LAB)==4 and F.ow() then break end
    if F.reportCrash("rival_battle") then break end
    F.press(F.ow() and "B" or "A",2);F.idle(14)
  end
  F.check("walking out starts the rival battle",battled,where().." lab="..getVar(VAR_LAB))
  F.check("the rival battle is fought before the player can leave",getVar(VAR_LAB)==4,"lab="..getVar(VAR_LAB))
  F.finish()
end)
