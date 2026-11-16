-- The other half of XRegionSaveRepair.lua: saves where the v12 -> v13 repairs have no proof to act
-- on and must leave the state alone.
--
-- The fixture v12xregionvoyage.srm was written by a pre-fix build driving the old scripts (see
-- lua/fixtures/v12xregion.md): the PokeGear set FLAG_RECEIVED_POKENAV, a Center and a hub return
-- docked Mr. Briney at his cottage before Peeko's rescue, and he sailed the player to Dewford. The
-- player never got a bike, and Goldenrod's first visit ran. From Dewford on, where the save put
-- Briney is what the player's route depends on, so the PokeNav repair must not hide him or stop
-- him being tracked; with no bike in the Bag or PC, the bike flag must stay clear and Rydel must
-- still give the first bike.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/XRegionSaveRepairVoyage.lua <rom> test/overworld/lua/fixtures/v12xregionvoyage.srm

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "XRegionSaveRepairVoyage")

local DEWFORD = { 0, 11 }
local MAUVILLE_BIKE_SHOP = { 10, 1 }
local ITEM_MACH_BIKE, ITEM_ACRO_BIKE = 707, 708
local FLAG_RECEIVED_BIKE = 0x5A
local FLAG_RECEIVED_POKENAV = 0xBC
local FLAG_VISITED_DEWFORD_TOWN = 0x959
local FLAG_HIDE_MR_BRINEY_DEWFORD_TOWN = 0x2E4
local VAR_DEVON_CORP_3F_STATE = 0x408F
local VAR_BRINEY_LOCATION = 0x4096
local BRINEY_AT_HOUSE = 1
local CONTEXT_RUNNING = 0

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function mapIs(m) return F.grp() == m[1] and F.mapn() == m[2] end
local function getVar(id) return F.r16(F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2) end
local function flagGet(id) return (F.r8(F.sb1() + S.SaveBlock1.flags + id // 8) >> (id % 8)) & 1 == 1 end
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
local function talk(dir, tag)
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
    F.press("A", 2)
  end
  F.shot(tag)
  return waitControl(60)
end
local function brineyState()
  return string.format("pokenav=%s devon3f=%d briney=%d dewfordBrineyHidden=%s",
    tostring(flagGet(FLAG_RECEIVED_POKENAV)), getVar(VAR_DEVON_CORP_3F_STATE), getVar(VAR_BRINEY_LOCATION),
    tostring(flagGet(FLAG_HIDE_MR_BRINEY_DEWFORD_TOWN)))
end

F.run(function()
  if not F.boot(DEWFORD[1]) then F.check("boot", false); F.finish(); return end
  F.shot("continue_dewford")
  F.check("continue: the save loaded in Dewford", mapIs(DEWFORD), where())
  F.check("continue: the save was migrated to the current version",
    F.r8(F.sb2() + S.SaveBlock2.saveVersion) == S.SAVE_FORMAT_VERSION)
  F.check("voyage: Dewford is recorded as visited", flagGet(FLAG_VISITED_DEWFORD_TOWN))
  F.check("voyage: Briney stays tracked by the PokeNav flag", flagGet(FLAG_RECEIVED_POKENAV), brineyState())
  F.check("voyage: Briney's recorded shore is kept", getVar(VAR_BRINEY_LOCATION) == BRINEY_AT_HOUSE, brineyState())
  F.check("voyage: Briney stays docked in Dewford", not flagGet(FLAG_HIDE_MR_BRINEY_DEWFORD_TOWN), brineyState())
  F.check("bike: with no bike anywhere the shop bike stays unrecorded", not flagGet(FLAG_RECEIVED_BIKE), bikeStr())

  F.check("rydel: warped into Rydel's Cycles", warp(MAUVILLE_BIKE_SHOP, 0, "rydel"), where())
  F.idle(30)
  F.check("rydel: walked up to Rydel", F.leg(2, 6), where())
  F.check("rydel: talked to Rydel", talk("Up", "rydel"))
  F.check("rydel: Rydel gives the first bike", qty(ITEM_MACH_BIKE) == 1 and qty(ITEM_ACRO_BIKE) == 0
    and flagGet(FLAG_RECEIVED_BIKE), bikeStr())
  F.finish()
end)
