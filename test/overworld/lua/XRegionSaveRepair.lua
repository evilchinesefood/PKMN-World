-- Existing saves damaged by two cross-region writes, repaired by the v12 -> v13 migration.
--
-- Before #602, Goldenrod's first-visit setup cleared FLAG_RECEIVED_BIKE, the flag Rydel's Cycles
-- shares with the Goldenrod bike shop, so Rydel gave a second bike. Before #604, Johto's mother set
-- FLAG_RECEIVED_POKENAV with the PokeGear, so Hoenn tracked Mr. Briney early: a Center recorded his
-- cottage and the next hub arrival put him and Peeko there while Peeko was still missing. Those
-- fixes stop new damage; MigrateSaveFormatIfNeeded (src/load_save.c) repairs saves that have it.
--
-- The fixture v12xregiondamaged.srm was written by a pre-fix build driving the old scripts (see
-- lua/fixtures/v12xregion.md): the PokeGear, Rydel's Mach Bike, the first walk into Goldenrod, the
-- Rustboro Center, a hub return, then a save inside the cottage with Briney and Peeko standing.
-- Continue migrates it. The suite reads the repaired flags, the cottage on Continue and after
-- walking back in, a Center visit, and Rydel. Then the control: Devon's real PokeNav scene sets
-- the flag, the save is stamped v12 again, saved, reset and continued, and the legitimate state
-- must come through the repair untouched.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/XRegionSaveRepair.lua <rom> test/overworld/lua/fixtures/v12xregiondamaged.srm

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "XRegionSaveRepair")

local BRINEYS_HOUSE = { 17, 0 }
local ROUTE104 = { 0, 19 }
local RUSTBORO_CENTER = { 11, 5 }
local DEVON_3F = { 11, 2 }
local MAUVILLE_BIKE_SHOP = { 10, 1 }
local ITEM_MACH_BIKE, ITEM_ACRO_BIKE = 707, 708
local FLAG_RECEIVED_BIKE = 0x5A
local FLAG_RECEIVED_POKENAV = 0xBC
local FLAG_SYS_POKENAV_GET = 0x94A
local FLAG_HIDE_BRINEYS_HOUSE_MR_BRINEY = 0x2E3
local FLAG_HIDE_BRINEYS_HOUSE_PEEKO = 0x371
local VAR_DEVON_CORP_3F_STATE = 0x408F
local VAR_BRINEY_LOCATION = 0x4096
local USM_ICO_SAVE = 7
local SENTINEL = 0xFFFF
local CONTEXT_RUNNING = 0
local OLD_VERSION = 12
local LOCALID_BRINEY, LOCALID_PEEKO = 1, 2

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function mapIs(m) return F.grp() == m[1] and F.mapn() == m[2] end
local function getVar(id) return F.r16(F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2) end
local function flagGet(id) return (F.r8(F.sb1() + S.SaveBlock1.flags + id // 8) >> (id % 8)) & 1 == 1 end
local function saveVersion() return F.r8(F.sb2() + S.SaveBlock2.saveVersion) end
local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function warp(m, w, tag)
  local gh, gt, go = d(m[1]); local mh, mt, mo = d(m[2]); local wh, wt, wo = d(w)
  return F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, m[1], m[2], tag)
end
local function qty(id)
  local key = F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF
  local ptr = F.r32(S.gBagPockets + 4 * S.BagPocket.stride)
  local n = 0
  for s = 0, F.pocketCap(4) - 1 do
    if F.r16(ptr + s * 4) == id then n = n + (F.r16(ptr + s * 4 + 2) ~ key) end
  end
  return n
end
local function bikeStr() return string.format("mach=%d acro=%d", qty(ITEM_MACH_BIKE), qty(ITEM_ACRO_BIKE)) end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function waitControl(n)
  for _ = 1, n or 600 do if hasControl() then return true end; F.idle(1) end
  return hasControl()
end
local function drain()
  for _ = 1, 60 do
    if hasControl() then return true end
    F.press("B", 2); F.idle(16)
  end
  return hasControl()
end
-- Yes/No prompts take A (Yes); a multichoice is answered with `row`.
local function multichoiceUp()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    if F.r8(a + S.Task.isActive) ~= 0 and (F.r32(a + S.Task.func) & 0xFFFFFFFE) == S.Task_HandleMultichoiceInput then return true end
  end
  return false
end
local function talk(dir, tag, row)
  F.face(dir)
  F.press("A", 2)
  local started = false
  for _ = 1, 120 do
    if not hasControl() then started = true; break end
    F.idle(1)
  end
  if not started then return false end
  for _ = 1, 400 do
    F.idle(20)
    if hasControl() then break end
    if multichoiceUp() and F.mcur() ~= (row or 0) then F.press("Down", 2) else F.press("A", 2) end
  end
  F.shot(tag)
  return waitControl(60)
end
local function cottageCast()
  local t = {}
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    local id = F.r8(b + S.ObjectEvent.localId)
    if (F.r8(b) & 1) == 1 and (id == LOCALID_BRINEY or id == LOCALID_PEEKO) then
      t[#t + 1] = string.format("id%d(%d,%d)", id, F.rs16(b + S.ObjectEvent.x) - 7, F.rs16(b + S.ObjectEvent.y) - 7)
    end
  end
  return t
end
local function brineyState()
  return string.format("pokenav=%s devon3f=%d briney=%d hideBriney=%s hidePeeko=%s",
    tostring(flagGet(FLAG_RECEIVED_POKENAV)), getVar(VAR_DEVON_CORP_3F_STATE), getVar(VAR_BRINEY_LOCATION),
    tostring(flagGet(FLAG_HIDE_BRINEYS_HOUSE_MR_BRINEY)), tostring(flagGet(FLAG_HIDE_BRINEYS_HOUSE_PEEKO)))
end

local function driveSave()
  F.w16(S.gSaveAttemptStatus, SENTINEL)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_SAVE) then return "noicon" end
  for i = 1, 3000 do
    if F.r16(S.gSaveAttemptStatus) ~= SENTINEL then
      F.idle(30)
      for _ = 1, 6 do F.press("B", 2); F.idle(20) end
      return F.r16(S.gSaveAttemptStatus) == 1 and "done" or "failed"
    end
    if i % 20 == 1 then joypad.set({ A = true }) else joypad.set({}) end
    emu.frameadvance()
  end
  return "timeout"
end
local function softReset()
  for _ = 1, 8 do joypad.set({ A = true, B = true, Start = true, Select = true }); emu.frameadvance() end
  joypad.set({})
end

F.run(function()
  if not F.boot(BRINEYS_HOUSE[1]) then F.check("boot", false); F.finish(); return end
  F.shot("continue_cottage")
  F.check("continue: the save loaded in Briney's cottage", mapIs(BRINEYS_HOUSE), where())
  F.check("continue: the save was migrated to the current version", saveVersion() == S.SAVE_FORMAT_VERSION,
    "version=" .. saveVersion())

  F.check("bike: the shop bike is recorded again", flagGet(FLAG_RECEIVED_BIKE), bikeStr())
  F.check("bike: the Bag still holds Rydel's one Mach Bike", qty(ITEM_MACH_BIKE) == 1 and qty(ITEM_ACRO_BIKE) == 0, bikeStr())

  F.check("pokenav: Devon's PokeNav gift is unrecorded", not flagGet(FLAG_RECEIVED_POKENAV), brineyState())
  F.check("pokenav: the PokeGear still works", flagGet(FLAG_SYS_POKENAV_GET))
  F.check("pokenav: Briney has no recorded shore", getVar(VAR_BRINEY_LOCATION) == 0, brineyState())
  F.check("pokenav: Briney and Peeko are away again",
    flagGet(FLAG_HIDE_BRINEYS_HOUSE_MR_BRINEY) and flagGet(FLAG_HIDE_BRINEYS_HOUSE_PEEKO), brineyState())
  local others = cottageCast()
  F.check("cottage: Briney and Peeko are not in the cottage on Continue", #others == 0, table.concat(others, " "))

  F.check("cottage: walked out of the door", F.route({ { 5, 7 }, { 5, 8 } }, "cottage_out"), where())
  for _ = 1, 4 do
    if mapIs(ROUTE104) then break end
    F.press("Down", 20); F.idle(60)
  end
  F.check("cottage: stepped onto Route 104", mapIs(ROUTE104) and waitControl(300), where())
  for _ = 1, 4 do
    if mapIs(BRINEYS_HOUSE) then break end
    F.press("Up", 20); F.idle(60)
  end
  F.check("cottage: walked back in", mapIs(BRINEYS_HOUSE) and waitControl(300), where())
  F.idle(60)
  F.shot("cottage_reentered")
  others = cottageCast()
  F.check("cottage: Briney and Peeko are not in the cottage after walking back in", #others == 0, table.concat(others, " "))

  F.check("center: warped into the Rustboro Pokemon Center", warp(RUSTBORO_CENTER, 0, "rustboro_center"), where())
  drain()
  F.check("center: a Center visit records no shore for Briney", getVar(VAR_BRINEY_LOCATION) == 0, brineyState())

  F.check("rydel: warped into Rydel's Cycles", warp(MAUVILLE_BIKE_SHOP, 0, "rydel"), where())
  F.idle(30)
  F.check("rydel: walked up to Rydel", F.leg(2, 6), where())
  F.check("rydel: talked to Rydel (an offer of a new bike is answered Acro Bike)", talk("Up", "rydel", 1))
  F.check("rydel: Rydel switches the bike instead of giving a second", qty(ITEM_MACH_BIKE) == 0 and qty(ITEM_ACRO_BIKE) == 1, bikeStr())

  F.check("control: warped into Devon's third floor", warp(DEVON_3F, 0, "devon3f"), where())
  for _ = 1, 600 do
    if getVar(VAR_DEVON_CORP_3F_STATE) == 1 and hasControl() then break end
    if F.reportCrash("devon3f") then break end
    F.press("A", 2); F.idle(14)
  end
  drain()
  F.shot("devon3f_after")
  F.check("control: Devon's president gave the PokeNav", getVar(VAR_DEVON_CORP_3F_STATE) == 1
    and flagGet(FLAG_RECEIVED_POKENAV), brineyState())
  F.check("control: Devon's scene sent Briney home", getVar(VAR_BRINEY_LOCATION) == 1
    and not flagGet(FLAG_HIDE_BRINEYS_HOUSE_MR_BRINEY), brineyState())

  F.w8(F.sb2() + S.SaveBlock2.saveVersion, OLD_VERSION)
  F.check("control: saved with the old version stamp", driveSave() == "done", where())
  softReset()
  if not F.boot(DEVON_3F[1]) then F.check("control: continued after the reset", false); F.finish(); return end
  F.check("control: continued after the reset", mapIs(DEVON_3F), where())
  F.check("control: the migration ran again", saveVersion() == S.SAVE_FORMAT_VERSION, "version=" .. saveVersion())
  F.check("control: Devon's PokeNav gift stays recorded", flagGet(FLAG_RECEIVED_POKENAV), brineyState())
  F.check("control: Briney stays home with his shore recorded", getVar(VAR_BRINEY_LOCATION) == 1
    and not flagGet(FLAG_HIDE_BRINEYS_HOUSE_MR_BRINEY) and not flagGet(FLAG_HIDE_BRINEYS_HOUSE_PEEKO), brineyState())
  F.check("control: the shop bike stays recorded", flagGet(FLAG_RECEIVED_BIKE) and qty(ITEM_ACRO_BIKE) == 1, bikeStr())
  F.finish()
end)
