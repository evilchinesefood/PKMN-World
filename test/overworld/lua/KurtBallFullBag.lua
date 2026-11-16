-- Kurt checks the bag before he makes a BALL.
--
-- Kurt takes five berries and makes five BALLS. With the POKé BALLS pocket full he hammered away,
-- said "I just finished your BALL. Here!", and only then the bag check said "The BAG is full".
-- He now checks first and says the bag has no room, before he starts.
--
-- Setup puts Azalea past the Slowpoke Well (VAR_AZALEA_TOWN_STATE 4, the crafting Kurt shown),
-- gives five Pecha Berries, and fills the 16-slot pocket in RAM with 16 ball types that are not a
-- Love Ball. Talking to Kurt and picking LOVE BALL is real input. Every line Kurt prints is read
-- from gStringVar4. With the pocket full he must not say "finished" or "get started", and the
-- berries stay. With one slot freed the same talk must make five Love Balls for the five berries.
--
-- Run: test/overworld/mgba-run.sh test/overworld/lua/KurtBallFullBag.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "KurtBallFullBag")

local KURT_FRONT = { 81, 2, 15, 4 }
local VAR_AZALEA_TOWN_STATE = 0xA08C
local FLAG_HIDE_KURT_1, FLAG_HIDE_KURT_2 = 0x607C, 0x607D
local POCKET_POKE_BALLS, POCKET_BERRIES = 1, 3
local ITEM_LOVE_BALL, ITEM_PECHA_BERRY = 19, 516
local OTHER_BALLS = { 2, 3, 6, 7, 8, 9, 10, 11, 12, 13, 14, 5, 15, 16, 17, 18 }
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2

local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end
local function scriptDone() return F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN and F.r8(S.sLockFieldControls) == 0 end
local function settle()
  for _ = 1, 300 do if F.ow() and scriptDone() then return true end F.press("B", 2); F.idle(10) end
  return false
end
local function key() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF end
local function pocketPtr(p) return F.r32(S.gBagPockets + p * S.BagPocket.stride + S.BagPocket.itemsPtr) end
local function quantity(p, id)
  local ptr, n = pocketPtr(p), 0
  for s = 0, F.pocketCap(p) - 1 do
    if F.r16(ptr + s * 4) == id then n = n + ((F.r16(ptr + s * 4 + 2) ~ key()) & 0xFFFF) end
  end
  return n
end
local function fillBalls()
  local ptr, cap = pocketPtr(POCKET_POKE_BALLS), F.pocketCap(POCKET_POKE_BALLS)
  if cap ~= #OTHER_BALLS then return false end
  for s = 0, cap - 1 do F.w16(ptr + s * 4, OTHER_BALLS[s + 1]); F.w16(ptr + s * 4 + 2, 3 ~ key()) end
  return true
end
local function freeLastBallSlot()
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
    elseif b == 0xB4 then t[#t + 1] = "'"
    elseif b == 0xAB then t[#t + 1] = "!"
    else t[#t + 1] = " " end
  end
  return (table.concat(t):gsub("%s+", " "))
end

local SCRIPT_BUF = S.gStringVar4 + 960
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function runScript(b)
  for i, v in ipairs(b) do F.w8(SCRIPT_BUF + i - 1, v) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
  F.idle(20)
end

local function multichoiceLive()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    if F.r8(a + S.Task.isActive) ~= 0 and (F.r32(a + S.Task.func) & ~1) == (S.Task_HandleMultichoiceInput & ~1) then return true end
  end
  return false
end

-- Talk to Kurt, pick LOVE BALL (row 0) once, cancel the menu if it comes back, and collect every
-- line he printed, in order.
local function askForLoveBall(tag)
  F.face("Up"); F.press("A", 2); F.idle(20)
  local lines, last, picked = {}, nil, false
  for _ = 1, 600 do
    local t = text()
    if t ~= last then
      lines[#lines + 1] = t; last = t
      if t:find("BAG", 1, true) or t:find("finished", 1, true) then F.idle(10); F.shot(tag .. "_line" .. #lines) end
    end
    if multichoiceLive() then
      F.idle(10)
      if not picked then
        for _ = 1, 8 do if F.mcur() == 0 then break end F.press("Up", 2); F.idle(10) end
        F.press("A", 2); picked = true
      else
        F.shot(tag .. "_menu_again")
        F.press("B", 2)
      end
      F.idle(20)
    elseif scriptDone() then
      break
    else
      F.press("A", 2); F.idle(12)
    end
  end
  local said = table.concat(lines, " | ")
  F.L("  " .. tag .. ": " .. said)
  settle()
  return said
end

F.run(function()
  if not F.boot(100) then F.finish(); return end
  instantText()
  local b = {}
  b[#b + 1] = 0x2A; le16(b, FLAG_HIDE_KURT_2)
  b[#b + 1] = 0x29; le16(b, FLAG_HIDE_KURT_1)
  b[#b + 1] = 0x16; le16(b, VAR_AZALEA_TOWN_STATE); le16(b, 4)
  b[#b + 1] = 0x44; le16(b, ITEM_PECHA_BERRY); le16(b, 5)
  b[#b + 1] = 0x02
  runScript(b)
  F.check("setup: five Pecha Berries", quantity(POCKET_BERRIES, ITEM_PECHA_BERRY) == 5)
  F.check("setup: the POKé BALLS pocket holds 16 other ball types", fillBalls())

  local warp = { 0x39, KURT_FRONT[1], KURT_FRONT[2], 0xFF }
  le16(warp, KURT_FRONT[3]); le16(warp, KURT_FRONT[4]); warp[#warp + 1] = 0x27; warp[#warp + 1] = 0x02
  runScript(warp)
  for _ = 1, 400 do F.idle(4); if F.grp() == KURT_FRONT[1] and F.mapn() == KURT_FRONT[2] and F.ow() then break end end
  settle(); instantText()
  F.check("in front of Kurt", F.grp() == 81 and F.mapn() == 2, string.format("%d.%d", F.grp(), F.mapn()))

  local full = askForLoveBall("full")
  F.check("full pocket: Kurt says the bag has no room for the BALLS", full:find("no room for those BALLS", 1, true) ~= nil, full)
  F.check("full pocket: Kurt never says he finished a BALL", not full:find("finished", 1, true), full)
  F.check("full pocket: Kurt never starts", not full:find("get started", 1, true), full)
  F.check("full pocket: the berries stay and no Love Ball appears",
    quantity(POCKET_BERRIES, ITEM_PECHA_BERRY) == 5 and quantity(POCKET_POKE_BALLS, ITEM_LOVE_BALL) == 0)

  freeLastBallSlot()
  local room = askForLoveBall("room")
  F.check("with room: Kurt starts, finishes and says it turned out great",
    room:find("get started", 1, true) ~= nil and room:find("finished", 1, true) ~= nil and room:find("turned out great", 1, true) ~= nil, room)
  F.check("with room: five berries became five Love Balls",
    quantity(POCKET_BERRIES, ITEM_PECHA_BERRY) == 0 and quantity(POCKET_POKE_BALLS, ITEM_LOVE_BALL) == 5,
    string.format("berries=%d love=%d", quantity(POCKET_BERRIES, ITEM_PECHA_BERRY), quantity(POCKET_POKE_BALLS, ITEM_LOVE_BALL)))

  F.check("no crash", not F.reportCrash("end"))
  F.finish()
end)
