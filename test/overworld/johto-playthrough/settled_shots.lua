-- Re-shoot a finished campaign's beats after the screen settles.
--
-- A beat's screenshot is taken the frame its goal is met, which is often mid-fade: a warp or Hub
-- Pass arrival still fading in, a cave exit fading from white, a thunderstorm flash. Those frames
-- read as dark or washed-out maps and send screenshot reviewers after palettes that are fine.
-- This loads each beat's checkpoint from the prior run (same frame as its shot), idles, shoots
-- again, and names the beats whose faded palettes were still moving.
--
--   python3 test/overworld/johto-playthrough/run.py --campaign world --suite settled_shots.lua \
--     --rom <that run's ROM> --elf <its ELF> --resume-dir <that run's case dir> [--from B] [--to B]
local here = (debug.getinfo(1, 'S').source:sub(2)):match('^(.*[/\\])')
package.path = here .. '?.lua;' .. here .. '../lua/?.lua;' .. assert(os.getenv('PW_PLAY_LUA')) .. '/?.lua;' .. package.path
local S = require('symbols')
local F = require('lib').new(S, 'CampaignSettledShots')
local N = require('nav')(F, S)
local P = require('pwsym')

local SETTLE_FRAMES = 300
-- Background colours only: an overworld Pokemon walking in loads a sprite palette mid-wait.
local PALETTE_COLORS = 256
-- A clock-tint step moves a colour by one unit; a fade or flash moves many colours by far more.
local MOVED_UNITS, MOVED_COLORS = 2, 32

local resume = assert(os.getenv('PW_RESUME_DIR'), '--resume-dir is required')
local first, last = os.getenv('PW_FROM'), os.getenv('PW_TO')

local function beatOrder()
  local names, seen = {}, {}
  local pipe = io.popen('ls "' .. resume .. '"/*.log')
  for log in pipe:lines() do
    for line in io.lines(log) do
      local name = line:match('^CHECKPOINT (%S+) %->')
      if name and not seen[name] then seen[name] = true; names[#names + 1] = name end
    end
  end
  pipe:close()
  return names
end

local function fadedPalette()
  local colors = {}
  for i = 0, PALETTE_COLORS - 1 do colors[i] = F.r16(P.gPlttBufferFaded + i * 2) end
  return colors
end

local function movedColors(a, b)
  local moved = 0
  for i = 0, PALETTE_COLORS - 1 do
    local x, y = a[i], b[i]
    for shift = 0, 10, 5 do
      if math.abs(((x >> shift) & 31) - ((y >> shift) & 31)) > MOVED_UNITS then moved = moved + 1; break end
    end
  end
  return moved
end

F.run(function()
  local beats, inRange, transient = beatOrder(), first == nil, {}
  F.check('the prior run logged checkpoints', #beats > 0, resume)
  for n, beat in ipairs(beats) do
    if beat == first then inRange = true end
    if inRange then
      F.check('loaded ' .. beat, client.loadstate(resume .. '/ckpt_' .. beat .. '.ss'))
      F.idle(1)
      local before = fadedPalette()
      F.idle(SETTLE_FRAMES)
      local moved = movedColors(before, fadedPalette())
      F.L(string.format('SETTLED %d %s: %s (%d,%d) palette colours moved %d', n, beat, N.mapName(),
        F.pos(), select(2, F.pos()), moved))
      if moved >= MOVED_COLORS then transient[#transient + 1] = beat end
      F.shot(string.format('%03d_%s', n, beat))
    end
    if beat == last then break end
  end
  F.L('TRANSIENT beat shots (judge these from the settled shots): ' .. (#transient > 0 and table.concat(transient, ' ') or 'none'))
  F.finish()
end)
