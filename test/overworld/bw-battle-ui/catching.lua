package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local F,S,U,X,tap,hook,controller,action,exitBattle=require('bw_helpers')('BWCatching')
local function keys(k,n) for i=1,n do joypad.set(k);emu.frameadvance() end end
F.run(function()
 assert(F.boot(100));hook(0);hook(4,0,300);hook(1,0,600);assert(action())
 keys({R=true},4);keys({R=true,Right=true},4);keys({R=true},45);F.shot('cycle_great');F.idle(45)
 F.check('cycle release stays at commands',controller('HandleInputChooseAction'))
 F.check('cycle selected Great Ball',F.r16(U.gBallToDisplay)==2)
 hook(111,0,1);F.check('cycle release consumed no ball',F.r16(X.gSpecialVar_0x8005)==5 and F.r16(U.gSpecialVar_0x8006)==5)
 keys({R=true},4);keys({R=true,B=true},4);F.idle(60)
 F.check('B cancels shortcut without leaving commands',controller('HandleInputChooseAction'))
 hook(111,0,1);F.check('shortcut cancellation consumed no ball',F.r16(U.gSpecialVar_0x8006)==5)
 F.press('R',4);F.idle(480)
 for i=1,400 do
  if F.ow() or controller('HandleInputChooseAction') then break end
  tap('B',1,24)
 end
 F.shot('throw_resolved');F.check('Great Ball throw resolves',F.ow() or controller('HandleInputChooseAction'))
 if not F.ow() then assert(exitBattle()) end
 hook(2);F.check('one Great Ball consumed',F.r16(U.gSpecialVar_0x8007)==4)
 hook(13);local boxCount=F.r16(X.gSpecialVar_0x8005)
 hook(12);hook(1,0,600);assert(action());F.shot('last_ball_ready')
 F.press('R',4)
 for i=1,180 do F.idle(3);F.shot('capture_'..string.format('%03d',i)) end
 for i=1,300 do
  if F.ow() then break end
  tap('B',1,24)
 end
 F.check('successful capture returns to field',F.ow());assert(F.ow());hook(13)
 F.check('last Master Ball consumed',F.r16(U.gSpecialVar_0x8006)==0)
 F.check('full-party capture stored in box',F.r16(X.gSpecialVar_0x8005)==boxCount+1)
 hook(1,0,600);assert(action());F.shot('no_balls')
 F.check('no shortcut after last ball depleted',F.r8(U.gLastUsedBallMenuPresent)==0)
 F.press('R',4);F.idle(90);F.check('R unavailable with empty ball pocket',controller('HandleInputChooseAction'))
 assert(exitBattle());hook(0);hook(3,0,600);assert(action())
 F.check('shortcut unavailable in trainer battle',F.r8(U.gLastUsedBallMenuPresent)==0)
 F.press('R',4);F.idle(90);F.check('R leaves trainer command input intact',controller('HandleInputChooseAction'))
 assert(exitBattle());F.finish()
end)
