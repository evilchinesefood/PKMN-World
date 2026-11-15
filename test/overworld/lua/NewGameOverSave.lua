-- New Game over a played save, without a power cycle.
--
-- A fresh new game is dumped twice (the second after a soft reset, so the bytes that come from
-- the RNG and the frame count differ between the two). The file is then played forward: a team,
-- money, items, story flags, the whole Pokedex, Shared Exp, a non-default outfit and a real
-- World Transit gate crossing into Johto, saved from the Start menu. After a soft reset the title
-- menu's NEW GAME starts over that loaded save. No byte of SaveBlock1, SaveBlock2, SaveBlock3 or
-- the PC may then still hold the played file's value where both fresh games agree on another one,
-- except the options and intro fields the title menu keeps by design (KEPT below). Bytes that
-- differ from the fresh games without matching the played file come from the RNG and are logged.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/NewGameOverSave.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "NewGameOverSave")

local HUB = { 100, 0 }
local JOHTO_GATE_X, JOHTO_ARRIVAL = 16, { 84, 23 }
local USM_ICO_SAVE = 7
local SENTINEL = 0xFFFF
local CONTEXT_RUNNING = 0
local ASLR_SLACK = 128
local POCKETS_COUNT = 5
local SPECIES_ABRA, SPECIES_RATTATA = 63, 19
local VAR_PLAYER_PALETTE = 0x40FC
local FLAG_QOL_SHARED_EXP = 0x21

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0
    and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function awaitControl(budget)
  for i = 1, budget or 600 do
    if hasControl() then return true end
    if i % 30 == 0 then F.press("B", 2) else F.idle(1) end
  end
  return hasControl()
end
local function drain()
  for _ = 1, 30 do
    F.press("B", 2); F.idle(16)
    if F.ensureFree() then return true end
  end
  return false
end
local function mapIs(g, m) return F.grp() == g and F.mapn() == m end

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
  b[#b + 1] = 0; b[#b + 1] = 6
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
local function setVar(id, v)
  runScript({ 0x16, id & 0xFF, id >> 8, v & 0xFF, v >> 8, 0x02 }); F.idle(10)
end
local function setFlag(id)
  runScript({ 0x29, id & 0xFF, id >> 8, 0x02 }); F.idle(10)
end
local function flag(id)
  local base, offset = F.sb1() + S.SaveBlock1.flags, id
  if id >= 0x6000 and id < 0x6400 then base = F.sb3() + S.SaveBlock3.johtoFlags; offset = id - 0x6000 end
  F.w8(base + offset // 8, F.r8(base + offset // 8) | (1 << (offset % 8)))
end

local function scriptMenuActive()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    local fn = F.r32(a + S.Task.func) & 0xFFFFFFFE
    if F.r8(a + S.Task.isActive) ~= 0 and (fn == S.Task_HandleYesNoInput or fn == S.Task_HandleMultichoiceInput
       or fn == S.Task_CallYesOrNoCallback) then return true end
  end
  return false
end
local function menu(want, tag)
  for _ = 1, 65 do
    if F.reportCrash(tag) then return false end
    if scriptMenuActive() then
      F.idle(12)
      for _ = 1, 10 do
        local c = F.mcur()
        if c == want then
          for _ = 1, 4 do
            F.press("A", 2)
            for _ = 1, 30 do
              if not scriptMenuActive() then F.idle(30); return true end
              F.idle(1)
            end
          end
          return false
        end
        F.press(c > want and "Up" or "Down", 2); F.idle(12)
      end
      return false
    end
    F.press("A", 2); F.idle(25)
  end
  F.shot(tag .. "_nomenu")
  return false
end
local function awaitMap(g, m, tag)
  for _ = 1, 220 do
    if mapIs(g, m) then F.idle(100); return true end
    if F.reportCrash(tag) then return false end
    F.press("A", 2); F.idle(14)
  end
  F.shot(tag .. "_failed")
  return false
end
local function crossToJohto()
  if not F.route({ { 16, 4 }, { JOHTO_GATE_X, 4 }, { JOHTO_GATE_X, 3 } }, "gate_walk") then return false end
  F.face("Up"); F.press("A", 3); F.idle(60)
  if not menu(1, "gate_team") then return false end
  if not menu(1, "gate_arrival") then return false end
  if not menu(0, "gate_confirm") then return false end
  return awaitMap(JOHTO_ARRIVAL[1], JOHTO_ARRIVAL[2], "gate") and awaitControl(600)
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

-- The main menu task: tMenuType = data[0], tCurrItem = data[1], tItemCount = data[12].
local function menuTask()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    if F.r8(a + S.Task.isActive) ~= 0 and (F.r32(a + S.Task.func) & 0xFFFFFFFE) == S.Task_HandleMainMenuInput then
      return a + S.Task.data
    end
  end
end
local function pickNewGame()
  local d
  for f = 1, 20000 do
    d = menuTask()
    if d then break end
    if f % 40 == 0 then F.press("Start", 2) else F.idle(1) end
  end
  if not d then return false, "no main menu" end
  F.idle(60)
  local items = F.rs16(d + 24)
  for _ = 1, 6 do
    if F.rs16(d + 2) == 1 then break end
    F.press("Down", 2); F.idle(20)
  end
  F.shot("main_menu_new_game")
  if F.rs16(d + 2) ~= 1 then return false, "cursor " .. F.rs16(d + 2) end
  F.press("A", 2); F.idle(30)
  return true, "items=" .. items
end

-- Save block images. SaveBlock1, SaveBlock2 and the PC move inside an ASLR window, so they are read
-- from their pointers for the struct size; SaveBlock3 is fixed.
local function blocks()
  return {
    { name = "SaveBlock1", base = F.sb1(), size = S.gSaveblock1_size - ASLR_SLACK },
    { name = "SaveBlock2", base = F.sb2(), size = S.gSaveblock2_size - ASLR_SLACK },
    { name = "SaveBlock3", base = F.sb3(), size = S.gSaveblock3_size },
    { name = "PC", base = F.r32(S.gPokemonStoragePtr), size = S.gPokemonStorage_size - ASLR_SLACK },
  }
end
-- Money, coins, game stats, Berry Powder and bag quantities are XORed with an encryption key that
-- every map load rerolls, so they are compared decrypted: XOR the key back out of each field.
local function decrypt(img)
  local key = F.r32(F.sb2() + S.SaveBlock2.encryptionKey)
  local function x(block, off, n)
    for k = 0, n - 1 do
      local i = off + k + 1
      img[block][i] = img[block][i] ~ ((key >> (8 * k)) & 0xFF)
    end
  end
  x("SaveBlock1", S.SaveBlock1.money, 4)
  x("SaveBlock1", S.SaveBlock1.coins, 2)
  for s = 0, 63 do x("SaveBlock1", S.SaveBlock1.gameStats + 4 * s, 4) end
  x("SaveBlock2", S.SaveBlock2.berryPowder, 4)
  x("SaveBlock2", S.SaveBlock2.encryptionKey, 4)
  local sb1 = F.sb1()
  for p = 0, POCKETS_COUNT - 1 do
    local slots = F.r32(S.gBagPockets + p * S.BagPocket.stride + S.BagPocket.itemsPtr)
    for k = 0, F.pocketCap(p) - 1 do x("SaveBlock1", slots + 4 * k + 2 - sb1, 2) end
  end
end
local function dump()
  local img = {}
  for _, b in ipairs(blocks()) do
    local t = {}
    for i = 0, b.size - 1 do t[i + 1] = F.r8(b.base + i) end
    img[b.name] = t
  end
  decrypt(img)
  return img
end

-- Bytes New Game keeps from the loaded file by design, as {first, last, mask}: the player's name and
-- gender (the intro rewrites them), the options the title menu sets (0x13..0x17), the RTC offset
-- and berry clock, the region checksum (restamped by every save before it is written), and the
-- Shared Exp flag, a title-menu option that lives in SaveBlock1 (src/new_game.c).
local KEPT = {
  SaveBlock1 = { { S.SaveBlock1.flags + FLAG_QOL_SHARED_EXP // 8, S.SaveBlock1.flags + FLAG_QOL_SHARED_EXP // 8,
                   1 << (FLAG_QOL_SHARED_EXP % 8) } },
  SaveBlock2 = { { 0x00, 0x09, 0xFF }, { 0x13, 0x17, 0xFF }, { 0x94, 0x95, 0xFF }, { 0x98, 0xA7, 0xFF } },
}
local function keptMask(name, off)
  for _, r in ipairs(KEPT[name] or {}) do
    if off >= r[1] and off <= r[2] then return r[3] end
  end
  return 0
end

-- A leaked bit: both fresh games agree on it, the played file changed it, and the New Game over
-- that file still holds the played value. RNG bytes the play did not reroll match fresh2 in the
-- played file, so they can never qualify; they are logged when they differ from the fresh games.
local function compare(fresh1, fresh2, prog, over)
  local leaks, total = 0, 0
  for _, b in ipairs(blocks()) do
    local a1, a2, p, o = fresh1[b.name], fresh2[b.name], prog[b.name], over[b.name]
    local runs, run = {}, nil
    for i = 1, #a1 do
      local off = i - 1
      local care = ~keptMask(b.name, off) & 0xFF
      local leak = ~(a1[i] ~ a2[i]) & (p[i] ~ a2[i]) & ~(o[i] ~ p[i]) & care & 0xFF
      local differs = (a1[i] & care) == (a2[i] & care) and (o[i] & care) ~= (a1[i] & care)
      if leak ~= 0 or differs then
        if run and run.last == off - 1 then run.last = off else run = { first = off, last = off }; runs[#runs + 1] = run end
        if leak ~= 0 then run.leaked = true end
      end
    end
    local mine = 0
    for _, r in ipairs(runs) do
      local f, pv, ov = {}, {}, {}
      for i = r.first + 1, math.min(r.last + 1, r.first + 12) do
        f[#f + 1] = string.format("%02X", a1[i]); pv[#pv + 1] = string.format("%02X", p[i])
        ov[#ov + 1] = string.format("%02X", o[i])
      end
      F.L(string.format("  %s+0x%04X..0x%04X (%d) fresh=%s played=%s newgame=%s%s", b.name, r.first, r.last,
        r.last - r.first + 1, table.concat(f), table.concat(pv), table.concat(ov), r.leaked and " LEAKED" or ""))
      total = total + 1
      if r.leaked then mine = mine + 1 end
    end
    leaks = leaks + mine
    F.check(b.name .. ": New Game keeps none of the played save's bits", mine == 0,
      mine .. " leaked run(s), " .. (#runs - mine) .. " RNG run(s)")
  end
  return leaks, total
end

local function bootNewGame(tag)
  local ok = F.boot(HUB[1])
  F.check(tag .. ": the new game reaches the World Transit hub", ok and mapIs(HUB[1], HUB[2]),
    string.format("%d/%d", F.grp(), F.mapn()))
  return ok
end

F.run(function()
  if not bootNewGame("fresh") then F.finish(); return end
  local fresh1 = dump()

  -- A different frame count at the title gives the second game a different RNG seed, so the
  -- bytes drawn from the RNG (trainer id, Dewford trend, Lilycove lady...) differ between them.
  softReset(); F.idle(90 + 173)
  if not bootNewGame("fresh again") then F.finish(); return end
  local fresh2 = dump()
  F.check("fresh: the second fresh game has no save behind it", F.r8(S.gSaveFileStatus) ~= 1,
    "status=" .. F.r8(S.gSaveFileStatus))

  F.check("played: a two-Pokemon team", createMon(SPECIES_ABRA, 30, { 100, 91, 19 }) == 1
    and createMon(SPECIES_RATTATA, 12, { 33 }) == 2)
  addItem(1, 20)      -- Poke Ball
  addItem(28, 9)      -- Potion
  addItem(135, 3)     -- Nugget
  F.w32(F.sb1() + S.SaveBlock1.money, 123456 ~ F.r32(F.sb2() + S.SaveBlock2.encryptionKey))
  for _, id in ipairs({ 0x94F, 0x950, 0x951 }) do setFlag(id) end   -- Hoenn badges 1-3
  setFlag(FLAG_QOL_SHARED_EXP)
  setVar(VAR_PLAYER_PALETTE, 1)
  F.dbg(); F.sel(7); F.sel(2); F.bOut(4)   -- Flags & Vars > Pokedex Flags All
  drain()
  -- Openings and first badges in all three regions, as TravelSaveContinue seeds them.
  for _, id in ipairs({ 0xDCF, 0x51, 0xA4B, 0x63F8, 0x94F, 0x95F, 0xA4D, 0x63FD, 0x954, 0x948,
                        0xD40, 0xD45, 0x6088, 0x60EA, 0x957, 0x95C, 0xA4A }) do flag(id) end
  F.w8(F.sb2() + S.SaveBlock2.introDoneBits, 7)
  F.check("played: crossed the World Transit gate into Johto", crossToJohto(),
    string.format("%d/%d", F.grp(), F.mapn()))
  F.check("played: the region is Johto", F.r8(F.sb2() + S.SaveBlock2.currentRegion) == 2,
    "region=" .. F.r8(F.sb2() + S.SaveBlock2.currentRegion))
  local status = driveSave()
  F.check("played: saved from the Start menu", status == "done", status)
  local prog = dump()
  F.shot("played_saved")

  softReset(); F.idle(90)
  local picked, detail = pickNewGame()
  F.check("over: the title menu offers CONTINUE and NEW GAME is picked", picked, detail)
  if not picked then F.finish(); return end
  if not bootNewGame("over") then F.finish(); return end
  F.shot("over_hub")
  local over = dump()

  local leaks, total = compare(fresh1, fresh2, prog, over)
  F.L(string.format("  %d differing run(s), %d of them hold the played save's bytes", total, leaks))
  F.check("over: Shared Exp, a title-menu option, carries over", (F.r8(F.sb1() + S.SaveBlock1.flags
    + FLAG_QOL_SHARED_EXP // 8) >> (FLAG_QOL_SHARED_EXP % 8)) & 1 == 1)
  F.check("over: the outfit is the intro's pick, not the played file's", F.r16(F.sb1() + S.SaveBlock1.vars
    + (VAR_PLAYER_PALETTE - 0x4000) * 2) == 0)
  F.check("over: party is empty", F.r8(S.gPartiesCount) == 0, "count=" .. F.r8(S.gPartiesCount))
  F.check("over: money is the new-game 3000", F.money() == 3000, "money=" .. F.money())
  F.check("over: region is unset until a gate", F.r8(F.sb2() + S.SaveBlock2.currentRegion) == 0,
    "region=" .. F.r8(F.sb2() + S.SaveBlock2.currentRegion))
  F.check("over: the player can walk", awaitControl(600) and F.step("Down"))
  F.finish()
end)
