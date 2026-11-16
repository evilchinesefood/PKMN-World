-- The Trainer Card's front badge row pages through Hoenn, Kanto and Johto with L/R (and Up/Down).
-- Each page must draw exactly the badges that region's flags hold, in that region's artwork slots,
-- for no badges, some badges and all badges, and the card must open on the active region's page.
-- The badge flags are written the way the gym scripts leave them (Hoenn system flags, the Kanto
-- bank in SaveBlock1, the Johto bank in SaveBlock3); the card is opened from the Start menu and
-- paged with real input. Oracle: the BG3 tilemap the card draws in VRAM (screen base 31), where
-- badge i sits at (4 + 3i, 15) as tile 192 + 2i, and empty slots hold tile 0.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "TrainerCardRegionPages")

local USM_ICO_TRAINER = 5
local HOENN_BADGE = 0x948 + 7
local KANTO_BADGE = 0xA40 + 0x0B
local JOHTO_BADGE = 0x6000 + 0x3F8
local BG3_MAP = 0x06000000 + 31 * 0x800
local NAMES = { [0] = "hoenn", [1] = "kanto", [2] = "johto" }

local function flagAddr(id)
  if id >= 0x6000 and id < 0x6400 then return F.sb3() + S.SaveBlock3.johtoFlags + (id - 0x6000) // 8, (id - 0x6000) % 8 end
  return F.sb1() + S.SaveBlock1.flags + id // 8, id % 8
end
local function setFlag(id, on)
  local a, b = flagAddr(id)
  local bit = 1 << b
  F.w8(a, on and (F.r8(a) | bit) or (F.r8(a) & (~bit & 255)))
end
local function setBadges(base, set)
  for i = 0, 7 do setFlag(base + i, set[i + 1] == true) end
end
local function badgeSet(list)
  local s = {}
  for _, i in ipairs(list) do s[i] = true end
  return s
end
local function drawnRow()
  local row = {}
  for i = 0, 7 do
    local x, y = 4 + 3 * i, 15
    local top = F.r16(BG3_MAP + (y * 32 + x) * 2) & 0x3FF
    local top2 = F.r16(BG3_MAP + (y * 32 + x + 1) * 2) & 0x3FF
    local bot = F.r16(BG3_MAP + ((y + 1) * 32 + x) * 2) & 0x3FF
    if top == 192 + 2 * i and top2 == 193 + 2 * i and bot == 208 + 2 * i then row[i + 1] = true
    elseif top == 0 and top2 == 0 and bot == 0 then row[i + 1] = false
    else row[i + 1] = string.format("?%03X", top) end
  end
  return row
end
local function fmt(row)
  local t = {}
  for i = 1, 8 do
    local v = row[i]
    t[i] = v == true and "B" or (v == false and "." or tostring(v))
  end
  return table.concat(t)
end
local function want(set)
  local r = {}
  for i = 1, 8 do r[i] = set[i] == true end
  return r
end
local function region() return F.r8(S.gCurrentRegion) end
-- sCardRegions is { HOENN, KANTO, JOHTO }; enum Region is NONE 0, KANTO 1, JOHTO 2, HOENN 3, and the
-- Hub (NONE) opens on the Hoenn page.
local PAGE_OF_REGION = { [0] = 0, [1] = 1, [2] = 2, [3] = 0 }

local function openCard(tag)
  F.press("Start", 2); F.idle(40)
  if not F.selectStartIcon(USM_ICO_TRAINER) then F.shot(tag .. "_noicon"); return false end
  F.press("A", 2)
  for _ = 1, 400 do F.idle(1); if not F.ow() then break end end
  F.idle(150)
  return not F.ow()
end
local function closeCard()
  F.press("B", 2)
  for _ = 1, 300 do F.idle(1); if F.ow() then break end end
  F.idle(60)
  for _ = 1, 3 do F.press("B", 2); F.idle(20) end
  return F.ow()
end

local function pageCheck(tag, page, sets)
  F.idle(20)
  local got = drawnRow()
  local exp = want(sets[page])
  F.shot(tag .. "_" .. NAMES[page])
  F.check(tag .. ": " .. NAMES[page] .. " page draws its badges", fmt(got) == fmt(exp),
    "got=" .. fmt(got) .. " want=" .. fmt(exp))
end

local function scenario(tag, sets)
  setBadges(HOENN_BADGE, sets[0]); setBadges(KANTO_BADGE, sets[1]); setBadges(JOHTO_BADGE, sets[2])
  if not F.check(tag .. ": card opens", openCard(tag)) then return end
  local page = PAGE_OF_REGION[region()]
  pageCheck(tag .. " open", page, sets)
  for _ = 1, 3 do
    F.press("R", 2); F.idle(30)
    page = (page + 1) % 3
    pageCheck(tag .. " R", page, sets)
  end
  F.press("L", 2); F.idle(30); page = (page + 2) % 3
  pageCheck(tag .. " L", page, sets)
  F.press("Down", 2); F.idle(30); page = (page + 1) % 3
  pageCheck(tag .. " Down", page, sets)
  F.press("R", 2); F.idle(2); F.press("R", 2); F.idle(2); F.press("L", 2); F.idle(30)
  page = (page + 1) % 3
  pageCheck(tag .. " R R L mashed", page, sets)
  F.press("A", 2); F.idle(120)
  F.shot(tag .. "_back")
  F.check(tag .. ": card closes to the field", closeCard())
end

local function debugWarp(g, m, tag)
  local function digits(n) return n // 100, (n // 10) % 10, n % 10 end
  local gh, gt, go = digits(g); local mh, mt, mo = digits(m)
  return F.warpTo(gh, gt, go, mh, mt, mo, 0, 0, 0, g, m, tag)
end

F.run(function()
  if not F.boot(100) then F.check("fresh boot", false); F.finish(); return end
  local none = badgeSet({})
  local all = badgeSet({ 1, 2, 3, 4, 5, 6, 7, 8 })
  scenario("none", { [0] = none, [1] = none, [2] = none })
  scenario("some", { [0] = badgeSet({ 1 }), [1] = badgeSet({ 1, 2, 3, 4 }), [2] = badgeSet({ 8 }) })
  scenario("mixed", { [0] = all, [1] = none, [2] = badgeSet({ 2, 5 }) })
  scenario("all", { [0] = all, [1] = all, [2] = all })
  local some = { [0] = badgeSet({ 3, 6 }), [1] = badgeSet({ 1, 8 }), [2] = badgeSet({ 4 }) }
  if F.check("warp into Kanto (Viridian City)", debugWarp(37, 1, "kanto")) then
    F.check("Viridian is the Kanto campaign", region() == 1, "region=" .. region())
    scenario("in kanto", some)
  end
  if F.check("warp into Johto (Cherrygrove City)", debugWarp(75, 1, "johto")) then
    F.check("Cherrygrove is the Johto campaign", region() == 2, "region=" .. region())
    scenario("in johto", some)
  end
  if F.check("warp into Hoenn (Slateport City)", debugWarp(0, 1, "hoenn")) then
    F.check("Slateport is the Hoenn campaign", region() == 3, "region=" .. region())
    scenario("in hoenn", some)
  end
  F.finish()
end)
