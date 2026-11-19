-- Eight Johto NPCs that pokemonHnS hides at new game stood in the world from turn one here, because
-- the port never registered their hide flags (HnS data/scripts/new_game.inc) and nothing else sets
-- them: Prof. Oak in Olivine's port hall, where talking to him hands over the National Pokedex, and
-- seven gym-leader cameos with post-League lines (Whitney, Morty, Jasmine, Pryce, Clair, Janine,
-- Sabrina). Found by test/overworld/AuditHideFlags.py --sources.
--
-- HnS shows the seven when the S.S. Aqua lands in Vermilion, its only way to Kanto. Here the Region
-- Hub reaches Kanto too and the boat is optional, so the Johto Hall of Fame shows them: a champion
-- who never boards still meets them. Their lines invite a rematch at each leader's own GYM (open to
-- a Johto champion), not at the FIGHTING DOJO, whose gym-leader roster was never ported (#101).
--
-- From a fresh game the suite checks the seven cameo hide flags are set and that the cameos in reach
-- of a warp are absent, then walks the port corridor to Oak's tile with real input and asserts no
-- National Pokedex. Oak's flag stays clear at new game (the port hides him on entry until the
-- ticket), so this fresh game is also the state of a save made before the fix. Then it plays the
-- Johto Hall of Fame ceremony to the title and continues the file, crosses to Kanto at the Hub's
-- gate, comes back with the HUB PASS and the Johto gate, and talks to the four cameos in reach of a
-- warp: each must stand, name a place that has a battle (or none), never the DOJO, and leave. Then
-- it leaves the state the League call leaves (VAR_NEWBARKTOWN_LABSTATE 10), talks to Elm for the
-- ticket and checks Oak stands at (8,16) and gives the dex. Last it leaves the state the voyage
-- leaves (VAR_SSAQUA_STATE 5), takes the S.S. Aqua door sailor's YES, and checks the landing
-- leaves the three unmet cameos shown and does not bring back the four already met.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/JohtoPostgameCameos.lua <rom> --env PW_MAX_FRAMES=900000

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "JohtoPostgameCameos")

local HUB_GROUP = 100
local ROW_PARTY_MENU, ROW_SET = 2, 9
local REGION_VARS_START, FLAG_JOHTO_BASE = 0xA000, 0x6000
local VAR_NEWBARKTOWN_LABSTATE = 0xA080 + 0x01
local VAR_SSAQUA_STATE = 0xA080 + 0x28
local VAR_LEAGUE_STATE = 0xA080 + 0x3B
local FLAG_SYS_NATIONAL_DEX = 0x948 + 0x36
local FLAG_JOHTO_CHAMPION = 0xA40 + 0x09
local FLAG_HUB_INTRO_TOUR_DONE = 0xD40 + 0x8F
local FLAG_HIDE_OLIVINE_PORT_OAK = FLAG_JOHTO_BASE + 0x0F
local REGION_KANTO, REGION_JOHTO = 1, 2
local CAMEOS = {
  { "Whitney", FLAG_JOHTO_BASE + 0xD5 },
  { "Morty", FLAG_JOHTO_BASE + 0xF3 },
  { "Jasmine", FLAG_JOHTO_BASE + 0x131 },
  { "Sabrina", FLAG_JOHTO_BASE + 0x138 },
  { "Pryce", FLAG_JOHTO_BASE + 0x170 },
  { "Clair", FLAG_JOHTO_BASE + 0x1B3 },
  { "Janine", FLAG_JOHTO_BASE + 0x1E2 },
}
local FLAG_OF = {}
for _, c in ipairs(CAMEOS) do FLAG_OF[c[1]] = c[2] end
local MET = { Whitney = true, Jasmine = true, Sabrina = true, Janine = true }
-- Cameos a warp lands within the object spawn window of: map, warp, local id, tile, the walk to
-- the tile the player talks from, the facing there, and a word her line must contain ("GYM" where
-- she has a battle to offer; Janine has none anywhere, so her own errand).
local IN_REACH = {
  { "Whitney", 84, 9, 0, 4, 20, 9, { { 24, 10 }, { 20, 10 } }, "Up", "GYM" },
  { "Jasmine", 88, 0, 0, 4, 5, 4, { { 3, 5 }, { 4, 5 }, { 4, 4 } }, "Right", "GYM" },
  { "Sabrina", 88, 9, 0, 3, 24, 5, { { 15, 5 }, { 23, 5 } }, "Right", "GYM" },
  { "Janine", 98, 10, 1, 4, 11, 6, { { 11, 5 } }, "Down", "lunch" },
}
local HOF_G, HOF_M = 99, 10
local NEWBARK_G, NEWBARK_M = 75, 0
local HUB_G, HUB_M = 100, 0
local ATTENDANT_KANTO_TALK, ATTENDANT_JOHTO_TALK = { 11, 3 }, { 16, 3 }
local PORT_G, PORT_M, OAK_LOCALID, OAK_X, OAK_Y = 88, 8, 7, 8, 16
local LAB_G, LAB_M, ELM_X, ELM_Y = 76, 0, 6, 3
local SSAQUA_G, SSAQUA_M = 95, 0
local VERMILION_PORT_G, VERMILION_PORT_M = 43, 2
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
local function mapIs(g, m) return F.grp() == g and F.mapn() == m end
local function region() return F.r8(S.gCurrentRegion) end

local function sb1Flag(id)
  return (F.r8(F.sb1() + S.SaveBlock1.flags + (id // 8)) & (1 << (id % 8))) ~= 0
end
local function setSb1Flag(id)
  local a = F.sb1() + S.SaveBlock1.flags + (id // 8)
  F.w8(a, F.r8(a) | (1 << (id % 8)))
end
local function johtoFlag(id)
  return (F.r8(F.sb3() + S.SaveBlock3.johtoFlags + ((id - FLAG_JOHTO_BASE) // 8)) & (1 << (id % 8))) ~= 0
end
local function regionVar(id, v)
  local a = F.sb3() + S.SaveBlock3.regionVars + (id - REGION_VARS_START) * 2
  if v == nil then return F.r16(a) end
  F.w16(a, v)
end

local function setParty()
  F.dbg(); F.idle(60)
  for _ = 1, ROW_PARTY_MENU do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(60)
  for _ = 1, ROW_SET do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(180)
  for _ = 1, 6 do F.press("B", 3); F.idle(20) end
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

-- The field message as ShowFieldMessage expanded it into gStringVar4.
local function decode(addr)
  local out = {}
  for i = 0, 399 do
    local c = F.r8(addr + i)
    if c == 0xFF then break end
    if c == 0x00 or c == 0xFE or c == 0xFA or c == 0xFB then out[#out + 1] = " "
    elseif c >= 0xBB and c <= 0xD4 then out[#out + 1] = string.char(65 + c - 0xBB)
    elseif c >= 0xD5 and c <= 0xEE then out[#out + 1] = string.char(97 + c - 0xD5)
    elseif c == 0xAB then out[#out + 1] = "!"
    elseif c == 0xAD then out[#out + 1] = "."
    elseif c == 0xB4 then out[#out + 1] = "'"
    elseif c == 0xB8 then out[#out + 1] = ","
    else out[#out + 1] = "?" end
  end
  return table.concat(out)
end

-- Press A once, then page the script with A (which also takes a YES/NO's default YES) until the
-- player holds the field again. Returns the control verdict and every field message it printed.
local function talk(tag)
  local said, last = {}, nil
  F.w8(S.gStringVar4, 0xFF)
  F.press("A", 2)
  for f = 1, 6000 do
    if f % 4 == 0 then
      local t = decode(S.gStringVar4)
      if t ~= "" and t ~= last then said[#said + 1] = t; last = t end
    end
    if f > 60 and hasControl() then
      F.idle(30)
      if hasControl() then return true, table.concat(said, " | ") end
    end
    if f % 600 == 0 and F.reportCrash(tag .. f) then return false, table.concat(said, " | ") end
    if f % 20 == 0 then F.press("A", 2) else F.idle(1) end
  end
  return false, table.concat(said, " | ")
end

-- Page scripts with A (each YES/NO and multichoice takes its default row) until the map changes.
local function mashUntilLeft(g, m, tag, budget)
  local said, last = {}, nil
  for i = 1, budget or 400 do
    if not mapIs(g, m) and F.ow() then F.idle(90); return true end
    if i % 30 == 0 and F.reportCrash(tag .. i) then return false end
    local t = decode(S.gStringVar4)
    if t ~= last then said[#said + 1] = t; last = t end
    F.press("A", 2); F.idle(18)
  end
  F.L("  " .. tag .. " said: " .. table.concat(said, " | "))
  return not mapIs(g, m)
end

-- A two-row YES/NO, driven by reading the cursor (want: 0 = YES, 1 = NO).
local function yesNo(want, tag)
  for _ = 1, 24 do
    local c0 = F.mcur()
    F.press("Down", 2); F.idle(12)
    local live = F.mcur() ~= c0
    if not live then
      c0 = F.mcur()
      F.press("Up", 2); F.idle(12)
      live = F.mcur() ~= c0
    end
    if live then
      for _ = 1, 6 do
        if F.mcur() == want then F.press("A", 2); F.idle(60); return true end
        F.press(F.mcur() > want and "Up" or "Down", 2); F.idle(12)
      end
      return false
    end
    F.press("A", 2); F.idle(35)
  end
  F.L("  yesNo " .. tag .. ": menu never went live")
  return false
end

local function isFrontEnd(c)
  return c == S.MainCB2_Intro or c == S.CB2_InitCopyrightScreenAfterBootup
    or c == S.MainCB2_WorldTitleScreen or c == S.CB2_InitMainMenu or c == S.CB2_MainMenu
    or c == S.CB2_InitTitleScreen
end

-- Lance's ceremony, the Hall of Fame screen, the soft reset to the title, then CONTINUE.
local function playHallOfFame()
  local front = false
  for f = 1, 60000 do
    if isFrontEnd(F.cb2()) then front = true; break end
    if f % 600 == 0 and F.reportCrash("hof" .. f) then return false end
    if f % 8 == 0 then F.press("A", 2) else F.idle(1) end
  end
  if not F.check("champion: the Hall of Fame ends at the title", front, string.format("cb2=%08X", F.cb2())) then return false end
  for _ = 1, 3000 do
    local c = F.cb2()
    if c == S.MainCB2_WorldTitleScreen or c == S.CB2_MainMenu then break end
    if c == S.MainCB2_Intro then F.press("Start", 2) end
    F.idle(1)
  end
  if F.cb2() == S.MainCB2_WorldTitleScreen then F.idle(120); F.press("Start", 2) end
  for _ = 1, 600 do if F.cb2() == S.CB2_MainMenu then break end F.idle(1) end
  F.idle(90)
  F.press("A", 2)
  for _ = 1, 3000 do if F.ow() then break end F.idle(1) end
  return F.ow()
end

local function keyItems()
  local _, ids = F.keyItemSlot(0xFFFF)
  return ids
end

-- SELECT the registered HUB PASS, answer its YES (the confirm rests on NO), and land in the hub.
local function hubPassOut(tag)
  awaitControl(1200)
  F.press("Select", 2); F.idle(90)
  if not yesNo(0, tag) then F.shot(tag .. "_noconfirm"); return false end
  for _ = 1, 600 do if mapIs(HUB_G, HUB_M) and F.ow() then break end F.idle(2) end
  awaitControl(1200)
  return mapIs(HUB_G, HUB_M)
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  F.idle(40)
  -- Into Johto the way a new player goes, through the Hub's JOHTO gate, which hands over the HUB PASS.
  setSb1Flag(FLAG_HUB_INTRO_TOUR_DONE)
  local bagBefore = keyItems()
  local hubPass
  if F.check("start: walk up to the JOHTO attendant", F.route({ ATTENDANT_JOHTO_TALK }, "johto_gate0"), where()) then
    F.face("Up")
    F.press("A", 2); F.idle(30)
    F.check("start: the JOHTO gate's YES leaves the hub", mashUntilLeft(HUB_G, HUB_M, "johto_gate0"), where())
  end
  awaitControl(2400)
  F.check("start: the player is in JOHTO", region() == REGION_JOHTO, "region=" .. region() .. " " .. where())
  local seen = {}
  for _, id in ipairs(bagBefore) do seen[id] = true end
  for _, id in ipairs(keyItems()) do if not seen[id] then hubPass = id end end
  if not F.check("start: the gate handed over the HUB PASS", hubPass ~= nil) then F.finish(); return end
  F.w16(F.sb1() + S.SaveBlock1.registeredItem, hubPass)
  setParty()
  F.check("Set Party published a party", F.r8(S.gPartiesCount) ~= 0)

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

  -- The League: Lance's Hall of Fame ceremony, as the Champion's room leaves it.
  regionVar(VAR_LEAGUE_STATE, 6)
  if not F.check("champion: into the Johto Hall of Fame", warp(HOF_G, HOF_M, 0, "hof"), where()) then F.finish(); return end
  local continued = playHallOfFame()
  F.check("champion: CONTINUE reaches the field", continued, string.format("cb2=%08X", F.cb2()))
  if not continued then F.finish(); return end
  awaitControl(3000)
  F.check("champion: CONTINUE lands in New Bark Town", mapIs(NEWBARK_G, NEWBARK_M), where())
  F.check("champion: the ceremony made the player Johto champion", sb1Flag(FLAG_JOHTO_CHAMPION))
  F.shot("champion_newbark")

  -- To Kanto through the Hub's gate, and back with the HUB PASS and the Johto gate. No boat.
  F.check("hub: the HUB PASS leaves New Bark Town", hubPassOut("hubpass1"), where())
  if F.check("hub: walk up to the KANTO attendant", F.route({ { ATTENDANT_KANTO_TALK[1], 4 }, ATTENDANT_KANTO_TALK }, "kanto_gate"), where()) then
    F.face("Up")
    F.press("A", 2); F.idle(30)
    F.check("hub: the KANTO gate's YES leaves the hub", mashUntilLeft(HUB_G, HUB_M, "kanto_gate"), where())
  end
  awaitControl(2400)
  F.check("hub: the player is in KANTO", region() == REGION_KANTO, "region=" .. region() .. " " .. where())
  F.shot("hub_kanto")
  F.check("hub: the HUB PASS leaves KANTO", hubPassOut("hubpass2"), where())
  if F.check("hub: walk up to the JOHTO attendant", F.route({ ATTENDANT_JOHTO_TALK }, "johto_gate"), where()) then
    F.face("Up")
    F.press("A", 2); F.idle(30)
    F.check("hub: the JOHTO gate's defaults leave the hub", mashUntilLeft(HUB_G, HUB_M, "johto_gate"), where())
  end
  awaitControl(2400)
  F.check("hub: the player is back in JOHTO", region() == REGION_JOHTO, "region=" .. region() .. " " .. where())
  F.check("hub: the remembered Johto team came back", F.r8(S.gPartiesCount) ~= 0, "party=" .. F.r8(S.gPartiesCount))
  F.shot("hub_johto")

  for _, c in ipairs(CAMEOS) do
    F.check("champion: " .. c[1] .. "'s cameo hide flag is clear", not johtoFlag(c[2]))
  end
  for _, c in ipairs(IN_REACH) do
    local name, g, m, w, id, x, y, path, facing, word = table.unpack(c)
    if F.check("champion: warp to " .. name .. "'s map", warp(g, m, w, name .. "2"), where()) then
      awaitControl(1200)
      F.idle(20)
      local o = object(id)
      F.check("champion: " .. name .. " stands at (" .. x .. "," .. y .. ")",
        shown(o) and o.x == x and o.y == y, describe(o))
      F.shot("champion_" .. name)
      if shown(o) and F.check("champion: walk up to " .. name, F.route(path, name), where()) then
        F.face(facing)
        local ok, said = talk(name)
        F.L("  " .. name .. " said: " .. said)
        F.check("champion: " .. name .. "'s scene returns control", ok, where())
        F.check("champion: " .. name .. "'s line names " .. word, said:find(word, 1, true) ~= nil, said)
        F.check("champion: " .. name .. "'s line sends no one to the DOJO", said:find("DOJO", 1, true) == nil, said)
        F.check("champion: " .. name .. " leaves after her line", johtoFlag(FLAG_OF[name]))
        F.check("champion: " .. name .. " is gone", not shown(object(id)), describe(object(id)))
      end
    end
  end

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
    if MET[c[1]] then
      F.check("voyage: " .. c[1] .. ", already met, stays gone", johtoFlag(c[2]))
    else
      F.check("voyage: " .. c[1] .. "'s cameo hide flag is still clear", not johtoFlag(c[2]))
    end
  end

  if not F.check("voyage: into the Department Store 6F", warp(DEPT6_G, DEPT6_M, 0, "dept6"), where()) then F.finish(); return end
  awaitControl(1200)
  local whitney = object(4)
  F.check("voyage: Whitney does not come back", not shown(whitney), describe(whitney))
  F.shot("voyage_dept6")
  F.check("no crash screen", not F.reportCrash("end"))
  F.shot("end")
  F.finish()
end)
