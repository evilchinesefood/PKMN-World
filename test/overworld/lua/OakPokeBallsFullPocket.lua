-- Oak's five POKé BALLS must not vanish into a full POKé BALLS pocket.
--
-- The POKéDEX scene handed them out with giveitem_msg (additem plus a fanfare, no space check).
-- The pocket has 16 slots, and a player who reaches Kanto after Johto and Hoenn can already carry
-- 16 other ball types: the Hub clerk sells 12 and Kurt makes 7 more. Oak then said "received five
-- POKé BALLS" and the bag stayed unchanged. Oak now says there is no room, the scene still
-- finishes, and he hands the balls over once the player has made room.
--
-- Setup boots a new game, enters Kanto through the Hub gate and plays Oak's starter scene with real
-- input. The rival battle is not fought: the suite writes what EndRivalBattle writes (lab scene 4,
-- FLAG_BEAT_RIVAL_IN_OAKS_LAB, FLAG_HIDE_RIVAL_IN_LAB). The Viridian clerk's real ON_FRAME scene
-- then hands over the PARCEL and moves the lab to scene 5. The POKé BALLS pocket is filled in RAM
-- with 16 real ball ids, none of them a POKé BALL. Delivering the PARCEL and both talks to Oak use
-- real input.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/OakPokeBallsFullPocket.lua [rom.gba]

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "OakPokeBallsFullPocket")

local HUB_G = 100
local LAB_G, LAB_M = 38, 3
local MART_G, MART_M = 39, 3
local VAR_LAB = 0xA02E
local FLAG_HIDE_RIVAL_IN_LAB = 0xA6D
local FLAG_BEAT_RIVAL_IN_OAKS_LAB = 0xC98
local FLAG_SYS_POKEDEX_GET = 0x949
local POCKET_POKE_BALLS = 1
local ITEM_POKE_BALL = 1
local ITEM_OAKS_PARCEL = 746
-- Hub clerk stock (Great..Premier, ids 2-14 less Master) plus Kurt's Level, Lure, Moon, Friend.
local OTHER_BALLS = { 2, 3, 6, 7, 8, 9, 10, 11, 12, 13, 14, 5, 15, 16, 17, 18 }

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function mapIs(g, m) return F.grp() == g and F.mapn() == m end
local function varAddr(id)
  if id >= 0xA000 then return F.sb3() + S.SaveBlock3.regionVars + (id - 0xA000) * 2 end
  return F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2
end
local function var(id, value)
  if value == nil then return F.r16(varAddr(id)) end
  F.w16(varAddr(id), value)
end
local function flag(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + (id // 8), 1 << (id % 8)
  if on == nil then return (F.r8(a) & m) ~= 0 end
  F.w8(a, on and (F.r8(a) | m) or (F.r8(a) & ~m & 0xFF))
end
local function key() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF end
local function pocketPtr(p) return F.r32(S.gBagPockets + p * S.BagPocket.stride + S.BagPocket.itemsPtr) end
local function quantity(id)
  local ptr, n = pocketPtr(POCKET_POKE_BALLS), 0
  for s = 0, F.pocketCap(POCKET_POKE_BALLS) - 1 do
    if F.r16(ptr + s * 4) == id then n = n + ((F.r16(ptr + s * 4 + 2) ~ key()) & 0xFFFF) end
  end
  return n
end
local function usedSlots()
  local ptr, n = pocketPtr(POCKET_POKE_BALLS), 0
  for s = 0, F.pocketCap(POCKET_POKE_BALLS) - 1 do if F.r16(ptr + s * 4) ~= 0 then n = n + 1 end end
  return n
end
local function fillBalls()
  local ptr, cap = pocketPtr(POCKET_POKE_BALLS), F.pocketCap(POCKET_POKE_BALLS)
  if cap ~= #OTHER_BALLS then return false end
  for s = 0, cap - 1 do F.w16(ptr + s * 4, OTHER_BALLS[s + 1]); F.w16(ptr + s * 4 + 2, 3 ~ key()) end
  return true
end
local function tossLastSlot()
  local ptr, cap = pocketPtr(POCKET_POKE_BALLS), F.pocketCap(POCKET_POKE_BALLS)
  F.w16(ptr + (cap - 1) * 4, 0); F.w16(ptr + (cap - 1) * 4 + 2, 0)
end

local function text()
  local t = {}
  for i = 0, 199 do
    local b = F.r8(S.gStringVar4 + i)
    if b == 0xFF then break end
    if b >= 0xBB and b <= 0xD4 then t[#t + 1] = string.char(65 + b - 0xBB)
    elseif b >= 0xD5 and b <= 0xEE then t[#t + 1] = string.char(97 + b - 0xD5)
    else t[#t + 1] = " " end
  end
  return table.concat(t)
end
local function scriptMenuActive()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    local fn = F.r32(a + S.Task.func) & 0xFFFFFFFE
    if F.r8(a + S.Task.isActive) ~= 0 and (fn == S.Task_HandleYesNoInput or fn == S.Task_HandleMultichoiceInput or fn == S.Task_CallYesOrNoCallback) then return true end
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
          for _ = 1, 4 do
            F.press("A", 2)
            for _ = 1, 30 do
              if not scriptMenuActive() then F.idle(30); return true end
              F.idle(1)
            end
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
local function awaitMap(g, m, tag)
  for _ = 1, 260 do
    if mapIs(g, m) then F.idle(100); return true end
    if F.reportCrash(tag) then return false end
    F.press("A", 2); F.idle(14)
  end
  F.shot(tag .. "_failed")
  return false
end
local function debugWarp(g, m, tag)
  local function digits(n) return n // 100, (n // 10) % 10, n % 10 end
  local gh, gt, go = digits(g); local mh, mt, mo = digits(m)
  return F.warpTo(gh, gt, go, mh, mt, mo, 0, 0, 0, g, m, tag)
end
-- B through a scripted scene until the player is free, logging every message that appears.
local function playScene(tag, seen)
  local last
  for _ = 1, 600 do
    if F.reportCrash(tag) then return false end
    local t = text()
    if t ~= last then
      last = t
      if #t > 0 then seen[#seen + 1] = t; F.L("  " .. tag .. ": " .. t) end
      if t:find("received five", 1, true) or t:find("no room", 1, true) then F.idle(40); F.shot(tag .. "_balls_msg") end
    end
    if scriptMenuActive() then return false end
    F.press("B", 2); F.idle(14)
    if F.ow() and F.ensureFree() then return true end
  end
  return false
end
local function said(seen, needle)
  for _, t in ipairs(seen) do if t:find(needle, 1, true) then return true end end
  return false
end
local function talkToOak(tag)
  if not F.route({ { 6, 5 }, { 6, 4 } }, tag .. "_walk") then return nil end
  F.w8(S.gStringVar4, 0xFF)
  F.face("Up"); F.press("A", 2); F.idle(30)
  local seen = {}
  local free = playScene(tag, seen)
  F.shot(tag)
  return seen, free
end

F.run(function()
  if not F.boot(HUB_G) then F.check("fresh boot", false); F.finish(); return end
  F.check("walk to the Kanto gate", F.route({ { 16, 4 }, { 11, 4 }, { 11, 3 } }, "kanto_gate"))
  F.face("Up"); F.press("A", 3); F.idle(60)
  F.check("Kanto gate crossing accepted", menu(0, "kanto_yes"))
  F.check("land in the Pallet bedroom", awaitMap(38, 1, "bedroom"), where())
  playScene("bedroom", {})

  F.check("reach Pallet Town", debugWarp(37, 0, "pallet"))
  playScene("pallet", {})
  F.check("walk toward Route 1", F.route({ { 6, 8 }, { 12, 8 }, { 12, 2 } }, "pallet_north"))
  F.press("Up", 16); F.idle(30)
  for _ = 1, 400 do
    if var(VAR_LAB) == 2 and F.ow() and not scriptMenuActive() then break end
    if F.reportCrash("oak_scene") then break end
    F.press("B", 2); F.idle(14)
  end
  playScene("starter_scene", {})
  F.check("Oak's starter scene runs", var(VAR_LAB) == 2 and mapIs(LAB_G, LAB_M), where() .. " lab=" .. var(VAR_LAB))

  local px = F.pos()
  F.check("walk to Bulbasaur's ball", F.route({ { px, 5 }, { 8, 5 } }, "bulbasaur_walk"))
  F.face("Up"); F.press("A", 2); F.idle(60)
  F.check("take Bulbasaur", menu(0, "bulbasaur_yes"))
  for _ = 1, 300 do
    if scriptMenuActive() then menu(1, "nickname_no") end
    if F.ow() and not scriptMenuActive() and F.ensureFree() then break end
    F.press("B", 2); F.idle(14)
  end
  F.check("the starter pick moves the lab to scene 3", var(VAR_LAB) == 3, "lab=" .. var(VAR_LAB))

  var(VAR_LAB, 4)
  flag(FLAG_BEAT_RIVAL_IN_OAKS_LAB, true)
  flag(FLAG_HIDE_RIVAL_IN_LAB, true)

  F.check("reach the Viridian mart", debugWarp(MART_G, MART_M, "viridian_mart"))
  playScene("parcel", {})
  F.check("the clerk's scene hands over the PARCEL", var(VAR_LAB) == 5 and F.itemCount(ITEM_OAKS_PARCEL) == 1,
    "lab=" .. var(VAR_LAB) .. " parcel=" .. F.itemCount(ITEM_OAKS_PARCEL))

  F.check("setup: the POKé BALLS pocket holds 16 other ball types", fillBalls() and usedSlots() == 16 and quantity(ITEM_POKE_BALL) == 0,
    "used=" .. usedSlots() .. " poke=" .. quantity(ITEM_POKE_BALL))

  F.check("reach Oak's lab", debugWarp(LAB_G, LAB_M, "lab"))
  playScene("lab_entry", {})
  local seen, free = talkToOak("dex_scene")
  F.check("the POKéDEX scene runs to the end", free and var(VAR_LAB) == 6 and flag(FLAG_SYS_POKEDEX_GET),
    "lab=" .. var(VAR_LAB) .. " dex=" .. tostring(flag(FLAG_SYS_POKEDEX_GET)))
  F.check("Oak hands over the POKéDEX", seen and said(seen, "received the POK"))
  F.check("no POKé BALL fits into the full pocket", quantity(ITEM_POKE_BALL) == 0 and usedSlots() == 16,
    "poke=" .. quantity(ITEM_POKE_BALL) .. " used=" .. usedSlots())
  F.check("the player is not told five POKé BALLS arrived", seen and not said(seen, "received five"))
  F.check("Oak says there is no room for them", seen and said(seen, "no room for these"))

  local again = talkToOak("still_full")
  F.check("with the pocket still full, Oak keeps them", again and said(again, "no room for these") and quantity(ITEM_POKE_BALL) == 0,
    "poke=" .. quantity(ITEM_POKE_BALL))

  tossLastSlot()
  local later = talkToOak("after_room")
  F.check("after making room, Oak gives the five POKé BALLS", quantity(ITEM_POKE_BALL) == 5, "poke=" .. quantity(ITEM_POKE_BALL))
  F.check("and says so", later and said(later, "received five"))

  local after = talkToOak("once_only")
  F.check("the handover happens only once", quantity(ITEM_POKE_BALL) == 5 and after and not said(after, "received five"),
    "poke=" .. quantity(ITEM_POKE_BALL))
  F.check("player control returns", F.ensureFree())
  F.check("no crash", not F.crashScreen())
  F.finish()
end)
