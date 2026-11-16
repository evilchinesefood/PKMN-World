-- Johto's mother hands over the PokeGear by setting FLAG_RECEIVED_POKENAV, the flag Devon's
-- president sets in Rustboro. Hoenn reads it as "the PokeNav scene is behind you": every Pokemon
-- Center visit then records Mr. Briney's shore, and the next Hoenn arrival docks him at his
-- cottage, so a player who started in Johto found Briney and Peeko home (and Briney ready to sail)
-- while Peeko was still missing. The suite starts in Johto through the hub gate, walks downstairs
-- for the mother's PokeGear scene, then plays Hoenn with the first badge: heals at the Rustboro
-- Pokemon Center, leaves by Hub Pass, comes back through the Hoenn gate and visits the cottage.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/PokegearKeepsHoennPokenav.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "PokegearKeepsHoennPokenav")

local HUB = { 100, 0 }
local HOUSE_1F, HOUSE_2F = { 76, 3 }, { 76, 4 }
local RUSTBORO_CENTER = { 11, 5 }
local BRINEYS_HOUSE = { 17, 0 }
local VAR_NEWBARK_TOWN_STATE = 0xA080
local VAR_BRINEY_LOCATION = 0x4096
local FLAG_RECEIVED_POKENAV = 0xBC
local FLAG_SYS_POKENAV_GET = 0x94A
local FLAG_BADGE01_GET = 0x94F
local FLAG_HIDE_BRINEYS_HOUSE_MR_BRINEY = 0x2E3
local CONTEXT_RUNNING = 0
local hubPass

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function mapIs(m) return F.grp() == m[1] and F.mapn() == m[2] end
local function varAddr(id)
  if id >= 0xA000 then return F.sb3() + S.SaveBlock3.regionVars + (id - 0xA000) * 2 end
  return F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2
end
local function getVar(id) return F.r16(varAddr(id)) end
local function flagAddr(id)
  if id >= 0x6000 and id < 0x6400 then return F.sb3() + S.SaveBlock3.johtoFlags + (id - 0x6000) // 8, (id - 0x6000) % 8 end
  return F.sb1() + S.SaveBlock1.flags + id // 8, id % 8
end
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
local function scriptMenuActive()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    local fn = F.r32(a + S.Task.func) & 0xFFFFFFFE
    if F.r8(a + S.Task.isActive) ~= 0 and (fn == S.Task_HandleYesNoInput or fn == S.Task_HandleMultichoiceInput or fn == S.Task_CallYesOrNoCallback) then return true end
  end
  return false
end
-- Press A until a Yes/No or menu is up, put the cursor on `want` and pick it.
local function menu(want, tag, maxA)
  for _ = 1, (maxA or 65) do
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
local function awaitMap(m, tag)
  for _ = 1, 400 do
    if mapIs(m) and F.ow() then F.idle(100); return true end
    if F.reportCrash(tag) then return false end
    F.press("A", 2); F.idle(14)
  end
  F.shot(tag .. "_failed")
  return false
end
local function awaitGroup(g, tag)
  for _ = 1, 400 do
    if F.grp() == g and F.ow() then F.idle(100); return true end
    if F.reportCrash(tag) then return false end
    F.press("A", 2); F.idle(14)
  end
  F.shot(tag .. "_failed")
  return false
end
local function drain()
  for _ = 1, 60 do
    if hasControl() then return true end
    F.press("B", 2); F.idle(16)
  end
  return hasControl()
end
local function crossGate(path, tag)
  if not F.route(path, tag .. "_walk") then return false end
  F.face("Up"); F.press("A", 3); F.idle(60)
  return menu(0, tag .. "_yes")
end
local function useHubPass(tag)
  F.w16(F.sb1() + S.SaveBlock1.registeredItem, hubPass)
  F.press("Select", 2); F.idle(90)
  return menu(0, tag .. "_hub_pass") and awaitMap(HUB, tag .. "_hub")
end
local function talk(dir, tag)
  F.face(dir)
  F.press("A", 2)
  local started = false
  for _ = 1, 120 do
    if not hasControl() then started = true; break end
    F.idle(1)
  end
  if not started then return false end
  for _ = 1, 400 do
    F.idle(20)
    if hasControl() then break end
    F.press("A", 2)
  end
  F.shot(tag)
  return hasControl()
end

F.run(function()
  if not F.boot(HUB[1]) then F.check("boot", false); F.finish(); return end
  local seen = {}
  for _, id in ipairs(select(2, F.keyItemSlot(0xFFFF))) do seen[id] = true end

  F.check("johto: the first crossing goes to Johto", crossGate({ { 16, 4 }, { 16, 3 } }, "johto"))
  F.check("johto: landed in New Bark", awaitGroup(76, "johto_land"), where())
  drain()
  for _, id in ipairs(select(2, F.keyItemSlot(0xFFFF))) do if not seen[id] then hubPass = id end end
  F.check("johto: the first crossing gives the Hub Pass", hubPass ~= nil, where())
  F.L("  landed at " .. where() .. " newbark=" .. getVar(VAR_NEWBARK_TOWN_STATE))
  F.shot("johto_landed")
  for _ = 1, 10 do
    local x0, y0 = F.pos()
    F.press("Right", 20); F.idle(40)
    local x1, y1 = F.pos()
    if x1 ~= x0 or y1 ~= y0 then break end
  end
  local bx, by = F.pos()
  F.check("johto: got out of bed and walked to the wall clock",
    F.route({ { bx, 4 }, { 9, 4 }, { 9, 3 } }, "clock_walk"), where())
  -- The wall clock's "Is this the correct time?" opens on NO, so confirm with Up and A.
  for _ = 1, 300 do
    if getVar(VAR_NEWBARK_TOWN_STATE) >= 1 and hasControl() then break end
    if F.reportCrash("clock") then break end
    if F.ow() then F.press("A", 2); F.idle(14)
    else F.press("A", 2); F.idle(40); F.press("Up", 2); F.idle(20) end
  end
  F.check("johto: the clock scene ran", getVar(VAR_NEWBARK_TOWN_STATE) >= 1, where())
  local x, y = F.pos()
  F.route({ { 9, y }, { 9, 3 } }, "stairs_walk")
  for _, dir in ipairs({ "Up", "Left", "Right", "Up", "Left" }) do
    if mapIs(HOUSE_1F) then break end
    F.press(dir, 20); F.idle(60)
  end
  F.check("johto: went downstairs", awaitMap(HOUSE_1F, "downstairs"), where())
  F.press("Down", 20)
  F.L("  downstairs at " .. where() .. " newbark=" .. getVar(VAR_NEWBARK_TOWN_STATE))
  for _ = 1, 600 do
    if getVar(VAR_NEWBARK_TOWN_STATE) >= 2 and hasControl() then break end
    if F.reportCrash("mom") then break end
    F.press("A", 2); F.idle(14)
  end
  F.shot("johto_mom")
  F.check("mom: the PokeGear scene ran", getVar(VAR_NEWBARK_TOWN_STATE) >= 2,
    where() .. " newbark=" .. getVar(VAR_NEWBARK_TOWN_STATE))
  F.check("mom: the PokeGear works (the shared PokeNav device)", flagGet(FLAG_SYS_POKENAV_GET))
  F.check("mom: the PokeGear leaves Devon's PokeNav gift unrecorded", not flagGet(FLAG_RECEIVED_POKENAV))

  -- Hoenn after the first badge, before Peeko's rescue: Mr. Briney is away from his cottage
  -- (FLAG_HIDE_BRINEYS_HOUSE_MR_BRINEY is set at new game and stays set until the rescue).
  flagSet(FLAG_BADGE01_GET)
  createMon(25, 30)
  F.check("hoenn: Briney is away from his cottage", flagGet(FLAG_HIDE_BRINEYS_HOUSE_MR_BRINEY))
  F.check("hoenn: warped into the Rustboro Pokemon Center", warp(RUSTBORO_CENTER, 0, "rustboro_center"), where())
  drain()
  F.L("  after the Center: VAR_BRINEY_LOCATION=" .. getVar(VAR_BRINEY_LOCATION))
  F.check("hoenn: a Center visit before the PokeNav records no shore for Briney", getVar(VAR_BRINEY_LOCATION) == 0,
    "briney=" .. getVar(VAR_BRINEY_LOCATION))
  F.check("hoenn: Hub Pass out of Hoenn", useHubPass("hoenn_out"), where())
  drain()
  F.check("hoenn: Hoenn gate accepted", crossGate({ { 16, 4 }, { 21, 4 }, { 21, 3 } }, "hoenn_gate"))
  -- The first prompt is the team choice: keep the current party (row 1).
  local menus = 0
  for _ = 1, 400 do
    if F.grp() ~= HUB[1] and hasControl() then break end
    if scriptMenuActive() then menu(menus == 0 and 1 or 0, "hoenn_dest", 3); menus = menus + 1 end
    F.press("A", 2); F.idle(14)
  end
  drain()
  F.L("  back in Hoenn at " .. where())
  F.shot("hoenn_back")
  F.check("hoenn: back in Hoenn", F.grp() ~= HUB[1], where())
  F.check("hoenn: Briney is still away after the arrival", flagGet(FLAG_HIDE_BRINEYS_HOUSE_MR_BRINEY))
  F.check("cottage: warped into Briney's cottage", warp(BRINEYS_HOUSE, 0, "cottage"), where())
  F.idle(60)
  F.shot("cottage")
  local others = {}
  local px, py = F.pos()
  for _, o in ipairs(F.objdump()) do
    if o.x ~= px or o.y ~= py then others[#others + 1] = string.format("(%d,%d)", o.x, o.y) end
  end
  F.check("cottage: Briney and Peeko are not home before the rescue", #others == 0, table.concat(others, " "))
  F.finish()
end)
