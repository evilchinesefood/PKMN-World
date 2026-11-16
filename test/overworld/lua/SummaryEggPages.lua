-- An Egg's summary must not leak what hatching reveals. 0829014ec0 hid the shiny star and the
-- friendship heart on an Egg's info page; an Egg also cannot turn pages (ChangePage returns), so
-- every other page must stay out of reach, including when the summary scrolls onto the Egg from a
-- hatched Pokemon that was showing its skills or moves page.
--
-- A shiny Bulbasaur leads (control: its star shows) and a shiny Togepi Egg from the debug Give Egg
-- menu (ScriptGiveEgg) follows. With real input the suite opens the party from the Start menu,
-- opens Bulbasaur's summary, scrolls onto the Egg, tries Left and Right on it, and reads the
-- summary's shiny and friendship sprites (by their fixed screen positions in gSprites) at every
-- stop. From each of Bulbasaur's other pages Down must skip the Egg: closing the summary must put
-- the party cursor back on the lead. The Pokemon are made shiny through the unencrypted
-- shinyModifier bit (setup).
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/SummaryEggPages.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SummaryEggPages")

local HUB_GROUP = 100
local MON = S.Pokemon.size
local USM_ICO_PARTY = 1
local SPECIES_TOGEPI = 175
local SHINY = { x = 126, y = 36 }
local HEART = { x = 233, y = 32 }
local PARTY_MENU_SLOT = 9   -- struct PartyMenu.slotId

local function party(slot) return S.gParties + slot * MON end
local function setShinyModifier(slot) local a = party(slot) + 30; F.w16(a, F.r16(a) | 0x4000) end
local function isEgg(slot) return (F.r8(party(slot) + 19) & 4) ~= 0 end

-- Returns nil when no in-use sprite sits at (x, y), else whether it is visible.
local function spriteVisibleAt(pos)
  for i = 0, S.Sprite.count - 1 do
    local a = S.gSprites + i * S.Sprite.stride
    local flags = F.r16(a + S.Sprite.inUse)
    if flags & 1 ~= 0 and F.rs16(a + 0x20) == pos.x and F.rs16(a + 0x22) == pos.y then
      return (flags & 4) == 0
    end
  end
  return nil
end

local function inSummary() return F.cb2() ~= (S.CB2_UpdatePartyMenu & ~1) and not F.ow() end

local function digits(n) n = n - 1; return n // 100, (n // 10) % 10, n % 10 end

local function openSummary()
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_PARTY) then return false end
  F.press("A", 2)
  for _ = 1, 200 do F.idle(3); if F.cb2() == (S.CB2_UpdatePartyMenu & ~1) then break end end
  F.idle(60)
  F.press("A", 2); F.idle(40)          -- action menu on the lead, Summary first
  F.shot("action_menu")
  F.press("A", 2)
  for _ = 1, 200 do F.idle(3); if inSummary() then break end end
  F.idle(90)
  return inSummary()
end

local function stop(tag)
  F.idle(40)
  F.shot(tag)
  return spriteVisibleAt(SHINY), spriteVisibleAt(HEART)
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  for off = 0, 6 * MON - 4, 4 do F.w32(S.gParties + off, 0) end
  F.w8(S.gPartiesCount, 0)
  F.dbg(); F.idle(30); F.bOut(4)
  F.dbg(); F.sel(3); F.sel(1); F.idle(20); F.spin(0, 0, 0); F.idle(20); F.spin(0, 0, 9); F.idle(60); F.bOut(4)
  F.dbg(); F.sel(3); F.sel(3); F.idle(20); F.spin(digits(SPECIES_TOGEPI)); F.idle(60); F.bOut(4)
  F.check("setup: a Pokemon and an Egg in the party", F.r8(S.gPartiesCount) == 2 and not isEgg(0) and isEgg(1),
    string.format("n=%d egg0=%s egg1=%s", F.r8(S.gPartiesCount), tostring(isEgg(0)), tostring(isEgg(1))))
  setShinyModifier(0)
  setShinyModifier(1)

  if not openSummary() then F.check("the summary opened", false, string.format("cb2=%08X", F.cb2())); F.finish(); return end
  local shiny, heart = stop("lead_info")
  F.check("control: the shiny lead shows its star", shiny == true, tostring(shiny))
  F.check("control: the lead shows its friendship heart", heart == true, tostring(heart))

  F.press("Down", 2)
  shiny, heart = stop("egg_info")
  F.check("the Egg's info page hides the shiny star", shiny ~= true, tostring(shiny))
  F.check("the Egg's info page hides the friendship heart", heart ~= true, tostring(heart))
  F.press("Right", 2); shiny, heart = stop("egg_right")
  F.check("Right on the Egg keeps the star and heart hidden", shiny ~= true and heart ~= true,
    tostring(shiny) .. "/" .. tostring(heart))
  F.press("Left", 2); shiny, heart = stop("egg_left")
  F.check("Left on the Egg keeps the star and heart hidden", shiny ~= true and heart ~= true,
    tostring(shiny) .. "/" .. tostring(heart))

  -- From each of the lead's later pages Down must skip the Egg: closing the summary then puts the
  -- party cursor back on the lead (it follows the Pokemon the summary showed last).
  F.press("Up", 2); F.idle(40)
  for page = 1, 3 do
    for _ = 1, page do F.press("Right", 2); F.idle(40) end
    F.press("Down", 2)
    shiny, heart = stop("egg_from_page" .. page)
    F.check("onto the Egg from page " .. page .. ": star and heart hidden", shiny ~= true and heart ~= true,
      tostring(shiny) .. "/" .. tostring(heart))
    F.press("B", 2)
    for _ = 1, 200 do F.idle(3); if F.cb2() == (S.CB2_UpdatePartyMenu & ~1) then break end end
    F.idle(60)
    local slot = F.rs8(S.gPartyMenu + PARTY_MENU_SLOT)
    F.check("from page " .. page .. ", Down skipped the Egg (the cursor returns to the lead)", slot == 0,
      "slot=" .. slot)
    F.press("A", 2)                       -- the action menu is back up; Summary is first
    for _ = 1, 200 do F.idle(3); if inSummary() then break end end
    F.idle(90)
  end

  for _ = 1, 30 do
    if F.ow() then break end
    F.press("B", 2); F.idle(30)
  end
  F.check("back on the field", F.ow())
  F.check("no crash screen", not F.crashScreen())
  F.finish()
end)
