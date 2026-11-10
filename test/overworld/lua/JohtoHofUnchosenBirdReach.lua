-- The Johto Hall of Fame's first-clear branch offers the bird the player did not pick, so it must
-- also clear what bars the way to it: the Tentacruel at the Whirl Islands chamber door on a GOLD
-- save (FLAG_HIDE_WHIRL_ISLANDS_TENTACRUEL) and the Tin Tower sage on a SILVER save
-- (FLAG_HIDE_TINTOWER_GUARD). The Johto campaign plays only GOLD, so this seeds a save that took
-- the other branch and runs the real ceremony script.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/JohtoHofUnchosenBirdReach.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "JohtoHofUnchosenBirdReach")

local HUB_GROUP = 100
local GRP_HOF, MAP_HOF, WARP_HOF = 99, 10, 0
local ROW_PARTY_MENU, ROW_SET = 2, 9
local REGION_VARS_START, FLAG_JOHTO_BASE = 0xA000, 0x6000
local VAR_COMPLETED_HO_OH = 0xA080 + 0x21
local VAR_COMPLETED_LUGIA = 0xA080 + 0x22
local VAR_LEAGUE_STATE = 0xA080 + 0x3B
local FLAG_HIDE_TINTOWER_GUARD = FLAG_JOHTO_BASE + 0xFF
local FLAG_HIDE_WHIRL_ISLANDS_TENTACRUEL = FLAG_JOHTO_BASE + 0x102
local CTX_STATUS = S.sGlobalScriptContextStatus
local CONTEXT_SHUTDOWN = 2
local BUDGET = 9000

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end

local function setParty()
  F.dbg(); F.idle(60)
  for _ = 1, ROW_PARTY_MENU do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(60)
  for _ = 1, ROW_SET do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(180)
  for _ = 1, 6 do F.press("B", 3); F.idle(20) end
end

local function johtoFlagAddr(id)
  return F.sb3() + S.SaveBlock3.johtoFlags + ((id - FLAG_JOHTO_BASE) // 8), 1 << (id % 8)
end
local function johtoFlagGet(id)
  local a, m = johtoFlagAddr(id)
  return (F.r8(a) & m) ~= 0
end
local function johtoFlagSet(id, on)
  local a, m = johtoFlagAddr(id)
  local v = F.r8(a)
  F.w8(a, on and (v | m) or (v & ~m & 0xFF))
end
local function regionVarGet(id) return F.r16(F.sb3() + S.SaveBlock3.regionVars + (id - REGION_VARS_START) * 2) end
local function regionVarSet(id, v) F.w16(F.sb3() + S.SaveBlock3.regionVars + (id - REGION_VARS_START) * 2, v) end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  F.idle(40)
  setParty()
  F.check("Set Party published a party", F.r8(S.gPartiesCount) ~= 0)

  -- A save where neither blocker has been cleared yet, and neither bird was caught.
  johtoFlagSet(FLAG_HIDE_TINTOWER_GUARD, false)
  johtoFlagSet(FLAG_HIDE_WHIRL_ISLANDS_TENTACRUEL, false)
  regionVarSet(VAR_COMPLETED_HO_OH, 3)
  regionVarSet(VAR_COMPLETED_LUGIA, 3)
  regionVarSet(VAR_LEAGUE_STATE, 6)

  local gh, gt, go = d(GRP_HOF)
  local mh, mt, mo = d(MAP_HOF)
  if not F.warpTo(gh, gt, go, mh, mt, mo, 0, 0, WARP_HOF, GRP_HOF, MAP_HOF, "hof") then
    F.check("warp to the Hall of Fame", false); F.finish(); return
  end

  local ran = false
  for i = 1, BUDGET do
    F.press("A", 1); F.idle(1)
    if i % 20 == 0 then F.press("B", 1) end
    if regionVarGet(VAR_LEAGUE_STATE) == 1 then
      ran = true
      F.w8(CTX_STATUS, CONTEXT_SHUTDOWN)
      break
    end
    if i % 300 == 0 and F.reportCrash("hof" .. i) then break end
  end
  F.check("the first-clear ceremony ran", ran)

  F.L(string.format("  HO_OH=%d LUGIA=%d guard hidden=%s tentacruel hidden=%s", regionVarGet(VAR_COMPLETED_HO_OH),
    regionVarGet(VAR_COMPLETED_LUGIA), tostring(johtoFlagGet(FLAG_HIDE_TINTOWER_GUARD)), tostring(johtoFlagGet(FLAG_HIDE_WHIRL_ISLANDS_TENTACRUEL))))
  F.check("both birds are offered again", regionVarGet(VAR_COMPLETED_HO_OH) == 4 and regionVarGet(VAR_COMPLETED_LUGIA) == 4)
  F.check("the Tin Tower sage stands aside for a SILVER save", johtoFlagGet(FLAG_HIDE_TINTOWER_GUARD))
  F.check("the Whirl Islands Tentacruel leaves for a GOLD save", johtoFlagGet(FLAG_HIDE_WHIRL_ISLANDS_TENTACRUEL))
  F.finish()
end)
