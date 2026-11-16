-- Seafoam Islands' falls and currents (FRLG), which no campaign beat or suite reaches. Falling
-- through a B2F hole lands on B3F water: with the current running it carries the player into B4F
-- on Surf; with both B3F boulders in place (the state the B2F boulders leave when they fall) the
-- current is stopped and the player stays afloat with control. Falling through a B3F hole lands on
-- B4F water: the current carries the player to the stairs and dumps them on land, or with both B4F
-- boulders in place they stay afloat. Setup passes Route 20 (whose map script resets the puzzle),
-- then writes only the boulder hide flags the falls leave and uses coordinate warps next to each
-- hole; the step into the hole and everything after it is real input and the maps' own scripts,
-- with a seeded mash of every button but the soft-reset chord through each fall and ride
-- (`PW_SEAFOAM_SEED=<n>` reseeds it).
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SeafoamCurrents")

local B2F, B3F, B4F = 85, 86, 87
local G = 35
local FLAG = function(n) return 0xA40 + n end
local B2F_BOULDER = { FLAG(0x44), FLAG(0x45) }
local B3F_BOULDER = { FLAG(0x46), FLAG(0x47) }
local B4F_BOULDER = { FLAG(0x4C), FLAG(0x4D) }
local STOPPED_B3F, STOPPED_B4F = FLAG(0x2D2), FLAG(0x2D3)
local PLAYER_AVATAR_FLAG_SURFING = 8
local VAR_REPEL_STEP_COUNT = 0x4021

local function d(n) return n // 100, (n // 10) % 10, n % 10 end
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function surfing() return (F.r8(S.gPlayerAvatar) & PLAYER_AVATAR_FLAG_SURFING) ~= 0 end
local function flagAddr(id) return F.sb1() + S.SaveBlock1.flags + id // 8, 1 << (id % 8) end
local function setFlag(id, on)
  local a, bit = flagAddr(id)
  F.w8(a, on and (F.r8(a) | bit) or (F.r8(a) & (~bit & 255)))
end
local function flag(id) local a, bit = flagAddr(id); return (F.r8(a) & bit) ~= 0 end

local function warpToCoords(grp, map, x, y, tag)
  for _ = 1, 4 do
    F.dbg(); F.sel(0); F.sel(1); F.idle(20)
    F.spin(d(grp)); F.spin(d(map))
    F.press("A", 2)
    for _ = 1, 400 do
      F.w8(S.sWarpDestination + 2, 0xFF)
      F.w16(S.sWarpDestination + 4, x)
      F.w16(S.sWarpDestination + 6, y)
      F.idle(1)
      local px, py = F.pos()
      if F.ow() and F.grp() == grp and F.mapn() == map and px == x and py == y then
        F.idle(120)
        return true
      end
    end
    F.bOut(5)
  end
  F.shot(tag .. "_warpfail")
  return false
end

-- Control is back once a step that should move the player does, and then steps back.
local function freeTo(dir, back)
  for _ = 1, 600 do
    if F.reportCrash("settle") then return false end
    if F.ow() then
      local x, y = F.pos()
      if F.step(dir) then
        local nx, ny = F.pos()
        if nx ~= x or ny ~= y then F.step(back); return true end
      end
    end
    F.press("B", 2); F.idle(10)
  end
  return false
end

local seed = tonumber(os.getenv("PW_SEAFOAM_SEED") or "7")
local function fall(grp, map, x, y, dir, tag)
  if not warpToCoords(grp, map, x, y, tag .. "_approach") then return false end
  F.w16(F.sb1() + S.SaveBlock1.vars + (VAR_REPEL_STEP_COUNT - 0x4000) * 2, 250)
  F.step(dir)
  -- Mash through the fall and the ride: every button but the soft-reset chord.
  local keys = { "A", "B", "Start", "Select", "Up", "Down", "Left", "Right", "L", "R" }
  for i = 1, 600 do
    if F.reportCrash(tag) then return false end
    seed = (seed * 1103515245 + 12345) % 2147483648
    if i % 6 == 0 then F.press(keys[seed % #keys + 1], 2) else F.idle(1) end
  end
  for _ = 1, 8 do F.press("B", 2); F.idle(20) end
  F.shot(tag)
  return true
end

F.run(function()
  if not F.boot(100) then F.check("fresh boot", false); F.finish(); return end
  F.dbg(); F.idle(40); F.sel(2); F.idle(40); for _ = 1, 9 do F.press("Down", 3); F.idle(16) end; F.press("A", 3); F.idle(180)
  for _ = 1, 6 do F.press("B", 2); F.idle(20) end

  -- B2F hole with the B3F current running: carried into B4F on Surf.
  F.check("Route 20 resets the puzzle", warpToCoords(37, 38, 60, 9, "route20") and flag(B3F_BOULDER[1]) and flag(B3F_BOULDER[2]),
    "b3f boulders hidden=" .. tostring(flag(B3F_BOULDER[1])) .. "," .. tostring(flag(B3F_BOULDER[2])))
  F.check("fall through the B2F hole (24,8)", fall(G, B2F, 24, 9, "Up", "b2f_fall_current"))
  F.check("the running current carries the player into B4F", F.grp() == G and F.mapn() == B4F, where())
  F.check("B4F arrival is on Surf", surfing(), where())
  F.check("control returns in B4F's east pool", freeTo("Left", "Right"), where())
  F.shot("b4f_east_pool")

  -- Both B2F boulders fell: B3F's two boulders are in, the current is stopped.
  setFlag(B2F_BOULDER[1], true); setFlag(B2F_BOULDER[2], true)
  setFlag(B3F_BOULDER[1], false); setFlag(B3F_BOULDER[2], false)
  F.check("fall through the B2F hole (27,8) onto stopped water", fall(G, B2F, 27, 9, "Up", "b2f_fall_stopped"))
  F.check("the stopped current leaves the player on B3F", F.grp() == G and F.mapn() == B3F, where())
  F.check("B3F records the stopped current", flag(STOPPED_B3F))
  F.check("the player is afloat on B3F", surfing(), where())
  F.check("control returns on B3F", freeTo("Down", "Up"), where())
  F.shot("b3f_stopped")

  -- B3F hole with the B4F current running: carried to the stairs and put ashore.
  F.check("fall through the B3F hole (9,18)", fall(G, B3F, 8, 18, "Right", "b3f_fall_current"))
  F.check("the fall lands in B4F", F.grp() == G and F.mapn() == B4F, where())
  F.check("the current puts the player ashore", not surfing(), where())
  F.check("control returns ashore in B4F", freeTo("Down", "Up") or freeTo("Up", "Down"), where())
  F.shot("b4f_ashore")

  -- Both B3F boulders fell: B4F's two boulders are in, the current is stopped.
  setFlag(B4F_BOULDER[1], false); setFlag(B4F_BOULDER[2], false)
  setFlag(FLAG(0x48), true); setFlag(FLAG(0x4A), true)
  F.check("fall through the B3F hole (6,18) onto stopped water", fall(G, B3F, 5, 18, "Right", "b3f_fall_stopped"))
  F.check("the fall lands in B4F again", F.grp() == G and F.mapn() == B4F, where())
  F.check("B4F records the stopped current", flag(STOPPED_B4F))
  F.check("the player is afloat on B4F", surfing(), where())
  F.check("control returns afloat in B4F", freeTo("Up", "Down") or freeTo("Right", "Left"), where())
  F.shot("b4f_stopped")
  F.finish()
end)
