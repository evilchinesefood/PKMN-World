-- After the Hoenn Hall of Fame, Continue puts the player outside their own house in Littleroot, as
-- Kanto (Pallet (6,8)) and Johto (New Bark (20,12)) already do. Brendan and May live in different
-- houses, so for each gender: Littleroot's progress is seeded the way the intro leaves it (Mom, rival-family
-- and moving-day hide flags, intro state 7, the player's house state 2), the Hall of Fame room's own
-- ON_FRAME runs the ceremony with plain A presses, and the title's Continue must land in front of
-- that gender's door, facing down, with the whiteout point on the same doorstep.
--
-- The first induction arms two scenes. Birch's "something to show you" plays on the doorstep at
-- once and leads to the lab, where the player must be able to walk. The S.S. Ticket and Lati TV scene in the player's 1F used to start
-- from the stairs only; now it starts from the front door, so the suite then enters the rival's
-- house (no scene, no Norman there), and its own house by the door: the scene must run with the
-- player inside the room the whole time, end below the TV facing Mom, give the ticket and the roamer, and
-- return control. Two more entries re-arm the scene the way the Hall of Fame leaves it: down the
-- stairs from the bedroom (an older save that continued in 2F) and a whiteout, which respawns the
-- player beside Mom.
--
-- Nothing on the doorstep says the ticket waits inside, so Mom calls the champion home. The Hall of
-- Fame arms the player's house state at 6; the first time the player has control in Littleroot, Mom
-- appears at their own door, says Dad is home, and the state becomes 3 (Norman shown, scene armed).
-- The suite walks out of the lab and expects exactly one call from the right door with control after
-- it, walks into the lab and out again and expects none, runs a second induction with the ticket
-- still waiting (Continue lands on the doorstep, so Mom calls from the doorway behind the player), and
-- walks out of the house after the scene and expects none.
--
-- PW_HOME_ONLY=male|female runs one gender.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "HoennHofHome")

local ONLY = os.getenv("PW_HOME_ONLY")
local HUB_GROUP = 100
local MALE, FEMALE = 0, 1
local CONTEXT_RUNNING = 0
local DIR_SOUTH, DIR_NORTH, DIR_WEST, DIR_EAST = 1, 2, 3, 4
local TOWN = { 0, 9 }
local LAB = { 1, 4 }
local HOF = { 16, 11 }
local LOCALID_DAD = 5
local LOCALID_TOWN_MOM = 4
local STATE_CALL_PENDING, STATE_DAD_WAITING, STATE_SCENE_DONE, STATE_LEFT_HOUSE = 6, 3, 4, 5
local ITEM_SS_TICKET = 727

local VARS_START = 0x4000
local VAR_HOUSES_MAY, VAR_HOUSES_BRENDAN = 0x4082, 0x408C
local VAR_INTRO, VAR_TOWN_STATE, VAR_RIVAL_STATE = 0x4092, 0x4050, 0x408D
local VAR_DEX_UPGRADE = 0x40D3
local FLAG_RECEIVED_SS_TICKET = 0x123
local FLAG_HIDE_DAD = 0x2DE
local FLAG_RESCUED_BIRCH = 0x52
local FLAG_HIDE_VIGOROTH_1, FLAG_HIDE_VIGOROTH_2 = 0x2F2, 0x2F3
local FLAG_LATI_ROAMING = 0xFF

local ROW_PARTY_MENU, ROW_SET, ROW_BATTLE = 2, 9, 10
local B_OUTCOME_LOST = 2

-- Per gender: the house maps, the doorstep, the whiteout tile beside Mom, where the scene leaves
-- the player (below the TV), the walk from there to the front door's mat and the intro's hide flags.
local HOMES = {
  male = {
    gender = MALE, var = VAR_HOUSES_BRENDAN, own1F = { 1, 0 }, own2F = { 1, 1 }, rival1F = { 1, 2 },
    door = { x = 5, y = 9, warp = 1 }, rivalDoor = 0, beside = { 2, 7 }, tv = { 4, 5 }, faceMom = DIR_EAST,
    exitRoute = { { 2, 5 }, { 2, 8 }, { 8, 8 } },
    hide = { 0x2F7, 0x2FA, 0x310, 0x2DF, 0x331, 0x2F9 }, show = { 0x2F6 },
  },
  female = {
    gender = FEMALE, var = VAR_HOUSES_MAY, own1F = { 1, 2 }, own2F = { 1, 3 }, rival1F = { 1, 0 },
    door = { x = 14, y = 9, warp = 0 }, rivalDoor = 1, beside = { 8, 7 }, tv = { 6, 5 }, faceMom = DIR_WEST,
    exitRoute = { { 8, 5 }, { 8, 8 }, { 2, 8 } },
    hide = { 0x2F6, 0x2F9, 0x311, 0x2E0, 0x332, 0x2FA }, show = { 0x2F7 },
  },
}

local function varAddr(id) return F.sb1() + S.SaveBlock1.vars + (id - VARS_START) * 2 end
local function varGet(id) return F.r16(varAddr(id)) end
local function varSet(id, v) F.w16(varAddr(id), v) end
local function flagAddr(id) return F.sb1() + S.SaveBlock1.flags + (id // 8) end
local function flagGet(id) return (F.r8(flagAddr(id)) & (1 << (id % 8))) ~= 0 end
local function flagSet(id) F.w8(flagAddr(id), F.r8(flagAddr(id)) | (1 << (id % 8))) end
local function flagClear(id) F.w8(flagAddr(id), F.r8(flagAddr(id)) & ~(1 << (id % 8)) & 0xFF) end

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function warp(g, m, w, tag)
  local gh, gt, go = d(g)
  local mh, mt, mo = d(m)
  local wh, wt, wo = d(w)
  return F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, g, m, tag)
end

local function at(map) return F.grp() == map[1] and F.mapn() == map[2] end
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function cb2() return F.cb2() end
local function running() return F.r8(S.sGlobalScriptContextStatus) == CONTEXT_RUNNING end
local function hasControl() return F.ow() and F.r8(S.sLockFieldControls) == 0 and not running() end

local function playerObj()
  for i = 0, 15 do
    local a = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(a) & 1) == 1 and F.r8(a + S.ObjectEvent.localId) == 0xFF then return a end
  end
end
local function facing() local a = playerObj(); return a and (F.r16(a + S.ObjectEvent.facing) & 0xF) or -1 end
local function dadVisible()
  for i = 0, 15 do
    local a = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(a) & 1) == 1 and F.r8(a + S.ObjectEvent.localId) == LOCALID_DAD and (F.r8(a + S.ObjectEvent.flags1) & 0x20) == 0 then
      return true
    end
  end
  return false
end

-- Littleroot's Mom (outside), as map coordinates, while she is on screen and visible.
local function townMom()
  if not at(TOWN) then return nil end
  for i = 0, 15 do
    local a = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(a) & 1) == 1 and F.r8(a + S.ObjectEvent.localId) == LOCALID_TOWN_MOM and (F.r8(a + S.ObjectEvent.flags1) & 0x20) == 0 then
      return F.rs16(a + S.ObjectEvent.x) - 7, F.rs16(a + S.ObjectEvent.y) - 7
    end
  end
end

local function heal()
  local a = F.sb1() + S.SaveBlock1.lastHealLocation
  return F.rs8(a), F.rs8(a + 1), F.rs16(a + 4), F.rs16(a + 6)
end

local function tapDown(n) for _ = 1, n do F.press("Down", 3); F.idle(16) end end
local function setParty()
  F.dbg(); F.idle(60)
  tapDown(ROW_PARTY_MENU); F.press("A", 3); F.idle(60)
  tapDown(ROW_SET); F.press("A", 3); F.idle(180)
  for _ = 1, 6 do F.press("B", 3); F.idle(20) end
end

local function isFrontEnd(c)
  return c == S.MainCB2_Intro or c == S.CB2_InitCopyrightScreenAfterBootup
    or c == S.MainCB2_WorldTitleScreen or c == S.CB2_InitMainMenu or c == S.CB2_MainMenu
    or c == S.CB2_InitTitleScreen
end

-- The room's ON_FRAME walks the player in and starts the ceremony; A advances it to the soft reset.
local function induct(tag)
  if not warp(HOF[1], HOF[2], 0, tag .. "_hof") then return false, "warp " .. where() end
  for f = 1, 60000 do
    if isFrontEnd(cb2()) then return true end
    if f % 600 == 0 and F.noteCrash(tag .. "_hof" .. f) then return false, "crash" end
    if f % 2400 == 0 then F.shot(string.format("%s_hof_%05d", tag, f)) end
    if f % 12 == 0 then F.press("A", 2) else F.idle(1) end
  end
  return false, string.format("cb2=%08X", cb2())
end

local function continueFromFrontEnd(tag)
  for _ = 1, 3000 do
    local c = cb2()
    if c == S.MainCB2_WorldTitleScreen or c == S.CB2_MainMenu then break end
    if c == S.MainCB2_Intro then F.press("Start", 2) end
    F.idle(1)
  end
  if cb2() == S.MainCB2_WorldTitleScreen then F.idle(120); F.press("Start", 2) end
  for _ = 1, 600 do if cb2() == S.CB2_MainMenu then break end F.idle(1) end
  F.idle(90)
  if cb2() ~= S.CB2_MainMenu then F.shot(tag .. "_no_menu"); return false end
  F.press("A", 2)
  for _ = 1, 3000 do if F.ow() then return true end F.idle(1) end
  return F.ow()
end

-- Littleroot as the intro leaves it for this gender, before any Hall of Fame.
local function seed(h)
  F.w8(F.sb2() + S.SaveBlock2.playerGender, h.gender)
  varSet(VAR_INTRO, 7); varSet(VAR_TOWN_STATE, 4); varSet(VAR_RIVAL_STATE, 4)
  varSet(VAR_HOUSES_MAY, 0); varSet(VAR_HOUSES_BRENDAN, 0); varSet(h.var, 2)
  varSet(VAR_DEX_UPGRADE, 0)
  flagSet(FLAG_RESCUED_BIRCH); flagSet(FLAG_HIDE_DAD); flagSet(FLAG_HIDE_VIGOROTH_1); flagSet(FLAG_HIDE_VIGOROTH_2)
  flagClear(FLAG_RECEIVED_SS_TICKET); flagClear(FLAG_LATI_ROAMING)
  for _, id in ipairs(h.hide) do flagSet(id) end
  for _, id in ipairs(h.show) do flagClear(id) end
end

-- What a Hall of Fame leaves for a champion who has not had the ticket scene yet. A save from
-- before this change has both house states at 3 and Norman's hide flag clear.
local function rearm(h, oldSave)
  varSet(VAR_HOUSES_MAY, oldSave and 3 or 0); varSet(VAR_HOUSES_BRENDAN, oldSave and 3 or 0); varSet(h.var, 3)
  flagClear(FLAG_RECEIVED_SS_TICKET); flagClear(FLAG_LATI_ROAMING)
  if oldSave then flagClear(FLAG_HIDE_DAD) end
end

-- Free on the field, then 30 quiet frames: the steps that prove control can start a Match Call
-- (Scott's Battle Frontier call comes after the Hall of Fame), whose text only A advances.
local function freeUp()
  local free = false
  for _ = 1, 60 do if F.ensureFree() then free = true; break end F.press("B", 2); F.idle(20) end
  if not free then return false end
  local calm = 0
  for i = 1, 3000 do
    calm = hasControl() and calm + 1 or 0
    if calm >= 30 then return true end
    if calm == 0 and i % 30 == 0 then F.press("A", 2) else F.idle(1) end
  end
  return false
end

-- Walk into a 1F (already standing on the doorstep or the stairs approach) with a held press.
local function stepInto(dir, map)
  joypad.set({ [dir] = true })
  for _ = 1, 40 do emu.frameadvance(); if at(map) then break end end
  joypad.set({})
  for _ = 1, 120 do if at(map) and F.ow() then break end F.idle(1) end
  return at(map)
end

-- Drive the ticket scene with A (the Lati multichoice takes its first row), tracking every tile the
-- player stands on. The scene's last step sets the house state to 4. Returns whether it finished
-- with control back and the tiles seen.
local function driveScene(tag, h)
  local tiles, seen = {}, {}
  for f = 1, 9000 do
    local x, y = F.pos()
    local k = x .. "," .. y
    if not seen[k] then seen[k] = true; tiles[#tiles + 1] = { x, y } end
    if varGet(h.var) ~= 3 and hasControl() then return true, tiles end
    if f % 600 == 0 and F.noteCrash(tag .. f) then break end
    if f == 240 then F.shot(tag .. "_dad") end
    if f % 24 == 0 then F.press("A", 2) else F.idle(1) end
  end
  return false, tiles
end

-- Watch Littleroot after an arrival: count Mom's appearances, note where she first stood, screenshot
-- the call, and wait for 30 frames of steady control with no call pending. B advances the text
-- slowly enough for each page to be on screen in a shot.
local function watchTown(tag, h, frames)
  local r = { shows = 0, ctl = false }
  local was, calm, first = false, 0, nil
  for f = 1, frames do
    local mx, my = townMom()
    if mx and not was then
      r.shows = r.shows + 1
      if not r.at then r.at = { mx, my }; first = f end
    end
    was = mx ~= nil
    if first and f > first and (f - first) % 90 == 1 and f - first < 600 then F.shot(string.format("%s_call_%d", tag, f - first)) end
    calm = (hasControl() and varGet(h.var) ~= STATE_CALL_PENDING) and calm + 1 or 0
    if calm >= 30 then r.ctl = true; break end
    if f % 600 == 0 and F.noteCrash(tag .. f) then break end
    if f % 90 == 0 and not hasControl() then F.press("B", 2) else F.idle(1) end
  end
  r.state = varGet(h.var)
  r.x, r.y = F.pos()
  r.facing = facing()
  F.shot(tag .. "_after")
  F.L(string.format("  %s: Mom shown %d time(s)%s, state %d, control %s at %s facing %d", tag, r.shows,
    r.at and string.format(" first at (%d,%d)", r.at[1], r.at[2]) or "", r.state, tostring(r.ctl), where(), r.facing))
  return r
end

local function momAtDoor(r, h)
  return r.at ~= nil and r.at[1] == h.door.x and (r.at[2] == h.door.y or r.at[2] == h.door.y - 1)
end

-- Hold a direction until the map changes to `map` (walking through a door or off a mat).
local function holdInto(dir, map)
  for _ = 1, 240 do if hasControl() then break end F.idle(1) end
  joypad.set({ [dir] = true })
  for _ = 1, 180 do emu.frameadvance(); if at(map) then break end end
  joypad.set({})
  return at(map)
end

local function tileList(t)
  local o = {}
  for _, p in ipairs(t) do o[#o + 1] = string.format("(%d,%d)", p[1], p[2]) end
  return table.concat(o, " ")
end

-- Shared checks for one run of the ticket scene.
local function checkScene(tag, h, ok, tiles)
  local x, y = F.pos()
  F.shot(tag .. "_end")
  F.L(string.format("  %s: tiles %s", tag, tileList(tiles)))
  F.check(tag .. ": control returns", ok, where())
  local inside = true
  for _, p in ipairs(tiles) do
    if p[1] < 0 or p[1] > 10 or p[2] < 2 or p[2] > 8 then inside = false end
  end
  F.check(tag .. ": the player stays inside the room", inside, tileList(tiles))
  F.check(tag .. ": the scene ends below the TV, facing Mom", at(h.own1F) and x == h.tv[1] and y == h.tv[2] and facing() == h.faceMom,
    string.format("%s facing %d", where(), facing()))
  F.check(tag .. ": the S.S. Ticket was given", flagGet(FLAG_RECEIVED_SS_TICKET) and F.itemCount(ITEM_SS_TICKET) == 1,
    string.format("flag=%s slots=%d", tostring(flagGet(FLAG_RECEIVED_SS_TICKET)), F.itemCount(ITEM_SS_TICKET)))
  F.check(tag .. ": the Lati is roaming", flagGet(FLAG_LATI_ROAMING))
  F.check(tag .. ": the scene is done", varGet(h.var) == 4, "state=" .. varGet(h.var))
  F.check(tag .. ": Norman left", not dadVisible() and flagGet(FLAG_HIDE_DAD))
end

local function whiteOut(tag)
  F.dbg(); F.idle(60)
  tapDown(ROW_PARTY_MENU); F.press("A", 3); F.idle(60)
  tapDown(ROW_BATTLE); F.press("A", 3); F.idle(30)
  local left = false
  for _ = 1, 800 do F.idle(8); if not F.ow() then left = true; break end end
  if not left then F.shot(tag .. "_no_battle"); return false, "the debug battle never started" end
  for _ = 1, 400 do if F.battlers() > 0 then break end F.idle(4) end
  for t = 1, 4000 do
    F.w8(S.gBattleOutcome, B_OUTCOME_LOST)
    for i = 0, 5 do
      local b = S.gParties + i * S.Pokemon.size
      if F.r16(b + S.Pokemon.maxHP) ~= 0 then F.w16(b + S.Pokemon.hp, 0) end
    end
    for i = 0, math.min(F.battlers(), 4) - 1 do F.w16(S.gBattleMons + i * S.BattlePokemon.size + S.BattlePokemon.hp, 0) end
    F.press("A", t % 3 == 0 and 2 or 1); F.idle(1)
    if t % 60 == 0 and F.reportCrash(tag) then return false, "crash" end
    if F.ow() then return true end
  end
  return false, "the whiteout never reached the field"
end

local function home(name, h)
  if ONLY and ONLY ~= name then return end
  F.L("== " .. name .. " ==")
  seed(h)
  local ok, why = induct(name)
  F.check(name .. ": the Hall of Fame ran to the soft reset", ok, why)
  if not ok then return end
  if not F.check(name .. ": Continue reaches the field", continueFromFrontEnd(name), string.format("cb2=%08X", cb2())) then return end
  F.idle(60)
  local x, y = F.pos()
  local dir = facing()
  F.shot(name .. "_landing")
  F.check(name .. ": Continue lands in front of the player's own door",
    at(TOWN) and x == h.door.x and y == h.door.y, string.format("%s, want 0/9 (%d,%d)", where(), h.door.x, h.door.y))
  F.check(name .. ": facing down", dir == DIR_SOUTH, "facing " .. dir)
  local hg, hm, hx, hy = heal()
  F.check(name .. ": the whiteout point is the same doorstep", hg == TOWN[1] and hm == TOWN[2] and hx == h.door.x and hy == h.door.y,
    string.format("%d/%d (%d,%d)", hg, hm, hx, hy))
  local other = h.var == VAR_HOUSES_MAY and VAR_HOUSES_BRENDAN or VAR_HOUSES_MAY
  F.check(name .. ": the Hall of Fame armed only the player's house, with Mom's call pending", varGet(h.var) == STATE_CALL_PENDING
    and varGet(other) ~= STATE_CALL_PENDING and varGet(other) ~= STATE_DAD_WAITING,
    string.format("may=%d brendan=%d", varGet(VAR_HOUSES_MAY), varGet(VAR_HOUSES_BRENDAN)))

  -- Birch waits on the doorstep and leads the player to the lab for the National Dex.
  F.idle(60)
  F.shot(name .. "_birch")
  local inLab = false
  for i = 1, 6000 do
    if at(LAB) and varGet(VAR_DEX_UPGRADE) >= 2 and hasControl() then inLab = true; break end
    if i % 30 == 0 then F.press("B", 2) else F.idle(1) end
  end
  F.shot(name .. "_lab")
  F.check(name .. ": Birch's scene ends in the lab with control", inLab,
    string.format("%s dex=%d", where(), varGet(VAR_DEX_UPGRADE)))
  local walked = false
  for _, dir in ipairs({ "Down", "Right", "Left", "Up" }) do
    local px, py = F.pos()
    local a = playerObj()
    F.L(string.format("  %s: try %s from (%d,%d) facing %d lock=%d status=%d obj0=%02X obj1=%02X obj3=%02X",
      name, dir, px, py, facing(), F.r8(S.sLockFieldControls), F.r8(S.sGlobalScriptContextStatus),
      a and F.r8(a) or 0, a and F.r8(a + 1) or 0, a and F.r8(a + 3) or 0))
    if F.step(dir) then walked = true; break end
  end
  F.check(name .. ": the player can walk in the lab", walked, where())

  -- Out of the lab: Mom calls from the player's own door, once, and the player keeps control.
  if F.route({ { 6, 11 } }, name .. "_lab_exit") and holdInto("Down", TOWN) then
    local r = watchTown(name .. "_lab_out", h, 4000)
    F.check(name .. ": Mom calls the player home after Birch's scene", r.shows >= 1 and r.state == STATE_DAD_WAITING,
      string.format("shown %d, state %d", r.shows, r.state))
    F.check(name .. ": Mom calls only once", r.shows == 1, "shown " .. r.shows)
    F.check(name .. ": Mom calls from the player's own door", momAtDoor(r, h),
      r.at and string.format("(%d,%d)", r.at[1], r.at[2]) or "never shown")
    F.check(name .. ": the player has control after Mom's call", r.ctl and freeUp(), where())
    F.check(name .. ": Mom went back inside", townMom() == nil)
  else
    F.check(name .. ": walked out of the lab", false, where())
  end

  -- Into the lab and out again: the same arrival must not call twice.
  if stepInto("Up", LAB) and holdInto("Down", TOWN) then
    local r = watchTown(name .. "_lab_again", h, 1200)
    F.check(name .. ": no second call on returning to Littleroot", r.shows == 0 and r.ctl and r.state == STATE_DAD_WAITING,
      string.format("shown %d, state %d", r.shows, r.state))
  else
    F.check(name .. ": walked into the lab and out", false, where())
  end

  -- A later Hall of Fame with the ticket still waiting re-arms the call. Continue lands on the
  -- doorstep, so Mom calls from the doorway behind the player.
  local ok2, why2 = induct(name .. "_2")
  F.check(name .. ": a second Hall of Fame ran to the soft reset", ok2, why2)
  if ok2 and F.check(name .. ": Continue after the second Hall of Fame reaches the field", continueFromFrontEnd(name .. "_2")) then
    local r = watchTown(name .. "_doorstep", h, 4000)
    F.check(name .. ": Mom calls on the doorstep after a later Hall of Fame", r.shows == 1 and r.state == STATE_DAD_WAITING,
      string.format("shown %d, state %d", r.shows, r.state))
    F.check(name .. ": Mom calls from the doorway behind the player", r.at ~= nil and r.at[1] == h.door.x and r.at[2] == h.door.y - 1,
      r.at and string.format("(%d,%d)", r.at[1], r.at[2]) or "never shown")
    F.check(name .. ": the player is still on the doorstep, facing the door, with control",
      r.ctl and at(TOWN) and r.x == h.door.x and r.y == h.door.y and r.facing == DIR_NORTH,
      string.format("%s facing %d", where(), r.facing))
  end

  -- The rival's house: nothing starts, and Norman is not standing in the neighbours' living room.
  if warp(TOWN[1], TOWN[2], h.rivalDoor, name .. "_rival_door") and freeUp() and stepInto("Up", h.rival1F) then
    F.idle(120)
    F.shot(name .. "_rival_house")
    F.check(name .. ": no scene in the rival's house", hasControl() and varGet(h.var) == 3, where() .. " state=" .. varGet(h.var))
    F.check(name .. ": no Norman in the rival's house", not dadVisible())
  else
    F.check(name .. ": walked into the rival's house", false, where())
  end

  -- The player's own house, by the front door.
  if warp(TOWN[1], TOWN[2], h.door.warp, name .. "_door") and freeUp() and stepInto("Up", h.own1F) then
    local ex, ey = F.pos()
    F.L(string.format("  %s: entered at (%d,%d)", name, ex, ey))
    local done, tiles = driveScene(name .. "_door_scene", h)
    checkScene(name .. " door", h, done, tiles)
    -- Out of the front door after the scene: no call.
    local mx, my = F.pos()
    F.L(string.format("  %s: leaving the house from (%d,%d)", name, mx, my))
    if F.route(h.exitRoute, name .. "_house_exit") and holdInto("Down", TOWN) then
      local r = watchTown(name .. "_house_out", h, 1200)
      F.check(name .. ": no call after the ticket scene", r.shows == 0 and r.ctl and r.state == STATE_LEFT_HOUSE,
        string.format("shown %d, state %d", r.shows, r.state))
    else
      F.check(name .. ": walked out of the house", false, where())
    end
  else
    F.check(name .. ": walked into the player's house", false, where())
  end

  -- An older save that continued in the bedroom: down the stairs, as before. Re-arm outside, or
  -- the 1F's ON_FRAME starts the scene under the debug menu.
  if warp(TOWN[1], TOWN[2], h.door.warp, name .. "_rearm") and freeUp() then rearm(h, true) end
  if warp(h.own2F[1], h.own2F[2], 0, name .. "_2f") and freeUp() and stepInto("Up", h.own1F) then
    local done, tiles = driveScene(name .. "_stairs_scene", h)
    checkScene(name .. " stairs", h, done, tiles)
  else
    F.check(name .. ": walked down the stairs", false, where())
  end

  -- A whiteout before going home respawns the player beside Mom; Mom heals, then the scene.
  if warp(TOWN[1], TOWN[2], h.door.warp, name .. "_out") and freeUp() then
    rearm(h, false)
    setParty()
    local wok, wwhy = whiteOut(name .. "_whiteout")
    F.check(name .. ": the whiteout reached the field", wok, wwhy)
    if wok then
      local wx, wy = F.pos()
      F.L(string.format("  %s: whiteout landed at %s", name, where()))
      F.check(name .. ": the whiteout lands beside Mom", at(h.own1F) and wx == h.beside[1] and wy == h.beside[2], where())
      local done, tiles = driveScene(name .. "_whiteout_scene", h)
      checkScene(name .. " whiteout", h, done, tiles)
    end
  else
    F.shot(name .. "_not_free_outside")
    F.check(name .. ": free outside before the whiteout", false, where())
  end
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  F.idle(40)
  setParty()
  F.check("Set Party published a party", F.r8(S.gPartiesCount) ~= 0)
  home("male", HOMES.male)
  home("female", HOMES.female)
  F.finish()
end)
