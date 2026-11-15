-- Artisan Cave belongs to the Battle Frontier island: both entrances open off the Frontier and no
-- route reaches it from mainland Hoenn. A Hub Pass used inside it must not count as leaving Hoenn,
-- so it must leave Hoenn's remembered team alone, as the Frontier outdoors already does.
-- A Hoenn team leaves through the Hub Pass and another team goes on to the Frontier through the hub
-- attendant. The suite debug-warps onto the tile below the cave's Frontier entrance (the beach in
-- front of it is reached by Surf), walks in, and uses the Hub Pass from the cave. Then the Hoenn
-- gate's recall must bring the remembered team back. Every Pokemon carries a distinct personality,
-- and the party and all PC boxes are counted before and after.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "ArtisanCaveDeparture")

local HUB = {100, 0}
local SLOTS = 14 * 30
local HOENN = 3
local HOENN_ATTENDANT, HOENN_STANDARD = 21, {9, 9}
local RECEPTION = {26, 50}
local FRONTIER_WEST = {26, 4}
local ARTISAN_B1F = {24, 99}
local FLAG_HOENN_CHAMPION = 0xA4A
local hubPass

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function mapIs(g, m) return F.grp() == g and F.mapn() == m end
local function team(region) return F.sb3() + S.SaveBlock3.regionalTravel + 4 + (region - 1) * 52 end
local function teamCount(region) return F.r8(team(region) + 48) end
local function count() return F.r8(S.gPartiesCount) end
local function party(slot) return S.gParties + (slot or 0) * S.Pokemon.size end
local function box(slot) return F.r32(S.gPokemonStoragePtr) + 4 + slot * 80 end
local function present(address) return (F.r8(address + 19) & 2) ~= 0 end
local function pid(address) return F.r32(address) end
local function bytes(base, size)
  local result = {}
  for i = 0, size - 1 do result[#result + 1] = string.char(F.r8(base + i)) end
  return table.concat(result)
end
local function putBytes(base, value)
  for i = 1, #value do F.w8(base + i - 1, value:byte(i)) end
end
local function zero(address, size) for i = 0, size - 1 do F.w8(address + i, 0) end end
local function flag(id, value)
  local a = F.sb1() + S.SaveBlock1.flags + id // 8
  local bit = 1 << (id % 8)
  if id >= 0x6000 and id < 0x6400 then
    a = F.sb3() + S.SaveBlock3.johtoFlags + (id - 0x6000) // 8
    bit = 1 << ((id - 0x6000) % 8)
  end
  F.w8(a, value and (F.r8(a) | bit) or (F.r8(a) & (~bit & 255)))
end

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
local function partyPids()
  local r = {}
  for i = 0, count() - 1 do r[#r + 1] = pid(party(i)) end
  return r
end
local function setParty(pids)
  for i = 0, 5 do zero(party(i), 100) end
  for i, p in ipairs(pids) do makeMon(party(i - 1), template, p) end
  F.w8(S.gPartiesCount, #pids)
end
local function seq(base, n) local r = {} for i = 0, n - 1 do r[#r + 1] = base + i end return r end
local function hex(list) local s = {} for _, p in ipairs(list) do s[#s + 1] = string.format("%X", p) end return table.concat(s, ",") end
local function census()
  local seen, dupes, n = {}, {}, 0
  local function add(address, tag)
    if not present(address) then return end
    local p = pid(address)
    n = n + 1
    if seen[p] then dupes[#dupes + 1] = string.format("%08X@%s", p, tag) end
    seen[p] = tag
  end
  for i = 0, 5 do add(party(i), "party" .. i) end
  for i = 0, SLOTS - 1 do add(box(i), "box" .. i) end
  return {seen = seen, dupes = dupes, n = n}
end
local function checkCensus(tag, before)
  local after = census()
  local ok, detail = #after.dupes == 0, string.format("%d mons", after.n)
  if not ok then detail = "cloned " .. table.concat(after.dupes, ",") end
  for p, w in pairs(before.seen) do
    if ok and not after.seen[p] then ok, detail = false, string.format("lost %08X (was %s)", p, w) end
  end
  for p, w in pairs(after.seen) do
    if ok and not before.seen[p] then ok, detail = false, string.format("new %08X at %s", p, w) end
  end
  F.check(tag, ok, detail)
end
local function partyIs(pids, tag)
  local got = partyPids()
  local ok = #got == #pids
  for i = 1, #pids do ok = ok and got[i] == pids[i] end
  F.check(tag, ok, "party=" .. hex(got))
end

local function drain()
  for _ = 1, 30 do
    F.press("B", 2); F.idle(16)
    if F.ensureFree() then return true end
  end
  return false
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
  F.shot(tag .. "_nomenu")
  return false
end
local function awaitMap(g, m, tag)
  for _ = 1, 220 do
    if mapIs(g, m) then F.idle(100); return true end
    if F.reportCrash(tag) then return false end
    F.press("A", 2); F.idle(14)
  end
  F.shot(tag .. "_failed")
  return false
end
local function debugParty()
  F.dbg(); F.idle(40); F.sel(2); F.idle(40)
  for _ = 1, 9 do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(180)
  drain()
  return count() == 1
end
-- The warp field of the debug menu only counts Up presses, so spin(n, 0, 0) selects warp n.
local function debugWarp(g, m, warp, tag)
  local function digits(n) return n // 100, (n // 10) % 10, n % 10 end
  local gh, gt, go = digits(g)
  local mh, mt, mo = digits(m)
  return F.warpTo(gh, gt, go, mh, mt, mo, warp, 0, 0, g, m, tag)
end
local function crossHoenn(teamChoice, tag)
  local x0, y0 = F.pos()
  local path = y0 >= 5 and {{x0, 6}, {16, 6}, {16, 4}} or {{16, 4}}
  path[#path + 1] = {HOENN_ATTENDANT, 4}; path[#path + 1] = {HOENN_ATTENDANT, 3}
  if not F.route(path, tag .. "_walk") then return false end
  F.face("Up"); F.press("A", 3); F.idle(60)
  if not menu(teamChoice, tag .. "_team") then return false end
  if not menu(1, tag .. "_arrival") then return false end
  if not menu(0, tag .. "_confirm") then return false end
  return awaitMap(HOENN_STANDARD[1], HOENN_STANDARD[2], tag)
end
local function passToHub(tag)
  for attempt = 1, 3 do
    drain()
    F.w16(F.sb1() + S.SaveBlock1.registeredItem, hubPass)
    F.press("Select", 2); F.idle(90)
    if menu(0, tag .. "_confirm" .. attempt) then return awaitMap(HUB[1], HUB[2], tag) end
  end
  return false
end
local function toFrontier(tag)
  drain()
  local x0, y0 = F.pos()
  local path = y0 >= 5 and {{x0, 6}, {16, 6}, {16, 4}} or {{16, 4}}
  path[#path + 1] = {4, 4}; path[#path + 1] = {4, 3}
  if not F.route(path, tag .. "_walk") then return false end
  F.face("Up"); F.press("A", 3); F.idle(60)
  return menu(0, tag .. "_yes") and awaitMap(RECEPTION[1], RECEPTION[2], tag)
end

local function setup()
  if not F.boot(HUB[1]) then return false end
  flag(0xDCF, true)
  flag(0x51, true)
  flag(0xA4B, true)
  flag(0x63F8, true)
  flag(0x94F, true)
  flag(0x95F, true) -- visited Slateport, so the standard Hoenn arrival is its harbor
  flag(FLAG_HOENN_CHAMPION, true) -- opens the hub's Battle Frontier attendant
  F.w8(F.sb2() + S.SaveBlock2.introDoneBits, 7)
  if not debugParty() then return false end
  template = bytes(party(), 100)
  local seen = {}
  for _, id in ipairs(select(2, F.keyItemSlot(0xFFFF))) do seen[id] = true end
  setParty(seq(0xA0, 6))
  if not crossHoenn(1, "first_keep") then return false end
  for _, id in ipairs(select(2, F.keyItemSlot(0xFFFF))) do if not seen[id] then hubPass = id end end
  return hubPass ~= nil
end

F.run(function()
  local ok = setup()
  F.check("setup reaches Hoenn with six distinct Pokemon and a Hub Pass", ok, where())
  if not ok then F.finish(); return end
  local A, B = seq(0xA0, 6), seq(0xB0, 3)

  F.check("Hub Pass out of Hoenn with team A", passToHub("depart_A"), where())
  F.check("Hoenn remembers six", teamCount(HOENN) == 6, "count=" .. teamCount(HOENN))
  local remembered = bytes(team(HOENN), 52)

  -- Hub PC edit: A into the PC, B carried to the Frontier.
  for i = 0, 5 do putBytes(box(i), bytes(party(i), 80)) end
  setParty(B)
  local before = census()

  -- Control: the Frontier outdoors is neutral, so a Hub Pass there keeps Hoenn's memory.
  F.check("hub attendant boards for the Frontier", toFrontier("frontier1"), where())
  F.check("Frontier west reached", debugWarp(FRONTIER_WEST[1], FRONTIER_WEST[2], 10, "frontier_west"), where())
  F.check("Hub Pass from the Frontier outdoors", passToHub("frontier_pass"), where())
  F.check("Frontier outdoors leaves Hoenn's memory alone", bytes(team(HOENN), 52) == remembered,
    "count=" .. teamCount(HOENN))

  F.check("hub attendant boards for the Frontier again", toFrontier("frontier2"), where())
  F.check("Artisan Cave entrance reached", debugWarp(FRONTIER_WEST[1], FRONTIER_WEST[2], 10, "artisan_door"), where())
  F.shot("artisan_door")
  F.step("Up"); F.press("Up", 20); F.idle(150)
  F.check("walked into Artisan Cave", mapIs(ARTISAN_B1F[1], ARTISAN_B1F[2]), where())
  F.shot("artisan_cave")
  F.check("Hub Pass from Artisan Cave", passToHub("cave_pass"), where())
  F.check("Artisan Cave leaves Hoenn's memory alone", bytes(team(HOENN), 52) == remembered,
    "count=" .. teamCount(HOENN))
  checkCensus("Frontier trips keep every Pokemon once", before)

  F.check("recall of the Hoenn team through the gate", crossHoenn(0, "recall_A"), where())
  partyIs(A, "recall brings back the team that left Hoenn")
  checkCensus("recall keeps every Pokemon once", before)
  F.finish()
end)
