-- The Abandoned Ship's Storage Key and Capt. Stern's Scanner trade, with real input. The locked
-- storage door is tried without the key, then with it: the key must be used up, the door must stay
-- unlocked after the map reloads, and the player must walk into the storage room. At the Slateport
-- harbor Stern is offered the Scanner with a full Items pocket: the trade must be refused with the
-- Scanner kept. With room, the DEEP SEA TOOTH must arrive, the Scanner must go, and talking again
-- must not trade twice.
--
-- Run: test/overworld/mgba-run.sh test/overworld/lua/AbandonedShipScanner.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "AbandonedShipScanner")

local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local MAIN_VBLANK_COUNTER1 = 0x20
local SYS = 0x948
local FLAG_BADGE07_GET = SYS + 13
local FLAG_USED_STORAGE_KEY, FLAG_EXCHANGED_SCANNER = 0xEF, 0x126
local FLAG_HIDE_STERN = 0x349
local ITEM_SCANNER, ITEM_STORAGE_KEY, ITEM_DEEP_SEA_TOOTH, ITEM_DEEP_SEA_SCALE = 737, 738, 399, 398
local VAR_REPEL_STEP_COUNT = 0x4021
local SHIP_B1F = { 24, 57 }
local STORAGE_ROOM = { 24, 61 }
local HARBOR = { 9, 9 }

local function vblank() return F.r32(S.gMain + MAIN_VBLANK_COUNTER1) end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function flagGet(id) return (F.r8(F.sb1() + S.SaveBlock1.flags + (id // 8)) & (1 << (id % 8))) ~= 0 end
local function flagSet(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + (id // 8), 1 << (id % 8)
  F.w8(a, (on == false) and (F.r8(a) & ~m & 0xFF) or (F.r8(a) | m))
end
local function varSet(id, v) F.w16(F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2, v) end

local SCRIPT_BUF = S.gStringVar4 + 960
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
end

local function mash(tag, budget, keys)
  local frames, settled, lastVb, stalls, i = 0, 0, vblank(), 0, 0
  while frames < (budget or 6000) do
    if F.reportCrash(tag) then return false, "crash screen" end
    local vb = vblank()
    if vb == lastVb then stalls = stalls + 1 else stalls = 0 end
    lastVb = vb
    if stalls > 30 then return false, "vblank counter stopped" end
    if hasControl() then
      settled = settled + 1
      if settled >= 3 then return true, "frames=" .. frames end
      F.idle(10); frames = frames + 10
    else
      settled = 0; i = i + 1
      F.press(keys[(i % #keys) + 1], 2); F.idle(12); frames = frames + 14
    end
  end
  return false, string.format("no control after %d frames at %d.%d", frames, F.grp(), F.mapn())
end

local function addItem(id)
  local b = { 0x44 }
  le16(b, id); le16(b, 1); b[#b + 1] = 0x02
  runScript(b)
  F.idle(10)
end

local function warpScript(g, n, x, y)
  local b = { 0x39, g, n, 0xFF }
  le16(b, x); le16(b, y); b[#b + 1] = 0x27; b[#b + 1] = 0x02
  runScript(b)
  for _ = 1, 400 do
    F.idle(4)
    if F.reportCrash("warp") then return false end
    if F.grp() == g and F.mapn() == n and F.ow() then return mash("warp_arrival", 3000, { "B" }) end
  end
  return false
end

local function giveParty()
  F.dbg(); F.idle(40); F.sel(2); F.idle(40)
  for _ = 1, 9 do F.press("Down", 2); F.idle(12) end
  F.press("A", 2); F.idle(180); F.bOut(6); F.idle(60)
end
local function fillItemsPocket()
  F.dbg(); F.sel(1); F.sel(1); F.sel(3); F.idle(120); F.bOut(6); mash("fill", 2000, { "B" })
end
local function clearBag()
  F.dbg(); F.sel(1); F.sel(2); F.idle(120); F.bOut(6); mash("clear", 2000, { "B" })
end

local function talk(dir, tag, keys)
  F.face(dir); F.idle(20)
  F.press("A", 2)
  local started = false
  for _ = 1, 60 do F.idle(2); if not hasControl() then started = true; break end end
  F.idle(20)
  F.shot(tag)
  local ok, detail = mash(tag, 6000, keys or { "A" })
  return started and ok, detail .. " started=" .. tostring(started)
end

F.run(function()
  if not F.boot(100) then F.finish(); return end
  giveParty()
  varSet(VAR_REPEL_STEP_COUNT, 250)
  F.ensureFree()

  -- Storage room door.
  if F.check("ship: below the storage door", warpScript(SHIP_B1F[1], SHIP_B1F[2], 11, 5)) then
    local ok, detail = talk("Up", "ship_locked")
    F.check("ship: locked without the key", ok and not flagGet(FLAG_USED_STORAGE_KEY), detail)
    addItem(ITEM_STORAGE_KEY)
    F.check("ship: Storage Key in the bag", F.itemCount(ITEM_STORAGE_KEY) == 1)
    ok, detail = talk("Up", "ship_unlock")
    F.check("ship: key unlocks the door", ok and flagGet(FLAG_USED_STORAGE_KEY), detail)
    F.check("ship: key used up", F.itemCount(ITEM_STORAGE_KEY) == 0, "count=" .. F.itemCount(ITEM_STORAGE_KEY))
    if warpScript(SHIP_B1F[1], SHIP_B1F[2], 11, 5) then
      F.step("Up")
      local entered = false
      for _ = 1, 200 do F.idle(4); if F.grp() == STORAGE_ROOM[1] and F.mapn() == STORAGE_ROOM[2] then entered = true; break end end
      F.check("ship: door stays open after a reload and leads into the storage room", entered,
        string.format("at %d.%d (%d,%d)", F.grp(), F.mapn(), F.pos()))
      mash("ship_room", 3000, { "B" })
      F.shot("ship_storage_room")
    end
  end

  -- Capt. Stern's Scanner trade.
  flagSet(FLAG_BADGE07_GET)
  flagSet(FLAG_HIDE_STERN, false)
  addItem(ITEM_SCANNER)
  fillItemsPocket()
  if F.check("harbor: beside Capt. Stern", warpScript(HARBOR[1], HARBOR[2], 6, 12)) then
    local ok, detail = talk("Down", "stern_full")
    F.check("harbor: full pocket refuses the trade", ok and F.itemCount(ITEM_DEEP_SEA_TOOTH) == 0, detail)
    F.check("harbor: Scanner kept", F.itemCount(ITEM_SCANNER) == 1 and not flagGet(FLAG_EXCHANGED_SCANNER))
    clearBag()
    addItem(ITEM_SCANNER)
    ok, detail = talk("Down", "stern_trade")
    F.check("harbor: trade completes", ok, detail)
    F.check("harbor: DEEP SEA TOOTH received", F.itemCount(ITEM_DEEP_SEA_TOOTH) == 1, "count=" .. F.itemCount(ITEM_DEEP_SEA_TOOTH))
    F.check("harbor: Scanner handed over", F.itemCount(ITEM_SCANNER) == 0 and flagGet(FLAG_EXCHANGED_SCANNER))
    ok, detail = talk("Down", "stern_again")
    F.check("harbor: talking again trades nothing", ok and F.itemCount(ITEM_DEEP_SEA_TOOTH) == 1
      and F.itemCount(ITEM_DEEP_SEA_SCALE) == 0, detail)
  end
  F.finish()
end)
