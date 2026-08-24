-- Tohjo Falls Celebi gate (v1.5).
-- Arriving with a full-HP Celebi follower arms VAR_TOHJO_FALLS_GIOVANNI_STATE.
-- CheckCelebi (src/scrcmd_johto_compat.c) requires lead SPECIES_CELEBI, HP==maxHP,
-- and a visible follower. ON_TRANSITION runs before ResetObjectEvents, so it sees
-- the leftover follower from the previous map.
--
-- Run via Testing/mgba-run.sh Testing/lua/TohjoCelebi.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "TohjoCelebi")

local HUB_GROUP = 100
local GRP_GIO, MAP_GIO, WARP_GIO = 98, 9, 0   -- MAP_TOHJO_FALLS_GIOVANNI_ROOM
local ROW_PARTY_MENU, ROW_SET = 2, 9
local FOLLOWER = 0xFE
local OBJ_EVENT_MON, SPECIES_MASK = 1 << 14, 0x8FFF
local SPECIES_WOBBUFFET, SPECIES_CELEBI = 202, 251
local OFF_HP, OFF_MAXHP = S.Pokemon.hp, S.Pokemon.maxHP
local OFF_CHECKSUM, OFF_SECURE = 28, 32
local SUB_STRIDE, NRAW = 12, 12
local REGION_VARS_START = 0xA000
local VAR_TOHJO = 0xA080 + 0x3A               -- VAR_TOHJO_FALLS_GIOVANNI_STATE
local SCRIPT_SCENE = S.TohjoFalls_EventScript_GiovanniScene
local SCRIPT_RIGHT = S.TohjoFalls_EventScript_GiovanniSceneRight
local CTX_STATUS = S.sGlobalScriptContextStatus
local CTX_SCRIPT = S.ScriptCtx.scriptPtr

local SUB0 = { [0]=0,0,0,0,0,0,1,1,2,3,2,3,1,1,2,3,2,3,1,1,2,3,2,3 }

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end

local function go(grp, map, warp, tag)
  local gh, gt, go_ = d(grp)
  local mh, mt, mo = d(map)
  local wh, wt, wo = d(warp)
  if not F.warpTo(gh, gt, go_, mh, mt, mo, wh, wt, wo, grp, map, tag) then
    F.check(tag .. "_warped", false, string.format("grp=%d map=%d", F.grp(), F.mapn()))
    return false
  end
  F.idle(60)
  return true
end

local function tapDown(n)
  for _ = 1, n do F.press("Down", 3); F.idle(16) end
end

local function setParty()
  F.dbg(); F.idle(60)
  tapDown(ROW_PARTY_MENU); F.press("A", 3); F.idle(60)
  tapDown(ROW_SET); F.press("A", 3); F.idle(180)
  for _ = 1, 6 do F.press("B", 3); F.idle(20) end
end

local function slot0() return S.gParties end

local function xorSecure(mon)
  local key = F.r32(mon) ~ F.r32(mon + 4)
  for i = 0, NRAW - 1 do
    local a = mon + OFF_SECURE + i * 4
    F.w32(a, F.r32(a) ~ key)
  end
end

local function checksumDecrypted(mon)
  local sum = 0
  for i = 0, NRAW - 1 do
    local w = F.r32(mon + OFF_SECURE + i * 4)
    sum = (sum + w + (w >> 16)) & 0xFFFFFFFF
  end
  return sum & 0xFFFF
end

local function readSpecies(mon)
  xorSecure(mon)
  local pid = F.r32(mon)
  local sub = mon + OFF_SECURE + SUB0[pid % 24] * SUB_STRIDE
  local sp = F.r16(sub) & 0x7FF
  xorSecure(mon)
  return sp
end

local function writeSpecies(mon, species)
  xorSecure(mon)
  local pid = F.r32(mon)
  local sub = mon + OFF_SECURE + SUB0[pid % 24] * SUB_STRIDE
  local w = F.r16(sub)
  F.w16(sub, (w & 0xF800) | (species & 0x7FF))
  F.w16(mon + OFF_CHECKSUM, checksumDecrypted(mon))
  xorSecure(mon)
end

local function tohjoVar()
  return F.r16(F.sb3() + S.SaveBlock3.regionVars + (VAR_TOHJO - REGION_VARS_START) * 2)
end

local function tohjoVarSet(v)
  F.w16(F.sb3() + S.SaveBlock3.regionVars + (VAR_TOHJO - REGION_VARS_START) * 2, v)
end

local function obj(localId)
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == localId then
      return {
        i = i, b = b,
        x = F.rs16(b + S.ObjectEvent.x) - 7,
        y = F.rs16(b + S.ObjectEvent.y) - 7,
        gfx = F.r16(b + S.ObjectEvent.graphicsId),
        invisible = (F.r8(b + S.ObjectEvent.flags1) & 0x20) ~= 0,
      }
    end
  end
  return nil
end

local function describeFol(o)
  if not o then return "ABSENT" end
  return string.format("(%d,%d) gfx=0x%04X sp=%d %s", o.x, o.y, o.gfx,
    o.gfx & SPECIES_MASK, o.invisible and "invisible" or "visible")
end

local function ensureFollowerOut(tag)
  local o = obj(FOLLOWER)
  if o and not o.invisible then return true end
  for _, dir in ipairs({ "Left", "Right", "Down", "Up" }) do
    F.step(dir); F.idle(20)
    o = obj(FOLLOWER)
    if o and not o.invisible then
      F.L(string.format("  follower out via %s: %s", dir, describeFol(o)))
      return true
    end
  end
  F.L("  follower still hidden after steps (" .. tag .. "): " .. describeFol(o))
  return o ~= nil and not o.invisible
end

local function dumpGate(tag)
  local mon = slot0()
  local sp, hp, mx = readSpecies(mon), F.r16(mon + OFF_HP), F.r16(mon + OFF_MAXHP)
  local o = obj(FOLLOWER)
  local flags1 = o and F.r8(o.b + S.ObjectEvent.flags1) or 0
  F.L(string.format("  gate[%s] species=%d hp=%d/%d VAR=%d fol=%s",
    tag, sp, hp, mx, tohjoVar(), describeFol(o)))
  return sp, hp, mx, o, flags1
end

local function showFollower(o)
  if not o then return false end
  F.w8(o.b + S.ObjectEvent.flags1, F.r8(o.b + S.ObjectEvent.flags1) & ~0x20)
  return not ((F.r8(o.b + S.ObjectEvent.flags1) & 0x20) ~= 0)
end

local function scriptPtr()
  return F.r32(S.sGlobalScriptContext + CTX_SCRIPT)
end

local function sceneArmedScript()
  local p = scriptPtr()
  return p >= SCRIPT_RIGHT and p < SCRIPT_SCENE + 0x200
end

local function idleCrash(n, tag)
  for i = 1, n do
    F.idle(1)
    if i % 30 == 0 and F.reportCrash(tag) then return true end
  end
  return false
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  F.idle(60)
  F.check("player is free before the debug work", F.ensureFree())

  setParty()
  local n = F.r8(S.gPartiesCount)
  F.check("Set Party published a party", n ~= 0, "count=" .. n)
  F.check("a step is possible with the new party", F.step("Left"))
  F.idle(40)
  F.check("follower is on screen after one step",
    (function() local o = obj(FOLLOWER); return o ~= nil and not o.invisible end)(),
    describeFol(obj(FOLLOWER)))
  F.shot("follower_out")

  local mon = slot0()
  local sp0 = readSpecies(mon)
  F.check("decrypt reads the debug lead as Wobbuffet", sp0 == SPECIES_WOBBUFFET, "species=" .. sp0)
  dumpGate("wobbuffet")

  -- ---- negative: non-Celebi follower must NOT arm -----------------------------------------
  tohjoVarSet(0)
  if not go(GRP_GIO, MAP_GIO, WARP_GIO, "neg_noncelebi") then F.finish(); return end
  dumpGate("after_wobbuffet_warp")
  F.shot("neg_noncelebi")
  F.check("non-Celebi follower does not arm the Giovanni event", tohjoVar() == 0,
    "VAR_TOHJO=" .. tohjoVar())

  -- ---- negative: full-species Celebi at less than full HP must NOT arm --------------------
  ensureFollowerOut("before_faint")
  writeSpecies(mon, SPECIES_CELEBI)
  local spC = readSpecies(mon)
  F.check("slot 0 is now Celebi", spC == SPECIES_CELEBI, "species=" .. spC)
  local mx = F.r16(mon + OFF_MAXHP)
  if mx < 2 then mx = 2; F.w16(mon + OFF_MAXHP, mx) end
  F.w16(mon + OFF_HP, mx - 1)
  local o = obj(FOLLOWER)
  if o then F.w16(o.b + S.ObjectEvent.graphicsId, SPECIES_CELEBI + OBJ_EVENT_MON) end
  dumpGate("celebi_hurt")
  tohjoVarSet(0)
  if not go(GRP_GIO, MAP_GIO, WARP_GIO, "neg_hurt") then F.finish(); return end
  dumpGate("after_hurt_warp")
  F.shot("neg_hurt")
  F.check("hurt Celebi (HP < maxHP) does not arm the Giovanni event", tohjoVar() == 0,
    "VAR_TOHJO=" .. tohjoVar() .. " hp=" .. F.r16(mon + OFF_HP) .. "/" .. F.r16(mon + OFF_MAXHP))

  -- ---- positive: full-HP Celebi follower arms ---------------------------------------------
  ensureFollowerOut("before_full")
  writeSpecies(mon, SPECIES_CELEBI)
  mx = F.r16(mon + OFF_MAXHP)
  F.w16(mon + OFF_HP, mx)
  o = obj(FOLLOWER)
  if o then
    F.w16(o.b + S.ObjectEvent.graphicsId, SPECIES_CELEBI + OBJ_EVENT_MON)
    showFollower(o)
  end
  dumpGate("celebi_full")
  tohjoVarSet(0)
  if not go(GRP_GIO, MAP_GIO, WARP_GIO, "pos_full") then F.finish(); return end
  local spA, hpA, mxA, folA = dumpGate("after_full_warp")
  F.shot("pos_armed")
  local armed = tohjoVar() == 1
  F.check("full-HP Celebi follower arms VAR_TOHJO_FALLS_GIOVANNI_STATE=1 on arrival",
    armed, string.format("VAR=%d species=%d hp=%d/%d fol=%s", tohjoVar(), spA, hpA, mxA, describeFol(folA)))

  -- Walk the trigger. Warp lands on (5,8); (5,7) is GiovanniScene. Follower respawns
  -- invisible on the new map; emerge happens on the first free step. Reveal it first
  -- so CheckCelebi at the trigger does not CancelScene.
  folA = obj(FOLLOWER)
  if folA then showFollower(folA) end
  local x, y = F.pos()
  F.L(string.format("  arrived at (%d,%d) VAR=%d script=0x%08X status=%d",
    x, y, tohjoVar(), scriptPtr(), F.r8(CTX_STATUS)))
  F.face("Up")
  F.step("Up")
  idleCrash(90, "trigger")
  x, y = F.pos()
  local st = F.r8(CTX_STATUS)
  local sptr = scriptPtr()
  F.L(string.format("  after Up (%d,%d) VAR=%d script=0x%08X status=%d",
    x, y, tohjoVar(), sptr, st))
  F.shot("on_trigger")
  -- Arming is the claim. Cutscene start is extra confirmation.
  F.check("walking the trigger keeps the event armed (VAR stays 1, not CancelScene)",
    tohjoVar() ~= 0, "VAR_TOHJO=" .. tohjoVar())
  F.check("Giovanni scene script started or the armed var survived the trigger",
    sceneArmedScript() or tohjoVar() == 1,
    string.format("script=0x%08X status=%d VAR=%d", sptr, st, tohjoVar()))
  if sceneArmedScript() then F.shot("cutscene") end

  F.finish()
end)
