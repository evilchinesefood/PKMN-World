-- The Regi chain with real input. The Sealed Chamber's back wall is read with Wailord first and
-- Relicanth last, which opens the tombs. In the Desert Ruins Rock Smash is used from the field
-- party menu on the braille spot, and in the Ancient Tomb Flash, each of which must open the inner
-- wall. The player then walks through, talks to the Regi and runs from the battle: the Regi must
-- fly away with its defeated flag clear and be back when the tomb is entered again. A wrong party
-- order must leave the Sealed Chamber shut, and using the move one tile off the spot must not open
-- a tomb.
--
-- Run: test/overworld/mgba-run.sh test/overworld/lua/HoennRegiPuzzles.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "HoennRegiPuzzles")

local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local MAIN_VBLANK_COUNTER1 = 0x20
local SYS = 0x948
local FLAG_BADGE = { SYS + 7, SYS + 8, SYS + 9, SYS + 10, SYS + 11, SYS + 12, SYS + 13, SYS + 14 }
local FLAG_SYS_POKEMON_GET = SYS
local FLAG_REGI_DOORS_OPENED = 0xE4
local FLAG_SYS_REGIROCK_PUZZLE_COMPLETED, FLAG_SYS_REGISTEEL_PUZZLE_COMPLETED = SYS + 0x50, SYS + 0x52
local FLAG_DEFEATED_REGIROCK, FLAG_DEFEATED_REGISTEEL = 0x1BB, 0x1BD
local VAR_REPEL_STEP_COUNT = 0x4021
local SPECIES_WAILORD, SPECIES_RELICANTH, SPECIES_WOBBUFFET = 321, 369, 202
local MOVE_ROCK_SMASH, MOVE_FLASH = 249, 148
local USM_ICO_PARTY = 1
local B_OUTCOME_RAN = 4
local G = 24
local MAP_DESERT_RUINS, MAP_ANCIENT_TOMB, MAP_SEALED_INNER = 6, 68, 72

local OFF_CHECKSUM, OFF_SECURE = 28, 32
local SUB_STRIDE, NRAW = 12, 12
local SUB0 = { [0]=0,0,0,0,0,0,1,1,2,3,2,3,1,1,2,3,2,3,1,1,2,3,2,3 }
local SUB1 = { [0]=1,1,2,3,2,3,0,0,0,0,0,0,2,3,1,1,3,2,2,3,1,1,3,2 }

local function vblank() return F.r32(S.gMain + MAIN_VBLANK_COUNTER1) end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function flagGet(id) return (F.r8(F.sb1() + S.SaveBlock1.flags + (id // 8)) & (1 << (id % 8))) ~= 0 end
local function flagSet(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + (id // 8), 1 << (id % 8)
  F.w8(a, (on == false) and (F.r8(a) & ~m & 0xFF) or (F.r8(a) | m))
end
local function varSet(id, v) F.w16(F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2, v) end

local function xorSecure(mon)
  local key = F.r32(mon) ~ F.r32(mon + 4)
  for i = 0, NRAW - 1 do local a = mon + OFF_SECURE + i * 4; F.w32(a, F.r32(a) ~ key) end
end
local function checksumDecrypted(mon)
  local sum = 0
  for i = 0, NRAW - 1 do local w = F.r32(mon + OFF_SECURE + i * 4); sum = (sum + w + (w >> 16)) & 0xFFFFFFFF end
  return sum & 0xFFFF
end
local function withSub(mon, table_, fn)
  xorSecure(mon)
  local sub = mon + OFF_SECURE + table_[F.r32(mon) % 24] * SUB_STRIDE
  local r = fn(sub)
  F.w16(mon + OFF_CHECKSUM, checksumDecrypted(mon))
  xorSecure(mon)
  return r
end
local function writeSpecies(mon, sp) withSub(mon, SUB0, function(s) F.w16(s, (F.r16(s) & 0xF800) | sp) end) end
local function readSpecies(mon) return withSub(mon, SUB0, function(s) return F.r16(s) & 0x7FF end) end
local function writeMove(mon, slot, mv)
  withSub(mon, SUB1, function(s)
    F.w16(s + slot * 2, (F.r16(s + slot * 2) & 0xF800) | mv)
    F.w8(s + 8 + slot, (F.r8(s + 8 + slot) & 0x80) | 15)
  end)
end

local SCRIPT_BUF = S.gStringVar4 + 960
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
end

local function mash(tag, budget, keys)
  local frames, settled, lastVb, stalls, i = 0, 0, vblank(), 0, 0
  while frames < (budget or 6000) do
    if F.reportCrash(tag) then return false, "crash screen" end
    local vb = vblank()
    if vb == lastVb then stalls = stalls + 1 else stalls = 0 end
    lastVb = vb
    if stalls > 30 then return false, "vblank counter stopped" end
    if hasControl() then
      settled = settled + 1
      if settled >= 3 then return true, "frames=" .. frames end
      F.idle(10); frames = frames + 10
    else
      settled = 0; i = i + 1
      F.press(keys[(i % #keys) + 1], 2); F.idle(12); frames = frames + 14
    end
  end
  return false, string.format("no control after %d frames at %d.%d cb2=%08X", frames, F.grp(), F.mapn(), F.cb2())
end

local function warpScript(g, n, x, y)
  local b = { 0x39, g, n, 0xFF }
  le16(b, x); le16(b, y); b[#b + 1] = 0x27; b[#b + 1] = 0x02
  runScript(b)
  for _ = 1, 400 do
    F.idle(4)
    if F.reportCrash("warp") then return false end
    if F.grp() == g and F.mapn() == n and F.ow() then return mash("warp_arrival", 3000, { "B" }) end
  end
  return false
end

local function giveParty()
  F.dbg(); F.idle(40); F.sel(2); F.idle(40)
  for _ = 1, 9 do F.press("Down", 2); F.idle(12) end
  F.press("A", 2); F.idle(180); F.bOut(6); F.idle(60)
end

local function setParty(firstSpecies, lastSpecies)
  local a, b = S.gParties, S.gParties + S.Pokemon.size
  writeSpecies(a, firstSpecies)
  writeSpecies(b, lastSpecies)
end

local function inPartyMenu()
  local c = F.cb2()
  return c == S.CB2_UpdatePartyMenu or c == S.CB2_InitPartyMenu or c == S.CB2_PartyMenuFromStartMenu
end

-- Start -> PARTY -> slot 0 -> action row `row` -> A. Returns true once the party menu closes.
local function useFieldMove(row, tag)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_PARTY) then F.L("  " .. tag .. ": PARTY icon not found"); F.bOut(4); return false end
  F.press("A", 2)
  local opened = false
  for _ = 1, 200 do F.idle(4); if inPartyMenu() then opened = true; break end end
  if not opened then F.L("  " .. tag .. ": party menu never opened"); F.bOut(4); return false end
  F.idle(40)
  F.press("A", 2); F.idle(40)
  for _ = 1, row do F.press("Down", 2); F.idle(12) end
  F.shot(tag .. "_actions")
  F.press("A", 2)
  for _ = 1, 300 do
    F.idle(4)
    if not inPartyMenu() then return true end
  end
  F.shot(tag .. "_still_in_party")
  for _ = 1, 8 do F.press("B", 2); F.idle(20) end
  return false
end

local function ctrl(b) return F.r32(S.gBattlerControllerFuncs + b * 4) & ~1 end
local function actionMenu()
  if F.cb2() ~= (S.BattleMainCB2 & ~1) then return false end
  for _, p in ipairs(S.ActionInputFunctions) do if ctrl(0) == (p & ~1) then return true end end
  return false
end

-- Wait for the action menu (B through the intro text), then RUN by reading the cursor.
local function runFromBattle(tag)
  local tries = 0
  for _ = 1, 3000 do
    if F.ow() and F.cb2() == (S.CB2_Overworld & ~1) and tries > 0 then break end
    if actionMenu() then
      F.idle(10)
      for _ = 1, 4 do
        if F.r8(S.gActionSelectionCursor) == 3 then break end
        F.press(F.r8(S.gActionSelectionCursor) % 2 == 0 and "Right" or "Down", 2); F.idle(10)
      end
      tries = tries + 1
      if tries == 1 then F.shot(tag .. "_run_cursor") end
      F.press("A", 2); F.idle(30)
    else
      F.press("B", 2); F.idle(10)
    end
  end
  local ok, detail = mash(tag .. "_after_battle", 4000, { "B" })
  return ok and F.r8(S.gBattleOutcome) == B_OUTCOME_RAN,
    string.format("%s outcome=%d run presses=%d", detail, F.r8(S.gBattleOutcome), tries)
end

local function tomb(name, mapNum, row, regiFlag, puzzleFlag, defeatedFlag)
  F.L("-- " .. name)
  if not F.check(name .. ": warped one tile off the braille spot", warpScript(G, mapNum, mapNum == MAP_DESERT_RUINS and 4 or 9, 25)) then return end
  local used = useFieldMove(row, name .. "_off")
  mash(name .. "_off", 3000, { "B" })
  F.check(name .. ": the move off the spot opens nothing", not flagGet(puzzleFlag), "used=" .. tostring(used))
  local sx, sy = (mapNum == MAP_DESERT_RUINS) and 6 or 8, (mapNum == MAP_DESERT_RUINS) and 23 or 25
  if not F.check(name .. ": warped onto the braille spot", warpScript(G, mapNum, sx, sy)) then return end
  F.check(name .. ": field move picked from the party menu", useFieldMove(row, name))
  local ok, detail = mash(name .. "_effect", 6000, { "A", "B" })
  F.shot(name .. "_opened")
  F.check(name .. ": control returns after the effect", ok, detail)
  F.check(name .. ": inner wall opened", flagGet(puzzleFlag))
  if not F.route({ { 8, sy }, { 8, 21 } }, name .. "_towall") then F.check(name .. ": reached the opening", false); return end
  F.step("Up")
  local through = false
  for _ = 1, 300 do F.idle(4); local _, y = F.pos(); if F.ow() and y <= 11 then through = true; break end end
  F.check(name .. ": walked through the opening", through, string.format("(%d,%d)", F.pos()))
  if not through then return end
  mash(name .. "_inner", 2000, { "B" })
  F.route({ { 8, 8 } }, name .. "_toregi")
  F.face("Up")
  F.press("A", 2)
  ok, detail = runFromBattle(name)
  F.check(name .. ": ran from the Regi", ok, detail)
  F.check(name .. ": Regi not marked defeated", not flagGet(defeatedFlag))
  local function regiShown()
    for _, o in ipairs(F.objdump()) do if o.x == 8 and o.y == 7 then return true end end
    return false
  end
  F.check(name .. ": Regi flew away for now", not regiShown())
  F.shot(name .. "_after_run")
  if warpScript(G, mapNum, 8, 10) then
    F.check(name .. ": Regi back after leaving and re-entering", regiShown())
    F.shot(name .. "_reentered")
  else
    F.check(name .. ": re-entered the tomb", false)
  end
end

F.run(function()
  if not F.boot(100) then F.finish(); return end
  giveParty()
  for _, f in ipairs(FLAG_BADGE) do flagSet(f) end
  flagSet(FLAG_SYS_POKEMON_GET)
  varSet(VAR_REPEL_STEP_COUNT, 250)
  local src, dst = S.gParties, S.gParties + S.Pokemon.size
  for i = 0, S.Pokemon.size - 1 do F.w8(dst + i, F.r8(src + i)) end
  F.w8(S.gPartiesCount, 2)
  setParty(SPECIES_RELICANTH, SPECIES_WAILORD)
  writeMove(S.gParties, 0, MOVE_ROCK_SMASH)
  writeMove(S.gParties, 1, MOVE_FLASH)
  F.check("party built", F.r8(S.gPartiesCount) == 2 and readSpecies(S.gParties) == SPECIES_RELICANTH,
    string.format("count=%d sp0=%d sp1=%d", F.r8(S.gPartiesCount), readSpecies(S.gParties), readSpecies(dst)))
  F.ensureFree()

  -- Sealed Chamber: wrong order first, then Wailord first and Relicanth last.
  if F.check("sealed: warped below the back wall", warpScript(G, MAP_SEALED_INNER, 10, 5)) then
    F.face("Up"); F.idle(30); F.press("A", 2)
    local started = false
    for _ = 1, 60 do F.idle(2); if not hasControl() then started = true; break end end
    local ok, detail = mash("sealed_wrong", 6000, { "A", "B" })
    F.check("sealed: wrong order reads the braille and returns control", started and ok, detail .. " started=" .. tostring(started))
    F.check("sealed: wrong order leaves the tombs shut", not flagGet(FLAG_REGI_DOORS_OPENED))
    setParty(SPECIES_WAILORD, SPECIES_RELICANTH)
    F.face("Up"); F.idle(30); F.press("A", 2)
    ok, detail = mash("sealed_right", 9000, { "A", "B" })
    F.shot("sealed_opened")
    F.check("sealed: right order returns control", ok, detail)
    F.check("sealed: tombs opened", flagGet(FLAG_REGI_DOORS_OPENED))
  end

  tomb("regirock", MAP_DESERT_RUINS, 1, nil, FLAG_SYS_REGIROCK_PUZZLE_COMPLETED, FLAG_DEFEATED_REGIROCK)
  tomb("registeel", MAP_ANCIENT_TOMB, 2, nil, FLAG_SYS_REGISTEEL_PUZZLE_COMPLETED, FLAG_DEFEATED_REGISTEEL)
  F.finish()
end)
