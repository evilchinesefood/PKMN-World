-- Issue #59: Mystery Gift row compiled out of the title/main menu.
-- Fresh new game: boot, set FLAG_SYS_MYSTERY_GIFT_ENABLE, in-game save, reboot
-- to CB2_InitMainMenu so CONTINUE exists. Do NOT press A on a menu item.
--
-- Run via Testing/mgba-run.sh Testing/lua/EncountersIncenseLink_MainMenu.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "EncountersIncenseLink_MainMenu")

local HAS_SAVED_GAME = 1
local HAS_MYSTERY_GIFT, HAS_MYSTERY_EVENTS = 2, 3
local MENU_TYPE_NAME = {
  [0] = "HAS_NO_SAVED_GAME",
  [1] = "HAS_SAVED_GAME",
  [2] = "HAS_MYSTERY_GIFT",
  [3] = "HAS_MYSTERY_EVENTS",
}

local SYSTEM_FLAGS = 0x948
local FLAG_SYS_MYSTERY_GIFT_ENABLE = SYSTEM_FLAGS + 0x7B  -- 0x9C3

local function taskBase(i)
  return S.gTasks + i * S.Task.stride
end

local function taskActive(i)
  return F.r8(taskBase(i) + S.Task.isActive) ~= 0
end

-- tMenuType = data[0], tCurrItem = data[1], tItemCount = data[12]; data is s16 at +8.
local function taskMenu(i)
  local b = taskBase(i) + S.Task.data
  return F.rs16(b + 0), F.rs16(b + 2), F.rs16(b + 24)
end

local function findMenuTask()
  for i = 0, S.Task.count - 1 do
    if taskActive(i) then
      local typ, cur, n = taskMenu(i)
      if typ >= 0 and typ <= 3 and n == typ + 2 and n >= 2 and n <= 5 then
        return i, typ, cur, n
      end
    end
  end
  return nil
end

local function sb1Flag(id)
  local b = F.sb1()
  if b < 0x02000000 or b > 0x0203FFFF then return false end
  return (F.r8(b + S.SaveBlock1.flags + (id // 8)) & (1 << (id % 8))) ~= 0
end

local function setSb1Flag(id)
  local b = F.sb1()
  if b < 0x02000000 or b > 0x0203FFFF then return false end
  local a = b + S.SaveBlock1.flags + (id // 8)
  F.w8(a, F.r8(a) | (1 << (id % 8)))
  return sb1Flag(id)
end

local function winHeight(i)
  return F.r8(S.gWindows + i * S.Window.stride + S.Window.height)
end

F.run(function()
  client.speedmode(800)

  if not F.boot(100) then
    F.check("boot to the hub", false)
    F.finish(); return
  end

  -- Discriminator: a TRUE LINK_MYSTERY_GIFT build would promote tMenuType to
  -- HAS_MYSTERY_GIFT when this flag is set. Force it on so a compile-in would
  -- show a 4th row; compiled-out must stay at CONTINUE+NEW GAME+OPTION.
  local flagSet = setSb1Flag(FLAG_SYS_MYSTERY_GIFT_ENABLE)
  F.check("FLAG_SYS_MYSTERY_GIFT_ENABLE set before the in-game save", flagSet)

  -- VerifyBagLayout.lua Start-wheel save: pin slot 0, Right Right to Save, A A A.
  F.press("Start", 2); F.idle(60)
  for _ = 1, 10 do F.press("Left", 2); F.idle(8) end
  F.press("Right", 2); F.idle(12); F.press("Right", 2); F.idle(12)
  F.press("A", 2); F.idle(90); F.press("A", 2); F.idle(60); F.press("A", 2); F.idle(240)
  F.idle(300)
  F.L("  saved; rebooting core")

  client.reboot_core()
  F.idle(240)

  -- Wait for the main menu. Do NOT F.boot() — that mashes A and would Continue.
  -- After reboot the intro CB2 (MainCB2_Intro) is up first; Start/A skip it.
  -- CB2_InitMainMenu is one-shot and becomes CB2_MainMenu, so a live menu
  -- task is the real arrival signal. Never press A once that task exists.
  local reachedMenu = false
  for f = 1, 20000 do
    if findMenuTask() then
      reachedMenu = true
      break
    end
    local c = F.cb2()
    if c == S.CB2_InitMainMenu or (S.CB2_MainMenu and c == S.CB2_MainMenu) then
      reachedMenu = true
      break
    end
    if f % 20 == 0 then
      F.press("Start", 2)
      F.press("A", 2)
    end
    F.idle(1)
  end
  F.check("reached main menu after save+reboot (no boot mash)", reachedMenu,
    "cb2=0x" .. string.format("%08x", F.cb2()))

  -- Start skips intro and opens the main menu. A would select CONTINUE.
  local menuI, menuType, menuCur, menuN
  for f = 1, 20000 do
    if not reachedMenu and f % 20 == 0 then F.press("Start", 2) end
    F.idle(1)
    local i, typ, cur, n = findMenuTask()
    if i and n >= 2 then
      -- Give Task_DisplayMainMenu a chance to draw. Never press A here.
      F.idle(180)
      menuI, menuType, menuCur, menuN = findMenuTask()
      if menuI then break end
    end
  end

  F.check("main menu task appeared (CONTINUE exists)", menuI ~= nil,
    menuI and string.format("task=%d type=%s itemCount=%d", menuI, MENU_TYPE_NAME[menuType] or "?", menuN)
          or ("cb2=0x" .. string.format("%08x", F.cb2())))
  if not menuI then F.shot("main_menu_missing"); F.finish(); return end

  menuType, menuCur, menuN = taskMenu(menuI)
  F.L(string.format("  tMenuType=%d (%s) tCurrItem=%d tItemCount=%d cb2=0x%08x",
    menuType, MENU_TYPE_NAME[menuType] or "?", menuCur, menuN, F.cb2()))
  F.L(string.format("  window heights 2/3/4/5 = %d/%d/%d/%d (CONTINUE is win2 height 6)",
    winHeight(2), winHeight(3), winHeight(4), winHeight(5)))

  F.check("tMenuType is HAS_SAVED_GAME (not HAS_MYSTERY_GIFT)",
    menuType == HAS_SAVED_GAME,
    string.format("type=%s (%d)", MENU_TYPE_NAME[menuType] or "?", menuType))
  F.check("main menu has 3 rows (CONTINUE + NEW GAME + OPTION), not 4",
    menuN == 3, "tItemCount=" .. menuN)
  F.check("HAS_MYSTERY_GIFT row does not exist",
    menuType ~= HAS_MYSTERY_GIFT and menuType ~= HAS_MYSTERY_EVENTS,
    MENU_TYPE_NAME[menuType] or tostring(menuType))

  -- Cursor max: Down is clamped at tItemCount-1. A 4-row menu would reach 3.
  local maxCur = menuCur
  for _ = 1, 6 do
    F.press("Down", 2); F.idle(12)
    local _, cur = taskMenu(menuI)
    if cur > maxCur then maxCur = cur end
  end
  F.L("  cursor max after 6 Downs = " .. maxCur)
  F.check("cursor max is 2 (third row), not 3 (Mystery Gift)",
    maxCur == 2, "maxCursor=" .. maxCur)
  F.shot("main_menu")

  -- Restore cursor to CONTINUE so a leftover A cannot hit a phantom 4th row.
  for _ = 1, 6 do F.press("Up", 2); F.idle(8) end
  local _, curNow = taskMenu(menuI)
  F.check("left the cursor on CONTINUE (row 0); never pressed A",
    curNow == 0, "tCurrItem=" .. curNow)

  F.finish()
end)
