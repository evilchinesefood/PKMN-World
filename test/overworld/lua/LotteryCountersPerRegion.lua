-- The Goldenrod Radio Tower lottery and the Lilycove Department Store lottery used one daily flag,
-- FLAG_DAILY_PICKED_LOTO_TICKET, and one pair of held-prize vars, so a draw in Goldenrod closed the
-- Lilycove counter until the next day, and a prize Lilycove held for a full Bag was handed out in
-- Goldenrod instead. The Radio Tower now keeps its own flag and vars. The suite draws at the Radio
-- Tower by talking (Yes), then talks to the Lilycove clerk: Lilycove must still offer its draw.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/LotteryCountersPerRegion.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "LotteryCountersPerRegion")

local HUB = 100
local RADIO_TOWER_1F = { 84, 18 }
local DEPT_STORE_1F = { 13, 16 }
local FLAG_DAILY_PICKED_LOTO_TICKET = 0xA12
local CONTEXT_RUNNING = 0

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function flagGet(id) return (F.r8(F.sb1() + S.SaveBlock1.flags + id // 8) >> (id % 8)) & 1 == 1 end
local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function warp(m, w, tag)
  local gh, gt, go = d(m[1]); local mh, mt, mo = d(m[2]); local wh, wt, wo = d(w)
  return F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, m[1], m[2], tag)
end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function yesNoUp()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    local fn = F.r32(a + S.Task.func) & 0xFFFFFFFE
    if F.r8(a + S.Task.isActive) ~= 0 and (fn == S.Task_HandleYesNoInput or fn == S.Task_CallYesOrNoCallback) then return true end
  end
  return false
end
-- Face the clerk, press A, answer everything with A (Yes) until control returns. Reports whether a
-- Yes/No prompt was offered on the way.
local function talk(dir, tag)
  F.face(dir)
  F.press("A", 2)
  local started, asked = false, false
  for _ = 1, 120 do
    if not hasControl() then started = true; break end
    F.idle(1)
  end
  if not started then return false, false end
  for _ = 1, 400 do
    for _ = 1, 20 do
      if yesNoUp() then asked = true end
      F.idle(1)
    end
    if hasControl() then break end
    F.press("A", 2)
  end
  F.shot(tag)
  return hasControl(), asked
end

F.run(function()
  if not F.boot(HUB) then F.check("boot", false); F.finish(); return end

  F.check("radio: warped into the Radio Tower", warp(RADIO_TOWER_1F, 0, "radio"), where())
  F.idle(30)
  F.check("radio: walked to the lottery counter", F.route({ { 9, 6 }, { 19, 6 }, { 19, 8 } }, "radio_walk"), where())
  local ok, asked = talk("Down", "radio_draw")
  F.check("radio: the Radio Tower clerk offered a draw", ok and asked)
  F.check("radio: a Radio Tower draw leaves Lilycove's daily flag alone", not flagGet(FLAG_DAILY_PICKED_LOTO_TICKET))

  F.check("lilycove: warped into the Department Store", warp(DEPT_STORE_1F, 0, "lilycove"), where())
  F.idle(30)
  F.check("lilycove: walked to the lottery counter", F.route({ { 8, 4 }, { 10, 4 } }, "lilycove_walk"), where())
  ok, asked = talk("Up", "lilycove_draw")
  F.check("lilycove: the Lilycove clerk still offers today's draw", ok and asked)
  F.check("lilycove: and records it", flagGet(FLAG_DAILY_PICKED_LOTO_TICKET))
  F.finish()
end)
