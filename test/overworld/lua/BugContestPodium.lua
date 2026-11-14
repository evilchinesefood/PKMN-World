-- Bug-Catching Contest judging puts the player's chosen Pokemon on the podium at (20,29).
--
-- The judging scene's ShowBugContestChosenMon used to return the local id of one of ten
-- per-species stand-in objects. Those objects were deleted, so the ids landed on lamp lights and
-- the podium stayed empty. The scene now draws one appended object (local id 44) through
-- VAR_OBJ_GFX_ID_0 with the chosen Pokemon's overworld graphics. A non-bug catch must show too,
-- and nothing may raise an assert screen.
--
-- Two contests run back to back: Weedle, then Growlithe (a non-bug, as a DexNav catch would be).
-- The catch is a debug-given Pokemon; the attendant, retiring, choosing the kept Pokemon,
-- judging and the walk back to the gate use real input.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/BugContestPodium.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BugContestPodium")

local REGION_JOHTO = 2
local GATE_G, GATE_M = 83, 7
local CONTEST_G, CONTEST_M = 83, 5
local FLAG_SYS_POKEMON_GET = 0x948
local FLAG_SYS_BUG_CONTEST_MODE = 0x948 + 0x21
local VAR_BUG_CONTEST_STATE = 0xA080 + 0x0E
local PODIUM_LOCALID = 44
local PODIUM_X, PODIUM_Y = 20, 29
local JUDGE_X, JUDGE_Y = 20, 28
local OBJ_EVENT_MON = 0x4000
local SPECIES_BITS = 0x0FFF

local function count() return F.r8(S.gPartiesCount) end
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function inContest() return F.grp() == CONTEST_G and F.mapn() == CONTEST_M end
local function atGate() return F.grp() == GATE_G and F.mapn() == GATE_M end
local function state() return F.r16(F.sb3() + S.SaveBlock3.regionVars + (VAR_BUG_CONTEST_STATE - 0xA000) * 2) end
local function sb1Flag(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + (id // 8), 1 << (id % 8)
  if on == nil then return (F.r8(a) & m) ~= 0 end
  F.w8(a, on and (F.r8(a) | m) or (F.r8(a) & ~m & 0xFF))
end
local function setJohto()
  F.w32(S.gCurrentRegion, REGION_JOHTO)
  F.w8(F.sb2() + S.SaveBlock2.currentRegion, REGION_JOHTO)
end

local function podium()
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == PODIUM_LOCALID then
      return {
        x = F.rs16(b + S.ObjectEvent.x) - 7, y = F.rs16(b + S.ObjectEvent.y) - 7,
        gfx = F.r16(b + S.ObjectEvent.graphicsId),
        invisible = (F.r8(b + S.ObjectEvent.flags1) & 0x20) ~= 0,
      }
    end
  end
end
local function describe(p)
  if not p then return "no podium object" end
  return string.format("(%d,%d) gfx=0x%04X invisible=%s", p.x, p.y, p.gfx, tostring(p.invisible))
end

local function tapDown(n) for _ = 1, n do F.press("Down", 3); F.idle(16) end end
local function drain(tries)
  for i = 1, tries or 40 do
    F.press("B", 3); F.idle(20)
    if i % 5 == 0 and F.ensureFree() then return true end
  end
  return F.ensureFree()
end
local function debugAction(path, tag)
  F.dbg(); F.idle(60)
  for i, row in ipairs(path) do
    tapDown(row); F.press("A", 3); F.idle(i == #path and 240 or 60)
  end
  if not drain(20) then F.L("  debug action " .. tag .. " did not return to the field") return false end
  return true
end
-- Give X > Pokemon (Basic): the species spinner starts at 1, so the ones digit is one short.
local function give(sp)
  F.dbg(); F.idle(60)
  tapDown(3); F.press("A", 3); F.idle(50)
  tapDown(1); F.press("A", 3); F.idle(40)
  F.press("Right", 2); F.idle(10)
  for _ = 1, (sp // 10) % 10 do F.press("Up", 2); F.idle(8) end
  F.press("Left", 2); F.idle(10)
  for _ = 1, sp % 10 - 1 do F.press("Up", 2); F.idle(8) end
  F.press("A", 3); F.idle(30)
  F.press("A", 3); F.idle(80)
  for _ = 1, 10 do F.press("B", 3); F.idle(20) end
  drain(20)
end

local function enterContest()
  F.leg(4, 2); F.face("Left"); F.press("A", 3); F.idle(40)
  for _ = 1, 400 do
    F.press("A", 2); F.idle(18)
    if inContest() and F.ow() then break end
  end
  drain(30)
  return inContest() and sb1Flag(FLAG_SYS_BUG_CONTEST_MODE)
end

-- Retire at the exit, keep party slot 1 and stop once the judging scene has the player at
-- (20,28). Returns the podium sample, or nil and whether an assert screen came up.
local function retireToJudging(tag)
  F.leg(13, 48)
  F.step("Down")
  for _ = 1, 900 do
    if F.reportCrash(tag .. "_retire") then return nil, true end
    local x, y = F.pos()
    if inContest() and state() == 3 and x == JUDGE_X and y == JUDGE_Y and F.ow() then
      F.idle(20)
      local p = podium()
      F.shot(tag .. "_judging")
      return p, false
    end
    if F.cb2() == (S.CB2_UpdatePartyMenu & ~1) then
      F.idle(30); F.press("Down", 2); F.idle(20); F.press("A", 2); F.idle(40)
      if F.cb2() == (S.CB2_UpdatePartyMenu & ~1) then F.press("A", 2); F.idle(40) end
    else
      F.press("A", 2); F.idle(18)
    end
  end
  F.shot(tag .. "_nojudging")
  return nil, false
end

local function finishContest(tag)
  for _ = 1, 900 do
    if atGate() and F.ow() and not sb1Flag(FLAG_SYS_BUG_CONTEST_MODE) then break end
    if F.reportCrash(tag .. "_end") then return false end
    F.press("A", 2); F.idle(18)
  end
  drain(30)
  return atGate() and not sb1Flag(FLAG_SYS_BUG_CONTEST_MODE)
end

local function contest(species, name)
  local tag = name:lower()
  F.check(name .. ": the attendant lets the player in", enterContest(), where())
  F.check(name .. ": no podium object while the contest runs", podium() == nil, describe(podium()))
  give(species)
  F.check(name .. ": setup: the catch joins the contest party", count() == 2, "count=" .. count())

  local p, crashed = retireToJudging(tag)
  F.check(name .. ": retiring and judging raise no assert screen", not crashed)
  F.check(name .. ": the podium object stands at (20,29)", p ~= nil and p.x == PODIUM_X and p.y == PODIUM_Y and not p.invisible,
    describe(p))
  F.check(name .. ": the podium shows the chosen species", p ~= nil and (p.gfx & OBJ_EVENT_MON) ~= 0
    and (p.gfx & SPECIES_BITS) == species, describe(p) .. " want species " .. species)

  F.check(name .. ": the contest ends back at the gate", finishContest(tag), where())
  F.check(name .. ": no podium object after the contest", podium() == nil, describe(podium()))
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  setJohto()
  sb1Flag(FLAG_SYS_POKEMON_GET, true)
  F.check("setup: debug Set Party ran", debugAction({ 2, 9 }, "set_party") and count() >= 1, "count=" .. count())

  local function toGate()
    local ok = F.warpTo(0, 8, 3, 0, 0, 7, 0, 0, 0, GATE_G, GATE_M, "gate")
    setJohto()
    return F.check("warp to the National Park gate", ok, where())
  end

  if not toGate() then F.finish(); return end
  contest(13, "Weedle")
  F.warpTo(1, 0, 0, 0, 0, 0, 0, 0, 0, 100, 0, "hub")
  if not toGate() then F.finish(); return end
  contest(58, "Growlithe")

  F.check("no crash", not F.crashScreen())
  F.finish()
end)
