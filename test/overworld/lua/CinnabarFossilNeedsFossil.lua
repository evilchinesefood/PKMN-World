-- The Cinnabar Lab revives only a fossil the player still carries.
--
-- I_KEY_FOSSILS is GEN_LATEST here, so the Helix Fossil, Dome Fossil and Old Amber are ordinary
-- Items-pocket goods: a mart buys them, and the Ruins of Alph lab revives them too (it checks the
-- bag). The Cinnabar scientist came from pokefirered unchanged and decided what to offer from the
-- "got it" flags Mt. Moon and the Pewter Museum set, so a fossil already sold or already revived in
-- Johto was still offered, `removeitem` failed silently, and the Pokemon came back anyway.
--
-- The game's own scripts leave the state: Mt. Moon sets FLAG_GOT_HELIX_FOSSIL and puts the fossil in
-- the bag. The suite reproduces that with an injected `setflag` + `additem`, sells the fossil at the
-- Cinnabar Mart with real input, then asks the scientist with real input. Oracle: the fossil is gone,
-- no revival starts (FLAG_REVIVED_HELIX clear, revive state 0) and the party stays empty after the
-- leave-and-return that would hand over the Omanyte. A control keeps a second fossil (Old Amber)
-- in the bag and must still be offered, revived and handed over.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "CinnabarFossilNeedsFossil")

local CINNABAR_G, ENTRANCE_M, EXPERIMENT_M, MART_M = 46, 1, 4, 7
local ITEM_HELIX_FOSSIL, ITEM_OLD_AMBER = 165, 167
local KANTO_FLAGS = 0xA40                            -- flags.h maps each flags_frlg.h id to 0xA40 + id
local FLAG_GOT_OLD_AMBER, FLAG_GOT_HELIX_FOSSIL = KANTO_FLAGS + 0x25E, KANTO_FLAGS + 0x273
local FLAG_GOT_FOSSIL_FROM_MT_MOON = KANTO_FLAGS + 0x232
local FLAG_REVIVED_HELIX, FLAG_REVIVED_AMBER = KANTO_FLAGS + 0x2ED, KANTO_FLAGS + 0x2EE
local LOCALID_SCIENTIST = 2
local VAR_REVIVE_STATE = 0xA043                     -- VAR_KANTO_SLICE(0x43), in SaveBlock3.regionVars
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function flagSet(id) return (F.r8(F.sb1() + S.SaveBlock1.flags + (id // 8)) & (1 << (id % 8))) ~= 0 end
local function var(id) return F.r16(S.gSaveblock3 + S.SaveBlock3.regionVars + (id - 0xA000) * 2) end
local function partyCount() return F.r8(S.gPartiesCount) end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end

local SCRIPT_BUF = S.gStringVar4 + 960
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
  for _ = 1, 200 do F.idle(4); if hasControl() then break end end
  F.idle(30)
end
local function lo(v) return v & 0xFF end
local function hi(v) return v >> 8 end
local function gotFossil(flag, item)
  runScript({ 0x29, lo(flag), hi(flag), 0x44, lo(item), hi(item), 1, 0, 0x02 })
end

local function settle(tag)
  for i = 1, 900 do
    if F.reportCrash(tag) then return false end
    if hasControl() then F.idle(30); if hasControl() then return true end end
    if i % 15 == 0 then F.press("B", 2) else F.idle(1) end
  end
  F.shot(tag .. "_stuck")
  return false
end
local function mash(btn, n, gap) for _ = 1, n do F.press(btn, 2); F.idle(gap or 30) end end
local function talkThrough(tag, n)
  for i = 1, n do
    if hasControl() then break end
    F.idle(20)
    if i <= 8 then F.shot(string.format("%s_t%d", tag, i)) end
    if not F.ow() then
      F.press("Start", 2); F.idle(20); F.press("A", 2); F.idle(90)   -- a nickname screen: keep the name
    else
      F.press("A", 2); F.idle(25)
    end
  end
end

local function sellFirstItem(tag)
  F.check(tag .. ": reach the clerk", F.route({ { 4, 5 }, { 4, 3 } }, tag .. "_walk"), where())
  F.face("Left")
  F.press("A", 2); F.idle(60)
  F.press("A", 2); F.idle(60)
  F.shot(tag .. "_menu")
  F.press("Down", 2); F.idle(20)
  F.press("A", 2); F.idle(120)
  F.shot(tag .. "_bag")
  F.press("A", 2); F.idle(60)
  F.shot(tag .. "_qty")
  F.press("A", 2); F.idle(60)
  F.shot(tag .. "_offer")
  mash("A", 4, 40)
  F.shot(tag .. "_sold")
  for _ = 1, 40 do
    if F.ow() and hasControl() then break end
    F.press("B", 2); F.idle(30)
  end
  settle(tag .. "_leave")
end

-- The scientist wanders one tile around (12,3), so a blocked step waits for him to move on.
local function walk(path, tag)
  local i = 1
  for _ = 1, 12 do
    while i <= #path and F.leg(path[i][1], path[i][2]) do i = i + 1 end
    if i > #path then return true end
    F.idle(40)
  end
  F.shot(tag .. "_stuck")
  return false
end

local function askScientist(tag)
  local px, py = F.pos()
  local path = (py == 4 and px >= 10) and { { 12, 4 } } or { { 7, 7 }, { 10, 7 }, { 10, 4 }, { 12, 4 } }
  F.check(tag .. ": walk to the scientist", walk(path, tag .. "_walk"), where())
  for _ = 1, 120 do
    local dir
    for i = 0, 15 do
      local b = S.gObjectEvents + i * S.ObjectEvent.stride
      if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == LOCALID_SCIENTIST then
        local x, y = F.rs16(b + S.ObjectEvent.x) - 7, F.rs16(b + S.ObjectEvent.y) - 7
        if x == 12 and y == 3 then dir = "Up" elseif x == 11 and y == 4 then dir = "Left" elseif x == 13 and y == 4 then dir = "Right" end
      end
    end
    if dir then
      F.face(dir)
      F.press("A", 2); F.idle(30)
      if not hasControl() then return true end
    else
      F.idle(30)
    end
  end
  F.check(tag .. ": the scientist answers", false, where())
  return false
end
local function leaveAndReturn(tag)
  F.check(tag .. ": walk to the door", walk({ { 10, 4 }, { 10, 7 }, { 7, 7 }, { 7, 8 } }, tag .. "_door"), where())
  F.step("Down")
  for _ = 1, 4 do
    if F.mapn() == ENTRANCE_M then break end
    F.press("Down", 8); F.idle(60)
  end
  for _ = 1, 300 do if F.ow() and F.mapn() == ENTRANCE_M then break end F.idle(2) end
  F.idle(60)
  F.check(tag .. ": in the lab entrance", F.grp() == CINNABAR_G and F.mapn() == ENTRANCE_M, where())
  F.step("Up")
  for _ = 1, 300 do if F.ow() and F.mapn() == EXPERIMENT_M then break end F.idle(2) end
  F.idle(60)
  F.check(tag .. ": back in the experiment room", F.grp() == CINNABAR_G and F.mapn() == EXPERIMENT_M, where())
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  instantText()
  F.check("warp to the Cinnabar Mart", F.warpTo(0, 4, 6, 0, 0, 7, 0, 0, 0, CINNABAR_G, MART_M, "mart"))
  instantText()
  gotFossil(FLAG_GOT_HELIX_FOSSIL, ITEM_HELIX_FOSSIL)
  runScript({ 0x29, lo(FLAG_GOT_FOSSIL_FROM_MT_MOON), hi(FLAG_GOT_FOSSIL_FROM_MT_MOON), 0x02 })
  F.check("setup: Mt. Moon's Helix Fossil is in the bag", F.itemCount(ITEM_HELIX_FOSSIL) == 1 and flagSet(FLAG_GOT_HELIX_FOSSIL))
  local money0 = F.money()
  sellFirstItem("sell")
  F.check("the Helix Fossil was sold", F.itemCount(ITEM_HELIX_FOSSIL) == 0 and F.money() > money0,
    string.format("slots=%d money %d -> %d", F.itemCount(ITEM_HELIX_FOSSIL), money0, F.money()))

  F.check("warp to the experiment room", F.warpTo(0, 4, 6, 0, 0, 4, 0, 0, 0, CINNABAR_G, EXPERIMENT_M, "lab"))
  instantText()
  local party0 = partyCount()
  askScientist("sold")
  talkThrough("sold", 12)
  settle("sold_talk")
  F.check("sold: no revival starts without the fossil", var(VAR_REVIVE_STATE) == 0,
    string.format("revive state %d", var(VAR_REVIVE_STATE)))
  leaveAndReturn("sold")
  askScientist("sold_again")
  talkThrough("sold_again", 12)
  settle("sold_again_talk")
  F.shot("sold_after")
  F.check("sold: no Omanyte for a fossil the player no longer has", partyCount() == party0 and not flagSet(FLAG_REVIVED_HELIX),
    string.format("party %d -> %d, revived=%s", party0, partyCount(), tostring(flagSet(FLAG_REVIVED_HELIX))))
  F.check("sold: the scientist is free for another fossil", var(VAR_REVIVE_STATE) == 0, string.format("revive state %d", var(VAR_REVIVE_STATE)))

  gotFossil(FLAG_GOT_OLD_AMBER, ITEM_OLD_AMBER)
  local party1 = partyCount()
  askScientist("amber")
  talkThrough("amber", 14)
  settle("amber_talk")
  F.check("control: the Old Amber in the bag is taken for revival",
    F.itemCount(ITEM_OLD_AMBER) == 0 and var(VAR_REVIVE_STATE) == 1,
    string.format("amber slots=%d revive state %d", F.itemCount(ITEM_OLD_AMBER), var(VAR_REVIVE_STATE)))
  leaveAndReturn("amber")
  askScientist("amber_collect")
  talkThrough("amber_collect", 10)
  settle("amber_collect_talk")
  F.check("control: Aerodactyl joins", partyCount() == party1 + 1 and flagSet(FLAG_REVIVED_AMBER) and var(VAR_REVIVE_STATE) == 0,
    string.format("party %d -> %d, revived=%s, revive state %d", party1, partyCount(), tostring(flagSet(FLAG_REVIVED_AMBER)), var(VAR_REVIVE_STATE)))
  F.finish()
end)
