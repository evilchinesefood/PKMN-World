-- Leave a story event part way through, spend time in another region, and come back a different
-- way, so the campaign's own beats finish the event from wherever that leaves the player.
-- Loaded by a region campaign's beats.lua for PW_DETOUR=<event>:<exit>; see README.md, Excursions.
return function(F, N, C)
  local L = F.L
  local S = F.S
  local P = require('pwsym')
  local O = require('pwoff')
  local E = {}
  E.GATES = { kanto = 11, johto = 16, hoenn = 21 }
  local POCKET_ITEMS, POCKET_KEY = 0, 4
  local USM_ICO_BAG = 2

  local function partyPids()
    local t = {}
    for i = 0, N.partyCount() - 1 do t[#t + 1] = F.r32(P.gParties + i * O.mon_size) end
    return t
  end

  -- What a detour must not change: the team (by personality, in order), money, and the event's items.
  function E.snapshot(items)
    local s = { pids = partyPids(), money = N.money(), items = {} }
    for _, id in ipairs(items or {}) do s.items[id] = N.itemQty(id) end
    return s
  end

  function E.compare(tag, before, after)
    local same = #before.pids == #after.pids
    for i = 1, #before.pids do same = same and before.pids[i] == after.pids[i] end
    F.check(tag .. ': the same team came back, in order', same, #before.pids .. ' -> ' .. #after.pids)
    F.check(tag .. ': money unchanged', before.money == after.money, before.money .. ' -> ' .. after.money)
    for id, qty in pairs(before.items) do
      F.check(tag .. ': item ' .. id .. ' kept', after.items[id] == qty, qty .. ' -> ' .. tostring(after.items[id]))
    end
  end

  ---------------------------------------------------------------- bag
  -- sUsmState is never freed, so the menu is open only while its main task runs.
  local function usm()
    local p = F.r32(S.sUsmState)
    if p >= 0x02000000 and p < 0x02040000 and N.activeTask(P.Task_UsmMain) then return p end
  end
  local function usmIcon()
    local p = usm()
    if not p then return nil end
    local abs, count = F.r8(p + 10) + F.r8(p + 5), F.r8(p + 23)
    if abs >= count then return nil end
    return F.r8(p + 11 + abs)
  end
  local function inBag() return F.cb2() == (S.CB2_BagMenuRun & ~1) or F.cb2() == S.CB2_BagMenuRun end
  local function pocket() return F.r8(S.gBagPosition + 5) end
  local function cursorItem(p)
    local ptr = F.r32(S.gBagPockets + p * S.BagPocket.stride)
    local cur, scroll = F.r16(S.gBagPosition + 8 + p * 2), F.r16(S.gBagPosition + 18 + p * 2)
    return F.r16(ptr + (cur + scroll) * 4)
  end

  -- Start menu, BAG, the pocket, the item, then A twice (Use is the first action).
  function E.openBagOn(p, id)
    N.settle()
    for _ = 1, 20 do
      if usm() then break end
      N.press('Start', 2); N.idle(30)
    end
    assert(usm(), 'start menu opened')
    for _ = 1, 16 do
      if usmIcon() == USM_ICO_BAG then break end
      N.press('Right', 2); N.idle(12)
    end
    assert(usmIcon() == USM_ICO_BAG, 'start menu cursor on BAG')
    N.press('A', 2)
    for _ = 1, 120 do if inBag() then break end; N.idle(4) end
    assert(inBag(), string.format('bag opened (cb2 %08x)', F.cb2()))
    N.idle(20)
    for _ = 1, 8 do
      if pocket() == p then break end
      N.press('Right', 2); N.idle(36)
    end
    assert(pocket() == p, 'bag on pocket ' .. p)
    for _ = 1, 40 do
      if cursorItem(p) == id then break end
      N.press('Down', 2); N.idle(10)
    end
    assert(cursorItem(p) == id, 'bag cursor on item ' .. id)
    F.shot('bag_item_' .. id)
    N.press('A', 2); N.idle(30)
    N.press('A', 2); N.idle(40)
  end

  local USM_ICO_PARTY = 1
  local function inParty()
    local c = F.cb2()
    return c == (S.CB2_UpdatePartyMenu & ~1) or c == (S.CB2_InitPartyMenu & ~1)
  end

  -- A field move from the party menu: the mon in `slot`, its first field move (the row under
  -- SUMMARY), then YES at the leave-the-area prompt.
  function E.fieldMove(slot, tag)
    N.settle()
    for _ = 1, 20 do
      if usm() then break end
      N.press('Start', 2); N.idle(30)
    end
    assert(usm(), 'start menu opened')
    for _ = 1, 16 do
      if usmIcon() == USM_ICO_PARTY then break end
      N.press('Right', 2); N.idle(12)
    end
    assert(usmIcon() == USM_ICO_PARTY, 'start menu cursor on PARTY')
    N.press('A', 2)
    for _ = 1, 240 do if inParty() then break end; N.idle(4) end
    assert(inParty(), string.format('party menu opened (cb2 %08x)', F.cb2()))
    N.idle(40)
    for _ = 1, 12 do
      if F.rs8(S.gPartyMenu + 9) == slot then break end
      N.press('Down', 2); N.idle(14)
    end
    assert(F.rs8(S.gPartyMenu + 9) == slot, 'party cursor on slot ' .. slot)
    N.press('A', 2); N.idle(40)
    N.press('Down', 2); N.idle(14)
    F.shot(tag .. '_field_move')
    N.press('A', 2); N.idle(40)
    local g, m = F.grp(), F.mapn()
    for _ = 1, 120 do
      if F.grp() ~= g or F.mapn() ~= m or not inParty() then break end
      N.press('Up', 2); N.idle(6); N.press('A', 2); N.idle(16)
    end
    for _ = 1, 400 do
      if F.grp() ~= g or F.mapn() ~= m then break end
      N.idle(5)
    end
    E.waitUnlocked()
    L('  ' .. tag .. ' landed at ' .. N.mapName())
    return F.grp() ~= g or F.mapn() ~= m
  end

  local function yesNoOpen()
    return N.activeTask(P.Task_CallYesOrNoCallback) ~= nil or N.activeTask(P.Task_HandleYesNoInput) ~= nil
  end

  -- The Hub Pass from the bag, not SELECT. Its confirm opens on NO.
  function E.hubPassBag()
    E.openBagOn(POCKET_KEY, C.ITEM_HUB_RETURN)
    for _ = 1, 120 do
      if yesNoOpen() then N.idle(30); N.press('Up'); N.idle(12); N.press('A'); N.idle(60); break end
      if F.ow() then N.press('A'); end
      N.idle(20)
    end
    for _ = 1, 400 do
      if N.mapName() == 'RegionHub' and N.free() then break end
      N.press('A'); N.idle(10)
    end
    assert(N.mapName() == 'RegionHub', 'bag Hub Pass left us at ' .. N.mapName())
  end

  -- The SELECT Hub Pass where it must refuse: the message shows and the player gets control back.
  -- The message is the item task's own, not a script, so read it from gStringVar4 while it is up.
  function E.hubPassRefused(tag)
    local map = N.mapName()
    F.w16(F.sb1() + F.S.SaveBlock1.registeredItem, C.ITEM_HUB_RETURN)
    N.press('Select')
    local said
    for _ = 1, 120 do
      N.idle(2)
      if N.activeTask(P.Task_CloseCantUseKeyItemMessage) or N.message():find('respond here') then said = N.message(); break end
      if yesNoOpen() then break end
    end
    N.idle(30)
    F.shot(tag .. '_hub_refused')
    local confirm = yesNoOpen()
    for _ = 1, 20 do
      if F.r8(S.sLockFieldControls) == 0 and N.free() then break end
      N.press('A'); N.idle(20)
    end
    F.check(tag .. ': the Hub Pass refused with its message', said ~= nil and said:find('respond here') ~= nil and not confirm,
      tostring(said))
    F.check(tag .. ': still on ' .. map .. ' with control back', N.mapName() == map and N.free() and F.r8(S.sLockFieldControls) == 0,
      N.mapName())
  end

  -- The rope's spin-in holds the field controls after the warp, past what N.free() looks at, and
  -- eats a SELECT pressed meanwhile.
  function E.waitUnlocked()
    -- The map id changes before the warp-in callback has run, so wait for a steady free stretch.
    local waited, steady = 0, 0
    while waited < 1800 and steady < 40 do
      local busy = not F.ow() or F.r8(S.sLockFieldControls) ~= 0 or N.activeTask(P.Task_EscapeRopeWarpIn) ~= nil
      steady = busy and 0 or steady + 4
      N.idle(4); waited = waited + 4
    end
    L(string.format('  field controls after %d frames: lock=%d task=%s', waited, F.r8(S.sLockFieldControls), tostring(N.activeTask(P.Task_EscapeRopeWarpIn) ~= nil)))
    N.settle()
    assert(F.r8(S.sLockFieldControls) == 0, 'field controls unlocked (lock=' .. F.r8(S.sLockFieldControls) .. ')')
  end

  -- Returns false when the map refuses the rope; the bag is closed and the player is free again.
  function E.escapeRope()
    if N.itemQty(C.ITEM_ESCAPE_ROPE) == 0 then assert(N.debugGiveItem(C.ITEM_ESCAPE_ROPE, 1), 'Escape Rope given') end
    local g, m, ropes = F.grp(), F.mapn(), N.itemQty(C.ITEM_ESCAPE_ROPE)
    E.openBagOn(POCKET_ITEMS, C.ITEM_ESCAPE_ROPE)
    for _ = 1, 300 do
      if F.grp() ~= g or F.mapn() ~= m then break end
      if inBag() and _ > 60 then break end   -- refused: the bag prints its message and stays open
      N.press('A', 1); N.idle(5)
    end
    if F.grp() == g and F.mapn() == m then
      -- The bag closes back onto the start menu, which runs on the overworld callback.
      for _ = 1, 12 do
        if F.ow() and not inBag() and not usm() then break end
        N.press('B', 2); N.idle(30)
      end
      N.settle()
      F.shot('rope_refused')
      F.check('Escape Rope refused on ' .. N.mapName() .. ': kept, control back', N.free() and not usm() and N.itemQty(C.ITEM_ESCAPE_ROPE) == ropes,
        'ropes ' .. ropes .. ' -> ' .. N.itemQty(C.ITEM_ESCAPE_ROPE))
      return false
    end
    E.waitUnlocked()
    L('  Escape Rope landed at ' .. N.mapName())
    F.check('Escape Rope used up', N.itemQty(C.ITEM_ESCAPE_ROPE) == ropes - 1)
    return true
  end

  -- Fly from the debug menu's Fly map: the real map and the real Fly warp, opened without the
  -- party menu. Used outdoors only, where the party's own Fly would be allowed.
  function E.fly(mapsec)
    F.dbg(); F.sel(0); F.sel(0); F.idle(60)
    for _ = 1, 120 do if F.cb2() == (P.CB2_FlyMap & ~1) then break end; F.idle(5) end
    F.idle(90)
    local map = F.r32(P.sRegionMap)
    local entry = P.gRegionMapEntries + mapsec * 8
    local tx, ty = F.r8(entry) + 1, F.r8(entry + 1) + 2
    for _ = 1, 80 do
      if F.r16(map) == mapsec then break end
      local cx, cy = F.r16(map + O.rm_cursorPosX), F.r16(map + O.rm_cursorPosY)
      if cx < tx then N.press('Right', 2) elseif cx > tx then N.press('Left', 2)
      elseif cy < ty then N.press('Down', 2) elseif cy > ty then N.press('Up', 2) else break end
      F.idle(14)
    end
    assert(F.r16(map) == mapsec, 'fly cursor reached mapsec ' .. mapsec)
    N.press('A', 2)
    local g0, m0 = F.grp(), F.mapn()
    for _ = 1, 600 do
      F.idle(5)
      if F.grp() ~= g0 or F.mapn() ~= m0 then break end
    end
    E.waitUnlocked()
    L('  flew to ' .. N.mapName())
  end

  -- From the Hub: cross into `other`, walk a little there, Hub Pass back, and take `home`'s gate.
  -- The other region's gate boxes this team and the home gate recalls it.
  function E.away(home, other, bag)
    assert(N.mapName() == 'RegionHub', 'away starts in the Hub')
    N.crossGate(E.GATES[other])
    L(string.format('  in %s at %s party=%d', other, N.mapName(), N.partyCount()))
    F.shot('away_' .. other)
    N.idle(60)
    if bag then E.hubPassBag() else N.useHubPass() end
    N.crossGate(E.GATES[home])
    L(string.format('  home again at %s party=%d', N.mapName(), N.partyCount()))
    F.shot('home_' .. home)
  end

  -- One exit, then the time away. `exit` is hubsel or hubbag (the Hub Pass by SELECT or from the
  -- bag; the way back uses the other one), rope, dig or teleport (then the Hub Pass).
  function E.leave(exit, home, other, surface)
    L('  leaving ' .. N.mapName() .. ' by ' .. exit)
    if exit == 'hubsel' then
      N.useHubPass()
      E.away(home, other, true)
    elseif exit == 'hubbag' then
      E.hubPassBag()
      E.away(home, other, false)
    elseif exit == 'dig' or exit == 'teleport' then
      assert(E.fieldMove(N.partyCount() - 1, exit), exit .. ' moved the player')
      N.useHubPass()
      E.away(home, other, false)
    elseif exit == 'rope' then
      if E.escapeRope() then L('  roped out to ' .. N.mapName()) end
      if N.mapName():find('^Underwater') then
        E.hubPassRefused('underwater')
        N.press('B'); N.idle(30); N.settle()   -- B surfaces where light filters down
        L('  after B underwater: ' .. N.mapName())
        if N.mapName():find('^Underwater') then
          assert(surface, 'an underwater landing needs a way up')
          surface()
          assert(not N.mapName():find('^Underwater'), 'surfaced from ' .. N.mapName())
        end
      end
      N.useHubPass()
      E.away(home, other, false)
    else
      error('unknown exit ' .. tostring(exit))
    end
  end

  -- Parse PW_DETOUR=<event>:<exit>[:<other region>]. Exit 'stay' only runs the spec's refuse check.
  function E.parse(detour)
    if not detour then return nil end
    local event, exit, other = detour:match('^([%w_]+):(%w+):?(%w*)$')
    if not event then return nil end
    return event, exit, other ~= '' and other or nil
  end

  -- Insert a detour beat named detour_<event> in front of beat `before`. spec: before, home, other,
  -- into (walk part way in), items (ids that must survive), refuse(E) (checks before leaving),
  -- surface (how to come up after an underwater rope landing), outside and fly (walk outdoors,
  -- then Fly to that mapsec on the way back), check (what the planner can't do, such as the cable car).
  function E.insert(B, detour, specs)
    local event, exit, other = E.parse(detour)
    local spec = event and specs[event]
    if not spec then return B end
    local at
    for i, b in ipairs(B) do if b.name == spec.before then at = i end end
    assert(at, 'no beat ' .. spec.before)
    table.insert(B, at, { name = 'detour_' .. event, run = function()
      if spec.setup then spec.setup() end
      if exit == 'dig' or exit == 'teleport' then
        local mon = exit == 'dig' and { species = C.SPECIES_DIGLETT, moves = { C.MOVE_DIG } }
          or { species = C.SPECIES_ABRA, moves = { C.MOVE_TELEPORT } }
        mon.level = 30
        assert(N.giveMon(mon), 'gave the ' .. exit .. ' user')
      end
      if spec.into then spec.into() end
      L('  part way in at ' .. N.mapName() .. string.format(' (%d,%d)', F.pos()))
      F.shot('detour_' .. event .. '_in')
      local before = E.snapshot(spec.items)
      if spec.refuse then spec.refuse(E) end
      if exit ~= 'stay' then E.leave(exit, spec.home, other or spec.other, spec.surface) end
      E.compare('detour ' .. event, before, E.snapshot(spec.items))
      if spec.fly then
        if spec.outside then assert(N.travel(spec.outside)) end
        E.fly(spec.fly)
      end
      if spec.check then spec.check() end
    end, done = function() return F.ow() and N.free() and F.grp() >= N.region.lo and F.grp() <= N.region.hi end })
    L('excursion: detour_' .. event .. ' by ' .. exit .. ' before ' .. spec.before)
    return B
  end

  return E
end
