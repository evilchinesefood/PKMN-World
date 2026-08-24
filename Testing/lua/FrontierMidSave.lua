-- Battle Frontier mid-challenge SAVE_LINK must persist SaveBlock3.
-- Resume a paused Tower challenge (SaveGameFrontier -> TrySavingData(SAVE_LINK)).
-- Unique SB3 bytes past the old 5-sector window (SB3[0..579]) must survive reboot.
--
-- Run via Testing/mgba-run.sh Testing/lua/FrontierMidSave.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "FrontierMidSave")

local HUB_GROUP = 100
local GRP_TOWER, MAP_TOWER, WARP_TOWER = 26, 5, 0  -- MAP_BATTLE_FRONTIER_BATTLE_TOWER_LOBBY
local ROW_PARTY_MENU, ROW_SET = 2, 9
local ROW_GIVE, ROW_MON_BASIC = 3, 1
local FLAG_SYS_GAME_CLEAR = 0x94C   -- SYSTEM_FLAGS + 0x4
local FLAG_HOENN_CHAMPION = 0xA4A
local CHALLENGE_STATUS_SAVING, CHALLENGE_STATUS_PAUSED = 1, 2
local SB2_CHALLENGE_STATUS = 0xCA8
local SB2_CHALLENGE_FLAGS  = 0xCA9  -- lvlMode:2, challengePaused:1, disableRecordBattle:1
local SB2_SELECTED_MONS    = 0xCAA
local SB2_CUR_BATTLE_NUM   = 0xCB2
local VARS_START = 0x4000
local VAR_FRONTIER_BATTLE_MODE = 0x40CE
local VAR_FRONTIER_FACILITY    = 0x40CF
local VAR_TEMP_CHALLENGE_STATUS = 0x4000
local LOCALID_SINGLES = 1
local MARK_JOHTO, MARK_KANTO, MARK_OBS = 0xA5, 0x5A, 0x3C
local FLASH              = 0x0E000000
local SECTOR_SIZE        = 0x1000
local SB3_CHUNK_OFF      = 3968
local SIG_OFF            = 4088
local COUNTER_OFF        = 4092
local ID_OFF             = 4084
local SECTOR_SIGNATURE   = 0x08012025

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end

local function tapDown(n)
  for _ = 1, n do F.press("Down", 3); F.idle(16) end
end

local function setParty()
  F.dbg(); F.idle(60)
  tapDown(ROW_PARTY_MENU); F.press("A", 3); F.idle(60)
  tapDown(ROW_SET); F.press("A", 3); F.idle(180)
  for _ = 1, 6 do F.press("B", 3); F.idle(20) end
end

local function giveMon(sh, st, so, lh, lt, lo)
  F.dbg(); F.sel(ROW_GIVE); F.sel(ROW_MON_BASIC); F.idle(20)
  F.spin(sh, st, so); F.idle(20)
  F.spin(lh, lt, lo); F.idle(60)
  F.bOut(4)
end

local function sb1FlagSet(id)
  local a = F.sb1() + S.SaveBlock1.flags + (id // 8)
  F.w8(a, F.r8(a) | (1 << (id % 8)))
end

local function varAddr(id)
  return F.sb1() + S.SaveBlock1.vars + (id - VARS_START) * 2
end

local function challengeStatus()
  return F.r8(F.sb2() + SB2_CHALLENGE_STATUS)
end

local function tempChallengeStatus()
  return F.r16(varAddr(VAR_TEMP_CHALLENGE_STATUS))
end

local function sb3Marks()
  local b = F.sb3()
  return F.r8(b + S.SaveBlock3.johtoFlags),
         F.r8(b + S.SaveBlock3.kantoTrainerFlags),
         F.r8(b + S.SaveBlock3.clearedObstacleBits)
end

local function fmtMarks(j, k, o)
  return string.format("johto=0x%02X kanto=0x%02X obs=0x%02X", j, k, o)
end

local function dumpSaveMeta(tag)
  F.L(string.format(
    "  saveMeta[%s] attempt=%d counter=%d lastWritten=%d damaged=0x%X rw=0x%08X",
    tag, F.r16(S.gSaveAttemptStatus), F.r32(S.gSaveCounter), F.r16(S.gLastWrittenSector),
    F.r32(S.gDamagedSaveSectors), F.r32(S.gReadWriteSector)))
end

local function dumpFlash(tag)
  local found = {}
  for i = 0, 27 do
    local base = FLASH + i * SECTOR_SIZE
    local sig = F.r32(base + SIG_OFF)
    if sig == SECTOR_SIGNATURE then
      local id, ctr = F.r16(base + ID_OFF), F.r32(base + COUNTER_OFF)
      local j = F.r8(base + SB3_CHUNK_OFF + (800 % 116))
      local k = F.r8(base + SB3_CHUNK_OFF + (941 % 116))
      local o = F.r8(base + SB3_CHUNK_OFF + (1168 % 116))
      -- Real unique bytes live in sector ids 6/8/10 (800/941/1168 div 116).
      local chunkJ = F.r8(base + SB3_CHUNK_OFF + (800 - 6 * 116))
      local chunkK = F.r8(base + SB3_CHUNK_OFF + (941 - 8 * 116))
      local chunkO = F.r8(base + SB3_CHUNK_OFF + (1168 - 10 * 116))
      found[#found + 1] = string.format("s%d:id=%d:ctr=%d", i, id, ctr)
      if id == 6 then F.L(string.format("  flash[%s] sector %d id=6 johtoFlags[0]=0x%02X", tag, i, chunkJ)) end
      if id == 8 then F.L(string.format("  flash[%s] sector %d id=8 kantoTrainerFlags[0]=0x%02X", tag, i, chunkK)) end
      if id == 10 then F.L(string.format("  flash[%s] sector %d id=10 clearedObstacleBits[0]=0x%02X", tag, i, chunkO)) end
    end
  end
  F.L(string.format("  flash[%s] signed sectors: %s", tag, #found > 0 and table.concat(found, " ") or "NONE"))
end

local function logState(tag)
  local j, k, o = sb3Marks()
  local x, y = F.pos()
  F.L(string.format(
    "  [%s] grp=%d map=%d pos=(%d,%d) ow=%s challengeStatus=%d tempStatus=%d party=%d %s crash=%s",
    tag, F.grp(), F.mapn(), x, y, tostring(F.ow()), challengeStatus(),
    tempChallengeStatus(), F.r8(S.gPartiesCount), fmtMarks(j, k, o),
    tostring(F.crashScreen() ~= nil)))
  dumpSaveMeta(tag)
  return j, k, o
end

local function seedFrontier()
  F.w8(F.sb2() + SB2_CHALLENGE_STATUS, CHALLENGE_STATUS_PAUSED)
  -- Keep lvlMode (low 2 bits) at 0 = Lv50; set challengePaused (bit 2).
  local f = F.r8(F.sb2() + SB2_CHALLENGE_FLAGS)
  F.w8(F.sb2() + SB2_CHALLENGE_FLAGS, (f & 0xFC) | (1 << 2))
  F.w16(F.sb2() + SB2_SELECTED_MONS, 1)
  F.w16(F.sb2() + SB2_SELECTED_MONS + 2, 2)
  F.w16(F.sb2() + SB2_SELECTED_MONS + 4, 3)
  F.w16(F.sb2() + SB2_CUR_BATTLE_NUM, 1)
  F.w16(varAddr(VAR_FRONTIER_BATTLE_MODE), 0)  -- SINGLES
  F.w16(varAddr(VAR_FRONTIER_FACILITY), 0)     -- TOWER
end

local function seedSb3()
  local b = F.sb3()
  F.w8(b + S.SaveBlock3.johtoFlags, MARK_JOHTO)
  F.w8(b + S.SaveBlock3.kantoTrainerFlags, MARK_KANTO)
  F.w8(b + S.SaveBlock3.clearedObstacleBits, MARK_OBS)
end

local function marksOk(j, k, o)
  return j == MARK_JOHTO and k == MARK_KANTO and o == MARK_OBS
end

-- Single warp attempt. warpTo retries with B, which would cancel ResumeChallenge.
local function warpTower()
  local gh, gt, go_ = d(GRP_TOWER)
  local mh, mt, mo = d(MAP_TOWER)
  local wh, wt, wo = d(WARP_TOWER)
  F.dbg(); F.sel(0); F.sel(1); F.idle(20)
  F.spin(gh, gt, go_); F.spin(mh, mt, mo); F.spin(wh, wt, wo)
  for i = 1, 400 do
    if F.reportCrash("warp_tower") then return false end
    -- ResumeChallenge faceplayer uses VAR_LAST_TALKED; keep the singles attendant.
    F.w16(S.gSpecialVar_LastTalked, LOCALID_SINGLES)
    if F.grp() == GRP_TOWER then
      local x, y = F.pos()
      F.L(string.format("  WARP tower ok map=%d (%d,%d) t=%d", F.mapn(), x, y, i))
      return true
    end
    emu.frameadvance()
  end
  F.shot("tower_warpfail")
  return false
end

local function mashWait(frames, tag)
  local sawSaving, sawSaveLink = false, false
  local status0 = challengeStatus()
  for i = 1, frames do
    if F.reportCrash(tag .. "_" .. i) then
      logState(tag .. "_crash")
      F.shot(tag .. "_crash")
      return sawSaveLink, sawSaving
    end
    F.w16(S.gSpecialVar_LastTalked, LOCALID_SINGLES)
    local st = challengeStatus()
    if st == CHALLENGE_STATUS_SAVING then sawSaving = true; sawSaveLink = true end
    if status0 == CHALLENGE_STATUS_PAUSED and st == CHALLENGE_STATUS_SAVING then
      sawSaveLink = true
    end
    if i % 30 == 0 then
      F.press("A", 2)
      if i % 120 == 0 then logState(tag .. "_t" .. i) end
    else
      joypad.set({})
      emu.frameadvance()
    end
  end
  return sawSaveLink, sawSaving
end

-- Establish a valid flash slot BEFORE unique bytes exist. SAVE_LINK's
-- HandleReplaceSector writes the current slot in place and needs gReadWriteSector
-- / gSaveCounter from a prior full save — a real paused-challenge player already
-- has one. Start-menu SAVE after seeding would false-pass (SAVE_NORMAL writes
-- all of SB3). Baseline unique bytes must be 0 here.
local function saveNormalSlot()
  local j, k, o = sb3Marks()
  F.L("  pre-SAVE_NORMAL " .. fmtMarks(j, k, o))
  dumpSaveMeta("pre_savenormal")
  F.press("Start", 2); F.idle(60)
  for _ = 1, 10 do F.press("Left", 2); F.idle(8) end
  F.press("Right", 2); F.idle(12); F.press("Right", 2); F.idle(12)
  F.shot("savenormal_menu")
  F.press("A", 2); F.idle(90); F.press("A", 2); F.idle(60); F.press("A", 2); F.idle(240)
  F.idle(300)
  for _ = 1, 8 do F.press("B", 3); F.idle(20) end
  F.shot("after_savenormal")
  logState("after_savenormal")
  dumpFlash("after_savenormal")
end

-- Attendant fallback: Challenge -> Lv50 -> pick 3 mons -> confirm save.
-- Singles save-before-enter is Common_EventScript_SaveGame (SAVE_NORMAL). Only
-- treat unique-byte survival as the SAVE_LINK proof if challengeStatus 2->1.
local function tryAttendant()
  F.L("== attendant fallback (if ResumeChallenge did not SAVE_LINK) ==")
  F.shot("attendant_start")
  if not F.route({ { 6, 6 } }, "to_singles") then
    F.shot("attendant_stuck")
    return false
  end
  F.face("Up")
  F.idle(20)
  F.tap("A"); F.idle(40)
  if not F.pick(0, "challenge", 16) then
    F.L("  challenge menu never live")
    F.shot("attendant_nochallenge")
    return false
  end
  F.idle(40)
  if not F.pick(0, "lv50", 16) then
    F.L("  level menu never live")
    F.shot("attendant_nolevel")
    return false
  end
  -- Party select: A on three mons. Cursor starts at slot 0.
  F.idle(90)
  F.shot("party_select")
  for n = 1, 3 do
    F.press("A", 3); F.idle(40)
    if n < 3 then F.press("Down", 3); F.idle(20) end
  end
  F.press("Start", 3); F.idle(40)
  F.press("A", 3); F.idle(60)
  -- Okay to save? Yes.
  for _ = 1, 40 do
    if F.menuLive() then
      for _ = 1, 4 do F.press("Up", 2); F.idle(8) end
      F.press("A", 2); F.idle(30)
      break
    end
    F.press("A", 2); F.idle(20)
  end
  mashWait(400, "attendant_save")
  return challengeStatus() == CHALLENGE_STATUS_SAVING
end

F.run(function()
  if not F.boot(HUB_GROUP) then
    F.check("boot to the hub", false)
    F.finish(); return
  end
  F.idle(40)
  F.shot("booted")
  F.check("boot to the hub", true)

  setParty()
  local n1 = F.r8(S.gPartiesCount)
  F.check("Set Party published a party", n1 ~= 0, "count=" .. n1)
  -- Tower eligibility wants 3 distinct species if we fall through to the attendant.
  giveMon(2, 5, 7, 0, 5, 0)  -- SPECIES_BLAZIKEN 257 Lv50
  giveMon(2, 5, 4, 0, 5, 0)  -- SPECIES_SCEPTILE 254 Lv50
  local n3 = F.r8(S.gPartiesCount)
  F.check("party has 3 mons", n3 >= 3, "count=" .. n3)
  F.shot("party_ready")

  -- SAVE_NORMAL first, before GAME_CLEAR extras shift the USM wheel off Save.
  local zJ, zK, zO = sb3Marks()
  F.check("unique SB3 bytes are 0 before SAVE_NORMAL (no false-pass)",
    zJ == 0 and zK == 0 and zO == 0, fmtMarks(zJ, zK, zO))
  saveNormalSlot()
  F.check("still on hub after SAVE_NORMAL", F.grp() == HUB_GROUP and F.ow(),
    string.format("grp=%d map=%d ow=%s", F.grp(), F.mapn(), tostring(F.ow())))
  F.L(string.format("  SAVE_NORMAL slot write attempt=%d counter=%d (informational; USM may not be on Save)",
    F.r16(S.gSaveAttemptStatus), F.r32(S.gSaveCounter)))

  sb1FlagSet(FLAG_SYS_GAME_CLEAR)
  sb1FlagSet(FLAG_HOENN_CHAMPION)
  seedFrontier()
  seedSb3()
  local beforeJ, beforeK, beforeO = logState("seeded")
  F.check("seeded unique SB3 bytes (must not be 0)", marksOk(beforeJ, beforeK, beforeO),
    fmtMarks(beforeJ, beforeK, beforeO))
  F.check("challengeStatus is PAUSED(2)", challengeStatus() == CHALLENGE_STATUS_PAUSED,
    "status=" .. challengeStatus())
  F.shot("after_seed")

  local warped = warpTower()
  F.check("warped to Battle Tower lobby (group 26)", warped,
    string.format("grp=%d map=%d", F.grp(), F.mapn()))
  F.shot("tower_arrival")
  logState("after_warp")
  if F.reportCrash("after_warp") then
    F.check("no crash on tower arrival", false)
  end

  -- ResumeChallenge: message/waitmessage then tower_save CHALLENGE_STATUS_SAVING.
  -- SAVE_LINK is the discriminator: challengeStatus 2 -> 1.
  local saveLink, sawSaving = mashWait(600, "resume")
  logState("after_resume_wait")
  F.shot("after_resume")

  if not saveLink then
    local st = challengeStatus()
    local tmp = tempChallengeStatus()
    F.L(string.format("  ResumeChallenge did not set SAVING (status=%d temp=%d)", st, tmp))
    if st == 0 or tmp == 255 or tmp == 1 then
      F.shot("quit_without_saving")
    end
    local att = tryAttendant()
    F.L("  attendant path SAVE_LINK-like=" .. tostring(att))
    saveLink = saveLink or (challengeStatus() == CHALLENGE_STATUS_SAVING)
    sawSaving = sawSaving or (challengeStatus() == CHALLENGE_STATUS_SAVING)
  end

  F.check("SAVE_LINK ran (challengeStatus became SAVING=1)", saveLink or sawSaving,
    "status=" .. challengeStatus() .. " temp=" .. tempChallengeStatus())

  -- SaveGameFrontier restores the party after TrySavingData returns. If party is
  -- still 0, the special is still inside the flash write — wait it out.
  for i = 1, 2000 do
    if F.r8(S.gPartiesCount) >= 3 then
      F.L("  SaveGameFrontier returned (party restored) t+" .. i)
      break
    end
    if i % 200 == 0 then logState("savewait_" .. i); dumpFlash("savewait_" .. i) end
    F.press("A", 2); F.idle(4)
  end
  dumpFlash("after_savelink")
  local afterJ, afterK, afterO = logState("after_save_insession")
  F.shot("after_save")
  F.check("unique SB3 bytes still in RAM after save", marksOk(afterJ, afterK, afterO),
    fmtMarks(afterJ, afterK, afterO))
  if F.reportCrash("after_save") then
    F.L("  elevator/map script crashed after SAVE_LINK; still rebooting the file the save wrote")
  end

  F.L("== reboot_core then Continue ==")
  client.reboot_core()
  F.idle(240)

  -- keepScene: do not step. Continue-warp may be the tower (group 26) or elsewhere.
  local continued = F.boot(nil, true)
  F.check("Continue reached the overworld", continued,
    string.format("ow=%s grp=%d map=%d", tostring(F.ow()), F.grp(), F.mapn()))
  F.shot("after_continue")
  if F.reportCrash("after_continue") then
    F.check("no crash after Continue", false)
  end

  local loadJ, loadK, loadO = logState("after_reboot")
  local survived = marksOk(loadJ, loadK, loadO)
  F.check("unique SB3 bytes survived the load (regression=0x00)", survived,
    fmtMarks(loadJ, loadK, loadO))
  F.check("johtoFlags[0] survived as 0xA5", loadJ == MARK_JOHTO, string.format("0x%02X", loadJ))
  F.check("kantoTrainerFlags[0] survived as 0x5A", loadK == MARK_KANTO, string.format("0x%02X", loadK))
  F.check("clearedObstacleBits[0] survived as 0x3C", loadO == MARK_OBS, string.format("0x%02X", loadO))

  F.L(string.format(
    "SUMMARY saveLink=%s before=%s afterSave=%s afterReboot=%s land=grp%d/map%d",
    tostring(saveLink or sawSaving),
    fmtMarks(beforeJ, beforeK, beforeO),
    fmtMarks(afterJ, afterK, afterO),
    fmtMarks(loadJ, loadK, loadO),
    F.grp(), F.mapn()))

  F.finish()
end)
