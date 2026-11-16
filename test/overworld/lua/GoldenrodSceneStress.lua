-- Goldenrod's three scenes from 0829014ec0, on real input with A, B and Start mashed through each:
--   * first visit after a Hub gate arrival at the Train Station: the city's ON_FRAME setup must run
--     on entry (state 0 -> 1), hide the Rockets and Bill, and hand control back;
--   * the Name Rater's TV (NameRival no longer follows with a waitstate): control must return, and
--     the news must read complete: it used to end on "Do YOU know his name?" for a naming screen
--     that no longer exists, so it now names the boy ({RIVAL}, GARY in Johto);
--   * the Radio Tower quiz won late (state 5, after the Plain Badge): FLAG_ENABLE_RADIO is set and
--     VAR_GOLDENROD_CITY_STATE is not rewound to 2.
-- Setup writes badges and the Azalea/Ilex/Goldenrod vars and gives a debug party; the gate, the
-- walks and the dialogue are the game's own.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "GoldenrodSceneStress")

local HUB = {100, 0}
local GOLDENROD, STATION, NAME_RATER, RADIO_1F = {83, 0}, {84, 23}, {84, 14}, {84, 18}
local JOHTO_ATTENDANT_X = 16
local VAR_GOLDENROD_CITY_STATE, VAR_AZALEA_TOWN_STATE, VAR_ILEX_FOREST_FARFETCHD = 0xA083, 0xA08C, 0xA08D
local FLAG_HIDE_GOLDENROD_ROCKETS, FLAG_HIDE_GOLDENROD_BILL = 0x6000 + 0xDD, 0x6000 + 0xD8
local FLAG_VISITED_GOLDENROD_CITY, FLAG_ENABLE_RADIO = 0x6000 + 0xEA, 0x6000 + 0xC5
local FLAG_JOHTO_BADGE = function(i) return 0x63F8 + i end
local CONTEXT_RUNNING = 0

local function text(addr, n)
  local t = {}
  for i = 0, n - 1 do
    local b = F.r8(addr + i)
    if b == 0xFF then break end
    if b >= 0xBB and b <= 0xD4 then t[#t + 1] = string.char(65 + b - 0xBB)
    elseif b >= 0xD5 and b <= 0xEE then t[#t + 1] = string.char(97 + b - 0xD5)
    else t[#t + 1] = " " end
  end
  return table.concat(t)
end
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function mapIs(m) return F.grp() == m[1] and F.mapn() == m[2] end
local function count() return F.r8(S.gPartiesCount) end
local function flagAddr(id)
  if id >= 0x6000 and id < 0x6400 then return F.sb3() + S.SaveBlock3.johtoFlags + (id - 0x6000) // 8, (id - 0x6000) % 8 end
  return F.sb1() + S.SaveBlock1.flags + id // 8, id % 8
end
local function flagGet(id) local a, b = flagAddr(id); return (F.r8(a) & (1 << b)) ~= 0 end
local function flag(id, on)
  local a, b = flagAddr(id)
  F.w8(a, on and (F.r8(a) | (1 << b)) or (F.r8(a) & (~(1 << b) & 0xFF)))
end
local function varAddr(id)
  if id >= 0xA000 then return F.sb3() + S.SaveBlock3.regionVars + (id - 0xA000) * 2 end
  return F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2
end
local function var(id, v) F.w16(varAddr(id), v) end
local function varGet(id) return F.r16(varAddr(id)) end
local function objectAt(x, y)
  for _, o in ipairs(F.objdump()) do if o.x == x and o.y == y then return true end end
  return false
end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
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
-- Page text with A until a Yes/No or multichoice is up, move the cursor to `want`, confirm.
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

-- A, B and Start in turn until the scene hands control back. Start only while a script holds
-- the field (the start menu would open otherwise).
local function mash(tag, budget)
  for i = 1, budget or 2400 do
    local k = i % 24
    if k == 0 then F.press("A", 2) elseif k == 8 then F.press("B", 2)
    elseif k == 16 and not hasControl() then F.press("Start", 2) else F.idle(1) end
    if i == 120 then F.shot(tag .. "_during") end
    if i > 240 and hasControl() then F.idle(40); if hasControl() then return true end end
    if i % 240 == 0 and F.reportCrash(tag) then return false end
  end
  return hasControl()
end

local function debugParty()
  F.dbg(); F.idle(40); F.sel(2); F.idle(40)
  for _ = 1, 9 do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(180)
  for _ = 1, 30 do F.press("B", 2); F.idle(16); if F.ensureFree() then break end end
  return count() >= 1
end

F.run(function()
  if not F.boot(HUB[1]) then F.check("boot", false); F.finish(); return end
  -- As JohtoGoldenrodArrival.lua: the hub is open, the intros are done, Johto's gate admits.
  flag(0xDCF, true); flag(0x51, true); flag(0xA4B, true); flag(0x94F, true); flag(0x95F, true)
  F.w8(F.sb2() + S.SaveBlock2.introDoneBits, 7)
  F.check("setup: debug party", debugParty(), "n=" .. count())
  flag(FLAG_JOHTO_BADGE(0), true); flag(FLAG_JOHTO_BADGE(1), true)
  var(VAR_AZALEA_TOWN_STATE, 7); var(VAR_ILEX_FOREST_FARFETCHD, 3); var(VAR_GOLDENROD_CITY_STATE, 0)

  -- The Johto gate's standard arrival with Ilex Forest done lands in the Train Station.
  local ok = F.route({{16,4},{JOHTO_ATTENDANT_X,4},{JOHTO_ATTENDANT_X,3}}, "gate_walk")
  if ok then
    F.face("Up"); F.press("A", 3); F.idle(60)
    ok = menu(1, "gate_team") and menu(1, "gate_arrival") and menu(0, "gate_confirm")
  end
  for _ = 1, 400 do
    if mapIs(STATION) and F.ow() then break end
    F.press("A", 2); F.idle(14)
  end
  F.idle(120)
  F.check("the Hub gate landed in the Goldenrod Train Station", ok and mapIs(STATION), where())
  if not mapIs(STATION) then F.finish(); return end
  F.check("the city has not set itself up yet (state 0)", varGet(VAR_GOLDENROD_CITY_STATE) == 0)

  -- Out of the station's south door into the city, mashing through the first-visit scene.
  ok = F.route({{16,25}}, "station_exit")
  if ok then for _ = 1, 30 do joypad.set({ Down = true }); emu.frameadvance() end end
  for _ = 1, 300 do if mapIs(GOLDENROD) then break end; F.idle(1) end
  local freed = mapIs(GOLDENROD) and mash("first_visit")
  F.shot("first_visit_after")
  F.check("entering the city ran its setup and returned control", freed and varGet(VAR_GOLDENROD_CITY_STATE) == 1,
    string.format("%s state=%d control=%s", where(), varGet(VAR_GOLDENROD_CITY_STATE), tostring(hasControl())))
  F.check("the setup marked the city visited and hid the Rockets and Bill",
    flagGet(FLAG_VISITED_GOLDENROD_CITY) and flagGet(FLAG_HIDE_GOLDENROD_ROCKETS) and flagGet(FLAG_HIDE_GOLDENROD_BILL))
  F.check("no Rocket stands beside the station door (22,22)", not objectAt(22, 22))

  -- Back into the station and out again: no second run.
  local x, y = F.pos()
  F.route({{24,22}}, "to_station_door")
  for _ = 1, 30 do joypad.set({ Up = true }); emu.frameadvance() end
  for _ = 1, 300 do if mapIs(STATION) then break end; F.idle(1) end
  F.idle(60)
  F.route({{16,25}}, "station_exit2")
  for _ = 1, 30 do joypad.set({ Down = true }); emu.frameadvance() end
  for _ = 1, 300 do if mapIs(GOLDENROD) then break end; F.idle(1) end
  F.idle(90)
  F.check("re-entering the city plays nothing and keeps state 1",
    mapIs(GOLDENROD) and hasControl() and varGet(VAR_GOLDENROD_CITY_STATE) == 1,
    string.format("%s state=%d", where(), varGet(VAR_GOLDENROD_CITY_STATE)))

  -- The Name Rater's TV.
  F.check("warped into the Name Rater's house", F.warpTo(0, 8, 4, 0, 1, 4, 0, 0, 0, NAME_RATER[1], NAME_RATER[2], "name_rater"), where())
  ok = F.route({{4,7},{2,7},{2,2}}, "to_tv")
  F.check("walked to the TV", ok, where())
  if ok then
    F.face("Up"); F.press("A", 3); F.idle(40)
    local news = text(S.gStringVar4, 200)
    F.L("  tv: " .. news)
    for i = 1, 5 do F.idle(200); F.shot("tv_page_" .. i); F.press("A", 2) end
    F.check("the TV news names the boy instead of asking for a name",
      news:find("REDHEADED BOY") ~= nil and news:find("His name is GARY") ~= nil and news:find("know his name") == nil, news)
    F.check("the TV news hands control back", mash("tv", 1800),
      string.format("lock=%d ctx=%d", F.r8(S.sLockFieldControls), F.r8(S.sGlobalScriptContextStatus)))
    F.shot("tv_after")
  end

  -- The Radio Tower quiz, won after the Plain Badge (state 5).
  var(VAR_GOLDENROD_CITY_STATE, 5); flag(FLAG_ENABLE_RADIO, false)
  F.check("warped into Radio Tower 1F", F.warpTo(0, 8, 4, 0, 1, 8, 0, 0, 0, RADIO_1F[1], RADIO_1F[2], "radio"), where())
  ok = F.route({{9,9},{9,7},{14,7},{14,8}}, "to_reception")
  F.check("walked to the reception counter", ok, where())
  if ok then
    F.face("Down"); F.press("A", 3); F.idle(40)
    local answers = { 0, 0, 0, 1, 0, 1 } -- take the quiz, then YES YES NO YES NO
    local all = true
    for i, a in ipairs(answers) do all = all and menu(a, "quiz_" .. i) end
    F.check("answered the quiz", all)
    F.check("the late quiz win hands control back", mash("quiz_end", 1800))
    F.check("the late quiz win enables the radio", flagGet(FLAG_ENABLE_RADIO))
    F.check("the late quiz win keeps VAR_GOLDENROD_CITY_STATE at 5", varGet(VAR_GOLDENROD_CITY_STATE) == 5,
      "state=" .. varGet(VAR_GOLDENROD_CITY_STATE))
    F.shot("quiz_after")
  end
  F.finish()
end)
