-- Issue #661: battle weather indicator. Real moves, Bag/Party round trips, every icon,
-- Cloud Nine suppression, sprite exhaustion, battle exit and a repeated battle.
-- Run through run.sh, which supplies the PW_A_* addresses from the ELF.
package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local mode=tonumber(os.getenv('PW_BATTLE_MODE') or '0')
local F,S,U,X,tap,hook,close,tasks,windows=require('swsh_helpers')('Weather'..mode)
local function A(n) return tonumber(assert(os.getenv('PW_A_'..n)),16) end
local WEATHER,CURSOR,TASK,MONS,SPR,V5,V6,V7=A('WEATHER'),A('CURSOR'),A('TASK'),A('MONS'),A('SPRITES'),A('V5'),A('V6'),A('V7')
local function action()
 for i=1,600 do
  if (F.r32(U.gBattlerControllerFuncs)&~1)==U.HandleInputChooseAction then F.idle(40);return true end
  tap('A',1,12)
 end
 return false
end
local function icon() return tasks(TASK) end
-- OBJ palette of the indicator sprite, as a string. A slot taken mid-transition is later
-- overwritten by a battler palette, so the colours must survive a Bag/Party round trip.
local function palsig()
 for i=0,15 do local p=S.gTasks+i*40
  if F.r8(p+4)~=0 and (F.r32(p)&~1)==(TASK&~1) then
   local slot=F.r16(SPR+F.r16(p+8+2)*0x44+4)>>12;local t={}
   for c=1,15 do t[#t+1]=string.format('%04x',F.r16(0x5000200+slot*32+c*2)) end
   return table.concat(t)
  end
 end
 return 'none'
end
local function move(slot) F.w8(CURSOR,slot);tap('A',1,40);F.w8(CURSOR,slot);tap('A',1,30) end
local function bagcycle()
 local c=F.r8(S.gActionSelectionCursor)
 if c&2~=0 then tap('Up') end
 if c&1==0 then tap('Right') end
 tap('A',1,300);assert(tasks(U.Task_BagMenu_HandleInput)==1,'bag did not open')
 local inbag=icon()
 tap('B',1,300);assert(action())
 return inbag
end
local function tofight() local c=F.r8(S.gActionSelectionCursor);if c&1~=0 then tap('Left',1,30) end;if c&2~=0 then tap('Up',1,30) end end
local function poke(bits,name,expect)
 F.w16(WEATHER,bits);F.idle(40)
 F.check(name..(expect==1 and ' shows icon' or ' shows no icon'),icon()==expect);F.shot(name)
end
local function viaparty(name)
 local before=palsig()
 local c=F.r8(S.gActionSelectionCursor)
 if c&1~=0 then tap('Left',1,30) end
 if c&2==0 then tap('Down',1,30) end
 tap('A',1,300);local inmenu=icon()
 tap('B',1,300);assert(action())
 F.check(name..': Party open removes icon',inmenu==0);F.check(name..': Party cancel restores icon',icon()==1);F.check(name..': palette intact after Party',palsig()==before and before~='none');F.shot(name..'_party_return')
end
local function viabag(name)
 local before=palsig();local inbag=bagcycle();F.check(name..': Bag open removes icon',inbag==0);F.check(name..': Bag cancel restores icon',icon()==1);F.check(name..': palette intact after Bag',palsig()==before and before~='none');F.shot(name..'_bag_return')
end
F.run(function()
 assert(F.boot(100));hook(0);hook(43,0,30)
 local abil,monsz,sprsz=F.r16(V5),F.r16(V6),F.r16(V7)
 F.L(string.format('ability off=%d BattlePokemon=%d Sprite=%d',abil,monsz,sprsz))
 hook(13,mode,600)
 F.check('battle ready',action());F.check('no weather, no icon',icon()==0);F.shot('none')
 if mode==0 then
  for i,m in ipairs({'rain','sun','hail','sandstorm'}) do
   move(i-1);F.idle(20);F.check(m..' move: icon hidden once actions are chosen',icon()==0 or i>1);F.shot(m..'_during_move')
   F.check(m..' next turn ready',action());F.check(m..' shows icon',icon()==1);F.shot(m)
  end
  F.check('sandstorm flag set by real move',F.r16(WEATHER)&(1<<5)~=0)
  viabag('sandstorm');viaparty('sandstorm')
  poke(1<<1,'heavy_rain',1);poke(1<<4,'harsh_sun',1);poke(1<<9,'strong_winds',1);poke(1<<8,'fog',1);poke(1<<7,'snow',1);poke(1<<2,'downpour',1)
  poke(0,'cleared',0)
  -- Cloud Nine on the foe suppresses weather effects, so GetWeather() reports none.
  local a=MONS+monsz*1+abil;local old=F.r16(a);F.w16(a,13);poke(1<<0,'cloud_nine_rain',0);F.w16(a,old)
  poke(1<<0,'rain_again',1)
  -- Sprite exhaustion: occupy every free slot, then ask for the icon again.
  local held={}
  assert(sprsz==0x44,'unexpected Sprite size')
  poke(0,'pre_exhaustion',0)
  for i=0,63 do local q=SPR+i*0x44+0x3e;local v=F.r8(q);if v&1==0 then F.w8(q,v|1);held[#held+1]=q end end
  F.w16(WEATHER,1<<3);F.idle(40)
  F.check('sprite exhaustion skips icon, no crash ('..#held..' slots held)',#held>0 and icon()==0 and not F.reportCrash('exhaust'))
  for _,q in ipairs(held) do F.w8(q,F.r8(q)&~1) end
  F.idle(40);F.check('icon appears once a sprite slot frees up',icon()==1);F.shot('after_exhaustion')
 else
  poke(1<<5,'doubles_sandstorm',1);viabag('doubles_sandstorm');poke(1<<7,'doubles_snow',1);viabag('doubles_snow');poke(1<<0,'doubles_rain',1)
  tofight();tap('A',1,60);F.check('icon stays during move selection',icon()==1);F.shot('doubles_move_menu');tap('B',1,60)
 end
 tofight();F.w8(S.gBattleOutcome,1)
 for i=1,180 do if F.ow() then break end;tap('A',1,20) end
 F.check('battle exit reaches field',F.ow());F.check('no icon task after battle',icon()==0);assert(not F.reportCrash('exit'))
 hook(13,mode,600);F.check('second battle ready',action());F.check('second battle starts with no icon',icon()==0);F.shot('second_battle')
 F.finish()
end)
