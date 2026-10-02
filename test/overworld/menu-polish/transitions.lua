-- Measure real emulated frames from A to fade and destination callback.
package.path = assert(os.getenv('PW_FEATURE_LIB')) .. '/?.lua;' .. package.path
local S = require('symbols')
local X = require('feature_symbols')
local M = require('menu_symbols')
local F = require('lib').new(S, 'MenuTransition')
local selection = tonumber(os.getenv('PW_MENU_SELECTION') or '2')
F.run(function()
    assert(F.boot(100))
    F.w16(S.gSpecialVar_0x8004, 38)
    F.w32(S.gMain + 4, X.hook)
    F.idle(240)
    for i = 1, selection do F.press('Down', 2); F.idle(8) end
    F.shot('selected_' .. selection)
    local callback = F.r32(S.gMain + 4)
    local palette = {}
    for i = 0, 255 do palette[i] = F.r16(M.gPlttBufferFaded + i * 2) end
    local fade, destination
    for frame = 1, 180 do
        if frame <= 2 then F.press('A', 1) else F.idle(1) end
        if not fade then
            for i = 0, 255 do
                if F.r16(M.gPlttBufferFaded + i * 2) ~= palette[i] then fade = frame; break end
            end
        end
        if F.r32(S.gMain + 4) ~= callback then destination = frame; break end
    end
    F.L('selection=' .. selection .. ' fade=' .. tostring(fade) .. ' destination=' .. tostring(destination))
    F.check('fade begins promptly', fade ~= nil and fade <= 4)
    F.check('destination starts without adapter timeout', destination ~= nil and destination <= 45)
    local expected = ({M.CB2_ContinueSavedGame, M.CB2_NewGameScene, M.CB2_InitOptionMenu})[selection + 1]
    F.check('selected destination reached', (F.r32(S.gMain + 4) & ~1) == (expected & ~1))
    F.idle(150)
    F.shot('destination_' .. selection)
    F.check('no crash', not F.reportCrash('menu transition'))
    F.finish()
end)
