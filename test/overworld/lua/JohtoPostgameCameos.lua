-- Eight Johto NPCs that pokemonHnS hides at new game stood in the world from turn one here, because
-- the port never registered their hide flags (HnS data/scripts/new_game.inc) and nothing else sets
-- them: Prof. Oak in Olivine's port hall, where talking to him hands over the National Pokedex, and
-- seven gym-leader cameos with post-League lines (Whitney, Morty, Jasmine, Pryce, Clair, Janine,
-- Sabrina). HnS shows Oak when Elm hands over the S.S. Ticket and shows the seven when the S.S. Aqua
-- lands in Vermilion. Found by test/overworld/AuditHideFlags.py --sources.
--
-- From a fresh game the suite checks the seven cameo hide flags are set and that the cameos in reach
-- of a warp are absent, then walks the port corridor to Oak's tile with real input and asserts no
-- National Pokedex. Oak's flag stays clear at new game (the port hides him on entry until the
-- ticket), so this fresh game is also the state of a save made before the fix. Then it leaves the state the League call leaves (VAR_NEWBARKTOWN_LABSTATE 10), talks to
-- Elm for the ticket and checks Oak stands at (8,16) and gives the dex. Last it leaves the state the
-- voyage leaves (VAR_SSAQUA_STATE 5), takes the S.S. Aqua door sailor's YES, and checks the seven
-- flags are clear, Whitney stands in the Department Store and talking to her sends her away.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/JohtoPostgameCameos.lua <rom> --env PW_MAX_FRAMES=900000

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "JohtoPostgameCameos")

local HUB_GROUP = 100
local REGION_VARS_START, FLAG_JOHTO_BASE = 0xA000, 0x6000
local VAR_NEWBARKTOWN_LABSTATE = 0xA080 + 0x01
local VAR_SSAQUA_STATE = 0xA080 + 0x28
local FLAG_SYS_NATIONAL_DEX = 0x948 + 0x36
local FLAG_HIDE_OLIVINE_PORT_OAK = FLAG_JOHTO_BASE + 0x0F
local CAMEOS = {
  { "Whitney", FLAG_JOHTO_BASE + 0xD5 },
  { "Morty", FLAG_JOHTO_BASE + 0xF3 },
  { "Jasmine", FLAG_JOHTO_BASE + 0x131 },
  { "Sabrina", FLAG_JOHTO_BASE + 0x138 },
  { "Pryce", FLAG_JOHTO_BASE + 0x170 },
  { "Clair", FLAG_JOHTO_BASE + 0x1B3 },
  { "Janine", FLAG_JOHTO_BASE + 0x1E2 },
}
-- Cameos a warp lands within the object spawn window of: map, warp, local id, tile.
local IN_REACH = {
  { "Whitney", 84, 9, 0, 4, 20, 9 },
  { "Jasmine", 88, 0, 0, 4, 5, 4 },
  { "Sabrina", 88, 9, 0, 3, 24, 5 },
  { "Janine", 98, 10, 1, 4, 11, 6 },
}
local PORT_G, PORT_M, OAK_LOCALID, OAK_X, OAK_Y = 88, 8, 7, 8, 16
local LAB_G, LAB_M, ELM_X, ELM_Y = 76, 0, 6, 3
local SSAQUA_G, SSAQUA_M = 95, 0
local VERMILION_PORT_G, VERMILION_PORT_M = 43, 8
local DEPT6_G, DEPT6_M = 84, 9
local CONTEXT_RUNNING = 0

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function warp(g, m, w, tag)
  local gh, gt, go = d(g)
  local mh, mt, mo = d(m)
  local wh, wt, wo = d(w)
  return F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, g, m, tag)
end
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end

local function sb1Flag(id)
  return (F.r8(F.sb1() + S.SaveBlock1.flags + (id // 8)) & (1 << (id % 8))) ~= 0
end
local function johtoFlag(id)
  return (F.r8(F.sb3() + S.SaveBlock3.johtoFlags + ((id - FLAG_JOHTO_BASE) // 8)) & (1 << (id % 8))) ~= 0
end
local function regionVar(id, v)
  local a = F.sb3() + S.SaveBlock3.regionVars + (id - REGION_VARS_START) * 2
  if v == nil then return F.r16(a) end
  F.w16(a, v)
end

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function awaitControl(budget)
  local calm = 0
  for i = 1, budget or 3000 do
    calm = hasControl() and calm + 1 or 0
    if calm >= 30 then return true end
    if calm == 0 and i % 20 == 0 then F.press("B", 2) else F.idle(1) end
  end
  return hasControl()
end

local function object(localId)
  for i = 0, 15 do
    local a = S.gObjectEvents + i * S.ObjectEvent.stride
    if F.r8(a) & 1 ~= 0 and F.r8(a + S.ObjectEvent.localId) == localId then
      return {
        x = F.rs16(a + S.ObjectEvent.x) - 7, y = F.rs16(a + S.ObjectEvent.y) - 7,
        visible = (F.r8(a + S.ObjectEvent.flags1) & 0x20) == 0,
      }
    end
  end
  return nil
end
local function shown(o) return o ~= nil and o.visible end
local function describe(o)
  return o and string.format("at (%d,%d) visible=%s", o.x, o.y, tostring(o.visible)) or "absent"
end

-- Press A once, then page the script with A (which also takes a YES/NO's default YES) until the
-- player holds the field again.
local function talk(tag)
  F.press("A", 2)
  for f = 1, 6000 do
    if f > 60 and hasControl() then
      F.idle(30)
      if hasControl() then return true end
    end
    if f % 600 == 0 and F.reportCrash(tag .. f) then return false end
    if f % 20 == 0 then F.press("A", 2) else F.idle(1) end
  end
  return false
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  F.idle(40)

  for _, c in ipairs(CAMEOS) do
    F.check("fresh game: " .. c[1] .. "'s cameo hide flag is set", johtoFlag(c[2]))
  end
  for _, c in ipairs(IN_REACH) do
    local name, g, m, w, id = c[1], c[2], c[3], c[4], c[5]
    if F.check("fresh game: warp to " .. name .. "'s map", warp(g, m, w, name), where()) then
      awaitControl(1200)
      F.idle(20)
      local o = object(id)
      F.check("fresh game: " .. name .. " is not standing in the world", not shown(o), describe(o))
      F.shot("fresh_" .. name)
    end
  end

  if not F.check("fresh game: into Olivine's port hall", warp(PORT_G, PORT_M, 0, "port"), where()) then F.finish(); return end
  awaitControl(1200)
  local oak = object(OAK_LOCALID)
  F.check("fresh game: Oak is not in the port hall", not shown(oak), describe(oak))
  local reached = F.route({ { OAK_X, 12 }, { OAK_X, OAK_Y } }, "corridor")
  F.check("fresh game: the corridor to the sailor is open", reached, where())
  if not reached then
    F.face("Down")
    talk("oak_early")
  end
  F.check("fresh game: no National Pokedex before the League", not sb1Flag(FLAG_SYS_NATIONAL_DEX))
  F.shot("fresh_port")

  -- What the League call leaves (NewBarkTown_EventScript_ElmCallAfterLeague), then Elm's own scene.
  regionVar(VAR_NEWBARKTOWN_LABSTATE, 10)
  if not F.check("champion: into Elm's lab", warp(LAB_G, LAB_M, 0, "lab"), where()) then F.finish(); return end
  awaitControl(1200)
  if not F.check("champion: walk up to Elm", F.route({ { ELM_X, 8 }, { ELM_X, ELM_Y + 1 } }, "elm"), where()) then F.finish(); return end
  F.face("Up")
  F.check("champion: Elm's scene returns control", talk("elm"), where())
  F.check("champion: Elm handed over the S.S. Ticket", regionVar(VAR_NEWBARKTOWN_LABSTATE) == 11,
    "labstate=" .. regionVar(VAR_NEWBARKTOWN_LABSTATE))
  F.check("champion: Oak's port hide flag is clear", not johtoFlag(FLAG_HIDE_OLIVINE_PORT_OAK))

  if not F.check("champion: into Olivine's port hall", warp(PORT_G, PORT_M, 0, "port2"), where()) then F.finish(); return end
  awaitControl(1200)
  oak = object(OAK_LOCALID)
  F.check("champion: Oak stands at (8,16)", shown(oak) and oak.x == OAK_X and oak.y == OAK_Y, describe(oak))
  F.shot("champion_port")
  if shown(oak) and F.route({ { OAK_X, 12 }, { OAK_X, OAK_Y - 1 } }, "oak") then
    F.face("Down")
    F.check("champion: Oak's scene returns control", talk("oak"), where())
    F.check("champion: Oak gives the National Pokedex", sb1Flag(FLAG_SYS_NATIONAL_DEX))
    F.check("champion: Oak leaves for good", johtoFlag(FLAG_HIDE_OLIVINE_PORT_OAK))
  end

  -- What the voyage leaves (SSAqua_RoomSSE's Metal Coat scene), then the door sailor's YES.
  regionVar(VAR_SSAQUA_STATE, 5)
  if not F.check("voyage: aboard the S.S. Aqua", warp(SSAQUA_G, SSAQUA_M, 1, "ssaqua"), where()) then F.finish(); return end
  awaitControl(2400)
  local sailor = object(4)
  F.check("voyage: the door sailor stands at (29,2)", sailor ~= nil and sailor.x == 29 and sailor.y == 2, describe(sailor))
  if F.check("voyage: walk up beside the door sailor", F.route({ { 28, 8 }, { 28, 2 } }, "sailor"), where()) then
    F.face("Right")
    talk("sailor")
  end
  awaitControl(2400)
  F.check("voyage: the sailor's YES lands in Vermilion",
    F.grp() == VERMILION_PORT_G and F.mapn() == VERMILION_PORT_M, where())
  for _, c in ipairs(CAMEOS) do
    F.check("voyage: " .. c[1] .. "'s cameo hide flag is clear", not johtoFlag(c[2]))
  end

  if not F.check("voyage: into the Department Store 6F", warp(DEPT6_G, DEPT6_M, 0, "dept6"), where()) then F.finish(); return end
  awaitControl(1200)
  local whitney = object(4)
  F.check("voyage: Whitney stands at (20,9)", shown(whitney) and whitney.x == 20 and whitney.y == 9, describe(whitney))
  F.shot("voyage_whitney")
  if shown(whitney) and F.route({ { 24, 10 }, { 20, 10 } }, "whitney") then
    F.face("Up")
    F.check("voyage: Whitney's scene returns control", talk("whitney"), where())
    F.check("voyage: Whitney leaves after her line", johtoFlag(CAMEOS[1][2]) and not shown(object(4)))
  end
  F.check("no crash screen", not F.reportCrash("end"))
  F.shot("end")
  F.finish()
end)
