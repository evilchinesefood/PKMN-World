-- May's or Brendan's Rayquaza call rings 250 steps after the Space Center battle
-- (ShouldDoRivalRayquazaCall) and clears FLAG_DEFEATED_MAGMA_SPACE_CENTER, the flag Emerald sets
-- only to arm that call. The Story resolver read the same flag as proof the Space Center was saved,
-- so once the phone rang, Story sent the player back to "Protect the Space Center" until the
-- Seafloor Cavern crisis began.
--
-- The suite leaves the state the Space Center victory script leaves (VAR_MOSSDEEP_SPACE_CENTER_STATE
-- 3, the flag, Steven's house 1) on top of seven Hoenn badges and Surf, then walks real steps until the call
-- rings: first in Mossdeep, then a second time in Johto's Violet City with buttons mashed under the
-- call. Each run answers the call, proves control returns and the field is walkable, and reads the
-- Hoenn row of the Story screen, opened through the Start menu.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/PhoneRayquazaCallStory.lua <rom>
-- PW_PHONE_SEED picks the mash seed (default 9101).

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "PhoneRayquazaCallStory")

local HUB = 100
local MOSSDEEP, MOSSDEEP_CENTER_DOOR, MOSSDEEP_ROW = { 0, 6 }, 2, { 20, 34, 17 }
local VIOLET, VIOLET_CENTER_DOOR, VIOLET_ROW = { 75, 6 }, 2, { 35, 48, 46 }
local FLAG_TEAM_AQUA_ESCAPED_IN_SUBMARINE = 0x70
local FLAG_DEFEATED_MAGMA_SPACE_CENTER = 0x75
local FLAG_RECEIVED_HM_SURF = 0x7A
local FLAG_DELIVERED_DEVON_GOODS = 0x95
local FLAG_RECEIVED_POKENAV = 0xBC
local FLAG_DELIVERED_STEVEN_LETTER = 0xBD
local FLAG_SYS_POKENAV_GET = 0x94A
local FLAG_BADGE01_GET = 0x94F
local VAR_MOSSDEEP_SPACE_CENTER_STATE = 0x409F
local VAR_STEVENS_HOUSE_STATE = 0x40C6
local VAR_RIVAL_RAYQUAZA_CALL_STEP_COUNTER = 0x40F6
local USM_ICO_QUESTS = 6
local HOENN_ROW, PROGRESS_STRIDE = 2, 16
local CONTEXT_RUNNING = 0
local seed = tonumber(os.getenv("PW_PHONE_SEED") or "") or 9101

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function varAddr(id)
  if id >= 0xA000 then return F.sb3() + S.SaveBlock3.regionVars + (id - 0xA000) * 2 end
  return F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2
end
local function getVar(id) return F.r16(varAddr(id)) end
local function setVar(id, v) F.w16(varAddr(id), v) end
local function flagAddr(id) return F.sb1() + S.SaveBlock1.flags + id // 8, id % 8 end
local function flagGet(id) local a, b = flagAddr(id); return (F.r8(a) >> b) & 1 == 1 end
local function flagSet(id) local a, b = flagAddr(id); F.w8(a, F.r8(a) | (1 << b)) end
local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function warp(m, w, tag)
  local gh, gt, go = d(m[1]); local mh, mt, mo = d(m[2]); local wh, wt, wo = d(w)
  return F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, m[1], m[2], tag)
end
local SCRIPT_BUF = S.gStringVar4 + 960
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
  F.idle(20)
end
local function createMon(species, level)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(b, species); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for _ = 1, 4 do le16(b, 0) end
  b[#b + 1] = 0x02
  runScript(b)
end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function partySum()
  local s = 0
  for i = 0, 6 * 100 - 1, 4 do s = (s + F.r32(S.gParties + i)) & 0xFFFFFFFF end
  return s
end

-- The state MossdeepCity_SpaceCenter_2F's victory script leaves behind.
local function spaceCenterSaved()
  flagSet(FLAG_DEFEATED_MAGMA_SPACE_CENTER)
  setVar(VAR_MOSSDEEP_SPACE_CENTER_STATE, 3)
  setVar(VAR_STEVENS_HOUSE_STATE, 1)
  setVar(VAR_RIVAL_RAYQUAZA_CALL_STEP_COUNTER, 0)
end

local rng = seed
local function rand(n) rng = (rng * 1103515245 + 12345) & 0x7FFFFFFF; return rng % n end
local MASH = { "A", "B", "Start", "Select", "L", "R", "Up", "Down", "Left", "Right" }

-- Pace a row until the phone rings. Returns the steps taken and whether a call was answered.
local function paceUntilCall(row, tag, mash)
  local x0, x1, y = row[1], row[2], row[3]
  local steps, dir = 0, "Left"
  for _ = 1, 700 do
    if F.reportCrash(tag) then return steps, false end
    if not hasControl() then
      F.shot(tag .. "_ringing")
      local pressed = 0
      for _ = 1, 900 do
        if hasControl() then break end
        if F.reportCrash(tag .. "_call") then return steps, false end
        if mash then
          local key = MASH[rand(#MASH) + 1]
          F.press(key, 1 + rand(3)); pressed = pressed + 1
          F.idle(rand(6))
        else
          F.press("A", 2); F.idle(20)
        end
      end
      F.L(string.format("  %s: call answered after %d steps (%d mashed presses) at %s", tag, steps, pressed, where()))
      for _ = 1, 60 do
        if hasControl() then break end
        F.press("B", 2); F.idle(16)
      end
      return steps, hasControl()
    end
    local x = F.pos()
    if x <= x0 then dir = "Right" elseif x >= x1 then dir = "Left" end
    if F.step(dir) then steps = steps + 1 end
    local _, py = F.pos()
    if py ~= y and hasControl() then F.step(py > y and "Up" or "Down") end
  end
  return steps, false
end

local function storyHoennObjective(tag)
  F.press("Start", 2); F.idle(60)
  if not F.check(tag .. ": Story icon", F.selectStartIcon(USM_ICO_QUESTS)) then F.press("B", 2); F.idle(60); return nil end
  F.press("A", 2); F.idle(120)
  if not F.check(tag .. ": Story opens", F.cb2() == (S.CB2_Story & ~1)) then return nil end
  local p = F.r32(F.r32(S.sStoryProgress + HOENN_ROW * PROGRESS_STRIDE))
  local t = {}
  for i = 0, 63 do local c = F.r8(p + i); if c == 0 then break end; t[#t + 1] = string.char(c) end
  F.shot(tag .. "_story")
  F.press("B", 2); F.idle(90); F.press("B", 2); F.idle(90)
  F.check(tag .. ": back on the field after Story", F.dismiss(20), where())
  return table.concat(t)
end

local function run(tag, map, door, row, mash)
  spaceCenterSaved()
  F.check(tag .. ": warped in", warp(map, door, tag), where())
  F.dismiss(20)
  local before = storyHoennObjective(tag .. "_before")
  F.check(tag .. ": before the call Story points past the Space Center", before == "hoenn.dive", tostring(before))
  local sum, money = partySum(), F.money()
  local steps, answered = paceUntilCall(row, tag, mash)
  F.check(tag .. ": the rival's call rang and was answered", answered, where() .. " steps=" .. steps)
  F.check(tag .. ": the call came on its 250-step count", steps >= 240 and steps <= 252, "steps=" .. steps)
  F.check(tag .. ": the call cleared its arming flag", not flagGet(FLAG_DEFEATED_MAGMA_SPACE_CENTER))
  F.check(tag .. ": control returned after the call", hasControl(), where())
  F.check(tag .. ": the field is walkable after the call", F.ensureFree(), where())
  F.check(tag .. ": party unchanged by the call", partySum() == sum)
  F.check(tag .. ": money unchanged by the call", F.money() == money, F.money() .. " vs " .. money)
  local objective = storyHoennObjective(tag)
  F.L("  " .. tag .. ": Hoenn Story objective after the call = " .. tostring(objective))
  F.check(tag .. ": Story does not send the player back to the saved Space Center",
    objective == "hoenn.dive", tostring(objective))
end

F.run(function()
  if not F.boot(HUB) then F.check("boot", false); F.finish(); return end
  F.L("  seed=" .. seed)
  createMon(25, 50)
  for i = 0, 6 do flagSet(FLAG_BADGE01_GET + i) end
  for _, f in ipairs({ FLAG_SYS_POKENAV_GET, FLAG_RECEIVED_POKENAV, FLAG_DELIVERED_STEVEN_LETTER,
                       FLAG_DELIVERED_DEVON_GOODS, FLAG_TEAM_AQUA_ESCAPED_IN_SUBMARINE, FLAG_RECEIVED_HM_SURF }) do
    flagSet(f)
  end
  run("mossdeep", MOSSDEEP, MOSSDEEP_CENTER_DOOR, MOSSDEEP_ROW, false)
  run("violet", VIOLET, VIOLET_CENTER_DOOR, VIOLET_ROW, true)
  F.finish()
end)
