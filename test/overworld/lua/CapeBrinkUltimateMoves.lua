-- The Cape Brink tutor teaches a fully friendly Venusaur, Charizard or Blastoise its ultimate move.
-- The move is chosen in C (CapeBrinkGetMoveToTeachLeadPokemon), so tools/learnset_helpers/
-- make_tutors.py, which reads `setvar VAR_0x8005, MOVE_*` from scripts, never listed Frenzy Plant,
-- Blast Burn or Hydro Cannon as tutor moves, no teachable learnset held them, and the party menu
-- showed the starter NOT ABLE: the tutor offered the move and could not teach it. Setup turns the
-- debug party's lead into each starter at 255 friendship with three moves (the state a
-- fully-raised starter brings); the talk, both Yes answers and the party pick are real input.
-- Oracle: the lead knows the ultimate move afterwards and its tutor flag is set.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "CapeBrinkUltimateMoves")

local HOUSE_G, HOUSE_M = 72, 0
local CASES = {
  { name = "Venusaur", species = 3, move = 338, flag = 0xA40 + 0x2DE },
  { name = "Charizard", species = 6, move = 307, flag = 0xA40 + 0x2DF },
  { name = "Blastoise", species = 9, move = 308, flag = 0xA40 + 0x2E0 },
}
local CONTEXT_SHUTDOWN = 2

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function flagSet(id) return (F.r8(F.sb1() + S.SaveBlock1.flags + id // 8) & (1 << (id % 8))) ~= 0 end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end

-- Decrypt slot 0's secure substructs, let `edit` change them, then fix the checksum and re-encrypt.
local function editLead(edit)
  local a = S.gParties
  local key = F.r32(a) ~ F.r32(a + 4)
  local w = {}
  for i = 0, 11 do w[i] = F.r32(a + 32 + i * 4) ~ key end
  local function sub(n) return F.r8(S.sSubstructOffsets + n * 24 + F.r32(a) % 24) * 3 end
  edit(w, sub)
  local sum = 0
  for i = 0, 11 do sum = sum + w[i] + (w[i] >> 16) end
  F.w16(a + 28, sum & 0xFFFF)
  for i = 0, 11 do F.w32(a + 32 + i * 4, w[i] ~ key) end
end
local function leadMoves()
  local a = S.gParties
  local key = F.r32(a) ~ F.r32(a + 4)
  local o = F.r8(S.sSubstructOffsets + 24 + F.r32(a) % 24) * 3
  local w0, w1 = F.r32(a + 32 + o * 4) ~ key, F.r32(a + 36 + o * 4) ~ key
  return { w0 & 0xFFFF, w0 >> 16, w1 & 0xFFFF, w1 >> 16 }
end
local function knows(move)
  for _, m in ipairs(leadMoves()) do if m == move then return true end end
  return false
end

-- A through the tutor: every Yes/No answered Yes, the party menu answered with slot 0.
local function talkToTutor(tag)
  F.face("Up")
  for _ = 1, 10 do
    F.press("A", 2); F.idle(20)
    if not hasControl() then break end
  end
  local free = 0
  for i = 1, 3000 do
    if F.reportCrash(tag) then return false end
    if hasControl() then
      free = free + 1
      if free > 60 then return true end
      F.idle(1)
    else
      free = 0
      if i % 12 == 0 then F.press("A", 2) else F.idle(1) end
    end
  end
  F.shot(tag .. "_stuck")
  return false
end

F.run(function()
  if not F.boot(100) then F.check("fresh boot", false); F.finish(); return end
  F.dbg(); F.idle(40); F.sel(2); F.idle(40); for _ = 1, 9 do F.press("Down", 3); F.idle(16) end; F.press("A", 3); F.idle(180)
  for _ = 1, 6 do F.press("B", 2); F.idle(20) end
  for _, c in ipairs(CASES) do
    editLead(function(w, sub)
      local g, atk = sub(0), sub(1)
      w[g] = (w[g] & ~0x7FF) | c.species
      w[g + 2] = (w[g + 2] & ~0xFF00) | (255 << 8)
      w[atk + 1] = w[atk + 1] & 0xFFFF
    end)
    F.check(c.name .. ": reach the tutor", F.warpTo(0, 7, 2, 0, 0, 0, 0, 0, 0, HOUSE_G, HOUSE_M, c.name) and F.route({ { 4, 6 }, { 4, 5 } }, c.name .. "_walk"), where())
    F.check(c.name .. ": the tutor's offer runs to the end", talkToTutor(c.name))
    F.shot(c.name .. "_after")
    F.check(c.name .. ": learns its ultimate move", knows(c.move), "moves=" .. table.concat(leadMoves(), ","))
    F.check(c.name .. ": the tutor records it", flagSet(c.flag))
    F.warpTo(0, 3, 7, 0, 4, 7, 0, 0, 0, 37, 47, "out")
  end
  F.finish()
end)
