-- Kurt's GS Ball scene waits outside his door: once he has looked at the ball the player walks out,
-- is walked three tiles south, and Kurt runs out after them. A Hub Pass out of Kurt's house leaves
-- without that door, so the next arrival in Azalea must not run the scene from wherever the player
-- stands. Kurt's own script takes the ball with real input, the Hub Pass is real, and the suite
-- debug-warps into the Ilex Forest gate and into a house so the player walks into Azalea from
-- elsewhere. Afterwards the player must be free and walking out of Kurt's door must play the
-- scene and give the ball back.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "AzaleaGsBallExit")

local HUB = {100, 0}
local HOENN_ATTENDANT, HOENN_STANDARD = 21, {9, 9}
local AZALEA = {80, 0}
local KURTS_HOUSE = {81, 2}
local HOUSE1 = {81, 1}
local ILEX_GATE = {82, 0}
local VAR_AZALEA_TOWN_STATE = 0xA08C
local FLAG_HIDE_KURT_1, FLAG_HIDE_KURT_2, FLAG_CAUGHT_CELEBI = 0x607C, 0x607D, 0x608E
local FLAG_HIDE_AZALEA_TOWN_SILVER = 0x6071
local ITEM_GS_BALL = 881
local hubPass

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function mapIs(m) return F.grp() == m[1] and F.mapn() == m[2] end
local function flagAddr(id)
  if id >= 0x6000 and id < 0x6400 then
    local o = id - 0x6000
    return F.sb3() + S.SaveBlock3.johtoFlags + o // 8, 1 << (o % 8)
  end
  return F.sb1() + S.SaveBlock1.flags + id // 8, 1 << (id % 8)
end
local function flag(id, value)
  local a, bit = flagAddr(id)
  F.w8(a, value and (F.r8(a) | bit) or (F.r8(a) & (~bit & 255)))
end
local function varAddr(id)
  if id >= 0xA000 then return F.sb3() + S.SaveBlock3.regionVars + (id - 0xA000) * 2 end
  return F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2
end
local function setVar(id, value) F.w16(varAddr(id), value) end
local function getVar(id) return F.r16(varAddr(id)) end
local function state() return getVar(VAR_AZALEA_TOWN_STATE) end
local function hasBall() return F.keyItemSlot(ITEM_GS_BALL) >= 0 end
local function giveKey(id)
  if F.keyItemSlot(id) >= 0 then return true end
  local base = F.r32(S.gBagPockets + 4 * S.BagPocket.stride)
  for i = 0, F.pocketCap(4) - 1 do
    if F.r16(base + i * 4) == 0 then
      F.w16(base + i * 4, id)
      F.w16(base + i * 4 + 2, 1 ~ (F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 65535))
      return F.keyItemSlot(id) >= 0
    end
  end
  return false
end

local function scriptMenuActive()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    local fn = F.r32(a + S.Task.func) & 0xFFFFFFFE
    if F.r8(a + S.Task.isActive) ~= 0 and (fn == S.Task_HandleYesNoInput or fn == S.Task_HandleMultichoiceInput
      or fn == S.Task_CallYesOrNoCallback) then return true end
  end
  return false
end
local function hasControl() return F.ow() and not scriptMenuActive() and F.r8(S.sLockFieldControls) == 0 end
-- Waits out any arrival scene with B, and requires control to hold for a while before returning.
local function settle(tag)
  local held = 0
  for _ = 1, 400 do
    if F.reportCrash(tag) then return false end
    if hasControl() then held = held + 1 else held = 0 end
    if held >= 20 then return true end
    F.press("B", 2); F.idle(8)
  end
  return false
end
local function drain()
  for _ = 1, 30 do
    F.press("B", 2); F.idle(16)
    if F.ensureFree() then return true end
  end
  return false
end
-- Directions the player can step and come back from. Up and Left are left out: the arrivals stand
-- on or just south of a door (the Ilex gate's opens west), and those steps walk back through it.
local function freeDirections()
  local moved = {}
  for _, d in ipairs({"Down", "Right"}) do
    if F.step(d) then
      moved[#moved + 1] = d
      F.step(({Up = "Down", Down = "Up", Left = "Right", Right = "Left"})[d])
    end
  end
  return table.concat(moved, ",")
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
  return false
end
local function awaitMap(m, tag)
  for _ = 1, 220 do
    if mapIs(m) then F.idle(100); return true end
    if F.reportCrash(tag) then return false end
    F.press("A", 2); F.idle(14)
  end
  F.shot(tag .. "_failed")
  return false
end
local function debugWarp(m, warp, tag)
  local function digits(n) return n // 100, (n // 10) % 10, n % 10 end
  local gh, gt, go = digits(m[1])
  local mh, mt, mo = digits(m[2])
  return F.warpTo(gh, gt, go, mh, mt, mo, warp, 0, 0, m[1], m[2], tag)
end
local function passToHub(tag)
  for attempt = 1, 3 do
    drain()
    F.w16(F.sb1() + S.SaveBlock1.registeredItem, hubPass)
    F.press("Select", 2); F.idle(90)
    if menu(0, tag .. "_confirm" .. attempt) then return awaitMap(HUB, tag) end
  end
  return false
end

local function setup()
  if not F.boot(HUB[1]) then return false end
  flag(0xDCF, true)
  flag(0x51, true)
  flag(0xA4B, true)
  flag(0x63F8, true)
  flag(0x94F, true)
  flag(0x95F, true)
  F.w8(F.sb2() + S.SaveBlock2.introDoneBits, 7)
  F.dbg(); F.idle(40); F.sel(2); F.idle(40)
  for _ = 1, 9 do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(180)
  drain()
  local seen = {}
  for _, id in ipairs(select(2, F.keyItemSlot(0xFFFF))) do seen[id] = true end
  if not F.route({{16, 4}, {HOENN_ATTENDANT, 4}, {HOENN_ATTENDANT, 3}}, "first_walk") then return false end
  F.face("Up"); F.press("A", 3); F.idle(60)
  if not (menu(1, "first_team") and menu(1, "first_arrival") and menu(0, "first_confirm")) then return false end
  if not awaitMap(HOENN_STANDARD, "first") then return false end
  for _, id in ipairs(select(2, F.keyItemSlot(0xFFFF))) do if not seen[id] then hubPass = id end end
  -- Kurt at his workbench, the player holding the GS Ball, Celebi not caught.
  flag(FLAG_HIDE_KURT_1, true)
  flag(FLAG_HIDE_KURT_2, false)
  flag(FLAG_CAUGHT_CELEBI, false)
  flag(FLAG_HIDE_AZALEA_TOWN_SILVER, true) -- set on the first Azalea visit, long before the GS Ball
  return hubPass ~= nil
end

-- Kurt takes the ball with real input and the player keeps control inside his house.
local function kurtTakesBall(tag)
  setVar(VAR_AZALEA_TOWN_STATE, 7)
  if not giveKey(ITEM_GS_BALL) then return false end
  if not debugWarp(KURTS_HOUSE, 0, tag .. "_house") then return false end
  drain()
  if not F.route({{4, 7}, {15, 7}, {15, 4}}, tag .. "_walk") then return false end
  F.face("Up"); F.press("A", 3)
  for _ = 1, 120 do
    if state() == 8 and hasControl() then break end
    F.press("A", 2); F.idle(20)
  end
  settle(tag)
  F.shot(tag .. "_kurt_has_ball")
  return state() == 8 and not hasBall() and mapIs(KURTS_HOUSE)
end

-- After an arrival from elsewhere the player must be free and Kurt must still be waiting.
local function arrivedElsewhere(tag)
  local controlled = settle(tag)
  F.shot(tag .. "_arrived")
  local x, y = F.pos()
  local dirs = freeDirections()
  F.check(tag .. ": control returns", controlled, where())
  F.check(tag .. ": the player can walk", dirs ~= "", string.format("%s dirs=%s", where(), dirs))
  F.check(tag .. ": the GS Ball scene still waits for Kurt's door", state() == 8 and not hasBall(),
    string.format("state=%d ball=%s at (%d,%d)", state(), tostring(hasBall()), x, y))
end

F.run(function()
  local ok = setup()
  F.check("setup has a Hub Pass and Kurt at his bench", ok, where())
  if not ok then F.finish(); return end

  F.check("Kurt takes the GS Ball", kurtTakesBall("kurt1"), where() .. " state=" .. state())
  F.check("Hub Pass out of Kurt's house", passToHub("pass1"), where())
  F.check("Ilex Forest gate reached", debugWarp(ILEX_GATE, 0, "ilex_gate"), where())
  drain()
  F.step("Left"); F.step("Right"); F.press("Right", 20); F.idle(60)
  F.check("walked into Azalea from the Ilex Forest gate", mapIs(AZALEA), where())
  arrivedElsewhere("Ilex Forest gate arrival")

  -- Kurt's door: in and out again, and the scene plays where it was written for.
  local walked = F.route({{8, 17}, {18, 17}, {18, 12}, {19, 12}}, "to_kurt")
  F.press("Up", 20); F.idle(150)
  local entered = walked and mapIs(KURTS_HOUSE)
  F.check("walked into Kurt's house", entered, where())
  drain()
  F.press("Down", 20); F.idle(150)
  local controlled = settle("kurt_door")
  F.shot("kurt_door_scene")
  F.check("leaving Kurt's door plays the GS Ball scene", entered and controlled and state() == 9 and hasBall(),
    string.format("%s state=%d ball=%s", where(), state(), tostring(hasBall())))
  F.check("the scene leaves the player south of Kurt's door", mapIs(AZALEA) and select(1, F.pos()) == 19
    and select(2, F.pos()) == 15, where())

  F.check("Kurt takes the GS Ball again", kurtTakesBall("kurt2"), where() .. " state=" .. state())
  F.check("Hub Pass out of Kurt's house again", passToHub("pass2"), where())
  F.check("house reached", debugWarp(HOUSE1, 0, "house1"), where())
  drain()
  F.press("Down", 20); F.idle(60)
  F.check("walked out of the house into Azalea", mapIs(AZALEA), where())
  arrivedElsewhere("house arrival")
  F.finish()
end)
