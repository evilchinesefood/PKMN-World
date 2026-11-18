-- Random Match Calls from Hoenn trainers ring wherever the player walks: TryStartMatchCall runs on
-- every tenth step, at most once per ten RTC minutes, on a 30% roll (60% behind a Lightning Rod lead),
-- on any map type that allows Fly. No suite had let one ring, and none had rung one outside Hoenn.
-- The suite sets the state the Rustboro PokeNav scene and five registrations (Rose, Andres, Dusty,
-- Lola, Ricky) leave (FLAG_HAS_MATCH_CALL and the registered-trainer flags) over five Hoenn badges,
-- leads with a Lightning Rod Rhyhorn, takes the first call in Mossdeep, then paces Johto's Violet City
-- and Kanto's Viridian City until a timed call rings in each, mashing every button under the Violet
-- call (PW_PHONE_SEED, default 9101). Each call must return control to a walkable field on the same
-- map with the party, money and registrations unchanged across the call (walking thousands of steps
-- raises friendship, so the party is compared from the ring), and leave no crash screen.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/PhoneMatchCallRegions.lua <rom>
--   --env PW_MAX_FRAMES=2000000 --timeout 3000 [--rtc <epoch>]

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "PhoneMatchCallRegions")

local HUB = 100
local MOSSDEEP, MOSSDEEP_CENTER_DOOR, MOSSDEEP_ROW = { 0, 6 }, 2, { 20, 34, 17 }
local VIOLET, VIOLET_CENTER_DOOR, VIOLET_ROW = { 75, 6 }, 2, { 35, 48, 46 }
local VIRIDIAN, VIRIDIAN_CENTER_DOOR, VIRIDIAN_ROW = { 37, 1 }, 0, { 18, 40, 27 }
local FLAG_HAS_MATCH_CALL = 0x12F
local FLAG_ADDED_MATCH_CALL_TO_POKENAV = 0x130
local TRAINER_REGISTERED_FLAGS_START = 0x15C
local FLAG_SYS_POKENAV_GET = 0x94A
local FLAG_BADGE01_GET = 0x94F
local REGISTERED = { 0, 1, 2, 3, 4 }
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

local rng = seed
local function rand(n) rng = (rng * 1103515245 + 12345) & 0x7FFFFFFF; return rng % n end
local MASH = { "A", "B", "Start", "Select", "L", "R", "Up", "Down", "Left", "Right" }
local function registrations()
  local t = {}
  for _, i in ipairs(REGISTERED) do t[#t + 1] = flagGet(TRAINER_REGISTERED_FLAGS_START + i) and "1" or "0" end
  return table.concat(t)
end

local function paceUntilCall(row, tag, mash)
  local x0, x1, y = row[1], row[2], row[3]
  local steps, dir, f0 = 0, "Left", emu.framecount()
  for _ = 1, 20000 do
    if F.reportCrash(tag) then return steps, false end
    if not hasControl() then
      local pressed, sum = 0, partySum()
      F.idle(40); F.shot(tag .. "_ringing")
      for _ = 1, 1500 do
        if hasControl() then break end
        if F.reportCrash(tag .. "_call") then return steps, false end
        if mash then
          F.press(MASH[rand(#MASH) + 1], 1 + rand(3)); pressed = pressed + 1
          F.idle(rand(6))
        else
          F.press("A", 2); F.idle(20)
        end
      end
      for _ = 1, 60 do
        if hasControl() then break end
        F.press("B", 2); F.idle(16)
      end
      F.L(string.format("  %s: call answered after %d steps, %d frames (%d mashed presses) at %s",
        tag, steps, emu.framecount() - f0, pressed, where()))
      return steps, hasControl(), sum
    end
    local x = F.pos()
    if x <= x0 then dir = "Right" elseif x >= x1 then dir = "Left" end
    if F.step(dir) then steps = steps + 1 else dir = dir == "Left" and "Right" or "Left" end
    local _, py = F.pos()
    if py ~= y and hasControl() then F.step(py > y and "Up" or "Down") end
  end
  return steps, false
end

local function run(tag, map, door, row, mash)
  F.check(tag .. ": warped in", warp(map, door, tag), where())
  F.dismiss(20)
  local money, regs = F.money(), registrations()
  local steps, answered, sum = paceUntilCall(row, tag, mash)
  F.check(tag .. ": a Match Call rang and was answered", answered, where() .. " steps=" .. steps)
  F.check(tag .. ": control returned after the call", hasControl(), where())
  F.check(tag .. ": the field is walkable after the call", F.ensureFree(), where())
  F.check(tag .. ": still on the map the call rang on", F.grp() == map[1] and F.mapn() == map[2], where())
  F.check(tag .. ": party unchanged by the call", partySum() == sum)
  F.check(tag .. ": money unchanged by the call", F.money() == money, F.money() .. " vs " .. money)
  F.check(tag .. ": registrations unchanged by the call", registrations() == regs, registrations())
  F.shot(tag .. "_after")
end

F.run(function()
  if not F.boot(HUB) then F.check("boot", false); F.finish(); return end
  F.L("  seed=" .. seed)
  createMon(111, 50)
  for i = 0, 4 do flagSet(FLAG_BADGE01_GET + i) end
  for _, f in ipairs({ FLAG_SYS_POKENAV_GET, FLAG_HAS_MATCH_CALL, FLAG_ADDED_MATCH_CALL_TO_POKENAV }) do flagSet(f) end
  for _, i in ipairs(REGISTERED) do flagSet(TRAINER_REGISTERED_FLAGS_START + i) end
  run("mossdeep", MOSSDEEP, MOSSDEEP_CENTER_DOOR, MOSSDEEP_ROW, false)
  run("violet", VIOLET, VIOLET_CENTER_DOOR, VIOLET_ROW, true)
  run("viridian", VIRIDIAN, VIRIDIAN_CENTER_DOOR, VIRIDIAN_ROW, false)
  F.finish()
end)
