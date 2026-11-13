-- Stress the World Championship registrar beyond the reward ledger WorldChampionshipRewards covers.
--
-- The registrar sets VAR_WORLD_CHAMPIONSHIP_MODE before handing over to the stock Dome attendant
-- flow. Every way out of that flow short of entering the tournament must clear it again, because
-- CannotUseHubReturnHere() refuses the HUB PASS while the mode is set. Each cancel below is driven
-- through the real menus, then the HUB PASS is used from SELECT and must actually reach the hub.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/WorldChampionshipStress.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "WorldChampionshipStress")

local CAP, TITLE, PENDING, MODE = 134, 0xD73, 0x40E5, 0x40F7
local STATUS, FRONTIER_FLAGS = 0xCA8, 0xCA9
local HUB_PASS = 893
local CHAMPION_FLAGS = { 0xA48, 0xA49, 0xA4A }
local LOBBY_G, LOBBY_M, HUB_G, HUB_M = 26, 18, 100, 0

local function var(id, value)
  local address = F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2
  if value ~= nil then F.w16(address, value) end
  return F.r16(address)
end

local function flag(id, value)
  local address, bit = F.sb1() + S.SaveBlock1.flags + id // 8, 1 << (id % 8)
  if value ~= nil then
    local old = F.r8(address)
    F.w8(address, value and (old | bit) or (old & ~bit & 0xFF))
  end
  return (F.r8(address) & bit) ~= 0
end

local function key() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF end

local function capCount()
  local ptr, total = F.r32(S.gBagPockets), 0
  for slot = 0, F.pocketCap(0) - 1 do
    if F.r16(ptr + slot * 4) == CAP then total = total + (F.r16(ptr + slot * 4 + 2) ~ key()) end
  end
  return total
end

local function giveKeyItem(id)
  local slot, _ = F.keyItemSlot(id)
  if slot >= 0 then return true end
  local ptr = F.r32(S.gBagPockets + 4 * S.BagPocket.stride)
  for s = 0, F.pocketCap(4) - 1 do
    if F.r16(ptr + s * 4) == 0 then
      F.w16(ptr + s * 4, id); F.w16(ptr + s * 4 + 2, 1 ~ key())
      return true
    end
  end
  return false
end

local function mapIs(g, m) return F.grp() == g and F.mapn() == m end

local function liveMenu()
  for i = 0, S.Task.count - 1 do
    local task = S.gTasks + i * S.Task.stride
    local fn = F.r32(task + S.Task.func) & 0xFFFFFFFE
    if F.r8(task + S.Task.isActive) ~= 0 then
      if fn == S.Task_HandleYesNoInput or fn == S.Task_CallYesOrNoCallback then return "yesno" end
      if fn == S.Task_HandleMultichoiceInput then return "multi" end
    end
  end
  return nil
end

-- Advance text with A until a YES/NO or multichoice task is live, then return its kind.
local function untilMenu(tag)
  for _ = 1, 60 do
    if F.reportCrash("menu_" .. tag) then return nil end
    local kind = liveMenu()
    if kind then F.idle(12); return kind end
    F.press("A", 2); F.idle(30)
  end
  F.L("  " .. tag .. ": no menu went live"); F.shot(tag .. "_nomenu")
  return nil
end

local function choose(want, tag)
  for _ = 1, 8 do
    local c = F.mcur()
    if c == want then F.press("A", 2); F.idle(45); return true end
    F.press(c > want and "Up" or "Down", 2); F.idle(12)
  end
  F.L("  " .. tag .. ": cursor never reached " .. want)
  return false
end

local function dismiss()
  for n = 1, 100 do
    if F.reportCrash("dialogue") then return false end
    F.press("B", 2); F.idle(20)
    if n % 5 == 0 and F.ensureFree() then return true end
  end
  return false
end

local function registrarTile()
  for i = 0, 15 do
    local address = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(address) & 1) ~= 0 and F.r8(address + S.ObjectEvent.localId) == 5 then
      return F.rs16(address + S.ObjectEvent.x) - 7, F.rs16(address + S.ObjectEvent.y) - 7
    end
  end
end

local function talkToRegistrar(tag)
  for _ = 1, 12 do
    local x, y = registrarTile()
    assert(x, "Registrar object missing")
    for _, side in ipairs({ { x, y + 1, "Up" }, { x - 1, y, "Right" }, { x + 1, y, "Left" }, { x, y - 1, "Down" } }) do
      if F.leg(side[1], side[2]) then
        F.face(side[3]); F.press("A", 2); F.idle(30)
        if F.r8(S.sGlobalScriptContextStatus) ~= 2 then return end
        break
      end
    end
    F.idle(30)
  end
  error("Could not talk to registrar")
end

-- Talk to the registrar, accept the championship, then leave the attendant flow by `exit`.
local function acceptThenCancel(tag, exit)
  talkToRegistrar(tag)
  if untilMenu(tag .. "_offer") ~= "yesno" then return false end
  F.shot(tag .. "_offer")
  if not choose(0, tag .. "_offer") then return false end
  if exit == "decline" then return dismiss() end
  if untilMenu(tag .. "_info") ~= "multi" then return false end
  if exit == "info_b" then
    F.press("B", 2); F.idle(45)
  elseif exit == "info_exit" then
    if not choose(2, tag .. "_info") then return false end
  elseif exit == "level_b" then
    if not choose(0, tag .. "_info") then return false end
    if untilMenu(tag .. "_level") ~= "multi" then return false end
    F.shot(tag .. "_level")
    F.press("B", 2); F.idle(45)
  end
  return dismiss()
end

local function declineOffer(tag)
  talkToRegistrar(tag)
  if untilMenu(tag .. "_offer") ~= "yesno" then return false end
  if not choose(1, tag .. "_offer") then return false end
  return dismiss()
end

local function hubPassReachesHub(tag)
  F.w16(F.sb1() + S.SaveBlock1.registeredItem, HUB_PASS)
  F.press("Select", 2); F.idle(90)
  F.shot(tag .. "_hubpass_select")
  local kind = untilMenu(tag .. "_hubpass")
  if kind ~= "yesno" then F.shot(tag .. "_hubpass_refused"); dismiss(); return false end
  if not choose(0, tag .. "_hubpass") then return false end
  for _ = 1, 150 do
    if mapIs(HUB_G, HUB_M) then F.idle(120); return true end
    if F.reportCrash("hubpass_" .. tag) then return false end
    F.press("A", 2); F.idle(20)
  end
  return mapIs(HUB_G, HUB_M)
end

local function backToLobby(tag)
  assert(F.warpTo(0, 2, 6, 0, 1, 8, 0, 0, 0, LOBBY_G, LOBBY_M, tag), "Dome warp failed")
  F.idle(60)
end

local function result(mode, status)
  var(0x40CE, 0)
  var(0x40CF, 1)
  var(MODE, mode)
  F.w8(F.sb2() + FRONTIER_FLAGS, 8)
  for i = 0, 2 do F.w16(F.sb2() + 0xCAA + i * 2, i + 1) end
  local warp = F.sb1() + 0x14
  F.w8(warp, LOBBY_G); F.w8(warp + 1, LOBBY_M); F.w8(warp + 2, 255)
  F.w16(warp + 4, 11); F.w16(warp + 6, 16)
  F.w8(F.sb2() + STATUS, status)
  F.w16(S.gSaveAttemptStatus, 0xFFFF)
  var(0x4000, status)
  F.idle(2)
  assert(dismiss(), "Tournament result did not finish")
end

F.run(function()
  assert(F.boot(100), "Fresh game did not boot")
  backToLobby("dome")
  for _, id in ipairs(CHAMPION_FLAGS) do flag(id, true) end
  flag(TITLE, false); var(PENDING, 0); var(MODE, 0)
  F.check("HUB PASS placed in the key items pocket", giveKeyItem(HUB_PASS))

  F.check("declining the offer runs cleanly", declineOffer("decline"))
  F.check("declining the offer leaves the mode clear", var(MODE) == 0, "mode=" .. var(MODE))

  local scenarios = {
    { "info_b", "B at the challenge menu" },
    { "info_exit", "EXIT at the challenge menu" },
    { "level_b", "B at the level menu" },
  }
  for _, sc in ipairs(scenarios) do
    local ok = acceptThenCancel(sc[1], sc[1])
    F.check(sc[2] .. ": dialogue closes", ok)
    F.check(sc[2] .. ": championship mode cleared", var(MODE) == 0, "mode=" .. var(MODE))
    F.check(sc[2] .. ": no prize or title granted", capCount() == 0 and var(PENDING) == 0 and not flag(TITLE),
      string.format("caps=%d pending=%d title=%s", capCount(), var(PENDING), tostring(flag(TITLE))))
    local reached = hubPassReachesHub(sc[1])
    F.check(sc[2] .. ": HUB PASS still reaches the hub", reached,
      string.format("grp=%d map=%d mode=%d", F.grp(), F.mapn(), var(MODE)))
    if reached then F.shot(sc[1] .. "_hub") end
    backToLobby("lobby_" .. sc[1])
  end

  result(1, 4)
  F.check("championship loss grants no cap", capCount() == 0 and var(PENDING) == 0, "caps=" .. capCount())
  result(1, 3)
  F.check("win after a loss grants exactly one cap and the title", capCount() == 1 and var(PENDING) == 0 and flag(TITLE),
    string.format("caps=%d pending=%d", capCount(), var(PENDING)))
  F.check("win clears the championship mode", var(MODE) == 0)
  F.check("HUB PASS works after a completed championship", hubPassReachesHub("after_win"))
  backToLobby("lobby_legacy")
  var(MODE, 1)
  F.check("a save left at mode 1 by an earlier cancel can still use the HUB PASS", hubPassReachesHub("legacy_mode"),
    string.format("grp=%d map=%d", F.grp(), F.mapn()))
  F.shot("completed")
  F.finish()
end)
