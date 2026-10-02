package.path = assert(os.getenv('PW_FEATURE_LIB')) .. '/?.lua;' .. package.path
local S = require('symbols')
local F = require('lib').new(S, 'MenuPolish')
local function tap(key) F.press(key, 2); F.idle(90) end
local function footer(tag)
    local p = S.gWindows + 2 * 12
    local width, height = F.r8(p + 3) * 8, F.r8(p + 4) * 8
    local buffer = F.r32(p + 8)
    assert(width == 224 and height == 16, 'unexpected footer size')
    local function pixel(x, y)
        local tile = (y // 8) * (width // 8) + x // 8
        local value = F.r8(buffer + tile * 32 + (y % 8) * 4 + (x % 8) // 2)
        return (value >> ((x % 2) * 4)) & 15
    end
    local good = true
    for _, x in ipairs({0, width - 1}) do
        for _, y in ipairs({0, height - 1}) do good = good and pixel(x, y) == 0 end
    end
    F.check(tag .. ' transparent rounded corners', good)
    F.check(tag .. ' panel fill retained', pixel(4, 0) == 1 and pixel(width - 5, height - 1) == 1)
end
F.run(function()
    assert(F.boot(100))
    tap('Start')
    assert(F.selectStartIcon(6))
    F.idle(30); F.shot('story_icon')
    tap('A'); footer('Story overview'); F.shot('story_overview')
    tap('A'); footer('Story detail'); F.shot('story_detail')
    tap('Right'); footer('Story page change')
    tap('B'); tap('B'); tap('B')
    tap('Start')
    assert(F.selectStartIcon(7))
    F.idle(30); F.shot('save_icon')
    tap('A'); F.shot('save_prompt'); tap('B'); tap('B')
    tap('Start')
    assert(F.selectStartIcon(9))
    tap('A'); footer('Options'); F.shot('options')
    for i = 1, 9 do tap('Down') end
    footer('Options after scrolling'); F.shot('options_scrolled')
    tap('B'); tap('B')
    F.check('returns to field', F.ow())
    F.check('no crash', not F.reportCrash('menu polish'))
    F.finish()
end)
