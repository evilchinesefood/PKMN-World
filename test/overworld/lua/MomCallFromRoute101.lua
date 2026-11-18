-- After the first Hoenn Hall of Fame, Mom calls the champion home the first time they have control in
-- Littleroot. Birch's scene takes them straight from the doorstep into the lab, so the call can wait
-- while they leave Littleroot some other way (the Hub Pass works in the lab) and walk back in from
-- Route 101. From there the call must still show Mom at the player's own door and give the camera
-- back to the player in Littleroot.
--
-- The call used to pan the camera along a fixed path written for the lab's door: seven tiles up and
-- along to the door. From Route 101's entrance at the top of town those seven tiles crossed into
-- Route 101, which became the current map mid-scene; the camera object (spawned in Littleroot) was
-- no longer found, so the pan back never ran and the camera stayed on Route 101, seven rows above the
-- player, until the next warp.
--
-- For each gender: Littleroot is seeded as the intro leaves it, the Hall of Fame room's ON_FRAME runs
-- the ceremony with plain A presses, Continue and Birch's scene end in the lab with the call still
-- pending (house state 6), and a debug warp stands in for leaving through the Hub and coming back to
-- Route 101. The player walks down into Littleroot (Brendan at x 10, May at x 11, the entrance's two
-- columns). On every frame of the call the current map must stay Littleroot and the camera inside
-- it; Mom must appear once at the player's own door; afterwards the house state is 3, the player has
-- control and the camera is on the player, and still is one step later.
--
-- PW_HOME_ONLY=male|female runs one gender.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "MomCallFromRoute101")

local ONLY = os.getenv("PW_HOME_ONLY")
local HUB_GROUP = 100
local MALE, FEMALE = 0, 1
local CONTEXT_RUNNING = 0
local TOWN = { 0, 9 }
local LAB = { 1, 4 }
local HOF = { 16, 11 }
local ROUTE101 = { 0, 16 }
local LOCALID_TOWN_MOM = 4
local STATE_CALL_PENDING, STATE_DAD_WAITING = 6, 3

local VARS_START = 0x4000
local VAR_HOUSES_MAY, VAR_HOUSES_BRENDAN = 0x4082, 0x408C
local VAR_INTRO, VAR_TOWN_STATE, VAR_RIVAL_STATE = 0x4092, 0x4050, 0x408D
local VAR_ROUTE101_STATE = 0x4060
local VAR_DEX_UPGRADE = 0x40D3
local FLAG_RECEIVED_SS_TICKET = 0x123
local FLAG_HIDE_DAD = 0x2DE
local FLAG_RESCUED_BIRCH = 0x52
local FLAG_HIDE_VIGOROTH_1, FLAG_HIDE_VIGOROTH_2 = 0x2F2, 0x2F3
local FLAG_LATI_ROAMING = 0xFF
local ROW_PARTY_MENU, ROW_SET = 2, 9

local HOMES = {
  male = { gender = MALE, var = VAR_HOUSES_BRENDAN, door = { x = 5, y = 8 }, entry = 10,
    hide = { 0x2F7, 0x2FA, 0x310, 0x2DF, 0x331, 0x2F9 }, show = { 0x2F6 } },
  female = { gender = FEMALE, var = VAR_HOUSES_MAY, door = { x = 14, y = 8 }, entry = 11,
    hide = { 0x2F6, 0x2F9, 0x311, 0x2E0, 0x332, 0x2FA }, show = { 0x2F7 } },
}

local function varAddr(id) return F.sb1() + S.SaveBlock1.vars + (id - VARS_START) * 2 end
local function varGet(id) return F.r16(varAddr(id)) end
local function varSet(id, v) F.w16(varAddr(id), v) end
local function flagAddr(id) return F.sb1() + S.SaveBlock1.flags + (id // 8) end
local function flagSet(id) F.w8(flagAddr(id), F.r8(flagAddr(id)) | (1 << (id % 8))) end
local function flagClear(id) F.w8(flagAddr(id), F.r8(flagAddr(id)) & ~(1 << (id % 8)) & 0xFF) end

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function at(map) return F.grp() == map[1] and F.mapn() == map[2] end
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function running() return F.r8(S.sGlobalScriptContextStatus) == CONTEXT_RUNNING end
local function hasControl() return F.ow() and F.r8(S.sLockFieldControls) == 0 and not running() end

local function objectWith(localId)
  for i = 0, 15 do
    local a = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(a) & 1) == 1 and F.r8(a + S.ObjectEvent.localId) == localId then return a end
  end
end
local function coords(a) return F.rs16(a + S.ObjectEvent.x) - 7, F.rs16(a + S.ObjectEvent.y) - 7 end
-- The camera's map position is gSaveBlock1Ptr->pos; on the field it is the player's own tile.
local function cameraOnPlayer()
  local a = objectWith(0xFF)
  if not a then return false, "no player object" end
  local ox, oy = coords(a)
  local px, py = F.pos()
  return ox == px and oy == py, string.format("map %d/%d camera (%d,%d) player (%d,%d)", F.grp(), F.mapn(), px, py, ox, oy)
end
-- Route 101's own local id 4 (its Zigzagoon) stays loaded for a while after the step into town.
local function townMom()
  if not at(TOWN) then return nil end
  for i = 0, 15 do
    local a = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(a) & 1) == 1 and F.r8(a + S.ObjectEvent.localId) == LOCALID_TOWN_MOM and F.r8(a + 10) == TOWN[1]
        and F.r8(a + 9) == TOWN[2] and (F.r8(a + S.ObjectEvent.flags1) & 0x20) == 0 then
      return coords(a)
    end
  end
end

local function tapDown(n) for _ = 1, n do F.press("Down", 3); F.idle(16) end end
local function setParty()
  F.dbg(); F.idle(60)
  tapDown(ROW_PARTY_MENU); F.press("A", 3); F.idle(60)
  tapDown(ROW_SET); F.press("A", 3); F.idle(180)
  for _ = 1, 6 do F.press("B", 3); F.idle(20) end
end

local function warpToCoords(grp, map, x, y, tag)
  for _ = 1, 4 do
    F.dbg(); F.sel(0); F.sel(1); F.idle(20)
    F.spin(d(grp)); F.spin(d(map))
    F.press("A", 2)
    for _ = 1, 400 do
      F.w8(S.sWarpDestination + 2, 0xFF)
      F.w16(S.sWarpDestination + 4, x)
      F.w16(S.sWarpDestination + 6, y)
      F.idle(1)
      local px, py = F.pos()
      if F.ow() and F.grp() == grp and F.mapn() == map and px == x and py == y then F.idle(90); return true end
    end
    F.bOut(5)
  end
  F.shot(tag .. "_warpfail")
  return false
end
local function warp(g, m, w, tag)
  local gh, gt, go = d(g)
  local mh, mt, mo = d(m)
  local wh, wt, wo = d(w)
  return F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, g, m, tag)
end

local function isFrontEnd(c)
  return c == S.MainCB2_Intro or c == S.CB2_InitCopyrightScreenAfterBootup
    or c == S.MainCB2_WorldTitleScreen or c == S.CB2_InitMainMenu or c == S.CB2_MainMenu
    or c == S.CB2_InitTitleScreen
end

local function induct(tag)
  if not warp(HOF[1], HOF[2], 0, tag .. "_hof") then return false, "warp " .. where() end
  for f = 1, 60000 do
    if isFrontEnd(F.cb2()) then return true end
    if f % 600 == 0 and F.noteCrash(tag .. "_hof" .. f) then return false, "crash" end
    if f % 12 == 0 then F.press("A", 2) else F.idle(1) end
  end
  return false, string.format("cb2=%08X", F.cb2())
end

local function continueFromFrontEnd(tag)
  for _ = 1, 3000 do
    local c = F.cb2()
    if c == S.MainCB2_WorldTitleScreen or c == S.CB2_MainMenu then break end
    if c == S.MainCB2_Intro then F.press("Start", 2) end
    F.idle(1)
  end
  if F.cb2() == S.MainCB2_WorldTitleScreen then F.idle(120); F.press("Start", 2) end
  for _ = 1, 600 do if F.cb2() == S.CB2_MainMenu then break end F.idle(1) end
  F.idle(90)
  if F.cb2() ~= S.CB2_MainMenu then F.shot(tag .. "_no_menu"); return false end
  F.press("A", 2)
  for _ = 1, 3000 do if F.ow() then return true end F.idle(1) end
  return F.ow()
end

local function seed(h)
  F.w8(F.sb2() + S.SaveBlock2.playerGender, h.gender)
  varSet(VAR_INTRO, 7); varSet(VAR_TOWN_STATE, 4); varSet(VAR_RIVAL_STATE, 4); varSet(VAR_ROUTE101_STATE, 3)
  varSet(VAR_HOUSES_MAY, 0); varSet(VAR_HOUSES_BRENDAN, 0); varSet(h.var, 2)
  varSet(VAR_DEX_UPGRADE, 0)
  flagSet(FLAG_RESCUED_BIRCH); flagSet(FLAG_HIDE_DAD); flagSet(FLAG_HIDE_VIGOROTH_1); flagSet(FLAG_HIDE_VIGOROTH_2)
  flagClear(FLAG_RECEIVED_SS_TICKET); flagClear(FLAG_LATI_ROAMING)
  for _, id in ipairs(h.hide) do flagSet(id) end
  for _, id in ipairs(h.show) do flagClear(id) end
end

-- Every frame from the end of the step into town until 30 frames of steady control after the call.
local function watchCall(tag, h, frames)
  local r = { shows = 0, ctl = false, away = nil, minX = 99, minY = 99, maxX = -99, maxY = -99 }
  local was, calm, first, inTown = false, 0, nil, false
  for f = 1, frames do
    if not at(TOWN) and not r.away then r.away = string.format("frame %d on %s", f, where()) end
    local px, py = F.pos()
    inTown = inTown or cameraOnPlayer()
    if inTown then
      r.minX, r.minY = math.min(r.minX, px), math.min(r.minY, py)
      r.maxX, r.maxY = math.max(r.maxX, px), math.max(r.maxY, py)
    end
    local mx, my = townMom()
    if mx and not was then
      r.shows = r.shows + 1
      if not r.at then r.at = { mx, my }; first = f end
    end
    was = mx ~= nil
    if first and f > first and (f - first) % 120 == 1 and f - first < 600 then F.shot(string.format("%s_call_%d", tag, f - first)) end
    calm = (hasControl() and varGet(h.var) ~= STATE_CALL_PENDING) and calm + 1 or 0
    if calm >= 30 then r.ctl = true; break end
    if f % 600 == 0 and F.noteCrash(tag .. f) then break end
    if f % 90 == 0 and not hasControl() then F.press("B", 2) else F.idle(1) end
  end
  r.state = varGet(h.var)
  F.shot(tag .. "_after")
  F.L(string.format("  %s: Mom shown %d time(s)%s, camera x %d..%d y %d..%d, state %d, control %s at %s", tag, r.shows,
    r.at and string.format(" first at (%d,%d)", r.at[1], r.at[2]) or "", r.minX, r.maxX, r.minY, r.maxY, r.state,
    tostring(r.ctl), where()))
  return r
end

local function home(name, h)
  if ONLY and ONLY ~= name then return end
  F.L("== " .. name .. " ==")
  seed(h)
  local ok, why = induct(name)
  if not F.check(name .. ": the Hall of Fame ran to the soft reset", ok, why) then return end
  if not F.check(name .. ": Continue reaches the field", continueFromFrontEnd(name), string.format("cb2=%08X", F.cb2())) then return end
  local inLab = false
  for i = 1, 6000 do
    if at(LAB) and varGet(VAR_DEX_UPGRADE) >= 2 and hasControl() then inLab = true; break end
    if i % 30 == 0 then F.press("B", 2) else F.idle(1) end
  end
  if not F.check(name .. ": Birch's scene ends in the lab with Mom's call still pending",
    inLab and varGet(h.var) == STATE_CALL_PENDING, string.format("%s state %d", where(), varGet(h.var))) then return end

  if not F.check(name .. ": back on Route 101 above Littleroot", warpToCoords(ROUTE101[1], ROUTE101[2], h.entry, 17, name .. "_r101")) then return end
  F.idle(30)
  joypad.set({ Down = true })
  for _ = 1, 120 do emu.frameadvance(); if at(TOWN) then break end end
  joypad.set({})
  local ex, ey = F.pos()
  if not F.check(name .. ": walks into Littleroot from Route 101", at(TOWN), where()) then return end
  F.L(string.format("  %s: entered Littleroot at (%d,%d)", name, ex, ey))

  local r = watchCall(name, h, 4000)
  F.check(name .. ": the current map stays Littleroot through the call", r.away == nil, r.away)
  F.check(name .. ": the camera stays inside Littleroot", r.minX >= 0 and r.minY >= 0 and r.maxX <= 19 and r.maxY <= 19,
    string.format("x %d..%d y %d..%d", r.minX, r.maxX, r.minY, r.maxY))
  F.check(name .. ": Mom calls once from the player's own door", r.shows == 1 and r.at ~= nil and r.at[1] == h.door.x
    and (r.at[2] == h.door.y or r.at[2] == h.door.y + 1),
    string.format("shown %d at %s", r.shows, r.at and string.format("(%d,%d)", r.at[1], r.at[2]) or "-"))
  F.check(name .. ": the call leaves Norman waiting with control back", r.ctl and r.state == STATE_DAD_WAITING,
    string.format("control %s state %d", tostring(r.ctl), r.state))
  local on, how = cameraOnPlayer()
  F.check(name .. ": the camera is back on the player", on and at(TOWN), how)
  local sx, sy = F.pos()
  F.step("Down")
  F.idle(20)
  local on2, how2 = cameraOnPlayer()
  local nx, ny = F.pos()
  F.check(name .. ": one step later the camera still follows the player", on2 and at(TOWN) and ny == sy + 1 and nx == sx, how2)
  F.shot(name .. "_step")
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
