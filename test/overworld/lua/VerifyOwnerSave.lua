-- A real save on this build: it loads where it was saved, upgrades to the current format, survives
-- an in-game save, and comes back unchanged after a soft reset and Continue.
--
--   test/overworld/mgba-run.sh test/overworld/lua/VerifyOwnerSave.lua pokemonworld.gba <copy-of-save>
--
-- The save must be the raw 131072-byte flash image (truncate an mGBA .sav's 16-byte RTC trailer).
-- Expectations come from the fixture itself, because a refused save boots a new game that can land
-- on the same map (the hub) and pass any location check; only the saved play time tells them apart.
local S = require("symbols")
local F = require("lib").new(S, "VerifyOwnerSave")

local SECTOR, SECTOR_SIG = 4096, 0x08012025
local USM_ICO_SAVE = 7
local SENTINEL, SAVE_OK = 0xFFFF, 1
local PLAY_HOURS, PLAY_MINUTES = 0x0E, 0x10
local MON, BOX_MON = S.Pokemon.size, S.BoxPokemon.size

local function fixture()
  local dir = (os.getenv("PW_SYMBOLS") or ""):match("^(.*[/\\])") or ""
  local fh = io.open(dir .. (os.getenv("PW_ROM_NAME") or "Verify1") .. ".sav", "rb")
  if not fh then return nil end
  local flash = fh:read("a"); fh:close()
  local slots = {}
  for s = 0, #flash // SECTOR - 1 do
    local id, _, sig, counter = string.unpack("<I2I2I4I4", flash, s * SECTOR + 0xFF4 + 1)
    if sig == SECTOR_SIG then
      slots[counter] = slots[counter] or {}
      slots[counter][id] = s * SECTOR + 1
    end
  end
  local newest
  for counter in pairs(slots) do if not newest or counter > newest then newest = counter end end
  local slot = newest and slots[newest]
  if not (slot and slot[0] and slot[1]) then return nil end
  local sb2, sb1 = slot[0], slot[1]
  return {
    ver = string.unpack("B", flash, sb2 + S.SaveBlock2.saveVersion),
    play = string.unpack("<I2", flash, sb2 + PLAY_HOURS) * 60 + string.unpack("B", flash, sb2 + PLAY_MINUTES),
    x = string.unpack("<i2", flash, sb1 + S.SaveBlock1.x),
    y = string.unpack("<i2", flash, sb1 + S.SaveBlock1.y),
    grp = string.unpack("b", flash, sb1 + S.SaveBlock1.mapGroup),
    map = string.unpack("b", flash, sb1 + S.SaveBlock1.mapNum),
  }
end

local function order(p)
  local o = {}
  for i = 0, 3 do o[i] = F.r8(S.sSubstructOffsets + i * 24 + p % 24) * 3 end
  return o
end
local function growth(a)
  local p = F.r32(a)
  local w = F.r32(a + 32 + order(p)[0] * 4) ~ p ~ F.r32(a + 4)
  return w & 0x7FF, w >> 16
end
local function hashRange(a, len)
  local h = 0
  for i = 0, len - 1 do h = (h * 31 + F.r8(a + i)) & 0xFFFFFFFF end
  return h
end

local function snapshot()
  local s = {}
  s.grp, s.map = F.grp(), F.mapn()
  s.x, s.y = F.pos()
  s.ver = F.r8(F.sb2() + S.SaveBlock2.saveVersion)
  s.play = F.r16(F.sb2() + PLAY_HOURS) * 60 + F.r8(F.sb2() + PLAY_MINUTES)
  s.money = F.money()
  s.n = F.r8(S.gPartiesCount)
  local party = {}
  for i = 0, s.n - 1 do
    local a = S.gParties + i * MON
    local species, item = growth(a)
    party[#party + 1] = ("%d/L%d/hp%d/i%d"):format(species, F.r8(a + S.Pokemon.level), F.r16(a + S.Pokemon.hp), item)
  end
  s.party = table.concat(party, ",")
  local base = F.r32(S.gPokemonStoragePtr) + 4
  s.boxed, s.boxhash = 0, 0
  for slot = 0, 14 * 30 - 1 do
    local p = F.r32(base + slot * BOX_MON)
    if p ~= 0 then
      s.boxed = s.boxed + 1
      s.boxhash = (s.boxhash * 31 + p + growth(base + slot * BOX_MON)) & 0xFFFFFFFF
    end
  end
  -- Vars are left out: step counters and the re-keyed game stats move on every save and Continue.
  s.flags = hashRange(F.sb1() + S.SaveBlock1.flags, S.SaveBlock1.vars - S.SaveBlock1.flags)
  return s
end

local KEYS = { "grp", "map", "x", "y", "ver", "play", "money", "n", "party", "boxed", "boxhash", "flags" }
local function fmt(s)
  local t = {}
  for _, k in ipairs(KEYS) do t[#t + 1] = k .. "=" .. tostring(s[k]) end
  return table.concat(t, " ")
end
local function differences(a, b)
  local d = {}
  for _, k in ipairs(KEYS) do
    if k ~= "play" and a[k] ~= b[k] then d[#d + 1] = ("%s %s->%s"):format(k, tostring(a[k]), tostring(b[k])) end
  end
  return table.concat(d, "; ")
end

local function manualSave()
  F.w16(S.gSaveAttemptStatus, SENTINEL)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_SAVE) then return "noicon" end
  for i = 1, 3000 do
    if F.r16(S.gSaveAttemptStatus) ~= SENTINEL then
      F.idle(30)
      for _ = 1, 6 do F.press("B", 2); F.idle(20) end
      return F.r16(S.gSaveAttemptStatus) == SAVE_OK and "done" or "error"
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
  local want = fixture()
  if not F.check("fixture holds an intact save slot", want ~= nil) then F.finish(); return end
  F.L(("SAVED v%d at %d/%d (%d,%d) play=%d:%02d"):format(want.ver, want.grp, want.map, want.x, want.y,
    want.play // 60, want.play % 60))

  if not F.check("save boots to the overworld", F.boot(want.grp)) then F.finish(); return end
  F.idle(120)
  F.check("no crash screen after load", F.crashScreen() == nil, tostring(F.crashScreen()))
  local loaded = snapshot()
  F.L("SNAP_LOAD " .. fmt(loaded))
  F.shot("loaded")

  F.check("play time continues from the save, not a new game", loaded.play >= want.play and loaded.play <= want.play + 2,
    ("play=%d saved=%d"):format(loaded.play, want.play))
  F.check("standing where the game was saved",
    loaded.grp == want.grp and loaded.map == want.map and loaded.x == want.x and loaded.y == want.y,
    ("%d/%d (%d,%d)"):format(loaded.grp, loaded.map, loaded.x, loaded.y))
  F.check("upgraded to the current save format", loaded.ver == S.SAVE_FORMAT_VERSION,
    ("v%d -> v%d, want v%d"):format(want.ver, loaded.ver, S.SAVE_FORMAT_VERSION))

  F.press("Start", 2); F.idle(60); F.shot("start_menu"); F.press("B", 2); F.idle(40)
  F.check("start menu opens and closes", F.ensureFree())

  local result = manualSave()
  F.check("in-game save succeeds", result == "done", result)
  local saved = snapshot()
  F.check("saving changes nothing in the game", differences(loaded, saved) == "", differences(loaded, saved))

  softReset()
  F.idle(60)
  if not F.check("Continue after a soft reset reaches the overworld", F.boot(want.grp)) then F.finish(); return end
  F.idle(120)
  local reloaded = snapshot()
  F.L("SNAP_RELOAD " .. fmt(reloaded))
  F.shot("reloaded")
  F.check("reloaded game matches the loaded one", differences(loaded, reloaded) == "", differences(loaded, reloaded))
  F.check("no crash screen after reload", F.crashScreen() == nil, tostring(F.crashScreen()))
  F.finish()
end)
