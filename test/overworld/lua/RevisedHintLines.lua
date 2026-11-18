-- The six NPC and sign scripts whose lines were rewritten so their advice matches this game, each
-- driven through its real trigger with a seeded A/B mash (Yes/No boxes steered by the cursor).
--
-- New Bark lab: Elm's first directions give PROF. BIRCH's number and set his match-call flag,
-- later visits repeat the directions, and after Togepi Elm says to call PROF. BIRCH.
-- Goldenrod Bike Shop: the clerk refused (No), then accepted with a full Key Items pocket (bag
-- full, no bike, flag clear), then accepted with room (Mach Bike, flag set). Talking again shows
-- a line that fits either shop bike, also for a Hoenn-first rider holding only Rydel's Acro Bike,
-- and the second clerk shows the new SELECT and speed line.
-- Goldenrod Dept. Store 2F: the youngster's POKeNAV line, twice, and the clerk's live stock holds
-- LUM BERRIES. Radio Tower 1F: NO at the new Lum Berry question is a wrong answer and enables
-- nothing; retaken with YES the quiz goes on to question 3 and the win enables the radio.
-- Pallet Town bedroom notice: START and STORY. Six Island Pokemon Center old man: LINKING CORD
-- on KADABRA and METAL COAT on ONIX.
-- Every talk must hand control back, and every line read from gStringVar4 must carry the new
-- wording and none of the old.
--
-- PW_SEED=<n> reseeds the mash (default 1). PW_TEXT=instant|fast|mid picks the text speed
-- (default instant).
-- Run via test/overworld/mgba-run.sh test/overworld/lua/RevisedHintLines.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "RevisedHintLines")

local BASE = tonumber(os.getenv("PW_SEED")) or 1
local SPEEDS = { mid = 1, fast = 2, instant = 3 }
local TEXT_SPEED = SPEEDS[os.getenv("PW_TEXT") or "instant"] or 3
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local BUF = S.gStringVar4 + 900
local ITEM_MACH_BIKE = 707
local ITEM_ACRO_BIKE = 708
local ITEM_LUM_BERRY = 522
local FLAG_RECEIVED_BIKE = 0x5A
local FLAG_ENABLE_PROF_BIRCH_MATCH_CALL = 0x119
local FLAG_ENABLE_RADIO = 0x6000 + 0xC5
local FLAG_JOHTO_STARTER_CHOSEN = 0x6000 + 0x38
local FLAG_SHOWN_ELM_TOGEPI = 0x6000 + 0x23
local VAR_NEWBARKTOWN_LABSTATE = 0xA081
local VAR_GOLDENROD_CITY_STATE = 0xA083
local VAR_MAP_SCENE_SIX_ISLAND_POKEMON_CENTER_1F = 0xA062

local seed = BASE
local function rnd(n)
  seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
  return (seed >> 8) % n
end
local function reseed(tag)
  local h = BASE & 0x7FFFFFFF
  for i = 1, #tag do h = ((h ~ tag:byte(i)) * 16777619) & 0x7FFFFFFF end
  seed = h
  F.L(string.format("== %s == seed=%d", tag, seed))
end

local function flagAddr(id)
  if id >= 0x6000 and id < 0x6400 then return F.sb3() + S.SaveBlock3.johtoFlags + (id - 0x6000) // 8, (id - 0x6000) % 8 end
  return F.sb1() + S.SaveBlock1.flags + id // 8, id % 8
end
local function flagGet(id) local a, b = flagAddr(id); return (F.r8(a) & (1 << b)) ~= 0 end
local function flag(id, on)
  local a, b = flagAddr(id)
  F.w8(a, on and (F.r8(a) | (1 << b)) or (F.r8(a) & (~(1 << b) & 0xFF)))
end
local function var(id, v) F.w16(F.sb3() + S.SaveBlock3.regionVars + (id - 0xA000) * 2, v) end

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function runScript(bytes)
  for i, v in ipairs(bytes) do F.w8(BUF + i - 1, v) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, BUF)
  F.w8(S.sGlobalScriptContextStatus, 0)
end
local function warp(g, n, x, y)
  runScript({ 0x39, g, n, 0xFF, x & 0xFF, x >> 8, y & 0xFF, y >> 8, 0x27, 0x02 })
  for _ = 1, 600 do
    F.idle(4)
    local px, py = F.pos()
    if F.grp() == g and F.mapn() == n and px == x and py == y and hasControl() then F.idle(30); return true end
  end
  return false
end

local CH = { [0x00] = " ", [0x1B] = "e", [0xAB] = "!", [0xAC] = "?", [0xAD] = ".", [0xB0] = "...", [0xB4] = "'",
  [0xB8] = ",", [0xFA] = " ", [0xFB] = " ", [0xFE] = " " }
for i = 0, 25 do CH[0xBB + i] = string.char(65 + i); CH[0xD5 + i] = string.char(97 + i) end
for i = 0, 9 do CH[0xA1 + i] = string.char(48 + i) end
local function shownText()
  local s = {}
  for i = 0, 399 do
    local c = F.r8(S.gStringVar4 + i)
    if c == 0xFF then break end
    s[#s + 1] = CH[c] or "~"
  end
  return table.concat(s)
end

local Seen = {}
local function noteText()
  local t = shownText()
  if t ~= "" and t ~= Seen.last then Seen.last = t; Seen.all[#Seen.all + 1] = t end
end
local function heard() return table.concat(Seen.all, " | ") end

local function scriptMenuActive()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    local fn = F.r32(a + S.Task.func) & 0xFFFFFFFE
    if F.r8(a + S.Task.isActive) ~= 0 and (fn == S.Task_HandleYesNoInput or fn == S.Task_CallYesOrNoCallback) then return true end
  end
  return false
end
local function frame(keys) joypad.set(keys or {}); emu.frameadvance(); noteText() end

-- Pages text with seeded A and B taps until a Yes/No box is up, then picks row `want`.
local function answer(want, tag)
  for _ = 1, 1200 do
    if scriptMenuActive() then
      for _ = 1, 12 do frame() end
      for _ = 1, 10 do
        local c = F.mcur()
        if c == want then
          frame({ A = true }); frame({ A = true })
          for _ = 1, 60 do frame(); if not scriptMenuActive() then return true end end
          return false
        end
        frame({ [c > want and "Up" or "Down"] = true }); frame({ [c > want and "Up" or "Down"] = true })
        for _ = 1, 10 do frame() end
      end
      return false
    end
    if rnd(12) == 0 then frame({ [want == 0 and "A" or "B"] = true }) else frame() end
  end
  F.shot(tag .. "_noyesno")
  return false
end

-- Seeded A/B taps until the script hands control back.
local function mashOut(tag)
  for i = 1, 4000 do
    local r = rnd(10)
    if hasControl() then frame()
    elseif r == 0 then frame({ A = true }) elseif r == 1 then frame({ B = true }) else frame() end
    if i == 30 then F.shot(tag) end
    if i > 60 and hasControl() then
      for _ = 1, 30 do frame() end
      if hasControl() then return true end
    end
    if i % 500 == 0 and F.reportCrash(tag) then return false end
  end
  return false
end

local function startTalk(dir, tag)
  Seen.all, Seen.last = {}, nil
  F.w8(S.gStringVar4, 0xFF)
  reseed(tag)
  F.face(dir)
  frame({ A = true }); frame({ A = true })
  for _ = 1, 90 do if not hasControl() then return true end; frame() end
  return false
end
local function talk(dir, tag)
  if not startTalk(dir, tag) then return false end
  return mashOut(tag)
end

local function has(s, ...) for _, w in ipairs({ ... }) do if not s:find(w, 1, true) then return false end end return true end
local function lacks(s, ...) for _, w in ipairs({ ... }) do if s:find(w, 1, true) then return false end end return true end

local function keyQty(id)
  local key = F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF
  local ptr = F.r32(S.gBagPockets + 4 * S.BagPocket.stride)
  local n = 0
  for s = 0, F.pocketCap(4) - 1 do
    if F.r16(ptr + s * 4) == id then n = n + (F.r16(ptr + s * 4 + 2) ~ key) end
  end
  return n
end
local function keyPocketFull()
  local ptr = F.r32(S.gBagPockets + 4 * S.BagPocket.stride)
  for s = 0, F.pocketCap(4) - 1 do if F.r16(ptr + s * 4) == 0 then return false end end
  return true
end

local function keyPtr() return F.r32(S.gBagPockets + 4 * S.BagPocket.stride) end
-- The debug fill leaves slots free when there are fewer key items than slots. Top those up, and
-- swap any Mach Bike stack out, so the full pocket has no free slot and no stack to join.
local function topUpKeyPocket()
  local ptr, cap, used = keyPtr(), F.pocketCap(4), {}
  local key = F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF
  for s = 0, cap - 1 do used[F.r16(ptr + s * 4)] = true end
  local id = 1
  for s = 0, cap - 1 do
    local cur = F.r16(ptr + s * 4)
    if cur == 0 or cur == ITEM_MACH_BIKE then
      while used[id] or id == ITEM_MACH_BIKE do id = id + 1 end
      used[id] = true
      F.w16(ptr + s * 4, id)
      F.w16(ptr + s * 4 + 2, 1 ~ key)
    end
  end
end
local function clearBag() F.dbg(); F.sel(1); F.sel(2); F.idle(120); F.bOut(6); mashOut("clear_bag") end

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  F.w16(F.sb2() + S.SaveBlock2.optionsU16, (F.r16(F.sb2() + S.SaveBlock2.optionsU16) & ~7) | TEXT_SPEED)
  F.L(string.format("PW_SEED=%d text=%d", BASE, TEXT_SPEED))

  -- New Bark Town lab.
  var(VAR_NEWBARKTOWN_LABSTATE, 1)
  var(VAR_GOLDENROD_CITY_STATE, 0)
  flag(FLAG_JOHTO_STARTER_CHOSEN, true)
  flag(FLAG_SHOWN_ELM_TOGEPI, false)
  flag(FLAG_ENABLE_PROF_BIRCH_MATCH_CALL, false)
  if F.check("elm: in front of Elm after the starter", warp(76, 0, 6, 4)) then
    local ok = talk("Up", "elm_first")
    F.check("elm: the first directions hand control back", ok)
    F.check("elm: the first directions give PROF. BIRCH's number",
      has(heard(), "take PROF. BIRCH's number", "good friend") and lacks(heard(), "you have my"), heard())
    F.check("elm: PROF. BIRCH's match call is registered", flagGet(FLAG_ENABLE_PROF_BIRCH_MATCH_CALL))
  end
  if F.check("elm: back at Elm's computer", warp(84, 0, 4, 6) and warp(76, 0, 3, 3)) then
    for i = 1, 2 do
      local ok = talk("Up", "elm_again_" .. i)
      F.check("elm: the repeated directions hand control back (" .. i .. ")", ok)
      F.check("elm: the repeated directions still name PROF. BIRCH (" .. i .. ")", has(heard(), "PROF. BIRCH"), heard())
    end
  end
  flag(FLAG_SHOWN_ELM_TOGEPI, true)
  if F.check("elm: at Elm's computer after Togepi", warp(84, 0, 4, 6) and warp(76, 0, 3, 3)) then
    local ok = talk("Up", "elm_callme")
    F.check("elm: the Togepi follow-up hands control back", ok)
    F.check("elm: the Togepi follow-up points to PROF. BIRCH",
      has(heard(), "Give PROF. BIRCH a call", "check your progress") and lacks(heard(), "I'm busy"), heard())
  end

  -- Goldenrod Bike Shop.
  flag(FLAG_RECEIVED_BIKE, false)
  if F.check("bike: in front of the clerk", warp(84, 0, 4, 5)) then
    local bikes0 = keyQty(ITEM_MACH_BIKE)
    local ok = startTalk("Up", "bike_refuse") and answer(1, "bike_refuse") and mashOut("bike_refuse")
    F.check("bike: refusing the clerk hands control back", ok, heard())
    F.check("bike: refusing gives no bike", keyQty(ITEM_MACH_BIKE) == bikes0 and not flagGet(FLAG_RECEIVED_BIKE),
      string.format("bikes %d -> %d", bikes0, keyQty(ITEM_MACH_BIKE)))

    clearBag()
    F.dbg(); F.sel(1); F.sel(1); F.sel(7); F.idle(120); F.bOut(6); mashOut("fill_keys")
    local filled = 0
    for slot = 0, F.pocketCap(4) - 1 do if F.r16(keyPtr() + slot * 4) ~= 0 then filled = filled + 1 end end
    F.L(string.format("debug fill: %d of %d key slots", filled, F.pocketCap(4)))
    topUpKeyPocket()
    F.check("bike: the Key Items pocket is full and holds no Mach Bike", keyPocketFull() and keyQty(ITEM_MACH_BIKE) == 0)
    ok = startTalk("Up", "bike_full") and answer(0, "bike_full") and mashOut("bike_full")
    F.check("bike: accepting with a full pocket hands control back", ok, heard())
    F.check("bike: a full pocket gets the bag-full line", heard():find("BAG is full", 1, true) ~= nil, heard())
    F.check("bike: a full pocket keeps the bike undelivered", keyQty(ITEM_MACH_BIKE) == 0 and not flagGet(FLAG_RECEIVED_BIKE),
      "bikes=" .. keyQty(ITEM_MACH_BIKE))

    clearBag()
    ok = startTalk("Up", "bike_take") and answer(0, "bike_take") and mashOut("bike_take")
    F.check("bike: accepting with room hands control back", ok, heard())
    F.check("bike: the clerk gives the Mach Bike", keyQty(ITEM_MACH_BIKE) == 1 and flagGet(FLAG_RECEIVED_BIKE),
      "bikes=" .. keyQty(ITEM_MACH_BIKE))

    for i = 1, 2 do
      ok = talk("Up", "bike_after_" .. i)
      F.check("bike: the clerk's thanks hand control back (" .. i .. ")", ok)
      F.check("bike: the clerk's thanks fit any shop bike (" .. i .. ")",
        has(heard(), "Every BIKE out on the road", "where folks can see") and lacks(heard(), "gear", "pressing R", "MACH BIKE"), heard())
    end
    F.check("bike: talking again gives no second bike", keyQty(ITEM_MACH_BIKE) == 1)

    -- FLAG_RECEIVED_BIKE is also Rydel's, so a Hoenn-first player arrives with his Acro Bike and the
    -- flag set, never having helped this clerk.
    clearBag()
    runScript({ 0x44, ITEM_ACRO_BIKE & 0xFF, ITEM_ACRO_BIKE >> 8, 1, 0, 0x02 })
    F.idle(30)
    F.check("bike: holding only Rydel's Acro Bike", keyQty(ITEM_ACRO_BIKE) == 1 and keyQty(ITEM_MACH_BIKE) == 0)
    ok = talk("Up", "bike_acro")
    F.check("bike: an Acro Bike rider's talk hands control back", ok)
    F.check("bike: an Acro Bike rider is not thanked for a MACH BIKE",
      has(heard(), "Every BIKE out on the road") and lacks(heard(), "MACH BIKE", "your help"), heard())
    F.check("bike: an Acro Bike rider gets no Mach Bike", keyQty(ITEM_MACH_BIKE) == 0)
  end
  if F.check("bike: in front of the second clerk", warp(84, 0, 2, 7)) then
    local ok = talk("Up", "bike_clerk2")
    F.check("bike: the second clerk hands control back", ok)
    F.check("bike: the second clerk says SELECT and the speed rule",
      has(heard(), "REGISTER your BIKE", "press SELECT", "picks up speed", "slow to a stop") and lacks(heard(), "change", "R button"), heard())
  end

  -- Goldenrod Dept. Store 2F.
  if F.check("dept: in front of the youngster", warp(84, 5, 13, 5)) then
    for i = 1, 2 do
      local ok = talk("Down", "dept_" .. i)
      F.check("dept: the youngster hands control back (" .. i .. ")", ok)
      F.check("dept: the youngster browses his POKeNAV (" .. i .. ")",
        has(heard(), "names", "POKeNAV", "Who should I call today") and lacks(heard(), "25"), heard())
    end
  end

  -- The quiz's new question 2 says the 2F clerk sells LUM BERRIES; read his live stock.
  local lum = false
  for _, y in ipairs({ 10, 9 }) do
    if not lum and warp(84, 5, 14, y) then
      F.w32(S.sMartInfo + 8, 0); F.w16(S.sMartInfo + 12, 0)
      F.face("Down")
      for _ = 1, 12 do
        F.press("A", 2); F.idle(40)
        if F.r16(S.sMartInfo + 12) > 0 then break end
      end
      local list, count = F.r32(S.sMartInfo + 8), F.r16(S.sMartInfo + 12)
      for i = 0, count - 1 do if F.r16(list + i * 2) == ITEM_LUM_BERRY then lum = true end end
      if count > 0 then
        F.shot("dept_clerk_shop")
        for _ = 1, 8 do F.press("B", 2); F.idle(30) end
        mashOut("dept_clerk_leave")
      end
    end
  end
  F.check("dept: the 2F clerk stocks LUM BERRIES, so YES is the true answer", lum)

  -- Radio Tower 1F quiz.
  flag(FLAG_ENABLE_RADIO, false)
  if F.check("quiz: at the reception counter", warp(84, 18, 14, 8)) then
    local ok = startTalk("Down", "quiz_wrong") and answer(0, "quiz_take") and answer(0, "quiz_q1")
    local q2 = heard()
    ok = ok and answer(1, "quiz_q2_no") and mashOut("quiz_wrong")
    F.check("quiz: NO at question 2 hands control back", ok, heard())
    F.check("quiz: question 2 asks about LUM BERRIES at the DEPT.STORE",
      has(q2 .. heard(), "GOLDENROD DEPT.STORE sells", "LUM BERRIES") and lacks(q2 .. heard(), "at a MART"), q2)
    F.check("quiz: NO at question 2 is a wrong answer", not flagGet(FLAG_ENABLE_RADIO) and not heard():find("Question 3", 1, true), heard())

    ok = startTalk("Down", "quiz_right")
    for i, a in ipairs({ 0, 0, 0 }) do ok = ok and answer(a, "quiz_r" .. i) end
    F.check("quiz: YES at question 2 goes on to question 3", ok and heard():find("Question 3", 1, true) ~= nil, heard())
    for i, a in ipairs({ 1, 0, 1 }) do ok = ok and answer(a, "quiz_r" .. (i + 3)) end
    ok = ok and mashOut("quiz_won")
    F.check("quiz: the win hands control back", ok)
    F.check("quiz: the win enables the radio", flagGet(FLAG_ENABLE_RADIO))
  end

  -- Pallet Town bedroom notice (Kanto).
  if F.check("pallet: in front of the notice", warp(38, 1, 11, 2)) then
    for i = 1, 2 do
      local ok = talk("Up", "pallet_" .. i)
      F.check("pallet: the notice hands control back (" .. i .. ")", ok)
      F.check("pallet: the notice points to START and STORY (" .. i .. ")",
        has(heard(), "Press START and choose STORY") and lacks(heard(), "HELP", "L or R"), heard())
    end
  end

  -- Six Island Pokemon Center, after the rival's scene there.
  var(VAR_MAP_SCENE_SIX_ISLAND_POKEMON_CENTER_1F, 1)
  if F.check("six: in front of the old man", warp(69, 0, 12, 6)) then
    for i = 1, 2 do
      local ok = talk("Up", "six_" .. i)
      F.check("six: the old man hands control back (" .. i .. ")", ok)
      F.check("six: the old man names both item evolutions (" .. i .. ")",
        has(heard(), "LINKING", "KADABRA", "ALAKAZAM", "ONIX", "METAL COAT") and lacks(heard(), "traded while holding"), heard())
    end
  end
  F.check("no crash screen", not F.reportCrash("end"))
  F.finish()
end)
