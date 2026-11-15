-- dcd1570afe refuses the Hub Pass in the champion rooms, as in the Elite Four rooms, so a League run
-- cannot step out to heal. The Johto champion room is the one that hands the player control
-- before the champion (Hoenn's and Kanto's walk straight into the battle on entry). The Hub Pass is
-- fired from Select with the confirm answered YES and A, B and Start pressed after it:
--   * Johto Champion's Room and Karen's Room, and Ever Grande's Hall 4 (the last hall before
--     Wallace): refused, the player stays, and control returns;
--   * the Johto Indigo Plateau Pokemon Center, the League lobby: the pass works (control).
-- Setup gives the pass with `additem` and registers it; the rooms are reached by debug warp.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "HubPassLeagueRooms")

local HUB_GROUP = 100
local ITEM_HUB_RETURN = 893
local CONTEXT_RUNNING = 0

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function count() return F.r8(S.gPartiesCount) end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function awaitControl(budget)
  for i = 1, budget do
    if hasControl() and i > 20 then F.idle(20); if hasControl() then return true end end
    if i % 30 == 0 then F.press("B", 2) else F.idle(1) end
  end
  return hasControl()
end

local SCRIPT_BUF = S.gStringVar4 + 960
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
  F.idle(20)
end

local function debugParty()
  F.dbg(); F.idle(40); F.sel(2); F.idle(40)
  for _ = 1, 9 do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(180)
  for _ = 1, 30 do F.press("B", 2); F.idle(16); if F.ensureFree() then break end end
  return count() >= 1
end

local function yesNoUp()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    if F.r8(a + S.Task.isActive) ~= 0 and (F.r32(a + S.Task.func) & 0xFFFFFFFE) == (S.Task_CallYesOrNoCallback & 0xFFFFFFFE) then
      return true
    end
  end
  return false
end

-- Select, then YES on the confirm when one comes up (its cursor rests on NO), with A, B and Start
-- pressed through any message. Nothing is pressed once the field has control again.
local function firePass(tag)
  F.w16(F.sb1() + S.SaveBlock1.registeredItem, ITEM_HUB_RETURN)
  F.press("Select", 2); F.idle(40)
  F.shot(tag .. "_pass")
  for i = 1, 60 do
    if F.grp() == HUB_GROUP then break end
    if yesNoUp() then
      F.press("Up", 2); F.idle(10); F.press("A", 2)
    elseif hasControl() then
      if i > 3 then break end
    else
      local k = i % 3
      F.press(k == 0 and "A" or k == 1 and "B" or "Start", 2)
    end
    F.idle(16)
  end
  F.idle(120)
end

local function refusedIn(name, warpArgs, g, m)
  local args = { table.unpack(warpArgs) }
  args[#args + 1] = g; args[#args + 1] = m; args[#args + 1] = name
  if not F.warpTo(table.unpack(args)) then F.check(name .. ": warped in", false, where()); return end
  F.check(name .. ": control after the entry scene", awaitControl(900), where())
  firePass(name)
  F.check(name .. ": the Hub Pass is refused, the player stays", F.grp() == g and F.mapn() == m, where())
  F.check(name .. ": control returns", awaitControl(600),
    string.format("lock=%d ctx=%d", F.r8(S.sLockFieldControls), F.r8(S.sGlobalScriptContextStatus)))
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot", false); F.finish(); return end
  F.check("setup: debug party", debugParty(), "n=" .. count())
  runScript({ 0x44, ITEM_HUB_RETURN & 0xFF, ITEM_HUB_RETURN >> 8, 1, 0, 0x02 })
  F.check("setup: the Hub Pass is in the bag", F.keyItemSlot(ITEM_HUB_RETURN) >= 0)

  refusedIn("Johto Champion's Room", { 0, 9, 9, 0, 0, 9, 0, 0, 0 }, 99, 9)
  refusedIn("Johto Karen's Room", { 0, 9, 9, 0, 0, 8, 0, 0, 0 }, 99, 8)
  refusedIn("Ever Grande Hall 4", { 0, 1, 6, 0, 0, 8, 0, 0, 0 }, 16, 8)

  -- The League lobby: the pass works.
  if F.warpTo(0, 9, 9, 0, 0, 4, 0, 0, 0, 99, 4, "johto_league_pc") then
    awaitControl(600)
    firePass("lobby")
    F.check("Johto League lobby: the Hub Pass reaches the hub", F.grp() == HUB_GROUP, where())
  else
    F.check("Johto League lobby: warped in", false, where())
  end
  F.finish()
end)
