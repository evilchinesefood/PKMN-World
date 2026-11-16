-- A Hoenn move tutor must teach its move again, with no "learned only once" warning.
--
-- Emerald's move_tutor macro set a FLAG_MOVE_TUTOR_TAUGHT_* flag after the first lesson and jumped
-- straight to the farewell line on every later visit, after asking "This move can be learned only
-- once. Is that okay?". The owner made every tutor reusable, so the Verdanturf Pokemon Center tutor
-- must offer Fury Cutter each time.
--
-- The suite gives two level 5 Mew, stands in front of the tutor and asks him twice with real input,
-- answering YES to every Yes/No box and picking a different Mew in the storage chooser each time.
-- Oracle: each visit raises exactly one Yes/No box (the offer) before the chooser opens, and each
-- Mew ends up knowing Fury Cutter.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "HoennTutorRepeat")

local MON, PARTY_SIZE = S.Pokemon.size, 6
local SPECIES_MEW, MOVE_FURY_CUTTER = 151, 210
local REGION_HOENN = 3
local PC_GROUP, PC_MAP, TUTOR_X, TUTOR_Y = 6, 4, 9, 6
local CONTEXT_SHUTDOWN = 2

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end
local function yesNoUp()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    if F.r8(a + S.Task.isActive) ~= 0 and (F.r32(a + S.Task.func) & 0xFFFFFFFE) == S.Task_HandleYesNoInput then return true end
  end
  return false
end

local function slotAddr(i) return S.gParties + i * MON end
local function moves(i)
  local a = slotAddr(i)
  local pers, otid = F.r32(a), F.r32(a + 4)
  local key = pers ~ otid
  local s1 = F.r8(S.sSubstructOffsets + 24 + pers % 24) * 3
  local w0, w1 = F.r32(a + 32 + s1 * 4) ~ key, F.r32(a + 32 + (s1 + 1) * 4) ~ key
  return { w0 & 0x7FF, (w0 >> 16) & 0x7FF, w1 & 0x7FF, (w1 >> 16) & 0x7FF }
end
local function knows(i, move)
  for _, m in ipairs(moves(i)) do if m == move then return true end end
  return false
end

local function digits(n) n = n - 1; return n // 100, (n // 10) % 10, n % 10 end
local function giveMon(species, level)
  local n0 = F.r8(S.gPartiesCount)
  for _ = 1, 3 do
    F.dbg(); F.idle(30); F.bOut(4)
    F.dbg(); F.sel(3); F.sel(1); F.idle(20)
    F.spin(digits(species)); F.idle(20)
    F.spin(digits(level)); F.idle(60); F.bOut(4)
    if F.r8(S.gPartiesCount) == n0 + 1 then return true end
    F.idle(60)
  end
  return false
end

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
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
      if F.ow() and F.grp() == grp and F.mapn() == map and px == x and py == y then
        F.idle(120)
        return true
      end
    end
    F.bOut(5)
  end
  F.shot(tag .. "_warpfail")
  return false
end

-- Talk to the tutor, answer YES to every Yes/No box, pick party slot `slot` in the storage chooser
-- (Left lands on party slot 1, Up moves to slot 0, A opens Select, A selects), and count the boxes
-- that came up before the chooser opened.
local function teach(slot, tag)
  F.face("Right")
  F.press("A", 2)
  local boxes, wasUp, inMenu = 0, false, false
  for i = 1, 2400 do
    if F.reportCrash(tag) then break end
    local up = yesNoUp()
    if up and not wasUp and not inMenu then
      boxes = boxes + 1
      F.idle(10)
      F.shot(string.format("%s_yesno%d", tag, boxes))
    end
    wasUp = up
    if not F.ow() then
      if not inMenu then
        inMenu = true
        F.idle(120)
        F.shot(tag .. "_chooser")
        local keys = slot == 0 and { "Left", "Up", "A", "A" } or { "Left", "A", "A" }
        for _, k in ipairs(keys) do F.press(k, 2); F.idle(45) end
      else
        F.idle(1)
      end
    elseif inMenu and hasControl() then
      break
    elseif i % 25 == 0 then
      F.press("A", 2)
    else
      F.idle(1)
    end
  end
  for _ = 1, 600 do if hasControl() then break end F.press("B", 2); F.idle(20) end
  return boxes, inMenu
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  instantText()
  for off = 0, PARTY_SIZE * MON - 4, 4 do F.w32(S.gParties + off, 0) end
  F.w8(S.gPartiesCount, 0)
  F.check("setup: two Mew", giveMon(SPECIES_MEW, 5) and giveMon(SPECIES_MEW, 5) and F.r8(S.gPartiesCount) == 2)
  F.check("setup: neither knows Fury Cutter", not knows(0, MOVE_FURY_CUTTER) and not knows(1, MOVE_FURY_CUTTER))
  F.w8(F.sb2() + S.SaveBlock2.currentRegion, REGION_HOENN)
  F.w32(S.gCurrentRegion, REGION_HOENN)
  if not F.check("stand before the Verdanturf Fury Cutter tutor", warpToCoords(PC_GROUP, PC_MAP, TUTOR_X, TUTOR_Y, "tutor")) then
    F.finish(); return
  end
  instantText()

  local boxes1, menu1 = teach(0, "first")
  F.check("first visit: the chooser opened", menu1)
  F.check("first visit: the first Mew learned Fury Cutter", knows(0, MOVE_FURY_CUTTER), table.concat(moves(0), ","))
  F.check("first visit: one Yes/No box, no learned-only-once warning", boxes1 == 1, "boxes=" .. boxes1)

  local boxes2, menu2 = teach(1, "second")
  F.check("second visit: the chooser opened", menu2)
  F.check("second visit: the second Mew learned Fury Cutter", knows(1, MOVE_FURY_CUTTER), table.concat(moves(1), ","))
  F.check("second visit: one Yes/No box, no learned-only-once warning", boxes2 == 1, "boxes=" .. boxes2)
  F.check("no crash", not F.crashScreen())
  F.finish()
end)
