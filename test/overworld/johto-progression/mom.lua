-- Isolated event-state fixture: debug warps/region RAM seed; dialogue uses real input.
local root=(debug.getinfo(1,'S').source:sub(2)):match('^(.*[/\\])')..'../lua/'
package.path=root..'?.lua;'..package.path
local S=require('symbols');local F=require('lib').new(S,'JohtoMom357')
local function flag(n,v)
 local a=F.sb3()+S.SaveBlock3.johtoFlags+n//8
 F.w8(a,v and (F.r8(a)|(1<<(n%8))) or (F.r8(a)&~(1<<(n%8))))
end
local function stage(state,visited,started)
 F.w16(F.sb3()+S.SaveBlock3.regionVars+0x80*2,state)
 flag(0x24,visited);flag(0x20,started)
 F.w8(F.sb2()+S.SaveBlock2.currentRegion,2);F.w32(S.gCurrentRegion,2)
 assert(F.warpTo(0,7,6,0,0,3,0,0,0,76,3,'mom_'..state))
end
F.run(function()
 assert(F.boot(100))
 local gender=tonumber(os.getenv('PW_357_GENDER')) or 0
 F.w8(F.sb2()+S.SaveBlock2.playerGender,gender)
 F.check('fixture gender applied',F.r8(F.sb2()+S.SaveBlock2.playerGender)==gender)
 F.dbg();F.sel(2);F.sel(9);F.bOut(4)
 F.check('fixture party exists',F.r8(S.gPartiesCount)>0)
 for _,c in ipairs({{0,false,false},{2,false,false},{4,false,true},{5,true,true}}) do
  stage(table.unpack(c));local state=c[1]
  if state==2 then assert(F.leg(9,6));assert(F.leg(8,6));assert(F.leg(8,5));F.face('Up')
  else assert(F.leg(9,6));assert(F.leg(3,6));assert(F.leg(3,2));F.face('Left') end
  if c[2] then F.w16(S.gParties+S.Pokemon.hp,1) end
  F.press('A',2);F.idle(20)
  F.check('Mom state '..state..' starts dialogue',F.r8(S.sGlobalScriptContextStatus)~=2)
  for i=1,200 do F.press('B',2);F.idle(20) end
  F.L(string.format('state=%d script=%08x native=%08x mode=%d status=%d',state,F.r32(S.sGlobalScriptContext+8),F.r32(S.sGlobalScriptContext+4),F.r8(S.sGlobalScriptContext+1),F.r8(S.sGlobalScriptContextStatus)))
  F.shot('state_'..state)
  local free=F.step('Down');if free then F.step('Up') end;F.check('Mom state '..state..' returns player control',free)
  if c[2] then F.check('Mom heals the injured party',F.r16(S.gParties+S.Pokemon.hp)==F.r16(S.gParties+S.Pokemon.maxHP)) end
  if state==4 then F.check('Good luck advances story',F.r16(F.sb3()+S.SaveBlock3.regionVars+0x80*2)==5) end
  if not free then F.finish();return end
 end
 F.finish()
end)
