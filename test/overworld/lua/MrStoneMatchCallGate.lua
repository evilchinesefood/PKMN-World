-- Johto's PokeGear and Hoenn's PokeNav are one device here (Emerald's Match Call). Emerald lists
-- MR. STONE with no flag because he is the one who hands over the PokeNav, so a player who started
-- in Johto found Devon's president in the PokeGear the moment their mother gave it to them, talking
-- about Hoenn errands, and calling him set FLAG_ENABLE_MR_STONE_POKENAV. pokemonHnS hides him too.
--
-- Johto first: crosses the hub's Johto gate, gets out of bed, sets the clock and walks downstairs
-- for the mother's PokeGear scene, then opens Match Call from the Start menu with real input and
-- mashes A, Up and Down on the list. Oracle: the live Match Call list holds no MR. STONE, nothing
-- crashes, control returns, and FLAG_ENABLE_MR_STONE_POKENAV stays clear. Then the same player plays
-- Devon's 3F scene in Rustboro, and the list must show MR. STONE.
-- Hoenn first (restored from a fresh-boot savestate): plays Devon's 3F scene and the Rustboro
-- scientist's Match Call tutorial (pick POKeNAV, call MR. STONE) with real input. Oracle: the
-- tutorial call lands on MR. STONE's first line, then the list opens with MR. STONE on top and his
-- next call is the letter errand.
--
-- Knobs: PW_SEED=<n> reseeds the list mash.
-- Run via test/overworld/mgba-run.sh test/overworld/lua/MrStoneMatchCallGate.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "MrStoneMatchCallGate")

local HUB = { 100, 0 }
local HOUSE_1F = { 76, 3 }
local NEWBARK = { 75, 0 }
local ELM_LAB = { 76, 0 }
local DEVON_3F = { 11, 2 }
local RUSTBORO = { 0, 3 }
local VAR_NEWBARK_TOWN_STATE = 0xA080
local VAR_DEVON_CORP_3F_STATE = 0x408F
local FLAG_SYS_POKENAV_GET = 0x94A
local FLAG_ADDED_MATCH_CALL_TO_POKENAV = 0x130
local FLAG_RECEIVED_POKENAV = 0xBC
local FLAG_ENABLE_MR_STONE_POKENAV = 0x158
local FLAG_RETURNED_DEVON_GOODS = 0x90
local FLAG_BADGE01_GET = 0x94F
local FLAG_ENABLE_PROF_BIRCH_MATCH_CALL = 0x119
local FLAG_JOHTO_STARTER_CHOSEN = 0x6000 + 0x38
local FLAG_SHOWN_ELM_TOGEPI = 0x6000 + 0x23
local VAR_NEWBARKTOWN_LABSTATE = 0xA081
local MC_HEADER_MR_STONE = 0
local USM_ICO_POKENAV = 3
local SUBSTRUCT_MAIN_MENU_HANDLER = 1
local SUBSTRUCT_MATCH_CALL_MAIN = 5
local MENU_TYPE_UNLOCK_MC, MENU_TYPE_UNLOCK_MC_RIBBONS = 1, 2
local MC_HEADER_PROF_BIRCH = 1
local MC = { numRegistered = 10, initFinished = 16, callback = 24, entries = 28, entrySize = 8, special = 0, headerId = 4 }
local CONTEXT_RUNNING = 0

local seed = tonumber(os.getenv("PW_SEED") or "") or 1
local rng = seed
local function rand(n) rng = (rng * 1103515245 + 12345) % 2147483648; return (rng >> 16) % n end

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
local function flagClear(id) local a, b = flagAddr(id); F.w8(a, F.r8(a) & ~(1 << b) & 0xFF) end
local function setVar(id, v) F.w16(varAddr(id), v) end
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
local function warpXY(m, x, y)
  runScript({ 0x39, m[1], m[2], 0xFF, x & 0xFF, x >> 8, y & 0xFF, y >> 8, 0x27, 0x02 })
  for _ = 1, 600 do
    F.idle(4)
    local px, py = F.pos()
    if mapIs(m) and px == x and py == y and hasControl() then F.idle(30); return true end
  end
  return false
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

local function decode(addr, max)
  local out = {}
  for i = 0, (max or 300) - 1 do
    local c = F.r8(addr + i)
    if c == 0xFF then break end
    if c == 0x00 or c == 0xFE or c == 0xFA or c == 0xFB then out[#out + 1] = " "
    elseif c >= 0xBB and c <= 0xD4 then out[#out + 1] = string.char(65 + c - 0xBB)
    elseif c >= 0xD5 and c <= 0xEE then out[#out + 1] = string.char(97 + c - 0xD5)
    elseif c >= 0xA1 and c <= 0xAA then out[#out + 1] = string.char(48 + c - 0xA1)
    elseif c == 0xAB then out[#out + 1] = "!"
    elseif c == 0xAD then out[#out + 1] = "."
    elseif c == 0xB4 then out[#out + 1] = "'"
    elseif c == 0xB8 then out[#out + 1] = ","
    elseif c == 0xF0 then out[#out + 1] = ":"
    else out[#out + 1] = "?" end
  end
  return table.concat(out)
end

local function matchCallMenu()
  local res = F.r32(S.gPokenavResources)
  if res < 0x02000000 or res >= 0x02040000 then return nil end
  local p = F.r32(res + 16 + SUBSTRUCT_MATCH_CALL_MAIN * 4)
  if p < 0x02000000 or p >= 0x02040000 then return nil end
  return p
end
local function listReady()
  local p = matchCallMenu()
  return p and F.r32(p + MC.initFinished) ~= 0 and (F.r32(p + MC.callback) & ~1) == (S.CB2_HandleMatchCallInput & ~1)
end
local function listHeaders()
  local p = matchCallMenu()
  local rows = {}
  for i = 0, F.r16(p + MC.numRegistered) - 1 do
    local e = p + MC.entries + i * MC.entrySize
    rows[#rows + 1] = { header = F.r16(e + MC.headerId), special = F.r8(e + MC.special) ~= 0 }
  end
  return rows
end
local function hasStone(rows)
  for _, r in ipairs(rows) do if r.special and r.header == MC_HEADER_MR_STONE then return true end end
  return false
end
local function describe(rows)
  local t = {}
  for _, r in ipairs(rows) do t[#t + 1] = (r.special and "mc" or "tr") .. r.header end
  return #rows .. " [" .. table.concat(t, " ") .. "]"
end

local function mainMenuType()
  local res = F.r32(S.gPokenavResources)
  if res < 0x02000000 or res >= 0x02040000 then return -1 end
  local p = F.r32(res + 16 + SUBSTRUCT_MAIN_MENU_HANDLER * 4)
  if p < 0x02000000 or p >= 0x02040000 then return -1 end
  return F.r16(p)
end

-- Opens the PokeNav from the Start menu; returns whether its main menu offers Match Call.
local function openPokenav(tag)
  drain()
  local offered = false
  for _ = 1, 3 do
    F.press("Start", 2); F.idle(60)
    offered = F.selectStartIcon(USM_ICO_POKENAV)
    if offered then break end
    for _ = 1, 4 do F.press("B", 2); F.idle(30) end
  end
  if not F.check(tag .. ": the Start menu offers the PokeNav", offered) then return false end
  F.press("A", 2); F.idle(240)
  local mt = mainMenuType()
  F.L(string.format("  %s: main menu type %d", tag, mt))
  F.shot(tag .. "_menu")
  return mt == MENU_TYPE_UNLOCK_MC or mt == MENU_TYPE_UNLOCK_MC_RIBBONS
end

local function openMatchCall(tag)
  local hasMatchCall = openPokenav(tag)
  if not F.check(tag .. ": the PokeNav offers Match Call", hasMatchCall) then return false end
  F.press("Down", 2); F.idle(20); F.press("Down", 2); F.idle(20)
  F.press("A", 2)
  for _ = 1, 300 do if listReady() then break end F.idle(1) end
  F.idle(60)
  F.shot(tag .. "_list")
  return F.check(tag .. ": the Match Call list opened", listReady(), where())
end

-- Calls the first contact with real input and returns what it said.
local function callFirst(tag)
  F.w8(S.gStringVar4, 0xFF)
  F.press("A", 2); F.idle(30)
  F.press("A", 2)
  for t = 1, 900 do
    if F.r8(S.gStringVar4) ~= 0xFF then break end
    if t % 40 == 0 then F.press("A", 2) else F.idle(1) end
  end
  local text = decode(S.gStringVar4)
  F.idle(90)
  F.shot(tag .. "_call")
  for _ = 1, 40 do
    if listReady() then break end
    F.press("A", 2); F.idle(40)
  end
  F.L("  " .. tag .. " call: " .. text)
  F.check(tag .. ": the call ends back on the list", listReady())
  return text
end

local function closePokenav(tag)
  for _ = 1, 10 do if F.ow() then break end F.press("B", 2); F.idle(90) end
  for _ = 1, 10 do if F.ensureFree() then break end F.press("B", 2); F.idle(20) end
  F.check(tag .. ": back on the field and walkable", F.ow() and F.ensureFree(), where())
end

local function johtoPokegear()
  F.check("johto: the first crossing goes to Johto", crossGate({ { 16, 4 }, { 16, 3 } }, "johto"))
  F.check("johto: landed in New Bark", awaitGroup(76, "johto_land"), where())
  drain()
  for _ = 1, 10 do
    local x0, y0 = F.pos()
    F.press("Right", 20); F.idle(40)
    local x1, y1 = F.pos()
    if x1 ~= x0 or y1 ~= y0 then break end
  end
  local bx = F.pos()
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
  local _, y = F.pos()
  F.route({ { 9, y }, { 9, 3 } }, "stairs_walk")
  for _, dir in ipairs({ "Up", "Left", "Right", "Up", "Left" }) do
    if mapIs(HOUSE_1F) then break end
    F.press(dir, 20); F.idle(60)
  end
  F.check("johto: went downstairs", awaitMap(HOUSE_1F, "downstairs"), where())
  F.press("Down", 20)
  for _ = 1, 600 do
    if getVar(VAR_NEWBARK_TOWN_STATE) >= 2 and hasControl() then break end
    if F.reportCrash("mom") then break end
    F.press("A", 2); F.idle(14)
  end
  F.shot("johto_mom")
  F.check("mom: the PokeGear scene ran", getVar(VAR_NEWBARK_TOWN_STATE) >= 2,
    where() .. " newbark=" .. getVar(VAR_NEWBARK_TOWN_STATE))
  F.check("mom: the PokeGear has Match Call", flagGet(FLAG_SYS_POKENAV_GET) and flagGet(FLAG_ADDED_MATCH_CALL_TO_POKENAV))
end

-- Devon's 3F scene after the Devon Goods came back, played by pressing A through it.
local function devonScene(tag)
  flagSet(FLAG_BADGE01_GET)
  flagSet(FLAG_RETURNED_DEVON_GOODS)
  createMon(25, 30)
  F.check(tag .. ": warped onto Devon's 3F", warp(DEVON_3F, 0, tag .. "_devon"), where())
  for _ = 1, 600 do
    if getVar(VAR_DEVON_CORP_3F_STATE) ~= 0 and hasControl() then break end
    if F.reportCrash(tag .. "_devon") then break end
    F.press("A", 2); F.idle(14)
  end
  F.shot(tag .. "_devon_done")
  F.check(tag .. ": Mr. Stone gave the PokeNav", flagGet(FLAG_RECEIVED_POKENAV) and getVar(VAR_DEVON_CORP_3F_STATE) == 1)
  F.check(tag .. ": control returned after Devon's scene", drain(), where())
end

-- Leaving Devon puts the player at its door with the scientist's Match Call tutorial on the next frame.
local function scientistTutorial(tag)
  F.check(tag .. ": out of Devon's door", warp(RUSTBORO, 5, tag .. "_rustboro"), where())
  F.check(tag .. ": the tutorial asks for the POKeNAV", menu(3, tag .. "_pick_pokenav", 120))
  F.idle(240)
  F.press("Down", 2); F.idle(20); F.press("Down", 2); F.idle(20)
  F.press("A", 2)
  for _ = 1, 300 do if listReady() then break end F.idle(1) end
  F.idle(60)
  F.shot(tag .. "_tutorial_list")
  local rows = listReady() and listHeaders() or {}
  F.L("  " .. tag .. " tutorial list: " .. describe(rows))
  F.check(tag .. ": the tutorial list holds MR. STONE", hasStone(rows), describe(rows))
  F.w8(S.gStringVar4, 0xFF)
  F.press("A", 2); F.idle(30)
  F.press("A", 2)
  for t = 1, 900 do
    if F.r8(S.gStringVar4) ~= 0xFF then break end
    if t % 40 == 0 then F.press("A", 2) else F.idle(1) end
  end
  local text = decode(S.gStringVar4)
  F.L("  " .. tag .. " tutorial call: " .. text)
  F.check(tag .. ": the tutorial call is MR. STONE's first line",
    text:find("must be working properly", 1, true) ~= nil and flagGet(FLAG_ENABLE_MR_STONE_POKENAV), text)
  F.idle(90)
  for _ = 1, 40 do
    if listReady() then break end
    F.press("A", 2); F.idle(40)
  end
  F.shot(tag .. "_tutorial_called")
  for _ = 1, 10 do
    if F.ow() then break end
    F.press("B", 2); F.idle(90)
  end
  for _ = 1, 60 do
    if hasControl() then break end
    F.press("A", 2); F.idle(25)
  end
  F.shot(tag .. "_tutorial_done")
  F.check(tag .. ": control returned after the tutorial", drain(), where())
end

F.run(function()
  if not F.boot(HUB[1]) then F.check("boot", false); F.finish(); return end
  F.L("seed " .. seed)
  local fresh = F.out .. "MrStoneMatchCallGate_fresh.ss"
  client.savestate(fresh)

  johtoPokegear()
  -- Calls can't be made indoors, so step out of the front door first.
  F.check("johto: out of the front door", warp(NEWBARK, 1, "newbark") and drain(), where())
  local offered = openPokenav("johto")
  local rows = {}
  if offered then
    F.press("Down", 2); F.idle(20); F.press("Down", 2); F.idle(20)
    F.press("A", 2)
    for _ = 1, 300 do if listReady() then break end F.idle(1) end
    F.idle(60)
    F.shot("johto_list")
    if listReady() then rows = listHeaders() end
    F.L("  johto list: " .. describe(rows))
    for _ = 1, 24 do
      local k = rand(4)
      F.press(k == 0 and "Up" or k == 1 and "Down" or "A", 2); F.idle(30)
      if F.reportCrash("johto_mash") then break end
    end
    F.shot("johto_mash")
  end
  F.check("johto: MR. STONE is not in the PokeGear", not hasStone(rows), describe(rows))
  F.check("johto: Match Call is offered only with someone to call", not offered or #rows > 0, describe(rows))
  F.check("johto: calling from the PokeGear never reaches MR. STONE", not flagGet(FLAG_ENABLE_MR_STONE_POKENAV))
  closePokenav("johto")

  -- Elm's first directions after the starter register his number (PROF. BIRCH's contact).
  setVar(VAR_NEWBARKTOWN_LABSTATE, 1)
  flagSet(FLAG_JOHTO_STARTER_CHOSEN)
  flagClear(FLAG_SHOWN_ELM_TOGEPI)
  F.check("elm: in front of Elm after the starter", warpXY(ELM_LAB, 6, 4), where())
  F.check("elm: the directions hand control back", talk("Up", "elm_directions"), where())
  F.check("elm: Elm registered his number", flagGet(FLAG_ENABLE_PROF_BIRCH_MATCH_CALL))
  F.check("elm: out of the front door", warp(NEWBARK, 1, "newbark_elm") and drain(), where())
  if openMatchCall("elm") then
    rows = listHeaders()
    F.L("  elm list: " .. describe(rows))
    F.check("elm: Elm's contact heads the list", rows[1] and rows[1].special and rows[1].header == MC_HEADER_PROF_BIRCH, describe(rows))
    F.check("elm: MR. STONE is still not listed", not hasStone(rows), describe(rows))
    local text = callFirst("elm")
    F.check("elm: Elm's contact answers", text:find("PROF. BIRCH:", 1, true) == 1, text)
    closePokenav("elm")
  end
  F.check("elm: MR. STONE was never called", not flagGet(FLAG_ENABLE_MR_STONE_POKENAV))

  devonScene("johto_devon")
  if openMatchCall("johto_devon") then
    local rows = listHeaders()
    F.L("  after Devon: " .. describe(rows))
    F.check("johto_devon: MR. STONE is listed once Devon gave the PokeNav", hasStone(rows), describe(rows))
    closePokenav("johto_devon")
  end

  client.loadstate(fresh)
  F.idle(30)
  F.check("hoenn: back to a fresh game", not flagGet(FLAG_SYS_POKENAV_GET) and mapIs(HUB), where())
  devonScene("hoenn")
  F.check("hoenn: no Match Call before the scientist adds it", not flagGet(FLAG_ADDED_MATCH_CALL_TO_POKENAV))
  scientistTutorial("hoenn")
  if openMatchCall("hoenn") then
    local rows = listHeaders()
    F.L("  hoenn list: " .. describe(rows))
    F.check("hoenn: MR. STONE heads the list", rows[1] and rows[1].special and rows[1].header == MC_HEADER_MR_STONE, describe(rows))
    local text = callFirst("hoenn")
    F.check("hoenn: MR. STONE answers with the letter errand",
      text:find("MR. STONE:", 1, true) == 1 and text:find("deliver my letter", 1, true) ~= nil, text)
    closePokenav("hoenn")
  end
  F.finish()
end)
