-- Secret bases in the red, brown and yellow caves, decorated, saved, left by HUB PASS and moved, with a
-- follower out the whole time. SecretBaseMoveStress covers the blue cave, the tree and the shrub.
--
-- With real input the suite makes a base in the Route 118 red cave, reads the PC's top menu (no
-- REGISTRY row: other players' bases came only from record mixing), places a SMALL DESK through the
-- PC's Decorate menu, saves inside, soft resets and continues. The desk must still be drawn and the
-- player must stand on the saved tile with control. It then leaves through a SELECT-registered HUB
-- PASS, comes back through the entrance it left open, and moves the base to the Route 114 brown cave
-- and the Route 111 yellow cave, ending with PACK UP. On every route visited, only the player's own
-- entrance may draw open: each other entrance must read the layout's own metatile.
-- Setup is the debug party, moves written with setmonmove, items and decorations given by script,
-- and debug warps onto the approach tiles; every talk, YES and menu choice is real input.
--
-- Run: test/overworld/mgba-run.sh test/overworld/lua/SecretBaseTerrains.lua [--env PW_SB_GENDER=1] [--env PW_SB_TEXT=3]

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SecretBaseTerrains")

local HUB = 100
local REGION_HOENN = 3
local MOVE_SECRET_POWER = 290
local ITEM_HUB_RETURN = 893
local DECOR_SMALL_DESK = 1
local SECRET_BASE_GROUP = 25
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local USM_ICO_PARTY, USM_ICO_SAVE = 1, 7
local SENTINEL = 0xFFFF
local OBJ_FOLLOWER = 0xFE
local MENU_MAX_CURSOR = 4
local FLAG_SYS_POKEMON_GET = 0x948

-- Entrances on each route (data/maps/*/map.json bg_events of type secret_base).
local ENTRANCES = {
  ["0.33"] = { { 47, 14 }, { 67, 6 }, { 29, 5 }, { 47, 5 }, { 46, 5 } },
  ["0.29"] = { { 9, 47 }, { 30, 51 }, { 11, 62 }, { 19, 70 }, { 11, 27 }, { 12, 27 }, { 32, 57 } },
  ["0.26"] = { { 24, 36 }, { 34, 50 }, { 33, 34 }, { 35, 1 }, { 35, 31 }, { 27, 27 }, { 14, 19 }, { 13, 19 } },
}

local BASES = {
  { tag = "red", group = 0, map = 33, ex = 47, ey = 14, base = 0, px = 1, py = 3,
    found = "DISCOVERED A SMALL CAVERN" },
  { tag = "brown", group = 0, map = 29, ex = 9, ey = 47, base = 1, px = 2, py = 3,
    found = "DISCOVERED A SMALL CAVERN", leaving = "NEAR ROUTE 118", partyFirst = true },
  { tag = "yellow", group = 0, map = 26, ex = 33, ey = 34, base = 3, px = 9, py = 3,
    found = "DISCOVERED A SMALL CAVERN", leaving = "NEAR ROUTE 114" },
}
local DESK_X, DESK_Y = 1, 5

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end

local SCRIPT_BUF = S.gStringVar4 + 960
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
  for _ = 1, 200 do F.idle(2); if F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN then break end end
  F.idle(4)
end

local function warpToCoords(grp, map, x, y, tag)
  for _ = 1, 4 do
    F.dbg(); F.sel(0); F.sel(1); F.idle(20)
    F.spin(d(grp)); F.spin(d(map))
    F.press("A", 2)
    for _ = 1, 400 do
      F.w8(S.sWarpDestination + 2, 0xFF)
      F.w16(S.sWarpDestination + 4, x)
      F.w16(S.sWarpDestination + 6, y)
      F.idle(1)
      local px, py = F.pos()
      if F.ow() and F.grp() == grp and F.mapn() == map and px == x and py == y then
        F.idle(120)
        return true
      end
    end
    F.bOut(5)
  end
  F.shot(tag .. "_warpfail")
  return false
end

local function metatileAt(x, y)
  local L = S.gBackupMapLayout
  local w = F.r32(L + S.BackupMapLayout.width)
  return F.r16(F.r32(L + S.BackupMapLayout.map) + 2 * ((x + 7) + (y + 7) * w)) & 0x3FF
end
-- The current layout's own block at (x, y): gMapHeader.mapLayout (+0) -> MapLayout {width, height,
-- border, map}. Route 111 swaps its layout on transition; setmaplayoutindex updates this pointer.
local function layoutMetatileAt(x, y)
  local layout = F.r32(S.gMapHeader)
  local w = F.r32(layout)
  return F.r16(F.r32(layout + 12) + 2 * (x + y * w)) & 0x3FF
end

-- Every entrance on this route except `mine` must draw as the layout draws it.
local function onlyMineOpen(tag, mine)
  local list = ENTRANCES[F.grp() .. "." .. F.mapn()]
  if not list then F.check(tag .. ": route has an entrance list", false, where()); return end
  local open = {}
  for _, e in ipairs(list) do
    if metatileAt(e[1], e[2]) ~= layoutMetatileAt(e[1], e[2]) then open[#open + 1] = string.format("(%d,%d)", e[1], e[2]) end
  end
  local want = mine and string.format("(%d,%d)", mine[1], mine[2]) or ""
  F.check(tag .. ": only the player's entrance draws open", table.concat(open, " ") == want,
    "open=" .. table.concat(open, " ") .. " want=" .. want)
end

-- gStringVar4 as uppercase ASCII; Gen 3 A = 0xBB, a = 0xD5.
local function message()
  local s = {}
  for i = 0, 300 do
    local c = F.r8(S.gStringVar4 + i)
    if c == 0xFF then break end
    if c >= 0xBB and c <= 0xD4 then s[#s + 1] = string.char(65 + c - 0xBB)
    elseif c >= 0xD5 and c <= 0xEE then s[#s + 1] = string.char(65 + c - 0xD5)
    elseif c >= 0xA1 and c <= 0xAA then s[#s + 1] = string.char(48 + c - 0xA1)
    else s[#s + 1] = " " end
  end
  return (table.concat(s):gsub("%s+", " "))
end

local function taskUp(fn) return F.taskLive(fn) end
local function scriptMenuUp() return taskUp(S.Task_HandleYesNoInput) or taskUp(S.Task_HandleMultichoiceInput) end

-- Talk, answer YES to every prompt, and read each message until the script lets go.
local function talkYes(tag)
  F.press("A", 2); F.idle(30)
  local seen = {}
  for _ = 1, 500 do
    if F.reportCrash(tag) then break end
    local m = message()
    if seen[#seen] ~= m then seen[#seen + 1] = m end
    if scriptMenuUp() then
      F.idle(16)
      for _ = 1, 4 do if F.mcur() == 0 then break end; F.press("Up", 2); F.idle(10) end
      F.press("A", 2); F.idle(30)
    elseif hasControl() and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN then
      F.idle(20); if hasControl() then break end
    else
      F.press("A", 2); F.idle(14)
    end
  end
  return table.concat(seen, " | ")
end

-- A field Yes/No that no script owns (the HUB PASS confirm rests on NO): probe the sMenu cursor with
-- Down/Up until it moves, then drive it to `want` (0 YES, 1 NO). A before the box is up pages text.
local function yesNo(want, tag)
  for _ = 1, 24 do
    if F.reportCrash("yesno_" .. tag) then return false end
    local c0 = F.mcur()
    F.press("Down", 2); F.idle(12)
    local live = F.mcur() ~= c0
    if not live then c0 = F.mcur(); F.press("Up", 2); F.idle(12); live = F.mcur() ~= c0 end
    if live then
      for _ = 1, 6 do
        if F.mcur() == want then F.press("A", 2); F.idle(60); return true end
        F.press(F.mcur() > want and "Up" or "Down", 2); F.idle(12)
      end
      return false
    end
    F.press("A", 2); F.idle(35)
  end
  return false
end

local function objByLocal(id)
  for i = 0, 15 do
    local o = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(o) & 1) ~= 0 and F.r8(o + S.ObjectEvent.localId) == id then return o end
  end
end
local function follower()
  local o = objByLocal(OBJ_FOLLOWER)
  if not o then return nil end
  return { x = F.rs16(o + S.ObjectEvent.x) - 7, y = F.rs16(o + S.ObjectEvent.y) - 7,
           shown = (F.r8(o + S.ObjectEvent.flags1) & 0x20) == 0 }
end
local function followerBeside(tag)
  local px, py = F.pos()
  local f = follower()
  local ok = f and f.shown and math.abs(f.x - px) + math.abs(f.y - py) == 1
  F.check(tag .. ": the follower stands beside the player", ok,
    f and string.format("follower (%d,%d) %s, player (%d,%d)", f.x, f.y, f.shown and "shown" or "hidden", px, py) or "no follower")
end

local function decorCount(category)
  local inv = S.gDecorationInventories + category * 8
  local items, size = F.r32(inv), F.r8(inv + 4)
  local n = 0
  for i = 0, size - 1 do if F.r8(items + i) ~= 0 then n = n + 1 end end
  return n
end

local function driveSave()
  F.w16(S.gSaveAttemptStatus, SENTINEL)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_SAVE) then return "noicon" end
  for i = 1, 3000 do
    if F.r16(S.gSaveAttemptStatus) ~= SENTINEL then
      F.idle(30)
      for _ = 1, 6 do F.press("B", 2); F.idle(20) end
      return F.r16(S.gSaveAttemptStatus) == 1 and "done" or "failed"
    end
    if i % 20 == 1 then joypad.set({ A = true }) else joypad.set({}) end
    emu.frameadvance()
  end
  return "timeout"
end

local function softReset()
  for _ = 1, 8 do joypad.set({ A = true, B = true, Start = true, Select = true }); emu.frameadvance() end
  joypad.set({})
end

local function awaitControl(budget)
  for i = 1, budget or 600 do
    if hasControl() then return true end
    if i % 30 == 0 then F.press("B", 2) else F.idle(1) end
  end
  return hasControl()
end

-- Open the PC in front of the player and wait for its top multichoice.
local function openPc(tag)
  F.face("Up")
  F.press("A", 2); F.idle(20)
  for _ = 1, 40 do
    if taskUp(S.Task_HandleMultichoiceInput) then F.idle(20); return true end
    F.press("A", 2); F.idle(30)
  end
  F.shot(tag .. "_nopc")
  return false
end
local function closeMenus(tag)
  for _ = 1, 20 do
    if hasControl() and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN then break end
    F.press("B", 2); F.idle(30)
  end
  F.check(tag .. ": control returns after backing out of the PC", hasControl(), where())
end

-- PC > DECORATION > DECORATE > DESK > SMALL DESK, cursor two tiles down, A, YES.
local function placeDesk(tag)
  if not openPc(tag) then return false end
  F.press("A", 2); F.idle(60)
  F.shot(tag .. "_decor_actions")
  F.press("A", 2); F.idle(60)
  F.shot(tag .. "_decor_categories")
  F.press("A", 2); F.idle(60)
  F.shot(tag .. "_decor_desks")
  F.press("A", 2); F.idle(120)
  for _ = 1, 2 do F.press("Down", 2); F.idle(20) end
  F.shot(tag .. "_cursor")
  F.press("A", 2); F.idle(40)
  for _ = 1, 30 do if taskUp(S.Task_HandleYesNoInput) then break end; F.idle(10) end
  F.shot(tag .. "_place_prompt")
  F.press("A", 2); F.idle(200)
  for _ = 1, 10 do F.press("A", 2); F.idle(30) end
  F.shot(tag .. "_placed")
  closeMenus(tag)
  return true
end

local function inPartyMenu()
  local c = F.cb2()
  return c == S.CB2_UpdatePartyMenu or c == S.CB2_InitPartyMenu or c == S.CB2_PartyMenuFromStartMenu
end

-- Start > PARTY > lead > SECRET POWER (row 1: the debug lead knows no other field move). Returns
-- whether the party menu closed into the field move rather than staying open on a refusal.
local function partySecretPower(tag)
  awaitControl(300)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_PARTY) then F.shot(tag .. "_noparty"); return false end
  F.press("A", 3)
  for _ = 1, 240 do F.idle(4); if inPartyMenu() then break end end
  F.idle(40)
  F.press("A", 3); F.idle(50)
  F.press("Down", 2); F.idle(12)
  F.shot(tag .. "_actions")
  F.press("A", 3)
  for _ = 1, 120 do F.idle(4); if not inPartyMenu() then return true end end
  F.shot(tag .. "_refused")
  for _ = 1, 20 do
    if not inPartyMenu() and hasControl() then break end
    F.press("B", 2); F.idle(30)
  end
  return false
end

-- Read every message of a script already running (no opening A: with control back, A would talk to
-- the entrance and start the other path), answering YES.
local function followScript(tag)
  for _ = 1, 120 do if F.r8(S.sGlobalScriptContextStatus) == CONTEXT_RUNNING or not hasControl() then break end; F.idle(2) end
  local seen = {}
  for _ = 1, 500 do
    if F.reportCrash(tag) then break end
    local m = message()
    if seen[#seen] ~= m then seen[#seen + 1] = m end
    if scriptMenuUp() then
      F.idle(16)
      for _ = 1, 4 do if F.mcur() == 0 then break end; F.press("Up", 2); F.idle(10) end
      F.press("A", 2); F.idle(30)
    elseif hasControl() and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN then
      F.idle(20); if hasControl() then break end
    else
      F.press("A", 2); F.idle(14)
    end
  end
  return table.concat(seen, " | ")
end

-- Walk out through the base's exit, the south arrow warp at (5,7): the saved dynamic warp must put the player back on the
-- approach tile below the entrance.
local function walkOut(sp, tag)
  F.route({ { 5, 3 }, { 5, 6 } }, tag .. "_to_exit")
  F.step("Down")
  F.press("Down", 20)                         -- the exit is a south arrow warp
  for i = 1, 600 do
    if F.ow() and F.grp() == sp.group and F.mapn() == sp.map then break end
    if i % 15 == 0 then F.press("B", 2) else F.idle(4) end
  end
  local ok = awaitControl(900)
  F.idle(30)
  local x, y = F.pos()
  F.check(tag .. ": the exit leads back below the entrance",
    ok and F.grp() == sp.group and F.mapn() == sp.map and x == sp.ex and y == sp.ey + 1, where())
  return ok and F.grp() == sp.group and F.mapn() == sp.map
end

local function enterBase(sp, tag)
  if not F.check(tag .. ": reach the entrance", warpToCoords(sp.group, sp.map, sp.ex, sp.ey + 1, tag)) then return nil end
  F.face("Up")
  if sp.partyFirst then
    -- With a base already made, the party menu's SECRET POWER is refused (SetUpFieldMove_SecretPower).
    F.check(tag .. ": party-menu SECRET POWER is refused while a base exists", not partySecretPower(tag .. "_party"), where())
    F.check(tag .. ": control and the route after the refusal", awaitControl(600) and F.grp() == sp.group and F.mapn() == sp.map, where())
    F.face("Up")
  end
  local text = talkYes(tag)
  F.L("  " .. tag .. ": " .. text)
  F.idle(60)
  return text
end

F.run(function()
  if not F.boot(HUB) then F.check("boot", false); F.finish(); return end
  F.dbg(); F.sel(2); F.sel(9); F.idle(120); F.bOut(3)    -- Party > Set Party: the debug team, lead out as follower
  F.w8(F.sb2() + S.SaveBlock2.currentRegion, REGION_HOENN)
  -- PW_SB_GENDER=1 plays May (her decorating sprite); PW_SB_TEXT=<0..3> sets the text speed.
  if os.getenv("PW_SB_GENDER") == "1" then F.w8(F.sb2() + S.SaveBlock2.playerGender, 1) end
  local speed = tonumber(os.getenv("PW_SB_TEXT") or "")
  if speed then F.w8(F.sb2() + S.SaveBlock2.optionsU16, (F.r8(F.sb2() + S.SaveBlock2.optionsU16) & ~7) | speed) end
  F.w32(S.gCurrentRegion, REGION_HOENN)
  runScript({ 0x7B, 0, 3, MOVE_SECRET_POWER & 0xFF, MOVE_SECRET_POWER >> 8, 0x02 })            -- setmonmove 0, 3
  runScript({ 0x44, ITEM_HUB_RETURN & 0xFF, ITEM_HUB_RETURN >> 8, 1, 0, 0x02 })                -- additem
  runScript({ 0x4B, DECOR_SMALL_DESK, 0, 0x02 })                                                 -- adddecoration
  local fa = F.sb1() + S.SaveBlock1.flags + FLAG_SYS_POKEMON_GET // 8
  F.w8(fa, F.r8(fa) | (1 << (FLAG_SYS_POKEMON_GET % 8)))                                         -- the PARTY icon
  F.check("setup: one SMALL DESK in the PC", decorCount(0) == 1, "desks=" .. decorCount(0))

  local red = BASES[1]
  if not F.check("red: reach the entrance", warpToCoords(red.group, red.map, red.ex, red.ey + 1, "red")) then F.finish(); return end
  F.face("Up")
  F.check("red: SECRET POWER from the party menu starts the field move", partySecretPower("red_party"), where())
  local text = followScript("red")
  F.L("  red: " .. text)
  F.idle(60)
  F.shot("red_inside")
  F.check("red: Secret Power opens it", text:find(red.found) ~= nil, text)
  local x, y = F.pos()
  F.check("red: land in the red cave base in front of its PC",
    F.grp() == SECRET_BASE_GROUP and F.mapn() == red.base and x == red.px and y == red.py, where())

  if openPc("red_pc") then
    F.shot("red_pc_menu")
    local rows = F.r8(S.sMenu + MENU_MAX_CURSOR) + 1
    F.check("red: the base PC offers DECORATION, PACK UP and TURN OFF only", rows == 3, "rows=" .. rows)
    closeMenus("red_pc")
  end

  local before = layoutMetatileAt(DESK_X, DESK_Y)
  placeDesk("red_desk")
  local desk = metatileAt(DESK_X, DESK_Y)
  F.check("red: the SMALL DESK is drawn where it was placed", desk ~= before,
    string.format("metatile 0x%03X, layout 0x%03X", desk, before))
  F.check("red: control after decorating", awaitControl(600), where())
  F.step("Down"); F.step("Up")
  followerBeside("red after decorating")

  local sx, sy = F.pos()
  F.check("red: save inside the base", driveSave() == "done")
  softReset()
  F.idle(60)
  F.check("red: continued to the field", F.boot(nil, true))
  F.idle(30)
  local cx, cy = F.pos()
  F.check("red: continue in the base on the saved tile",
    F.grp() == SECRET_BASE_GROUP and F.mapn() == red.base and cx == sx and cy == sy, where())
  F.check("red: the desk is drawn after Continue", metatileAt(DESK_X, DESK_Y) == desk,
    string.format("metatile 0x%03X want 0x%03X", metatileAt(DESK_X, DESK_Y), desk))
  F.check("red: control after Continue", awaitControl(600), where())
  F.shot("red_continued")
  F.check("red: the player can walk after Continue", F.step("Down") and F.step("Up"), where())
  followerBeside("red after Continue")
  if walkOut(red, "red_after_continue") then
    local moved = F.step("Left")             -- (47,16) below the approach tile is a ledge wall
    F.check("red: the player can walk outside after Continue", moved, where())
    followerBeside("red outside after Continue")
    if moved then F.step("Right") end
    F.face("Up")
    talkYes("red_back_in")
    F.idle(60)
    F.check("red: back inside through the entrance", F.grp() == SECRET_BASE_GROUP and F.mapn() == red.base, where())
    awaitControl(600)
  end

  F.check("red: the HUB PASS is in the bag", F.itemCount(ITEM_HUB_RETURN) == 1)
  F.w16(F.sb1() + S.SaveBlock1.registeredItem, ITEM_HUB_RETURN)
  F.press("Select", 2); F.idle(90)
  F.shot("red_hubpass_select")
  F.check("red: the HUB PASS asks to confirm", yesNo(0, "hubpass"), where())
  for i = 1, 600 do
    if F.ow() and F.grp() == HUB then break end
    if i % 10 == 0 then F.press("B", 2) else F.idle(4) end
  end
  F.check("red: the HUB PASS leaves the base for the hub", F.grp() == HUB, where())
  F.check("red: control in the hub", awaitControl(900), where())

  if F.check("red: back on Route 118", warpToCoords(red.group, red.map, red.ex, red.ey + 1, "red_back")) then
    onlyMineOpen("Route 118 with the base", { red.ex, red.ey })
    F.face("Up")
    talkYes("red_reenter")
    F.idle(60)
    F.shot("red_reentered")
    F.check("red: the open entrance leads into the player's base", F.grp() == SECRET_BASE_GROUP and F.mapn() == red.base, where())
    F.check("red: the desk is still there", metatileAt(DESK_X, DESK_Y) == desk,
      string.format("metatile 0x%03X want 0x%03X", metatileAt(DESK_X, DESK_Y), desk))
    F.check("red: control inside", awaitControl(600), where())
  end

  for i = 2, 3 do
    local sp = BASES[i]
    local t = enterBase(sp, sp.tag)
    if not t then break end
    F.shot(sp.tag .. "_inside")
    F.check(sp.tag .. ": Secret Power opens it", t:find(sp.found) ~= nil, t)
    F.check(sp.tag .. ": the move names the base being left", t:find(sp.leaving) ~= nil, t)
    local bx, by = F.pos()
    F.check(sp.tag .. ": land in the new base in front of its PC",
      F.grp() == SECRET_BASE_GROUP and F.mapn() == sp.base and bx == sp.px and by == sp.py, where())
    F.check(sp.tag .. ": the desk went back to the PC", decorCount(0) == 1, "desks=" .. decorCount(0))
    if openPc(sp.tag .. "_pc") then
      local rows = F.r8(S.sMenu + MENU_MAX_CURSOR) + 1
      F.check(sp.tag .. ": the PC still offers three rows", rows == 3, "rows=" .. rows)
      closeMenus(sp.tag .. "_pc")
    end
    F.step("Down"); F.step("Up")
    followerBeside(sp.tag .. " inside after a step")
    if walkOut(sp, sp.tag .. "_out") then
      onlyMineOpen(sp.tag .. " route with the base", { sp.ex, sp.ey })
    end
  end

  if F.check("Route 118 after the move", warpToCoords(0, 33, 47, 15, "red_after")) then
    onlyMineOpen("Route 118 after the move", nil)
  end
  if F.check("Route 114 after the move", warpToCoords(0, 29, 9, 48, "brown_after")) then
    onlyMineOpen("Route 114 after the move", nil)
  end

  local yellow = BASES[3]
  if F.check("yellow: back at the entrance", warpToCoords(yellow.group, yellow.map, yellow.ex, yellow.ey + 1, "yellow_back")) then
    F.face("Up")
    talkYes("yellow_reenter")
    F.idle(60)
    if F.check("yellow: in the base again", F.grp() == SECRET_BASE_GROUP and F.mapn() == yellow.base, where()) then
      F.route({ { 5, 3 }, { yellow.px, yellow.py } }, "yellow_to_pc")
      if openPc("yellow_pack") then
        F.press("Down", 2); F.idle(12)
        F.press("A", 2); F.idle(40)
        local packed = talkYes("yellow_pack")
        F.L("  pack up: " .. packed)
        for _ = 1, 600 do if F.ow() and F.grp() == yellow.group and F.mapn() == yellow.map then break end; F.idle(4) end
        F.idle(60)
        F.shot("yellow_packed")
        F.check("yellow: PACK UP returns the player to Route 111", F.grp() == yellow.group and F.mapn() == yellow.map, where())
        F.check("yellow: control after PACK UP", awaitControl(900), where())
        onlyMineOpen("Route 111 after PACK UP", nil)
      end
    end
  end

  F.check("no crash", not F.crashScreen())
  F.finish()
end)
