-- Escort ("follow me") scenes, run live and stressed.
--
-- Each escort is started from its real trigger (a coord event or talking to the guide), the
-- dialogue that decides whether the walk happens is answered deliberately, and then the walk is
-- hammered: A, B, Start, Select, L, R and every direction, cycling every few frames, until the
-- script context shuts down. Start never opens the menu while the script holds the player, so
-- "save and reload mid-escort" is not reachable and is asserted as such.
--
-- After each walk the suite checks what the script promised: the guide left or is home, the story
-- flags and vars landed, the player stands on the tile the movement scripts end on, the field is
-- live (a real step lands), and nothing crashed. Escorts covered:
--   Cherrygrove guide gent  coord triggers Top / Mid / Bottom, decline, then a talk re-offer
--   Violet City Earl        talked to from the south and from the east (both VAR_FACING cases)
--   Pewter City gym guide   coord trigger, and talked to from the west and from the east
-- The World Transit intro tour has its own suites (HubIntroTour, HubIntroTourFollower).
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/EscortStress.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "EscortStress")

local HUB_GROUP = 100
local CONTEXT_SHUTDOWN = 2
local VBLANK = 0x20                    -- gMain.vblankCounter1

local FLAG_JOHTO_BASE, VAR_JOHTO_BASE, VAR_KANTO_BASE = 0x6000, 0xA080, 0xA000
local FLAG_KANTO_BASE = 0xA40
local FLAG_HIDE_GUIDE_GENT_CHERRYGROVE = FLAG_JOHTO_BASE + 0x08
local FLAG_HIDE_CHERRYGROVE_GUIDE_GENT_HOUSE = FLAG_JOHTO_BASE + 0x0A
local FLAG_HIDE_VIOLET_CITY_EARL = FLAG_JOHTO_BASE + 0x17
local VAR_CHERRYGROVE_CITY_STATE = VAR_JOHTO_BASE + 0x02
local VAR_MAP_SCENE_PEWTER_CITY = VAR_KANTO_BASE + 0x45
local FLAG_HIDE_PEWTER_CITY_GYM_GUIDE = FLAG_KANTO_BASE + 0x2E

local CHERRYGROVE = { grp = 75, map = 1, warp = 4 }   -- House 3 door (50,17)
local VIOLET = { grp = 75, map = 6, warp = 3 }        -- Mart door (16,35)
local PEWTER = { grp = 37, map = 2, warp = 3 }        -- Mart door (28,18)
local GENT, EARL, GYM_GUIDE = 1, 4, 5

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end

local function go(m, tag)
  if F.grp() == m.grp and F.mapn() == m.map then
    local gh, gt, go_ = d(HUB_GROUP)
    F.warpTo(gh, gt, go_, 0, 0, 0, 0, 0, 0, HUB_GROUP, 0, tag .. "_via_hub")
    F.idle(60)
  end
  local gh, gt, go_ = d(m.grp)
  local mh, mt, mo = d(m.map)
  local wh, wt, wo = d(m.warp)
  local ok = F.warpTo(gh, gt, go_, mh, mt, mo, wh, wt, wo, m.grp, m.map, tag)
  F.check(tag .. "_warped", ok, string.format("grp=%d map=%d", F.grp(), F.mapn()))
  F.idle(90)
  return ok
end

local function flagAddr(id)
  if id >= FLAG_JOHTO_BASE then
    return F.sb3() + S.SaveBlock3.johtoFlags + (id - FLAG_JOHTO_BASE) // 8
  end
  return F.sb1() + S.SaveBlock1.flags + id // 8
end
local function flagGet(id) return (F.r8(flagAddr(id)) & (1 << (id % 8))) ~= 0 end
local function flagSet(id, on)
  local a, m = flagAddr(id), 1 << (id % 8)
  F.w8(a, on and (F.r8(a) | m) or (F.r8(a) & ~m & 0xFF))
end
local function varAddr(id) return F.sb3() + S.SaveBlock3.regionVars + (id - 0xA000) * 2 end
local function varGet(id) return F.r16(varAddr(id)) end
local function varSet(id, v) F.w16(varAddr(id), v) end

local function obj(localId)
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == localId then
      return { x = F.rs16(b + S.ObjectEvent.x) - 7, y = F.rs16(b + S.ObjectEvent.y) - 7,
               invisible = (F.r8(b + S.ObjectEvent.flags1) & 0x20) ~= 0 }
    end
  end
  return nil
end
local function at(o) return o and string.format("(%d,%d)", o.x, o.y) or "ABSENT" end
local function scriptIdle() return F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN end
local function menuOpen() return F.r32(S.sUsmState) ~= 0 end
local function vblank() return F.r32(S.gMain + VBLANK) end

-- Press only `btn` until the guide leaves its tile (the walk has begun) or the script ends.
local function answerUntilMoving(btn, guideId, maxFrames)
  local o0 = obj(guideId)
  for f = 1, maxFrames do
    if f % 8 < 2 then joypad.set({ [btn] = true }) else joypad.set({}) end
    emu.frameadvance()
    local o = obj(guideId)
    if o0 and (not o or o.x ~= o0.x or o.y ~= o0.y) then return "moving" end
    if f > 30 and scriptIdle() then return "ended" end
  end
  return "timeout"
end

local STRESS = { "A", "B", "Start", "Up", "Select", "Left", "A", "Down", "B", "Right", "L", "R", "Start" }

-- Mash everything until the script context shuts down. Returns a report table.
local function stressUntilDone(maxFrames)
  local r = { frames = 0, menu = false, leftOw = false, stall = false }
  local lastVb, sameVb = vblank(), 0
  for f = 1, maxFrames do
    local btn = STRESS[(f // 6) % #STRESS + 1]
    if f % 6 < 2 then joypad.set({ [btn] = true }) else joypad.set({}) end
    emu.frameadvance()
    r.frames = f
    if menuOpen() then r.menu = true end
    if not F.ow() then r.leftOw = true end
    local vb = vblank()
    if vb == lastVb then sameVb = sameVb + 1 else sameVb = 0 end
    lastVb = vb
    if sameVb > 120 then r.stall = true; break end
    if f > 10 and scriptIdle() then
      r.x, r.y = F.pos()
      joypad.set({}); emu.frameadvance()
      return r, true
    end
  end
  r.x, r.y = F.pos()
  return r, false
end

local function verifyWalk(tag, r, done, wantX, wantY)
  F.L(string.format("  %s: %d stress frames, done=%s end (%s,%s) menu=%s leftOw=%s stall=%s",
    tag, r.frames, tostring(done), tostring(r.x), tostring(r.y), tostring(r.menu), tostring(r.leftOw), tostring(r.stall)))
  F.check(tag .. "_script_finished_under_stress", done, r.frames .. " frames")
  F.check(tag .. "_no_crash_or_freeze", not r.stall and not F.reportCrash(tag), "vblank stalled")
  F.check(tag .. "_start_never_opened_menu_mid_escort", not r.menu, "menu opened")
  F.check(tag .. "_stayed_on_field", not r.leftOw, "left CB2_Overworld")
  F.check(tag .. "_player_on_final_tile", r.x == wantX and r.y == wantY,
    string.format("(%s,%s) want (%d,%d)", tostring(r.x), tostring(r.y), wantX, wantY))
  F.idle(30)
  for _ = 1, 6 do F.press("B", 2); F.idle(10) end
  F.check(tag .. "_player_free_after", F.ensureFree(), "no step landed")
end

---------------------------------------------------------------------------------------------
-- Cherrygrove guide gent. Gent (57,8); triggers (57,9/10/11) need VAR_CHERRYGROVE_CITY_STATE 0.
-- Every accepted tour ends with the player on (41,16) and the gent gone into House 2.
---------------------------------------------------------------------------------------------
local GENT_END = { 41, 16 }

local function resetGent(tag)
  varSet(VAR_CHERRYGROVE_CITY_STATE, 0)
  flagSet(FLAG_HIDE_GUIDE_GENT_CHERRYGROVE, false)
  flagSet(FLAG_HIDE_CHERRYGROVE_GUIDE_GENT_HOUSE, false)
  if not go(CHERRYGROVE, tag) then return false end
  local ok = F.route({ { 47, 18 }, { 47, 11 }, { 56, 11 } }, tag)
  F.check(tag .. "_gent_home", at(obj(GENT)) == "(57,8)", at(obj(GENT)))
  return ok
end

local function gentDone(tag)
  F.check(tag .. "_gent_removed", obj(GENT) == nil, at(obj(GENT)))
  F.check(tag .. "_gent_hidden_in_city", flagGet(FLAG_HIDE_GUIDE_GENT_CHERRYGROVE), "flag clear")
  F.check(tag .. "_gent_shown_in_house", not flagGet(FLAG_HIDE_CHERRYGROVE_GUIDE_GENT_HOUSE), "flag set")
  F.check(tag .. "_city_state_1", varGet(VAR_CHERRYGROVE_CITY_STATE) == 1, "var=" .. varGet(VAR_CHERRYGROVE_CITY_STATE))
end

local function gentTrigger(tag, approachY)
  if not resetGent(tag) then return end
  if approachY ~= 11 then F.leg(56, approachY) end
  F.step("Right")
  local how = answerUntilMoving("A", GENT, 900)
  F.check(tag .. "_tour_started", how == "moving", how)
  local r, done = stressUntilDone(6000)
  verifyWalk(tag, r, done, GENT_END[1], GENT_END[2])
  gentDone(tag)
  F.shot(tag)
end

local function cherrygrove()
  -- Decline at the Bottom trigger: released, state 1, gent stays for a re-offer.
  if not resetGent("gent_decline") then return end
  F.step("Right")
  local how = answerUntilMoving("B", GENT, 900)
  F.check("gent_decline_no_walk", how == "ended", how)
  F.check("gent_decline_state_1", varGet(VAR_CHERRYGROVE_CITY_STATE) == 1, "var=" .. varGet(VAR_CHERRYGROVE_CITY_STATE))
  F.check("gent_decline_gent_stays", at(obj(GENT)) == "(57,8)", at(obj(GENT)))
  F.check("gent_decline_player_free", F.ensureFree(), "no step landed")

  -- Re-offer by talking: the only tile next to him is (57,9); triggers are dead at state 1.
  F.leg(56, 9); F.step("Right"); F.face("Up")
  F.press("A", 2)
  how = answerUntilMoving("A", GENT, 900)
  F.check("gent_talk_tour_started", how == "moving", how)
  local r, done = stressUntilDone(6000)
  verifyWalk("gent_talk", r, done, GENT_END[1], GENT_END[2])
  gentDone("gent_talk")

  gentTrigger("gent_top", 9)
  gentTrigger("gent_mid", 10)
  gentTrigger("gent_bottom", 11)
end

---------------------------------------------------------------------------------------------
-- Violet City Earl at (18,35). Reachable only from (18,36) facing north and (19,35) facing west,
-- the two VAR_FACING cases the script switches on. Saying NO (B) starts the walk to the Trainer
-- School; both paths end with the player on (38,38) and Earl gone through the door at (39,36).
---------------------------------------------------------------------------------------------
local function earl(tag, standX, standY, faceDir)
  flagSet(FLAG_HIDE_VIOLET_CITY_EARL, false)
  if not go(VIOLET, tag) then return end
  if not F.route({ { 18, 36 }, { standX, standY } }, tag) then return end
  F.check(tag .. "_earl_home", at(obj(EARL)) == "(18,35)", at(obj(EARL)))
  F.face(faceDir)
  F.press("A", 2)
  local how = answerUntilMoving("B", EARL, 1500)
  F.check(tag .. "_walk_started", how == "moving", how)
  local r, done = stressUntilDone(6000)
  verifyWalk(tag, r, done, 38, 38)
  F.check(tag .. "_earl_removed", obj(EARL) == nil, at(obj(EARL)))
  F.check(tag .. "_earl_hidden", flagGet(FLAG_HIDE_VIOLET_CITY_EARL), "flag clear")
  F.shot(tag)
end

---------------------------------------------------------------------------------------------
-- Pewter City gym guide (42,20). Coord triggers at (42..43,21..23) need VAR_MAP_SCENE_PEWTER_CITY
-- 0; talking to him works at any scene value. Both walk the player to the gym door.
---------------------------------------------------------------------------------------------
local PEWTER_APPROACH = {
  trigger = { scene = 0, route = { { 28, 21 }, { 41, 21 }, { 41, 22 } }, act = function() F.step("Right") end, final = { 15, 18 } },
  west    = { scene = 1, route = { { 28, 20 }, { 41, 20 } }, act = function() F.face("Right"); F.press("A", 2) end, final = { 15, 18 } },
  -- From the Route 3 side. VAR_FACING is WEST, so the script skips the walk: the guide says his
  -- lines, walks off alone, and the player keeps the tile. Asserted so it can never hang.
  east    = { scene = 1, route = { { 28, 21 }, { 43, 21 }, { 43, 20 } }, act = function() F.face("Left"); F.press("A", 2) end, final = { 43, 20 } },
}

local function pewter(tag, mode)
  local m = PEWTER_APPROACH[mode]
  varSet(VAR_MAP_SCENE_PEWTER_CITY, m.scene)
  flagSet(FLAG_HIDE_PEWTER_CITY_GYM_GUIDE, false)
  if not go(PEWTER, tag) then return end
  if not F.route(m.route, tag) then return end
  F.check(tag .. "_guide_home", at(obj(GYM_GUIDE)) == "(42,20)", at(obj(GYM_GUIDE)))
  m.act()
  local how = answerUntilMoving("A", GYM_GUIDE, 1500)
  F.check(tag .. "_guide_moved", how == "moving", how)
  local r, done = stressUntilDone(6000)
  -- Read before any step: the script clears FLAG_HIDE_PEWTER_CITY_GYM_GUIDE, so he respawns home
  -- on the next camera update, by design (he greets every visit until Brock falls).
  F.check(tag .. "_guide_removed_at_script_end", obj(GYM_GUIDE) == nil, at(obj(GYM_GUIDE)))
  verifyWalk(tag, r, done, m.final[1], m.final[2])
  F.check(tag .. "_scene_unchanged", varGet(VAR_MAP_SCENE_PEWTER_CITY) == m.scene, "scene=" .. varGet(VAR_MAP_SCENE_PEWTER_CITY))
  F.shot(tag)
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  F.check("player is free", F.ensureFree())
  cherrygrove()
  earl("earl_south", 18, 36, "Up")
  earl("earl_east", 19, 35, "Left")
  pewter("pewter_trigger", "trigger")
  pewter("pewter_talk_west", "west")
  pewter("pewter_talk_east", "east")
  F.finish()
end)
