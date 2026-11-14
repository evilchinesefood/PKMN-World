-- The Safari Zone's ways out in Kanto, Johto and Hoenn, driven through the real scripts. Setup gives
-- one Pokemon and a Pokeblock case and sets the wallet; the attendant, the step that ends the clock,
-- the pay-to-continue prompt, the out-of-balls prompt after a real wild battle, the walk back through
-- the entrance and the start menu's RETIRE are real input. The step counter and ball count are
-- lowered in RAM to one left, which is what 599 steps or 29 throws leave.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/SafariStress.lua
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SafariStress")

local FLAG_SYS_POKEMON_GET = 0x948
local FLAG_SYS_SAFARI_MODE = 0x948 + 0x2C
local VAR_KANTO_SCENE = 0xA000 + 0x47
local ROW_GIVE, ROW_MON_BASIC = 3, 1
local ONLY = os.getenv("PW_SAFARI_ONLY")

local ITEM_POKEBLOCK_CASE = 722
local USM_ICO_RETIRE = 10

local K = {
  name = "kanto", entG = 45, entM = 0, zoneG = 35, zoneM = 63, steps = 600,
  warp = { 0, 4, 5, 0, 0, 0, 0, 0, 2 }, approach = { { 4, 4 } }, trigger = "Up", arrive = { 26, 30 },
  grassPath = { { 26, 29 }, { 33, 29 }, { 33, 28 } }, grass = { { 33, 28 }, { 34, 28 } },
}
local J = {
  name = "johto", entG = 96, entM = 2, zoneG = 96, zoneM = 4, steps = 500,
  warp = { 0, 9, 6, 0, 0, 2, 0, 0, 1 }, approach = { { 9, 3 } }, trigger = "Up", arrive = { 14, 9 },
}
local H = {
  name = "hoenn", entG = 23, entM = 0, zoneG = 26, zoneM = 3, steps = 500,
  warp = { 0, 2, 3, 0, 0, 0, 0, 0, 2 }, approach = { { 14, 4 }, { 9, 4 } }, trigger = "Left", arrive = { 32, 34 },
  grassPath = { { 32, 35 }, { 28, 35 }, { 28, 33 }, { 27, 33 } }, grass = { { 27, 33 }, { 26, 33 } },
}

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function key() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) end
local function money() return F.r32(F.sb1() + S.SaveBlock1.money) ~ key() end
local function setMoney(v) F.w32(F.sb1() + S.SaveBlock1.money, v ~ key()) end
local function balls() return F.r8(S.gNumSafariBalls) end
local function steps() return F.r16(S.gSafariZoneStepCounter) end
local function sb1Flag(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + (id // 8), 1 << (id % 8)
  if on == nil then return (F.r8(a) & m) ~= 0 end
  F.w8(a, on and (F.r8(a) | m) or (F.r8(a) & ~m & 0xFF))
end
local function safari() return sb1Flag(FLAG_SYS_SAFARI_MODE) end
local function regionVar(id) return F.r16(F.sb3() + S.SaveBlock3.regionVars + (id - 0xA000) * 2) end
local function scriptLive()
  local p = F.r32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr)
  return F.r8(S.sGlobalScriptContextStatus) ~= 2 and p >= 0x08000000 and p < 0x0A000000
end
local function count() return F.r8(S.gPartiesCount) end
local function on(g, m) return F.grp() == g and F.mapn() == m end

local function tapDown(n) for _ = 1, n do F.press("Down", 3); F.idle(16) end end
local function give(sp)
  F.dbg(); F.idle(60)
  tapDown(ROW_GIVE); F.press("A", 3); F.idle(50)
  tapDown(ROW_MON_BASIC); F.press("A", 3); F.idle(40)
  F.press("Right", 2); F.idle(10)
  for _ = 1, (sp // 10) % 10 do F.press("Up", 2); F.idle(8) end
  F.press("Left", 2); F.idle(10)
  for _ = 1, sp % 10 - 1 do F.press("Up", 2); F.idle(8) end
  F.press("A", 3); F.idle(30)
  F.press("A", 3); F.idle(80)
  for _ = 1, 10 do F.press("B", 3); F.idle(20) end
end

-- Mash a button until the overworld is idle (no script, field controls free) for a while.
local function settle(btn, maxPresses)
  local calm = 0
  for _ = 1, maxPresses or 200 do
    if F.reportCrash("settle") then return false end
    if F.ow() and not scriptLive() and F.r8(S.sLockFieldControls) == 0 then
      calm = calm + 1
      if calm >= 4 then return true end
      F.idle(20)
    else
      calm = 0
      F.press(btn, 2); F.idle(18)
    end
  end
  return false
end

local function enter(z)
  if not on(z.entG, z.entM) and not F.warpTo(z.warp[1], z.warp[2], z.warp[3], z.warp[4], z.warp[5], z.warp[6],
      z.warp[7], z.warp[8], z.warp[9], z.entG, z.entM, z.name .. "_entrance") then
    return F.check(z.name .. ": warp to the entrance", false, where())
  end
  settle("B", 30)
  for _, p in ipairs(z.approach) do F.leg(p[1], p[2]) end
  F.step(z.trigger)
  for _ = 1, 400 do
    F.press("A", 2); F.idle(18)
    if on(z.zoneG, z.zoneM) and F.ow() then break end
  end
  settle("B", 60)
  return F.check(z.name .. ": the attendant lets the player in", on(z.zoneG, z.zoneM) and safari(), where())
end

local BACK = { Up = "Down", Down = "Up", Left = "Right", Right = "Left" }
local function free()
  if not F.ow() or scriptLive() then return false end
  for _, d in ipairs({ "Right", "Down", "Up", "Left" }) do
    if F.step(d) then return F.step(BACK[d]) end
  end
  return false
end

local function assertOut(z, tag)
  F.shot(z.name .. "_" .. tag)
  F.check(z.name .. " " .. tag .. ": the player is back in the entrance", on(z.entG, z.entM), where())
  F.check(z.name .. " " .. tag .. ": Safari mode is off", not safari(), string.format("balls=%d steps=%d", balls(), steps()))
  F.check(z.name .. " " .. tag .. ": the field is free", free(), where())
  if z.name == "kanto" then
    F.check(z.name .. " " .. tag .. ": the exit scene is cleared", regionVar(VAR_KANTO_SCENE) == 0, "scene=" .. regionVar(VAR_KANTO_SCENE))
  end
  F.check(z.name .. " " .. tag .. ": no crash", not F.crashScreen())
end

local function openRetire()
  for _ = 1, 4 do
    F.press("Start", 2); F.idle(90)
    if F.selectStartIcon(USM_ICO_RETIRE) then return true end
    for _ = 1, 6 do F.press("B", 3); F.idle(20) end
  end
  return false
end

local function stepOut()
  return F.step("Up") or F.step("Down") or F.step("Left") or F.step("Right")
end

-- Leave through the zone's own exit and answer its prompt with btn (A = leave, B = stay).
local function walkOut(z, btn)
  if z.name ~= "hoenn" then
    F.leg(z.arrive[1], z.arrive[2] - 1)
    F.step("Down")
    for _ = 1, 60 do
      if not on(z.zoneG, z.zoneM) then break end
      joypad.set({ Down = true }); emu.frameadvance()
    end
  else
    F.leg(32, 35)
    F.face("Up")
    F.press("A", 3); F.idle(40)
    settle("B", 60)
    F.face("Up")
    F.press("A", 3); F.idle(60)
  end
  return settle(btn, 200)
end

local function timesUp(z, btn, wallet)
  setMoney(wallet)
  F.w16(S.gSafariZoneStepCounter, 1)
  stepOut()
  return settle(btn, 200)
end

local function scenarios(z)
  local function want(tag) return not ONLY or (z.name .. "_" .. tag):find(ONLY, 1, true) end

  if want("pay") then
    setMoney(5000)
    if enter(z) then
      F.w8(S.gNumSafariBalls, 7)
      timesUp(z, "A", 5000)
      F.shot(z.name .. "_paid")
      F.check(z.name .. " pay: the player stays in the zone", on(z.zoneG, z.zoneM) and safari(), where())
      F.check(z.name .. " pay: 500 is taken", money() == 4500, "money=" .. money())
      F.check(z.name .. " pay: the clock and balls are refilled", balls() == 30 and steps() >= z.steps - 2,
        string.format("balls=%d steps=%d", balls(), steps()))
      F.check(z.name .. " pay: no crash", not F.crashScreen())
      timesUp(z, "B", 4500)
      assertOut(z, "decline")
      F.check(z.name .. " decline: no money is taken", money() == 4500, "money=" .. money())
    end
  end

  if want("broke") then
    setMoney(5000)
    if enter(z) then
      timesUp(z, "A", 499)
      assertOut(z, "broke")
      F.check(z.name .. " broke: the wallet is untouched", money() == 499, "money=" .. money())
    end
  end

  if want("early") then
    setMoney(5000)
    if enter(z) then
      walkOut(z, "B")
      F.shot(z.name .. "_early_no")
      F.check(z.name .. " early/no: the player is back in the zone", on(z.zoneG, z.zoneM) and safari(), where())
      F.check(z.name .. " early/no: no crash", not F.crashScreen())
      walkOut(z, "A")
      assertOut(z, "early")
    end
  end

  if want("retire") then
    setMoney(5000)
    if enter(z) then
      F.check(z.name .. " retire: the start menu offers RETIRE", openRetire(), where())
      F.press("A", 3); F.idle(60)
      for _ = 1, 60 do
        if not scriptLive() then break end
        F.press("B", 2); F.idle(18)
      end
      F.idle(30)
      F.shot(z.name .. "_retire_no")
      local x0, y0 = F.pos()
      local walked = F.step("Up") or F.step("Right") or F.step("Left") or F.step("Down")
      F.check(z.name .. " retire/no: the start menu comes back", F.r32(S.sUsmMemory) ~= 0, where())
      F.check(z.name .. " retire/no: the player cannot walk under the menu", not walked,
        string.format("from (%d,%d) to %s", x0, y0, where()))
      F.press("Start", 2); F.idle(60)
      for _ = 1, 20 do
        if F.r32(S.sUsmMemory) == 0 and F.r8(S.sLockFieldControls) == 0 then break end
        F.press("B", 3); F.idle(30)
      end
      F.check(z.name .. " retire/no: B closes the menu", F.r32(S.sUsmMemory) == 0, where())
      F.check(z.name .. " retire/no: the player stays in the zone", on(z.zoneG, z.zoneM) and safari(), where())
      F.check(z.name .. " retire/no: the field is free", free(), where())
      F.check(z.name .. " retire/no: no crash", not F.crashScreen())
      F.check(z.name .. " retire: RETIRE is offered again", openRetire(), where())
      F.press("A", 3); F.idle(60)
      settle("A", 200)
      assertOut(z, "retire")
    end
  end

  if want("balls") and z.grass then
    setMoney(5000)
    if enter(z) then
      local p = z.grassPath
      for i = 1, #p do F.leg(p[i][1], p[i][2]) end
      F.w8(S.gNumSafariBalls, 1)
      F.w16(S.gSafariZoneStepCounter, 400)
      local fought = false
      for i = 1, 300 do
        local g = z.grass[(i % 2) + 1]
        F.leg(g[1], g[2])
        if not F.ow() then fought = true; break end
      end
      F.check(z.name .. " balls: a wild Safari battle starts", fought, where())
      if fought then
        for _ = 1, 400 do
          if balls() == 0 then break end
          F.press("A", 2); F.idle(20)
        end
        F.check(z.name .. " balls: the last ball is thrown", balls() == 0, "balls=" .. balls())
        local before = count()
        settle("B", 400)
        F.L(string.format("  %s balls: outcome=%d party %d->%d", z.name, F.outcome(), before, count()))
        if F.outcome() == 7 then
          F.check(z.name .. " balls: the last-ball catch joins the party", count() == before + 1, "count=" .. count())
        end
        assertOut(z, "balls")
      end
    end
  end
end

local function giveKeyItem(id)
  local ptr, k = F.r32(S.gBagPockets + 4 * S.BagPocket.stride), F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF
  for s = 0, F.pocketCap(4) - 1 do
    if F.r16(ptr + s * 4) == id then return true end
  end
  for s = 0, F.pocketCap(4) - 1 do
    if F.r16(ptr + s * 4) == 0 then F.w16(ptr + s * 4, id); F.w16(ptr + s * 4 + 2, 1 ~ k); return true end
  end
  return false
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  sb1Flag(FLAG_SYS_POKEMON_GET, true)
  give(16)
  F.check("setup: one Pokemon in the party", count() == 1, "count=" .. count())
  F.check("setup: a Pokeblock case for the Johto and Hoenn counters", giveKeyItem(ITEM_POKEBLOCK_CASE))
  for _, z in ipairs({ K, J, H }) do scenarios(z) end
  F.finish()
end)
