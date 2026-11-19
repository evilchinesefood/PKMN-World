-- Boot an incompatible battery save. The cartridge must report TOO_OLD and start a new game.
-- cases.tsv runs this suite with the historical v3 save and the exact outgoing v13 layout.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, os.getenv("PW_CASE_NAME") or "MigrateFixtures")

F.run(function()
  -- Stop at the selectable menu before pressing A on its first row. Seeing an
  -- overworld later cannot distinguish NEW GAME from an accidental CONTINUE.
  local menu
  for frame = 1, 4000 do
    for i = 0, S.Task.count - 1 do
      local task = S.gTasks + i * S.Task.stride
      if F.r8(task + S.Task.isActive) ~= 0 and
          (F.r32(task + S.Task.func) & ~1) == (S.Task_HandleMainMenuInput & ~1) then
        menu = task
        break
      end
    end
    if menu then break end
    joypad.set(frame % 18 < 2 and { A = true } or {})
    emu.frameadvance()
  end
  if not F.check("main menu reached", menu ~= nil) then F.finish(); return end
  joypad.set({})
  F.check("menu offers NEW GAME and OPTIONS only", F.r16(menu + S.Task.data) == 0 and
    F.r16(menu + S.Task.data + 24) == 2 and F.r16(S.gSaveFileStatus) == 0)
  if not F.check("refused cartridge boots a new game", F.boot()) then F.finish(); return end
  local sb2, sb3 = F.sb2(), F.sb3()
  F.check("old layout was refused as TOO_OLD", F.r8(S.gSaveVersionRefusal) == 1,
    "reason=" .. F.r8(S.gSaveVersionRefusal))
  F.check("new game uses the current clean-save format", F.r8(sb2 + S.SaveBlock2.saveVersion) ==
    S.SAVE_FORMAT_VERSION and S.SAVE_FORMAT_LAYOUT_MIN == S.SAVE_FORMAT_VERSION)

  -- Cross-check on the reshaped side. A half-loaded legacy save is exactly the failure mode the
  -- gate exists to prevent, and its signature is garbage in the shifted region banks. On a fresh
  -- new game these read clean, so a non-zero here means legacy bytes survived into the new layout.
  local SB3 = S.SaveBlock3
  -- Bit 7 of johtoFlags[0] is FLAG_HIDE_MOMS_FRIEND2 (FLAG_JOHTO_SLICE(0x07)), which
  -- NewGameInitData sets; every other bit of the byte is clear on a fresh game.
  local johtoByte = F.r8(sb3 + SB3.johtoFlags) & 0x7F
  F.check("johtoFlags bank is clean (no legacy bytes in the shifted layout)", johtoByte == 0,
    "byte0=" .. johtoByte)

  local kantoByte = F.r8(sb3 + SB3.kantoTrainerFlags)
  F.check("kantoTrainerFlags bank is clean", kantoByte == 0, "byte0=" .. kantoByte)

  local jVar = F.r16(sb3 + SB3.regionVars + 0x100 * 2)  -- a Johto-slice regionVars cell
  F.check("regionVars Johto-slice cell is 0", jVar == 0, "cell=" .. jVar)

  -- The v7 obstacle bitfield stamps its generated-table hash on load (ResyncClearedObstacleTable).
  -- Zero would mean that never ran, which is how obstacle bits silently drift after a map edit.
  local hash = F.r32(sb3 + SB3.obstacleTableHash)
  F.check("obstacle table hash is stamped (not 0)", hash ~= 0, string.format("hash=0x%08X", hash))

  -- Fresh save: nothing cut or smashed yet.
  local bits0 = F.r8(sb3 + SB3.clearedObstacleBits)
  F.check("cleared-obstacle bits start empty", bits0 == 0, "byte0=" .. bits0)

  F.shot("gated")
  F.finish()
end)
