-- Johto field moves unlock at the badges Johto's own text names, as in pokemonHnS.
--
-- Falkner and Sage Li say the ZEPHYRBADGE (Violet) lets FLASH work outside battle, Bugsy and the
-- Ilex charcoal master say CUT needs the HIVEBADGE (Azalea), Whitney's gym guide says the PLAINBADGE
-- unlocks STRENGTH, and Chuck's wife says FLY needs the STORMBADGE (Cianwood). pokemonHnS gates the
-- same moves the same way and also lets ROCK SMASH work from the ZEPHYRBADGE (party_menu.c,
-- field_move_scripts.inc). The gates here used Hoenn's order for Johto: Cut at Zephyr, Flash at
-- Hive, Rock Smash at Plain, Strength at Fog and Fly at Mineral.
--
-- Mew (it can learn every HM) knows FLASH, ROCK SMASH, STRENGTH and FLY. Each case writes only the
-- badges a player would hold at that point and drives the move with real input:
--   1. Dark Cave, Zephyr only: FLASH from the party menu lights the cave. Cianwood City, Zephyr
--      only: A on a rock offers ROCK SMASH and breaks it (no Zephyr-era rock is reachable on foot,
--      so the rock is Cianwood's, outside the house door).
--   2. Violet City, Zephyr only: A on the Cut tree only describes it; with the Hive Badge too, the
--      tree is cut (Mew can learn CUT, QOL_FIELD_MOVES_NO_TEACH).
--   3. Union Cave B1F, Zephyr, Hive and Plain: A on a boulder offers STRENGTH and turns it on.
--   4. Violet City, the first five badges: FLY from the party menu opens the fly map.
-- Controls with no badge: FLASH refuses and the rock only gets described.
-- Oracle: FLAG_SYS_USE_FLASH, FLAG_SYS_USE_STRENGTH, the rock and tree objects, the fly map
-- callback, and the field message read from gStringVar4.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "JohtoBadgeFieldMoves")

local HUB_GROUP = 100
local REGION_JOHTO = 2
local CONTEXT_SHUTDOWN = 2
local PARTY_SIZE = 6
local MON = S.Pokemon.size

local FLAG_JOHTO_BASE = 0x6000
local function FLAG_JOHTO_BADGE(i) return FLAG_JOHTO_BASE + 0x3F8 + i end
local SYSTEM_FLAGS = 0x948
local FLAG_SYS_POKEMON_GET = SYSTEM_FLAGS + 0x0
local FLAG_SYS_USE_FLASH = SYSTEM_FLAGS + 0x28
local FLAG_SYS_USE_STRENGTH = SYSTEM_FLAGS + 0x29
local VAR_REPEL_STEP_COUNT = 0x4021
local VARS_START = 0x4000

local SPECIES_MEW = 151
local MOVE_FLASH, MOVE_ROCK_SMASH, MOVE_STRENGTH, MOVE_FLY = 148, 249, 70, 19
local ROW_FLASH, ROW_FLY = 1, 4          -- SUMMARY, then the known field moves in move-slot order

local DARK_CAVE = { g = 94, m = 16, w = 0 }     -- DarkCave_SouthSide, warp 0 from Route 31 (14,20)
local UNION_B1F = { g = 82, m = 3, w = 3 }      -- UnionCave_B1F, warp 3 from Ruins of Alph (3,13)
local VIOLET = { g = 75, m = 6, w = 6 }         -- VioletCity, warp 6 is the Trainer School door
local CIANWOOD = { g = 89, m = 0, w = 0 }       -- CianwoodCity, warp 0 is House 1's door (11,25)
local ROCK = { 10, 26 }                         -- west of the tile below that door
local TREE = { 43, 38 }
local BOULDER = { 11, 11 }

local OFF_CHECKSUM, OFF_SECURE = 28, 32
local SUB_STRIDE, NRAW = 12, 12
local SUB1 = { [0]=1,1,2,3,2,3,0,0,0,0,0,0,2,3,1,1,3,2,2,3,1,1,3,2 }

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end
local function flagAddr(n)
  if n >= FLAG_JOHTO_BASE then return F.sb3() + S.SaveBlock3.johtoFlags + (n - FLAG_JOHTO_BASE) // 8 end
  return F.sb1() + S.SaveBlock1.flags + n // 8
end
local function setFlag(n, on)
  local a, m = flagAddr(n), 1 << (n % 8)
  F.w8(a, on and (F.r8(a) | m) or (F.r8(a) & ~m & 0xFF))
end
local function getFlag(n) return (F.r8(flagAddr(n)) & (1 << (n % 8))) ~= 0 end
local function setVar(id, v) F.w16(F.sb1() + S.SaveBlock1.vars + (id - VARS_START) * 2, v) end
local function badges(n)
  for i = 0, 7 do setFlag(FLAG_JOHTO_BADGE(i), i < n) end
end
local function setJohto()
  F.w32(S.gCurrentRegion, REGION_JOHTO)
  F.w8(F.sb2() + S.SaveBlock2.currentRegion, REGION_JOHTO)
end

local function decode(addr, max)
  local out = {}
  for i = 0, (max or 200) - 1 do
    local c = F.r8(addr + i)
    if c == 0xFF then break end
    if c == 0x00 then out[#out + 1] = " "
    elseif c >= 0xBB and c <= 0xD4 then out[#out + 1] = string.char(65 + c - 0xBB)
    elseif c >= 0xD5 and c <= 0xEE then out[#out + 1] = string.char(97 + c - 0xD5)
    elseif c == 0xAB then out[#out + 1] = "!"
    elseif c == 0xAD then out[#out + 1] = "."
    elseif c == 0xB8 then out[#out + 1] = ","
    elseif c == 0xB4 then out[#out + 1] = "'"
    elseif c == 0xAC then out[#out + 1] = "?"
    elseif c == 0xFE or c == 0xFA or c == 0xFB then out[#out + 1] = " "
    else out[#out + 1] = "~" end
  end
  return table.concat(out)
end
local function clearText() F.w8(S.gStringVar4, 0xFF) end

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
local function writeMoves(mon, moves)
  xorSecure(mon)
  local sub = mon + OFF_SECURE + SUB1[F.r32(mon) % 24] * SUB_STRIDE
  for slot, mv in ipairs(moves) do
    local a = sub + (slot - 1) * 2
    F.w16(a, (F.r16(a) & 0xF800) | mv)
    F.w8(sub + 8 + slot - 1, 15)
  end
  F.w16(mon + OFF_CHECKSUM, checksumDecrypted(mon))
  xorSecure(mon)
end
local function readMoves(mon)
  xorSecure(mon)
  local sub = mon + OFF_SECURE + SUB1[F.r32(mon) % 24] * SUB_STRIDE
  local t = {}
  for slot = 0, 3 do t[#t + 1] = F.r16(sub + slot * 2) & 0x7FF end
  xorSecure(mon)
  return t
end

local function zeroParty()
  for off = 0, PARTY_SIZE * MON - 4, 4 do F.w32(S.gParties + off, 0) end
  F.w8(S.gPartiesCount, 0)
end
local function digits(n) n = n - 1; return n // 100, (n // 10) % 10, n % 10 end
local function giveMon(species, level)
  for _ = 1, 3 do
    zeroParty()
    F.dbg(); F.idle(30); F.bOut(4)
    F.dbg(); F.sel(3); F.sel(1); F.idle(20)
    F.spin(digits(species)); F.idle(20)
    F.spin(digits(level)); F.idle(60); F.bOut(4)
    if F.r8(S.gPartiesCount) == 1 then return true end
    F.idle(60)
  end
  return false
end

local function backToControl()
  for _ = 1, 80 do
    if hasControl() then return true end
    F.press("B", 2); F.idle(20)
  end
  return hasControl()
end

local function d3(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function go(dst, tag)
  local gh, gt, go_ = d3(dst.g)
  local mh, mt, mo = d3(dst.m)
  local wh, wt, wo = d3(dst.w)
  local ok = F.warpTo(gh, gt, go_, mh, mt, mo, wh, wt, wo, dst.g, dst.m, tag)
  F.idle(40)
  setJohto()
  instantText()
  setVar(VAR_REPEL_STEP_COUNT, 250)
  return ok
end

local function objectAt(x, y)
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.rs16(b + 0x10) == x + 7 and F.rs16(b + 0x12) == y + 7 then return true end
  end
  return false
end

-- Press A on the object in front, mash A through its messages (YES is the default), and keep
-- every distinct gStringVar4 text seen on the way.
local function interact(tag)
  clearText()
  local seen, last = {}, nil
  F.press("A", 2)
  for i = 1, 900 do
    local t = decode(S.gStringVar4)
    if t ~= last and t ~= "" then seen[#seen + 1] = t; last = t; F.L("  " .. tag .. ": " .. t) end
    if i > 30 and hasControl() then break end
    if i % 8 == 0 and F.reportCrash(tag) then break end
    joypad.set((i % 30 < 2) and { A = true } or {})
    emu.frameadvance()
  end
  joypad.set({})
  F.idle(20)
  F.shot(tag)
  backToControl()
  return table.concat(seen, " | ")
end

local USM_ICO_PARTY = 1
local function inPartyMenu()
  local c = F.cb2()
  return c == S.CB2_UpdatePartyMenu or c == S.CB2_InitPartyMenu or c == S.CB2_PartyMenuFromStartMenu
end
local function inFlyMap()
  local c = F.cb2()
  return c == S.CB2_FlyMap or c == S.CB2_OpenFlyMap
end
local function usmCursor()
  local st = F.r32(S.sUsmState)
  if st < 0x02000000 or st >= 0x02040000 then return -1, {} end
  local count = math.min(F.r8(st + 23), 12)
  local items = {}
  for i = 0, count - 1 do items[#items + 1] = F.r8(st + 11 + i) end
  return F.r8(st + 10) + F.r8(st + 5), items
end
local function openParty(tag)
  setFlag(FLAG_SYS_POKEMON_GET, true)
  for _ = 1, 4 do
    backToControl()
    F.press("Start", 2); F.idle(90)
    local cur, items = usmCursor()
    local want = -1
    for i = 1, #items do if items[i] == USM_ICO_PARTY then want = i - 1 end end
    if want >= 0 and cur >= 0 then
      local dir = (want > cur) and "Right" or "Left"
      for _ = 1, math.abs(want - cur) do F.press(dir, 2); F.idle(12) end
      F.press("A", 3)
      for _ = 1, 240 do
        F.idle(4)
        if inPartyMenu() then F.idle(40); return true end
      end
    end
    for _ = 1, 6 do F.press("B", 3); F.idle(20) end
  end
  F.shot(tag .. "_noparty")
  return false
end

-- A on the lead, Down onto `row`, A. Returns "flymap" if the fly map opened, else the frames
-- spent before the field came back.
local function useFieldMove(row, tag)
  if not openParty(tag) then return "noparty" end
  F.press("A", 3); F.idle(50)
  for _ = 1, row do F.press("Down", 2); F.idle(12) end
  F.shot(tag .. "_row")
  F.press("A", 3)
  for t = 1, 300 do
    F.idle(4)
    if inFlyMap() then F.idle(40); F.shot(tag .. "_flymap"); return "flymap" end
    if t == 30 then F.shot(tag .. "_after") end
    if t > 40 and t % 10 == 0 then F.press("B", 2) end
    if t > 40 and hasControl() then return "field" end
    if t % 20 == 0 and F.reportCrash(tag) then return "crash" end
  end
  return "stuck"
end

local function leaveFlyMap()
  for _ = 1, 40 do
    if not inFlyMap() and F.ow() then break end
    F.press("B", 2); F.idle(30)
  end
  backToControl()
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  instantText()
  F.check("Mew joins the party", giveMon(SPECIES_MEW, 50), "count " .. F.r8(S.gPartiesCount))
  writeMoves(S.gParties, { MOVE_FLASH, MOVE_ROCK_SMASH, MOVE_STRENGTH, MOVE_FLY })
  local mv = readMoves(S.gParties)
  F.check("Mew knows FLASH, ROCK SMASH, STRENGTH and FLY",
    mv[1] == MOVE_FLASH and mv[2] == MOVE_ROCK_SMASH and mv[3] == MOVE_STRENGTH and mv[4] == MOVE_FLY,
    table.concat(mv, ","))
  setFlag(FLAG_SYS_POKEMON_GET, true)

  -- 1. Dark Cave: no badge, then the Zephyr Badge.
  badges(0)
  F.check("warp into Dark Cave", go(DARK_CAVE, "darkcave"), where())
  F.check("Dark Cave is dark on arrival", not getFlag(FLAG_SYS_USE_FLASH), tostring(getFlag(FLAG_SYS_USE_FLASH)))
  local r = useFieldMove(ROW_FLASH, "flash_nobadge")
  F.check("FLASH refuses with no badge", r == "field" and not getFlag(FLAG_SYS_USE_FLASH),
    r .. " flash=" .. tostring(getFlag(FLAG_SYS_USE_FLASH)))

  badges(1)
  r = useFieldMove(ROW_FLASH, "flash_zephyr")
  F.check("FLASH lights Dark Cave with the Zephyr Badge (Falkner, Sage Li)",
    getFlag(FLAG_SYS_USE_FLASH), r .. " flash=" .. tostring(getFlag(FLAG_SYS_USE_FLASH)))
  backToControl()

  F.check("warp to Cianwood City", go(CIANWOOD, "cianwood"), where())
  badges(0)
  F.check("walk to the rock", F.route({ { ROCK[1] + 1, ROCK[2] } }, "rock"), where())
  F.face("Left")
  local rockThere = objectAt(ROCK[1], ROCK[2])
  F.check("the rock stands west of the player", rockThere, where())
  local said = interact("rock_nobadge")
  F.check("the rock is only described with no badge",
    said:find("rugged rock", 1, true) ~= nil and objectAt(ROCK[1], ROCK[2]), said)
  badges(1)
  F.face("Left")
  said = interact("rock_zephyr")
  F.check("ROCK SMASH is offered with the Zephyr Badge (pokemonHnS)",
    said:find("ROCK SMASH", 1, true) ~= nil, said)
  F.check("the rock is smashed with the Zephyr Badge", rockThere and not objectAt(ROCK[1], ROCK[2]), where())

  -- 2. Violet City's Cut tree: Zephyr only, then Hive.
  F.check("warp to Violet City", go(VIOLET, "violet"), where())
  badges(1)
  F.check("walk to the Cut tree", F.route({ { 39, 38 }, { TREE[1] - 1, TREE[2] } }, "tree"), where())
  F.face("Right")
  said = interact("tree_zephyr")
  F.check("the Cut tree is only described with the Zephyr Badge (Ilex charcoal master: AZALEA's badge)",
    said:find("Would you like", 1, true) == nil and objectAt(TREE[1], TREE[2]), said)
  badges(2)
  F.face("Right")
  said = interact("tree_hive")
  F.check("CUT is offered with the Hive Badge", said:find("Would you like to CUT", 1, true) ~= nil, said)
  F.check("the tree is cut with the Hive Badge", not objectAt(TREE[1], TREE[2]), where())

  -- 4. FLY from Violet City with the first five badges (Storm is the fifth).
  badges(5)
  r = useFieldMove(ROW_FLY, "fly_storm")
  F.check("FLY opens the fly map with the Storm Badge (Chuck's wife)", r == "flymap", r)
  leaveFlyMap()

  -- 3. Union Cave B1F boulder with Zephyr, Hive and Plain.
  F.check("warp into Union Cave B1F", go(UNION_B1F, "unioncave"), where())
  badges(3)
  setFlag(FLAG_SYS_USE_STRENGTH, false)
  F.check("walk to the boulder", F.route({ { 3, 11 }, { BOULDER[1] - 1, BOULDER[2] } }, "boulder"), where())
  F.face("Right")
  said = interact("boulder_plain")
  F.check("STRENGTH is offered with the Plain Badge (Whitney's gym guide)",
    said:find("Would you like to use STRENGTH", 1, true) ~= nil, said)
  F.check("STRENGTH is on after the boulder", getFlag(FLAG_SYS_USE_STRENGTH), tostring(getFlag(FLAG_SYS_USE_STRENGTH)))
  F.finish()
end)
