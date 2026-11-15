-- The Hub Pass in every self-contained session it must refuse, and in the neutral and mainland
-- facilities where it must work. Each context is entered the way its entry script leaves it (the
-- session flag or var, then a debug warp), and the Hub Pass itself is SELECT with real input.
-- Refused: Safari Zone, Bug-Catching Contest, a live Trainer Hill challenge, a Battle Pike room,
-- the Battle Pyramid, a live Frontier challenge, underwater. Allowed: a Battle Tent lobby, the
-- Trainer Hill lobby, the S.S. Tidal mid-cruise (the cruise must not outlive the warp) and the
-- Lilycove contest lobby. A refusal must keep the player in place with control, and only the
-- contest lobby, which is mainland Hoenn, may rewrite Hoenn's remembered team.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "HubPassContexts")

local HUB = {100, 0}
local HOENN_ATTENDANT, HOENN_STANDARD = 21, {9, 9}
local HOENN = 3
local FLAG_SYS_SAFARI_MODE, FLAG_SYS_BUG_CONTEST_MODE, FLAG_SYS_CRUISE_MODE = 0x974, 0x969, 0x975
local VAR_TRAINER_HILL_IS_ACTIVE, VAR_SS_TIDAL_STATE, VAR_SS_TIDAL_SCOTT_STATE = 0x40D6, 0x40B4, 0x40D4
local SS_TIDAL_BOARD_SLATEPORT, SS_TIDAL_DEPART_SLATEPORT = 1, 2
local hubPass

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function mapIs(m) return F.grp() == m[1] and F.mapn() == m[2] end
local function team(region) return F.sb3() + S.SaveBlock3.regionalTravel + 4 + (region - 1) * 52 end
local function teamCount(region) return F.r8(team(region) + 48) end
local function count() return F.r8(S.gPartiesCount) end
local function party(slot) return S.gParties + (slot or 0) * S.Pokemon.size end
local function bytes(base, size)
  local result = {}
  for i = 0, size - 1 do result[#result + 1] = string.char(F.r8(base + i)) end
  return table.concat(result)
end
local function putBytes(base, value)
  for i = 1, #value do F.w8(base + i - 1, value:byte(i)) end
end
local function zero(address, size) for i = 0, size - 1 do F.w8(address + i, 0) end end
local function flagAddr(id)
  if id >= 0x6000 and id < 0x6400 then
    local o = id - 0x6000
    return F.sb3() + S.SaveBlock3.johtoFlags + o // 8, 1 << (o % 8)
  end
  return F.sb1() + S.SaveBlock1.flags + id // 8, 1 << (id % 8)
end
local function flag(id, value)
  local a, bit = flagAddr(id)
  F.w8(a, value and (F.r8(a) | bit) or (F.r8(a) & (~bit & 255)))
end
local function flagSet(id) local a, bit = flagAddr(id); return F.r8(a) & bit ~= 0 end
local function varAddr(id) return F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2 end
local function setVar(id, value) F.w16(varAddr(id), value) end
local function getVar(id) return F.r16(varAddr(id)) end

local function order(p)
  local o = {}
  for i = 0, 3 do o[i] = F.r8(S.sSubstructOffsets + i * 24 + p % 24) * 3 end
  return o
end
local function decode(address)
  local key = F.r32(address) ~ F.r32(address + 4)
  local w = {}
  for i = 0, 11 do w[i] = F.r32(address + 32 + i * 4) ~ key end
  local o = order(F.r32(address))
  local sub = {}
  for i = 0, 3 do sub[i] = {w[o[i]], w[o[i] + 1], w[o[i] + 2]} end
  return sub
end
local function encode(address, sub)
  local key = F.r32(address) ~ F.r32(address + 4)
  local o = order(F.r32(address))
  local w = {}
  for i = 0, 3 do for k = 0, 2 do w[o[i] + k] = sub[i][k + 1] end end
  local checksum = 0
  for i = 0, 11 do
    checksum = (checksum + (w[i] & 65535) + (w[i] >> 16)) & 65535
    F.w32(address + 32 + i * 4, w[i] ~ key)
  end
  F.w16(address + 28, checksum)
end
-- A copy of the template with its own personality and no regional identity.
local function makeMon(dst, src, personality)
  putBytes(dst, src)
  local sub = decode(dst)
  F.w32(dst, personality)
  sub[0][1] = sub[0][1] & 0x03FFFFFF
  sub[0][2] = sub[0][2] & 0x1FFFFFFF
  sub[0][3] = sub[0][3] & 0x3FFFFFFF
  sub[1][2] = sub[1][2] & 0xC7FF07FF
  sub[3][3] = sub[3][3] & 0xEFFFFFFF
  encode(dst, sub)
end
local template
local function setParty(pids)
  for i = 0, 5 do zero(party(i), 100) end
  for i, p in ipairs(pids) do makeMon(party(i - 1), template, p) end
  F.w8(S.gPartiesCount, #pids)
end

local function scriptMenuActive()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    local fn = F.r32(a + S.Task.func) & 0xFFFFFFFE
    if F.r8(a + S.Task.isActive) ~= 0 and (fn == S.Task_HandleYesNoInput or fn == S.Task_HandleMultichoiceInput
      or fn == S.Task_CallYesOrNoCallback) then return true end
  end
  return false
end
local function hasControl() return F.ow() and not scriptMenuActive() and F.r8(S.sLockFieldControls) == 0 end
local function awaitControl(tag)
  local held = 0
  for _ = 1, 300 do
    if F.reportCrash(tag) then return false end
    if hasControl() then held = held + 1 else held = 0 end
    if held >= 10 then return true end
    F.press("B", 2); F.idle(8)
  end
  return false
end
local function drain()
  for _ = 1, 30 do
    F.press("B", 2); F.idle(16)
    if F.ensureFree() then return true end
  end
  return false
end
local function menu(want, tag)
  for _ = 1, 65 do
    if F.reportCrash(tag) then return false end
    if scriptMenuActive() then
      F.idle(12)
      for _ = 1, 10 do
        local c = F.mcur()
        if c == want then
          F.shot(tag)
          for _ = 1, 4 do
            F.press("A", 2)
            for _ = 1, 30 do
              if not scriptMenuActive() then F.idle(30); return true end
              F.idle(1)
            end
          end
          return false
        end
        F.press(c > want and "Up" or "Down", 2); F.idle(12)
      end
      return false
    end
    F.press("A", 2); F.idle(25)
  end
  return false
end
local function awaitMap(m, tag)
  for _ = 1, 220 do
    if mapIs(m) then F.idle(100); return true end
    if F.reportCrash(tag) then return false end
    F.press("A", 2); F.idle(14)
  end
  F.shot(tag .. "_failed")
  return false
end
local function debugWarp(m, warp, tag)
  local function digits(n) return n // 100, (n // 10) % 10, n % 10 end
  local gh, gt, go = digits(m[1])
  local mh, mt, mo = digits(m[2])
  return F.warpTo(gh, gt, go, mh, mt, mo, warp, 0, 0, m[1], m[2], tag)
end

-- SELECT with the Hub Pass registered. "hub" when the confirm appeared and YES warped, "refused"
-- when no confirm ever appeared. The refusal text is dismissed with B, never A, so nothing nearby
-- is talked to.
local function tryHubPass(tag)
  if not awaitControl(tag .. "_ready") then return "no control" end
  F.w16(F.sb1() + S.SaveBlock1.registeredItem, hubPass)
  F.press("Select", 2); F.idle(60)
  F.shot(tag)
  for _ = 1, 30 do
    if scriptMenuActive() then
      if not menu(0, tag .. "_yes") then return "confirm stuck" end
      return awaitMap(HUB, tag) and "hub" or "lost"
    end
    if hasControl() then return "refused" end
    F.press("B", 2); F.idle(24)
  end
  return awaitControl(tag .. "_dismiss") and "refused" or "no control"
end

local function setup()
  if not F.boot(HUB[1]) then return false end
  flag(0xDCF, true)
  flag(0x51, true)
  flag(0xA4B, true)
  flag(0x63F8, true)
  flag(0x94F, true)
  flag(0x95F, true)
  F.w8(F.sb2() + S.SaveBlock2.introDoneBits, 7)
  F.dbg(); F.idle(40); F.sel(2); F.idle(40)
  for _ = 1, 9 do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(180)
  drain()
  if count() ~= 1 then return false end
  template = bytes(party(), 100)
  local seen = {}
  for _, id in ipairs(select(2, F.keyItemSlot(0xFFFF))) do seen[id] = true end
  setParty({0xA0, 0xA1, 0xA2})
  if not F.route({{16, 4}, {HOENN_ATTENDANT, 4}, {HOENN_ATTENDANT, 3}}, "first_walk") then return false end
  F.face("Up"); F.press("A", 3); F.idle(60)
  if not (menu(1, "first_team") and menu(1, "first_arrival") and menu(0, "first_confirm")) then return false end
  if not awaitMap(HOENN_STANDARD, "first") then return false end
  for _, id in ipairs(select(2, F.keyItemSlot(0xFFFF))) do if not seen[id] then hubPass = id end end
  return hubPass ~= nil
end

local refused = {
  {name = "Safari Zone", map = {26, 3}, enter = function()
    flag(FLAG_SYS_SAFARI_MODE, true); F.w16(S.gSafariZoneStepCounter, 500)
  end, leave = function()
    flag(FLAG_SYS_SAFARI_MODE, false); F.w16(S.gSafariZoneStepCounter, 0)
  end},
  {name = "Bug-Catching Contest", map = {83, 5}, enter = function()
    flag(FLAG_SYS_BUG_CONTEST_MODE, true)
  end, leave = function() flag(FLAG_SYS_BUG_CONTEST_MODE, false) end},
  {name = "Trainer Hill challenge", map = {26, 61}, enter = function()
    setVar(VAR_TRAINER_HILL_IS_ACTIVE, 1)
  end, leave = function() setVar(VAR_TRAINER_HILL_IS_ACTIVE, 0) end},
  {name = "Battle Pike three-path room", map = {26, 36}},
  {name = "Battle Pyramid", map = {26, 27}},
  {name = "Frontier challenge in progress", map = {8, 2}, enter = function()
    F.w8(F.sb2() + S.SaveBlock2.frontierChallengeStatus, 1)
  end, leave = function() F.w8(F.sb2() + S.SaveBlock2.frontierChallengeStatus, 0) end},
  {name = "underwater", map = {0, 50}},
}

F.run(function()
  local ok = setup()
  F.check("setup reaches Hoenn with a Hub Pass", ok, where())
  if not ok then F.finish(); return end
  F.check("Hub Pass out of Hoenn", tryHubPass("depart") == "hub", where())
  local remembered = bytes(team(HOENN), 52)
  F.check("Hoenn remembers the team that left", teamCount(HOENN) == 3, "count=" .. teamCount(HOENN))
  setParty({0xB0, 0xB1})

  for _, c in ipairs(refused) do
    if not mapIs(HUB) then debugWarp(HUB, 0, c.name .. "_hub") end
    if c.enter then c.enter() end
    local arrived = debugWarp(c.map, 0, c.name)
    F.check(c.name .. ": reached", arrived, where())
    if arrived then
      local result = tryHubPass(c.name)
      F.check(c.name .. ": Hub Pass refused", result == "refused", "result=" .. result .. " at " .. where())
      F.check(c.name .. ": still there with control", mapIs(c.map) and hasControl(), where())
    end
    if c.leave then c.leave() end
  end
  F.check("refusals leave Hoenn's memory alone", bytes(team(HOENN), 52) == remembered, "count=" .. teamCount(HOENN))

  local function allowed(name, map, warp, prime, after)
    if not mapIs(HUB) then debugWarp(HUB, 0, name .. "_hub") end
    local arrived = debugWarp(map, warp, name)
    F.check(name .. ": reached", arrived, where())
    if not arrived then return end
    if prime then prime() end
    F.check(name .. ": Hub Pass works", tryHubPass(name) == "hub", where())
    if after then after() end
  end
  allowed("Battle Tent lobby", {9, 2}, 0)
  allowed("Trainer Hill lobby", {26, 60}, 0)
  setVar(VAR_SS_TIDAL_SCOTT_STATE, 1)
  setVar(VAR_SS_TIDAL_STATE, SS_TIDAL_BOARD_SLATEPORT)
  allowed("S.S. Tidal mid-cruise", {25, 41}, 0, function()
    awaitControl("tidal_depart")
    F.check("S.S. Tidal: the corridor's own script started the cruise",
      flagSet(FLAG_SYS_CRUISE_MODE) and getVar(VAR_SS_TIDAL_STATE) == SS_TIDAL_DEPART_SLATEPORT,
      string.format("cruise=%s state=%d", tostring(flagSet(FLAG_SYS_CRUISE_MODE)), getVar(VAR_SS_TIDAL_STATE)))
  end, function()
    F.check("S.S. Tidal: the cruise does not outlive the warp",
      not flagSet(FLAG_SYS_CRUISE_MODE) and getVar(VAR_SS_TIDAL_STATE) == 0,
      string.format("cruise=%s state=%d", tostring(flagSet(FLAG_SYS_CRUISE_MODE)), getVar(VAR_SS_TIDAL_STATE)))
  end)
  F.check("neutral facilities leave Hoenn's memory alone", bytes(team(HOENN), 52) == remembered,
    "count=" .. teamCount(HOENN))

  allowed("Lilycove contest lobby", {13, 4}, 0)
  F.check("the contest lobby is mainland Hoenn and records the carried team",
    teamCount(HOENN) == 2 and bytes(team(HOENN), 52) ~= remembered, "count=" .. teamCount(HOENN))
  F.finish()
end)
