-- The Safari Zone's pay-to-continue prompt with the party and every PC box full. The entrances
-- refuse a player with no room (no Safari Ball can be thrown then: battle_main.c answers each
-- throw with BattleScript_PrintFullBox), but a catch into the last free box slot fills the
-- storage mid-game. The continue prompt then took 500 for 30 balls that could not be thrown.
--
-- Setup fills the party and the boxes through the debug menu and frees one box slot so the real
-- attendant lets the player in. Inside, the freed slot is refilled, which is the storage a catch
-- into that slot leaves. The step counter is lowered to one, as 599 steps would leave it, and the
-- times-up prompt is answered Yes with 5000 in the wallet.
--
-- Discrimination: on a build without the storage check in data/scripts/safari_zone.inc the
-- player pays 500 and stays in the zone, so both "wallet untouched" checks fail.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/SafariFullStorage.lua
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SafariFullStorage")

local FLAG_SYS_POKEMON_GET = 0x948
local FLAG_SYS_SAFARI_MODE = 0x948 + 0x2C
local ITEM_POKEBLOCK_CASE = 722
local BOXES, PER_BOX, BOX_MON = 14, 30, S.BoxPokemon.size
local FREED_BOX, FREED_SLOT = BOXES - 1, PER_BOX - 1

local K = {
  name = "kanto", entG = 45, entM = 0, zoneG = 35, zoneM = 63,
  warp = { 0, 4, 5, 0, 0, 0, 0, 0, 2 }, approach = { { 4, 4 } }, trigger = "Up",
}
local H = {
  name = "hoenn", entG = 23, entM = 0, zoneG = 26, zoneM = 3,
  warp = { 0, 2, 3, 0, 0, 0, 0, 0, 2 }, approach = { { 14, 4 }, { 9, 4 } }, trigger = "Left",
}

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function key() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) end
local function money() return F.r32(F.sb1() + S.SaveBlock1.money) ~ key() end
local function setMoney(v) F.w32(F.sb1() + S.SaveBlock1.money, v ~ key()) end
local function balls() return F.r8(S.gNumSafariBalls) end
local function sb1Flag(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + (id // 8), 1 << (id % 8)
  if on == nil then return (F.r8(a) & m) ~= 0 end
  F.w8(a, on and (F.r8(a) | m) or (F.r8(a) & ~m & 0xFF))
end
local function safari() return sb1Flag(FLAG_SYS_SAFARI_MODE) end
local function count() return F.r8(S.gPartiesCount) end
local function on(g, m) return F.grp() == g and F.mapn() == m end
local function scriptLive()
  local p = F.r32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr)
  return F.r8(S.sGlobalScriptContextStatus) ~= 2 and p >= 0x08000000 and p < 0x0A000000
end

local function storage() return F.r32(S.gPokemonStoragePtr) end
local function boxSlot(box, slot) return storage() + 4 + (box * PER_BOX + slot) * BOX_MON end
local function occupied(a) return F.r32(a) ~= 0 or F.r32(a + 4) ~= 0 end
local function boxCount()
  local n = 0
  for box = 0, BOXES - 1 do for slot = 0, PER_BOX - 1 do if occupied(boxSlot(box, slot)) then n = n + 1 end end end
  return n
end
local function bytes(a, n)
  local t = {}
  for i = 0, n - 1 do t[#t + 1] = F.r8(a + i) end
  return t
end
local function putBytes(a, t) for i = 1, #t do F.w8(a + i - 1, t[i]) end end
local function clearSlot(a) for o = 0, BOX_MON - 4, 4 do F.w32(a + o, 0) end end

local function tapDown(n) for _ = 1, n do F.press("Down", 3); F.idle(16) end end
local function drain(tries)
  for i = 1, tries or 40 do
    F.press("B", 3); F.idle(20)
    if i % 5 == 0 and F.ensureFree() then return true end
  end
  return F.ensureFree()
end
local function debugAction(path, tag)
  F.dbg(); F.idle(60)
  for i, row in ipairs(path) do
    tapDown(row); F.press("A", 3); F.idle(i == #path and 240 or 60)
  end
  if not drain(20) then F.L("  debug action " .. tag .. " did not return to the field") return false end
  return true
end
local function give(sp)
  F.dbg(); F.idle(60)
  tapDown(3); F.press("A", 3); F.idle(50)
  tapDown(1); F.press("A", 3); F.idle(40)
  F.press("Right", 2); F.idle(10)
  for _ = 1, (sp // 10) % 10 do F.press("Up", 2); F.idle(8) end
  F.press("Left", 2); F.idle(10)
  for _ = 1, sp % 10 - 1 do F.press("Up", 2); F.idle(8) end
  F.press("A", 3); F.idle(30)
  F.press("A", 3); F.idle(80)
  for _ = 1, 10 do F.press("B", 3); F.idle(20) end
  drain(20)
end
local function giveKeyItem(id)
  local ptr, k = F.r32(S.gBagPockets + 4 * S.BagPocket.stride), key() & 0xFFFF
  for s = 0, F.pocketCap(4) - 1 do
    if F.r16(ptr + s * 4) == id then return true end
  end
  for s = 0, F.pocketCap(4) - 1 do
    if F.r16(ptr + s * 4) == 0 then F.w16(ptr + s * 4, id); F.w16(ptr + s * 4 + 2, 1 ~ k); return true end
  end
  return false
end

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
  return F.check(z.name .. ": the attendant lets the player in with one free box slot",
    on(z.zoneG, z.zoneM) and safari(), where())
end

local function stepOut()
  return F.step("Up") or F.step("Down") or F.step("Left") or F.step("Right")
end

local function scenario(z, parkedBytes)
  clearSlot(boxSlot(FREED_BOX, FREED_SLOT))
  F.check(z.name .. ": setup: one box slot is free", boxCount() == BOXES * PER_BOX - 1, "boxed=" .. boxCount())
  setMoney(5000)
  if not enter(z) then return end
  putBytes(boxSlot(FREED_BOX, FREED_SLOT), parkedBytes)
  setMoney(5000)
  F.check(z.name .. ": setup: a catch has filled the last box slot", boxCount() == BOXES * PER_BOX and count() == 6,
    string.format("boxed=%d party=%d", boxCount(), count()))
  F.w16(S.gSafariZoneStepCounter, 1)
  stepOut()
  settle("A", 200)
  F.shot(z.name .. "_after_prompt")
  F.check(z.name .. ": the wallet is untouched", money() == 5000, "money=" .. money())
  F.check(z.name .. ": the game ends instead of refilling balls nobody can throw",
    on(z.entG, z.entM) and not safari(), string.format("%s balls=%d safari=%s", where(), balls(), tostring(safari())))
  F.check(z.name .. ": the field is free", F.ow() and not scriptLive(), where())
  F.check(z.name .. ": no crash", not F.crashScreen())
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  sb1Flag(FLAG_SYS_POKEMON_GET, true)
  F.check("setup: debug Set Party ran", debugAction({ 2, 9 }, "set_party") and count() >= 1, "count=" .. count())
  for _, sp in ipairs({ 19, 21, 27, 29, 32 }) do if count() < 6 then give(sp) end end
  F.check("setup: a full party of six", count() == 6, "count=" .. count())
  F.check("setup: debug Fill PC Boxes Fast ran", debugAction({ 1, 1, 0 }, "fill_pc") and boxCount() == BOXES * PER_BOX,
    "boxed=" .. boxCount())
  F.check("setup: a Pokeblock case for the Hoenn counter", giveKeyItem(ITEM_POKEBLOCK_CASE))
  local parkedBytes = bytes(boxSlot(FREED_BOX, FREED_SLOT), BOX_MON)
  for _, z in ipairs({ K, H }) do scenario(z, parkedBytes) end
  F.finish()
end)
