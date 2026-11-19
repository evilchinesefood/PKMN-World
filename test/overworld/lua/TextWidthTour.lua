-- Text measurement tour: one fixed-input pass over the screens that centre, right-align or size
-- windows with GetStringWidth, screenshotting each once it settles.
--
-- Every input is a fixed frame count, so two ROMs that differ only in text code produce screenshot
-- pairs with the same names on the same frames. test/overworld/TextWidthDiff.py pixel-diffs a pair
-- of runs and reports every differing image with the bounding box of the change.
--
-- The suite's own verdict covers what it can judge alone: each scene opens, comes back to the field
-- and never raises a crash screen, battles start as the type they meant to, and every BW action-box
-- label is centred in its button.
--
-- Run: test/overworld/mgba-run.sh test/overworld/lua/TextWidthTour.lua <rom> --timeout 3000
-- PW_TWT_ONLY=<text> runs only the scenes whose tag contains <text>.

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "TextWidthTour")

local ONLY = os.getenv and os.getenv("PW_TWT_ONLY") or nil
local CONTEXT_RUNNING = 0
local TEXT_SPEED_INSTANT = 3
local SYS = 0x948
local FLAG_SYS_POKEMON_GET, FLAG_SYS_POKEDEX_GET, FLAG_SYS_POKENAV_GET = SYS, SYS + 1, SYS + 2
local FLAG_SYS_DEXNAV_GET = 0x948 + 0xBE
local FLAG_SYS_GAME_CLEAR = SYS + 0x2B
local FLAG_SYS_SAFARI_MODE = SYS + 0x2C
local FLAG_SYS_FRONTIER_PASS = 0x9BA
local ICON_POKEDEX, ICON_PARTY, ICON_BAG, ICON_TRAINER, ICON_STORY = 0, 1, 2, 5, 6
local B_DOUBLE, B_SAFARI = 1 << 0, 1 << 7
local B_OUTCOME_RAN = 4
local SPECIES_PIKACHU, SPECIES_GYARADOS, SPECIES_KYOGRE = 25, 130, 382
local MOVE_THUNDERBOLT, MOVE_SURF, MOVE_QUICK_ATTACK, MOVE_PROTECT = 85, 57, 98, 182
local ITEMS = {
  { 28, 99 }, { 29, 7 }, { 32, 12 }, { 116, 3 }, { 120, 1 }, { 102, 42 },  -- Items and Medicine
  { 1, 99 }, { 3, 5 }, { 4, 1 },                                          -- Poke Balls
  { 582, 1 }, { 583, 1 },                                                 -- TMs
  { 515, 3 }, { 520, 25 }, { 523, 999 },                                  -- Berries
  { 706, 1 }, { 709, 1 }, { 713, 1 },                                     -- Key Items
}

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function setFlag(id, on)
  local a = F.sb1() + S.SaveBlock1.flags + (id // 8)
  if on == false then F.w8(a, F.r8(a) & ~(1 << (id % 8)) & 0xFF) else F.w8(a, F.r8(a) | (1 << (id % 8))) end
end
local function optWord() return F.r16(F.sb2() + S.SaveBlock2.optionsU16) end
local function setMoney(v) F.w32(F.sb1() + S.SaveBlock1.money, v ~ F.r32(F.sb2() + S.SaveBlock2.encryptionKey)) end

local function snap(tag)
  client.screenshot(F.out .. "TextWidthTour_" .. tag .. ".png")
  F.L("  snap " .. tag)
end

-- ---- scripts from EWRAM -----------------------------------------------------------------------
local SCRIPT_BUF = S.gStringVar4 + 960
local TEXT_BUF = S.gStringVar2
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
end
local function native(t, addr) t[#t + 1] = 0x23; le32(t, addr | 1) end
local function callScript(addr) local b = { 0x04 }; le32(b, addr); b[#b + 1] = 0x02; runScript(b) end
local function warp(g, n, x, y, enter)
  local b = {}
  if enter then native(b, enter) end
  b[#b + 1] = 0x39; b[#b + 1] = g; b[#b + 1] = n; b[#b + 1] = 0xFF; le16(b, x); le16(b, y); b[#b + 1] = 0x27; b[#b + 1] = 0x02
  runScript(b)
  for _ = 1, 400 do
    F.idle(4)
    if F.reportCrash("warp") then return false end
    if F.grp() == g and F.mapn() == n and F.ow() then
      for _ = 1, 300 do
        if hasControl() then F.idle(30); return true end
        F.press("B", 2); F.idle(10)
      end
    end
  end
  F.L(string.format("  warp to %d.%d failed: at %d.%d cb2=%08X", g, n, F.grp(), F.mapn(), F.cb2()))
  return false
end
local function addItem(id, qty)
  local b = { 0x44 }; le16(b, id); le16(b, qty); b[#b + 1] = 0x02
  runScript(b); F.idle(10)
end

-- Pokemon text encoding for the few characters the keypad message uses.
local ENC = { [" "] = 0x00, ["!"] = 0xAB, ["."] = 0xAD, [","] = 0xB8, ["\n"] = 0xFE }
local function encode(s)
  local out = {}
  local i = 1
  while i <= #s do
    local key = s:match("^{(%u+)}", i)
    if key then
      local pad = ({ A = 0, B = 1, L = 2, R = 3, START = 4, SELECT = 5 })[key]
      out[#out + 1] = 0xF8; out[#out + 1] = pad
      i = i + #key + 2
    else
      local c = s:sub(i, i)
      if ENC[c] then out[#out + 1] = ENC[c]
      elseif c:match("%u") then out[#out + 1] = 0xBB + c:byte() - 65
      elseif c:match("%l") then out[#out + 1] = 0xD5 + c:byte() - 97
      end
      i = i + 1
    end
  end
  out[#out + 1] = 0xFF
  return out
end

-- ---- leaving whatever is open -------------------------------------------------------------------
local function toField(tag)
  for _ = 1, 80 do
    if hasControl() then F.idle(20); return true end
    if F.reportCrash(tag .. "_leave") then return false end
    F.press("B", 2); F.idle(24)
  end
  F.L(string.format("  %s: still busy cb2=%08X lock=%d ctx=%d", tag, F.cb2(), F.r8(S.sLockFieldControls),
    F.r8(S.sGlobalScriptContextStatus)))
  return hasControl()
end

local function scene(tag, body)
  if ONLY and not tag:find(ONLY, 1, true) then return end
  F.L("== " .. tag)
  if not hasControl() then toField(tag .. "_before") end
  local ok, err = pcall(body)
  if not ok then F.check(tag .. ": scene ran", false, tostring(err)) end
  F.check(tag .. ": no crash screen", not F.reportCrash(tag))
  F.check(tag .. ": control returns to the field", toField(tag))
end

local function key(k, wait) F.press(k, 2); F.idle(wait or 40) end

local function openIcon(icon)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(icon) then return false end
  F.press("A", 2); F.idle(150)
  return not F.ow()
end

-- ---- battles ------------------------------------------------------------------------------------
local function pokeChar(b)
  if b == 0x00 then return " " end
  if b >= 0xBB and b <= 0xD4 then return string.char(65 + (b - 0xBB)) end
  if b >= 0xD5 and b <= 0xEE then return string.char(65 + (b - 0xD5)) end
  return ""
end
local function battleText()
  local t = {}
  for i = 0, 80 do
    local b = F.r8(S.gDisplayedStringBattle + i)
    if b == 0xFF then break end
    t[#t + 1] = pokeChar(b)
  end
  return table.concat(t)
end

-- Screenshot every tenth frame of the intro (send-outs, healthboxes sliding in, ability pop-ups)
-- until the action box asks for a choice.
local function battleIntro(tag)
  for _ = 1, 400 do if F.cb2() == S.BattleMainCB2 then break end F.idle(2) end
  if not F.check(tag .. ": battle starts", F.cb2() == S.BattleMainCB2, string.format("cb2=%08X", F.cb2())) then return false end
  for f = 0, 1500, 10 do
    if battleText():find("WHAT WILL", 1, true) then break end
    if f % 30 == 0 then snap(string.format("%s_intro_%04d", tag, f)) end
    if f % 60 == 50 then F.press("A", 2); F.idle(8) else F.idle(10) end
  end
  F.idle(30)
  return battleText():find("WHAT WILL", 1, true) ~= nil
end

-- BattleUI_PopulateActionBox blits the 17x6-tile button art into B_WIN_ACTION_MENU, then centres
-- each label in a 48 px cell at x = 14 or 80, rows 7 or 31. A label's pixels are wherever the
-- window buffer no longer matches the art; its left and right margins inside the cell should agree
-- to within the one pixel an odd width leaves over.
local B_WIN_ACTION_MENU, ABOX_W, LABEL_CELL = 2, 17, 48
local function actionLabelMargins()
  local w = S.gWindows + B_WIN_ACTION_MENU * S.Window.stride
  local data = F.r32(w + S.Window.tileData)
  local function px(base, x, y)
    local tile = (y // 8) * ABOX_W + (x // 8)
    local b = F.r8(base + tile * 32 + (y % 8) * 4 + (x % 8) // 2)
    return (x % 2 == 0) and (b & 0xF) or (b >> 4)
  end
  local out = {}
  for i = 0, 3 do
    local x0 = (i & 1) ~= 0 and 80 or 14
    local y0 = (i & 2) ~= 0 and 31 or 7
    local lo, hi = nil, nil
    for x = x0 - 6, math.min(x0 + LABEL_CELL + 5, ABOX_W * 8 - 1) do
      for y = y0, y0 + 15 do
        if px(data, x, y) ~= px(S.sBWBattleUI_ActionBox, x, y) then
          lo = lo or x; hi = x
          break
        end
      end
    end
    out[#out + 1] = lo and { left = lo - x0, right = x0 + LABEL_CELL - 1 - hi } or { left = -99, right = -99 }
  end
  return out
end

local function checkActionLabels(tag)
  for i, m in ipairs(actionLabelMargins()) do
    F.check(string.format("%s: action label %d is centred in its button", tag, i), m.left >= 0 and m.right >= 0
      and math.abs(m.left - m.right) <= 1, string.format("left=%d right=%d", m.left, m.right))
  end
end

local function battleMenus(tag)
  snap(tag .. "_actions")
  key("A", 50); snap(tag .. "_moves")
  key("Right", 20); snap(tag .. "_moves_right")
  key("Down", 20); snap(tag .. "_moves_down")
  key("B", 50); snap(tag .. "_back_to_actions")
end

local function endBattle(tag)
  F.w8(S.gBattleOutcome, B_OUTCOME_RAN)
  for i = 1, 300 do
    if F.ow() then break end
    if i % 3 == 0 then F.press("A", 2) end
    F.idle(10)
  end
  return F.check(tag .. ": back on the field", F.ow(), string.format("cb2=%08X", F.cb2()))
end

local function wild(species, level, species2, level2)
  local b = { 0xB6 }; le16(b, species); b[#b + 1] = level; le16(b, 0); le16(b, species2 or 0); b[#b + 1] = level2 or 0; le16(b, 0)
  return b
end

-- ---- setup --------------------------------------------------------------------------------------
local function giveParty()
  F.dbg(); F.idle(40); F.sel(2); F.idle(40)
  for _ = 1, 9 do F.press("Down", 2); F.idle(12) end
  F.press("A", 2); F.idle(180); F.bOut(6); F.idle(60)
end
local function giveMon(species, level, moves)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(b, species); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for k = 1, 4 do le16(b, moves[k] or 0) end
  b[#b + 1] = 0x02
  runScript(b); F.idle(30)
end
local function allDexFlags()
  F.dbg(); F.idle(40); F.sel(7); F.idle(40)
  F.sel(2); F.idle(120); F.bOut(6); F.idle(60)
end

local function optionTask()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    if F.r8(a + S.Task.isActive) ~= 0 and (F.r32(a + S.Task.func) & ~1) == S.Task_OptionMenuProcessInput then return a end
  end
end

local function frontEnd()
  for i = 1, 6000 do
    if F.cb2() == S.MainCB2_WorldTitleScreen then break end
    if F.cb2() == S.MainCB2_Intro and i % 90 == 0 then F.press("Start", 2) end
    F.idle(1)
  end
  F.check("title screen reached", F.cb2() == S.MainCB2_WorldTitleScreen, string.format("cb2=%08X", F.cb2()))
  F.idle(150); snap("title")
  for _ = 1, 300 do
    if F.cb2() == S.CB2_MainMenu then break end
    F.press("Start", 2); F.idle(20)
  end
  F.check("main menu reached", F.cb2() == S.CB2_MainMenu, string.format("cb2=%08X", F.cb2()))
  F.idle(60); snap("main_menu")
  key("Down", 20); snap("main_menu_options_row")
  key("A", 10)
  for _ = 1, 150 do if optionTask() then break end F.idle(4) end
  F.check("main menu Options opens", optionTask() ~= nil)
  F.idle(40); snap("main_options_top")
  for i = 1, 12 do key("Down", 12); if i % 4 == 0 then snap("main_options_row" .. i) end end
  key("B", 10)
  for _ = 1, 200 do if F.cb2() == S.CB2_MainMenu and not optionTask() then break end F.idle(2) end
  F.idle(60)
  key("Up", 20)
end

F.run(function()
  if not ONLY or ("front end"):find(ONLY, 1, true) then frontEnd() end
  if not F.boot(100) then F.finish(); return end
  F.w16(F.sb2() + S.SaveBlock2.optionsU16, (optWord() & ~7) | TEXT_SPEED_INSTANT)
  giveParty()
  giveMon(SPECIES_PIKACHU, 50, { MOVE_THUNDERBOLT, MOVE_QUICK_ATTACK, MOVE_PROTECT, MOVE_SURF })
  giveMon(SPECIES_GYARADOS, 50, { MOVE_SURF, MOVE_PROTECT })
  F.check("party of three", F.r8(S.gPartiesCount) >= 3, "party=" .. F.r8(S.gPartiesCount))
  allDexFlags()
  for _, f in ipairs({ FLAG_SYS_POKEMON_GET, FLAG_SYS_POKEDEX_GET, FLAG_SYS_DEXNAV_GET, FLAG_SYS_POKENAV_GET, FLAG_SYS_GAME_CLEAR }) do setFlag(f) end
  for _, it in ipairs(ITEMS) do addItem(it[1], it[2]) end
  setMoney(999999)
  F.ensureFree()

  scene("graphical start menu", function()
    F.press("Start", 2); F.idle(60)
    snap("usm_open")
    for i = 1, 8 do key("Right", 24); snap("usm_right" .. i) end
  end)

  scene("classic start menu", function()
    local b = {}; native(b, S.ShowStartMenu); b[#b + 1] = 0x02
    runScript(b); F.idle(60)
    snap("classic_start")
    -- The acquired DexNav adds a row to the classic menu before Options.
    for i = 1, 8 do key("Down", 16); snap("classic_start_row" .. i) end
    key("A", 10)
    for _ = 1, 150 do if optionTask() then break end F.idle(4) end
    F.check("Options opens from the classic Start menu", optionTask() ~= nil)
    F.idle(40); snap("options_top")
    for i = 1, 12 do key("Down", 12); if i % 4 == 0 then snap("options_row" .. i) end end
  end)

  scene("bag pockets", function()
    F.check("bag opens", openIcon(ICON_BAG))
    snap("bag_pocket0")
    for p = 1, 5 do key("Right", 50); snap("bag_pocket" .. p) end
    for i = 1, 3 do key("Down", 20) end
    snap("bag_down3")
  end)

  scene("party and summary", function()
    F.check("party menu opens", openIcon(ICON_PARTY))
    snap("party")
    key("A", 40); snap("party_actions")
    key("A", 150); snap("summary_page0")
    for p = 1, 5 do key("Right", 50); snap("summary_page" .. p) end
    key("Down", 120); snap("summary_next_mon")
    key("Down", 120); snap("summary_third_mon")
  end)

  scene("pokedex", function()
    F.check("pokedex opens", openIcon(ICON_POKEDEX))
    F.idle(60); snap("dex_list")
    for i = 1, 4 do key("Down", 16) end
    snap("dex_list_down4")
    key("A", 150); snap("dex_entry")
    for p = 1, 4 do key("Right", 90); snap("dex_page" .. p) end
  end)

  scene("trainer card", function()
    F.check("trainer card opens", openIcon(ICON_TRAINER))
    snap("tcard_front")
    key("A", 120); snap("tcard_back")
  end)

  scene("story", function()
    F.check("story opens", openIcon(ICON_STORY))
    F.idle(60); snap("story")
    for i = 1, 3 do key("Down", 30); snap("story_down" .. i) end
    key("A", 90); snap("story_detail")
    key("Right", 60); snap("story_right")
  end)

  scene("pc boxes", function()
    callScript(S.EventScript_PC); F.idle(90)
    snap("pc_choice")
    key("A", 90); snap("pc_a1")
    key("A", 90); snap("pc_a2")
    key("A", 90); snap("pc_a3")
    key("A", 90); snap("pc_menu")
    key("Down", 20); key("Down", 20); snap("pc_move_row")
    key("A", 180); snap("pc_box")
    for i = 1, 3 do key("Right", 30); snap("pc_box_right" .. i) end
    key("Down", 30); snap("pc_box_down")
    key("R", 90); snap("pc_box_next")
  end)

  local function mart(tag)
    if not F.check(tag .. ": in front of the clerk", warp(100, 0, 2, 7)) then return end
    F.face("Left")
    F.w32(S.sMartInfo + 12, 0)
    key("A", 90); snap(tag .. "_welcome")
    key("A", 60); snap(tag .. "_menu")
    key("A", 150); snap(tag .. "_buy")
    for i = 1, 3 do key("Down", 20) end
    snap(tag .. "_buy_down3")
    key("A", 60); snap(tag .. "_qty")
    for i = 1, 5 do key("Up", 10) end
    snap(tag .. "_qty5")
  end
  scene("mart at the money cap", function() setMoney(999999); mart("mart_max") end)
  scene("mart with seven dollars", function() setMoney(7); mart("mart_low") end)
  setMoney(999999)

  scene("naming screen", function()
    local b = { 0x16 }; le16(b, 0x8004); le16(b, 0)
    native(b, S.ChangePokemonNickname); b[#b + 1] = 0x27; b[#b + 1] = 0x02
    runScript(b); F.idle(180)
    snap("naming")
    key("Select", 60); snap("naming_page2")
    key("Select", 60); snap("naming_page3")
    key("Start", 30); key("A", 180)
  end)

  scene("move relearner", function()
    F.dbg(); F.idle(40); F.sel(2); F.idle(40)
    F.sel(0); F.idle(150)
    snap("relearn_open")
    key("A", 150); snap("relearn_after_a")
    key("A", 150); snap("relearn_chooser")
    key("Left", 30); snap("relearn_chooser_party")
    key("A", 60); snap("relearn_chooser_a")
    key("A", 180); snap("relearn_which")
    key("A", 180); snap("relearn_list")
    for i = 1, 3 do key("Down", 20) end
    snap("relearn_down3")
    key("B", 60); snap("relearn_quit_prompt")
    key("A", 120); snap("relearn_quit")
  end)

  scene("keypad message", function()
    local text = encode("Press {A} to talk, {B} to run.\nHold {L}{R} to page, {START} or {SELECT}.")
    for i, v in ipairs(text) do F.w8(TEXT_BUF + i - 1, v) end
    local b = { 0x69, 0x67 }; le32(b, TEXT_BUF)
    for _, op in ipairs({ 0x66, 0x6D, 0x68, 0x6B, 0x02 }) do b[#b + 1] = op end
    runScript(b); F.idle(60)
    snap("msg_keypad")
    key("A", 40)
  end)

  scene("wild single with Intimidate", function()
    local b = wild(SPECIES_GYARADOS, 30); b[#b + 1] = 0xB7; b[#b + 1] = 0x02
    runScript(b)
    if battleIntro("single") then checkActionLabels("single"); battleMenus("single") end
    endBattle("single")
  end)

  scene("wild double with ability pop-ups", function()
    local b = wild(SPECIES_GYARADOS, 30, SPECIES_KYOGRE, 30); b[#b + 1] = 0xB7; b[#b + 1] = 0x02
    runScript(b)
    local up = battleIntro("double")
    F.check("double: a double battle", (F.battleFlags() & B_DOUBLE) ~= 0, string.format("flags=%X", F.battleFlags()))
    if up then checkActionLabels("double"); battleMenus("double") end
    endBattle("double")
  end)

  local function safari(tag, g, n, x, y)
    if not F.check(tag .. ": entered the Safari Zone", warp(g, n, x, y, S.EnterSafariMode)) then return end
    local b = wild(SPECIES_PIKACHU, 20); native(b, S.BattleSetup_StartWildBattle); b[#b + 1] = 0x02
    runScript(b)
    local up = battleIntro(tag)
    F.check(tag .. ": a Safari battle", (F.battleFlags() & B_SAFARI) ~= 0, string.format("flags=%X", F.battleFlags()))
    if up then
      checkActionLabels(tag)
      snap(tag .. "_actions")
      key("Right", 20); snap(tag .. "_actions_right")
      key("Down", 20); snap(tag .. "_actions_down")
    end
    endBattle(tag)
  end
  scene("Hoenn Safari battle", function() safari("safari_hoenn", 26, 3, 32, 33) end)
  scene("Kanto Safari battle", function() safari("safari_kanto", 35, 63, 26, 30) end)
  setFlag(FLAG_SYS_SAFARI_MODE, false)

  scene("frontier pass", function()
    setFlag(FLAG_SYS_FRONTIER_PASS)
    F.w16(F.sb2() + S.SaveBlock2.bp, 1234)
    F.check("frontier pass opens", openIcon(ICON_TRAINER))
    snap("fpass")
    key("A", 120); snap("fpass_card")
    key("A", 120); snap("fpass_card_flip")
    key("A", 120)
    for _ = 1, 30 do joypad.set({ Up = true }); emu.frameadvance() end
    F.idle(20)
    key("A", 150); snap("fpass_map")
    for i = 1, 4 do key("Down", 25); snap("fpass_map_down" .. i) end
  end)
  setFlag(FLAG_SYS_FRONTIER_PASS, false)

  if not ONLY or ("hall of fame"):find(ONLY, 1, true) then
    F.L("== hall of fame")
    if F.check("hall of fame: warped in", F.warpTo(0, 1, 6, 0, 1, 1, 0, 0, 0, 16, 11, "hof")) then
      for f = 0, 9000, 30 do
        local c = F.cb2()
        if c == S.CB2_DoHallOfFameScreen or c == S.CB2_HallOfFame or c == S.CB2_HofIdle then
          if f % 90 == 0 then snap(string.format("hof_%05d", f)) end
        end
        if c == S.MainCB2_Intro or c == S.MainCB2_WorldTitleScreen or c == S.CB2_InitCopyrightScreenAfterBootup then break end
        if f % 240 == 0 then F.press("A", 2); F.idle(28) else F.idle(30) end
      end
      F.check("hall of fame: no crash screen", not F.reportCrash("hof"))
    end
  end

  F.finish()
end)
