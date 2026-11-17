-- Mashing through every region's Hall of Fame, from the room's own arrival script to Continue.
--
-- Each case warps onto the room's arrival tile (the tile the Champion's room leads to) with a full
-- party and a follower, as the Champion's exit leaves the player, and mashes A, B, Start, Select,
-- L, R and the D-pad with a seeded source through the walk in, the speech, the record machine, the
-- induction screen, its save and the soft reset that replaces the credits. The mash stops when the
-- intro or title comes up, so it never reaches the main menu's New Game row; the run then boots and
-- Continues. Checks: no crash screen, the game reached the intro, Continue returns to the field at
-- the region's respawn map with control, and the same party in the same order.
--
-- PW_HOF_ONLY=<text> runs matching regions, PW_HOF_BASE=<n> reseeds.

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "HofMash")

local ONLY = os.getenv("PW_HOF_ONLY")
local BASE = tonumber(os.getenv("PW_HOF_BASE") or "") or 0x40F
local VAR_JOHTO_LEAGUE_STATE = 0xA080 + 0x3B

local seed = BASE
local function rnd()
  seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
  return seed >> 8
end
local function seedFor(tag)
  local h = BASE & 0x7FFFFFFF
  for i = 1, #tag do h = ((h ~ tag:byte(i)) * 16777619) & 0x7FFFFFFF end
  return h
end

local SCRIPT_BUF = S.gStringVar4 + 960
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, 0)
end
local function setVar(id, v) local b = { 0x16 }; le16(b, id); le16(b, v); b[#b + 1] = 0x02; runScript(b); F.idle(20) end
local function createMon(species, level)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(b, species); le16(b, level)
  le32(b, 0)
  b[#b + 1] = 0x02
  runScript(b); F.idle(20)
end

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == 2
end

-- warp group num 0xFF x y; waitstate; end
local function warpScript(g, n, x, y)
  local b = { 0x39, g, n, 0xFF }
  le16(b, x); le16(b, y); b[#b + 1] = 0x27; b[#b + 1] = 0x02
  runScript(b)
  for _ = 1, 400 do
    F.idle(4)
    if F.reportCrash("warp") then return false end
    if F.grp() == g and F.mapn() == n and F.ow() then return true end
  end
  return false
end

local STOP = {}
for _, k in ipairs({ "CB2_Intro", "CB2_InitTitleScreen", "CB2_WorldTitleScreen", "CB2_InitMainMenu", "CB2_MainMenu" }) do
  if S[k] then STOP[S[k] & ~1] = k end
end

-- Personality, OT id and level of each member. The induction adds the Champion Ribbon, which
-- changes the encrypted words and the checksum.
local function partyBytes()
  local t = {}
  for i = 0, F.r8(S.gPartiesCount) - 1 do
    local a = S.gParties + i * S.Pokemon.size
    t[#t + 1] = string.format("%08X/%08X/%d", F.r32(a), F.r32(a + 4), F.r8(a + S.Pokemon.level))
  end
  return table.concat(t, ",")
end

local DIRS = { "Up", "Down", "Left", "Right" }
local function mashFrame()
  local t = {}
  for b, p in pairs({ A = 30, B = 25, Start = 8, Select = 8, L = 8, R = 8 }) do
    if rnd() % 100 < p then t[b] = true end
  end
  if t.R and t.Start then t.R = nil end
  if t.A and t.B and t.Start and t.Select then t.Select = nil end
  if rnd() % 100 < 40 then t[DIRS[rnd() % 4 + 1]] = true end
  joypad.set(t)
  emu.frameadvance()
end

local function case(tag, room, respawn, setup)
  if ONLY and not tag:find(ONLY, 1, true) then return end
  seed = seedFor(tag)
  F.L(string.format("== %s == seed=%d", tag, seed))
  if setup then setup() end
  local party0, n0 = partyBytes(), F.r8(S.gPartiesCount)
  if not warpScript(room[1], room[2], room[3], room[4]) then F.check(tag .. ": reached the Hall of Fame", false); return end
  local stopAt, crashed, frames = nil, false, 0
  for i = 1, 30000 do
    frames = i
    if i % 10 == 0 and F.reportCrash(tag) then crashed = true; break end
    local cb = F.cb2()
    if STOP[cb] then stopAt = STOP[cb]; break end
    if i % 3000 == 0 then F.shot(string.format("%s_%d", tag, i // 3000)) end
    mashFrame()
  end
  joypad.set({})
  F.L(string.format("  mash ended after %d frames at %s cb2=%08X", frames, tostring(stopAt), F.cb2()))
  F.check(tag .. ": no crash", not crashed)
  F.check(tag .. ": the induction ended in the soft reset", stopAt ~= nil, string.format("cb2=%08X grp=%d map=%d", F.cb2(), F.grp(), F.mapn()))
  if not stopAt then F.shot(tag .. "_stuck"); return end
  F.idle(30)
  if not F.boot(nil, true) then F.check(tag .. ": Continue", false); return end
  -- Read the landing before any input: Hoenn's first induction then plays Birch's doorstep scene,
  -- which ends in his lab.
  local landG, landM = F.grp(), F.mapn()
  for _ = 1, 400 do if hasControl() then break end F.press("B", 2); F.idle(10) end
  F.check(tag .. ": control after Continue", hasControl())
  F.check(tag .. ": respawned at the region's home", landG == respawn[1] and landM == respawn[2],
    string.format("grp=%d map=%d", landG, landM))
  local party1 = partyBytes()
  F.check(tag .. ": party unchanged", F.r8(S.gPartiesCount) == n0 and party1 == party0, "n=" .. F.r8(S.gPartiesCount))
  F.shot(tag .. "_after")
end

F.run(function()
  if not F.boot(100) then F.finish(); return end
  for _, sp in ipairs({ 131, 6, 9, 3, 25, 150 }) do createMon(sp, 70) end
  F.check("party of six", F.r8(S.gPartiesCount) == 6)

  case("kanto", { 35, 80, 5, 12 }, { 37, 0 })
  case("hoenn", { 16, 11, 7, 16 }, { 0, 9 })
  case("johto", { 99, 10, 5, 12 }, { 75, 0 }, function() setVar(VAR_JOHTO_LEAGUE_STATE, 6) end)
  F.finish()
end)
