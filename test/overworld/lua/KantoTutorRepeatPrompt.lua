-- A Kanto move tutor that teaches again must not say its move can be learned only once.
--
-- I_REUSABLE_TMS is TRUE, so move_tutors_frlg.inc compiles out every FRLG tutor's "taught" flag and
-- the tutor offers the move again on the next visit. The scripts still asked "This move can be
-- learned only once. Is that okay?" before the party menu, a promise the game then broke. Cape
-- Brink's ultimate-move tutor keeps its flags in C and stays one-time, so it keeps the question.
--
-- The suite gives two level 5 Mew, enters the Pewter Museum by its back door and asks the Seismic
-- Toss tutor twice with real input, answering YES to every Yes/No box and picking a different Mew
-- each time. Oracle: each visit raises exactly one Yes/No box (the offer) before the party menu, and
-- each Mew ends up knowing Seismic Toss, which proves the tutor really is reusable.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "KantoTutorRepeatPrompt")

local MON, PARTY_SIZE = S.Pokemon.size, 6
local SPECIES_MEW, MOVE_SEISMIC_TOSS = 151, 69
local MUSEUM_G, MUSEUM_M = 40, 0
local CONTEXT_SHUTDOWN = 2

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
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

-- Talk to the tutor, answer YES to every Yes/No box, pick party slot `slot`, and count the boxes
-- that came up before the party menu opened.
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
        F.shot(tag .. "_party")
        for _ = 1, slot do F.press("Down", 2); F.idle(12) end
        F.press("A", 2); F.idle(60)
      elseif i % 30 == 0 then
        F.press("A", 2)
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
  F.check("setup: neither knows Seismic Toss", not knows(0, MOVE_SEISMIC_TOSS) and not knows(1, MOVE_SEISMIC_TOSS))
  F.check("warp to the Pewter Museum back door", F.warpTo(0, 4, 0, 0, 0, 0, 0, 0, 3, MUSEUM_G, MUSEUM_M, "museum"))
  instantText()
  F.check("walk to the Seismic Toss tutor", F.route({ { 21, 8 }, { 25, 8 }, { 25, 7 } }, "tutor"), where())

  local boxes1, menu1 = teach(0, "first")
  F.check("first visit: the party menu opened", menu1)
  F.check("first visit: the first Mew learned Seismic Toss", knows(0, MOVE_SEISMIC_TOSS), table.concat(moves(0), ","))
  F.check("first visit: one Yes/No box, no learned-only-once warning", boxes1 == 1, "boxes=" .. boxes1)

  local boxes2, menu2 = teach(1, "second")
  F.check("second visit: the tutor teaches again", menu2 and knows(1, MOVE_SEISMIC_TOSS), table.concat(moves(1), ","))
  F.check("second visit: one Yes/No box, no learned-only-once warning", boxes2 == 1, "boxes=" .. boxes2)
  F.finish()
end)
