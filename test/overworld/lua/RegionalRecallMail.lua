-- Gate team recall with held Mail and a chosen follower. A recall keeps carried members, withdraws
-- the rest from the PC and deposits everyone else. Mail lives in SaveBlock1.mail and a holder only
-- stores an index into it, so a recalled holder must keep its message, a deposited holder's message
-- must move to the PC mailbox intact, and a refused recall (full PC, full mailbox) must touch none.
-- The chosen follower is a party index that GetFollowerSlot re-finds after a reorder;
-- PlanExchange reads the raw index, so the suite reorders with the party menu right before the
-- gate and checks that the chosen Pokemon still follows after the recall.
-- Debug and memory setup stand in for hub PC edits and for writing Mail; the party menu's Follow
-- and Switch, every gate crossing, the Hub Pass and save and Continue use real input.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "RegionalRecallMail")

local HUB = {100, 0}
local SLOTS = 14 * 30
local gates = {
  {attendant=11, standardG=37, standardM=5},
  {attendant=16, standardG=84, standardM=23},
  {attendant=21, standardG=9, standardM=9},
}
local ITEM_ORANGE_MAIL, ITEM_HARBOR_MAIL = 199, 200
local MAIL_SIZE, MAIL_COUNT, PARTY_MAIL, MAIL_NONE = 36, 16, 6, 0xFF
local MON_MAIL = 85
local FLAG_SYS_POKEMON_GET = 0x948
local USM_ICO_PARTY = 1
local hubPass
local function where() local x,y=F.pos(); return string.format("%d/%d (%d,%d)",F.grp(),F.mapn(),x,y) end
local function mapIs(g,m) return F.grp()==g and F.mapn()==m end
local function travelBank() return F.sb3()+S.SaveBlock3.regionalTravel end
local function team(region) return travelBank()+4+(region-1)*52 end
local function teamCount(region) return F.r8(team(region)+48) end
local function count() return F.r8(S.gPartiesCount) end
local function party(slot) return S.gParties+(slot or 0)*S.Pokemon.size end
local function box(slot) return F.r32(S.gPokemonStoragePtr)+4+slot*80 end
local function mail(i) return F.sb1()+S.SaveBlock1.mail+i*MAIL_SIZE end
local function present(address) return (F.r8(address+19)&2)~=0 end
local function pid(address) return F.r32(address) end
local function followerSlot() return F.r8(F.sb2()+S.SaveBlock2.followerSlot) end
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
local function heldItem(address) return (decode(address)[0][1]>>16)&0x3FF end
local function setHeldItem(address,item)
  local sub=decode(address)
  sub[0][1]=(sub[0][1]&~(0x3FF<<16))|(item<<16)
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
local function partyMon(slot,personality)
  makeMon(party(slot),template,personality,100)
  F.w8(party(slot)+MON_MAIL,MAIL_NONE)
end
local function boxMon(slot,personality) makeMon(box(slot),template,personality,80) end
local function setParty(pids)
  for i=0,5 do zero(party(i),100) end
  for i,p in ipairs(pids) do partyMon(i-1,p) end
  F.w8(S.gPartiesCount,#pids)
end
local function partyPids()
  local r={}
  for i=0,count()-1 do r[#r+1]=pid(party(i)) end
  return r
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
local function findBox(p) for i=0,SLOTS-1 do if present(box(i)) and pid(box(i))==p then return i end end end
local function findParty(p) for i=0,count()-1 do if pid(party(i))==p then return i end end end
local function seq(base,n) local r={} for i=0,n-1 do r[#r+1]=base+i end return r end
-- The carried party as raw bytes, regional identities included, keyed by personality.
local function capture()
  local r={}
  for i=0,count()-1 do r[pid(party(i))]=bytes(party(i),100) end
  return r
end

-- Nine words of easy chat plus the item, so every message is distinct and checkable.
local function letter(seed,item)
  local w={}
  for i=0,8 do w[#w+1]=string.char((seed+i)&255,(seed>>8)&255) end
  return table.concat(w).."PLAYER\255\255\0\0\0\0"..string.char(25,0,item&255,item>>8,0,0)
end
local function giveMail(slot,index,seed,item)
  putBytes(mail(index),letter(seed,item))
  setHeldItem(party(slot),item)
  F.w8(party(slot)+MON_MAIL,index)
end
local function clearMailbox() for i=0,MAIL_COUNT-1 do zero(mail(i),MAIL_SIZE) end end
local function mailIndexOf(text)
  for i=0,MAIL_COUNT-1 do if bytes(mail(i),MAIL_SIZE)==text then return i end end
  return nil
end
-- Where the message is held now: the party holder's mail index, or nil.
local function heldLetter(p)
  local slot=findParty(p)
  if not slot then return nil end
  local index=F.r8(party(slot)+MON_MAIL)
  if index>=MAIL_COUNT then return nil end
  return index,bytes(mail(index),MAIL_SIZE),heldItem(party(slot))
end
local function mailSnapshot() return bytes(mail(0),MAIL_SIZE*MAIL_COUNT) end

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
local function saveReload(tag)
  F.press("Start",2);F.idle(60)
  if not F.selectStartIcon(7) then F.check(tag.." save action available",false);return false end
  for _=1,8 do F.press("A",2);F.idle(90) end
  F.idle(300);drain()
  client.reboot_core();F.idle(240)
  if not F.boot(nil,true) then F.check(tag.." Continue",false);return false end
  drain()
  return true
end

local function menuMax() return F.rs8(S.sMenu+S.Menu.maxCursorPos) end
local function openParty()
  F.press("Start",2);F.idle(60)
  if not F.selectStartIcon(USM_ICO_PARTY) then F.L("  party icon not found");return false end
  F.press("A",2);F.idle(90)
  if F.cb2()~=(S.CB2_UpdatePartyMenu&~1) then F.L("  party menu did not open");return false end
  return true
end
local function closeParty()
  for _=1,4 do
    F.press("B",2);F.idle(60)
    if F.ow() then break end
  end
  drain()
end
-- The field action list ends Follow, Nickname, Cancel (src/swsh_party_menu.c).
local function partyFollow(slot,tag)
  if not openParty() then return false end
  for _=1,slot do F.press("Down",2);F.idle(12) end
  F.press("A",2);F.idle(40)
  for _=1,menuMax()-2 do F.press("Down",2);F.idle(12) end
  F.shot(tag.."_follow_row")
  F.press("A",2);F.idle(60)
  F.press("A",2);F.idle(40)
  closeParty()
  return true
end
local function partySwitch(a,b)
  if not openParty() then return false end
  for _=1,a do F.press("Down",2);F.idle(12) end
  F.press("L",2);F.idle(40)
  for _=1,b-a do F.press("Down",2);F.idle(12) end
  F.shot("switch_target")
  F.press("A",2);F.idle(90)
  closeParty()
  return true
end

local function setup()
  if not F.boot(HUB[1]) then return false end
  flag(0xDCF,true)
  flag(0x51,true)
  flag(0xA4B,true)
  flag(0x63F8,true)
  flag(0x94F,true)
  flag(FLAG_SYS_POKEMON_GET,true)
  F.w8(F.sb2()+S.SaveBlock2.introDoneBits,7)
  if not debugParty() then return false end
  template=bytes(party(),100)
  local seen={}
  for _,id in ipairs(select(2,F.keyItemSlot(0xFFFF))) do seen[id]=true end
  setParty(seq(0xA0,6))
  if not cross(3,1,"first_keep") then return false end
  for _,id in ipairs(select(2,F.keyItemSlot(0xFFFF))) do if not seen[id] then hubPass=id end end
  return hubPass~=nil and passToHub("depart_A") and teamCount(3)==6
end

F.run(function()
  local ok=setup()
  F.check("setup: Hoenn remembers six and a Hub Pass is in hand",ok,where())
  if not ok then F.finish();return end
  local A=seq(0xA0,6)
  local X=0xC0
  local saved=capture()

  -- Hub PC edit: A3 and a stranger X carried, the rest of A boxed. Both carried hold Mail.
  for i=0,SLOTS-1 do zero(box(i),80) end
  for i,p in ipairs(A) do if i~=3 then putBytes(box(i-1),saved[p]:sub(1,80)) end end
  setParty({X})
  putBytes(party(1),saved[A[3]])
  F.w8(party(1)+MON_MAIL,MAIL_NONE)
  F.w8(S.gPartiesCount,2)
  clearMailbox()
  local letterX,letterA3=letter(0x1100,ITEM_ORANGE_MAIL),letter(0x2200,ITEM_HARBOR_MAIL)
  giveMail(0,0,0x1100,ITEM_ORANGE_MAIL)
  giveMail(1,1,0x2200,ITEM_HARBOR_MAIL)

  F.check("Follow chosen on A3 in the second slot",partyFollow(1,"follow_a3") and followerSlot()==2,"slot="..followerSlot())
  F.check("party-menu Switch puts A3 first",partySwitch(0,1) and pid(party(0))==A[3],string.format("lead=%X",pid(party(0))))
  F.check("back on the field the stored follower index already names A3",followerSlot()==1,"slot="..followerSlot())

  F.check("recall A while A3 and X hold Mail",cross(3,0,"recall_mail"))
  partyIs(A,"recalled party is A in remembered order")
  local index,text,item=heldLetter(A[3])
  F.check("A3 still holds its Harbor Mail",item==ITEM_HARBOR_MAIL,"item="..tostring(item))
  F.check("A3's message survives the recall",text==letterA3,"index="..tostring(index))
  local xBox=findBox(X)
  F.check("X was deposited",xBox~=nil)
  F.check("X was deposited without its Mail",xBox and heldItem(box(xBox))==0,"item="..(xBox and heldItem(box(xBox)) or -1))
  local moved=mailIndexOf(letterX)
  F.check("X's message moved to the PC mailbox intact",moved~=nil and moved>=PARTY_MAIL,"index="..tostring(moved))
  F.check("X's old party Mail slot is free",F.r16(mail(0)+32)==0,"item="..F.r16(mail(0)+32))
  F.check("the chosen A3 still follows after the recall",
    followerSlot()==3 and pid(party(2))==A[3],string.format("slot=%d at=%X",followerSlot(),pid(party(math.max(followerSlot(),1)-1))))

  if saveReload("recall_mail") then
    index,text,item=heldLetter(A[3])
    F.check("after Continue A3 still holds its message",item==ITEM_HARBOR_MAIL and text==letterA3,"index="..tostring(index))
    F.check("after Continue X's message is still in the PC mailbox",moved~=nil and mailIndexOf(letterX)==moved,"index="..tostring(mailIndexOf(letterX)))
  end
  F.check("Hoenn departure with A",passToHub("depart_A2"))

  -- Full PC: A3 and five strangers carried, A6 released, every other slot full. The recall has
  -- four withdrawals for five deposits, so it must be refused and leave every message in place.
  saved=capture()
  for i=0,SLOTS-1 do zero(box(i),80) end
  for i=1,5 do if i~=3 then putBytes(box(i-1),saved[A[i]]:sub(1,80)) end end
  for i=0,SLOTS-1 do if not present(box(i)) then boxMon(i,0x10000+i) end end
  local Y=seq(0xD0,5)
  setParty({0,Y[1],Y[2],Y[3],Y[4],Y[5]})
  putBytes(party(0),saved[A[3]])
  F.w8(party(0)+MON_MAIL,MAIL_NONE)
  clearMailbox()
  giveMail(0,0,0x2200,ITEM_HARBOR_MAIL)
  giveMail(1,1,0x3300,ITEM_ORANGE_MAIL)
  local before=mailSnapshot()
  F.check("recall into a full PC is refused and stays in the hub",refusedCross(3,0,"recall_full_pc"))
  partyIs({A[3],Y[1],Y[2],Y[3],Y[4],Y[5]},"refused full-PC recall keeps the party")
  F.check("refused full-PC recall leaves every Mail record untouched",mailSnapshot()==before)
  F.check("refused full-PC recall leaves both holders holding",
    F.r8(party(0)+MON_MAIL)==0 and heldItem(party(0))==ITEM_HARBOR_MAIL
    and F.r8(party(1)+MON_MAIL)==1 and heldItem(party(1))==ITEM_ORANGE_MAIL)

  -- Full mailbox: room in the PC but no free mailbox slot for the stranger's Mail.
  zero(box(SLOTS-1),80)
  setParty({0,Y[1]})
  putBytes(party(0),saved[A[3]])
  F.w8(party(0)+MON_MAIL,MAIL_NONE)
  for i=PARTY_MAIL,MAIL_COUNT-1 do putBytes(mail(i),letter(0x4000+i,ITEM_ORANGE_MAIL)) end
  giveMail(0,0,0x2200,ITEM_HARBOR_MAIL)
  giveMail(1,1,0x3300,ITEM_ORANGE_MAIL)
  before=mailSnapshot()
  F.check("recall with a full mailbox is refused and stays in the hub",refusedCross(3,0,"recall_full_mailbox"))
  partyIs({A[3],Y[1]},"refused full-mailbox recall keeps the party")
  F.check("refused full-mailbox recall leaves every Mail record untouched",mailSnapshot()==before)
  F.check("no crash",not F.crashScreen())
  F.finish()
end)
