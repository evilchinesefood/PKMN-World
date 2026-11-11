local here=(debug.getinfo(1,"S").source:sub(2)):match("^(.*[/\\])") or ""
package.path=here.."?.lua;"..package.path
local S=require("symbols")
local F=require("lib").new(S,"FamilyBattleOptions")
local function tap(k) F.press(k,2);F.idle(12) end
local function flag(n)
 local a=F.sb1()+S.SaveBlock1.flags+n//8
 F.w8(a,F.r8(a)|(1<<(n%8)))
end
local function giveMon(h,t,o)
 F.dbg();F.sel(3);F.sel(1);F.idle(20)
 F.spin(h,t,o);F.idle(20);F.spin(1,0,0);F.idle(60);F.bOut(4)
end
local function actionReady()
 local fn=F.r32(S.gBattlerControllerFuncs)&~1
 for _,p in ipairs(S.ActionInputFunctions) do if fn==p then return true end end
 return false
end
local function awaitAction()
 for _=1,400 do
  if actionReady() then return true end
  F.press("A",2);F.idle(10)
 end
 return false
end
local function text()
 local a=S.gDisplayedStringBattle
 local t={}
 for i=0,399 do
  local b=F.r8(a+i)
  if b==255 then break end
  if b>=161 and b<=170 then t[#t+1]=string.char(48+b-161)
  elseif b>=187 and b<=212 then t[#t+1]=string.char(65+b-187)
  elseif b>=213 and b<=238 then t[#t+1]=string.char(97+b-213)
  elseif b==0 or b==254 or b==250 or b==251 then t[#t+1]=" " end
 end
 return table.concat(t)
end
local function launch(style)
 local a=F.sb2()+S.SaveBlock2.optionsU16
 F.w16(a,(F.r16(a)&~0x207)|3|(style<<9))
 F.w16(F.sb2()+S.SaveBlock2.ratesU16,F.r16(F.sb2()+S.SaveBlock2.ratesU16)|0x310)
 if not F.route({{6,4},{6,10},{9,10}},"terminal") then return false end
 F.face("Up");tap("A")
 if not F.pick(1,"leader",10) or not F.pick(0,"hoenn",12) or not F.pick(0,"roxanne",12) then return false end
 return awaitAction()
end
local function bagQty()
 local ptr=F.r32(S.gBagPockets)
 local key=F.r32(F.sb2()+S.SaveBlock2.encryptionKey)&0xFFFF
 for i=0,F.pocketCap(0)-1 do if F.r16(ptr+i*4)==28 then return F.r16(ptr+i*4+2)~key end end
 return 0
end
local function testBag()
 local mx=F.r16(S.gBattleMons+S.BattlePokemon.maxHP)
 local before=mx-40
 F.w16(S.gBattleMons+S.BattlePokemon.hp,before)
 F.w16(S.gParties+S.Pokemon.hp,before)
 tap("Up");tap("Left");tap("Right");tap("A");F.idle(100)
 F.check("old Hard Mode bit permits trainer battle Bag",F.cb2()==S.CB2_BagMenuRun or F.cb2()==S.CB2_Bag,"cb="..string.format("%08X",F.cb2()))
 F.shot("trainer_bag")
 local peak=before
 for i=1,500 do
  if i%18==1 then F.press("A",2) else F.idle(1) end
  local hp=F.r16(S.gBattleMons+S.BattlePokemon.hp)
  if hp>peak then peak=hp end
  if bagQty()==2 and actionReady() then break end
 end
 F.check("Potion consumed in trainer battle",bagQty()==2,"quantity="..bagQty())
 F.check("Potion healed twenty HP",peak>=before+20,"before="..before.." peak="..peak)
 return awaitAction()
end
local function knockout(style)
 local opponent=F.r16(S.gBattlerPartyIndexes+2)
 F.w16(S.gBattleMons+S.BattlePokemon.moves,129)
 F.w8(S.gBattleMons+S.BattlePokemon.pp,20)
 F.w16(S.gBattleMons+S.BattlePokemon.size+S.BattlePokemon.hp,1)
 F.w16(S.gParties+6*S.Pokemon.size+opponent*S.Pokemon.size+S.Pokemon.hp,1)
 tap("Up");tap("Left");tap("A")
 for i=1,200 do if (F.r32(S.gBattlerControllerFuncs)&~1)==S.HandleInputChooseMove then break end F.idle(1) end
 tap("Up");tap("Left");tap("A")
 local sawPrompt=false
 for i=1,1800 do
  local shown=text()
  if shown:find("Will you switch") then
   if not sawPrompt then F.shot("shift_prompt") end
   sawPrompt=true
   F.idle(30)
   F.press("B",2);F.idle(30)
  elseif F.r16(S.gBattlerPartyIndexes+2)~=opponent and actionReady() then break
  elseif i%20==0 then F.press("A",2) end
  F.idle(1)
 end
 F.shot("after_knockout")
 F.check(style==0 and "Shift offers switching after an opponent faints" or "Set sends the next opponent without a switch prompt",sawPrompt==(style==0))
 F.check("next opponent enters",F.r16(S.gBattlerPartyIndexes+2)~=opponent)
 return awaitAction()
end
local function finishBattle(win)
 local money=F.money()
 local base=win and 6*S.Pokemon.size or 0
 for i=0,5 do F.w16(S.gParties+base+i*S.Pokemon.size+S.Pokemon.hp,0) end
 F.w16(S.gBattleMons+(win and S.BattlePokemon.size or 0)+S.BattlePokemon.hp,0)
 for i=1,600 do if F.ow() then break end F.press("A",8);F.idle(6) end
 F.check("leader simulation returns to field",F.ow())
 F.check("simulation outcome is "..(win and "win" or "loss"),F.outcome()==(win and 1 or 2),"outcome="..F.outcome())
 F.check(win and "leader simulation win leaves wallet unchanged" or "leader simulation defeat remains free at 2x Money Loss",F.money()==money,"before="..money.." after="..F.money())
 F.pick(1,"no_retry",20);F.idle(90);F.dismiss(20);F.ensureFree()
end
local function testForfeit()
 for id=0x94F,0x956 do
  local a=F.sb1()+S.SaveBlock1.flags+id//8
  F.w8(a,F.r8(a)&~(1<<(id%8)))
 end
 F.check("launch existing charged leader-forfeit path",launch(1))
 if not actionReady() then return end
 local before=F.money()
 tap("Down");tap("Right");tap("A")
 local confirmation=false
 for i=1,120 do
  if (F.r32(S.gBattlerControllerFuncs)&~1)==S.PlayerHandleYesNoInput then confirmation=true;break end
  F.press("A",2);F.idle(12)
 end
 if not F.check("forfeit reaches real confirmation",confirmation) then return end
 tap("Up");tap("A")
 local displayed=false
 for i=1,600 do
  if text():find("1600") then displayed=true end
  if F.ow() then break end
  F.press("A",8);F.idle(6)
 end
 F.check("forfeit returns to field",F.ow())
 F.check("forfeit outcome retained",F.outcome()==9,"outcome="..F.outcome())
 F.check("2x scales existing 800 forfeit charge to 1600",F.money()==before-1600,"before="..before.." after="..F.money())
 F.check("forfeit message displays actual 1600 deduction",displayed)
 F.shot("forfeit_2x")
end
F.run(function()
 if not F.boot(100) then F.check("boot",false);F.finish();return end
 giveMon(3,7,5);giveMon(0,0,1);flag(0xA4A)
 for id=0x94F,0x956 do flag(id) end
 F.w8(F.sb2()+S.SaveBlock2.currentRegion,3);F.w32(S.gCurrentRegion,3)
 local ptr=F.r32(S.gBagPockets)
 F.w16(ptr,28);F.w16(ptr+2,3~(F.r32(F.sb2()+S.SaveBlock2.encryptionKey)&0xFFFF))
 F.w32(F.sb1()+S.SaveBlock1.money,50000~F.r32(F.sb2()+S.SaveBlock2.encryptionKey))
 for style=0,1 do
  F.check("launch leader trainer with style "..style,launch(style))
  if not actionReady() then F.finish();return end
  F.check("old difficulty bit remains set",(F.r16(F.sb2()+S.SaveBlock2.ratesU16)&0x10)~=0)
  F.check("battle style matches independently selected value",F.r8(S.gBattleScripting+S.BattleScripting.battleStyle)==style)
  F.check("battle uses Instant text selection",(F.r16(F.sb2()+S.SaveBlock2.optionsU16)&7)==3)
  if style==0 then testBag() end
  knockout(style)
  finishBattle(style==1)
 end
 testForfeit()
 F.finish()
end)
