local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "FamilyOptions")
local rows = {
  {name="Text Speed", row=0, slot=1, values={0,1,2,3}, word=0x14, shift=0, mask=7},
  {name="Exp Rate", row=8, slot=13, values={1,0,2,3}, word=0x16, shift=0, mask=3},
  {name="Catch Rate", row=9, slot=14, values={3,0,1,2}, word=0x16, shift=2, mask=3},
  {name="Encounter Rate", row=10, slot=2, values={1,0,2,3}, word=0x16, shift=6, mask=3},
  {name="Money Loss", row=11, slot=4, values={1,0,2,3}, word=0x16, shift=8, mask=3},
}
local function tap(key) F.press(key,2);F.idle(12) end
local function walletAndBag()
  local key=F.r32(F.sb2()+S.SaveBlock2.encryptionKey)
  local result={tostring(F.r32(F.sb1()+S.SaveBlock1.money)~key)}
  for pocket=0,4 do
    local ptr=F.r32(S.gBagPockets+pocket*S.BagPocket.stride)
    for slot=0,F.pocketCap(pocket)-1 do
      result[#result+1]=string.format("%d/%d",F.r16(ptr+slot*4),F.r16(ptr+slot*4+2)~(key&65535))
    end
  end
  return table.concat(result,",")
end
local function task()
  for i=0,S.Task.count-1 do
    local address=S.gTasks+i*S.Task.stride
    if F.r8(address+S.Task.isActive)~=0 and (F.r32(address+S.Task.func)&~1)==S.Task_OptionMenuProcessInput then return address end
  end
end
local function staged(row) local t=task();return t and F.r16(t+S.Task.data+row.slot*2) or -1 end
local function saved(row) return (F.r16(F.sb2()+row.word)>>row.shift)&row.mask end
local function openOptions()
  if not F.ensureFree() then return false end
  tap("Start");F.idle(50)
  if not F.selectStartIcon(9) then return false end
  tap("A")
  for _=1,100 do if task() then F.idle(20);return true end F.idle(4) end
  F.shot("options_missing")
  return false
end
local function closeOptions()
  tap("B");F.idle(90);tap("B");F.idle(30)
  return F.ow() and F.ensureFree()
end
local function selectRow(row)
  for _=1,20 do
    local t=task()
    if not t then return false end
    local current=F.r16(t+S.Task.data)
    if current==row.row then return true end
    tap(current>row.row and "Up" or "Down")
  end
  return false
end
local function setValue(row,value)
  if not selectRow(row) then return false end
  for _=1,4 do if staged(row)==value then return true end tap("Right") end
  return staged(row)==value
end
local function preferences()
  return F.r16(F.sb2()+0x14),F.r16(F.sb2()+0x16),F.r8(F.sb2()+0x13)
end
local function checkPreferences(tag,a,b,c)
  local x,y,z=preferences()
  F.check(tag,x==a and y==b and z==c,string.format("%04X/%04X/%02X expected %04X/%04X/%02X",x,y,z,a,b,c))
end
local function flag(id)
  local base,offset=F.sb1()+S.SaveBlock1.flags,id
  if id>=0x6000 then base=F.sb3()+S.SaveBlock3.johtoFlags;offset=id-0x6000 end
  local a=base+offset//8
  F.w8(a,F.r8(a)|(1<<(offset%8)))
end
local function scriptMenu()
  for i=0,S.Task.count-1 do
    local a=S.gTasks+i*S.Task.stride
    local fn=F.r32(a+S.Task.func)&~1
    if F.r8(a+S.Task.isActive)~=0 and (fn==S.Task_HandleYesNoInput or fn==S.Task_HandleMultichoiceInput or fn==S.Task_CallYesOrNoCallback) then return true end
  end
  return false
end
local function choose(value)
  for _=1,70 do
    if scriptMenu() then
      F.idle(12)
      for _=1,10 do
        local c=F.mcur()
        if c==value then tap("A");F.idle(40);return true end
        tap(c>value and "Up" or "Down")
      end
      return false
    end
    tap("A");F.idle(12)
  end
  return false
end
local function awaitMap(group,map)
  for _=1,220 do
    if F.grp()==group and F.mapn()==map then F.idle(100);return true end
    if F.reportCrash("travel") then return false end
    tap("A")
  end
  return false
end
local function cross(region)
  local gateX=({11,16,21})[region]
  if not F.route({{16,4},{gateX,4},{gateX,3}},"gate_"..region) then return false end
  F.face("Up");tap("A");F.idle(60)
  if not choose(1) or not choose(1) or not choose(0) then return false end
  local destination=({{37,5},{84,23},{9,9}})[region]
  return awaitMap(destination[1],destination[2])
end

F.run(function()
  if not F.boot(100) then F.check("fresh game reaches hub",false);F.finish();return end
  F.check("new game keeps Mid text",saved(rows[1])==1)
  F.check("new Encounter Rate defaults to 1x",saved(rows[4])==0)
  F.check("new Money Loss defaults to 1x",saved(rows[5])==0)
  F.w16(F.sb2()+0x16,F.r16(F.sb2()+0x16)|0x10)
  local initialA,initialB,initialC=preferences()
  local moneyAndBag=walletAndBag()
  F.check("Options opens through Start menu",openOptions())
  if not task() then F.finish();return end
  for _,row in ipairs(rows) do
    F.check(row.name.." row reachable",selectRow(row))
    local start=staged(row)
    local column
    for i,value in ipairs(row.values) do if start==value then column=i end end
    if not column then F.check(row.name.." valid starting value",false);F.finish();return end
    for _,direction in ipairs({"Right","Left"}) do
      for step=1,4 do
        column=((column-1+(direction=="Right" and 1 or -1))%4)+1
        tap(direction)
        F.check(row.name.." "..direction.." step "..step,staged(row)==row.values[column],"stored="..staged(row))
        F.check(row.name.." selection stays staged until exit",saved(row)==start)
      end
    end
    F.shot(row.name:gsub(" ","_").."_choices")
  end
  for _,row in ipairs(rows) do F.check(row.name.." select third displayed choice",setValue(row,row.values[3])) end
  F.check("select Instant",setValue(rows[1],3))
  F.shot("Instant_selected")
  F.check("Options exit returns to field",closeOptions())
  for _,row in ipairs(rows) do
    local expected=row.row==0 and 3 or row.values[3]
    F.check(row.name.." persisted on exit",saved(row)==expected,"stored="..saved(row))
  end
  local a,b,c=preferences()
  F.check("unrelated first-word preferences preserved",(a&0xFFF8)==(initialA&0xFFF8))
  F.check("deprecated bit and Nicknames preserved",(b&0xFC30)==(initialB&0xFC30))
  F.check("button mode preserved",c==initialC)
  F.check("Options leaves money and bag unchanged",walletAndBag()==moneyAndBag)
  F.check("Options reopens",openOptions())
  for _,row in ipairs(rows) do
    F.check(row.name.." reopens at saved value",staged(row)==saved(row))
  end
  F.shot("reopened_Instant")
  closeOptions()
  checkPreferences("reopening changes no preferences",a,b,c)
  tap("Start");F.idle(50)
  F.check("Save action available",F.selectStartIcon(7))
  for _=1,8 do tap("A");F.idle(90) end
  F.idle(300);tap("B");F.idle(30)
  client.reboot_core();F.idle(240)
  F.check("Continue after real save",F.boot(nil,true))
  checkPreferences("all preferences survive save and Continue",a,b,c)
  F.ensureFree()
  for _,id in ipairs({0xDCF,0x51,0xA4B,0x63F8,0x94F}) do flag(id) end
  F.w8(F.sb2()+S.SaveBlock2.introDoneBits,7)
  F.dbg();F.idle(40);F.sel(2);F.idle(40)
  for _=1,9 do tap("Down") end
  tap("A");F.idle(180);F.bOut(6);F.idle(60);F.ensureFree()
  for _,region in ipairs({3,1,2}) do
    local arrived=cross(region)
    F.check("travel into region "..region,arrived)
    checkPreferences("global preferences survive region "..region,a,b,c)
    if not arrived then F.shot("travel_failed");break end
    F.w16(F.sb1()+S.SaveBlock1.registeredItem,893)
    tap("Select");F.idle(90)
    F.check("Hub Pass confirmation region "..region,choose(0))
    F.check("return to hub from region "..region,awaitMap(100,0))
    F.ensureFree()
  end
  checkPreferences("preferences remain global after all three regions",a,b,c)
  F.finish()
end)
