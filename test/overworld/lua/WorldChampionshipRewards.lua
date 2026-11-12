local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "WorldChampionshipRewards")
local CAP, TITLE, PENDING, MODE = 134, 0xD73, 0x40E5, 0x40F7
local STATUS, FRONTIER_FLAGS = 0xCA8, 0xCA9

local function var(id, value)
  local address = F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2
  if value ~= nil then F.w16(address, value) end
  return F.r16(address)
end

local function title(value)
  local address, bit = F.sb1() + S.SaveBlock1.flags + TITLE // 8, 1 << (TITLE % 8)
  if value ~= nil then
    local old = F.r8(address)
    F.w8(address, value and (old | bit) or (old & ~bit))
  end
  return (F.r8(address) & bit) ~= 0
end

local function capCount()
  local ptr, total = F.r32(S.gBagPockets), 0
  local key = F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF
  for slot = 0, F.pocketCap(0) - 1 do
    if F.r16(ptr + slot * 4) == CAP then total = total + (F.r16(ptr + slot * 4 + 2) ~ key) end
  end
  return total
end

local function bag(count, full)
  local ptr = F.r32(S.gBagPockets)
  local key = F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF
  for slot = 0, F.pocketCap(0) - 1 do
    F.w16(ptr + slot * 4, full and 17 or 0)
    F.w16(ptr + slot * 4 + 2, (full and 999 or 0) ~ key)
  end
  if count > 0 then
    F.w16(ptr, CAP)
    F.w16(ptr + 2, count ~ key)
  end
end

local function dismiss()
  for n = 1, 100 do
    if F.reportCrash("reward_dialogue") then return false end
    F.press("B", 2); F.idle(20)
    if n % 5 == 0 and F.ensureFree() then return true end
  end
  return false
end

local function save()
  F.w16(S.gSaveAttemptStatus, 0xFFFF)
  F.press("Start", 2); F.idle(60)
  assert(F.selectStartIcon(7), "Save action unavailable")
  F.press("A", 2); F.idle(90)
  for _ = 1, 12 do
    F.press("A", 2); F.idle(45)
    if F.r16(S.gSaveAttemptStatus) == 1 then break end
  end
  F.idle(120)
  assert(dismiss(), "Save dialogue did not close")
  F.check("normal save completed", F.r16(S.gSaveAttemptStatus) == 1)
end

local function reload(expectedCaps, expectedPending)
  client.reboot_core()
  assert(F.boot(26), "Continue did not reach Dome lobby")
  F.check("Continue preserves caps and pending debt", capCount() == expectedCaps and var(PENDING) == expectedPending,
    string.format("caps=%d pending=%d", capCount(), var(PENDING)))
  F.check("Continue keeps result consumed and mode cleared", F.r8(F.sb2() + STATUS) == 0 and var(MODE) == 0)
end

local function result(mode, status)
  local bp = F.bp()
  local wins = F.r16(F.sb2() + 0xD1C)
  var(0x40CE, 0)
  var(0x40CF, 1)
  var(MODE, mode)
  F.w8(F.sb2() + FRONTIER_FLAGS, 8)
  for i = 0, 2 do F.w16(F.sb2() + 0xCAA + i * 2, i + 1) end
  local warp = F.sb1() + 0x14
  F.w8(warp, 26); F.w8(warp + 1, 18); F.w8(warp + 2, 255)
  F.w16(warp + 4, 11); F.w16(warp + 6, 16)
  F.w8(F.sb2() + STATUS, status)
  F.w16(S.gSaveAttemptStatus, 0xFFFF)
  var(0x4000, status)
  F.idle(2)
  assert(dismiss(), "Tournament result did not finish")
  F.check("result saved and consumed once", F.r16(S.gSaveAttemptStatus) == 1 and F.r8(F.sb2() + STATUS) == 0)
  F.check("normal BP result is retained", status == 3 and F.bp() > bp or status == 4 and F.bp() == bp)
  F.check("normal tournament record is retained", F.r16(F.sb2() + 0xD1C) == wins + (status == 3 and 1 or 0))
end

local function registrar()
  for _ = 1, 12 do
    local x, y
    for i = 0, 15 do
      local address = S.gObjectEvents + i * S.ObjectEvent.stride
      if (F.r8(address) & 1) ~= 0 and F.r8(address + S.ObjectEvent.localId) == 5 then
        x, y = F.rs16(address + S.ObjectEvent.x) - 7, F.rs16(address + S.ObjectEvent.y) - 7
      end
    end
    assert(x, "Registrar object missing")
    if F.route({{x, y + 1}}, "registrar") then
      F.face("Up"); F.press("A", 2); F.idle(15)
      if F.r8(S.sGlobalScriptContextStatus) ~= 2 then
        assert(dismiss(), "Registrar dialogue did not finish")
        return
      end
    end
  end
  error("Could not talk to registrar")
end

F.run(function()
  assert(F.boot(100), "Fresh game did not boot")
  assert(F.warpTo(0, 2, 6, 0, 1, 8, 0, 0, 0, 26, 18, "dome"), "Dome warp failed")
  bag(0, false); title(false); var(PENDING, 0)
  save()

  result(1, 3)
  F.check("first victory awards cap and title", capCount() == 1 and title() and var(PENDING) == 0)
  result(1, 3)
  F.check("repeat victory awards another cap", capCount() == 2 and title() and var(PENDING) == 0)
  reload(2, 0)

  bag(0, false); title(true); var(PENDING, 0)
  registrar()
  F.check("legacy title grants no retroactive cap", capCount() == 0 and var(PENDING) == 0)
  result(1, 3)
  F.check("legacy champion earns next victory cap", capCount() == 1 and var(PENDING) == 0)

  bag(999, true); title(false)
  result(1, 3)
  F.check("full stack retains reward and grants title", capCount() == 999 and var(PENDING) == 1 and title())
  result(1, 3)
  F.check("another full-bag win accumulates debt", capCount() == 999 and var(PENDING) == 2)
  reload(999, 2)
  registrar(); registrar()
  F.check("failed retries retain both caps", capCount() == 999 and var(PENDING) == 2)
  bag(998, true)
  registrar()
  F.check("partial backlog collection debits exactly one", capCount() == 999 and var(PENDING) == 1)
  save(); reload(999, 1)
  bag(0, false)
  registrar(); registrar()
  F.check("remaining cap is delivered only once", capCount() == 1 and var(PENDING) == 0)
  save(); reload(1, 0)

  local beforeCaps, beforeDebt = capCount(), var(PENDING)
  result(0, 3)
  F.check("ordinary Dome win grants no cap", capCount() == beforeCaps and var(PENDING) == beforeDebt)
  result(1, 4)
  F.check("championship loss grants no cap", capCount() == beforeCaps and var(PENDING) == beforeDebt)
  F.shot("completed")
  F.finish()
end)
