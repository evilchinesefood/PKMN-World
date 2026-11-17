-- Whiteout, then Save and Continue, in each region. A real wild battle (setwildbattle/dowildbattle,
-- as DoubleKoWhiteout starts them) against a level 50 Raticate knocks out a lone level 5 Magikarp
-- that knows only Splash; the whiteout runs on its own. The respawn is the region's Pokemon Center
-- (Oldale, Viridian, Cherrygrove), set by walking in, and the battle is fought in the town outside.
-- After the whiteout the field must be back at that Center with the party healed, the money loss
-- taken, the follower out and the map's music playing. Then a save from the Start menu, a soft reset
-- and Continue must restore all of it: map, tile, money, party HP, follower and music.
--
-- PW_WOSC_ONLY=<text> runs matching regions.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "WhiteoutSaveContinue")

local ONLY = os.getenv("PW_WOSC_ONLY")
local SPECIES_MAGIKARP, SPECIES_RATICATE = 129, 20
local MOVE_SPLASH = 150
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local PARTY_SIZE = 6
local USM_ICO_SAVE = 7
local SENTINEL = 0xFFFF
local OBJ_EVENT_ID_FOLLOWER = 0xFE
local WALLET = 10000

local SCRIPT_BUF = S.gStringVar4 + 960
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
  F.idle(20)
end
local function giveMon(species, level, moves)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = PARTY_SIZE
  le16(b, species); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for k = 1, 4 do le16(b, moves[k] or 0) end
  b[#b + 1] = 0x02
  runScript(b)
end
local function startWild(species, level)
  local b = { 0xB6 }
  le16(b, species); b[#b + 1] = level; le16(b, 0)
  le16(b, 0); b[#b + 1] = 0; le16(b, 0)
  b[#b + 1] = 0xB7
  b[#b + 1] = 0x02
  runScript(b)
  for _ = 1, 1500 do
    F.idle(1)
    if not F.ow() and F.battlers() >= 2 then return true end
  end
  return false
end
local function key32() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) end
local function setMoney(v) F.w32(F.sb1() + S.SaveBlock1.money, v ~ key32()) end

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function awaitControl(budget)
  for i = 1, budget or 900 do
    if hasControl() and i > 20 then F.idle(20); if hasControl() then return true end end
    if i % 60 == 0 then F.press("A", 2) elseif i % 60 == 30 then F.press("B", 2) else F.idle(1) end
  end
  return hasControl()
end
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end

local function follower()
  for i = 0, 15 do
    local o = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(o) & 1) ~= 0 and F.r8(o + S.ObjectEvent.localId) == OBJ_EVENT_ID_FOLLOWER then
      return ((F.r8(o + S.ObjectEvent.flags1) >> 5) & 1) == 1 and "hidden" or "shown"
    end
  end
  return "none"
end
local function playingSong()
  local hdr = F.r32(S.gMPlayInfo_BGM)
  if hdr == 0 then return 0 end
  for id = 0, 900 do
    if F.r32(S.gSongTable + id * 8) == hdr then return id end
  end
  return -1
end
local function headerMusic() return F.r16(S.gMapHeader + 0x10) end
local function bgmPaused() return (F.r32(S.gMPlayInfo_BGM + 4) & 0x80000000) ~= 0 end
local function hp() return F.r16(S.gParties + S.Pokemon.hp), F.r16(S.gParties + S.Pokemon.maxHP) end

local function snapshot()
  local x, y = F.pos()
  local h, m = hp()
  F.idle(60)
  return { grp = F.grp(), map = F.mapn(), x = x, y = y, money = F.money(), hp = h, maxHP = m, follower = follower(),
           song = playingSong(), header = headerMusic(), paused = bgmPaused() }
end
local function fmt(s)
  return string.format("%d/%d (%d,%d) money=%d hp=%d/%d follower=%s song=%d header=%d paused=%s", s.grp, s.map, s.x, s.y,
    s.money, s.hp, s.maxHP, s.follower, s.song, s.header, tostring(s.paused))
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


local REGIONS = {
  { tag = "hoenn", center = { 0, 0, 2, 0, 0, 2, 0, 0, 0 }, cg = 2, cm = 2, town = { 0, 0, 0, 0, 1, 0, 0, 0, 0 }, tg = 0, tm = 10 },
  { tag = "kanto", center = { 0, 3, 9, 0, 0, 4, 0, 0, 0 }, cg = 39, cm = 4, town = { 0, 3, 7, 0, 0, 1, 0, 0, 0 }, tg = 37, tm = 1 },
  { tag = "johto", center = { 0, 7, 7, 0, 0, 0, 0, 0, 0 }, cg = 77, cm = 0, town = { 0, 7, 5, 0, 0, 1, 0, 0, 0 }, tg = 75, tm = 1 },
}

local function region(r)
  local tag = r.tag
  local function w(t, g, m, label) return F.warpTo(t[1], t[2], t[3], t[4], t[5], t[6], t[7], t[8], t[9], g, m, tag .. "_" .. label) end
  F.check(tag .. ": walked into the Pokemon Center", w(r.center, r.cg, r.cm, "center") and awaitControl(600), where())
  local respawn = F.r8(F.sb1() + S.SaveBlock1.lastHealLocation) .. "/" .. F.r8(F.sb1() + S.SaveBlock1.lastHealLocation + 1)
  F.check(tag .. ": out in the town", w(r.town, r.tg, r.tm, "town") and awaitControl(600), where())
  setMoney(WALLET)
  F.check(tag .. ": a wild battle starts", startWild(SPECIES_RATICATE, 50), where())
  local back = false
  for i = 1, 20000 do
    if F.ow() and i > 120 then back = awaitControl(1200); break end
    if i % 15 == 0 then F.press("A", 2) else F.idle(1) end
    if i % 600 == 0 and F.reportCrash(tag) then break end
  end
  for k = 1, 6 do if hasControl() then break end F.shot(tag .. "_landing_" .. k); F.idle(150) end
  back = back or awaitControl(3000)
  local after = snapshot()
  F.shot(tag .. "_after_whiteout")
  F.L("  " .. tag .. " after whiteout: " .. fmt(after) .. " respawn " .. respawn)
  F.check(tag .. ": the whiteout hands control back", back, where())
  F.check(tag .. ": the landing is the Center that set the respawn", after.grp == r.cg and after.map == r.cm, fmt(after))
  F.check(tag .. ": the party is healed", after.hp == after.maxHP and after.maxHP > 0, fmt(after))
  F.check(tag .. ": money was lost", after.money < WALLET, fmt(after))
  F.check(tag .. ": the map's music plays, not paused", after.song == after.header and not after.paused, fmt(after))

  local saved = driveSave()
  F.check(tag .. ": saved from the Start menu", saved == "done", saved)
  softReset(); F.idle(60)
  local booted = F.boot(nil, true)
  awaitControl(900)
  local cont = snapshot()
  F.shot(tag .. "_after_continue")
  F.L("  " .. tag .. " after continue: " .. fmt(cont))
  F.check(tag .. ": continued to the field", booted and hasControl(), where())
  F.check(tag .. ": same map and tile", cont.grp == after.grp and cont.map == after.map and cont.x == after.x and cont.y == after.y, fmt(cont))
  F.check(tag .. ": same money and party HP", cont.money == after.money and cont.hp == after.hp, fmt(cont))
  F.check(tag .. ": the follower is in the same state", cont.follower == after.follower, fmt(cont))
  F.check(tag .. ": the map's music plays, not paused", cont.song == cont.header and cont.song == after.song and not cont.paused, fmt(cont))
  F.check(tag .. ": the player can walk", F.step("Down") or F.step("Left") or F.step("Right"), where())
  F.step("Down"); F.idle(30)
  F.check(tag .. ": the follower comes out once the player walks", follower() == "shown", "follower " .. follower())
end

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  giveMon(SPECIES_MAGIKARP, 5, { MOVE_SPLASH })
  F.check("setup: a lone level 5 Magikarp that knows Splash", F.r8(S.gPartiesCount) == 1)
  for _, r in ipairs(REGIONS) do
    if not ONLY or r.tag:find(ONLY, 1, true) then
      F.L("== " .. r.tag .. " ==")
      local ok, e = pcall(region, r)
      if not ok then F.check(r.tag .. ": ran without a Lua error", false, tostring(e)) end
    end
  end
  F.finish()
end)
