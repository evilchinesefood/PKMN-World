-- Gate team recall under storage pressure. Every Pokemon carries a distinct personality, and the
-- whole party plus all PC boxes are counted before and after each gate, refusal and Continue.
-- Debug and memory setup stand in for hub PC edits only; every crossing uses the real gate.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "RegionalTravelStorage")

local HUB = {100, 0}
local SLOTS = 14 * 30
local gates = {
  {attendant=11, standardG=37, standardM=5},
  {attendant=16, standardG=84, standardM=23},
  {attendant=21, standardG=9, standardM=9},
}
local hubPass
local function where() local x,y=F.pos(); return string.format("%d/%d (%d,%d)",F.grp(),F.mapn(),x,y) end
local function mapIs(g,m) return F.grp()==g and F.mapn()==m end
local function travelBank() return F.sb3()+S.SaveBlock3.regionalTravel end
local function team(region) return travelBank()+4+(region-1)*52 end
local function teamCount(region) return F.r8(team(region)+48) end
local function active() return F.r8(F.sb2()+S.SaveBlock2.currentRegion) end
local function count() return F.r8(S.gPartiesCount) end
local function party(slot) return S.gParties+(slot or 0)*S.Pokemon.size end
local function box(slot) return F.r32(S.gPokemonStoragePtr)+4+slot*80 end
local function present(address) return (F.r8(address+19)&2)~=0 end
local function pid(address) return F.r32(address) end
local function bytes(base,size)
  local result={}
  for i=0,size-1 do result[#result+1]=string.char(F.r8(base+i)) end
  return table.concat(result)
end
local function putBytes(base,value)
  for i=1,#value do F.w8(base+i-1,value:byte(i)) end
end
local function zero(address,size) for i=0,size-1 do F.w8(address+i,0) end end
local function flag(id,value)
  local base,offset
  if id>=0x6000 and id<0x6400 then base=F.sb3()+S.SaveBlock3.johtoFlags;offset=id-0x6000
  else base=F.sb1()+S.SaveBlock1.flags;offset=id end
  local a=base+offset//8
  local bit=1<<(offset%8)
  F.w8(a,value and (F.r8(a)|bit) or (F.r8(a)&(~bit&255)))
end
local function money() return F.money() end
local function setMoney(v) F.w32(F.sb1()+S.SaveBlock1.money,v~F.r32(F.sb2()+S.SaveBlock2.encryptionKey)) end

local function order(p)
  local o={}
  for i=0,3 do o[i]=F.r8(S.sSubstructOffsets+i*24+p%24)*3 end
  return o
end
local function decode(address)
  local key=F.r32(address)~F.r32(address+4)
  local w={}
  for i=0,11 do w[i]=F.r32(address+32+i*4)~key end
  local o=order(F.r32(address))
  local sub={}
  for i=0,3 do sub[i]={w[o[i]],w[o[i]+1],w[o[i]+2]} end
  return sub
end
local function encode(address,sub)
  local key=F.r32(address)~F.r32(address+4)
  local o=order(F.r32(address))
  local w={}
  for i=0,3 do for k=0,2 do w[o[i]+k]=sub[i][k+1] end end
  local checksum=0
  for i=0,11 do
    checksum=(checksum+(w[i]&65535)+(w[i]>>16))&65535
    F.w32(address+32+i*4,w[i]~key)
  end
  F.w16(address+28,checksum)
end
local function identity(address)
  local s=decode(address)
  local a,b,c=s[0][1],s[0][2],s[0][3]
  local d,e=s[1][2],s[3][3]
  return ((a>>26)&63)|(((b>>29)&7)<<6)|(((c>>30)&3)<<9)
      |(((d>>11)&31)<<11)|(((d>>27)&7)<<16)|(((e>>28)&1)<<19)
end
-- A copy of the template with its own personality, no regional identity, optional egg bit.
local function makeMon(dst,src,personality,size,egg)
  putBytes(dst,src:sub(1,size))
  local sub=decode(dst)
  F.w32(dst,personality)
  sub[0][1]=sub[0][1]&0x03FFFFFF
  sub[0][2]=sub[0][2]&0x1FFFFFFF
  sub[0][3]=sub[0][3]&0x3FFFFFFF
  sub[1][2]=sub[1][2]&0xC7FF07FF
  sub[3][3]=sub[3][3]&0xEFFFFFFF
  if egg then
    sub[3][2]=sub[3][2]|0x40000000
    F.w8(dst+19,F.r8(dst+19)|4)
  end
  encode(dst,sub)
end

local template
local function partyMon(slot,personality,egg) makeMon(party(slot),template,personality,100,egg) end
local function boxMon(slot,personality,egg) makeMon(box(slot),template,personality,80,egg) end
local function partyPids()
  local r={}
  for i=0,count()-1 do r[#r+1]=pid(party(i)) end
  return r
end
local function setParty(pids)
  for i=0,5 do zero(party(i),100) end
  for i,p in ipairs(pids) do partyMon(i-1,p) end
  F.w8(S.gPartiesCount,#pids)
end
local function census()
  local seen,dupes,n={},{},0
  local function add(address,where_)
    if not present(address) then return end
    local p=pid(address)
    n=n+1
    if seen[p] then dupes[#dupes+1]=string.format("%08X@%s",p,where_) end
    seen[p]=where_
  end
  for i=0,5 do add(party(i),"party"..i) end
  for i=0,SLOTS-1 do add(box(i),"box"..i) end
  return {seen=seen,dupes=dupes,n=n}
end
local function sameCensus(a,b,expectGone)
  expectGone=expectGone or {}
  local gone={}
  for _,p in ipairs(expectGone) do gone[p]=true end
  if #b.dupes>0 then return false,"cloned "..table.concat(b.dupes,",") end
  for p,w in pairs(a.seen) do
    if not gone[p] and not b.seen[p] then return false,string.format("lost %08X (was %s)",p,w) end
  end
  for p,w in pairs(b.seen) do
    if not a.seen[p] then return false,string.format("new %08X at %s",p,w) end
  end
  return true,string.format("%d mons",b.n)
end
local function partyIs(pids,tag)
  local got=partyPids()
  local ok=#got==#pids
  for i=1,#pids do ok=ok and got[i]==pids[i] end
  local s={}
  for _,p in ipairs(got) do s[#s+1]=string.format("%X",p) end
  F.check(tag,ok,"party="..table.concat(s,","))
  return ok
end
local function seq(base,n) local r={} for i=0,n-1 do r[#r+1]=base+i end return r end

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
          F.L("  menu "..tag..": A never closed the menu")
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
local function talkGate(region,tag)
  local x=gates[region].attendant
  if not F.route({{16,4},{x,4},{x,3}},tag.."_walk") then return false end
  F.face("Up");F.press("A",3);F.idle(60)
  return true
end
-- Standard arrival only (choice 1), so the destination map is known.
local function cross(region,teamChoice,tag,partial)
  if not talkGate(region,tag) then return false end
  if not menu(teamChoice,tag.."_team") then return false end
  if not menu(1,tag.."_arrival") then return false end
  if partial and not menu(0,tag.."_partial") then return false end
  if not menu(0,tag.."_confirm") then return false end
  return awaitMap(gates[region].standardG,gates[region].standardM,tag)
end
-- Walk the gate up to the final confirmation and expect a refusal that leaves the player in the hub.
local function refusedCross(region,teamChoice,tag)
  if not talkGate(region,tag) then return false end
  if not menu(teamChoice,tag.."_team") then return false end
  for _=1,40 do
    if scriptMenuActive() then F.shot(tag.."_offered");return false end
    F.press("B",2);F.idle(20)
  end
  drain()
  return mapIs(HUB[1],HUB[2])
end
local function passToHub(tag)
  F.w16(F.sb1()+S.SaveBlock1.registeredItem,hubPass)
  F.press("Select",2);F.idle(90)
  if not menu(0,tag.."_confirm") then return false end
  return awaitMap(HUB[1],HUB[2],tag)
end
local function saveReload(tag)
  local before=census()
  local bank=bytes(travelBank(),168)
  local pp=partyPids()
  F.press("Start",2);F.idle(60)
  if not F.selectStartIcon(7) then F.check(tag.." save action available",false);return false end
  for _=1,8 do F.press("A",2);F.idle(90) end
  F.idle(300);drain()
  client.reboot_core();F.idle(240)
  if not F.boot(nil,true) then F.check(tag.." Continue",false);return false end
  drain()
  local ok,detail=sameCensus(before,census())
  F.check(tag.." census survives save and Continue",ok,detail)
  F.check(tag.." remembered teams survive save and Continue",bytes(travelBank(),168)==bank)
  partyIs(pp,tag.." party order survives save and Continue")
  return ok
end

local function setup()
  if not F.boot(HUB[1]) then return false end
  flag(0xDCF,true)
  flag(0x51,true)
  flag(0xA4B,true)
  flag(0x63F8,true)
  F.w16(F.sb3()+S.SaveBlock3.regionVars+0x8C*2,7) -- VAR_AZALEA_TOWN_STATE: past Ilex, so Johto arrives at Goldenrod
  flag(0x94F,true)
  flag(0x95F,true) -- visited Slateport, so the standard Hoenn arrival is its harbor
  F.w8(F.sb2()+S.SaveBlock2.introDoneBits,7)
  if not debugParty() then return false end
  template=bytes(party(),100)
  local seen={}
  for _,id in ipairs(select(2,F.keyItemSlot(0xFFFF))) do seen[id]=true end
  setParty(seq(0xA0,6))
  if not cross(3,1,"first_keep") then return false end
  for _,id in ipairs(select(2,F.keyItemSlot(0xFFFF))) do if not seen[id] then hubPass=id end end
  return hubPass~=nil
end

F.run(function()
  local ok=setup()
  F.check("setup reaches Hoenn with six distinct Pokemon and a Hub Pass",ok,where())
  if not ok then F.finish();return end
  local A=seq(0xA0,6)
  local B=seq(0xB0,6)
  F.check("Hoenn departure with a full party",passToHub("depart_A"))
  F.check("Hoenn remembers six",teamCount(3)==6,"count="..teamCount(3))

  -- Hub PC edit: A into box slots 0-5, carry B, every other slot full.
  for i=0,5 do putBytes(box(i),bytes(party(i),80)) end
  setParty(B)
  for i=6,SLOTS-1 do boxMon(i,0x10000+i) end
  local full=census()
  F.check("fixture fills party and every PC slot with distinct Pokemon",full.n==6+SLOTS and #full.dupes==0,"n="..full.n)
  setMoney(0)
  F.check("keep-current B into Johto with a full PC",cross(2,1,"keep_B_full_pc"))
  F.check("full-PC keep does not move anyone",select(1,sameCensus(full,census())))
  F.check("zero money survives the gate",money()==0,"money="..money())
  setMoney(999999)
  F.check("Johto departure with a full PC",passToHub("depart_B"))
  F.check("max money survives the Hub Pass",money()==999999,"money="..money())
  F.check("Johto remembers B",teamCount(2)==6)

  local before=census()
  F.check("recall A into Hoenn with exactly six free slots from the swap",cross(3,0,"recall_A_exact"))
  partyIs(A,"recalled party is A in remembered order")
  local same,detail=sameCensus(before,census())
  F.check("exact swap keeps every Pokemon once",same,detail)
  saveReload("exact_swap")
  F.check("Hoenn departure after exact swap",passToHub("depart_A2"))

  -- One slot short: release B6 and refill its slot, so B recalls five and six must leave.
  local b6
  for i=0,SLOTS-1 do if present(box(i)) and pid(box(i))==B[6] then b6=i end end
  F.check("B6 is in the PC",b6~=nil)
  zero(box(b6),80)
  boxMon(b6,0x20000)
  before=census()
  local bank=bytes(travelBank(),168)
  F.check("one-short recall is refused and stays in the hub",refusedCross(2,0,"recall_B_short"))
  same,detail=sameCensus(before,census())
  F.check("refused recall moves nobody",same,detail)
  partyIs(A,"refused recall keeps A carried")
  F.check("refused recall keeps every memory",bytes(travelBank(),168)==bank)
  saveReload("refused_short")

  -- Free exactly one slot elsewhere; partial recall of five now fits.
  zero(box(SLOTS-1),80)
  before=census()
  F.check("partial recall of B with exactly enough room",cross(2,0,"recall_B_partial",true))
  partyIs({B[1],B[2],B[3],B[4],B[5]},"partial recall carries the five available B")
  same,detail=sameCensus(before,census())
  F.check("partial recall keeps every Pokemon once",same,detail)
  saveReload("partial_exact")
  F.check("Johto departure with five",passToHub("depart_B5"))
  F.check("Johto now remembers five",teamCount(2)==5)

  -- Party of two carrying a Pokemon Hoenn remembers; Hoenn recall keeps it and pulls the rest.
  local function find(p) for i=0,SLOTS-1 do if present(box(i)) and pid(box(i))==p then return i end end end
  local a3=find(A[3])
  F.check("A3 is in the PC",a3~=nil)
  -- A hand-moved box mon needs a valid party tail (mail slot, stats), as BoxMonToMon gives it.
  putBytes(party(5),bytes(box(a3),80)..template:sub(81,100))
  local free={a3}
  for i=SLOTS-2,0,-1 do
    if #free==4 then break end
    if present(box(i)) and pid(box(i))>=0x10000 then zero(box(i),80);free[#free+1]=i end
  end
  for k=1,4 do zero(box(free[k]),80);putBytes(box(free[k]),bytes(party(k),80)) end
  putBytes(party(1),bytes(party(5),100))
  for i=2,5 do zero(party(i),100) end
  F.w8(S.gPartiesCount,2)
  before=census()
  F.check("party of two holding a Hoenn member",#before.dupes==0 and count()==2,table.concat(before.dupes,","))
  F.check("recall A while carrying A3",cross(3,0,"recall_A_with_member"))
  partyIs(A,"recall retains the carried member in its remembered slot")
  same,detail=sameCensus(before,census())
  F.check("shared-member recall keeps every Pokemon once",same,detail)
  saveReload("shared_member")
  F.check("Hoenn departure with A",passToHub("depart_A3"))

  -- Eggs and fainted members travel as stored; an all-fainted remembered team is refused.
  local eggSlot=math.min(count(),5)
  partyMon(eggSlot,0xE66,true)
  F.w8(S.gPartiesCount,eggSlot+1)
  F.check("egg written into party",F.r8(party(eggSlot)+19)&4~=0)
  before=census()
  F.check("keep-current with an egg into Kanto",cross(1,1,"keep_egg"))
  F.check("Kanto departure with an egg",passToHub("depart_egg"))
  F.check("Kanto remembers the egg",teamCount(1)==eggSlot+1)
  for i=0,5 do F.w16(party(i)+S.Pokemon.hp,0) end
  before=census()
  bank=bytes(travelBank(),168)
  F.check("all-fainted keep-current is refused",refusedCross(3,1,"keep_fainted"))
  same,detail=sameCensus(before,census())
  F.check("refused fainted keep moves nobody",same,detail)
  F.check("refused fainted keep keeps memory",bytes(travelBank(),168)==bank)
  for i=0,5 do F.w16(party(i)+S.Pokemon.hp,10) end
  F.check("recall Johto deposits the egg",cross(2,0,"recall_B_egg"))
  same,detail=sameCensus(before,census())
  F.check("egg deposit keeps every Pokemon once",same,detail)
  F.check("Johto departure",passToHub("depart_B6"))
  F.check("recall Kanto withdraws the egg",cross(1,0,"recall_egg"))
  F.check("egg came back as an egg",F.r8(party(eggSlot)+19)&4~=0 and pid(party(eggSlot))==0xE66)
  same,detail=sameCensus(before,census())
  F.check("egg round trip keeps every Pokemon once",same,detail)
  saveReload("egg_round_trip")
  F.finish()
end)
