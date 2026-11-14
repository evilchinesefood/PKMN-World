-- World Transit gate recall when the remembered team changed after departure, plus input abuse.
-- A remembered member evolved, hatched, went to the Day Care or was released; a remembered team
-- of only Eggs; A/B/Start mashing through the preview at Instant text; and a soft reset on each
-- of a range of frames between the final Yes and the region's arrival. Every Pokemon carries a
-- distinct personality and the party, every PC box and the Day Care are counted before and after.
-- Memory setup stands in for hub PC edits and evolution; every crossing uses the real gate.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "GateRecallStress")

local HUB = {100, 0}
local SLOTS = 14 * 30
local HOENN, JOHTO = 3, 2
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
local function count() return F.r8(S.gPartiesCount) end
local function party(slot) return S.gParties+(slot or 0)*S.Pokemon.size end
local function box(slot) return F.r32(S.gPokemonStoragePtr)+4+slot*80 end
local function daycare() return F.sb1()+S.SaveBlock1.daycare end
local function present(address) return (F.r8(address+19)&2)~=0 end
local function isEgg(address) return (F.r8(address+19)&4)~=0 end
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
local function species(address) return decode(address)[0][1]&0x7FF end
local function setSpecies(address,value)
  local sub=decode(address)
  sub[0][1]=(sub[0][1]&~0x7FF)|value
  encode(address,sub)
end
local function setEgg(address,egg)
  local sub=decode(address)
  if egg then
    sub[3][2]=sub[3][2]|0x40000000
    F.w8(address+19,F.r8(address+19)|4)
  else
    sub[3][2]=sub[3][2]&~0x40000000
    F.w8(address+19,F.r8(address+19)&~4)
  end
  encode(address,sub)
end
-- A copy of the template with its own personality and no regional identity.
local function makeMon(dst,src,personality,size)
  putBytes(dst,src:sub(1,size))
  local sub=decode(dst)
  F.w32(dst,personality)
  sub[0][1]=sub[0][1]&0x03FFFFFF
  sub[0][2]=sub[0][2]&0x1FFFFFFF
  sub[0][3]=sub[0][3]&0x3FFFFFFF
  sub[1][2]=sub[1][2]&0xC7FF07FF
  sub[3][3]=sub[3][3]&0xEFFFFFFF
  encode(dst,sub)
end

local template
local function partyPids()
  local r={}
  for i=0,count()-1 do r[#r+1]=pid(party(i)) end
  return r
end
local function setParty(pids)
  for i=0,5 do zero(party(i),100) end
  for i,p in ipairs(pids) do makeMon(party(i-1),template,p,100) end
  F.w8(S.gPartiesCount,#pids)
end
local function findBox(p) for i=0,SLOTS-1 do if present(box(i)) and pid(box(i))==p then return i end end end
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
  add(daycare(),"daycare")
  return {seen=seen,dupes=dupes,n=n}
end
local function sameCensus(a,b)
  if #b.dupes>0 then return false,"cloned "..table.concat(b.dupes,",") end
  for p,w in pairs(a.seen) do
    if not b.seen[p] then return false,string.format("lost %08X (was %s)",p,w) end
  end
  for p,w in pairs(b.seen) do
    if not a.seen[p] then return false,string.format("new %08X at %s",p,w) end
  end
  return true,string.format("%d mons",b.n)
end
local function checkCensus(tag,before)
  local same,detail=sameCensus(before,census())
  F.check(tag,same,detail)
  return same
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
-- Selects row `want` of the next script menu. With `closeNow`, returns on the frame the menu closes.
local function menu(want,tag,closeNow)
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
              if not scriptMenuActive() then
                if not closeNow then F.idle(30) end
                return true
              end
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
local function talkGate(region,tag)
  local x=gates[region].attendant
  if not F.route({{16,4},{x,4},{x,3}},tag.."_walk") then return false end
  F.face("Up");F.press("A",3);F.idle(60)
  return true
end
local function cross(region,teamChoice,tag,partial)
  if not talkGate(region,tag) then return false end
  if not menu(teamChoice,tag.."_team") then return false end
  if not menu(1,tag.."_arrival") then return false end
  if partial and not menu(0,tag.."_partial") then return false end
  if not menu(0,tag.."_confirm") then return false end
  return awaitMap(gates[region].standardG,gates[region].standardM,tag)
end
-- Picks a team the gate must refuse, then expects the conversation to end in the hub.
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
  for attempt=1,3 do
    drain()
    F.w16(F.sb1()+S.SaveBlock1.registeredItem,hubPass)
    F.press("Select",2);F.idle(90)
    if menu(0,tag.."_confirm"..attempt) then return awaitMap(HUB[1],HUB[2],tag) end
  end
  return false
end
-- Holds the reset buttons until the game resets. The commit scans the whole PC, so the main loop
-- can miss the first frames of the combination. Returns how many frames it was held.
local function softReset()
  local counter=S.gMain+0x20
  for i=1,120 do
    local before=F.r32(counter)
    joypad.set({A=true,B=true,Start=true,Select=true});emu.frameadvance()
    if F.grp()~=HUB[1] and F.grp()~=gates[HOENN].standardG or F.r32(counter)<before then
      joypad.set({});return i
    end
  end
  joypad.set({})
  return -1
end
local function saveGame(tag)
  F.press("Start",2);F.idle(60)
  if not F.selectStartIcon(7) then F.check(tag.." save action available",false);return false end
  for _=1,8 do F.press("A",2);F.idle(90) end
  F.idle(300);drain()
  return true
end
local function instantText() F.w8(F.sb2()+0x14,(F.r8(F.sb2()+0x14)&~7)|3) end

local function setup()
  if not F.boot(HUB[1]) then return false end
  flag(0xDCF,true)
  flag(0x51,true)
  flag(0xA4B,true)
  flag(0x63F8,true)
  flag(0x94F,true)
  flag(0x95F,true) -- visited Slateport, so the standard Hoenn arrival is its harbor
  F.w8(F.sb2()+S.SaveBlock2.introDoneBits,7)
  if not debugParty() then return false end
  template=bytes(party(),100)
  local seen={}
  for _,id in ipairs(select(2,F.keyItemSlot(0xFFFF))) do seen[id]=true end
  setParty(seq(0xA0,6))
  if not cross(HOENN,1,"first_keep") then return false end
  for _,id in ipairs(select(2,F.keyItemSlot(0xFFFF))) do if not seen[id] then hubPass=id end end
  return hubPass~=nil
end

F.run(function()
  local ok=setup()
  F.check("setup reaches Hoenn with six distinct Pokemon and a Hub Pass",ok,where())
  if not ok then F.finish();return end
  local A=seq(0xA0,6)
  local B=seq(0xB0,6)
  local baseSpecies=species(party(0))
  local evolved=baseSpecies==1 and 2 or 1

  -- A2 leaves Hoenn as an Egg so it can hatch while Hoenn is away.
  setEgg(party(1),true)
  F.check("Hoenn departure with A, A2 an Egg",passToHub("depart_A"))
  F.check("Hoenn remembers six",teamCount(HOENN)==6,"count="..teamCount(HOENN))

  -- Hub PC edit: A into the PC, B carried. Then A1 evolves, A2 hatches, A3 goes to the
  -- Day Care and A4 is released.
  for i=0,5 do putBytes(box(i),bytes(party(i),80)) end
  setParty(B)
  setSpecies(box(0),evolved)
  setEgg(box(1),false)
  putBytes(daycare(),bytes(box(2),80))
  zero(box(2),80)
  zero(box(3),80)
  local before=census()
  F.check("fixture holds B, four A in the PC and A3 in the Day Care",before.n==11 and #before.dupes==0,"n="..before.n)
  F.check("partial recall of the changed Hoenn team",cross(HOENN,0,"recall_changed",true),where())
  partyIs({A[1],A[2],A[5],A[6]},"recall carries the four reachable members in remembered order")
  checkCensus("changed-team recall keeps every Pokemon once",before)
  F.check("evolved member arrives as its new species",species(party(0))==evolved,"species="..species(party(0)))
  F.check("hatched member arrives hatched",not isEgg(party(1)))
  F.check("Day Care member stays in the Day Care",pid(daycare())==A[3] and present(daycare()))
  F.check("Day Care member is not also in the party or PC",findBox(A[3])==nil)

  -- A remembered team of only Eggs: recall must be refused, keep-current still works.
  for i=0,count()-1 do setEgg(party(i),true) end
  F.check("Hoenn departure with only Eggs",passToHub("depart_eggs"))
  F.check("Hoenn remembers four Eggs",teamCount(HOENN)==4,"count="..teamCount(HOENN))
  local eggs=partyPids()
  local free={}
  for i=0,SLOTS-1 do if #free<#eggs and not present(box(i)) then free[#free+1]=i end end
  for k,slot in ipairs(free) do putBytes(box(slot),bytes(party(k-1),80)) end
  local C={0xC0,0xC1}
  setParty(C)
  before=census()
  local bank=bytes(travelBank(),168)
  F.check("recalling an all-Egg team is refused in the hub",refusedCross(HOENN,0,"recall_eggs"),where())
  checkCensus("refused Egg recall moves nobody",before)
  F.check("refused Egg recall keeps every memory",bytes(travelBank(),168)==bank)
  F.check("keep-current still travels beside an all-Egg memory",cross(HOENN,1,"keep_beside_eggs"),where())
  partyIs(C,"keep-current carries the party it had")
  checkCensus("keep-current beside Eggs keeps every Pokemon once",before)

  -- Mash A, B, Start and the D-pad through each gate at Instant text. Whatever the mash selects,
  -- nobody is cloned or lost and the game never crashes.
  instantText()
  F.check("Hoenn departure before mashing",passToHub("depart_mash"))
  local patterns={
    {"A"},{"A","B"},{"A","Start"},{"A","Down","A"},{"A","A","Up","B"},{"Start","A","Select","A"},
  }
  for n,pattern in ipairs(patterns) do
    local tag="mash"..n
    local region=(n-1)%3+1
    local g=gates[region]
    if not mapIs(HUB[1],HUB[2]) then F.check(tag.." Hub Pass back",passToHub(tag.."_back"),where()) end
    before=census()
    local x,y=F.pos()
    local path=y>=5 and {{x,6},{16,6},{16,4}} or {{x,4},{16,4}}
    path[#path+1]={g.attendant,4};path[#path+1]={g.attendant,3}
    local walked=F.route(path,tag.."_walk")
    F.face("Up")
    local crashed=false
    for i=1,2400 do
      local key=pattern[(i//3)%#pattern+1]
      if i%3==0 then joypad.set({[key]=true}) else joypad.set({}) end
      emu.frameadvance()
      if i%30==0 and F.reportCrash(tag) then crashed=true;break end
    end
    joypad.set({})
    F.idle(120);drain()
    F.check(tag.." walked to gate "..region,walked,where())
    F.check(tag.." never crashed",not crashed)
    F.check(tag.." ends in the hub or the standard arrival",mapIs(HUB[1],HUB[2]) or mapIs(g.standardG,g.standardM),where())
    checkCensus(tag.." keeps every Pokemon once",before)
    F.L(string.format("  %s gate %d ends at %s party=%d",tag,region,where(),count()))
  end

  -- Select (the registered Hub Pass) held through the gate's warp and the arrival, then through
  -- the Hub Pass's own warp back. Neither warp may start a second one or crash.
  if not mapIs(HUB[1],HUB[2]) then F.check("Hub Pass back before Select spam",passToHub("spam_back"),where()) end
  F.w16(F.sb1()+S.SaveBlock1.registeredItem,hubPass)
  before=census()
  local reached=talkGate(HOENN,"spam") and menu(1,"spam_team") and menu(1,"spam_arrival")
    and menu(0,"spam_confirm",true)
  F.check("Select spam: reached the final Yes",reached,where())
  local crashed=false
  for i=1,600 do
    if i%2==0 then joypad.set({Select=true}) else joypad.set({}) end
    emu.frameadvance()
    if i%30==0 and F.reportCrash("spam_gate") then crashed=true;break end
  end
  joypad.set({})
  F.shot("spam_gate_after")
  drain()
  F.check("Select through the gate warp never crashes",not crashed)
  F.check("Select through the gate warp lands at the standard arrival",mapIs(gates[HOENN].standardG,gates[HOENN].standardM),where())
  checkCensus("Select through the gate warp keeps every Pokemon once",before)
  F.press("Select",2);F.idle(90)
  reached=menu(0,"spam_pass_confirm",true)
  F.check("Select spam: accepted the Hub Pass",reached,where())
  crashed=false
  for i=1,600 do
    if i%2==0 then joypad.set({Select=true}) else joypad.set({}) end
    emu.frameadvance()
    if i%30==0 and F.reportCrash("spam_pass") then crashed=true;break end
  end
  joypad.set({})
  F.shot("spam_pass_after")
  drain()
  F.check("Select through the Hub Pass warp never crashes",not crashed)
  F.check("Select through the Hub Pass warp lands in the hub",mapIs(HUB[1],HUB[2]),where())
  checkCensus("Select through the Hub Pass warp keeps every Pokemon once",before)

  -- Soft reset between the final Yes and the arrival. The commit has moved Pokemon in RAM only,
  -- so every reset must Continue in the hub with the saved party, PC and memories.
  if not mapIs(HUB[1],HUB[2]) then F.check("Hub Pass back before the reset sweep",passToHub("reset_back"),where()) end
  drain()
  -- Hoenn remembers C1 and C2. Carry C1 alone with C2 in the PC, so the commit withdraws C2.
  F.check("Hoenn remembers C1 and C2",teamCount(HOENN)==2 and F.r32(team(HOENN)+8)~=0,"count="..teamCount(HOENN))
  local slotB2
  for i=0,SLOTS-1 do if not slotB2 and not present(box(i)) then slotB2=i end end
  putBytes(box(slotB2),bytes(party(1),80))
  zero(party(1),100)
  F.w8(S.gPartiesCount,1)
  F.check("hub save before the reset sweep",saveGame("reset_sweep"))
  local saved=census()
  local savedBank=bytes(travelBank(),168)
  local savedParty=partyPids()
  for _,off in ipairs({0,1,2,3,5,8,12,20,30,45,60,90,150}) do
    local tag="reset "..off.." frames after the final Yes"
    local reached=talkGate(HOENN,"reset"..off)
      and menu(0,"reset"..off.."_team") and menu(1,"reset"..off.."_arrival")
      and menu(0,"reset"..off.."_confirm",true)
    F.check(tag..": reached the final Yes",reached,where())
    if not reached then break end
    local moved=count()
    F.idle(off)
    F.L(string.format("  %s: party=%d->%d at %s",tag,moved,count(),where()))
    local held=softReset()
    F.L(string.format("  %s: reset combination held %d frames",tag,held))
    F.idle(60)
    if not F.boot(nil,true) or F.reportCrash(tag) then F.check(tag..": Continue",false);break end
    drain()
    F.check(tag..": Continue lands in the hub",mapIs(HUB[1],HUB[2]),where())
    checkCensus(tag..": the saved Pokemon load once each",saved)
    F.check(tag..": the saved memories load",bytes(travelBank(),168)==savedBank)
    partyIs(savedParty,tag..": the saved party loads")
  end
  F.finish()
end)
