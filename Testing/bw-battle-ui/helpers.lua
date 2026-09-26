local S=require('symbols');local X=require('feature_symbols');local U=require('bw_symbols')
return function(name)
 local F=require('lib').new(S,name)
 local function tap(k,n,delay) for i=1,(n or 1) do F.press(k,4);F.idle(delay or 45) end end
 local function hook(c,a,wait)
  assert(c>=100 or F.ow(),'fixture must start from the field')
  F.w16(S.gSpecialVar_0x8004,c);F.w16(X.gSpecialVar_0x8005,a or 0);F.w32(S.gMain+4,X.hook);F.idle(wait or 180)
 end
 local function controller(fn,battler)
  return (F.r32(S.gMain+4)&~1)==U.BattleMainCB2 and (F.r32(U.gBattlerControllerFuncs+(battler or 0)*4)&~1)==(U[fn]&~1)
 end
 local function action()
  for i=1,400 do
   if controller('HandleInputChooseAction') then F.idle(30);return true end
   tap('A',1,12)
  end
  F.shot('action_timeout');return false
 end
 local function exitBattle()
  assert(controller('HandleInputChooseAction'),'exit requires the command menu')
  local c=F.r8(S.gActionSelectionCursor)
  if F.battleFlags()&8~=0 then
   -- Debug multi trainers cannot flee; finish at a controller boundary.
   F.w8(S.gBattleOutcome,1)
   if c&1~=0 then tap('Left') end
   if c&2~=0 then tap('Up') end
  else
   if c&1==0 then tap('Right') end
   if c&2==0 then tap('Down') end
  end
  tap('A',1,120)
  for i=1,200 do if F.ow() then return true end;tap('A',1,20) end
  F.shot('exit_timeout');F.L(string.format('exit callback=%x outcome=%d',F.r32(S.gMain+4),F.r8(S.gBattleOutcome)))
  return false
 end
 return F,S,U,X,tap,hook,controller,action,exitBattle
end
