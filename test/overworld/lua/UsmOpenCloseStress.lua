-- The graphical Start menu opened and closed 125 times with real input, with the icon set changing
-- between opens. Each close must hand back every sprite, sprite-VRAM tile and OAM matrix it took
-- (0829014ec0 freed the second arrow sheet, which leaked 16 tiles per close), and every open must
-- put the cursor on an icon that exists: a cursor restored from a screen opened with more icons
-- (sUsmSavedIcon/Offset) is clamped to the list built now.
--
-- Cycles vary the D-pad walk (holds past the auto-repeat delay included), reorder with SELECT on
-- some, and toggle the Pokedex, PokeNav and DexNav flags between opens (setup for the icon set;
-- the menu itself is driven by input). Every 12th cycle opens Options from the last icon, removes
-- three icons while Options is up, and returns: the reopened menu's cursor must be in range and A
-- must open the icon it shows. The sprite, tile and matrix counts are compared with the field
-- baseline after each close; Options returns through a field reload (which can respawn the
-- follower), so the baseline is re-taken there and every reload must settle on the same counts.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/UsmOpenCloseStress.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "UsmOpenCloseStress")

local HUB_GROUP = 100
local CYCLES = tonumber(os.getenv("PW_USM_CYCLES") or "125")
local FLAG_SYS_POKEMON_GET, FLAG_SYS_POKEDEX_GET, FLAG_SYS_POKENAV_GET = 0x948, 0x949, 0x94A
local FLAG_SYS_DEXNAV_GET = 0x948 + 0xBE
local USM_ICO_OPTIONS = 9
local MAX_VISIBLE = 6

local function flag(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + (id // 8), 1 << (id % 8)
  if on == nil then return (F.r8(a) & m) ~= 0 end
  F.w8(a, on and (F.r8(a) | m) or (F.r8(a) & ~m & 0xFF))
end

local function popcount8(v) local n = 0; while v > 0 do n = n + (v & 1); v = v >> 1 end return n end
local function spritesInUse()
  local n = 0
  for i = 0, S.Sprite.count - 1 do
    if F.r8(S.gSprites + i * S.Sprite.stride + S.Sprite.inUse) & 1 ~= 0 then n = n + 1 end
  end
  return n
end
local function tilesInUse()
  local n = 0
  for i = 0, 127 do n = n + popcount8(F.r8(S.sSpriteTileAllocBitmap + i)) end
  return n
end
local function matricesInUse()
  local v, n = F.r32(S.gOamMatrixAllocBitmap), 0
  for _ = 0, 31 do n = n + (v & 1); v = v >> 1 end
  return n
end
local function counts() return spritesInUse(), tilesInUse(), matricesInUse() end

local function state()
  local p = F.r32(S.sUsmState)
  if p < 0x02000000 or p >= 0x02040000 then return nil end
  local st = { idx = F.r8(p + 5), offset = F.r8(p + 10), count = F.r8(p + 23), items = {} }
  for i = 0, st.count - 1 do st.items[i] = F.r8(p + 11 + i) end
  return st
end
local function menuOpen() return F.r32(S.sUsmMemory) ~= 0 and state() ~= nil end

-- The cursor must name a real icon: offset within the scroll range, index within what is visible.
local function cursorOk(st)
  if not st or st.count < 1 or st.count > 12 then return false, "no menu state" end
  local maxOffset = math.max(0, st.count - MAX_VISIBLE)
  local visible = math.min(MAX_VISIBLE, st.count - st.offset)
  if st.offset > maxOffset then return false, string.format("offset %d > %d", st.offset, maxOffset) end
  if st.idx >= visible then return false, string.format("idx %d >= visible %d", st.idx, visible) end
  return true, string.format("icon %d at %d+%d of %d", st.items[st.offset + st.idx], st.offset, st.idx, st.count)
end

local function openMenu()
  for _ = 1, 3 do
    F.press("Start", 2)
    for _ = 1, 60 do F.idle(2); if menuOpen() then F.idle(16); return true end end
    F.idle(30)
  end
  return false
end
local function closeMenu()
  F.press("B", 2)
  for _ = 1, 90 do F.idle(2); if not menuOpen() then break end end
  F.idle(24)
  return not menuOpen()
end

local rng = 0x2545
local function rand(n) rng = (rng * 1103515245 + 12345) & 0x7FFFFFFF; return rng % n end

local failures = 0
local function fail(tag, detail)
  failures = failures + 1
  if failures <= 12 then F.L("  FAIL " .. tag .. ": " .. detail) end
  if failures == 1 then F.shot("first_failure") end
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  flag(FLAG_SYS_POKEMON_GET, true)
  F.dbg(); F.sel(3); F.sel(1); F.idle(20); F.spin(0, 2, 4); F.idle(20); F.spin(0, 1, 0); F.idle(60); F.bOut(4)
  F.check("setup: a Pokemon in the party", F.r8(S.gPartiesCount) >= 1, "n=" .. F.r8(S.gPartiesCount))
  F.ensureFree()
  F.idle(60)
  local s0, t0, m0 = counts()
  F.L(string.format("  field baseline: sprites=%d tiles=%d matrices=%d", s0, t0, m0))

  local maxOpenSprites, maxOpenTiles, restored, restoredOk = 0, 0, 0, 0
  local reloads = {}
  for c = 1, CYCLES do
    if c % 4 == 1 then
      flag(FLAG_SYS_POKEDEX_GET, rand(3) ~= 0)
      flag(FLAG_SYS_POKENAV_GET, rand(2) == 0)
      flag(FLAG_SYS_DEXNAV_GET, rand(2) == 0)
    end
    if not openMenu() then fail("cycle " .. c, "the menu did not open"); F.idle(60); goto continue end
    do
      local ok, d = cursorOk(state())
      if not ok then fail("cycle " .. c .. " open", d) end
      local so, to = counts()
      maxOpenSprites = math.max(maxOpenSprites, so); maxOpenTiles = math.max(maxOpenTiles, to)
    end

    if c % 12 == 0 then
      -- Options from the last icon, then fewer icons while Options is up.
      flag(FLAG_SYS_POKEDEX_GET, true); flag(FLAG_SYS_POKENAV_GET, true); flag(FLAG_SYS_DEXNAV_GET, true)
      closeMenu(); openMenu()
      if F.selectStartIcon(USM_ICO_OPTIONS) then
        local before = state()
        F.press("A", 2)
        for _ = 1, 200 do F.idle(2); if not menuOpen() and not F.ow() then break end end
        F.idle(60)
        flag(FLAG_SYS_POKEDEX_GET, false); flag(FLAG_SYS_POKENAV_GET, false); flag(FLAG_SYS_DEXNAV_GET, false)
        F.press("B", 2)
        for _ = 1, 300 do F.idle(2); if menuOpen() then break end end
        F.idle(30)
        restored = restored + 1
        local st = state()
        local ok, d = cursorOk(st)
        F.L(string.format("  cycle %d: Options from %d+%d of %d, back to %s", c, before.offset, before.idx,
          before.count, d))
        if restored == 1 then F.shot("restored_cursor") end
        if not ok then fail("cycle " .. c .. " restored", d) else
          -- A opens what the cursor shows: Options again (its own screen) or another icon.
          local icon = st.items[st.offset + st.idx]
          F.press("A", 2)
          local left = false
          for _ = 1, 200 do F.idle(2); if not menuOpen() then left = true; break end end
          F.idle(60)
          if F.reportCrash("restored A " .. c) then fail("cycle " .. c, "crash after A") end
          if left then restoredOk = restoredOk + 1 end
          F.L(string.format("    A on icon %d left the menu=%s cb2=%08X", icon, tostring(left), F.cb2()))
          for _ = 1, 40 do
            if F.ow() and not menuOpen() and F.ensureFree() then break end
            F.press("B", 2); F.idle(24)
          end
        end
        if menuOpen() then closeMenu() end
        -- Options returns through a field reload, which can respawn the follower; re-take the
        -- baseline there and require every reload to land on the same one.
        for _ = 1, 30 do if F.ow() and not menuOpen() then break end; F.idle(4) end
        F.idle(40)
        s0, t0, m0 = counts()
        reloads[#reloads + 1] = string.format("%d/%d/%d", s0, t0, m0)
      else
        fail("cycle " .. c, "Options not found"); closeMenu()
      end
      goto settle
    end

    do
      local steps = rand(9)
      local dir = rand(4) == 0 and "Left" or "Right"
      if rand(6) == 0 then
        F.press(dir, 45 + rand(30)); F.idle(10)     -- hold past the auto-repeat delay
      else
        for _ = 1, steps do F.press(dir, 2); F.idle(6 + rand(8)) end
      end
      if c % 7 == 0 then
        F.press("Select", 2); F.idle(12)
        F.press(rand(2) == 0 and "Left" or "Right", 2); F.idle(12)
        F.press("Select", 2); F.idle(12)
      end
      local ok, d = cursorOk(state())
      if not ok then fail("cycle " .. c .. " walk", d) end
      local so, to = counts()
      maxOpenSprites = math.max(maxOpenSprites, so); maxOpenTiles = math.max(maxOpenTiles, to)
      if not closeMenu() then fail("cycle " .. c, "the menu did not close") end
    end

    ::settle::
    for _ = 1, 30 do if F.ow() and not menuOpen() then break end; F.idle(4) end
    F.idle(20)
    do
      local s, t, m = counts()
      if s ~= s0 or t ~= t0 or m ~= m0 then
        fail("cycle " .. c .. " close", string.format("sprites=%d tiles=%d matrices=%d (baseline %d/%d/%d)",
          s, t, m, s0, t0, m0))
      end
    end
    if F.reportCrash("cycle " .. c) then fail("cycle " .. c, "crash screen"); break end
    ::continue::
  end

  local s1, t1, m1 = counts()
  F.L(string.format("  after %d cycles: sprites=%d tiles=%d matrices=%d; open peak sprites=%d tiles=%d",
    CYCLES, s1, t1, m1, maxOpenSprites, maxOpenTiles))
  F.shot("after_cycles")
  F.check("every open put the cursor on a real icon and every close freed what it took", failures == 0,
    failures .. " failures")
  F.check("sprite, tile and matrix counts are back to the field baseline", s1 == s0 and t1 == t0 and m1 == m0,
    string.format("%d/%d/%d vs %d/%d/%d", s1, t1, m1, s0, t0, m0))
  local sameReload = true
  for _, r in ipairs(reloads) do if r ~= reloads[1] then sameReload = false end end
  F.check("every field reload after Options settles on the same counts", sameReload, table.concat(reloads, " "))
  F.check("the restored cursor was exercised", restored >= CYCLES // 12, "restored=" .. restored)
  F.check("A on every restored cursor opened its icon", restoredOk == restored, restoredOk .. "/" .. restored)
  F.check("control returns on the field", F.ow() and F.ensureFree())
  F.finish()
end)
