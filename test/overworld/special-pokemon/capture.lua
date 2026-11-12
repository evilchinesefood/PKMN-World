local here=debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])') or ''
package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..here..'?.lua;'..package.path
local H=require('sources_lib')('SpecialPokemonCapture')
local F,S,X=H.F,H.S,H.X
local C=require('capture_symbols')
local function tap(key,frames) F.press(key,2);F.idle(frames or 20) end
local function controller(name)
    return (F.r32(S.gMain+4)&~1)==C.BattleMainCB2
        and (F.r32(C.gBattlerControllerFuncs)&~1)==C[name]
end
local function action()
    for _=1,500 do
        if controller('HandleInputChooseAction') then F.idle(20);return end
        tap('A',10)
    end
    F.shot('battle_action_timeout')
    error('battle did not reach action input')
end
local function start(name)
    H.begin(name)
    action()
    F.shot(name..'_battle')
end
local function finish(expected)
    for _=1,1000 do
        if H.idle() then
            F.check('battle outcome '..expected,F.r8(S.gBattleOutcome)==expected)
            return
        end
        tap('B',12)
    end
    F.shot('battle_finish_timeout')
    error('battle did not return field control')
end
local function chooseAction(index)
    assert(controller('HandleInputChooseAction'))
    local cursor=F.r8(S.gActionSelectionCursor)
    if (cursor&1)~=(index&1) then tap((index&1)==0 and 'Left' or 'Right') end
    if (cursor&2)~=(index&2) then tap((index&2)==0 and 'Up' or 'Down') end
    tap('A')
end
local function fight()
    chooseAction(0)
    for _=1,120 do
        if controller('HandleInputChooseMove') then F.idle(30);tap('A',60);return end
        F.idle(5)
    end
    error('move menu did not open')
end
local function caught(name,mark)
    start(name)
    F.check(name..': prepared source is not collected before capture',not H.flag(mark))
    F.check(name..': normal ball shortcut available',F.r8(C.gLastUsedBallMenuPresent)~=0)
    F.press('R',4)
    F.idle(300)
    finish(7)
    F.check(name..': successful catch marks checklist',H.flag(mark))
end
F.run(function()
    assert(F.boot(100))
    H.invoke(0)
    H.invoke(3)
    H.talk('Surfer',true)
    start('Surfboard')
    chooseAction(3)
    finish(4)
    F.check('running preserves source without collection',H.flag(0xDDB) and not H.flag(0xDD1))
    start('Surfboard')
    fight()
    finish(1)
    F.check('target faint preserves source without collection',H.flag(0xDDB) and not H.flag(0xDD1))
    H.invoke(4)
    start('Surfboard')
    for _=1,40 do
        if H.idle() then break end
        if controller('HandleInputChooseAction') then fight() else tap('A',20) end
    end
    finish(2)
    F.check('defeat preserves source without collection',H.flag(0xDDB) and not H.flag(0xDD1))
    H.invoke(3)
    caught('Surfboard',0xDD1)
    H.talk('PirateSailor',true)
    caught('Pirate',0xDD7)
    H.invoke(5)
    F.check('two captures remain in actual ownership',F.r16(S.gSpecialVar_Result)==66 and F.r16(X.gSpecialVar_0x8005)==2)
    H.invoke(2,0,1200)
    F.check('ordinary save succeeded',F.r16(X.gSpecialVar_0x8005)==1)
    client.reboot_core()
    F.idle(5)
    assert(F.boot(nil,true),'Continue did not reach field')
    F.idle(120)
    F.check('Continue retains capture marks',H.flag(0xDD1) and H.flag(0xDD7))
    H.invoke(5)
    F.check('Continue retains two owned captures',F.r16(S.gSpecialVar_Result)==66 and F.r16(X.gSpecialVar_0x8005)==2)
    H.talk('BalloonSeller',false)
    start('Surfboard')
    F.press('R',4)
    F.idle(300)
    finish(7)
    H.invoke(5)
    F.check('regional map revisit allows repeat catch',F.r16(S.gSpecialVar_Result)==66 and F.r16(X.gSpecialVar_0x8005)==3)
    F.finish()
end)
