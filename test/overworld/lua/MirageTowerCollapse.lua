-- Mirage Tower's collapse, taken with real input and mashed. The player stands under a fossil on
-- 4F with a follower out, talks to it, answers YES and mashes A/B through the ceiling crumble, the
-- warp to Route 111, the fall, the tower's disintegration and the fossil message. The fossil must
-- be in the bag, the tower state must advance, the player must land on the sand with control and
-- the follower must come back beside them. Then Route 111 is entered again: the tower stays gone.
--
-- Run: test/overworld/mgba-run.sh test/overworld/lua/MirageTowerCollapse.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "MirageTowerCollapse")

local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local MAIN_VBLANK_COUNTER1 = 0x20
local VAR_MIRAGE_TOWER_STATE = 0x40CB
local VAR_REPEL_STEP_COUNT = 0x4021
local FLAG_CHOSE_ROOT_FOSSIL, FLAG_CHOSE_CLAW_FOSSIL = 0x14F, 0x150
local FLAG_HIDE_DESERT_UNDERPASS_FOSSIL = 0x36A
local FLAG_HIDE_ROOT, FLAG_HIDE_CLAW = 0x3C3, 0x3C4
local ITEM_ROOT_FOSSIL, ITEM_CLAW_FOSSIL = 168, 169
local OBJ_PLAYER, OBJ_FOLLOWER = 0xFF, 0xFE
local TOWER_4F = { 24, 97 }
local ROUTE111 = { 0, 26 }

local function vblank() return F.r32(S.gMain + MAIN_VBLANK_COUNTER1) end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function flagGet(id) return (F.r8(F.sb1() + S.SaveBlock1.flags + (id // 8)) & (1 << (id % 8))) ~= 0 end
local function flagSet(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + (id // 8), 1 << (id % 8)
  F.w8(a, on and (F.r8(a) | m) or (F.r8(a) & ~m & 0xFF))
end
local function varGet(id) return F.r16(F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2) end
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
local function warpScript(g, n, x, y)
  local b = { 0x39, g, n, 0xFF }
  le16(b, x); le16(b, y); b[#b + 1] = 0x27; b[#b + 1] = 0x02
  runScript(b)
  for _ = 1, 400 do
    F.idle(4)
    if F.reportCrash("warp") then return false end
    if F.grp() == g and F.mapn() == n and F.ow() then
      for _ = 1, 200 do if hasControl() then F.idle(20); return true end F.press("B", 2); F.idle(10) end
      return hasControl()
    end
  end
  F.L(string.format("  warp to %d.%d failed: at %d.%d cb2=%08X", g, n, F.grp(), F.mapn(), F.cb2()))
  return false
end

local function obj(localId)
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == localId then
      return { x = F.rs16(b + S.ObjectEvent.x) - 7, y = F.rs16(b + S.ObjectEvent.y) - 7,
               invisible = (F.r8(b + S.ObjectEvent.flags1) & 0x20) ~= 0 }
    end
  end
  return nil
end

local function giveParty()
  F.dbg(); F.idle(40); F.sel(2); F.idle(40)
  for _ = 1, 9 do F.press("Down", 2); F.idle(12) end
  F.press("A", 2); F.idle(180); F.bOut(6); F.idle(60)
end

local seed = 0x5EED
local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648; return (seed >> 8) % n end

-- Mash A/B until the player has control on Route 111 for three samples in a row.
local function mashCollapse(tag)
  local frames, settled, lastVb, stalls = 0, 0, vblank(), 0
  local hiddenWithFollowerShown, shotFall, maxSprites = 0, false, 0
  while frames < 12000 do
    if F.reportCrash(tag) then return false, "crash screen", 0 end
    local vb = vblank()
    if vb == lastVb then stalls = stalls + 1 else stalls = 0 end
    lastVb = vb
    if stalls > 30 then return false, "vblank counter stopped", 0 end
    if F.ow() and F.grp() == ROUTE111[1] and F.mapn() == ROUTE111[2] then
      local p, f = obj(OBJ_PLAYER), obj(OBJ_FOLLOWER)
      if p and p.invisible and f and not f.invisible then
        hiddenWithFollowerShown = hiddenWithFollowerShown + 1
        if not shotFall then F.shot(tag .. "_follower_while_player_hidden"); shotFall = true end
      end
      if hasControl() then
        settled = settled + 1
        if settled >= 3 then return true, string.format("frames=%d", frames), hiddenWithFollowerShown end
      else
        settled = 0
      end
    end
    if hasControl() then
      F.idle(10); frames = frames + 10
    else
      local chose = flagGet(FLAG_CHOSE_ROOT_FOSSIL) or flagGet(FLAG_CHOSE_CLAW_FOSSIL)
      F.press((not chose or rnd(10) < 7) and "A" or "B", 2)
      local wait = 3 + rnd(12)
      F.idle(wait); frames = frames + 2 + wait
    end
  end
  return false, "control never returned on Route 111 at " .. F.grp() .. "." .. F.mapn(), hiddenWithFollowerShown
end

local function takeFossil(x, tag)
  if not warpScript(TOWER_4F[1], TOWER_4F[2], x, 5) then F.check(tag .. ": reached 4F", false); return false end
  F.face("Up")
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 then
      F.L(string.format("  obj %d local=%d gfx=%d (%d,%d) inv=%s", i, F.r8(b + S.ObjectEvent.localId),
        F.r16(b + S.ObjectEvent.graphicsId), F.rs16(b + S.ObjectEvent.x) - 7, F.rs16(b + S.ObjectEvent.y) - 7,
        tostring((F.r8(b + S.ObjectEvent.flags1) & 0x20) ~= 0)))
    end
  end
  F.shot(tag .. "_before_talk")
  F.press("A", 2)
  for _ = 1, 30 do F.idle(2); if not hasControl() then F.idle(30); F.shot(tag .. "_talk"); return true end end
  F.check(tag .. ": fossil talk started", false)
  return false
end

F.run(function()
  if not F.boot(100) then F.finish(); return end
  giveParty()
  F.check("debug party", F.r8(S.gPartiesCount) >= 1, "party=" .. F.r8(S.gPartiesCount))
  varSet(VAR_REPEL_STEP_COUNT, 250)
  F.ensureFree()

  -- Root Fossil, follower out.
  if takeFossil(5, "root") then
    local fol = obj(OBJ_FOLLOWER)
    F.L("  follower before: " .. (fol and string.format("(%d,%d) inv=%s", fol.x, fol.y, tostring(fol.invisible)) or "none"))
    local ok, detail, hidden = mashCollapse("root")
    F.check("root: collapse returns control on Route 111", ok, detail)
    F.shot("root_landed")
    local x, y = F.pos()
    F.check("root: landed on (19,59)", x == 19 and y == 59, string.format("(%d,%d)", x, y))
    F.check("root: Root Fossil in the bag", F.itemCount(ITEM_ROOT_FOSSIL) == 1, "count=" .. F.itemCount(ITEM_ROOT_FOSSIL))
    F.check("root: no Claw Fossil", F.itemCount(ITEM_CLAW_FOSSIL) == 0)
    F.check("root: chose-root flag", flagGet(FLAG_CHOSE_ROOT_FOSSIL) and not flagGet(FLAG_CHOSE_CLAW_FOSSIL))
    F.check("root: both fossils hidden", flagGet(FLAG_HIDE_ROOT) and flagGet(FLAG_HIDE_CLAW))
    F.check("root: tower state 2 after the disintegration", varGet(VAR_MIRAGE_TOWER_STATE) == 2,
      "state=" .. varGet(VAR_MIRAGE_TOWER_STATE))
    F.check("root: Desert Underpass fossil shown", not flagGet(FLAG_HIDE_DESERT_UNDERPASS_FOSSIL))
    F.check("root: follower never stood visible while the player was hidden", hidden == 0,
      "frames=" .. tostring(hidden))
    local p = obj(OBJ_PLAYER)
    F.check("root: player visible after landing", p and not p.invisible)
    F.check("root: player can walk", F.step("Down"), string.format("(%d,%d)", F.pos()))
    F.idle(30)
    if fol then
      local f = obj(OBJ_FOLLOWER)
      x, y = F.pos()
      F.check("root: follower out beside the player after a step",
        f and not f.invisible and math.abs(f.x - x) + math.abs(f.y - y) <= 1,
        f and string.format("follower (%d,%d) inv=%s, player (%d,%d)", f.x, f.y, tostring(f.invisible), x, y) or "none")
      F.shot("root_follower_after_step")
    end
    -- Re-enter Route 111 from another map: the tower stays gone.
    if warpScript(2, 2, 7, 4) and warpScript(ROUTE111[1], ROUTE111[2], 19, 60) then
      F.check("root: tower state 3 on re-entry", varGet(VAR_MIRAGE_TOWER_STATE) == 3,
        "state=" .. varGet(VAR_MIRAGE_TOWER_STATE))
      F.shot("root_route111_reentry")
    else
      F.check("root: re-entered Route 111", false)
    end
  end

  F.finish()
end)
