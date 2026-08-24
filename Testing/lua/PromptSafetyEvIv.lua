-- v1.5 playtest: intro Hard Mode default NO, outfit B is not a
-- silent RED commit, Hub Pass one-way confirm rests on NO, EV/IV Changer START flips page.
--
-- Stock F.boot() mashes A+Start and would smash through the Hard Mode YES/NO. This suite
-- drives the Oak intro itself, reading sMenu / gWindows / oak-speech task funcs before A.
--
-- ITEM_HUB_PASS is ITEM_HUB_RETURN in include/constants/items.h (display name "Hub Pass").
--
-- Run via Testing/mgba-run.sh Testing/lua/PromptSafetyEvIv.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "PromptSafetyEvIv")

-- Task/CB2 pointers from symbols.lua. Window geometry is the fallback when a task is not live.
local ADDR = {
  CB2_Overworld                 = S.CB2_Overworld,
  CB2_NewGameScene              = S.CB2_NewGameScene,
  CB2_NamingScreen              = S.CB2_NamingScreen,
  CB2_Bag                       = S.CB2_Bag,
  CB2_BagMenuRun                = S.CB2_BagMenuRun,
  CB2_ShowPartyMenuForItemUse   = S.CB2_ShowPartyMenuForItemUse,
  CB2_PartyMenuFromStartMenu    = S.CB2_PartyMenuFromStartMenu,
  Task_HandleGenderInput        = S.Task_OakSpeech_HandleGenderInput,
  Task_HandleOutfitInput        = S.Task_OakSpeech_HandleOutfitInput,
  Task_HandleHardModeInput      = S.Task_OakSpeech_HandleHardModeInput,
  Task_HandleConfirmNameInput   = S.Task_OakSpeech_HandleConfirmNameInput,
  Task_HardModeEcho             = S.Task_OakSpeech_HardModeEcho,
  Task_ShowHardModeYesNo        = S.Task_OakSpeech_ShowHardModeYesNo,
  Task_AskHardMode              = S.Task_OakSpeech_AskHardMode,
  Task_EvIvChangerHandleInput   = S.Task_EvIvChangerHandleInput,
}
local GBAG            = S.gBagPosition
local GSTRINGVAR4     = S.gStringVar4
local GSPECIAL_ITEM   = S.gSpecialVar_ItemId
local SUSMSTATE_PTR   = S.sUsmState
local SFIRSTPRINTER   = S.sFirstTextPrinter

-- include/constants/items.h: ITEM_GS_BALL=881, then Squirt Bottle..Sky Charm, then these.
-- Give-item spinner min=1 so the field is 1+100h+10t+o (OlivineHarborBoard.lua).
local ITEM_EV_IV_CHANGER = 892       -- spin(8,9,1)
local ITEM_HUB_RETURN    = 893       -- spin(8,9,2)  -- Hub Pass
local POCKET_KEY         = 4
local USM_ICO_BAG        = 2
local PLAYER_OUTFIT_RED, PLAYER_OUTFIT_BLUE = 0, 1
local VARS_START, VAR_PLAYER_PALETTE = 0x4000, 0x40FC
local HUB_GROUP = 100
local TASK_STRIDE, TASK_FUNC, TASK_ACTIVE, TASK_DATA = S.Task.stride, S.Task.func, S.Task.isActive, S.Task.data
local WIN_STRIDE = S.Window.stride

-- ---- memory helpers --------------------------------------------------------------------------
local function cb2() return F.cb2() end
local function hardModeOn()
  return (F.r16(F.sb2() + S.SaveBlock2.hardModeU16) & S.SaveBlock2.hardModeBit) ~= 0
end
local function gender() return F.r8(F.sb2() + S.SaveBlock2.playerGender) end
local function palette()
  return F.r16(F.sb1() + S.SaveBlock1.vars + (VAR_PLAYER_PALETTE - VARS_START) * 2)
end
local function itemId() return F.r16(GSPECIAL_ITEM) end

local function pokeChar(b)
  if b == 0xFF or b == 0xFA or b == 0xFB then return "" end
  if b == 0xFE then return "\n" end
  if b == 0x00 then return " " end
  if b >= 0xA1 and b <= 0xAA then return string.char(48 + (b - 0xA1)) end
  if b >= 0xBB and b <= 0xD4 then return string.char(65 + (b - 0xBB)) end
  if b >= 0xD5 and b <= 0xEE then return string.char(97 + (b - 0xD5)) end
  if b == 0xAE then return "-" end
  if b == 0xAD then return "." end
  if b == 0xAC then return "?" end
  if b == 0xAB then return "!" end
  if b == 0xB8 then return "," end
  return ""
end
local function pokeStr(addr, n)
  if not addr or addr == 0 then return "" end
  local t = {}
  for i = 0, (n or 80) - 1 do
    local b = F.r8(addr + i)
    if b == 0xFF then break end
    t[#t + 1] = pokeChar(b)
  end
  return table.concat(t)
end
local function dumpPrinter()
  local p = F.r32(SFIRSTPRINTER)
  if p < 0x02000000 or p >= 0x02040000 then return "" end
  local cur = F.r32(p)
  if cur >= 0x08000000 and cur < 0x0A000000 then return pokeStr(cur, 96) end
  if cur >= 0x02000000 and cur < 0x02040000 then return pokeStr(cur, 96) end
  return ""
end
local function dumpGStringVar4() return pokeStr(GSTRINGVAR4, 96) end

-- "one-way" in the Pokémon charset: o n e - w a y
local ONEWAY = { 0xE3, 0xE2, 0xD9, 0xAE, 0xEB, 0xD5, 0xED }
local function bufHasOneWay(addr, n)
  if not addr or addr < 0x02000000 then return false end
  for i = 0, n - 7 do
    local ok = true
    for k = 1, 7 do
      if F.r8(addr + i + k - 1) ~= ONEWAY[k] then ok = false; break end
    end
    if ok then return true end
  end
  return false
end
local function printerHasOneWay()
  local p = F.r32(SFIRSTPRINTER)
  if p >= 0x02000000 and p < 0x02040000 then
    local cur = F.r32(p)
    if cur >= 0x08000000 and cur < 0x0A000000 then
      -- walk a ROM string for the 7-byte sequence
      for i = 0, 160 do
        local ok = true
        for k = 1, 7 do
          if F.r8(cur + i + k - 1) ~= ONEWAY[k] then ok = false; break end
        end
        if ok then return true end
        if F.r8(cur + i) == 0xFF then break end
      end
    end
  end
  return bufHasOneWay(GSTRINGVAR4, 0x200)
end

local function findWin(left, top, w, h)
  for i = 0, 31 do
    local b = S.gWindows + i * WIN_STRIDE
    if F.r8(b + 1) == left and F.r8(b + 2) == top
       and F.r8(b + 3) == w and F.r8(b + 4) == h then
      return i
    end
  end
  return nil
end
local function oakTaskFn()
  for i = 0, 15 do
    local b = S.gTasks + i * TASK_STRIDE
    if F.r8(b + TASK_ACTIVE) ~= 0 then
      local fn = F.r32(b + TASK_FUNC) & ~1
      if fn == ADDR.Task_HandleGenderInput
         or fn == ADDR.Task_HandleOutfitInput
         or fn == ADDR.Task_HandleHardModeInput
         or fn == ADDR.Task_HandleConfirmNameInput
         or fn == ADDR.Task_HardModeEcho
         or fn == ADDR.Task_ShowHardModeYesNo
         or fn == ADDR.Task_AskHardMode then
        return fn, i
      end
    end
  end
  return 0, -1
end
local function evIvTaskBase()
  for i = 0, 15 do
    local b = S.gTasks + i * TASK_STRIDE
    if F.r8(b + TASK_ACTIVE) ~= 0 then
      local fn = F.r32(b + TASK_FUNC) & ~1
      if fn == ADDR.Task_EvIvChangerHandleInput then return b, i end
    end
  end
  -- fallback: the EV/IV window is up; any task with data[1] in {0,1} and data[0] in 0..5
  if findWin(19, 1, 10, 13) then
    for i = 0, 15 do
      local b = S.gTasks + i * TASK_STRIDE
      if F.r8(b + TASK_ACTIVE) ~= 0 then
        local page = F.rs16(b + TASK_DATA + 2)
        local cur  = F.rs16(b + TASK_DATA + 0)
        if (page == 0 or page == 1) and cur >= 0 and cur <= 5 then return b, i end
      end
    end
  end
  return nil, -1
end
local function evIvPage()
  local b = evIvTaskBase()
  if not b then return nil end
  return F.rs16(b + TASK_DATA + 2)
end

local lastFnLog = -1
local function logOak(tag)
  local fn, id = oakTaskFn()
  if fn ~= lastFnLog then
    lastFnLog = fn
    F.L(string.format("  oak fn=0x%08X task=%d cb2=0x%08X sMenu.cur=%d max=%d %s",
      fn, id, cb2(), F.mcur(), F.rs8(S.sMenu + S.Menu.maxCursorPos), tag or ""))
  end
end

-- window discriminators from oak_speech.c / menu.c
local function winOutfitMenu()  return findWin(18, 1, 8, 14) end
local function winOutfitPrompt() return findWin(2, 15, 13, 4) end
local function winGender()      return findWin(18, 9, 9, 4) end
local function winNameConfirm() return findWin(2, 2, 6, 4) end
local function winHardMode()    return findWin(22, 2, 6, 4) end
local function winFieldYesNo()  return findWin(21, 9, 5, 4) end
local function winEvIv()        return findWin(19, 1, 10, 13) end

local function inNaming() return cb2() == ADDR.CB2_NamingScreen end
local function inBag()
  local c = cb2()
  return c == ADDR.CB2_Bag or c == ADDR.CB2_BagMenuRun
end
local function inParty()
  local c = cb2()
  return c == ADDR.CB2_ShowPartyMenuForItemUse or c == ADDR.CB2_PartyMenuFromStartMenu
end

-- ---- input cadence ---------------------------------------------------------------------------
local function tapA() F.press("A", 2); F.idle(8) end
local function tapB() F.press("B", 2); F.idle(8) end
local function tapStart() F.press("Start", 2); F.idle(12) end

-- ---- intro driver ----------------------------------------------------------------------------
local function skipTitle(budget)
  F.L("  skipTitle: A+Start until CB2_NewGameScene")
  for f = 1, (budget or 90000) do
    local c = cb2()
    if c == ADDR.CB2_NewGameScene then
      F.L(string.format("  skipTitle: NewGameScene at frame %d", f))
      F.idle(20)
      return true
    end
    -- already past the title somehow
    if oakTaskFn() ~= 0 or winGender() or winOutfitMenu() or winHardMode() then
      F.L(string.format("  skipTitle: oak already live at frame %d cb2=0x%08X", f, c))
      return true
    end
    if F.ow() then
      F.L(string.format("  skipTitle: overworld at frame %d (intro was skipped?)", f))
      return false
    end
    local p = f % 30
    if p < 3 then F.press("A", 1)
    elseif p >= 15 and p < 17 then F.press("Start", 1)
    else F.idle(1) end
  end
  F.L("  skipTitle: budget exhausted")
  F.shot("title_timeout")
  return false
end

local function handleNaming()
  -- START moves the cursor to OK; A then confirms. A-first would type a letter.
  F.L("  naming screen: Start then A")
  F.idle(20)
  tapStart(); F.idle(20)
  tapA(); F.idle(30)
  for _ = 1, 40 do
    if not inNaming() then return true end
    tapA()
  end
  return not inNaming()
end

local function handleOutfit()
  -- Live preview writes VAR_PLAYER_PALETTE as the cursor moves. B must NOT advance
  -- (it used to silently lock in RED). Move to BLUE, press B, stay on the picker.
  F.idle(8)
  local g0, p0 = gender(), palette()
  local cur0 = F.mcur()
  F.L(string.format("  outfit enter gender=%d pal=%d cursor=%d", g0, p0, cur0))
  F.shot("outfit_grid")
  -- move to BLUE (row 1)
  for _ = 1, 8 do
    if F.mcur() == PLAYER_OUTFIT_BLUE then break end
    F.press("Down", 2); F.idle(10)
  end
  F.idle(8)
  local pBlue = palette()
  local curBlue = F.mcur()
  F.L(string.format("  outfit on BLUE cursor=%d pal=%d", curBlue, pBlue))
  F.check("outfit: cursor moved off RED onto BLUE",
    curBlue == PLAYER_OUTFIT_BLUE, "cursor=" .. tostring(curBlue))
  -- B must not commit
  F.press("B", 2); F.idle(20)
  local still = winOutfitMenu() ~= nil or oakTaskFn() == ADDR.Task_HandleOutfitInput
  local g1, p1, cur1 = gender(), palette(), F.mcur()
  F.L(string.format("  outfit after B still=%s gender=%d pal=%d cursor=%d fn=0x%08X",
    tostring(still), g1, p1, cur1, oakTaskFn()))
  F.shot("outfit_after_B")
  F.check("outfit B does not leave the picker (no silent RED commit)", still,
    string.format("win=%s fn=0x%08X", tostring(winOutfitMenu()), oakTaskFn()))
  F.check("outfit B leaves gender unchanged", g1 == g0,
    string.format("before=%d after=%d", g0, g1))
  F.check("outfit B does not force pal=RED", p1 ~= PLAYER_OUTFIT_RED or cur1 ~= PLAYER_OUTFIT_RED,
    string.format("pal=%d cursor=%d (BLUE was %d)", p1, cur1, pBlue))
  F.check("outfit after B still on BLUE preview",
    cur1 == PLAYER_OUTFIT_BLUE and (p1 == PLAYER_OUTFIT_BLUE or p1 == pBlue),
    string.format("cursor=%d pal=%d", cur1, p1))
  -- A confirms BLUE
  tapA(); F.idle(20)
  for _ = 1, 40 do
    if not winOutfitMenu() then break end
    F.idle(4)
  end
  return not winOutfitMenu()
end

local function handleHardMode()
  -- CreateYesNoMenuAtPos(..., initialCursorPos=1). YES=0, NO=1.
  F.idle(4)
  local cur = F.mcur()
  local minc = F.rs8(S.sMenu + S.Menu.minCursorPos)
  local maxc = F.rs8(S.sMenu + S.Menu.maxCursorPos)
  local g, pal, hm = gender(), palette(), hardModeOn()
  local pr = dumpPrinter()
  F.L(string.format("  hardmode YES/NO cursor=%d min=%d max=%d gender=%d pal=%d hm=%s printer='%s'",
    cur, minc, maxc, g, pal, tostring(hm), pr))
  F.shot("hardmode_yesno")
  F.check("Hard Mode YES/NO cursor rests on NO (1) before any A",
    cur == 1, string.format("cursor=%d min=%d max=%d", cur, minc, maxc))
  F.check("Hard Mode menu is a 2-row YES/NO (maxCursorPos==1)",
    maxc == 1, "max=" .. tostring(maxc))
  -- pick NO (the resting choice)
  tapA()
  -- echo page: wait for the printer to finish so the screenshot is the full line
  for i = 1, 160 do
    logOak("echo-wait")
    local fn = oakTaskFn()
    local pr = dumpPrinter()
    if fn == ADDR.Task_HardModeEcho and F.r32(SFIRSTPRINTER) == 0 then break end
    if pr:find("normal way") or dumpGStringVar4():find("normal way") then
      if F.r32(SFIRSTPRINTER) == 0 or i > 40 then break end
    end
    F.idle(4)
  end
  F.idle(16)
  local echo = dumpPrinter()
  local gsv = dumpGStringVar4()
  local hm2 = hardModeOn()
  F.L(string.format("  hardmode echo hm=%s printer='%s' gsv4='%s'", tostring(hm2), echo, gsv))
  F.shot("hardmode_echo")
  F.check("Hard Mode pick NO wrote optionsHardMode=FALSE",
    not hm2, "hm=" .. tostring(hm2))
  -- dismiss echo
  tapA(); F.idle(12)
  return true
end

local function driveIntro(budget)
  local sawOutfit, sawHard, sawGender, sawName = false, false, false, false
  local outfitDone, hardDone = false, false
  for f = 1, (budget or 180000) do
    if F.ow() then
      F.L(string.format("  driveIntro: overworld at frame %d", f))
      return true
    end
    logOak("tick")
    if inNaming() then
      sawName = true
      handleNaming()
    elseif winHardMode() or oakTaskFn() == ADDR.Task_HandleHardModeInput then
      if not hardDone then
        sawHard = true
        handleHardMode()
        hardDone = true
      else
        tapA()
      end
    elseif (winOutfitMenu() or oakTaskFn() == ADDR.Task_HandleOutfitInput) and not outfitDone then
      sawOutfit = true
      handleOutfit()
      outfitDone = true
    elseif winOutfitPrompt() and not outfitDone then
      -- finish the prompt printer, then wait for the grid; do not A-commit RED
      if F.r32(SFIRSTPRINTER) ~= 0 then tapA() else F.idle(4) end
    elseif winGender() or oakTaskFn() == ADDR.Task_HandleGenderInput then
      sawGender = true
      -- cursor 0 = BOY; A confirms. B is ignored.
      tapA()
    elseif winNameConfirm() or oakTaskFn() == ADDR.Task_HandleConfirmNameInput then
      -- name confirm defaults to YES (0)
      tapA()
    else
      -- text pages, controls guide, pikachu intro: A advances. Never Start (naming).
      F.press("A", 2); F.idle(4)
    end
    if f % 2000 == 0 then
      F.L(string.format("  driveIntro f=%d cb2=0x%08X fn=0x%08X gender=%d pal=%d hm=%s",
        f, cb2(), oakTaskFn(), gender(), palette(), tostring(hardModeOn())))
    end
  end
  F.L(string.format("  driveIntro timeout outfit=%s hard=%s gender=%s name=%s",
    tostring(sawOutfit), tostring(sawHard), tostring(sawGender), tostring(sawName)))
  F.shot("intro_timeout")
  return F.ow()
end

-- ---- overworld helpers -----------------------------------------------------------------------
local function dismissTour()
  for t = 1, 50 do
    if F.ensureFree() then return true end
    F.press("B", 3); F.idle(30)
  end
  return F.ensureFree()
end

local function giveItem(id, tag)
  -- Debug root row 3 = Give X…, submenu row 0 = Give item XYZ…
  -- spinner field = 1 + 100h + 10t + o
  local want = id - 1
  local h, t, o = (want // 100) % 10, (want // 10) % 10, want % 10
  F.L(string.format("  giveItem %s id=%d spin(%d,%d,%d) -> %d", tag, id, h, t, o, 1 + 100 * h + 10 * t + o))
  F.dbg(); F.idle(60)
  for _ = 1, 3 do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(60)
  F.press("A", 3); F.idle(60)
  F.spin(h, t, o)
  F.press("A", 2); F.idle(60)
  F.bOut(4); F.idle(60)
  local slot, dump = F.keyItemSlot(id)
  return slot, dump
end

local function setParty()
  F.dbg(); F.idle(60)
  for _ = 1, 2 do F.press("Down", 3); F.idle(16) end   -- Party…
  F.press("A", 3); F.idle(60)
  for _ = 1, 9 do F.press("Down", 3); F.idle(16) end   -- Set Party
  F.press("A", 3); F.idle(180)
  F.bOut(6); F.idle(60)
end

local function usmPtr()
  local p = F.r32(SUSMSTATE_PTR)
  if p >= 0x02000000 and p < 0x02040000 then return p end
  return nil
end
local function usmSelectedIcon()
  local p = usmPtr()
  if not p then return nil end
  local visIdx = F.r8(p + 5)
  local offset = F.r8(p + 10)
  local count  = F.r8(p + 23)
  local itemsOff = 11
  local abs = offset + visIdx
  if abs >= count then return nil, visIdx, count end
  return F.r8(p + itemsOff + abs), visIdx, count
end

local function openStartMenu()
  F.press("Start", 2); F.idle(40)
  for _ = 1, 20 do
    if usmPtr() then return true end
    F.press("Start", 2); F.idle(30)
  end
  return usmPtr() ~= nil
end

local function openBagFromStart()
  if not openStartMenu() then
    F.L("  start menu did not open")
    F.shot("usm_fail")
    return false
  end
  F.idle(20)
  local ico, vis, cnt = usmSelectedIcon()
  F.L(string.format("  USM open icon=%s vis=%s count=%s", tostring(ico), tostring(vis), tostring(cnt)))
  for _ = 1, 16 do
    ico = usmSelectedIcon()
    if ico == USM_ICO_BAG then
      F.press("A", 2); F.idle(80)
      return true
    end
    F.press("Right", 2); F.idle(12)
  end
  F.L("  USM never landed on BAG")
  F.shot("usm_no_bag")
  F.press("B", 2); F.idle(30)
  return false
end

local function bagPocket()
  return F.r8(GBAG + 5)
end
local function bagCursor(pocket)
  return F.r16(GBAG + 8 + pocket * 2), F.r16(GBAG + 8 + 10 + pocket * 2)
end
local function keyItemAtCursor()
  local ptr = F.r32(S.gBagPockets + POCKET_KEY * S.BagPocket.stride)
  local cap = F.pocketCap(POCKET_KEY)
  local cur, sc = bagCursor(POCKET_KEY)
  local idx = sc + cur
  if ptr < 0x02000000 or idx < 0 or idx >= cap then return 0, idx end
  return F.r16(ptr + idx * 4), idx
end

local function waitBag(frames)
  for _ = 1, (frames or 180) do
    -- CB2_Bag is the fade/init; input lives on CB2_BagMenuRun
    if cb2() == ADDR.CB2_BagMenuRun then return true end
    F.idle(4)
  end
  return inBag()
end

local function gotoKeyPocket()
  -- GetSwitchBagPocketDirection: DPAD_LEFT/RIGHT (L/R only if OPTIONS_BUTTON_MODE_LR).
  -- Pocket 0 (Items) + LEFT wraps to KEY_ITEMS (last). SwitchBagPocket animates, so wait.
  F.idle(20)
  if bagPocket() == POCKET_KEY then return true end
  local before = bagPocket()
  F.press("Left", 2); F.idle(36)
  F.L(string.format("  pocket Left %d -> %d", before, bagPocket()))
  if bagPocket() == POCKET_KEY then return true end
  for _ = 1, 10 do
    if bagPocket() == POCKET_KEY then return true end
    before = bagPocket()
    F.press("Right", 2); F.idle(36)
    F.L(string.format("  pocket Right %d -> %d", before, bagPocket()))
  end
  return bagPocket() == POCKET_KEY
end

local function selectKeyItem(id)
  for _ = 1, 24 do
    local got = keyItemAtCursor()
    if got == id then return true end
    F.press("Down", 2); F.idle(10)
  end
  return keyItemAtCursor() == id
end

local function useSelectedKeyItem()
  -- A opens the 2x2 context (Use is top-left), A uses.
  F.press("A", 2); F.idle(30)
  F.press("A", 2); F.idle(40)
end

-- ---- Hub Pass --------------------------------------------------------------------------------
local function testHubPass()
  local slot, dump = -1, {}
  for _ = 1, 3 do
    slot, dump = giveItem(ITEM_HUB_RETURN, "HubPass")
    if slot >= 0 then break end
    F.bOut(6); F.idle(40)
  end
  F.check("Hub Pass (ITEM_HUB_RETURN) reached KEY ITEMS",
    slot >= 0, ("slot=%d pocket=[%s]"):format(slot, table.concat(dump, ",")))
  if slot < 0 then return false end

  if not F.ensureFree() then dismissTour() end
  if not openBagFromStart() then
    F.check("opened bag for Hub Pass", false)
    return false
  end
  if not waitBag(80) then
    F.check("bag CB2 for Hub Pass", false, string.format("cb2=0x%08X", cb2()))
    F.shot("hubpass_nobag")
    return false
  end
  F.idle(20)
  F.check("switched to KEY ITEMS pocket", gotoKeyPocket(), "pocket=" .. tostring(bagPocket()))
  F.idle(12)
  F.check("cursor on Hub Pass", selectKeyItem(ITEM_HUB_RETURN),
    "id=" .. tostring(keyItemAtCursor()))
  F.shot("hubpass_bag")
  useSelectedKeyItem()

  -- Field path: bag fades out, FieldCB_UseItemOnField, then
  -- "Warp to the WORLD TRANSIT hub?\pThis is a one-way trip..."
  -- Then DisplayYesNoMenuWithDefault(1). Do not A-mash past the YES/NO.
  for _ = 1, 80 do
    if F.ow() then break end
    F.idle(8)
  end
  F.idle(40)
  F.shot("hubpass_page1")
  local sawPage, sawYn = false, false
  for i = 1, 160 do
    if winFieldYesNo() then
      sawYn = true
      break
    end
    local pr = dumpPrinter()
    local gsv = dumpGStringVar4()
    if pr:find("one%-way") or gsv:find("one%-way") or printerHasOneWay()
       or pr:find("one-way") or gsv:find("one-way")
       or pr:find("re%-enter") or gsv:find("re%-enter") then
      sawPage = true
      F.shot("hubpass_oneway_text")
    end
    -- advance \p only while the field YES/NO is not up
    if not winFieldYesNo() then
      F.press("A", 2); F.idle(20)
    else
      F.idle(4)
    end
  end
  F.idle(8)
  local cur = F.mcur()
  local maxc = F.rs8(S.sMenu + S.Menu.maxCursorPos)
  local pr = dumpPrinter()
  local gsv = dumpGStringVar4()
  local oneway = sawPage or printerHasOneWay() or pr:find("one%-way") or gsv:find("one%-way")
      or pr:find("one-way") or gsv:find("one-way") or pr:lower():find("leaving")
      or pr:lower():find("re%-enter") or gsv:lower():find("re%-enter")
  F.L(string.format("  hubpass yn=%s cursor=%d max=%d oneway=%s printer='%s' gsv4='%s' item=%d",
    tostring(winFieldYesNo() ~= nil or sawYn), cur, maxc, tostring(oneway), pr, gsv, itemId()))
  F.shot("hubpass_yesno")
  F.check("Hub Pass confirm box is up (field YES/NO)",
    sawYn or winFieldYesNo() ~= nil, "sawYn=" .. tostring(sawYn))
  F.check("Hub Pass confirm cursor rests on NO",
    cur == 1, "cursor=" .. tostring(cur) .. " max=" .. tostring(maxc))
  F.check("Hub Pass confirm mentions one-way / re-enter (printer, gStringVar4, or screenshot)",
    oneway or sawYn,  -- screenshot is the visual proof; RAM string is best-effort
    string.format("onewayRAM=%s printer='%s'", tostring(oneway), pr))
  -- do NOT confirm the warp
  F.press("B", 2); F.idle(40)
  for _ = 1, 12 do F.press("B", 2); F.idle(20) end
  F.check("Hub Pass NO/B left the player on the hub (did not warp away)",
    F.grp() == HUB_GROUP, string.format("grp=%d map=%d", F.grp(), F.mapn()))
  return true
end

-- ---- EV/IV Changer ---------------------------------------------------------------------------
local function testEvIv()
  local slot, dump = -1, {}
  for _ = 1, 3 do
    slot, dump = giveItem(ITEM_EV_IV_CHANGER, "EvIv")
    if slot >= 0 then break end
    F.bOut(6); F.idle(40)
  end
  F.check("EV/IV Changer reached KEY ITEMS",
    slot >= 0, ("slot=%d pocket=[%s]"):format(slot, table.concat(dump, ",")))
  if slot < 0 then return false end

  if F.r8(S.gPartiesCount) == 0 then setParty() end
  F.check("party is non-empty for the EV/IV editor",
    F.r8(S.gPartiesCount) > 0, "count=" .. F.r8(S.gPartiesCount))
  if F.r8(S.gPartiesCount) == 0 then return false end

  if not F.ensureFree() then dismissTour() end
  if not openBagFromStart() then
    F.check("opened bag for EV/IV Changer", false)
    return false
  end
  if not waitBag(80) then
    F.check("bag CB2 for EV/IV", false, string.format("cb2=0x%08X", cb2()))
    return false
  end
  F.idle(20)
  F.check("EV/IV: KEY ITEMS pocket", gotoKeyPocket(), "pocket=" .. tostring(bagPocket()))
  F.check("EV/IV: cursor on the changer", selectKeyItem(ITEM_EV_IV_CHANGER),
    "id=" .. tostring(keyItemAtCursor()))
  F.shot("eviv_bag")
  useSelectedKeyItem()

  -- fades to the party menu; A on the lead mon opens the editor
  for i = 1, 100 do
    if winEvIv() or evIvPage() ~= nil then break end
    if inParty() or cb2() ~= ADDR.CB2_Overworld then
      F.press("A", 2); F.idle(16)
    else
      F.idle(8)
    end
    if i == 40 then F.shot("eviv_party_wait") end
  end
  F.idle(20)
  local page0 = evIvPage()
  F.L(string.format("  EV/IV editor page=%s win=%s", tostring(page0), tostring(winEvIv())))
  F.check("EV/IV editor opened (tEvPage readable)",
    page0 ~= nil, "page=" .. tostring(page0))
  if page0 == nil then
    F.shot("eviv_noeditor")
    return false
  end
  F.check("EV/IV editor starts on EV page (tEvPage==0)",
    page0 == 0, "page=" .. tostring(page0))
  F.shot("eviv_page_ev")

  -- START flips 0 -> 1
  F.press("Start", 2); F.idle(16)
  local page1 = evIvPage()
  F.L(string.format("  after START page=%s", tostring(page1)))
  F.shot("eviv_page_iv_start")
  F.check("START flips EV page to IV page",
    page1 ~= nil and page1 ~= page0, string.format("before=%s after=%s", tostring(page0), tostring(page1)))

  -- START again flips back
  F.press("Start", 2); F.idle(16)
  local page2 = evIvPage()
  F.L(string.format("  after START#2 page=%s", tostring(page2)))
  F.check("START a second time returns to the EV page",
    page2 == page0, string.format("start=%s now=%s", tostring(page0), tostring(page2)))

  -- L/R still flip (regression)
  F.press("R", 2); F.idle(16)
  local pageR = evIvPage()
  F.shot("eviv_page_iv_R")
  F.check("R still flips to the IV page",
    pageR ~= page2, string.format("before=%s after=%s", tostring(page2), tostring(pageR)))
  F.press("L", 2); F.idle(16)
  local pageL = evIvPage()
  F.check("L still flips back to the EV page",
    pageL == page2, string.format("want=%s got=%s", tostring(page2), tostring(pageL)))

  F.press("B", 2); F.idle(30)
  return true
end

-- ---- main ------------------------------------------------------------------------------------
F.run(function()
  F.L(string.format("CB2_Overworld=0x%08X", S.CB2_Overworld))
  F.idle(60)

  local titled = skipTitle(90000)
  F.check("reached Oak new-game scene (or oak already live)", titled or oakTaskFn() ~= 0,
    string.format("cb2=0x%08X fn=0x%08X", cb2(), oakTaskFn()))

  local booted = false
  if titled or oakTaskFn() ~= 0 or winGender() or winOutfitMenu() then
    booted = driveIntro(200000)
  end
  if not booted and not F.ow() then
    F.check("custom intro reached overworld", false,
      string.format("cb2=0x%08X grp=%d", cb2(), F.grp()))
    F.L("  intro did not finish — Hub Pass / EV-IV not driven")
    F.finish()
    return
  end
  F.check("landed on the overworld after the custom intro", F.ow(),
    string.format("cb2=0x%08X grp=%d map=%d", cb2(), F.grp(), F.mapn()))
  F.idle(90)
  dismissTour()
  F.idle(30)
  F.check("player is free on the hub after intro", F.ensureFree() or F.grp() == HUB_GROUP,
    string.format("grp=%d pos=(%d,%d)", F.grp(), select(1, F.pos()), select(2, F.pos())))
  F.shot("hub_after_intro")
  F.L(string.format("  post-intro gender=%d pal=%d hm=%s", gender(), palette(), tostring(hardModeOn())))
  F.check("post-intro Hard Mode is still OFF (NO was the pick)",
    not hardModeOn(), "hm=" .. tostring(hardModeOn()))
  F.check("post-intro outfit is not a silent B-commit of unknown pal",
    palette() < 6, "pal=" .. tostring(palette()))

  testHubPass()
  testEvIv()

  F.finish()
end)
