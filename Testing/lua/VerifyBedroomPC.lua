-- VerifyBedroomPC.lua — issue #55's playtest checklist, all four bedroom PCs on one fresh new game.
--
-- 6d86b3c2 stopped the two non-Hoenn bedrooms (New Bark, Pallet) offering a DECORATION entry the
-- decoration system was never adapted to, by adding a THIRD top-menu table without it, selected on
-- gMapHeader.mapLayoutId. That shipped without ever being run in game, which is why #55 stayed open.
--
-- ★ WHY THE TABLE POINTER IS THE LOAD-BEARING ASSERTION, not the count. The new table and the
-- regular player-PC table have IDENTICAL contents AND an identical count — both are
-- {ITEMSTORAGE, MAILBOX, TURNOFF} (src/player_pc.c:202-224). So:
--   * PlayerPC_TurnOff (:518) MUST compare `sTopMenuOptionOrder != sPlayerPC_OptionOrder`; no count
--     can distinguish them, and getting this wrong sends a bedroom to the regular-PC branch, which
--     never runs the shutdown script.
--   * InitPlayerPCMenu (:423) MUST stay a ROW-COUNT test (`sTopMenuNumOptions > NUM_PLAYER_PC_OPTIONS`);
--     the two window templates differ in nothing but .height (6 vs 8, :252-269), so "which PC" is
--     the wrong question there and only "how many rows" is the right one.
-- The two tests genuinely go in opposite directions. This suite asserts both keys independently.
--
-- ★ Both Littleroot bedrooms are GENDER-GATED — Brendan's 2F is MALE-only and May's 2F FEMALE-only
-- (scripts.inc:236 and :282). One run covers all four by seeding SaveBlock2.playerGender.
--
-- ★ This suite originally asserted two New Bark bugs were PRESENT; both are fixed now (#57, which
-- #58 was folded into), so it asserts the fixed behaviour instead:
--   #57a New Bark's PC reused LittlerootTown_BrendansHouse_2F_EventScript_PC and inherited its
--        checkplayergender gate, so a FEMALE player could never open it. New Bark now has its own
--        ungated script pair and appears TWICE in the table below, once per gender.
--   #57b New Bark's PC tile (1,1) is metatile 648 with behaviour 0 = MB_NORMAL, and the map has no
--        MB_PC tile at all, so all three arms of IsPlayerInFrontOfPC failed and the screen never
--        animated. A fourth arm (IsPlayerHousePCTileJohto) plus PC_LOCATION_NEW_BARK now cycle it
--        648 <-> 650. The scriptPtr watch remains the independent shutdown evidence: a tileAt-only
--        "screen turned off" assert PASSES on a build where the shutdown script never ran, which is
--        the vacuous-green failure MANIFEST.md warns about and is exactly how New Bark used to look.
--
-- Run against a THROWAWAY COPY (lib.new refuses anything not Verify*/MigChk*/FixGen*):
--   cp <repo>\pokemonworld.gba  BizHawk\VerifyBedroomPC.gba
--   EmuHawk.exe BizHawk\VerifyBedroomPC.gba --lua=<repo>\Testing\lua\VerifyBedroomPC.lua
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(require("symbols"), "VerifyBedroomPC")

-- ---- constants (compiler-probed / read from the generated headers, never hand-counted) ---------
local MENU_ITEMSTORAGE, MENU_MAILBOX, MENU_DECORATION, MENU_TURNOFF = 0, 1, 2, 3
local MALE, FEMALE = 0, 1
local DECOR_MENU_ROWS = 4   -- DECORATE / PUT AWAY / TOSS / CANCEL (src/decoration.c:222)

-- Each bedroom: where it is, how to reach the PC, and what the menu must look like there.
-- Routes are BFS-verified against the map's own map.bin collision AND its object_events; a
-- collision-only path lies, because objects block movement too.
local BEDROOMS = {
  {
    name = "NewBark", gender = MALE,
    grp = 76, map = 4, warp = 1, layout = 796,
    -- warp 1 lands on (1,6), the middle tile of the bed, facing SOUTH. Warp 0 is a TRAP: from
    -- (9,2) every southward route crosses the coord_event clock triggers at (9,3)/(10,3), which
    -- hijack the run with a forced walk and the wall-clock UI.
    land = { 1, 6 },
    route = { { "Left", 0, 6 }, { "Up", 0, 5 }, { "Up", 0, 4 }, { "Up", 0, 3 },
              { "Right", 1, 3 }, { "Up", 1, 2 } },
    pc = { 1, 1 }, options = { MENU_ITEMSTORAGE, MENU_MAILBOX, MENU_TURNOFF },
    table_ = "sBedroomPC_NoDecorOptionOrder", winH = 6,
    offScript = "NewBarkTown_PlayersHouse_2F_EventScript_TurnOffPlayerPC",
  },
  {
    name = "Pallet", gender = MALE,
    grp = 38, map = 1, warp = 0, layout = 443,
    -- Row y=2 is broken at x=0 and x=8,9, so the warp corner is a separate alcove — no straight
    -- line to the PC. Do NOT continue west along y=4: (6,4) is the TV.
    land = { 10, 2 },
    route = { { "Down", 10, 3 }, { "Down", 10, 4 }, { "Left", 9, 4 }, { "Left", 8, 4 },
              { "Left", 7, 4 }, { "Up", 7, 3 }, { "Left", 6, 3 }, { "Left", 5, 3 },
              { "Left", 4, 3 }, { "Left", 3, 3 }, { "Left", 2, 3 }, { "Left", 1, 3 },
              { "Up", 1, 2 } },
    pc = { 1, 1 }, options = { MENU_ITEMSTORAGE, MENU_MAILBOX, MENU_TURNOFF },
    table_ = "sBedroomPC_NoDecorOptionOrder", winH = 6,
    offScript = "EventScript_PalletTown_PlayersHouse_2F_ShutDownPC",
  },
  {
    name = "Brendans", gender = MALE,
    grp = 1, map = 1, warp = 0, layout = 55,
    -- warp 0 is MB_NON_ANIMATED_DOOR, so the engine auto-steps the player off it to (7,2).
    land = { 7, 2 },
    route = { { "Left", 6, 2 }, { "Left", 5, 2 }, { "Left", 4, 2 }, { "Left", 3, 2 },
              { "Left", 2, 2 }, { "Left", 1, 2 }, { "Left", 0, 2 } },
    pc = { 0, 1 }, options = { MENU_ITEMSTORAGE, MENU_MAILBOX, MENU_DECORATION, MENU_TURNOFF },
    table_ = "sBedroomPC_OptionOrder", winH = 8,
    offScript = "LittlerootTown_BrendansHouse_2F_EventScript_TurnOffPlayerPC",
  },
  {
    name = "Mays", gender = FEMALE,
    grp = 1, map = 3, warp = 0, layout = 57,
    land = { 1, 2 },
    route = { { "Right", 2, 2 }, { "Right", 3, 2 }, { "Right", 4, 2 }, { "Right", 5, 2 },
              { "Right", 6, 2 }, { "Right", 7, 2 }, { "Right", 8, 2 } },
    pc = { 8, 1 }, options = { MENU_ITEMSTORAGE, MENU_MAILBOX, MENU_DECORATION, MENU_TURNOFF },
    table_ = "sBedroomPC_OptionOrder", winH = 8,
    offScript = "LittlerootTown_MaysHouse_2F_EventScript_TurnOffPlayerPC",
  },
  {
    -- Issue #57: New Bark is one map that is the player's own room for both genders, so the whole
    -- battery must pass on a FEMALE save too. Before the fix this phase could not even open the PC
    -- (it inherited Littleroot Brendan's checkplayergender gate), and had it opened, TURN OFF would
    -- have dispatched May's script and written a Hoenn metatile onto gTileset_PlayersHouse. Running
    -- the same table entry twice is what makes the gender independence assertable rather than
    -- asserted. Must not sit next to the MALE NewBark phase: warpTo's success test is group+map
    -- only, so a warp to the map you already stand on returns true having warped nobody.
    name = "NewBarkFemale", gender = FEMALE,
    grp = 76, map = 4, warp = 1, layout = 796,
    land = { 1, 6 },
    route = { { "Left", 0, 6 }, { "Up", 0, 5 }, { "Up", 0, 4 }, { "Up", 0, 3 },
              { "Right", 1, 3 }, { "Up", 1, 2 } },
    pc = { 1, 1 }, options = { MENU_ITEMSTORAGE, MENU_MAILBOX, MENU_TURNOFF },
    table_ = "sBedroomPC_NoDecorOptionOrder", winH = 6,
    offScript = "NewBarkTown_PlayersHouse_2F_EventScript_TurnOffPlayerPC",
  },
}

-- ---- accessors ---------------------------------------------------------------------------------
local OFF = S.BackupMapLayout.mapOffset

-- Live map grid; the grid carries the MAP_OFFSET border, so map coord (x,y) sits at (x+7, y+7).
local function tileAt(x, y)
  local w = F.r32(S.gBackupMapLayout + S.BackupMapLayout.width)
  local p = F.r32(S.gBackupMapLayout + S.BackupMapLayout.map)
  if p < 0x02000000 or w <= 0 then return -1 end
  return F.r16(p + 2 * ((x + OFF) + (y + OFF) * w)) & 0x3FF
end

local function numOptions() return F.r8(S.sTopMenuNumOptions) end
local function optionTable() return F.r32(S.sTopMenuOptionOrder) end
local function menuRows()    return F.rs8(S.sMenu + S.Menu.maxCursorPos) + 1 end
local function menuWinId()   return F.r8(S.sMenu + S.Menu.windowId) end
local function winHeight(id) return F.r8(S.gWindows + id * S.Window.stride + S.Window.height) end
local function winWidth(id)  return F.r8(S.gWindows + id * S.Window.stride + S.Window.width) end
local function scriptPtr()   return F.r32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr) end
local function layoutId()    return F.r16(S.gMapHeader + S.MapHeader.mapLayoutId) end

-- Read the live option list through the pointer the game is actually using.
local function optionIds(n)
  local p, t = optionTable(), {}
  if p < 0x08000000 then return t end
  for i = 0, n - 1 do t[#t + 1] = F.r8(p + i) end
  return t
end

local function eq(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do if a[i] ~= b[i] then return false end end
  return true
end

local function fmt(t) return "{" .. table.concat(t, ",") .. "}" end

-- ★ sMenu and sTopMenu* are STATICS and keep the previous menu's values. Same shape as the
-- documented sMartInfo trap: without poisoning, a phase where the PC silently never opened reports
-- the PREVIOUS phase's row count and passes. Poison, then wait for the game to overwrite it.
local POISON = 0x7F
local function poison()
  F.w8(S.sTopMenuNumOptions, 0)
  F.w32(S.sTopMenuOptionOrder, 0)
  F.w8(S.sMenu + S.Menu.maxCursorPos, POISON)
  F.w8(S.sMenu + S.Menu.windowId, 0xFF)
end

-- Open the PC. A fires the sign script; the script then runs DoPCTurnOnEffect + playse before
-- "<PLAYER> booted up the PC." (a MSGBOX_DEFAULT) even starts printing, so a SECOND A on a fixed
-- 60-frame delay is eaten — that is exactly how the first run of this suite failed, with the
-- screenshot showing the box still on screen and numOptions=0.
--
-- Press-then-poll instead: wait for the menu after every press and only press again once the wait
-- has expired. The check runs before each press and at 1-frame granularity, so a press cannot land
-- on a live menu and silently select ITEM STORAGE.
local function menuReady()
  return F.rs8(S.sMenu + S.Menu.maxCursorPos) ~= POISON and numOptions() > 0
end

local function openPC(tries)
  poison()
  for _ = 1, (tries or 6) do
    F.press("A", 2)
    for _ = 1, 120 do
      if menuReady() then F.idle(20); return true end
      F.idle(1)
    end
  end
  return false
end

-- Recover field control before a phase's warp. A phase that failed mid-script leaves the player
-- under `lockall` with a box open, and R+Start cannot open the debug menu there — which is why one
-- failed openPC cascaded into "never reached" for every later bedroom in the first run.
-- B only: next to an NPC or a sign an A re-opens what you are trying to close.
--
-- F.ow() is NOT the test — a msgbox is a task running on the overworld callback, so ow() stays
-- true with a box on screen. Drain unconditionally, then let ensureFree() (which probes by
-- stepping) be the actual proof of control; a step here is harmless, we are about to warp.
local function drainToField()
  for _ = 1, 30 do F.press("B", 3); F.idle(20) end
  local free = F.ensureFree()
  F.idle(30)
  return free
end

-- ★ Do NOT use F.pick / F.menuLive here. menuLive() presses Down to probe, and the 3-option menu
-- runs Menu_ProcessInputNoWrap (src/player_pc.c:442), which CLAMPS at maxCursorPos instead of
-- wrapping — so a cursor driven past row 0 can never come back. Drive it explicitly downward only,
-- reading sMenu.cursorPos, and never assume a starting row.
local function cursorTo(row, budget)
  for _ = 1, (budget or 10) do
    if F.mcur() == row then return true end
    F.press("Down", 2); F.idle(12)
  end
  return F.mcur() == row
end

-- ---- one bedroom -------------------------------------------------------------------------------
local function bedroom(b)
  local tag = b.name
  F.L(("== %s (group %d map %d, %s) =="):format(tag, b.grp, b.map,
      b.gender == MALE and "MALE" or "FEMALE"))

  -- Clear whatever the previous phase left on screen first. Without this one failed openPC leaves
  -- the player under `lockall` and every later warpTo reports "never reached".
  drainToField()

  -- Seed gender BEFORE the warp: both Littleroot PCs branch on it, and New Bark inherits that
  -- branch (#57).
  F.w8(F.sb2() + S.SaveBlock2.playerGender, b.gender)

  local d = function(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
  local gh, gt, go = d(b.grp)
  local mh, mt, mo = d(b.map)
  local wh, wt, wo = d(b.warp)
  if not F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, b.grp, b.map, tag) then
    F.check(tag .. "_warped", false, "never reached " .. tag); return
  end
  F.idle(120)

  -- Assert the ARRIVAL TILE, not warpTo's return: its success test is group+map only, so a false
  -- pass leaves the debug menu open and silently eats every step that follows.
  local x, y = F.pos()
  if not F.check(tag .. "_landed", x == b.land[1] and y == b.land[2],
      ("(%d,%d) want (%d,%d)"):format(x, y, b.land[1], b.land[2])) then return end
  F.check(tag .. "_layout", layoutId() == b.layout,
    ("mapLayoutId=%d want=%d"):format(layoutId(), b.layout))

  -- Walk the explicit waypoints. leg() is a greedy axis-first walk, not a pathfinder, and three of
  -- these four rooms have furniture a straight line runs into.
  for i, step in ipairs(b.route) do
    F.step(step[1]); F.idle(6)
    local px, py = F.pos()
    if px ~= step[2] or py ~= step[3] then
      F.check(("%s_route_step%d"):format(tag, i), false,
        ("at (%d,%d) after %s, want (%d,%d)"):format(px, py, step[1], step[2], step[3]))
      return
    end
  end
  F.face("Up")
  F.idle(20)

  local tileBefore = tileAt(b.pc[1], b.pc[2])
  if not F.check(tag .. "_pc_opened", openPC(),
      ("numOptions=%d rows=%d"):format(numOptions(), menuRows())) then
    F.shot(tag .. "_openfail"); return
  end
  local tileOpen = tileAt(b.pc[1], b.pc[2])

  -- ---- the checklist ----------------------------------------------------------------------
  local want = b.options
  local got = optionIds(numOptions())
  F.L(("  numOptions=%d rows=%d winId=%d winH=%d options=%s tile %d->%d"):format(
      numOptions(), menuRows(), menuWinId(), winHeight(menuWinId()), fmt(got), tileBefore, tileOpen))

  F.check(tag .. "_option_count", numOptions() == #want,
    ("%d want %d"):format(numOptions(), #want))
  -- The menu's own row count, independently of the variable that fed it.
  F.check(tag .. "_menu_rows", menuRows() == #want,
    ("sMenu rows=%d want %d"):format(menuRows(), #want))
  -- THE load-bearing one: which TABLE, not how many rows. See the header.
  F.check(tag .. "_option_table", optionTable() == S[b.table_],
    ("sTopMenuOptionOrder=0x%08X want %s=0x%08X"):format(optionTable(), b.table_, S[b.table_]))
  F.check(tag .. "_option_ids", eq(got, want), ("%s want %s"):format(fmt(got), fmt(want)))
  -- DECORATION present or absent, by id — the entry #55 is about.
  local hasDecor = false
  for _, v in ipairs(got) do if v == MENU_DECORATION then hasDecor = true end end
  local wantDecor = false
  for _, v in ipairs(want) do if v == MENU_DECORATION then wantDecor = true end end
  F.check(tag .. "_decoration_entry", hasDecor == wantDecor,
    ("DECORATION present=%s want=%s"):format(tostring(hasDecor), tostring(wantDecor)))
  -- The snug box. AddWindow copies the template verbatim, so gWindows[id].window.height IS the
  -- drawn frame; 2 tilemap rows per option is the invariant the fix rests on.
  local h = winHeight(menuWinId())
  F.check(tag .. "_window_height", h == b.winH and h == 2 * #want,
    ("height=%d want %d (=2*%d rows)"):format(h, b.winH, #want))
  F.shot(tag .. "_menu")

  -- ---- TURN OFF ------------------------------------------------------------------------------
  -- The one place the table-pointer key is observable from outside: PlayerPC_TurnOff only runs a
  -- shutdown script when sTopMenuOptionOrder is NOT sPlayerPC_OptionOrder. If that test were a
  -- count test, both bedrooms with 3 options would fall to ScriptContext_Enable() and no script
  -- would run at all — which is exactly what this watch would catch.
  local turnOffRow = #want - 1
  if F.check(tag .. "_turnoff_cursor", cursorTo(turnOffRow),
      ("cursor row %d of %d"):format(F.mcur(), #want)) then
    F.press("A", 2)
    local wantScript = S[b.offScript]
    local seen, sawPtr = false, 0
    for _ = 1, 240 do
      local p = scriptPtr()
      if p >= wantScript and p < wantScript + 64 then seen = true; sawPtr = p; break end
      F.idle(1)
    end
    F.check(tag .. "_turnoff_script", seen,
      seen and ("scriptPtr 0x%08X in %s"):format(sawPtr, b.offScript)
           or ("never entered %s (0x%08X); scriptPtr=0x%08X"):format(b.offScript, wantScript, scriptPtr()))
    F.idle(150)
    local tileAfter = tileAt(b.pc[1], b.pc[2])
    F.L(("  tile %d (before) -> %d (menu open) -> %d (after TURN OFF)"):format(
        tileBefore, tileOpen, tileAfter))
    -- All four bedrooms animate now that New Bark has its own detector (#57/#58); the tile must
    -- change while the PC is on and come back afterwards. The scriptPtr watch above stays the
    -- independent evidence — an "off" tile alone would also pass on a build that never ran the
    -- shutdown script, which is precisely how New Bark used to look correct.
    F.check(tag .. "_screen_on", tileOpen ~= tileBefore,
      ("tile %d -> %d while open"):format(tileBefore, tileOpen))
    F.check(tag .. "_screen_off", tileAfter == tileBefore,
      ("tile %d -> %d after TURN OFF"):format(tileOpen, tileAfter))
    F.shot(tag .. "_after")
  end

  -- ---- DECORATION opens (Littleroot only) — a SECOND, INDEPENDENT PC session ------------------
  -- Checklist (b) asks that placing a doll still works. The shipped change cannot reach placement
  -- itself — it only picks the top-menu table, the window height and the shutdown branch — so what
  -- is asserted is the boundary of the changed code: the entry is present and really enters
  -- DoPlayerRoomDecorationMenu. Full placement is a decoration-system test, not a #55 test, and is
  -- deliberately NOT claimed.
  --
  -- ★ This runs in its own PC session, AFTER turn-off, and that ordering is load-bearing. Doing it
  -- inside the first session broke the turn-off check: DecorationMenuAction_Cancel returns via
  -- ReshowPlayerPC (src/decoration.c:766), which re-prints the prompt and re-inits the menu, so a
  -- cursor read taken straight afterwards saw the DECORATION menu's stale CANCEL row (3) — the same
  -- row TURN OFF sits on — reported "cursor row 3 of 4", and the A that followed was eaten by the
  -- still-printing message. The screen then never turned off because TURN OFF was never chosen.
  if wantDecor then
    if not F.check(tag .. "_decor_reopened", openPC(),
        ("numOptions=%d rows=%d"):format(numOptions(), menuRows())) then return end
    -- ★ Rows alone CANNOT discriminate these two menus — the decoration menu is also 4 rows, and it
    -- reuses the same window id, which is why the first run's check passed vacuously at
    -- "rows=4 want 4, winId 1->1". The widths do differ: the PC menu is sized to "ITEM STORAGE",
    -- the decoration menu to "PUT AWAY". Both are logged so a vacuous pass stays visible.
    local pcW = winWidth(menuWinId())
    if F.check(tag .. "_decor_cursor", cursorTo(MENU_DECORATION), "cursor at DECORATION row") then
      F.press("A", 2); F.idle(150)
      local decorW = winWidth(menuWinId())
      F.L(("  window width: PC menu=%d, decoration menu=%d, rows=%d"):format(pcW, decorW, menuRows()))
      F.check(tag .. "_decor_menu_opened",
        menuRows() == DECOR_MENU_ROWS and decorW ~= pcW,
        ("rows=%d (want %d), width %d -> %d (must differ)"):format(
          menuRows(), DECOR_MENU_ROWS, pcW, decorW))
      F.shot(tag .. "_decor")
    end
    -- Leave via B; drainToField() at the next phase finishes the job.
    for _ = 1, 8 do F.press("B", 3); F.idle(25) end
  end
end

-- ---- main --------------------------------------------------------------------------------------
F.run(function()
  if not F.boot(100) then F.check("boot to overworld", false); F.finish(); return end
  F.check("booted to the RegionHub (map group 100)", F.grp() == 100, "grp=" .. F.grp())

  -- Order matters: warpTo's success test is group+map only, so no warp may target the map the
  -- player is already standing on. The list is ordered so no two consecutive phases share a map —
  -- in particular NewBarkFemale is last, reached from May's house, not from the MALE NewBark phase.
  for _, b in ipairs(BEDROOMS) do bedroom(b) end

  F.finish()
end)
