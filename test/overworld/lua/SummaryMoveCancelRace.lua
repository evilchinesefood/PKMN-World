-- Up pressed while the summary's move panel is still sliding in must not show a move past the list.
--
-- On the SwSh summary's moves page A starts move select with the cursor on the first move, and
-- Task_ShowEffectTilemap slides the details panel in over six frames before it prints the details
-- of the move under the cursor. Move select already takes input during the slide, and Up from the
-- first move lands on the Cancel row, index MAX_MON_MOVES. The panel's last step read
-- summary.moves[4], one past the array: the first two PP bytes as a move id (20 | 10 << 8 = 2580
-- for this Abra's Teleport and Dig), far past gMovesInfo. What that entry holds moves with every
-- build. It showed a category icon and placeholder text on the Cancel row, and on the build where
-- InputSpamStress's dig mash found it, a NULL description that FormatTextByWidth copied from open
-- bus into its 100-byte stack buffer until the return address was gone (CPU in Undefined mode).
--
-- A debug-made Abra (Teleport, Dig) leads; the summary opens from the party menu with real input.
-- Controls first: after a finished slide the panel shows Teleport's Status icon, and Up to Cancel
-- clears it. Then three races press Up one, three and five frames after A. Each must keep the game
-- running and show no move details on Cancel; Down must then wrap to Teleport (proving the cursor
-- sat on Cancel) and B must leave move select. B must finally close the summary and the field must
-- come back.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/SummaryMoveCancelRace.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SummaryMoveCancelRace")

local HUB_GROUP = 100
local SPECIES_ABRA, MOVE_TELEPORT, MOVE_DIG = 63, 100, 91
local USM_ICO_PARTY = 1
local FLAG_SYS_POKEMON_GET = 0x948 -- the start menu lists Pokemon only once it is set
local CATEGORY_STATUS = 2
local VBLANK1 = S.gMain + 0x20 -- struct Main.vblankCounter1 (include/main.h)

local SCRIPT_BUF = S.gStringVar4 + 960
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, 0)
  F.idle(20)
end
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function createMon(species, level, moves)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(b, species); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for k = 1, 4 do le16(b, moves[k] or 0) end
  b[#b + 1] = 0x02
  runScript(b)
end

local function leadLast()
  local n = F.r8(S.gPartiesCount)
  local a, b = S.gParties, S.gParties + (n - 1) * S.Pokemon.size
  for i = 0, S.Pokemon.size - 4, 4 do
    local x, y = F.r32(a + i), F.r32(b + i)
    F.w32(a + i, y); F.w32(b + i, x)
  end
end

local function taskActive(fn)
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    if F.r8(a + S.Task.isActive) ~= 0 and (F.r32(a + S.Task.func) & ~1) == (fn & ~1) then return true end
  end
  return false
end
local function moveSelect() return taskActive(S.Task_HandleInput_MoveSelect) end

-- The category of the visible move category icon, or nil when the panel shows none.
local function categoryIcon()
  for i = 0, S.Sprite.count - 1 do
    local a = S.gSprites + i * S.Sprite.stride
    local flags = F.r16(a + S.Sprite.inUse)
    if flags & 1 ~= 0 and flags & 4 == 0 and F.r32(a + S.Sprite.template) == S.sSpriteTemplate_CategoryIcons then
      return F.r8(a + S.Sprite.animNum)
    end
  end
  return nil
end

local function reg(name) return client.readRegister(name) & 0xFFFFFFFF end

local function tap(key, after)
  joypad.set({ [key] = true }); emu.frameadvance()
  F.idle(after)
end

local function recover()
  for i = 1, 2400 do
    if F.reportCrash("recover") then return false end
    if F.ow() and i % 60 == 0 and F.ensureFree() then return true end
    joypad.set((i % 24 < 2) and { B = true } or {})
    emu.frameadvance()
  end
  return false
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  local flags = F.sb1() + S.SaveBlock1.flags + FLAG_SYS_POKEMON_GET // 8
  F.w8(flags, F.r8(flags) | (1 << (FLAG_SYS_POKEMON_GET % 8)))
  createMon(SPECIES_ABRA, 50, { MOVE_TELEPORT, MOVE_DIG })
  leadLast()

  F.press("Start", 2); F.idle(60)
  local opened = F.selectStartIcon(USM_ICO_PARTY)
  if opened then
    -- Summary heads the lead's action list.
    F.press("A", 2); F.idle(120); F.press("A", 2); F.idle(60); F.press("A", 2); F.idle(120)
    tap("Right", 40); tap("Right", 40)
    tap("A", 30)
  end
  F.shot("teleport")
  if not F.check("move select opens on the summary's moves page with Teleport's Status icon",
      opened and moveSelect() and categoryIcon() == CATEGORY_STATUS,
      string.format("party=%d cb2=%08X moveSelect=%s icon=%s", F.r8(S.gPartiesCount), F.cb2(), tostring(moveSelect()),
        tostring(categoryIcon()))) then
    F.finish(); return
  end
  tap("Up", 30)
  F.shot("cancel_after_slide")
  F.check("Up to Cancel after the slide shows no move details", categoryIcon() == nil,
    "icon=" .. tostring(categoryIcon()))
  tap("B", 30)
  F.check("B leaves move select", not moveSelect())

  for _, delay in ipairs({ 1, 3, 5 }) do
    local tag = string.format("Up %d frame%s after A", delay, delay == 1 and "" or "s")
    tap("A", delay - 1)
    local sliding = taskActive(S.Task_ShowEffectTilemap)
    local v0 = F.r32(VBLANK1)
    tap("Up", 30)
    local ran = F.r32(VBLANK1) - v0
    F.shot(string.format("race_%d", delay))
    F.check(tag .. ": Up lands while the move panel is still sliding in", sliding)
    local crashed = F.reportCrash("race_" .. delay)
    F.check(tag .. ": the game keeps running", ran >= 25 and not crashed,
      string.format("vblanks=%d over 31 frames pc=%08X lr=%08X cpsr=%08X", ran, reg("pc"), reg("lr"), reg("cpsr")))
    F.check(tag .. ": Cancel shows no move details", categoryIcon() == nil, "icon=" .. tostring(categoryIcon()))
    tap("Down", 30)
    F.check(tag .. ": Down wraps from Cancel to Teleport", categoryIcon() == CATEGORY_STATUS,
      "icon=" .. tostring(categoryIcon()))
    tap("B", 30)
    F.check(tag .. ": B leaves move select", not moveSelect())
  end

  tap("B", 120)
  F.check("B closes the summary back to the party menu", F.cb2() == (S.CB2_UpdatePartyMenu & ~1),
    string.format("cb2=%08X", F.cb2()))
  F.check("control returns to the field", recover(), string.format("cb2=%08X", F.cb2()))
  F.finish()
end)
