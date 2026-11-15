-- Save, then Continue, at odd moments: surfing with a follower, underwater, next to a visible wild
-- Pokemon, aboard the S.S. Anne and the S.S. Aqua. Each case saves from the Start menu, then
-- either soft resets or cuts the power, continues the file and checks the map, the position, the
-- party, the region, the whiteout point, the avatar state, and that the player can walk.
--
-- PW_CONT_ONLY=<text> (runner --env) runs only matching cases.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/ContinueOddMoments.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "ContinueOddMoments")

local HUB_GROUP = 100
local USM_ICO_SAVE = 7
local SENTINEL = 0xFFFF
local CONTEXT_RUNNING = 0
local PARTY_SIZE = 6
local SPECIES_LAPRAS = 131
local MOVE_SURF, MOVE_ICE_BEAM, MOVE_DIVE = 57, 58, 291
local ITEM_SURF_TOOL, ITEM_DIVE_TOOL, ITEM_HUB_RETURN = 876, 880, 893
local AVATAR_SURFING, AVATAR_UNDERWATER = 1 << 3, 1 << 4
local OBJ_EVENT_ID_FOLLOWER = 0xFE
local ONLY = os.getenv("PW_CONT_ONLY")

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function warp(g, m, w, tag)
  local gh, gt, go = d(g)
  local mh, mt, mo = d(m)
  local wh, wt, wo = d(w)
  return F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, g, m, tag)
end

local SCRIPT_BUF = S.gStringVar4 + 960
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
end
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function createMon(species, level, moves)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = PARTY_SIZE
  le16(b, species); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for k = 1, 4 do le16(b, moves[k] or 0) end
  b[#b + 1] = 0x02
  runScript(b); F.idle(20)
  return F.r8(S.gPartiesCount)
end
local function addItem(id, qty)
  runScript({ 0x44, id & 0xFF, id >> 8, qty & 0xFF, qty >> 8, 0x02 }); F.idle(10)
end

local function avatar() return F.r8(S.gPlayerAvatar) end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0
    and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end

local function objByLocal(id)
  for i = 0, 15 do
    local o = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(o) & 1) ~= 0 and F.r8(o + 8) == id then return o end
  end
end
local function follower()
  local o = objByLocal(OBJ_EVENT_ID_FOLLOWER)
  if not o then return "none" end
  local inv = (F.r8(o + 1) >> 5) & 1
  return string.format("%s@(%d,%d)", inv == 1 and "hidden" or "shown", F.rs16(o + 0x10) - 7, F.rs16(o + 0x12) - 7)
end
local function countOwes()
  local n = 0
  for i = 0, 15 do
    local o = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(o) & 1) ~= 0 and F.r8(o + 7) == 0xFF then n = n + 1 end
  end
  return n
end

local function partyHash()
  local n = F.r8(S.gPartiesCount)
  local h = n
  for i = 0, n * S.Pokemon.size - 1, 4 do h = (h * 31 + F.r32(S.gParties + i)) & 0xFFFFFFFF end
  return h
end
local function heal()
  local a = F.sb1() + S.SaveBlock1.lastHealLocation
  return string.format("%d/%d(%d,%d)", F.r8(a), F.r8(a + 1), F.rs16(a + 4), F.rs16(a + 6))
end

local function snapshot()
  local x, y = F.pos()
  return { grp = F.grp(), map = F.mapn(), x = x, y = y, party = partyHash(), n = F.r8(S.gPartiesCount),
           region = F.r8(F.sb2() + S.SaveBlock2.currentRegion), heal = heal(),
           avatar = avatar() & (AVATAR_SURFING | AVATAR_UNDERWATER), follower = follower() }
end
local function fmt(s)
  return string.format("%d/%d (%d,%d) party=%08X n=%d region=%d heal=%s avatar=%02X follower=%s",
    s.grp, s.map, s.x, s.y, s.party, s.n, s.region, s.heal, s.avatar, s.follower)
end

local function driveSave()
  F.w16(S.gSaveAttemptStatus, SENTINEL)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_SAVE) then return "noicon" end
  for i = 1, 3000 do
    if F.r16(S.gSaveAttemptStatus) ~= SENTINEL then
      F.idle(30)
      for _ = 1, 6 do F.press("B", 2); F.idle(20) end
      return F.r16(S.gSaveAttemptStatus) == 1 and "done" or "failed"
    end
    if i % 20 == 1 then joypad.set({ A = true }) else joypad.set({}) end
    emu.frameadvance()
  end
  return "timeout"
end

local function softReset()
  for _ = 1, 8 do joypad.set({ A = true, B = true, Start = true, Select = true }); emu.frameadvance() end
  joypad.set({})
end

local function awaitControl(budget)
  for i = 1, budget or 600 do
    if hasControl() then return true end
    if i % 30 == 0 then F.press("B", 2) else F.idle(1) end
  end
  return hasControl()
end

local function continueAndCheck(tag, before, how, probeDir)
  if how == "power" then client.reboot_core() else softReset() end
  F.idle(60)
  local booted = F.boot(nil, true)
  F.check(tag .. ": continued to the field", booted)
  if not booted then return false end
  F.idle(30)
  if F.reportCrash(tag) then F.check(tag .. ": no crash", false); return false end
  local after = snapshot()
  F.L("  before " .. fmt(before))
  F.L("  after  " .. fmt(after))
  F.check(tag .. ": same map and tile", after.grp == before.grp and after.map == before.map
    and after.x == before.x and after.y == before.y, fmt(after))
  F.check(tag .. ": same party", after.party == before.party and after.n == before.n)
  F.check(tag .. ": same region", after.region == before.region, after.region .. " vs " .. before.region)
  F.check(tag .. ": same whiteout point", after.heal == before.heal, after.heal .. " vs " .. before.heal)
  F.check(tag .. ": same avatar state", after.avatar == before.avatar,
    string.format("%02X vs %02X", after.avatar, before.avatar))
  F.check(tag .. ": control returns", awaitControl(600))
  if probeDir then
    local moved = F.step(probeDir)
    F.check(tag .. ": the player can move " .. probeDir, moved, fmt(snapshot()))
  end
  return true
end

local function case(tag, body)
  if ONLY and not tag:find(ONLY, 1, true) then return end
  F.L("== " .. tag .. " ==")
  local ok, err = pcall(body)
  if not ok then F.check(tag .. ": ran without a Lua error", false, tostring(err)) end
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  F.w8(F.sb2() + 0x14, (F.r8(F.sb2() + 0x14) & ~7) | 3)
  F.check("a Lapras leads", createMon(SPECIES_LAPRAS, 10, { MOVE_SURF, MOVE_ICE_BEAM, MOVE_DIVE }) == 1)
  addItem(ITEM_SURF_TOOL, 1); addItem(ITEM_DIVE_TOOL, 1)

  for _, how in ipairs({ "soft", "power" }) do
    case("surfing with a follower (" .. how .. ")", function()
      if not warp(87, 2, 4, "route41") then F.check("warp to Route 41", false); return end
      F.check("arrives surfing", (avatar() & AVATAR_SURFING) ~= 0)
      for _ = 1, 3 do F.step("Down") end
      local before = snapshot()
      F.check("save while surfing", driveSave() == "done")
      continueAndCheck("surfing (" .. how .. ")", before, how, "Down")
      F.L("  follower after a step: " .. follower())
    end)
  end

  -- The debug warp lands underwater on a walled tile (40,40), so this case checks state and
  -- control, not a step.
  case("underwater", function()
    if not warp(0, 50, 0, "underwater124") then F.check("warp underwater", false); return end
    F.L("  avatar " .. string.format("%02X", avatar()))
    local before = snapshot()
    F.check("save underwater", driveSave() == "done")
    continueAndCheck("underwater", before, "soft", nil)
  end)

  case("next to a visible wild Pokemon", function()
    if not warp(75, 2, 0, "route29") then F.check("warp to Route 29", false); return end
    local seen = 0
    local walk = { "Left", "Left", "Down", "Down", "Right", "Right", "Up", "Up" }
    for i = 1, 160 do
      F.w8(S.sOWESpawnCountdown, 0)
      F.step(walk[(i // 3) % #walk + 1])
      seen = countOwes()
      if seen > 0 then break end
    end
    F.check("a visible wild Pokemon spawned", seen > 0, "owes=" .. seen)
    if not os.getenv("PW_CONT_NOSAVE") then
      local before = snapshot()
      F.check("save next to it", driveSave() == "done")
      continueAndCheck("visible wild Pokemon", before, "soft", nil)
    end
    F.L("  owes after continue: " .. countOwes())
    -- Walk at the restored encounter; touching it must start a battle that returns to the field.
    local battled = false
    for _ = 1, 30 do
      local target
      for i = 0, 15 do
        local o = S.gObjectEvents + i * S.ObjectEvent.stride
        if (F.r8(o) & 1) ~= 0 and F.r8(o + 7) == 0xFF then target = o end
      end
      if not target or battled then break end
      local px, py = F.pos()
      local tx, ty = F.rs16(target + 0x10) - 7, F.rs16(target + 0x12) - 7
      local dir = (tx > px and "Right") or (tx < px and "Left") or (ty > py and "Down") or "Up"
      F.press(dir, 16)
      for _ = 1, 120 do
        if F.cb2() == (S.BattleMainCB2 & ~1) then battled = true; break end
        emu.frameadvance()
      end
    end
    F.L("  touched the restored encounter: battle=" .. tostring(battled))
    if battled then
      for i = 1, 20000 do
        if F.ow() and hasControl() then break end
        if i % 120 == 0 and F.reportCrash("owe_battle") then break end
        F.w8(S.gActionSelectionCursor, 0)
        if i % 10 == 0 then F.press("A", 2) else F.idle(1) end
      end
      local back = F.ow() and hasControl()
      if not back then F.shot("owe_battle_stuck") end
      F.check("the restored encounter's battle returns to the field", back,
        string.format("cb2=%08X outcome=%d", F.cb2(), F.outcome()))
    end
  end)

  case("aboard the S.S. Anne", function()
    if not warp(35, 5, 0, "ssanne") then F.check("warp to the S.S. Anne", false); return end
    F.idle(60); awaitControl(600)
    local before = snapshot()
    F.check("save aboard the S.S. Anne", driveSave() == "done")
    continueAndCheck("S.S. Anne", before, "soft", nil)
  end)

  case("aboard the S.S. Aqua", function()
    if not warp(95, 0, 0, "ssaqua") then F.check("warp to the S.S. Aqua", false); return end
    F.idle(60); awaitControl(600)
    local before = snapshot()
    F.check("save aboard the S.S. Aqua", driveSave() == "done")
    continueAndCheck("S.S. Aqua", before, "power", nil)
  end)

  -- The Hub Pass fired from Select while surfing: the hub is indoors, so the player must land on
  -- foot with the follower walking, then save and Continue there.
  case("hub pass while surfing", function()
    if not warp(87, 2, 4, "route41_pass") then F.check("warp to Route 41", false); return end
    F.check("surfing before the Hub Pass", (avatar() & AVATAR_SURFING) ~= 0)
    addItem(ITEM_HUB_RETURN, 1)
    F.w16(F.sb1() + S.SaveBlock1.registeredItem, ITEM_HUB_RETURN)
    F.press("Select", 2); F.idle(90)
    -- The confirm's cursor rests on NO; Up before each A answers YES once the box is up.
    for _ = 1, 40 do
      if F.grp() == HUB_GROUP then break end
      F.press("Up", 2); F.idle(10); F.press("A", 2); F.idle(20)
    end
    F.idle(120)
    F.check("the Hub Pass reached the hub", F.grp() == HUB_GROUP, string.format("%d/%d", F.grp(), F.mapn()))
    F.check("hub control returns", awaitControl(600))
    F.check("on foot in the hub", (avatar() & (AVATAR_SURFING | AVATAR_UNDERWATER)) == 0,
      string.format("avatar=%02X follower=%s", avatar(), follower()))
    F.check("the player can walk in the hub", F.step("Down"))
    local before = snapshot()
    F.check("save in the hub", driveSave() == "done")
    continueAndCheck("hub after the pass", before, "power", "Up")
  end)

  F.finish()
end)
