-- The party menu and PC storage: a Pokemon icon must draw in front of the icon in the row below it.
--
-- Icons are 32 pixels tall on 24-pixel rows in the party menu, the PC's party column and the box
-- grid, so each icon's bottom overlaps the next row's top. Sprites with equal subpriority sort the
-- lower one in front, and the party menu and the PC's party column gave every icon one subpriority
-- (box icons differed only by column), so Balloon Pikachu's balloons covered Surfboard Pikachu's
-- board whenever Balloon sat below it: the overlap #529 fixed on the Special Pokemon checklist.
-- Classic Cap, Surfboard and Balloon Pikachu come from the debug Give menu. With real input the
-- party menu is opened and its first and third Pokemon switched, then the PC (Move Pokemon) moves
-- Surfboard to box row 1 and Balloon to the slot below it. The suite compares the OAM sort keys the
-- game builds (BuildOamBuffer: priority, subpriority, then lower on screen first) for each upper
-- and lower icon: in the party menu before and after the switch, in the PC's party column, in the
-- box after the moves, after closing and reopening the PC, after Surfboard is picked up and put
-- back (re-created box icons used OAM priority 2, the box's first icons 1), and after scrolling
-- away and back.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/IconRowStacking.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "IconRowStacking")

local SURFBOARD, BALLOONS, CLASSIC = 1574, 1575, 1573
local AREA_BOX, AREA_PARTY = 0, 1
local PARTY_ACTION_SWITCH = 8
local SPR_X, SPR_Y, SPR_SUBPRIO = 0x20, 0x22, 0x43

local function tap(key, n, wait) for _ = 1, (n or 1) do F.press(key, 2); F.idle(wait or 24) end end

local function giveMon(species)
  local n = species - 1
  local d = { n // 1000, (n // 100) % 10, (n // 10) % 10, n % 10 }
  local before = F.r8(S.gPartiesCount)
  F.dbg(); F.sel(3); F.sel(1); F.idle(20)
  for _ = 1, 3 do tap("Right", 1, 8) end
  for _ = 1, 3 do tap("Down", 1, 8) end
  for i = 1, 4 do
    for _ = 1, d[i] do tap("Up", 1, 8) end
    if i < 4 then tap("Left", 1, 8) end
  end
  tap("A", 1, 45); F.idle(20)
  F.spin(0, 2, 0); F.idle(60); F.bOut(6)
  for _ = 1, 10 do if F.ensureFree() then break end F.press("B", 2); F.idle(20) end
  return F.r8(S.gPartiesCount) == before + 1
end

local function species(slot)
  local a = S.gParties + slot * S.Pokemon.size
  local pers = F.r32(a)
  local key = pers ~ F.r32(a + 4)
  local s0 = F.r8(S.sSubstructOffsets + pers % 24) * 3
  return (F.r32(a + 32 + s0 * 4) ~ key) & 0x7FF
end

-- The in-use sprite whose position is (x, y), with the key BuildOamBuffer sorts it by.
local function spriteAt(x, y)
  for i = 0, S.Sprite.count - 1 do
    local a = S.gSprites + i * S.Sprite.stride
    if (F.r8(a + S.Sprite.inUse) & 1) ~= 0 and F.rs16(a + SPR_X) == x and F.rs16(a + SPR_Y) == y then
      local oy = F.r8(a)
      if oy >= 160 then oy = oy - 256 end
      local prio = (F.r16(a + 4) >> 10) & 3
      local sub = F.r8(a + SPR_SUBPRIO)
      return { index = i, sub = sub, key = (prio << 30) | (sub << 22) | (((159 - oy) & 0x1FF) << 13) | i }
    end
  end
  return nil
end
local function partyXY(slot) return 40, 24 * slot + 16 end
local function menuXY(slot) return 34, 24 * slot + 18 end
local function boxXY(pos) return 24 * (pos % 6) + 92, 24 * (pos // 6) + 40 end
local function inFront(tag, upper, lower)
  local u, l = spriteAt(upper[1], upper[2]), spriteAt(lower[1], lower[2])
  F.check(tag, u ~= nil and l ~= nil and u.key < l.key,
    u and l and string.format("upper sub %d key %08X, lower sub %d key %08X", u.sub, u.key, l.sub, l.key) or "icon missing")
end

local function area() return F.r8(S.sCursorArea) end
local function cursor() return F.r8(S.sCursorPosition) end
local function holding() return F.r8(S.sIsMonBeingMoved) ~= 0 end
local function cursorTo(wantArea, pos)
  for _ = 1, 30 do
    if area() == wantArea and cursor() == pos then return true end
    if area() ~= wantArea then
      tap(wantArea == AREA_PARTY and "Left" or "Right", 1, 30)
    elseif wantArea == AREA_PARTY then
      tap(cursor() < pos and "Down" or "Up", 1, 20)
    else
      local r, c, wr, wc = cursor() // 6, cursor() % 6, pos // 6, pos % 6
      if r ~= wr then tap(r < wr and "Down" or "Up", 1, 20) else tap(c < wc and "Right" or "Left", 1, 20) end
    end
  end
  return area() == wantArea and cursor() == pos
end
local function pickUp()
  tap("A", 1, 40)
  for _ = 1, 4 do if holding() then return true end tap("A", 1, 40) end
  return holding()
end
local function putDown()
  tap("A", 1, 60)
  for _ = 1, 3 do if not holding() then return true end tap("A", 1, 60) end
  return not holding()
end

local function pcMenuLive() return F.ow() and F.rs8(S.sMenu + S.Menu.maxCursorPos) == 4 end
local function openPc()
  F.w8(S.sMenu + 2, 0); F.w8(S.sMenu + S.Menu.maxCursorPos, 0)
  F.dbg(); F.idle(60)
  F.press("Down", 3); F.idle(16); F.press("A", 3); F.idle(60)
  F.press("A", 3); F.idle(60)
  for _ = 1, 200 do if pcMenuLive() then break end F.press("A", 2); F.idle(18) end
  if not pcMenuLive() then return false end
  F.idle(20)
  for _ = 1, 4 do if F.mcur() == 0 then break end F.press("Up", 2); F.idle(14) end
  F.press("A", 2); F.idle(200)                          -- Move Pokemon
  return F.r32(S.sStorage) ~= 0
end
local function closePc()
  for _ = 1, 30 do
    if F.ow() and F.r32(S.sStorage) == 0 then break end
    tap("B", 1, 40)
  end
  for _ = 1, 20 do if F.ensureFree() then break end F.press("B", 2); F.idle(20) end
  return F.ow()
end

F.run(function()
  assert(F.boot(100), "Fresh game did not boot")
  local opt = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(opt, (F.r16(opt) & ~7) | 3)
  F.check("setup: Classic Cap, Surfboard and Balloon Pikachu given",
    giveMon(CLASSIC) and giveMon(SURFBOARD) and giveMon(BALLOONS), "party " .. F.r8(S.gPartiesCount))

  -- Party menu: Classic Cap, Surfboard, Balloon; then switch the first and third.
  F.press("Start", 2); F.idle(60)
  F.check("party menu opens", F.selectStartIcon(1) and (F.press("A", 2) or true) and (F.idle(120) or true)
    and F.cb2() == (S.CB2_UpdatePartyMenu & ~1))
  F.shot("party_menu")
  inFront("party menu: Classic Cap (slot 1) in front of Surfboard (slot 2)", { menuXY(0) }, { menuXY(1) })
  inFront("party menu: Surfboard (slot 2) in front of Balloon (slot 3)", { menuXY(1) }, { menuXY(2) })
  local switching = false
  for down = 1, 4 do
    tap("A", 1, 50)
    tap("Down", down, 16)
    tap("A", 1, 50)
    if F.r8(S.gPartyMenu + 11) == PARTY_ACTION_SWITCH then switching = true; break end
    tap("B", 2, 40)
  end
  F.check("Switch chosen for the first Pokemon", switching)
  tap("Down", 2, 20); tap("A", 1, 150)
  F.check("switched: Balloon leads and Classic Cap is third",
    species(0) == BALLOONS and species(1) == SURFBOARD and species(2) == CLASSIC,
    string.format("%d,%d,%d", species(0), species(1), species(2)))
  F.shot("party_menu_switched")
  inFront("party menu after the switch: Balloon (slot 1) in front of Surfboard (slot 2)", { menuXY(0) }, { menuXY(1) })
  inFront("party menu after the switch: Surfboard (slot 2) in front of Classic Cap (slot 3)", { menuXY(1) }, { menuXY(2) })
  for _ = 1, 4 do F.press("B", 2); F.idle(60); if F.ow() then break end end
  for _ = 1, 20 do if F.ensureFree() then break end F.press("B", 2); F.idle(20) end

  F.check("PC opens on Move Pokemon", openPc())
  F.idle(30)
  F.shot("party_column")
  inFront("PC party column: Balloon (slot 1) in front of Surfboard (slot 2)", { partyXY(0) }, { partyXY(1) })
  inFront("PC party column: Surfboard (slot 2) in front of Classic Cap (slot 3)", { partyXY(1) }, { partyXY(2) })

  -- Surfboard to box row 1 column 2, then Balloon (party slot 1) to the slot below it.
  F.check("cursor on party slot 2", cursorTo(AREA_PARTY, 1))
  F.check("Surfboard picked up", pickUp())
  F.check("cursor on box slot 2", cursorTo(AREA_BOX, 1))
  F.check("Surfboard put down in the box", putDown())
  F.idle(40)
  F.check("cursor on party slot 1", cursorTo(AREA_PARTY, 0))
  F.check("Balloon picked up", pickUp())
  F.check("cursor on box slot 8", cursorTo(AREA_BOX, 7))
  F.check("Balloon put down below Surfboard", putDown())
  F.idle(60)
  F.shot("box_after_moves")
  inFront("box after the moves: Surfboard in front of Balloon below it", { boxXY(1) }, { boxXY(7) })

  F.check("PC closes", closePc())
  F.check("PC reopens", openPc())
  F.idle(30)
  F.shot("box_reopened")
  inFront("box reopened: Surfboard in front of Balloon below it", { boxXY(1) }, { boxXY(7) })

  F.check("cursor on Surfboard in the reopened box", cursorTo(AREA_BOX, 1))
  F.check("Surfboard picked up again", pickUp())
  F.check("Surfboard put back", putDown())
  F.idle(40)
  F.shot("box_put_back")
  inFront("box, Surfboard put back above Balloon: Surfboard in front", { boxXY(1) }, { boxXY(7) })

  F.check("cursor in the box", cursorTo(AREA_BOX, 0))
  tap("R", 1, 90); tap("L", 1, 90)
  F.shot("box_scrolled_back")
  inFront("box scrolled away and back: Surfboard in front of Balloon below it", { boxXY(1) }, { boxXY(7) })

  F.check("back on the field", closePc())
  F.finish()
end)
