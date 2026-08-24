-- Issue #167: Grass/Bug followers comment on the outdoors.
-- COND_MSG_OUTDOORS in src/follower_helper.c is MATCH_OUTDOORS + MATCH_TYPES(GRASS, BUG)
-- with sOutdoorsTexts { sniffing, breeze, deep breath }. Selection is a 50% roll
-- then a reservoir over every matching conditional, so we talk repeatedly.
--
-- Run via Testing/mgba-run.sh Testing/lua/FollowerOutdoors.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "FollowerOutdoors")

local HUB_GROUP = 100
local GRP_TOWN, MAP_TOWN, WARP_TOWN = 75, 0, 1  -- New Bark, player's house door
local GRP_R29, MAP_R29, WARP_R29 = 75, 2, 0     -- Route 29, MAP_TYPE_ROUTE
local FOLLOWER = 0xFE
local SPECIES_MASK = 0x8FFF
local SPECIES_ODDISH = 43
local OFF_HP, OFF_MAXHP = S.Pokemon.hp, S.Pokemon.maxHP
local OFF_CHECKSUM, OFF_SECURE = 28, 32
local SUB_STRIDE, NRAW = 12, 12
local SUB0 = { [0]=0,0,0,0,0,0,1,1,2,3,2,3,1,1,2,3,2,3,1,1,2,3,2,3 }

local MSG_SNIFF  = S.sCondMsg51
local MSG_BREEZE = S.sCondMsg52
local MSG_BREATH = S.sCondMsg53
local MSG_HAPPY  = S.sCondMsg43  -- day-pool "happy to see what's outdoors", not this claim
local CTX_STATUS = S.sGlobalScriptContextStatus
local CTX_SCRIPT, CTX_DATA0 = S.ScriptCtx.scriptPtr, 100
local CONTEXT_SHUTDOWN = 2
local TALKS = 80
local ROW_GIVE, ROW_MON_BASIC = 3, 1

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

-- Give X… / Pokémon (Basic): species spinner starts at 1, digit 0 = ones.
-- Oddish is 43. Right to tens, +4 tens = 41, Left, +2 ones = 43. Then level 10.
local function giveOddish()
  F.dbg(); F.idle(60)
  tapDown(ROW_GIVE); F.press("A", 3); F.idle(50)
  tapDown(ROW_MON_BASIC); F.press("A", 3); F.idle(40)
  F.press("Right", 2); F.idle(10)
  for _ = 1, 4 do F.press("Up", 2); F.idle(8) end
  F.press("Left", 2); F.idle(10)
  for _ = 1, 2 do F.press("Up", 2); F.idle(8) end
  F.shot("give_species")
  F.press("A", 3); F.idle(30)
  for _ = 1, 9 do F.press("Up", 2); F.idle(8) end  -- level 10
  F.press("A", 3); F.idle(60)
  for _ = 1, 8 do F.press("B", 3); F.idle(20) end
end

local function xorSecure(mon)
  local key = F.r32(mon) ~ F.r32(mon + 4)
  for i = 0, NRAW - 1 do
    local a = mon + OFF_SECURE + i * 4
    F.w32(a, F.r32(a) ~ key)
  end
end

local function checksumDecrypted(mon)
  local sum = 0
  for i = 0, NRAW - 1 do
    local w = F.r32(mon + OFF_SECURE + i * 4)
    sum = (sum + w + (w >> 16)) & 0xFFFFFFFF
  end
  return sum & 0xFFFF
end

local function readSpecies(mon)
  xorSecure(mon)
  local pid = F.r32(mon)
  local sub = mon + OFF_SECURE + SUB0[pid % 24] * SUB_STRIDE
  local sp = F.r16(sub) & 0x7FF
  xorSecure(mon)
  return sp
end

local function writeSpecies(mon, species)
  xorSecure(mon)
  local pid = F.r32(mon)
  local sub = mon + OFF_SECURE + SUB0[pid % 24] * SUB_STRIDE
  local w = F.r16(sub)
  F.w16(sub, (w & 0xF800) | (species & 0x7FF))
  F.w16(mon + OFF_CHECKSUM, checksumDecrypted(mon))
  xorSecure(mon)
end

local function obj(localId)
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == localId then
      return {
        i = i, b = b,
        x = F.rs16(b + S.ObjectEvent.x) - 7,
        y = F.rs16(b + S.ObjectEvent.y) - 7,
        gfx = F.r16(b + S.ObjectEvent.graphicsId),
        invisible = (F.r8(b + S.ObjectEvent.flags1) & 0x20) ~= 0,
      }
    end
  end
  return nil
end

local function decode(addr, n)
  n = n or 96
  local t = {}
  local i = 0
  while i < n do
    local b = F.r8(addr + i)
    if b == 0xFF then break end
    if b == 0xFE then t[#t + 1] = "/"
    elseif b == 0xFD then
      t[#t + 1] = "{VAR}"
      i = i + 1
    elseif b == 0xFC then
      i = i + 1
    elseif b == 0xFA or b == 0xFB then
      -- prompt
    elseif b >= 0xBB and b <= 0xD4 then t[#t + 1] = string.char(65 + (b - 0xBB))
    elseif b >= 0xD5 and b <= 0xEE then t[#t + 1] = string.char(97 + (b - 0xD5))
    elseif b >= 0xA1 and b <= 0xAA then t[#t + 1] = string.char(48 + (b - 0xA1))
    elseif b == 0x00 then t[#t + 1] = " "
    elseif b == 0xAD then t[#t + 1] = "."
    elseif b == 0xAB then t[#t + 1] = "!"
    elseif b == 0xAC then t[#t + 1] = "?"
    elseif b == 0xB4 then t[#t + 1] = "'"
    elseif b == 0xB8 then t[#t + 1] = ","
    elseif b == 0xB0 then t[#t + 1] = "..."
    else t[#t + 1] = string.format("[%02X]", b) end
    i = i + 1
  end
  return table.concat(t)
end

local function msgName(p)
  if p == MSG_SNIFF then return "SNIFF" end
  if p == MSG_BREEZE then return "BREEZE" end
  if p == MSG_BREATH then return "BREATH" end
  if p == MSG_HAPPY then return "DAY_OUTDOORS" end
  return string.format("other=0x%08X", p)
end

local function isOutdoorsLine(p)
  return p == MSG_SNIFF or p == MSG_BREEZE or p == MSG_BREATH
end

local function faceFollower()
  local px, py = F.pos()
  local o = obj(FOLLOWER)
  if not o or o.invisible then return false end
  local dir
  if o.x > px then dir = "Right" elseif o.x < px then dir = "Left"
  elseif o.y > py then dir = "Down" else dir = "Up" end
  F.face(dir)
  return true
end

local function dismissTalk()
  for _ = 1, 40 do
    F.press("A", 2); F.idle(8)
    F.press("B", 2); F.idle(10)
    if F.r8(CTX_STATUS) == CONTEXT_SHUTDOWN then
      F.idle(20)
      return true
    end
  end
  return F.r8(CTX_STATUS) == CONTEXT_SHUTDOWN
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  F.idle(40)

  giveOddish()
  local n = F.r8(S.gPartiesCount)
  local mon = S.gParties
  local sp0 = readSpecies(mon)
  F.L(string.format("  after Give: count=%d species=%d hp=%d/%d nick='%s'",
    n, sp0, F.r16(mon + OFF_HP), F.r16(mon + OFF_MAXHP), decode(mon + 8, 10)))
  F.check("Give Oddish published a party", n ~= 0, "count=" .. n)
  F.check("slot 0 is Oddish (Grass/Poison)", sp0 == SPECIES_ODDISH, "species=" .. sp0)
  if sp0 ~= SPECIES_ODDISH then
    writeSpecies(mon, SPECIES_ODDISH)
    F.w16(mon + OFF_HP, F.r16(mon + OFF_MAXHP))
    F.L("  fallback writeSpecies -> " .. readSpecies(mon))
  end

  F.L("  authored outdoors lines:")
  F.L("    SNIFF  " .. decode(MSG_SNIFF))
  F.L("    BREEZE " .. decode(MSG_BREEZE))
  F.L("    BREATH " .. decode(MSG_BREATH))

  -- New Bark is MAP_TYPE_TOWN (outdoors) but the house door talks to Mom. Route 29
  -- is MAP_TYPE_ROUTE; warp 0 is the west gate, one step south is pavement.
  if not go(GRP_R29, MAP_R29, WARP_R29, "route29") then
    if not go(GRP_TOWN, MAP_TOWN, WARP_TOWN, "newbark") then F.finish(); return end
  end
  F.shot("arrival")
  F.L(string.format("  mapType=%d (TOWN=1 ROUTE=3) grp=%d map=%d",
    F.r8(S.gMapHeader + 24), F.grp(), F.mapn()))
  -- Warp respawns the follower invisible. A warp-exit step can be copy-locked so
  -- the ball-emerge is skipped; keep stepping, then force the invisible bit.
  local o
  for _, dir in ipairs({ "Down", "Left", "Right", "Up", "Down" }) do
    F.step(dir); F.idle(24)
    o = obj(FOLLOWER)
    if o and not o.invisible then break end
  end
  o = obj(FOLLOWER)
  if o and o.invisible then
    F.w8(o.b + S.ObjectEvent.flags1, F.r8(o.b + S.ObjectEvent.flags1) & ~0x20)
    F.step("Left"); F.idle(24)
    o = obj(FOLLOWER)
    F.L("  forced follower visible bit; now " .. ((o and not o.invisible) and "visible" or "still hidden"))
  end
  o = obj(FOLLOWER)
  F.L(string.format("  follower after emerge: %s", o and string.format("(%d,%d) gfx=0x%04X inv=%s", o.x, o.y, o.gfx, tostring(o.invisible)) or "ABSENT"))
  F.check("Oddish follower is visible outdoors",
    o ~= nil and not o.invisible and (o.gfx & SPECIES_MASK) == SPECIES_ODDISH,
    o and string.format("gfx=0x%04X inv=%s", o.gfx, tostring(o.invisible)) or "ABSENT")
  F.shot("follower_out")

  local hit, lines = nil, {}
  for n = 1, TALKS do
    if F.reportCrash("talk" .. n) then break end
    if not F.ow() then
      for _ = 1, 200 do
        F.press("B", 2); F.idle(4); F.press("Right", 2); F.idle(4); F.press("A", 2); F.idle(8)
        if F.ow() then break end
      end
    end
    if not faceFollower() then
      F.step("Left"); F.idle(20)
      if not faceFollower() then F.L("  talk " .. n .. ": no visible follower"); break end
    end
    F.press("A", 3)
    local got = false
    for _ = 1, 90 do
      F.idle(1)
      if F.r8(CTX_STATUS) ~= CONTEXT_SHUTDOWN then got = true; break end
    end
    local p = F.r32(S.sGlobalScriptContext + CTX_DATA0)
    local sptr = F.r32(S.sGlobalScriptContext + CTX_SCRIPT)
    local buf = decode(S.gStringVar4, 120)
    local rom = (p >= 0x08000000 and p < 0x0A000000) and decode(p) or "?"
    lines[#lines + 1] = string.format("n=%d ptr=%s script=0x%08X rom='%s' buf='%s'",
      n, msgName(p), sptr, rom, buf)
    if n <= 5 or isOutdoorsLine(p) then F.L("  talk " .. lines[#lines]) end
    local blob = (rom .. " " .. buf):lower()
    local looksOut = isOutdoorsLine(p)
      or blob:find("sniffing", 1, true) or blob:find("open air", 1, true)
      or blob:find("breeze", 1, true) or blob:find("fresh air", 1, true)
    if looksOut and not hit then
      hit = { n = n, p = p, rom = rom, buf = buf }
      F.shot("outdoors_line")
    end
    dismissTalk()
    if hit then break end
  end

  if not hit then
    F.L("  all talks:")
    for _, s in ipairs(lines) do F.L("    " .. s) end
    F.shot("no_outdoors_line")
  end

  F.check("an outdoors-conditional Grass/Bug line was spoken",
    hit ~= nil,
    hit and string.format("talk %d %s rom='%s' buf='%s'", hit.n, msgName(hit.p), hit.rom, hit.buf)
        or ("no match in " .. #lines .. " talks"))

  F.finish()
end)
