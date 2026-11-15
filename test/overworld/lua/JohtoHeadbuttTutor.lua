-- The Ilex Forest Headbutt tutor teaches Headbutt. His script offered `TUTOR_MOVE_HEADBUTT`, an
-- alias of MOVE_HEADBUTT that tools/learnset_helpers/make_tutors.py does not read (it looks for
-- `setvar VAR_0x8005, MOVE_*`), so Headbutt never became a tutor move, no species' teachable
-- learnset held it, and his party menu marked every Pokemon NOT ABLE.
--
-- With real input from the Route 34 entrance the suite walks 94 tiles to the tutor at (42,26),
-- says YES, and picks a level 5 Pidgey (slot 2; a level 100 Lapras leads so the Repel holds),
-- then checks Pidgey knows Headbutt and the script set FLAG_GET_HEADBUTT, which is what lets the
-- Headbutt trees answer.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/JohtoHeadbuttTutor.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "JohtoHeadbuttTutor")

local GRP_ILEX, MAP_ILEX_FOREST = 80, 3
local FLAG_JOHTO_BASE = 0x6000
local FLAG_GET_HEADBUTT = FLAG_JOHTO_BASE + 0x8A
local VAR_REPEL_STEP_COUNT = 0x4021
local SPECIES_PIDGEY, MOVE_HEADBUTT = 16, 29
local PARTY_MENU_SLOT = 9

local ROUTE = { { 20, 14 }, { 20, 15 }, { 37, 15 }, { 37, 13 }, { 42, 13 }, { 42, 10 }, { 43, 10 }, { 43, 9 },
                { 53, 9 }, { 53, 10 }, { 55, 10 }, { 55, 13 }, { 63, 13 }, { 63, 24 }, { 61, 24 }, { 61, 25 },
                { 58, 25 }, { 58, 27 }, { 57, 27 }, { 57, 28 }, { 54, 28 }, { 54, 29 }, { 44, 29 }, { 44, 27 },
                { 42, 27 } }

local function where()
  local x, y = F.pos()
  return string.format("grp=%d map=%d pos=(%d,%d)", F.grp(), F.mapn(), x, y)
end

local function johtoFlag(id)
  return (F.r8(F.sb3() + S.SaveBlock3.johtoFlags + ((id - FLAG_JOHTO_BASE) // 8)) & (1 << (id % 8))) ~= 0
end

local function repel()
  F.w16(F.sb1() + S.SaveBlock1.vars + (VAR_REPEL_STEP_COUNT - 0x4000) * 2, 250)
end

local function scriptPtr()
  return F.r32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr)
end

local function order(p)
  local o = {}
  for i = 0, 3 do o[i] = F.r8(S.sSubstructOffsets + i * 24 + p % 24) * 3 end
  return o
end
local function partyMon(slot)
  local a = S.gParties + slot * S.Pokemon.size
  local key = F.r32(a) ~ F.r32(a + 4)
  local w = {}
  for i = 0, 11 do w[i] = F.r32(a + 32 + i * 4) ~ key end
  local o = order(F.r32(a))
  local s1 = o[1]
  return {
    species = w[o[0]] & 0x7FF,
    moves = { w[s1] & 0x7FF, (w[s1] >> 16) & 0x7FF, w[s1 + 1] & 0x7FF, (w[s1 + 1] >> 16) & 0x7FF },
  }
end
local function knows(mon, move)
  for _, m in ipairs(mon.moves) do if m == move then return true end end
  return false
end
local function moves(mon)
  return string.format("species=%d moves=%d,%d,%d,%d", mon.species, mon.moves[1], mon.moves[2], mon.moves[3], mon.moves[4])
end

local function givePokemon(sh, st, so, lh, lt, lo)
  F.dbg(); F.idle(60)
  for _ = 1, 3 do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(60)
  F.press("Down", 3); F.idle(16)
  F.press("A", 3); F.idle(60)
  F.spin(sh, st, so)
  F.spin(lh, lt, lo)
  F.idle(90)
  F.bOut(4); F.idle(60)
end

local function inPartyMenu() return F.cb2() == S.CB2_UpdatePartyMenu end

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end

  givePokemon(1, 3, 0, 0, 9, 9)
  givePokemon(0, 1, 5, 0, 0, 4)
  local pidgey = partyMon(1)
  F.check("party is a Lapras lead and a Pidgey without Headbutt",
    F.r8(S.gPartiesCount) == 2 and pidgey.species == SPECIES_PIDGEY and not knows(pidgey, MOVE_HEADBUTT), moves(pidgey))
  F.check("FLAG_GET_HEADBUTT starts clear", not johtoFlag(FLAG_GET_HEADBUTT), "")

  F.check("warp to Ilex Forest's Route 34 entrance",
    F.warpTo(0, 8, 0, 0, 0, 3, 0, 0, 1, GRP_ILEX, MAP_ILEX_FOREST, "ilex"), where())
  local walked = false
  for _ = 1, 3 do
    repel()
    walked = F.route(ROUTE, "to_tutor")
    if walked then break end
    F.idle(90)
  end
  F.check("walk to the tutor's south tile (42,27) with real input", walked, where())
  F.face("Up")
  F.shot("at_tutor")

  F.press("A", 2)
  local opened = false
  for _ = 1, 30 do
    F.idle(40)
    if inPartyMenu() then opened = true; break end
    F.press("A", 2)
  end
  F.check("YES to the tutor opens the party menu", opened, string.format("cb2=0x%08X", F.cb2()))
  if opened then
    F.idle(60)
    for _ = 1, 6 do
      if F.rs8(S.gPartyMenu + PARTY_MENU_SLOT) == 1 then break end
      F.press("Down", 2); F.idle(20)
    end
    F.shot("party_menu")
    F.check("cursor on Pidgey", F.rs8(S.gPartyMenu + PARTY_MENU_SLOT) == 1, "")
    F.press("A", 2)
    for _ = 1, 40 do
      F.idle(40)
      if F.ow() and scriptPtr() == 0 then break end
      F.press("B", 2)
    end
  end
  F.idle(60)
  pidgey = partyMon(1)
  F.check("Pidgey learned Headbutt from the tutor", knows(pidgey, MOVE_HEADBUTT), moves(pidgey))
  F.check("the tutor set FLAG_GET_HEADBUTT", johtoFlag(FLAG_GET_HEADBUTT), "")
  F.check("control returned to the overworld", F.ow() and scriptPtr() == 0, where())
  F.shot("after")
  F.finish()
end)
