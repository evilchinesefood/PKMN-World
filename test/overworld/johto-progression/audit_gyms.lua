-- Staged story handoffs: authored NPC scripts, forced battle wins at action boundary.
package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local F,S,U,X,tap,hook,controller,action=require('bw_helpers')('JohtoGymAudit')
local A=require('audit_symbols');local C=require('constants')
local function cmd(c,a,b,x,y,n)
 F.w16(A.gSpecialVar_0x8006,b or 0);F.w16(A.gSpecialVar_0x8007,x or 0);F.w16(A.gSpecialVar_0x8008,y or 0);hook(c,a,n or 180)
end
local function flag(id)
 local p=F.sb3()+S.SaveBlock3.johtoFlags+(id-0x6000)//8
 return F.r8(p)&(1<<(id%8))~=0
end
local function trainer(id)
 local p,n
 if id>=1727 then p=F.sb3()+S.SaveBlock3.johtoTrainerFlags;n=id-1727
 else p=F.sb1()+S.SaveBlock1.flags;n=0x500+id end
 return F.r8(p+n//8)&(1<<(n%8))~=0
end
local function state(id) return F.r16(F.sb3()+S.SaveBlock3.regionVars+(id-0xa000)*2) end
local function free() return F.ow() and F.r8(S.sGlobalScriptContextStatus)==2 end
local function finish(budget)
 local battled=false
 for i=1,(budget or 600) do
  if F.reportCrash('handoff') then return false,battled end
  if controller('HandleInputChooseAction') then
   battled=true;F.w8(S.gBattleOutcome,1)
   tap('A',1,30)
  elseif free() then F.idle(30);return true,battled
  else tap('A',1,20) end
 end
 F.L(string.format('timeout %d/%d (%d,%d) script=%08x native=%08x mode=%d status=%d',F.grp(),F.mapn(),F.pos(),select(2,F.pos()),F.r32(S.sGlobalScriptContext+8),F.r32(S.sGlobalScriptContext+4),F.r8(S.sGlobalScriptContext+1),F.r8(S.sGlobalScriptContextStatus)))
 F.shot('timeout');return false,battled
end
local function talk()
 F.face('Up');tap('A');return finish()
end
F.run(function()
 assert(F.boot(100));hook(0,tonumber(os.getenv("PW_AUDIT_SPECIES")) or 0)
 F.w8(F.sb2()+S.SaveBlock2.currentRegion,2);F.w32(S.gCurrentRegion,2)
 cmd(3,C.FLAG_SYS_POKEMON_GET)
 cmd(3,0x6103) -- Morty's released-beasts prerequisite, explicitly staged.
 local cases=require('gym_cases')
 local order=os.getenv('PW_AUDIT_ORDER')
 if order then
  local selected={}
  for name in order:gmatch('[^,]+') do for _,c in ipairs(cases) do if c.name==name then selected[#selected+1]=c end end end
  assert(#selected==3);cases=selected
 end
 for _,c in ipairs(cases) do
  if not os.getenv('PW_AUDIT_GYM') or os.getenv('PW_AUDIT_GYM')==c.name then
  F.L('GYM '..c.name);cmd(1,c.g,c.m,c.x,c.y,360)
  F.check(c.name..' positioned beside leader',F.grp()==c.g and F.mapn()==c.m)
  local palettes={}
  for j=0,15 do palettes[#palettes+1]=string.format('%04x',F.r16(U.sSpritePaletteTags+j*2)) end
  F.L('palette tags before talk '..table.concat(palettes,','))
  F.check('arrival has no crash',not F.reportCrash('arrival'))
  local done,battle=talk()
  F.check(c.name..' battle reaches command menu',battle)
  F.check(c.name..' victory script finishes',done)
  assert(done,'cannot continue after locked victory')
  if c.name=='Whitney' then
   F.check('Whitney crying state',state(0xa083)==3)
   -- Walk into her actual exit trigger, then return for the badge.
   assert(F.step('Down'));finish();F.L('Whitney state after exit '..state(0xa083))
   -- The exit trigger is at (15,11); coordinate changes precede tile completion.
   if state(0xa083)==3 then F.step('Down');finish();F.idle(40);finish() end
   F.L(string.format('Whitney after exit coords=(%d,%d) state=%d',F.pos(),select(2,F.pos()),state(0xa083)))
   if state(0xa083)==3 then F.step('Up');F.idle(45);F.step('Down');F.idle(90);finish() end
   F.check('Whitney exit advances badge state',state(0xa083)==4)
   assert(F.leg(c.x,c.y));talk()
  end
  for _,id in ipairs(c.trainers) do F.check(c.name..' gym trainer cleared '..id,trainer(id)) end
  local hoennClean=true
  for _,id in ipairs(c.hoenn) do if trainer(id) then hoennClean=false end end
  F.check(c.name..' preserves all corresponding Hoenn gym trainers',hoennClean)
  if c.name=='Clair' then
   F.check('Clair opens Dragons Den',state(0xa0ab)==2)
  else F.check(c.name..' awards badge',flag(c.badge)) end
  if c.name=='Chuck' then
   tap('Start');assert(F.selectStartIcon(1));tap('A',1,180);F.check('Chuck returns menu control',not F.ow());tap('B');tap('B');F.idle(60)
  else F.check(c.name..' returns movement',F.step('Down')) end
  F.shot(c.name..'_complete')
 end end
 F.finish()
end)
