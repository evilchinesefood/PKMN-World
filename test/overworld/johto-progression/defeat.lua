-- Isolated first-home recovery fixture. Debug party/battle, RAM faint to target recovery.
local root=(debug.getinfo(1,'S').source:sub(2)):match('^(.*[/\\])')..'../lua/'
package.path=root..'?.lua;'..package.path
local S=require('symbols');local F=require('lib').new(S,'JohtoDefeat357')
F.run(function()
 assert(F.boot(100))
 local gender=tonumber(os.getenv('PW_357_GENDER')) or 0
 F.w8(F.sb2()+S.SaveBlock2.playerGender,gender)
 F.check('fixture gender applied',F.r8(F.sb2()+S.SaveBlock2.playerGender)==gender)
 F.dbg();F.sel(2);F.sel(9);F.bOut(4)
 F.check('fixture party created',F.r8(S.gPartiesCount)>0)
 F.w8(F.sb2()+S.SaveBlock2.currentRegion,2);F.w32(S.gCurrentRegion,2)
 for _,state in ipairs({0,2,5}) do
 F.w16(F.sb3()+S.SaveBlock3.regionVars+0x80*2,state)
 assert(F.warpTo(0,7,5,0,0,0,0,0,0,75,0,'newbark'))
 F.dismiss(60)
 local h=F.sb1()+S.SaveBlock1.lastHealLocation
 F.w8(h,75);F.w8(h+1,0);F.w8(h+2,255);F.w16(h+4,20);F.w16(h+6,12)
 F.dbg();F.sel(2);F.sel(10);F.idle(240)
 F.check('battle started',not F.ow())
 for i=1,2000 do
  if F.ow() then break end
  for j=0,5 do F.w16(S.gParties+j*S.Pokemon.size+S.Pokemon.hp,0) end
  F.w16(S.gBattleMons+S.BattlePokemon.hp,0)
  F.w8(S.gBattleOutcome,2)
  F.press('A',2);F.idle(4)
 end
 for i=1,300 do F.press('B',2);F.idle(20) end
 F.L(string.format('landing=%d/%d pos=(%d,%d) script=%08x native=%08x mode=%d status=%d',F.grp(),F.mapn(),F.pos(),select(2,F.pos()),F.r32(S.sGlobalScriptContext+8),F.r32(S.sGlobalScriptContext+4),F.r8(S.sGlobalScriptContext+1),F.r8(S.sGlobalScriptContextStatus)))
 F.shot('recovery_state_'..state)
 F.check('respawn is New Bark home',F.grp()==76 and F.mapn()==3)
 F.check('home defeat returns control',F.step('Down'))
 F.check('party is healed',F.r16(S.gParties+S.Pokemon.hp)>0)
 F.check('recovery script finished in state '..state,F.r8(S.sGlobalScriptContextStatus)==2)
 end
 F.finish()
end)
