-- The Battle Frontier move tutors must take Battle Points exactly when a move is learned.
--
-- The Lounge 7 tutors (Hoenn) price each move in BP, check the balance after the "That will be N
-- Battle Points" Yes, then open the storage chooser and charge only if the lesson succeeds. Every
-- way out of the lesson has to leave the balance alone. With real input at the left tutor (Soft-
-- Boiled, 16 BP) the suite tries: one point short, exactly enough but B in the chooser, a Magikarp
-- that cannot learn it, a Mew with four moves that declines to forget one, then a Mew with three moves
-- that learns it, and a second visit with the emptied balance. Battle Points are written straight to
-- the save block between visits (the debug menu only has Max), and the suite checks the offset by
-- giving the debug maximum first.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "FrontierTutorPayment")

local HUB = 100
local REGION_HOENN = 3
local LOUNGE7_GROUP, LOUNGE7_MAP, TUTOR_X, TUTOR_Y = 26, 49, 2, 6
-- offsetof(struct SaveBlock2, frontier.battlePoints), offsetof probe with the modern CFLAGS.
local SB2_BATTLE_POINTS = 3768
local MAX_BATTLE_POINTS = 9999
local PRICE = 16
local SPECIES_MEW, SPECIES_MAGIKARP, MOVE_SOFT_BOILED = 151, 129, 135
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local SCRIPT_BUF = S.gStringVar4 + 960

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function runScript(b)
  for i, v in ipairs(b) do F.w8(SCRIPT_BUF + i - 1, v) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
  for _ = 1, 200 do F.idle(4); if hasControl() then break end end
  F.idle(30)
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
local function warpToCoords(grp, map, x, y, tag)
  for _ = 1, 4 do
    F.dbg(); F.sel(0); F.sel(1); F.idle(20)
    F.spin(d(grp)); F.spin(d(map))
    F.press("A", 2)
    for _ = 1, 400 do
      F.w8(S.sWarpDestination + 2, 0xFF)
      F.w16(S.sWarpDestination + 4, x)
      F.w16(S.sWarpDestination + 6, y)
      F.idle(1)
      local px, py = F.pos()
      if F.ow() and F.grp() == grp and F.mapn() == map and px == x and py == y then F.idle(120); return true end
    end
    F.bOut(5)
  end
  F.shot(tag .. "_warpfail")
  return false
end
-- gStringVar4 as uppercase ASCII; Gen 3 A = 0xBB, a = 0xD5.
local function message()
  local s = {}
  for i = 0, 200 do
    local c = F.r8(S.gStringVar4 + i)
    if c == 0xFF then break end
    if c >= 0xBB and c <= 0xD4 then s[#s + 1] = string.char(65 + c - 0xBB)
    elseif c >= 0xD5 and c <= 0xEE then s[#s + 1] = string.char(65 + c - 0xD5)
    elseif c == 0xAC then s[#s + 1] = "?"
    else s[#s + 1] = " " end
  end
  return table.concat(s)
end
local function bp() return F.r16(F.sb2() + SB2_BATTLE_POINTS) end
local function setBp(n) F.w16(F.sb2() + SB2_BATTLE_POINTS, n) end
local function moves(i)
  local a = S.gParties + i * S.Pokemon.size
  local pers, otid = F.r32(a), F.r32(a + 4)
  local key = pers ~ otid
  local s1 = F.r8(S.sSubstructOffsets + 24 + pers % 24) * 3
  local w0, w1 = F.r32(a + 32 + s1 * 4) ~ key, F.r32(a + 32 + (s1 + 1) * 4) ~ key
  return { w0 & 0x7FF, (w0 >> 16) & 0x7FF, w1 & 0x7FF, (w1 >> 16) & 0x7FF }
end
local function knows(i, move)
  for _, m in ipairs(moves(i)) do if m == move then return true end end
  return false
end

-- Chooser keys per party slot: Left lands on party slot 1, Up/Down from there.
local SLOT_KEYS = { [0] = { "Left", "Up" }, [1] = { "Left" }, [2] = { "Left", "Down" } }

-- One visit: talk, pick Soft-Boiled (row 0) and say YES; then in the chooser either press B
-- (slot = nil) or pick `slot` and answer every Yes/No inside the lesson with `lessonAnswer`.
-- Returns the transcript.
local function visit(tag, slot, lessonAnswer)
  local said = {}
  local function note() local m = message(); if said[#said] ~= m then said[#said + 1] = m end end
  F.face("Up"); F.press("A", 2)
  local chooser, asked = false, false
  for _ = 1, 600 do
    note()
    local m = message()
    if not F.ow() then chooser = true; break end
    if hasControl() and #said > 1 then break end
    if m:find("HAVEN T GOT ENOUGH") then
      F.press("A", 2); F.idle(40)
      F.press("B", 2); F.idle(40)                -- leave the move list
    elseif m:find("THAT WILL BE") and not asked then
      asked = true
      F.idle(40); F.shot(tag .. "_price"); F.press("A", 2); F.idle(30)
    else
      F.press("A", 2); F.idle(20)
    end
  end
  if chooser then
    F.idle(120); F.shot(tag .. "_chooser")
    if slot == nil then
      for _ = 1, 6 do if F.ow() then break end; F.press("B", 2); F.idle(60) end
    else
      for _, k in ipairs(SLOT_KEYS[slot]) do F.press(k, 2); F.idle(45) end
      F.press("A", 2); F.idle(45); F.press("A", 2); F.idle(60)
    end
  end
  for _ = 1, 800 do
    note()
    if hasControl() then F.idle(20); if hasControl() then break end end
    local m = message()
    if lessonAnswer == "No" and m:find("SHOULD A MOVE BE DELETED") then
      F.idle(30); F.press("B", 2); F.idle(30)
    elseif m:find("STOP LEARNING") or m:find("STOP TRYING") then
      F.idle(30); F.press("A", 2); F.idle(30)
    else
      F.press("A", 2); F.idle(20)
    end
  end
  F.L("  " .. tag .. ": " .. table.concat(said, " | "))
  return table.concat(said, " | "), chooser
end

F.run(function()
  if not F.boot(HUB) then F.check("boot", false); F.finish(); return end
  for off = 0, 6 * S.Pokemon.size - 4, 4 do F.w32(S.gParties + off, 0) end
  F.w8(S.gPartiesCount, 0)
  createMon(SPECIES_MEW, 50, { 1 })
  createMon(SPECIES_MAGIKARP, 5, { 150 })
  createMon(SPECIES_MEW, 50, { 1, 5, 25, 34 })
  F.check("setup: Mew (one move), Magikarp, Mew (four moves)", F.r8(S.gPartiesCount) == 3)
  F.dbg(); F.sel(3); F.sel(7); F.idle(60); F.bOut(4)          -- Give X > Max Battle Points
  F.check("setup: the battle points offset holds the debug maximum", bp() == MAX_BATTLE_POINTS, "bp=" .. bp())
  F.w8(F.sb2() + S.SaveBlock2.currentRegion, REGION_HOENN)
  F.w32(S.gCurrentRegion, REGION_HOENN)
  if not F.check("setup: below the left Lounge 7 tutor", warpToCoords(LOUNGE7_GROUP, LOUNGE7_MAP, TUTOR_X, TUTOR_Y, "lounge")) then
    F.finish(); return
  end
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)

  setBp(PRICE - 1)
  local t, chooser = visit("short", 0, "Yes")
  F.check("one point short: refused before the chooser", t:find("HAVEN T GOT ENOUGH") ~= nil and not chooser)
  F.check("one point short: balance unchanged", bp() == PRICE - 1, "bp=" .. bp())

  setBp(PRICE)
  t, chooser = visit("chooser_b", nil, "Yes")
  F.check("B in the chooser: the chooser opened", chooser)
  F.check("B in the chooser: nothing charged", bp() == PRICE and not t:find("TAKE YOUR BATTLE POINTS"), "bp=" .. bp())

  t, chooser = visit("magikarp", 1, "Yes")
  F.check("Magikarp: told it cannot learn the move", t:find("CAN T BE LEARNED") ~= nil, t)
  F.check("Magikarp: nothing charged", bp() == PRICE, "bp=" .. bp())

  t, chooser = visit("full_decline", 2, "No")
  F.check("four moves, declined: the move was not learned", not knows(2, MOVE_SOFT_BOILED), table.concat(moves(2), ","))
  F.check("four moves, declined: nothing charged", bp() == PRICE and not t:find("TAKE YOUR BATTLE POINTS"), "bp=" .. bp())

  t, chooser = visit("learn", 0, "Yes")
  F.check("three free slots: Soft-Boiled learned", knows(0, MOVE_SOFT_BOILED), table.concat(moves(0), ","))
  F.check("three free slots: charged the price once", bp() == 0 and t:find("TAKE YOUR BATTLE POINTS") ~= nil, "bp=" .. bp())

  t, chooser = visit("empty", 0, "Yes")
  F.check("empty balance: refused before the chooser", t:find("HAVEN T GOT ENOUGH") ~= nil and not chooser)
  F.check("empty balance: stays at zero", bp() == 0, "bp=" .. bp())
  F.check("control returns", hasControl())
  F.check("no crash", not F.crashScreen())
  F.finish()
end)
