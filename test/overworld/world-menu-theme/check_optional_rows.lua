-- Exercise dormant optional layouts through production tasks, with a synthetic
-- menu type because link features are deliberately disabled in the shipped ROM.
local here = (debug.getinfo(1, 'S').source:sub(2)):match('^(.*[/\\])') or ''
package.path = here .. '../lua/?.lua;' .. package.path
local S = require('symbols')
local F = require('lib').new(S, 'MainMenuOptionalRows')
local function task(fn)
  for i = 0, 15 do
    local p = S.gTasks + i * 40
    if F.r8(p + 4) ~= 0 and (F.r32(p) & ~1) == (fn & ~1) then return p end
  end
end
local function enter(mode, selected)
  F.w16(S.gSaveFileStatus, 1)
  F.w16(S.sCurrItemAndOptionMenuCheck, selected)
  F.w32(S.gMain + 4, S.CB2_InitMainMenu | 1)
  for i = 1, 600 do
    F.idle(1)
    local p = task(S.Task_DisplayMainMenu)
    if p then
      F.w16(p + 8, mode)
      F.w16(p + 10, selected)
      F.w16(p + 32, mode + 2)
      F.idle(90)
      assert(task(S.Task_HandleMainMenuInput), 'main menu not ready')
      return
    end
  end
  error('main menu did not reach display task')
end
local function tap(key, count)
  for i = 1, count do F.press(key, 3); F.idle(20) end
end
local function visible(tag, scroll)
  F.check(tag .. ': BG0 scroll fits the optional layout', F.r16(S.sGpuRegBuffer + 0x12) == (scroll or 32))
  local range = F.r16(S.sGpuRegBuffer + 0x44)
  F.check(tag .. ': selected frame fits the display', (range & 255) <= 160 and (range >> 8) < (range & 255))
end
F.run(function()
  assert(F.boot(100))
  enter(2, 0)
  tap('Down', 3)
  visible('Gift Options')
  F.shot('gift_options')
  tap('Up', 1)
  F.check('Gift leaving Options restores scroll', F.r16(S.sGpuRegBuffer + 0x12) == 0)
  enter(2, 3)
  visible('Gift restored Options')
  enter(3, 0)
  tap('Down', 4)
  visible('Events Options', 48)
  F.check('no crash', not F.reportCrash('optional menu rows'))
  F.finish()
end)
