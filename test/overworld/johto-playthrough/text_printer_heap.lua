-- A text printer still linked when the heap is reset must not hang the return to the field.
--
-- Text printers live in a heap-allocated list headed by sFirstTextPrinter. ReturnToFieldLocal
-- resets the heap first (ResetMirageTowerAndSaveBlockPtrs -> MoveSaveBlocks_ResetHeap), then
-- InitViewGraphics -> DeactivateAllTextPrinters walks the list. A printer that finished on the
-- frame a battle ended was still linked, so the walk read a block the reset had overwritten and
-- Free() stopped at src/malloc.c:97. The natural-difficulty bot hit it after a catch.
--
-- The stale head is staged by a write, since the real timing is a matter of single frames; the
-- heap reset, the walk and the return to the field are the game's own, driven through the Bag.
--
--   python3 test/overworld/johto-playthrough/run.py --suite text_printer_heap.lua
local here = (debug.getinfo(1, 'S').source:sub(2)):match('^(.*[/\\])')
package.path = here .. '?.lua;' .. here .. '../lua/?.lua;' .. assert(os.getenv('PW_PLAY_LUA')) .. '/?.lua;' .. package.path
local S = require('symbols')
local F = require('lib').new(S, 'TextPrinterHeap')
local N = require('nav')(F, S)
local P = require('pwsym')
local USM_ICO_BAG = 2

F.run(function()
  assert(F.boot(100), 'fresh hub boot')
  N.settle()
  F.check('no printer is linked while the field is idle', F.r32(P.sFirstTextPrinter) == 0)

  F.press('Start'); F.idle(60)
  assert(F.selectStartIcon(USM_ICO_BAG), 'Bag icon on the Start menu')
  F.press('A'); F.idle(90)
  for _ = 1, 300 do
    if F.cb2() == (P.CB2_BagMenuRun & ~1) then break end
    F.idle(1)
  end
  F.check('the Bag opened', F.cb2() == (P.CB2_BagMenuRun & ~1))

  F.w32(P.sFirstTextPrinter, P.gHeap + 0x4000)

  F.press('B'); F.idle(120)
  local back = false
  for _ = 1, 900 do
    if F.ow() then back = true; break end
    F.idle(1)
  end
  F.check('the field came back with a printer linked at the heap reset', back, 'cb2=' .. string.format('%08x', F.cb2()))
  F.check('no crash screen', not F.reportCrash('text_printer_heap'))
  F.check('the printer list was dropped with the heap', F.r32(P.sFirstTextPrinter) == 0, string.format('%08x', F.r32(P.sFirstTextPrinter)))
  F.finish()
end)
