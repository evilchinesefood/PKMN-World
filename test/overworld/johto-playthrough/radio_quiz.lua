-- The Radio Tower 1F quiz is the only way past the Beauty blocking Whitney's Gym door, so it must
-- accept true answers. Question 3 asks whether Kurt makes his POKé BALLs from apricorns; the
-- script accepted only NO (a GSC answer left behind when HnS rewrote the question), so a player
-- answering truthfully failed every time. Found by the Johto playthrough. Answers each question
-- by what it asks, through the real receptionist and Yes/No menus.
--
--   python3 test/overworld/johto-playthrough/run.py --suite radio_quiz.lua
local here = (debug.getinfo(1, 'S').source:sub(2)):match('^(.*[/\\])')
package.path = here .. '?.lua;' .. here .. '../lua/?.lua;' .. assert(os.getenv('PW_PLAY_LUA')) .. '/?.lua;' .. package.path
local S = require('symbols')
local F = require('lib').new(S, 'JohtoRadioQuiz')
local N = require('nav')(F, S)
local C = require('pwconst')
local function truthful(t, k)
  if k ~= 'yesno' then return 0 end
  local l = t:lower()
  if l:find('charmander') then return 'no' end   -- not a slot-machine prize
  return 'yes'   -- daytime-only POKéMON, no Berries at a MART, Kurt's apricorns, Falkner's birds
end
F.run(function()
  if not F.boot(100) then F.check('boot', false); F.finish(); return end
  local ok = F.warpTo(0, 8, 4, 0, 1, 8, 0, 0, 0, 84, 18, 'radio_tower_1f')
  F.check('warp to Radio Tower 1F', ok)
  if not ok then F.finish(); return end
  F.check('quiz not yet won', not N.flag(C.FLAG_ENABLE_RADIO))
  F.check('reach the receptionist across the counter', N.talkFrom(14, 8, 1, { policy = truthful }))
  local q3
  for _, line in ipairs(N.transcript) do if line:find('apricorns') then q3 = true end end
  F.check('question 3 asks about Kurt and apricorns', q3)
  F.check('truthful answers win the quiz', N.flag(C.FLAG_ENABLE_RADIO))
  F.check('the Gym-door Beauty is dismissed', N.flag(C.FLAG_HIDE_GOLDENROD_BEAUTY))
  F.check('player control returns', N.free())
  F.finish()
end)
