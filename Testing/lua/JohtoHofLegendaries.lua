-- Johto HOF rematch must not re-arm already-caught Mew/Deoxys.
-- JohtoPokemonLeague_HallOfFame_EventScript_SetGameClearFlags clears FLAG_DEFEATED_MEW
-- / FLAG_DEFEATED_DEOXYS (unresolved retries) and must leave FLAG_CAUGHT_MEW and
-- FLAG_BATTLED_DEOXYS (the caught markers) and the hide flags set.
-- There is no FLAG_CAUGHT_DEOXYS in this tree; FLAG_BATTLED_DEOXYS is the catch flag.
--
-- Run via Testing/mgba-run.sh Testing/lua/JohtoHofLegendaries.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "JohtoHofLegendaries")

local HUB_GROUP = 100
local GRP_HOF, MAP_HOF, WARP_HOF = 99, 10, 0  -- MAP_JOHTO_POKEMON_LEAGUE_HALL_OF_FAME
local ROW_PARTY_MENU, ROW_SET = 2, 9
local REGION_VARS_START, FLAG_JOHTO_BASE = 0xA000, 0x6000
local VAR_LEAGUE_STATE = 0xA080 + 0x3B
local FLAG_CAUGHT_MEW      = 0x1CA
local FLAG_BATTLED_DEOXYS  = 0x1AD
local FLAG_DEFEATED_MEW    = 0x1C7
local FLAG_DEFEATED_DEOXYS = 0x1AC
local FLAG_HIDE_MEW        = 0x2CE
local FLAG_HIDE_DEOXYS     = 0x2FB
local FLAG_JOHTO_CHAMPION  = 0xA49            -- SaveBlock1 Kanto-bank gap
local FLAG_IS_KANTO_CHAMPION = FLAG_JOHTO_BASE + 0x13D
local SCRIPT_SETFLAGS = S.JohtoPokemonLeague_HallOfFame_EventScript_SetGameClearFlags
local CTX_STATUS, CTX_SCRIPT = S.sGlobalScriptContextStatus, 8
local CONTEXT_SHUTDOWN = 2
local BUDGET = 9000

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end

local function go(grp, map, warp, tag)
  local gh, gt, go_ = d(grp)
  local mh, mt, mo = d(map)
  local wh, wt, wo = d(warp)
  if not F.warpTo(gh, gt, go_, mh, mt, mo, wh, wt, wo, grp, map, tag) then
    F.check(tag .. "_warped", false, string.format("grp=%d map=%d", F.grp(), F.mapn()))
    return false
  end
  F.idle(60)
  return true
end

local function tapDown(n)
  for _ = 1, n do F.press("Down", 3); F.idle(16) end
end

local function setParty()
  F.dbg(); F.idle(60)
  tapDown(ROW_PARTY_MENU); F.press("A", 3); F.idle(60)
  tapDown(ROW_SET); F.press("A", 3); F.idle(180)
  for _ = 1, 6 do F.press("B", 3); F.idle(20) end
end

local function sb1FlagGet(id)
  return (F.r8(F.sb1() + S.SaveBlock1.flags + (id // 8)) & (1 << (id % 8))) ~= 0
end
local function sb1FlagSet(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + (id // 8), 1 << (id % 8)
  local v = F.r8(a)
  F.w8(a, on and (v | m) or (v & ~m & 0xFF))
end
local function johtoFlagGet(id)
  local a, m = F.sb3() + S.SaveBlock3.johtoFlags + ((id - FLAG_JOHTO_BASE) // 8), 1 << (id % 8)
  return (F.r8(a) & m) ~= 0
end
local function regionVarGet(id)
  return F.r16(F.sb3() + S.SaveBlock3.regionVars + (id - REGION_VARS_START) * 2)
end
local function regionVarSet(id, v)
  F.w16(F.sb3() + S.SaveBlock3.regionVars + (id - REGION_VARS_START) * 2, v)
end

local function dumpFlags(tag)
  F.L(string.format(
    "  flags[%s] CAUGHT_MEW=%s BATTLED_DEOXYS=%s DEFEATED_MEW=%s DEFEATED_DEOXYS=%s HIDE_MEW=%s HIDE_DEOXYS=%s JOHTO_CHAMP=%s KANTO_CHAMP=%s LEAGUE_STATE=%d",
    tag,
    tostring(sb1FlagGet(FLAG_CAUGHT_MEW)),
    tostring(sb1FlagGet(FLAG_BATTLED_DEOXYS)),
    tostring(sb1FlagGet(FLAG_DEFEATED_MEW)),
    tostring(sb1FlagGet(FLAG_DEFEATED_DEOXYS)),
    tostring(sb1FlagGet(FLAG_HIDE_MEW)),
    tostring(sb1FlagGet(FLAG_HIDE_DEOXYS)),
    tostring(sb1FlagGet(FLAG_JOHTO_CHAMPION)),
    tostring(johtoFlagGet(FLAG_IS_KANTO_CHAMPION)),
    regionVarGet(VAR_LEAGUE_STATE)))
end

local function stopScript()
  F.w8(CTX_STATUS, CONTEXT_SHUTDOWN)
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  F.idle(40)

  -- HOF record field effect needs a party.
  setParty()
  F.check("Set Party published a party", F.r8(S.gPartiesCount) ~= 0)

  sb1FlagSet(FLAG_CAUGHT_MEW, true)
  sb1FlagSet(FLAG_BATTLED_DEOXYS, true)
  sb1FlagSet(FLAG_DEFEATED_MEW, true)
  sb1FlagSet(FLAG_DEFEATED_DEOXYS, true)
  sb1FlagSet(FLAG_HIDE_MEW, true)
  sb1FlagSet(FLAG_HIDE_DEOXYS, true)
  sb1FlagSet(FLAG_JOHTO_CHAMPION, true)  -- rematch branch -> SetGameClearFlags
  regionVarSet(VAR_LEAGUE_STATE, 6)      -- OnFrame fires the cutscene
  dumpFlags("seeded")
  F.check("seeded FLAG_CAUGHT_MEW", sb1FlagGet(FLAG_CAUGHT_MEW))
  F.check("seeded FLAG_BATTLED_DEOXYS", sb1FlagGet(FLAG_BATTLED_DEOXYS))
  F.check("seeded FLAG_JOHTO_CHAMPION (rematch path)", sb1FlagGet(FLAG_JOHTO_CHAMPION))

  if not go(GRP_HOF, MAP_HOF, WARP_HOF, "hof") then F.finish(); return end
  F.shot("hof_arrival")
  dumpFlags("after_warp")
  F.check("OnFrame still sees LEAGUE_STATE=6 (or already ran)",
    regionVarGet(VAR_LEAGUE_STATE) == 6 or johtoFlagGet(FLAG_IS_KANTO_CHAMPION),
    "LEAGUE_STATE=" .. regionVarGet(VAR_LEAGUE_STATE))

  local ran, sawPtr = false, false
  for i = 1, BUDGET do
    F.press("A", 1)
    F.idle(1)
    if i % 20 == 0 then F.press("B", 1) end
    local sptr = F.r32(S.sGlobalScriptContext + CTX_SCRIPT)
    if sptr >= SCRIPT_SETFLAGS and sptr < SCRIPT_SETFLAGS + 0x180 then sawPtr = true end
    -- SetGameClearFlags is wait-free: the whole call finishes in one script burst,
    -- then fadescreenspeed starts. FLAG_IS_KANTO_CHAMPION is the discriminator that
    -- it ran, and we have ~24 fade frames before special GameClear.
    if johtoFlagGet(FLAG_IS_KANTO_CHAMPION) or regionVarGet(VAR_LEAGUE_STATE) == 1 then
      ran = true
      F.L(string.format("  SetGameClearFlags observed at frame %d script=0x%08X", i, sptr))
      dumpFlags("post_setflags")
      F.shot("post_setflags")
      stopScript()
      break
    end
    if i % 300 == 0 then
      F.L(string.format("  waiting f=%d script=0x%08X status=%d LEAGUE=%d",
        i, sptr, F.r8(CTX_STATUS), regionVarGet(VAR_LEAGUE_STATE)))
      if F.reportCrash("hof" .. i) then break end
    end
  end

  if not ran then
    dumpFlags("timeout")
    F.shot("hof_timeout")
  end
  F.check("HOF rematch path ran SetGameClearFlags", ran,
    sawPtr and "saw script ptr but flags never flipped" or "cutscene never reached SetGameClearFlags")

  dumpFlags("final")
  F.check("FLAG_CAUGHT_MEW stayed set (not re-armed as uncaught)", sb1FlagGet(FLAG_CAUGHT_MEW))
  F.check("FLAG_BATTLED_DEOXYS stayed set (caught-Deoxys marker, not cleared)", sb1FlagGet(FLAG_BATTLED_DEOXYS))
  F.check("FLAG_HIDE_MEW stayed set (Mew stays hidden)", sb1FlagGet(FLAG_HIDE_MEW))
  F.check("FLAG_HIDE_DEOXYS stayed set (Deoxys stays hidden)", sb1FlagGet(FLAG_HIDE_DEOXYS))
  -- These two ARE cleared on purpose (unresolved retries). Log, don't require.
  F.L(string.format("  (info) DEFEATED_MEW=%s DEFEATED_DEOXYS=%s — script is allowed to clear these",
    tostring(sb1FlagGet(FLAG_DEFEATED_MEW)), tostring(sb1FlagGet(FLAG_DEFEATED_DEOXYS))))

  F.finish()
end)
