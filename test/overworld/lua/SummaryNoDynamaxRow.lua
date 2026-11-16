-- Dynamax and Terastal are off in this Gen 1-3 game (B_FLAG_DYNAMAX_BATTLE 0) and nothing a player can reach
-- hands out a Dynamax Band, Dynamax Candy or Max Soup, so the SwSh summary's skills page must not
-- draw a "Dmax Lv." row. With SWSH_SUMMARY_SHOW_DYNAMAX_LEVEL off the page loads page_skills.bin,
-- whose row 11 starts with the Ability label (tiles 0x7B-0x7E), and the ability window moves up to
-- sit under the stats; page_skills_dynamax.bin puts the Dmax label (0x84-0x87) there instead.
-- Nothing hands out a Tera Orb either, so the info page must not draw a Tera type badge.
--
-- With real input the suite opens the skills page from the party (Start menu), from a PC box
-- (Withdraw mode, Summary), and in the Rocket HQ multi battle with Lance scrolls onto his Dragonite.
-- Each stop reads BG2's tilemap row 11 out of VRAM and checks the ability window's tilemap top.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/SummaryNoDynamaxRow.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SummaryNoDynamaxRow")

local MON = S.Pokemon.size
local ABILITY_LABEL = "07B 07C 07D 07E"
local ABILITY_WINDOW_BASE_BLOCK = 277
local ABILITY_WINDOW_TOP = 11
local PC_MENU_ROWS = 5

local function digits(n) n = n - 1; return n // 100, (n // 10) % 10, n % 10 end
local function inPartyMenu() return F.cb2() == (S.CB2_UpdatePartyMenu & ~1) end
local function inBattle() return F.cb2() == (S.BattleMainCB2 & ~1) end
local function ctrl(b) return F.r32(S.gBattlerControllerFuncs + b * 4) & ~1 end
local function actionMenu()
  for _, p in ipairs(S.ActionInputFunctions) do if ctrl(0) == (p & ~1) then return true end end
  return false
end

local function row11Label()
  local sbb = (F.r16(0x0400000C) >> 8) & 0x1F
  local base = 0x06000000 + sbb * 0x800
  local t = {}
  for c = 1, 4 do t[#t + 1] = string.format("%03X", F.r16(base + (11 * 32 + c) * 2) & 0x3FF) end
  return table.concat(t, " ")
end

local WINDOWS_MAX = 32
local function abilityWindowTop()
  for i = 0, WINDOWS_MAX - 1 do
    local w = S.gWindows + i * S.Window.stride
    if F.r8(w + S.Window.bg) ~= 0xFF and F.r16(w + S.Window.baseBlock) == ABILITY_WINDOW_BASE_BLOCK then
      return F.r8(w + S.Window.tilemapTop)
    end
  end
end

-- SetMonTypeIcons puts the Tera type badge at (124 + 16, 45 + 7) on the info page.
local TERA_BADGE = { x = 140, y = 52 }
local function spriteVisibleAt(pos)
  for i = 0, S.Sprite.count - 1 do
    local a = S.gSprites + i * S.Sprite.stride
    local flags = F.r16(a + S.Sprite.inUse)
    if flags & 1 ~= 0 and F.rs16(a + 0x20) == pos.x and F.rs16(a + 0x22) == pos.y and (flags & 4) == 0 then
      return true
    end
  end
  return false
end

local function checkInfo(tag)
  F.idle(30)
  F.shot(tag .. "_info")
  F.check(tag .. ": the info page shows no Tera type badge", not spriteVisibleAt(TERA_BADGE))
end

local function checkSkills(tag)
  F.idle(60)
  F.shot(tag)
  local label, top = row11Label(), abilityWindowTop()
  F.check(tag .. ": row 11 shows the Ability label, no Dmax Lv. row", label == ABILITY_LABEL, label)
  F.check(tag .. ": the ability window sits right under the stats", top == ABILITY_WINDOW_TOP, tostring(top))
end

local function giveMon(species, level)
  F.dbg(); F.sel(3); F.sel(1); F.idle(20); F.spin(digits(species)); F.idle(20); F.spin(digits(level)); F.idle(60); F.bOut(4)
end

local function clearParty()
  for off = 0, 6 * MON - 4, 4 do F.w32(S.gParties + off, 0) end
  F.w8(S.gPartiesCount, 0)
end

local function backToField()
  for _ = 1, 40 do
    if F.ow() and F.ensureFree() then return true end
    F.press("B", 2); F.idle(30)
  end
  return F.ow()
end

local function fromParty()
  F.press("Start", 2); F.idle(60)
  F.selectStartIcon(1)
  F.press("A", 2)
  for _ = 1, 200 do F.idle(3); if inPartyMenu() then break end end
  F.idle(60)
  F.press("A", 2); F.idle(40)
  F.press("A", 2)
  for _ = 1, 200 do F.idle(3); if not inPartyMenu() then break end end
  F.idle(90)
  checkInfo("party")
  F.press("Right", 2)
  checkSkills("party")
  F.check("party: back on the field", backToField())
end

local function fromBox()
  F.dbg(); F.sel(1); F.sel(1); F.sel(0); F.idle(200); F.bOut(4)
  F.w8(S.sMenu + 2, 0); F.w8(S.sMenu + S.Menu.maxCursorPos, 0)
  F.dbg(); F.idle(60); F.press("Down", 3); F.idle(16); F.press("A", 3); F.idle(60); F.press("A", 3); F.idle(60)
  for _ = 1, 200 do
    if F.ow() and F.rs8(S.sMenu + S.Menu.maxCursorPos) == PC_MENU_ROWS - 1 then break end
    F.press("A", 2); F.idle(18)
  end
  F.press("Down", 2); F.idle(12); F.press("Down", 2); F.idle(12)
  F.shot("pc_menu_withdraw")
  F.press("A", 2)
  for _ = 1, 300 do F.idle(2); if not F.ow() then break end end
  F.idle(120)
  F.press("A", 2); F.idle(40)
  F.press("Down", 2); F.idle(20)
  F.shot("box_slot_menu")
  F.press("A", 2); F.idle(150)
  checkInfo("box")
  F.press("Right", 2)
  checkSkills("box")
  F.check("box: back on the field", backToField())
end

local function fromMultiPartner()
  clearParty()
  for _, sp in ipairs({ 1, 4, 7 }) do giveMon(sp, 50) end
  F.check("multi: three Pokemon", F.r8(S.gPartiesCount) == 3, "n=" .. F.r8(S.gPartiesCount))
  if not F.check("multi: warp to Rocket HQ B2F", F.warpTo(0, 9, 2, 0, 1, 4, 0, 0, 0, 92, 14, "rocket_hq")) then return end
  for i = 0, 2 do F.w8(S.gSelectedOrderFromParty + i, i + 1) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, S.MahoganyHideout_B2F_EventScript_DoLanceMultiBattle)
  F.w8(S.sGlobalScriptContextStatus, 0)
  local ready = false
  for _ = 1, 3000 do
    if inBattle() and actionMenu() then ready = true; break end
    if F.reportCrash("intro") then break end
    F.press("A", 2); F.idle(10)
  end
  if not F.check("multi: the battle reached the action menu", ready) then return end
  F.idle(30)
  F.press("Down", 2); F.idle(20)
  F.press("A", 2)
  for _ = 1, 200 do F.idle(3); if inPartyMenu() then break end end
  F.idle(60)
  F.press("A", 2); F.idle(40)
  F.press("Down", 2); F.idle(20)
  F.press("A", 2)
  for _ = 1, 200 do F.idle(3); if not inPartyMenu() then break end end
  F.idle(90)
  checkInfo("multi_own")
  F.press("Right", 2)
  checkSkills("multi_own")
  for _ = 1, 3 do F.press("Down", 2); F.idle(70) end
  checkSkills("multi_partner")
end

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  clearParty()
  F.dbg(); F.idle(30); F.bOut(4)
  giveMon(6, 51)
  fromParty()
  fromBox()
  fromMultiPartner()
  F.check("no crash screen", not F.crashScreen())
  F.finish()
end)
