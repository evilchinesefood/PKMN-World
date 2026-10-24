package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
return function(name)
 local F,S,U,X,tap,hook,controller=require('bw_helpers')(name)
 local A=require('audit_symbols');local C=require('constants')
 local function cmd(c,a,b,x,y,n)
  F.w16(A.gSpecialVar_0x8006,b or 0);F.w16(A.gSpecialVar_0x8007,x or 0);F.w16(A.gSpecialVar_0x8008,y or 0);hook(c,a,n or 60)
 end
 local function state(id) return F.r16(F.sb3()+S.SaveBlock3.regionVars+(id-0xa000)*2) end
 local function free() return F.ow() and F.r8(S.sGlobalScriptContextStatus)==2 end
 local function flag(id)
  local p,n
  if id>=0x6000 and id<=0x63ff then p=F.sb3()+S.SaveBlock3.johtoFlags;n=id-0x6000
  else p=F.sb1()+S.SaveBlock1.flags;n=id end
  return F.r8(p+n//8)&(1<<(n%8))~=0
 end
 local function finish(budget)
  local battles=0;local inBattle=false
  F.idle(45)
  for i=1,(budget or 1000) do
   if F.reportCrash('handoff') then return false,battles end
   if controller('HandleInputChooseAction') then
    if not inBattle then battles=battles+1;inBattle=true end
    F.w8(S.gBattleOutcome,1);tap('A',1,30)
   elseif free() then F.idle(60);if free() then return true,battles end
   elseif F.cb2()==S.CB2_NamingScreen then tap('Start');tap('A')
   else
    if F.ow() then inBattle=false end
    -- Choose the correct third/fifth shrine answers through the real menu.
    local menu=false
    for j=0,S.Task.count-1 do
     local t=S.gTasks+j*S.Task.stride
     if F.r8(t+S.Task.isActive)~=0 and (F.r32(t)&~1)==A.Task_HandleMultichoiceInput then
      menu=true;F.idle(30)
      local p=F.r32(S.sGlobalScriptContext+8);local index=0
      if p>=A.DragonsDen_Shrine_EventScript_ElderQuiz3 and p<A.DragonsDen_Shrine_EventScript_ElderQuiz3Correct then index=1 end
      if p>=A.DragonsDen_Shrine_EventScript_ElderQuiz5 and p<A.DragonsDen_Shrine_EventScript_ElderWrong then index=2 end
      for k=1,index do tap('Down',1,12) end
      tap('A',1,30);break
     end
    end
    if not menu then tap('A',1,20) end
   end
  end
  F.L(string.format('timeout map=%d/%d (%d,%d) cb2=%08x script=%08x native=%08x status=%d',F.grp(),F.mapn(),F.pos(),select(2,F.pos()),F.cb2(),F.r32(S.sGlobalScriptContext+8),F.r32(S.sGlobalScriptContext+4),F.r8(S.sGlobalScriptContextStatus)))
  F.shot('timeout');return false,battles
 end
 local function boot()
  assert(F.boot(100));hook(0,152)
  F.w8(F.sb2()+S.SaveBlock2.currentRegion,2);F.w32(S.gCurrentRegion,2)
 end
 return {F=F,S=S,A=A,C=C,tap=tap,cmd=cmd,state=state,flag=flag,finish=finish,free=free,boot=boot}
end
