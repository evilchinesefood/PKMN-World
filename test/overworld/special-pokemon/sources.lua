local here = debug.getinfo(1, 'S').source:sub(2):match('^(.*[/\\])') or ''
package.path = assert(os.getenv('PW_FEATURE_LIB')) .. '/?.lua;' .. here .. '?.lua;' .. package.path
local S, X, D = require('symbols'), require('feature_symbols'), require('sources_data')
local F = require('lib').new(S, 'SpecialPokemonSources')
local function idle()
    return F.ow() and F.r8(S.sGlobalScriptContextStatus) == 2
end
local function invoke(command, arg, frames)
    assert(idle(), 'fixture requires idle field control')
    F.w16(S.gSpecialVar_0x8004, command)
    F.w16(X.gSpecialVar_0x8005, arg or 0)
    F.w32(S.gMain + 4, X.hook)
    F.idle(frames or 60)
end
local function flag(id)
    return (F.r8(F.sb1() + S.SaveBlock1.flags + (id // 8)) & (1 << (id % 8))) ~= 0
end
local function object(localId)
    for i = 0, 15 do
        local b = S.gObjectEvents + i * S.ObjectEvent.stride
        if (F.r8(b) & 1) ~= 0 and F.r8(b + S.ObjectEvent.localId) == localId then
            return F.rs16(b + S.ObjectEvent.x) - 7, F.rs16(b + S.ObjectEvent.y) - 7
        end
    end
end
local function talk(name, accept)
    local row = assert(D[name])
    invoke(1, row.index, 180)
    for _=1,120 do
        if idle() then break end
        F.press('B',2); F.idle(10)
    end
    assert(idle(), name .. ': warp returned field control')
    local ox, oy = object(row.localId)
    assert(ox, name .. ': source object spawned')
    local px, py = F.pos()
    if math.abs(px - ox) + math.abs(py - oy) ~= 1 then
        assert(F.leg(ox, oy + 1), name .. ': reach wandering source')
        px, py = F.pos()
    end
    F.face(px < ox and 'Right' or px > ox and 'Left' or py < oy and 'Down' or 'Up')
    F.press('A', 2)
    F.idle(10)
    assert(not idle(), name .. ': actual interaction started')
    F.shot(name)
    for _ = 1, 500 do
        if idle() then
            F.check(name .. ': interaction returned control', true)
            return
        end
        F.press(accept and 'A' or 'B', 2)
        F.idle(10)
    end
    error(name .. ': interaction did not finish')
end
F.run(function()
    assert(F.boot(100))
    invoke(0)
    talk('ClassicCapTrainer', true)
    F.check('classic cap collected through NPC', flag(0xDD0))
    talk('BalloonSeller', true)
    F.check('balloon Pikachu collected through NPC', flag(0xDD2))
    talk('ClassicCapTrainer', true)
    F.check('repeat cap gift fills party slot without an extra mark', flag(0xDD0) and F.r8(S.gPartiesCount) == 4)
    talk('SquadOrganizer', true)
    talk('SquadOne', true)
    talk('SquadTwo', true)
    talk('SquadOrganizer', true)
    F.check('squad task completed and awarded', flag(0xDD3))
    talk('KilnHelper', true)
    talk('WellHelper', true)
    invoke(2, 0, 1200)
    F.check('mid-task save succeeded', F.r16(X.gSpecialVar_0x8005) == 1)
    client.reboot_core()
    F.idle(5)
    assert(F.boot(nil, true), 'mid-task Continue did not return to field')
    F.idle(120)
    F.check('Continue retains water delivery without an award', flag(0xDE8) and not flag(0xDD4))
    talk('KilnHelper', true)
    F.check('kiln task completed and awarded', flag(0xDD4))
    talk('Florist', true)
    talk('FlowerResidentOne', true)
    talk('FlowerResidentTwo', true)
    talk('Florist', true)
    F.check('flowers task awarded to PC with full party', flag(0xDD5))
    talk('Surfer', true)
    talk('Surfboard', false)
    talk('PirateSailor', true)
    talk('Pirate', false)
    F.check('declined encounters do not mark collection', not flag(0xDD1) and not flag(0xDD7))
    talk('SquadOrganizer', true)
    talk('KilnHelper', true)
    talk('Florist', true)
    F.check('repeat gifts retain all five marks', flag(0xDD0) and flag(0xDD2) and flag(0xDD3) and flag(0xDD4) and flag(0xDD5))
    F.finish()
end)
