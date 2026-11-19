-- The Special Pokemon checklist under real input: both page ends, held keys, page 2's three rows,
-- the icon draw order, every detail page, and fast open and close, with 0, 1 and all 7 collected.
--
-- The list shows four rows a page. Each row is a full icon tall (32 pixels), so no icon reaches into
-- the next row: on 29-pixel rows (#529) Balloon Pikachu's balloons still covered the bottom 3 pixels
-- of Surfboard Pikachu's board, whose art fills its icon to the last row. Page 2 holds entries 5 to 7, so it must
-- draw exactly three icons on the first three rows and nothing on the fourth, and an icon left
-- over from page 1 would show as a fourth sprite. Each icon must draw in front of the one below it
-- (a lower subpriority). The ends clamp like the Pokedex list: Up on the first entry and Down on
-- the last do nothing. The collected count in the header comes from SpecialPokemon_ReconcileOwned,
-- so the suite gives the Pokemon with the debug Give menu and lets the checklist find them.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/SpecialChecklistStress.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SpecialChecklistStress")

local FLAG_SYS_POKEDEX_GET = 0x949
local FLAG_SYS_DEXNAV_GET = 0x948 + 0xBE
local COLLECTED = { 0xDD0, 0xDD1, 0xDD2, 0xDD3, 0xDD4, 0xDD5, 0xDD7 }
local SPECIES = { 1573, 1574, 1575, 1576, 1577, 1578, 1580 }
local ROWS, ENTRIES, ROW_H, ICON_Y0, ICON_H = 4, 7, 32, 36, 32
local MON = S.Pokemon.size
local SPR_X, SPR_Y, SPR_SUBPRIO = 0x20, 0x22, 0x43

local function flag(id, value)
  local a, bit = F.sb1() + S.SaveBlock1.flags + id // 8, 1 << (id % 8)
  if value ~= nil then F.w8(a, value and (F.r8(a) | bit) or (F.r8(a) & ~bit & 0xFF)) end
  return (F.r8(a) & bit) ~= 0
end
local function tap(key, n, wait) for _ = 1, (n or 1) do F.press(key, 2); F.idle(wait or 24) end end
local function hold(key, frames) F.press(key, frames); F.idle(20) end

local function menu() return F.r32(S.sSpecialPokemonMenu) end
local function selected() return F.r8(menu() + S.SpecialPokemonMenu.selected) end
local function detail() return F.r8(menu() + S.SpecialPokemonMenu.detail) ~= 0 end
local function sprites()
  local t = {}
  for i = 0, S.Sprite.count - 1 do
    local a = S.gSprites + i * S.Sprite.stride
    if (F.r8(a + S.Sprite.inUse) & 1) ~= 0 then
      t[#t + 1] = { x = F.rs16(a + SPR_X), y = F.rs16(a + SPR_Y), sub = F.r8(a + SPR_SUBPRIO) }
    end
  end
  table.sort(t, function(p, q) return p.y < q.y end)
  return t
end
local function describe(t)
  local s = {}
  for _, p in ipairs(t) do s[#s + 1] = string.format("(%d,%d s%d)", p.x, p.y, p.sub) end
  return table.concat(s, " ")
end
-- The icons of a list page: one per row at the row's y, a full icon height apart, upper rows in front.
local function pageIconsOk(n)
  local t = sprites()
  if #t ~= n then return false, describe(t) end
  for r = 2, n do
    if t[r].y - t[r - 1].y < ICON_H then return false, "icons overlap: " .. describe(t) end
  end
  for r = 1, n do
    if t[r].y ~= ICON_Y0 + (r - 1) * ROW_H then return false, describe(t) end
    if r > 1 and t[r].sub <= t[r - 1].sub then return false, describe(t) end
  end
  return true, describe(t)
end

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
  F.spin(0, 5, 0); F.idle(60); F.bOut(6)
  for _ = 1, 10 do if F.ensureFree() then break end F.press("B", 2); F.idle(20) end
  return F.r8(S.gPartiesCount) == before + 1 or before == 6
end

local function openDex()
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(0) then return false end
  F.press("A", 2); F.idle(240)
  return true
end
local function fading() return (F.r32(S.gPaletteFade + S.PaletteFade.activeWord) & 0x80000000) ~= 0 end
local function openChecklist(wait)
  for _ = 1, 360 do
    if F.taskLive(S.Task_HandlePokedexInput) then break end
    F.idle(1)
  end
  if not F.taskLive(S.Task_HandlePokedexInput) then return false end
  F.idle(12) -- The list also waits for the previous Start menu to finish sliding away.
  tap("Start", 1, 60); tap("Down", 3); F.press("A", 2)
  if wait == 0 then return true end
  for _ = 1, 360 do
    if F.taskLive(S.HandleCollectionInput) and not fading() then
      F.idle(wait or 0)
      return true
    end
    F.idle(1)
  end
  return false
end
local function toField()
  for _ = 1, 30 do if F.ow() then break end tap("B", 1, 40) end
  for _ = 1, 10 do if F.ensureFree() then break end F.press("B", 2); F.idle(20) end
  return F.ow()
end
local function headerCount()
  local n = 0
  for _, id in ipairs(COLLECTED) do if flag(id) then n = n + 1 end end
  return n
end

local function pages(tag)
  F.check(tag .. ": opens on entry 1", selected() == 0 and not detail())
  local ok, d = pageIconsOk(ROWS)
  F.check(tag .. ": page 1 draws four icons, upper rows in front", ok, d)
  F.shot(tag .. "_page1")
  tap("Up", 1, 30)
  F.check(tag .. ": Up on entry 1 stays", selected() == 0, "selected " .. selected())
  tap("Left", 1, 30)
  F.check(tag .. ": Left on page 1 stays", selected() == 0, "selected " .. selected())
  tap("Right", 1, 40)
  ok, d = pageIconsOk(ENTRIES - ROWS)
  F.check(tag .. ": Right turns to page 2 with three icons and no fourth row", selected() == ROWS and ok,
    "selected " .. selected() .. " " .. d)
  F.shot(tag .. "_page2")
  tap("Down", 3, 30)
  F.check(tag .. ": Down stops on entry 7", selected() == ENTRIES - 1, "selected " .. selected())
  tap("Right", 1, 30)
  F.check(tag .. ": Right on page 2 stays", selected() == ENTRIES - 1, "selected " .. selected())
  ok, d = pageIconsOk(ENTRIES - ROWS)
  F.check(tag .. ": page 2 still three icons", ok, d)
  F.shot(tag .. "_page2_last")
  tap("Up", 3, 30)
  F.check(tag .. ": Up from entry 5 crosses back to page 1", selected() == ROWS - 1 and pageIconsOk(ROWS),
    "selected " .. selected() .. " " .. describe(sprites()))
end

F.run(function()
  assert(F.boot(100), "Fresh game did not boot")
  local opt = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(opt, (F.r16(opt) & ~7) | 3)
  flag(FLAG_SYS_POKEDEX_GET, true)
  flag(FLAG_SYS_DEXNAV_GET, true)
  F.dbg(); F.sel(7); F.sel(2); F.idle(60); F.bOut(4)   -- Pokedex Flags All
  for _, id in ipairs(COLLECTED) do flag(id, false) end

  -- None collected.
  F.check("setup: Pokedex opens", openDex())
  F.check("0 collected: checklist opens", openChecklist())
  F.check("0 collected: no collection marks", headerCount() == 0)
  pages("zero")

  -- Held keys: Down runs to the last entry across the page break, Up runs back.
  hold("Down", 90)
  local ok, d = pageIconsOk(ENTRIES - ROWS)
  F.check("held Down reaches entry 7 on page 2", selected() == ENTRIES - 1 and ok, "selected " .. selected() .. " " .. d)
  hold("Up", 90)
  ok, d = pageIconsOk(ROWS)
  F.check("held Up returns to entry 1 on page 1", selected() == 0 and ok, "selected " .. selected() .. " " .. d)
  hold("Right", 60)
  F.check("held Right stops on page 2", selected() == ROWS, "selected " .. selected())
  hold("Left", 60)
  F.check("held Left stops on page 1", selected() == 0, "selected " .. selected())

  -- Close while the open fade is still running, then open and close back to back.
  tap("B", 1, 60)
  F.check("B closes to the Pokedex", menu() == 0)
  openChecklist(0)
  local opening = false
  for _ = 1, 240 do
    opening = F.taskLive(S.HandleCollectionInput) and fading()
    if opening then break end
    F.idle(1)
  end
  F.check("checklist is opening with its fade active", opening)
  F.press("B", 2); F.idle(80)
  local stayedOpen = menu() ~= 0
  for _ = 1, 20 do if menu() == 0 then break end tap("B", 1, 20) end
  F.check("B during the open fade is ignored, then B closes", stayedOpen and menu() == 0)
  for i = 1, 3 do
    F.check("fast round " .. i .. " opens", openChecklist())
    tap("B", 1, 50)
    F.check("fast round " .. i .. " closes", menu() == 0)
  end
  F.check("back on the field", toField())

  -- One collected.
  F.check("setup: Classic Cap Pikachu given", giveMon(SPECIES[1]))
  openDex(); openChecklist()
  F.check("1 collected: only Classic Cap marked", headerCount() == 1 and flag(COLLECTED[1]))
  F.shot("one_page1")
  tap("B", 1, 60); toField()

  -- All seven: five more in the party and the seventh to the PC.
  for i = 2, ENTRIES do
    F.check("setup: special " .. i .. " given", giveMon(SPECIES[i]))
  end
  openDex(); openChecklist()
  F.check("7 collected: every entry marked", headerCount() == ENTRIES, "marked " .. headerCount())
  pages("seven")

  -- Every detail page, then Left back through them.
  tap("Up", ENTRIES, 20)
  tap("A", 1, 40)
  F.check("A opens entry 1's details", detail() and selected() == 0 and #sprites() == 1)
  F.shot("detail_1")
  for i = 2, ENTRIES do
    tap("Right", 1, 40)
    local t = sprites()
    F.check("detail " .. i .. ": one icon", selected() == i - 1 and #t == 1, describe(t))
    F.shot("detail_" .. i)
  end
  tap("Right", 1, 30)
  F.check("Right on the last detail page stays", selected() == ENTRIES - 1)
  tap("B", 1, 40)
  ok, d = pageIconsOk(ENTRIES - ROWS)
  F.check("B from entry 7's details returns to page 2", not detail() and selected() == ENTRIES - 1 and ok, d)
  tap("A", 1, 40)
  hold("Left", 120)
  F.check("held Left in the details stops on entry 1", detail() and selected() == 0, "selected " .. selected())
  tap("B", 1, 40)
  ok, d = pageIconsOk(ROWS)
  F.check("B from entry 1's details returns to page 1", not detail() and ok, d)

  -- Mash A and B: details and list alternate, then the list closes.
  for _ = 1, 6 do F.press("A", 2); F.idle(3); F.press("B", 2); F.idle(3) end
  F.idle(60)
  F.check("A/B mash leaves a consistent screen", menu() == 0 or (not detail() and #sprites() >= ENTRIES - ROWS),
    string.format("menu %08X", menu()))
  F.check("back on the field after the mash", toField())
  F.finish()
end)
