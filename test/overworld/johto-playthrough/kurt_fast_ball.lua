-- Kurt's Fast Ball after the Slowpoke Well must not lock up a player whose POKé BALLS pocket is full.
--
-- The gift was an ON_FRAME script keyed only on VAR_AZALEA_TOWN_STATE == 3. With a full pocket
-- (16 ball types, no Fast Ball) giveitem failed, the state stayed 3, and the script re-fired on
-- the next frame: "take it" / "The BAG is full", forever, with no way to open the Bag and make
-- room. Found by the Johto playthrough. The gift now runs once per entry to the house; a full
-- bag gives control back and the gift is offered again on the next visit.
--
-- Setup is staged (a debug warp, the rescue state written directly, the pocket filled with the
-- debug menu); what is tested is the real map script, the real Bag and controller input.
--
--   python3 test/overworld/johto-playthrough/run.py --suite kurt_fast_ball.lua
local here = (debug.getinfo(1, 'S').source:sub(2)):match('^(.*[/\\])')
package.path = here .. '?.lua;' .. here .. '../lua/?.lua;' .. assert(os.getenv('PW_PLAY_LUA')) .. '/?.lua;' .. package.path
local S = require('symbols')
local F = require('lib').new(S, 'JohtoKurtFastBall')
local N = require('nav')(F, S)
local C = require('pwconst')

local function debugMenu(rows)
  N.press('R', 1); for _ = 1, 3 do joypad.set({ R = true, Start = true }); emu.frameadvance() end; N.idle(80)
  for _, r in ipairs(rows) do
    for _ = 1, r do N.press('Down', 3); N.idle(16) end
    N.press('A', 3); N.idle(60)
  end
  for _ = 1, 6 do N.press('B', 2); N.idle(20) end
  N.settle()
end
local function kurtLines()
  local n = 0
  for _, line in ipairs(N.transcript) do if line:find('honored to make') then n = n + 1 end end
  return n
end
local function enterHouse()
  -- Leave by the door mat and come straight back in.
  N.go(4, 8); N.press('Down', 30); N.idle(120); N.settle()
  N.press('Up', 30); N.idle(160)
end

F.run(function()
  if not F.boot(100) then F.check('boot', false); F.finish(); return end
  F.w16(F.sb3() + S.SaveBlock3.regionVars + (C.VAR_AZALEA_TOWN_STATE - 0xA000) * 2, 3)
  debugMenu({ 1, 1, 4 })    -- PC/Bag... > Fill... > Fill Pocket Poke Balls
  F.check('the POKé BALLS pocket holds no Fast Ball', N.itemCount(C.ITEM_FAST_BALL) == 0)
  local ok = F.warpTo(0, 8, 1, 0, 0, 2, 0, 0, 0, 81, 2, 'kurts_house')
  F.check("warp into Kurt's house after the rescue", ok)
  if not ok then F.finish(); return end
  N.settle({ limit = 60 * 30 })
  F.check('Kurt offers the Fast Ball', kurtLines() == 1, 'offers=' .. kurtLines())
  F.check('a full bag gives control back', N.free() and F.ensureFree())
  F.check('the gift is still owed (state 3)', N.var(C.VAR_AZALEA_TOWN_STATE) == 3)
  enterHouse()
  N.settle({ limit = 60 * 30 })
  F.check('re-entering offers it again', kurtLines() == 2, 'offers=' .. kurtLines())
  F.check('and control comes back again', N.free() and F.ensureFree())
  debugMenu({ 1, 2 })       -- PC/Bag... > Clear Bag
  enterHouse()
  N.settle({ limit = 60 * 30 })
  F.check('with room, the Fast Ball is received', N.itemCount(C.ITEM_FAST_BALL) > 0)
  F.check('and the rescue is complete (state 4)', N.var(C.VAR_AZALEA_TOWN_STATE) == 4)
  F.check('player control returns', N.free() and F.ensureFree())
  F.finish()
end)
