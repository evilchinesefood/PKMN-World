-- Declining a move at the Move Relearner's "Teach X?" prompt must cost nothing.
--
-- Fallarbor's relearner (and every relearner that calls TeachMoveRelearnerMove) checks
-- Special_HasMoveToRelearn first, which leaves VAR_RESULT TRUE. LearnMove's No/B branch at the
-- confirmation prompt returned without clearing it, so UIEndTask read the stale TRUE as "a move was
-- learned", closed the relearner and the script took the Heart Scale for nothing.
--
-- With real input from inside the house the suite talks to the relearner, says YES, picks the lead
-- Wobbuffet in the storage chooser, picks the first move and answers NO; then picks it again and
-- presses B; then gives up from the list. The relearner must stay open after each decline, the
-- Heart Scale must stay in the bag and the Pokemon must be unchanged. Setup gives the debug party
-- and one Heart Scale (an additem script, the way the game gives items) and warps into the house.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "RelearnerDeclineHeartScale")

local HUB = 100
local REGION_HOENN = 3
local ITEM_HEART_SCALE = 152
local FALLARBOR_RELEARNER_GROUP, FALLARBOR_RELEARNER_MAP = 5, 5
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end

local SCRIPT_BUF = S.gStringVar4 + 960
local function addItem(id, n)
  local bytes = { 0x44, id & 0xFF, id >> 8, n, 0, 0x02 }       -- additem id, n; end
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
  for _ = 1, 200 do F.idle(4); if hasControl() then break end end
  F.idle(30)
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

-- gStringVar4 as uppercase ASCII; Gen 3 A = 0xBB, a = 0xD5.
local function message()
  local s = {}
  for i = 0, 200 do
    local c = F.r8(S.gStringVar4 + i)
    if c == 0xFF then break end
    if c >= 0xBB and c <= 0xD4 then s[#s + 1] = string.char(65 + c - 0xBB)
    elseif c >= 0xD5 and c <= 0xEE then s[#s + 1] = string.char(65 + c - 0xD5)
    elseif c == 0xAC then s[#s + 1] = "?"
    else s[#s + 1] = " " end
  end
  return table.concat(s)
end

local function yesNoUp()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    local fn = F.r32(a + S.Task.func) & 0xFFFFFFFE
    if F.r8(a + S.Task.isActive) ~= 0 and (fn == S.Task_HandleYesNoInput or fn == S.Task_HandleMultichoiceInput) then return true end
  end
  return false
end

local function partyBytes()
  local t = {}
  for i = 0, S.Pokemon.size - 1 do t[#t + 1] = F.r8(S.gParties + i) end
  return table.concat(t, ",")
end

local function waitFor(pred, frames)
  for _ = 1, frames // 5 do if pred() then return true end; F.idle(5) end
  return pred()
end

-- From the relearner's list, A on the first move opens "Teach X?"; answer NO with the cursor or B.
local function declineFirstMove(tag, keys)
  F.press("A", 2)
  local asked = waitFor(function() return message():find("TEACH SAFEGUARD") ~= nil end, 200)
  F.idle(120)
  F.shot(tag .. "_prompt")
  F.check(tag .. ": the relearner asks to teach the move", asked, message())
  if keys == "No" then
    for _ = 1, 5 do
      if F.mcur() == 1 then break end
      F.press("Down", 2); F.idle(20)
    end
    F.check(tag .. ": the cursor is on NO", F.mcur() == 1, "cursor=" .. F.mcur())
    F.press("A", 2)
  else
    F.press("B", 2)
  end
  F.idle(120)
  F.shot(tag .. "_after")
  F.check(tag .. ": the relearner stays open on its move list",
    not F.ow() and message():find("TEACH WHICH") ~= nil,
    string.format("cb2=%08X msg=%s", F.cb2(), message()))
end

F.run(function()
  if not F.boot(HUB) then F.check("boot", false); F.finish(); return end
  F.dbg(); F.sel(2); F.sel(9); F.idle(120); F.bOut(3)    -- Party > Set Party: the debug Wobbuffet
  F.w8(F.sb2() + S.SaveBlock2.currentRegion, REGION_HOENN)
  F.w32(S.gCurrentRegion, REGION_HOENN)
  addItem(ITEM_HEART_SCALE, 1)
  F.check("setup: one Heart Scale", F.itemCount(ITEM_HEART_SCALE) == 1)
  if not F.check("setup: inside the Fallarbor relearner's house",
    warpToCoords(FALLARBOR_RELEARNER_GROUP, FALLARBOR_RELEARNER_MAP, 4, 5, "house")) then F.finish(); return end
  local before = partyBytes()

  F.face("Up"); F.press("A", 2); F.idle(30)
  local chooser = false
  for _ = 1, 300 do
    if not F.ow() then chooser = true; break end
    if yesNoUp() then F.idle(16) end
    F.press("A", 2); F.idle(14)
  end
  F.idle(90)
  F.shot("chooser")
  F.check("the YES opens the Pokemon chooser", chooser)

  -- Party column: Left lands on slot 1, Up on the Wobbuffet; A opens Select, A selects it.
  for _, k in ipairs({ "Left", "Up", "A", "A" }) do F.press(k, 2); F.idle(45) end
  waitFor(F.ow, 400)
  local opened = false
  for _ = 1, 60 do
    if not F.ow() then opened = true; break end
    F.press("A", 2); F.idle(20)
  end
  F.idle(150)
  F.shot("move_list")
  F.check("the relearner opens on its move list", opened and message():find("TEACH WHICH") ~= nil, message())

  declineFirstMove("no", "No")
  declineFirstMove("b", "B")

  -- Give up from the list: B, then YES.
  F.press("B", 2)
  waitFor(function() return message():find("GIVE UP") ~= nil end, 200)
  F.idle(120)
  F.shot("give_up")
  for _ = 1, 20 do
    if F.ow() then break end
    F.press("A", 2); F.idle(30)
  end
  -- The script goes back to "Which POKeMON needs tutoring?"; B closes the chooser.
  local said = {}
  for _ = 1, 300 do
    local m = message()
    if said[#said] ~= m then said[#said + 1] = m end
    if hasControl() then F.idle(20); if hasControl() then break end end
    if F.ow() then F.press("A", 2); F.idle(20) else F.idle(60); F.press("B", 2) end
  end
  F.shot("back_in_house")
  local text = table.concat(said, " | ")
  F.L("  after giving up: " .. text)
  F.check("control returns after giving up", hasControl())
  F.check("the relearner did not take a Heart Scale", F.itemCount(ITEM_HEART_SCALE) == 1 and not text:find("HANDED OVER"),
    "heart scale slots=" .. F.itemCount(ITEM_HEART_SCALE) .. " said=" .. text)
  F.check("the Wobbuffet is unchanged", partyBytes() == before)
  F.check("no crash", not F.crashScreen())
  F.finish()
end)
