-- Hall of Fame records shared by all three regions, and the post-credits respawn in each.
--
-- Kanto records and shows its Hall of Fame with hall_of_fame_frlg.c, Hoenn and Johto with
-- hall_of_fame.c. Both write the same save sectors (SAVE_HALL_OF_FAME) and both PC viewers read
-- them, so they must agree on how many teams the buffer holds. The suite enters the Kanto Hall of
-- Fame 31 times, then reads the record from a Hoenn Pokemon Center PC: the viewer must open on the
-- newest team, numbered by GAME_STAT_ENTERED_HOF. Then a Hoenn record (the 32nd) must be the
-- newest team in a Kanto Center PC, and a first Johto clear (the 33rd) the newest in Hoenn again.
-- The buffer has room for all 33, so the first record must survive each viewer read.
--
-- Every record is made by the game's own Hall of Fame script: a debug warp puts the player on the
-- room's entrance (for Johto, VAR_LEAGUE_STATE 6, which the Champion's room leaves), the cutscene,
-- the recording screen and the soft reset run on a seeded mash of single A, B, Start and Select
-- presses, and the title screen and main menu's Continue run on the same mash. Each Continue must
-- land on that region's respawn with control. Setup gives the Pokedex, as any champion has. The lead is replaced before each entry with a
-- different species so every record is distinguishable. The PCs are walked to and used by input.
--
-- PW_HOF_SEED=<n> (runner --env) reseeds the mash. PW_HOF_KANTO=<n> sets the Kanto entry count.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/HofRecordsCrossRegion.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "HofRecordsCrossRegion")

local KANTO_ENTRIES = tonumber(os.getenv("PW_HOF_KANTO") or "") or 31
local seed = tonumber(os.getenv("PW_HOF_SEED") or "") or 6006
local KANTO, JOHTO, HOENN = 1, 2, 3
local CONTEXT_RUNNING = 0
local GAME_STAT_ENTERED_HOF = 10
local FLAG_SYS_GAME_CLEAR = 0x94C
local FLAG_SYS_POKEDEX_GET = 0x949
local VAR_LEAGUE_STATE = 0xA080 + 0x3B
local REGION_VARS_START = 0xA000
local HOF_MON_SIZE, HOF_TEAM_SIZE = 24, 24 * 6

local HOF = {
  [KANTO] = { g = 35, m = 80, respawn = { 37, 0 }, name = "Kanto" },
  [HOENN] = { g = 16, m = 11, name = "Hoenn" },
  [JOHTO] = { g = 99, m = 10, respawn = { 75, 0 }, name = "Johto" },
}
-- Center door warp, the tile below the PC, and the walk from the door.
local PCS = {
  [HOENN] = { g = 2, m = 2, warp = 0, path = { { 7, 4 }, { 10, 4 }, { 10, 2 } }, name = "Oldale Center" },
  [KANTO] = { g = 39, m = 4, warp = 1, path = { { 7, 4 }, { 11, 4 }, { 11, 2 } }, name = "Viridian Center" },
}

local function rand(n)
  seed = (seed * 1103515245 + 12345) % 2147483648
  return (seed // 65536) % n
end

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function region() return F.r8(S.gCurrentRegion) end
local function gender() return F.r8(F.sb2() + S.SaveBlock2.playerGender) end
local function gameStat(i)
  return F.r32(F.sb1() + S.SaveBlock1.gameStats + 4 * i) ~ F.r32(F.sb2() + S.SaveBlock2.encryptionKey)
end
local function flagSet(id) return (F.r8(F.sb1() + S.SaveBlock1.flags + (id // 8)) & (1 << (id % 8))) ~= 0 end
local function setFlag(id)
  local a = F.sb1() + S.SaveBlock1.flags + (id // 8)
  F.w8(a, F.r8(a) | (1 << (id % 8)))
end
local function regionVarSet(id, v) F.w16(F.sb3() + S.SaveBlock3.regionVars + (id - REGION_VARS_START) * 2, v) end

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
local function personality(slot) return F.r32(S.gParties + slot * S.Pokemon.size) end
local function createMon(slot, species, level)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = slot
  le16(b, species); le16(b, level)
  le32(b, 0)
  b[#b + 1] = 0x02
  local p0 = personality(slot < 6 and slot or 0)
  for _ = 1, 5 do
    awaitControl(300)
    runScript(b); F.idle(30)
    if personality(slot < 6 and slot or 0) ~= p0 then return true end
  end
  F.L(string.format("  createMon(%d, %d) never changed the slot", slot, species))
  return false
end

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function warp(g, m, w, tag)
  local gh, gt, go = d(g)
  local mh, mt, mo = d(m)
  local wh, wt, wo = d(w)
  return F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, g, m, tag)
end

-- One button at a time, never the soft-reset chord and never a direction (Down on the main menu
-- would pick New Game).
local MASH = { "A", "A", "A", "B", "Start", "Select" }
local function mashUntil(cond, budget, tag)
  for f = 1, budget do
    if cond() then return true, f end
    if f % 200 == 0 and F.reportCrash(tag) then return false, f end
    if f % 6 == 0 then
      joypad.set({ [MASH[rand(#MASH) + 1]] = true })
    else
      joypad.set({})
    end
    emu.frameadvance()
  end
  return cond(), budget
end

-- Enter a Hall of Fame room and play the cutscene, the recording, the soft reset and Continue.
local function enterHof(r, tag, shoot)
  local h = HOF[r]
  if not warp(h.g, h.m, 0, tag) then
    F.check(tag .. ": warped into the " .. h.name .. " Hall of Fame", false, where())
    return false
  end
  local left = mashUntil(function() return not F.ow() end, 12000, tag .. "_cutscene")
  if not left then
    F.shot(tag .. "_no_hof_screen")
    F.check(tag .. ": the Hall of Fame screen opened", false, where())
    return false
  end
  if shoot then
    mashUntil(function() return false end, 420, tag .. "_screen")
    F.shot(tag .. "_hof_screen")
  end
  local back, frames = mashUntil(function() return F.ow() end, 40000, tag .. "_record")
  if not back then
    F.shot(tag .. "_no_continue")
    F.check(tag .. ": Continue returned to the field after the Hall of Fame", false,
      string.format("cb2=0x%08X", F.cb2()))
    return false
  end
  local ctl = awaitControl(900)
  F.L(string.format("  %s: back on %s after %d frames, control=%s", tag, where(), frames, tostring(ctl)))
  return ctl
end

local function respawnFor(r)
  if r == HOENN then
    return gender() == 0 and { 1, 1 } or { 1, 3 }
  end
  return HOF[r].respawn
end

-- ---- the PC viewer ----------------------------------------------------------------------------
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
          F.shot(tag)
          F.press("A", 2)
          for _ = 1, 60 do
            if not scriptMenuActive() then return true end
            F.idle(1)
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
local function viewerTask()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    local fn = F.r32(a + S.Task.func) & 0xFFFFFFFE
    if F.r8(a + S.Task.isActive) ~= 0 then
      for _, v in ipairs(S.HofPCInputFunctions) do
        if fn == (v & 0xFFFFFFFE) then return a end
      end
    end
  end
  return nil
end
local function teamLead(team)
  local buf = F.r32(S.gHoFSaveBuffer)
  if buf < 0x02000000 or buf >= 0x02040000 then return -1 end
  return F.r16(buf + team * HOF_TEAM_SIZE + 8) >> 1
end

-- Walk to a Center PC, open the Hall of Fame row, and read which team the viewer shows first.
local function viewHof(r, wantLead, wantNo, tag)
  local pc = PCS[r]
  if not warp(pc.g, pc.m, pc.warp, tag) then
    F.check(tag .. ": warped to the " .. pc.name, false, where())
    return
  end
  awaitControl(300)
  if not F.route(pc.path, tag .. "_walk") then
    F.check(tag .. ": walked to the " .. pc.name .. " PC", false, where())
    return
  end
  F.face("Up"); F.press("A", 3); F.idle(40)
  if not menu(2, tag .. "_pcmenu") then
    F.check(tag .. ": the PC offered its Hall of Fame row", false, where())
    return
  end
  local task
  for _ = 1, 600 do
    task = viewerTask()
    if task then break end
    F.idle(2)
  end
  F.check(tag .. ": the Hall of Fame viewer opened", task ~= nil)
  if not task then F.shot(tag .. "_noviewer"); return end
  F.idle(60)
  local team = F.rs16(task + S.Task.data + 0)
  local no = F.rs16(task + S.Task.data + 2)
  local lead = teamLead(team)
  F.shot(tag .. "_viewer")
  F.L(string.format("  %s: viewer shows team index %d, HOF No. %d, lead species %d", tag, team, no, lead))
  F.check(tag .. ": the viewer opens on the newest record (lead species " .. wantLead .. ")",
    lead == wantLead, string.format("team %d lead %d", team, lead))
  F.check(tag .. ": numbered " .. wantNo, no == wantNo, "No. " .. no)
  F.check(tag .. ": the first record is still kept", teamLead(0) == 1, "oldest lead " .. teamLead(0))
  for _ = 1, 8 do
    if F.ow() and not viewerTask() then break end
    F.press("B", 2); F.idle(40)
  end
  for _ = 1, 4 do F.press("B", 2); F.idle(30) end
  F.check(tag .. ": the viewer closed back to the field", awaitControl(900), where())
end

-- ---- run --------------------------------------------------------------------------------------
F.run(function()
  if not F.boot(100) then F.check("booted", false); F.finish(); return end

  -- Every Pokedex holder has the National Dex (ResyncCurrentRegionFromMap), as a champion would.
  setFlag(FLAG_SYS_POKEDEX_GET)
  createMon(6, 1, 50)
  local made = 0
  for k = 1, KANTO_ENTRIES do
    createMon(0, k, 50)
    local tag = string.format("kanto%02d", k)
    if not enterHof(KANTO, tag, k == 1) then break end
    made = k
    local want = respawnFor(KANTO)
    if k == 1 or k == KANTO_ENTRIES then
      F.shot(tag .. "_respawn")
      F.check(tag .. ": Continue lands in Pallet Town", F.grp() == want[1] and F.mapn() == want[2], where())
      F.check(tag .. ": the region is Kanto", region() == KANTO, "region=" .. region())
      F.check(tag .. ": FLAG_SYS_GAME_CLEAR is set", flagSet(FLAG_SYS_GAME_CLEAR))
    elseif not (F.grp() == want[1] and F.mapn() == want[2]) then
      F.check(tag .. ": Continue lands in Pallet Town", false, where())
    end
  end
  F.check("all " .. KANTO_ENTRIES .. " Kanto Hall of Fame entries ran", made == KANTO_ENTRIES, "made " .. made)
  F.check("GAME_STAT_ENTERED_HOF counts them", gameStat(GAME_STAT_ENTERED_HOF) == made,
    "stat=" .. gameStat(GAME_STAT_ENTERED_HOF))

  viewHof(HOENN, made, made, "hoenn_pc_after_kanto")

  local hoennLead = made + 1
  createMon(0, hoennLead, 50)
  if enterHof(HOENN, "hoenn", true) then
    local want = respawnFor(HOENN)
    F.shot("hoenn_respawn")
    F.check("hoenn: Continue lands in the player's Littleroot bedroom",
      F.grp() == want[1] and F.mapn() == want[2], where())
    F.check("hoenn: the region is Hoenn", region() == HOENN, "region=" .. region())
  end
  viewHof(KANTO, hoennLead, made + 1, "kanto_pc_after_hoenn")

  local johtoLead = made + 2
  createMon(0, johtoLead, 50)
  regionVarSet(VAR_LEAGUE_STATE, 6)
  if enterHof(JOHTO, "johto", true) then
    local want = respawnFor(JOHTO)
    F.shot("johto_respawn")
    F.check("johto: Continue lands in New Bark Town", F.grp() == want[1] and F.mapn() == want[2], where())
    F.check("johto: the region is Johto", region() == JOHTO, "region=" .. region())
  end
  viewHof(HOENN, johtoLead, made + 2, "hoenn_pc_after_johto")
  F.check("GAME_STAT_ENTERED_HOF counts every entry", gameStat(GAME_STAT_ENTERED_HOF) == made + 2,
    "stat=" .. gameStat(GAME_STAT_ENTERED_HOF))
  F.finish()
end)
