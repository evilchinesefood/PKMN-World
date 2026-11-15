-- Pokedex: Pikachu's and Squirtle's Forms pages with the special variants, then the Special
-- Pokemon checklist. Navigation from SpecialDexFormsNav.lua and SpecialChecklistPaging.lua.
local F, S, X = dofile(os.getenv("REC_TOOLS") .. "/Show.lua")("Dex")

local function taskRunning(fn)
  for i = 0, S.Task.count - 1 do
    local task = S.gTasks + i * S.Task.stride
    if F.r8(task + S.Task.isActive) ~= 0 and (F.r32(task + S.Task.func) & ~1) == (fn & ~1) then return true end
  end
  return false
end
local function waitForms()
  for _ = 1, 300 do if taskRunning(S.Task_HandleFormsScreenInput) then F.idle(20); return true end F.idle(2) end
  return false
end
local function toField()
  for _ = 1, 30 do if F.ow() then break end X.tap("B", 40) end
  for _ = 1, 10 do if F.ensureFree() then break end F.press("B", 2); F.idle(20) end
  F.idle(30)
  return F.ow()
end
local function openDexList(index, tag)
  F.press("Start", 2); F.idle(60)
  F.check(tag .. ": Pokedex icon", F.selectStartIcon(0))
  F.press("A", 2); F.idle(240)
  X.tap("Start", 40); X.tap("Down"); X.tap("A", 60)
  X.rec(false)
  for _ = 1, index do F.press("Down", 2); F.idle(10) end
  F.idle(30)
  X.rec(true)
  F.idle(50)
end
local function forms(index, n, tag)
  X.mark(tag)
  openDexList(index, tag)
  X.tap("A", 100)                       -- Info
  for _ = 1, 3 do X.tap("Right", 70) end -- Area, Stats, Evos
  X.tap("Start", 30)                    -- Forms
  F.check(tag .. ": Forms page", waitForms())
  F.idle(60)
  X.tap("A", 50)
  for i = 1, n do X.tap("Right", 44); F.shot(string.format("%s_%02d", tag, i)) end
  F.idle(40)
  X.tap("B", 40)
  X.rec(false)
  F.check(tag .. ": back to the field", toField())
end

F.run(function()
  X.rec(false)
  assert(F.boot(100), "boot")
  X.instantText()
  X.flag(0x949, true)                                   -- FLAG_SYS_POKEDEX_GET
  F.dbg(); F.sel(7); F.sel(2); F.idle(60); F.bOut(4)   -- Pokedex Flags All
  F.dbg(); F.sel(7); F.sel(5); F.idle(60); F.bOut(4)   -- Toggle National Dex
  F.w8(F.sb2() + 0x19, 1)
  for _, id in ipairs({ 0xDD1, 0xDD2, 0xDD3, 0xDD7, 0xDDB, 0xDDC, 0xDDD, 0xDE1 }) do X.flag(id, true) end
  X.normalText()
  F.idle(30)

  X.rec(true)
  forms(24, 18, "pikachu")
  X.rec(true)
  forms(6, 3, "squirtle")

  X.rec(true); X.mark("checklist")
  F.press("Start", 2); F.idle(60)
  F.selectStartIcon(0); F.press("A", 2); F.idle(240)
  X.tap("Start", 60); X.tap("Down", 30); X.tap("Down", 30); X.tap("Down", 40); X.tap("A", 120)
  F.idle(60); F.shot("checklist_page1")
  for _ = 1, 4 do X.tap("Down", 45) end
  X.tap("Right", 70); F.shot("checklist_page2")
  X.tap("Down", 45)
  X.tap("Left", 60)
  for _ = 1, 6 do X.tap("Up", 20) end
  F.idle(30)
  X.tap("A", 110); F.shot("detail_1")
  for i = 2, 7 do X.tap("Right", 100); F.shot("detail_" .. i) end
  X.tap("B", 60); F.idle(40)
  X.rec(false)
  F.check("back to the field", toField())
  F.finish()
end)
