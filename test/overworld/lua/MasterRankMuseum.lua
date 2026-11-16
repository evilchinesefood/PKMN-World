-- A Master Rank win in each of the five contest categories through the real contest flow, the
-- ribbon, the contest artist's painting taken to the Lilycove Museum, and the museum after all five.
--
-- Setup gives a Milotic, maxes its five conditions and sheen and gives it the Hyper Rank ribbon of
-- every category (substructs re-encrypted with a fresh checksum; the ribbon is what the receptionist
-- checks for Master Rank), and leaves FLAG_HIDE_LILYCOVE_MUSEUM_CURATOR set and the museum 2F state 1
-- the way following the 1F curator upstairs does. Then for each category, with real input: talk to
-- the receptionist, Enter, Master Rank, the category, pick Milotic, play the contest choosing a
-- different move each turn, accept the artist's offer. A category is retried (up to 10 times) until
-- the win scores the 800 points the artist needs; each win must leave the Master ribbon and the
-- category's painting flag. Then the museum 2F must hang five different paintings and the curator
-- must give the Glass Ornament.
--
-- Manual: about 160 seconds and up to 1.5M frames. Run via
--   test/overworld/mgba-run.sh test/overworld/lua/MasterRankMuseum.lua <rom> --timeout 1200 --env PW_MAX_FRAMES=1500000
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "MasterRankMuseum")
local MON = S.Pokemon.size
local ONLY = os.getenv("PW_CAT")
local FLAG_CURATOR = 0x307
local VAR_MUSEUM_2F = 0x94
local PAINTING_FLAG = { [0] = 0xA0, 0xA1, 0xA2, 0xA3, 0xA4 }
local FLAG_GLASS = 0xEC
local DECOR_GLASS_ORNAMENT = 44
local CATS = { [0] = "cool", "beauty", "cute", "smart", "tough" }

local function sdigits(n) n = n - 1; return n // 100, (n // 10) % 10, n % 10 end
local function setFlag(fl) local a = F.sb1() + S.SaveBlock1.flags + (fl >> 3); F.w8(a, F.r8(a) | (1 << (fl & 7))) end
local function flag(fl) return (F.r8(F.sb1() + S.SaveBlock1.flags + (fl >> 3)) >> (fl & 7)) & 1 end
local function scriptDone() return F.ow() and F.r8(S.sGlobalScriptContextStatus) == 2 end
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end

local function order(p) local o = {}; for i = 0, 3 do o[i] = F.r8(S.sSubstructOffsets + i * 24 + p % 24) * 3 end; return o end
local function decode(a)
  local key = F.r32(a) ~ F.r32(a + 4); local w = {}
  for i = 0, 11 do w[i] = F.r32(a + 32 + i * 4) ~ key end
  return w, order(F.r32(a))
end
local function encode(a, w)
  local key = F.r32(a) ~ F.r32(a + 4); local sum = 0
  for i = 0, 11 do local v = w[i] & 0xFFFFFFFF; sum = sum + (v & 0xFFFF) + (v >> 16); F.w32(a + 32 + i * 4, v ~ key) end
  F.w16(a + 28, sum & 0xFFFF)
end
local function ribbons(a) local w, o = decode(a); return w[o[3] + 2] & 0x7FFF, (w[o[3] + 2] >> 18) & 1 end

local function liveTask(fn)
  for i = 0, S.Task.count - 1 do
    local t = S.gTasks + i * S.Task.stride
    if F.r8(t + S.Task.isActive) ~= 0 and (F.r32(t + S.Task.func) & ~1) == (fn & ~1) then return true end
  end
  return false
end

local function choose(want)
  for _ = 1, 8 do
    local c = F.mcur()
    if c == want then F.press("A", 2); F.idle(30); return true end
    F.press(c > want and "Up" or "Down", 2); F.idle(12)
  end
  return false
end

local function contest(cat)
  local tag = CATS[cat]
  F.check(tag .. ": warp to the lobby", F.warpTo(0, 1, 3, 0, 0, 4, 0, 0, 0, 13, 4, tag))
  F.route({ { 14, 5 }, { 14, 3 } }, tag); F.face("Up")
  F.press("A", 2); F.idle(30)
  local wants = { 0, 3, cat }
  local mc, sawContest, sawPainting, sawYesNo, lastShot, turns = 0, false, false, 0, 0, 0
  for f = 1, 60000 do
    if F.reportCrash(tag .. f) then break end
    local cb = F.cb2()
    if cb == (S.CB2_ContestMain & ~1) then sawContest = true end
    if cb == (S.CB2_ContestPainting & ~1) then sawPainting = true end
    if liveTask(S.Task_HandleMoveSelectInput) then
      turns = turns + 1
      F.idle(10)
      for _ = 1, (turns - 1) % 4 do F.press("Down", 2); F.idle(8) end
      F.shot(tag .. "_move" .. turns)
      F.press("A", 2); F.idle(60)
    elseif liveTask(S.Task_HandleMultichoiceInput) then
      F.idle(15); mc = mc + 1
      F.shot(tag .. "_mc" .. mc)
      choose(wants[mc] or 0)
    elseif liveTask(S.Task_HandleYesNoInput) then
      sawYesNo = sawYesNo + 1; F.idle(15); F.shot(tag .. "_yesno" .. sawYesNo); F.press("A", 2); F.idle(30)
    elseif F.cb2() == (S.CB2_UpdatePartyMenu & ~1) then
      F.idle(40); F.shot(tag .. "_party"); F.press("A", 2); F.idle(40); F.press("A", 2); F.idle(60)
    else
      if sawContest and F.grp() == 13 and F.mapn() == 4 and scriptDone() then
        F.idle(240)
        if scriptDone() and not liveTask(S.Task_HandleYesNoInput) then break end
      end
      if f - lastShot >= 1500 then lastShot = f; F.shot(tag .. "_t" .. f) end
      if f % 25 == 0 and not liveTask(S.Task_HandleMoveSelectInput) then F.press("A", 2) else F.idle(1) end
    end
  end
  F.shot(tag .. "_end")
  local rib, artist = ribbons(S.gParties)
  F.L(string.format("%s: at %s contest=%s painting=%s ribbons=%04X artist=%d paintingFlag=%d", tag, where(),
    tostring(sawContest), tostring(sawPainting), rib, artist, flag(PAINTING_FLAG[cat])))
  return ((rib >> (cat * 3)) & 7) == 4 and flag(PAINTING_FLAG[cat]) == 1
end

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  F.w16(F.sb2() + S.SaveBlock2.optionsU16, (F.r16(F.sb2() + S.SaveBlock2.optionsU16) & ~7) | 3)
  for off = 0, 6 * MON - 4, 4 do F.w32(S.gParties + off, 0) end
  F.w8(S.gPartiesCount, 0)
  F.dbg(); F.idle(30); F.bOut(4)
  F.dbg(); F.sel(3); F.sel(1); F.idle(20); F.spin(sdigits(350)); F.idle(20); F.spin(0, 5, 0); F.idle(60); F.bOut(4)
  F.check("one Pokemon", F.r8(S.gPartiesCount) == 1)
  local w, o = decode(S.gParties)
  w[o[2] + 1] = (w[o[2] + 1] & 0xFFFF) | 0xFFFF0000
  w[o[2] + 2] = 0xFFFFFFFF
  w[o[3] + 2] = (w[o[3] + 2] & ~0x7FFF) | 0x36DB
  encode(S.gParties, w)

  setFlag(FLAG_CURATOR)
  F.w16(F.sb1() + S.SaveBlock1.vars + VAR_MUSEUM_2F * 2, 1)
  for cat = 0, 4 do
    if not ONLY or CATS[cat]:find(ONLY, 1, true) then
      local ok = false
      for try = 1, 10 do if contest(cat) then ok = true; break end end
      F.check(CATS[cat] .. ": won with ribbon and painting within 10 tries", ok)
    end
  end
  F.check("museum: warp to 2F", F.warpTo(0, 1, 3, 0, 0, 3, 0, 0, 0, 13, 3, "museum"))
  F.idle(120); F.shot("museum_2f")
  local w = F.r32(S.gBackupMapLayout); local map = F.r32(S.gBackupMapLayout + 8)
  local function mt(x, y) return F.r16(map + ((x + 7) + (y + 7) * w) * 2) & 0x3FF end
  local frames = { { 10, 6 }, { 18, 6 }, { 14, 10 }, { 6, 10 }, { 2, 6 } }
  local hung = {}
  for i, p in ipairs(frames) do hung[i] = string.format("%03X", mt(p[1], p[2])) end
  F.check("museum: five different paintings hang in the five frames", #hung == 5 and hung[1] ~= hung[2] and hung[2] ~= hung[3]
    and hung[3] ~= hung[4] and hung[4] ~= hung[5] and hung[1] ~= hung[5], table.concat(hung, " "))
  F.route({ { 13, 8 }, { 11, 8 } }, "curator"); F.face("Left")
  F.press("A", 2)
  for _ = 1, 200 do F.idle(15); if scriptDone() then break end; F.press("A", 2) end
  F.shot("museum_after_curator")
  local p = F.r32(S.gDecorationInventories + 3 * 8); local n = F.r8(S.gDecorationInventories + 3 * 8 + 4); local glass = 0
  for i = 0, n - 1 do if F.r8(p + i) == DECOR_GLASS_ORNAMENT then glass = glass + 1 end end
  F.check("museum: the curator gives the Glass Ornament after all five paintings", flag(FLAG_GLASS) == 1 and glass == 1,
    string.format("flag=%d ornaments=%d", flag(FLAG_GLASS), glass))
  F.check("no crash", not F.crashScreen())
  F.finish()
end)
