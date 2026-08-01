-- Issue #59 part C, live: the hub staircase bounces a non-champion with a
-- message, admits a champion, and the descent returns control (the D1 guard
-- behaviour on the new warp pair). The two segments are separated by a debug
-- warp so no message-box or movement state can leak between them.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(require("symbols"), "HubStairsGate")

local APPROACH = { { 6, 4 }, { 6, 12 }, { 3, 12 }, { 3, 13 }, { 2, 13 } }

local function hold(dir, frames)
  for _ = 1, (frames or 30) do joypad.set({ [dir] = true }); emu.frameadvance() end
  F.idle(10)
end

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end

  -- A. non-champion: step onto the apron -> gate -> DENIED -> bounced back
  F.check("A: reached (2,13)", F.route(APPROACH, "approach"))
  hold("Down", 40); F.idle(60)
  local free = false
  for _ = 1, 40 do
    F.press("B", 2); F.idle(15)
    if F.ensureFree() then free = true; break end
  end
  F.idle(30)
  local x, y = F.pos()
  F.check("A: non-champion bounced back to (2,13)", x == 2 and y == 13, ("(%d,%d)"):format(x, y))
  F.check("A: still on the hub 1F", F.grp() == 100 and F.mapn() == 0)
  F.check("A: control returned after the bounce", free)

  -- B. champion: clean re-entry via a warp, then walk straight up the stairs
  local a = F.sb1() + S.SaveBlock1.flags + math.floor(0xA4A / 8)
  F.w8(a, F.r8(a) | (1 << (0xA4A % 8)))     -- FLAG_HOENN_CHAMPION
  F.check("B: hub re-entered clean", F.warpTo(1, 0, 0, 0, 0, 0, 0, 0, 0, 100, 0, "reenter"))
  F.idle(120)
  F.check("B: reached (2,13)", F.route(APPROACH, "reapproach"))
  F.route({ { 2, 14 } }, "ontoApron")
  F.idle(60)
  local gx, gy = F.pos()
  F.check("B: champion admitted onto the apron, no DENIED box", gx == 2 and gy == 14,
    ("(%d,%d)"):format(gx, gy))
  for _ = 1, 20 do
    for _ = 1, 12 do joypad.set({ Left = true }); emu.frameadvance() end
    F.idle(8)
    if F.mapn() == 1 then break end
  end
  for _ = 1, 400 do
    if F.mapn() == 1 then break end
    F.idle(10)
  end
  F.check("B: champion rides up to RegionHub_2F", F.grp() == 100 and F.mapn() == 1,
    ("grp=%d map=%d"):format(F.grp(), F.mapn()))
  -- the arrival auto-walk (EscalatorWarpIn_End steps the player east off the
  -- escalator) must finish before any input; prove control AWAY from the
  -- escalator or ensureFree's own Left step rides straight back down
  for _ = 1, 400 do
    local bx, by = F.pos()
    if bx == 2 and by == 6 then break end
    F.idle(10)
  end
  F.route({ { 4, 6 } }, "offEsc")
  F.check("B: control returns on the flagship floor", F.ensureFree())

  -- C. descent: walk back onto the 2F escalator; land on the 1F ride cell and
  -- get walked east onto the apron with control -- the D1 guard behaviour
  F.route({ { 3, 6 }, { 2, 6 } }, "besideEsc")
  local rode = false
  for _ = 1, 20 do
    for _ = 1, 12 do joypad.set({ Left = true }); emu.frameadvance() end
    F.idle(8)
    if F.mapn() == 0 then rode = true; break end
  end
  for _ = 1, 300 do
    if F.mapn() == 0 then rode = true; break end
    F.idle(10)
  end
  F.check("C: descent returns to the hub 1F", rode and F.grp() == 100)
  -- the landing auto-walk carries the player from (1,14) east to the apron
  for _ = 1, 400 do
    local dx, dy = F.pos()
    if dx == 2 and dy == 14 then break end
    F.idle(10)
  end
  local dx, dy = F.pos()
  F.check("C: landed and auto-walked onto the apron (2,14)", dx == 2 and dy == 14, ("(%d,%d)"):format(dx, dy))
  F.route({ { 2, 13 } }, "offApron")
  F.check("C: control returns after the descent (D1 guard)", F.ensureFree())
  F.shot("stairs_done")
  F.finish()
end)
