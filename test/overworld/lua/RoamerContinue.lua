-- A roaming Latias across Save and Continue. The roamer is met in Route 117's grass and hurt and
-- paralysed in a real battle, then the player saves on Route 117 with the roamer's own map set to
-- Route 117 and continues after a soft reset. The roamer must keep the HP and status it left the
-- battle with, and when it shows up again it must be the roamer (a roamer battle on its saved HP
-- and status), never a fresh wild Latias.
--
-- Setup gives a level 100 Jolteon that knows only Nuzzle, so it moves first, paralyses and chips the
-- Latias, and the Latias then flees, and runs the Lati TV special the Littleroot scene runs. The one convenience
-- is pinning the roamer's EWRAM map onto Route 117 so the grass finds it, as RoamerParkRelease
-- does. The walk, the encounters, the battles, the save and the Continue are real input.
--
-- PW_ROAM_ONLY=<text> runs matching scenarios.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "RoamerContinue")

local ROUTE117 = { 0, 32 }
local SPECIES_JOLTEON, SPECIES_LATIAS = 135, 380
local MOVE_NUZZLE = 609
local VAR_ROAMER_POKEMON, VAR_0x8004 = 0x40D5, 0x8004
local FLAG_LATIOS_OR_LATIAS_ROAMING = 0xFF
local BATTLE_TYPE_ROAMER = 1 << 10
local ROAMER_COUNT, ROAMER_SIZE = 2, 28
local OE_CATEGORY, OE_LEVEL = 0x1B, 0x1D
local CONTEXT_RUNNING = 0
local PARTY_SIZE = 6
local USM_ICO_SAVE = 7
local SENTINEL = 0xFFFF
local ONLY = os.getenv("PW_ROAM_ONLY")

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function mapIs(m) return F.grp() == m[1] and F.mapn() == m[2] end
local function flagSet(id, on)
  local a = F.sb1() + S.SaveBlock1.flags + id // 8
  local bit = 1 << (id % 8)
  F.w8(a, on and (F.r8(a) | bit) or (F.r8(a) & (~bit & 0xFF)))
end

local function roamer(i)
  local a = F.sb1() + S.SaveBlock1.roamer + i * ROAMER_SIZE
  return { species = F.r16(a + 8), personality = F.r32(a + 4), hp = F.r16(a + 10), level = F.r8(a + 12),
           status = F.r8(a + 13), active = F.r8(a + 19) ~= 0 }
end
local function fmtRoamer(r)
  return string.format("sp=%d pid=%08X hp=%d lv=%d status=%02X active=%s", r.species, r.personality, r.hp,
    r.level, r.status, tostring(r.active))
end
local function latiSlot()
  for i = 0, ROAMER_COUNT - 1 do
    local r = roamer(i)
    if r.active and r.species == SPECIES_LATIAS then return i end
  end
end
local function roamerMap(i) return F.r8(S.sRoamerLocation + i * 2), F.r8(S.sRoamerLocation + i * 2 + 1) end
local function pinRoamer(i, m)
  F.w8(S.sRoamerLocation + i * 2, m[1]); F.w8(S.sRoamerLocation + i * 2 + 1, m[2])
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
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
  F.idle(20)
end
local function giveMon(species, level, abilityNum, moves)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = PARTY_SIZE
  le16(b, species); le16(b, level)
  le32(b, (1 << 3) | (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  le16(b, abilityNum)
  for k = 1, 4 do le16(b, moves[k] or 0) end
  b[#b + 1] = 0x02
  runScript(b)
end
local SUB3 = { 3, 2, 3, 2, 1, 1, 3, 2, 3, 2, 1, 1, 3, 2, 3, 2, 1, 1, 0, 0, 0, 0, 0, 0 }
local function setMetLevel(slotIdx, lvl)
  local b = S.gParties + slotIdx * S.Pokemon.size
  local pid, otid = F.r32(b), F.r32(b + 4)
  local key = pid ~ otid
  local addr = b + 32 + 12 * SUB3[(pid % 24) + 1]
  local old = F.r32(addr) ~ key
  local new = (old & ~(0x7F << 16)) | ((lvl & 0x7F) << 16)
  local function halves(v) return (v & 0xFFFF) + (v >> 16) end
  F.w32(addr, new ~ key)
  F.w16(b + 28, (F.r16(b + 28) - halves(old) + halves(new)) & 0xFFFF)
end
local function laTiTvScene(colour)
  local b = { 0x16 }; le16(b, VAR_0x8004); le16(b, colour)
  b[#b + 1] = 0x23; le32(b, S.InitRoamer | 1)
  b[#b + 1] = 0x16; le16(b, VAR_ROAMER_POKEMON); le16(b, colour)
  b[#b + 1] = 0x02
  runScript(b)
  flagSet(FLAG_LATIOS_OR_LATIAS_ROAMING, true)
end

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function awaitControl(budget)
  for i = 1, budget or 900 do
    if hasControl() and i > 20 then return true end
    if i % 30 == 0 then F.press("B", 2) else F.idle(1) end
  end
  return hasControl()
end

-- The overworld Latias, if one is out: generated overworld encounters use local ids 249-252, keep
-- the species in graphicsId and the roamer index (or a wild category) in warpArrowSpriteId.
local function latiObject()
  for i = 0, 15 do
    local o = S.gObjectEvents + i * S.ObjectEvent.stride
    local lid = F.r8(o + S.ObjectEvent.localId)
    if (F.r8(o) & 1) ~= 0 and lid >= 249 and lid <= 252
       and (F.r16(o + S.ObjectEvent.graphicsId) & 0x8FFF) == SPECIES_LATIAS then
      return o, F.rs16(o + S.ObjectEvent.x) - 7, F.rs16(o + S.ObjectEvent.y) - 7, F.r8(o + OE_CATEGORY),
        F.r8(o + OE_LEVEL)
    end
  end
end

local function opponent()
  local b = S.gParties + PARTY_SIZE * S.Pokemon.size
  return { hp = F.r16(b + S.Pokemon.hp), status = F.r32(b + S.Pokemon.status), level = F.r8(b + S.Pokemon.level),
           pid = F.r32(b) }
end

-- Battle driver: Nuzzle with A for `hits` turns, then hold B to run. Returns what was seen.
local function battle(hits, shotTag)
  local seen = { roamer = false, flags = 0, opp = nil }
  for _ = 1, 600 do
    if F.battlers() > 0 then break end
    F.idle(1)
  end
  F.idle(30)
  seen.flags = F.battleFlags()
  seen.roamer = (seen.flags & BATTLE_TYPE_ROAMER) ~= 0
  seen.opp = opponent()
  if shotTag then F.idle(200); F.shot(shotTag) end
  local turnsA = 0
  for i = 1, 12000 do
    if F.ow() and i > 60 then break end
    if turnsA < hits * 400 then
      if i % 25 == 0 then F.press("A", 2) else F.idle(1) end
      turnsA = turnsA + 1
    else
      joypad.set({ B = true, A = (i % 40) < 3 or nil }); emu.frameadvance()
    end
    if i % 300 == 0 and F.reportCrash("battle") then break end
    if os.getenv("PW_ROAM_TRACE") and i % 150 == 0 and i < 1500 then F.shot("battle_" .. i) end
  end
  F.idle(60)
  seen.back = F.ow()
  if seen.back then F.w8(S.gBattlersCount, 0) end
  return seen
end

-- Patrol Route 117's grass and chase the overworld Latias once it is out: walk at it, and when
-- next to it face it and press A. Returns "battle" once a battle starts.
local PATROL = { { 30, 15 }, { 34, 15 }, { 34, 17 }, { 30, 17 } }
local function toward(px, py, tx, ty)
  local dx, dy = tx - px, ty - py
  if math.abs(dx) >= math.abs(dy) then return dx > 0 and "Right" or "Left", dy > 0 and "Down" or "Up" end
  return dy > 0 and "Down" or "Up", dx > 0 and "Right" or "Left"
end
local function seekLati(slot, budget, pin, wantObject)
  local wp = 1
  for _ = 1, budget or 400 do
    if not F.ow() then
      for _ = 1, 900 do
        if F.battlers() > 0 then return "battle" end
        if F.ow() then break end
        F.idle(1)
      end
      if not F.ow() then
        F.L(string.format("  left the overworld without a battle (cb2 %08X)", F.cb2()))
        return "elsewhere"
      end
    end
    if pin then pinRoamer(slot, ROUTE117) end
    local px, py = F.pos()
    local o, ox, oy = latiObject()
    if o and wantObject then return "object" end
    local tx, ty
    if o then tx, ty = ox, oy else tx, ty = PATROL[wp][1], PATROL[wp][2] end
    if not o and px == tx and py == ty then wp = wp % #PATROL + 1
    elseif o and math.abs(tx - px) + math.abs(ty - py) == 1 then
      F.face((toward(px, py, tx, ty))); F.press("A", 2); F.idle(40)
    else
      local a, b = toward(px, py, tx, ty)
      if not F.step(a) and not F.ow() == false then
        if (tx ~= px and ty ~= py) or not o then F.step(b) end
      end
    end
  end
  return "none"
end

-- Seek until a Latias battle starts, fleeing any other wild Pokemon met on the way.
local function meetLati(slot, hits, budget, pin, shotTag)
  for _ = 1, 20 do
    local met = seekLati(slot, budget, pin ~= false)
    if met ~= "battle" then return nil, met end
    for _ = 1, 600 do if F.battlers() > 0 then break end F.idle(1) end
    F.idle(30)
    local sp = F.r16(S.gBattleMons + S.BattlePokemon.size)
    local isLati = (F.battleFlags() & BATTLE_TYPE_ROAMER) ~= 0 or sp == SPECIES_LATIAS
    local b = battle(isLati and hits or 0, isLati and shotTag or nil)
    if isLati then return b end
    F.L(string.format("  fled a wild battle, species %d (cb2 %08X battlers %d)", sp, F.cb2(), F.battlers()))
    if sp == 0 then F.shot("no_species") end
    if not b.back then return nil, "stuck" end
    awaitControl(300)
  end
  return nil, "never"
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

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  giveMon(SPECIES_JOLTEON, 100, 0, { MOVE_NUZZLE })
  setMetLevel(0, 5)
  F.check("setup: a level 100 Jolteon that knows only Nuzzle leads", F.r8(S.gPartiesCount) == 1)
  laTiTvScene(0)
  local slot = latiSlot()
  F.check("setup: the Lati TV special left Latias roaming", slot ~= nil)
  if not slot then F.finish(); return end
  local start = roamer(slot)
  F.L("  roamer " .. fmtRoamer(start))

  -- Route 117's trainers, beaten, as the game leaves them, so their sight lines stay quiet.
  for _, t in ipairs({ 364, 545, 538, 369, 227, 287, 756, 757, 755 }) do flagSet(0x500 + t, true) end
  F.check("warped to Route 117", F.warpTo(0, 0, 0, 0, 3, 2, 0, 0, 0, ROUTE117[1], ROUTE117[2], "route117"), where())
  awaitControl(300)
  F.route({ { 51, 8 }, { 36, 8 } }, "to_grass")

  -- First meeting: a real roamer battle, hurt and paralysed, then run.
  local b1, met = meetLati(slot, 2, 600)
  F.shot("after_first_battle")
  local hurt = roamer(slot)
  F.L("  after battle " .. fmtRoamer(hurt))
  F.check("the first meeting is a roamer battle", b1 and b1.roamer, b1 and string.format("flags=%08X", b1.flags) or met)
  F.check("the roamer left the battle hurt and paralysed, still roaming",
    hurt.active and hurt.hp < start.hp and hurt.status ~= 0, fmtRoamer(hurt))
  if not (b1 and b1.back) then F.finish(); return end
  awaitControl(600)

  local function scenario(tag, how, body)
    if ONLY and not tag:find(ONLY, 1, true) then return end
    F.L("== " .. tag .. " ==")
    local ok, err = pcall(body, how)
    if not ok then F.check(tag .. ": ran without a Lua error", false, tostring(err)) end
  end
  local function saveAndContinue(tag, how)
    local before = roamer(slot)
    local saved = driveSave()
    F.check(tag .. ": saved on Route 117", saved == "done", saved)
    if how == "power" then client.reboot_core() else softReset() end
    F.idle(60)
    local booted = F.boot(nil, true)
    F.check(tag .. ": continued to the field on Route 117", booted and mapIs(ROUTE117), where())
    awaitControl(600)
    local mg, mn = roamerMap(slot)
    local cont = roamer(slot)
    F.L(string.format("  after continue: roamer map %d/%d %s", mg, mn, fmtRoamer(cont)))
    F.check(tag .. ": the roamer kept its HP and status across Continue",
      cont.active and cont.hp == before.hp and cont.status == before.status and cont.personality == before.personality,
      fmtRoamer(cont))
    return before
  end
  local function checkMeeting(tag, b, met, before)
    F.check(tag .. ": it is the roamer, on its saved HP and status",
      b and b.roamer and b.opp.hp == before.hp and (b.opp.status & 0xFF) == before.status,
      b and string.format("flags=%08X opp hp=%d status=%X lv=%d", b.flags, b.opp.hp, b.opp.status, b.opp.level) or met)
    local r = roamer(slot)
    F.check(tag .. ": Latias still roams afterwards, still paralysed", r.active and r.status == before.status, fmtRoamer(r))
  end

  -- Save on Route 117 with the roamer on Route 117, continue, and meet it again in the grass.
  scenario("grass", "soft", function(how)
    pinRoamer(slot, ROUTE117)
    local before = saveAndContinue("grass", how)
    local b, met = meetLati(slot, 0, 600, true, "grass_battle")
    checkMeeting("grass", b, met, before)
    awaitControl(600)
  end)

  -- Save with the overworld Latias in view, continue, and talk to the Latias the save restored.
  for _, how in ipairs({ "soft", "power" }) do
    scenario("visible (" .. how .. ")", how, function()
      local tag = "visible (" .. how .. ")"
      local seen
      for _ = 1, 20 do
        seen = seekLati(slot, 600, true, true)
        if seen ~= "battle" then break end
        local b = battle(0)
        F.L(string.format("  fled a battle on the way (flags %08X)", b.flags))
        awaitControl(300)
      end
      local o, ox, oy, cat = latiObject()
      F.check(tag .. ": the overworld Latias is out", seen == "object" and o ~= nil and cat == slot,
        string.format("%s cat=%s", seen, tostring(cat)))
      if not o then return end
      local before = saveAndContinue(tag, how)
      local o2, ox2, oy2, cat2 = latiObject()
      F.check(tag .. ": the save restored the overworld Latias", o2 ~= nil and cat2 == slot,
        string.format("at (%s,%s) cat=%s", tostring(ox2), tostring(oy2), tostring(cat2)))
      if not o2 then return end
      local b, met = meetLati(slot, 0, 300, false, (tag:gsub("[^%w]", "_")) .. "_battle")
      if b and not b.roamer then
        F.L(string.format("  a plain wild Latias: lv=%d hp=%d pid=%08X (roamer pid %08X)", b.opp.level, b.opp.hp,
          b.opp.pid, before.personality))
      end
      checkMeeting(tag, b, met, before)
      awaitControl(600)
    end)
  end
  F.finish()
end)
