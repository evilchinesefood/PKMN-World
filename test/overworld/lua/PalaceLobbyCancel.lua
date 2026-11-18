-- Every cancel at the Battle Palace lobby attendants, singles and doubles, with a follower out.
--
-- The lobby's party-restoring cancel (LoadPartyAndCancelChallenge) is reached from the party pick
-- (backing out with none or with three chosen) and from the save prompt (NO or B). The plain cancel
-- is reached from the first menu (CANCEL or B) and the level menu (CANCEL or B). Each case starts
-- from one post-boot savestate with four Lv. 50 Pokemon (Charizard leads, so it is the follower),
-- walks to the attendant and cancels through the real menus. After each cancel control must come
-- back, the player must walk, the party must be byte-identical to the one that walked in, and the
-- follower must be the lead and walk behind the player. The party pick chooses slots 3, 2, 1, so
-- a party reordered to the pick would put Venusaur in front.
--
-- The base saves the game from the Start menu, which also writes the party SavePlayerParty keeps
-- (SaveBlock1.playerParty). The "stale" cases then gain a fifth Pokemon without saving, so that
-- copy lags the live party the way it does after any earlier save or challenge. The suite asserts
-- the copy really is the old four before it cancels, so a cancel that restored it would drop the
-- fifth.
--
-- `--env PW_CASE=<text>` runs the cases whose name contains the text.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/PalaceLobbyCancel.lua <rom.gba>

local S = require("symbols")
local F = require("lib").new(S, "PalaceLobbyCancel")

local FRONTIER, PALACE_LOBBY = 26, 22
local FOLLOWER = 0xFE
local ATTENDANT = {
  singles = { walk = { { 12, 10 }, { 5, 10 }, { 5, 7 } }, away = "Down" },
  doubles = { walk = { { 13, 10 }, { 13, 8 }, { 19, 8 }, { 19, 7 } }, away = "Left" },
}

local SCRIPT_BUF = S.gStringVar4 + 960
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function giveMon(species, moves)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(b, species); le16(b, 50)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for i = 1, 4 do le16(b, moves[i] or 0) end
  b[#b + 1] = 0x02
  for i, v in ipairs(b) do F.w8(SCRIPT_BUF + i - 1, v) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, 0)
  F.idle(20)
end

local function bytesAt(base, count)
  local t = {}
  for i = 0, count * S.Pokemon.size - 1 do t[#t + 1] = F.r8(base + i) end
  return count .. ":" .. table.concat(t, ",")
end
local function partyBytes() return bytesAt(S.gParties, F.r8(S.gPartiesCount)) end
local function savedPartyBytes()
  return bytesAt(F.sb1() + S.SaveBlock1.playerParty, F.r8(F.sb1() + S.SaveBlock1.playerPartyCount))
end
local function personalities()
  local t = {}
  for i = 0, F.r8(S.gPartiesCount) - 1 do t[#t + 1] = string.format("%08X", F.r32(S.gParties + i * S.Pokemon.size)) end
  return table.concat(t, " ")
end
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end

local function cb(addr) return F.cb2() == (addr & ~1) end
local function inPartyMenu() return cb(S.CB2_UpdatePartyMenu) or cb(S.CB2_InitPartyMenu) end
local function scriptIdle() return F.r8(S.sGlobalScriptContextStatus) == 2 end

local function liveMenu()
  for i = 0, S.Task.count - 1 do
    local task = S.gTasks + i * S.Task.stride
    local fn = F.r32(task + S.Task.func) & 0xFFFFFFFE
    if F.r8(task + S.Task.isActive) ~= 0 then
      if fn == S.Task_HandleYesNoInput or fn == S.Task_CallYesOrNoCallback then return "yesno" end
      if fn == S.Task_HandleMultichoiceInput then return "multi" end
    end
  end
end
local function waitMenu(tag)
  for _ = 1, 80 do
    if F.reportCrash("menu_" .. tag) then return false end
    if liveMenu() then F.idle(12); return true end
    F.press("A", 2); F.idle(30)
  end
  F.L("  " .. tag .. ": no menu went live"); F.shot(tag .. "_nomenu")
  return false
end
local function choose(want)
  for _ = 1, 8 do
    local c = F.mcur()
    if c == want then F.press("A", 2); F.idle(45); return true end
    F.press(c > want and "Up" or "Down", 2); F.idle(12)
  end
  return false
end
local function menuPick(want, tag) return waitMenu(tag) and choose(want) end
local function menuB(tag)
  if not waitMenu(tag) then return false end
  F.press("B", 2); F.idle(45)
  return true
end

-- Opens the pick, chooses slots 3, 2, 1, then either confirms (Start, A) or backs out (B, YES).
local function pick(n, backOut)
  for _ = 1, 300 do
    if inPartyMenu() then break end
    F.press("A", 2); F.idle(20)
  end
  if not inPartyMenu() then return false end
  F.idle(60)
  if n > 0 then F.press("Down", 2); F.idle(20); F.press("Down", 2); F.idle(20) end
  for i = 1, n do
    F.press("A", 2); F.idle(30)
    F.press("A", 2); F.idle(40)
    if i < n then F.press("Up", 2); F.idle(20) end
  end
  if n > 0 and not backOut then F.shot("picked") end
  F.press(backOut and "B" or "Start", 2); F.idle(60)
  for _ = 1, 8 do
    if not inPartyMenu() then break end
    F.press("A", 2); F.idle(60)
  end
  return not inPartyMenu()
end

local USM_ICO_SAVE, SENTINEL = 7, 0xFFFF
local function saveGame()
  F.w16(S.gSaveAttemptStatus, SENTINEL)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_SAVE) then return false end
  for i = 1, 3000 do
    if F.r16(S.gSaveAttemptStatus) ~= SENTINEL then
      F.idle(30)
      for _ = 1, 6 do F.press("B", 2); F.idle(20) end
      return F.r16(S.gSaveAttemptStatus) == 1
    end
    if i % 20 == 1 then joypad.set({ A = true }) else joypad.set({}) end
    emu.frameadvance()
  end
  return false
end

local function follower()
  for i = 0, 15 do
    local a = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(a) & 1) ~= 0 and F.r8(a + S.ObjectEvent.localId) == FOLLOWER then
      return { gfx = F.r16(a + S.ObjectEvent.graphicsId), visible = (F.r8(a + 1) & 0x20) == 0 }
    end
  end
end
local function folStr(f) return f and string.format("gfx=%04X visible=%s", f.gfx, tostring(f.visible)) or "none" end

local function talk(mode, tag)
  if not F.check(tag .. ": walked to the attendant", F.route(ATTENDANT[mode].walk, tag), where()) then return false end
  F.face("Up"); F.press("A", 2); F.idle(30)
  return true
end

-- Pages the closing text with B (A would talk to the attendant again) until the script releases.
local function waitReleased(tag)
  for _ = 1, 60 do
    if F.reportCrash(tag .. "_release") then return false end
    if F.ow() and scriptIdle() and F.r8(S.sLockFieldControls) == 0 and not liveMenu() then
      F.idle(30)
      if scriptIdle() and F.r8(S.sLockFieldControls) == 0 then return true end
    end
    F.press("B", 2); F.idle(30)
  end
  return false
end

local CANCELS = {
  challenge_b      = function(tag) return menuB(tag .. "_challenge") end,
  challenge_cancel = function(tag) return menuPick(2, tag .. "_challenge") end,
  level_b          = function(tag) return menuPick(0, tag .. "_challenge") and menuB(tag .. "_level") end,
  level_cancel     = function(tag) return menuPick(0, tag .. "_challenge") and menuPick(2, tag .. "_level") end,
  pick_none        = function(tag) return menuPick(0, tag .. "_challenge") and menuPick(0, tag .. "_level") and pick(0, true) end,
  pick_three_back  = function(tag) return menuPick(0, tag .. "_challenge") and menuPick(0, tag .. "_level") and pick(3, true) end,
  save_no          = function(tag)
    return menuPick(0, tag .. "_challenge") and menuPick(0, tag .. "_level") and pick(3, false) and menuPick(1, tag .. "_save")
  end,
  save_b           = function(tag)
    return menuPick(0, tag .. "_challenge") and menuPick(0, tag .. "_level") and pick(3, false) and menuB(tag .. "_save")
  end,
}

local function settle(tag, mode, party0, fol0)
  local released = waitReleased(tag)
  F.check(tag .. ": control came back in the lobby", released and F.grp() == FRONTIER and F.mapn() == PALACE_LOBBY, where())
  local folNow = follower()
  F.L(string.format("  %s: follower on release %s, frontier status %d", tag, folStr(folNow), F.r8(F.sb2() + S.SaveBlock2.frontierChallengeStatus)))
  F.check(tag .. ": the follower is out as the lead on release", folNow ~= nil and fol0 ~= nil and folNow.gfx == fol0.gfx, folStr(folNow))
  F.check(tag .. ": the party is byte-identical to the one that walked in", partyBytes() == party0, "now " .. personalities())
  F.check(tag .. ": no challenge was started", F.r8(F.sb2() + S.SaveBlock2.frontierChallengeStatus) == 0)
  local x0, y0 = F.pos()
  local away = ATTENDANT[mode].away
  F.step(away); F.idle(20); F.step(away); F.idle(60)
  local x, y = F.pos()
  F.check(tag .. ": the player walks", math.abs(x - x0) + math.abs(y - y0) == 2, where())
  local fol = follower()
  F.shot(tag .. "_end")
  F.check(tag .. ": the follower walks behind the player", fol ~= nil and fol.visible and fol0 ~= nil and fol.gfx == fol0.gfx, folStr(fol))
end

local function runCase(c, base)
  local tag = c.name
  client.loadstate(base); F.idle(10)
  assert(F.warpTo(0, 2, 6, 0, 2, 2, 0, 0, 0, FRONTIER, PALACE_LOBBY, tag), "lobby warp failed")
  F.idle(60)
  if c.stale then
    giveMon(133, { 33, 0, 0, 0 })
    F.check(tag .. ": a fifth Pokemon joined after the save", F.r8(S.gPartiesCount) == 5, "n=" .. F.r8(S.gPartiesCount))
    F.check(tag .. ": the saved party is the four from before", F.r8(F.sb1() + S.SaveBlock1.playerPartyCount) == 4
      and savedPartyBytes() ~= partyBytes(), "saved n=" .. F.r8(F.sb1() + S.SaveBlock1.playerPartyCount))
  end
  local party0 = partyBytes()
  if not talk(c.mode, tag) then return end
  local fol0 = follower()
  F.L(string.format("  %s: walked in with party %s follower %s", tag, personalities(), folStr(fol0)))
  if not F.check(tag .. ": reached the " .. c.cancel .. " cancel", CANCELS[c.cancel](tag), where()) then
    F.shot(tag .. "_lost"); return
  end
  settle(tag, c.mode, party0, fol0)
end

local CASES = {}
for _, mode in ipairs({ "singles", "doubles" }) do
  for _, cancel in ipairs({ "challenge_b", "challenge_cancel", "level_b", "level_cancel", "pick_none", "pick_three_back", "save_no", "save_b" }) do
    CASES[#CASES + 1] = { name = mode .. "_" .. cancel, mode = mode, cancel = cancel }
  end
  CASES[#CASES + 1] = { name = mode .. "_stale_save_no", mode = mode, cancel = "save_no", stale = true }
  CASES[#CASES + 1] = { name = mode .. "_stale_pick_three_back", mode = mode, cancel = "pick_three_back", stale = true }
end

F.run(function()
  assert(F.boot(100), "Fresh game did not boot")
  giveMon(6, { 53, 89, 0, 0 }); giveMon(9, { 57, 58, 0, 0 }); giveMon(3, { 202, 89, 0, 0 }); giveMon(25, { 85, 0, 0, 0 })
  F.check("four Pokemon in the party", F.r8(S.gPartiesCount) == 4, "n=" .. F.r8(S.gPartiesCount))
  F.check("saved the game from the Start menu", saveGame())
  F.check("the save wrote the four into SaveBlock1.playerParty", savedPartyBytes() == partyBytes(),
    "saved n=" .. F.r8(F.sb1() + S.SaveBlock1.playerPartyCount))
  local base = F.out .. "PalaceLobbyCancel_base.ss"
  client.savestate(base)
  local only = os.getenv("PW_CASE")
  for _, c in ipairs(CASES) do
    if not only or c.name:find(only, 1, true) then runCase(c, base) end
  end
  F.check("no crash screen", not F.crashScreen())
  F.finish()
end)
