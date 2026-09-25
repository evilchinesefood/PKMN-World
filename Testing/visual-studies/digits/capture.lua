-- Runs only against an isolated baseline/candidate study ROM with study_hook.c.
-- All UI pages use production menu functions and controls; test data are created in RAM.
local libdir=assert(os.getenv('PW_STUDY_LIB'))
package.path=libdir..'/?.lua;'..package.path
local X=require('study_symbols');local S=require('symbols')
local F=require('lib').new(S,'DigitsStudy')
local function hook(command,arg)
  F.w16(S.gSpecialVar_0x8004,command)
  F.w16(X.arg,arg or 0) -- gSpecialVar_0x8005; independently checked against input ELF
  F.w32(S.gMain+4,X.hook)
  F.idle(240)
end
local function tap(key,n) for i=1,(n or 1) do F.press(key,2);F.idle(90) end end
local function closeSummary() tap('B');F.idle(120);F.check('summary returns to field',F.ow()) end
F.run(function()
  F.check('boot into field',F.boot(100))
  if not F.ow() then F.finish();return end
  hook(0)
  F.check('six fixture Pokemon',F.r8(S.gPartiesCount)==6)
  F.check('fixture callback returned',F.ow())
  hook(1,0);F.shot('summary_info_level1')
  tap('Right');F.shot('summary_stats_hp1')
  tap('A');F.shot('summary_ivs31')
  tap('A');F.shot('summary_evs252_total510')
  tap('Right');F.shot('summary_pp1_40_10_5')
  tap('A');F.shot('summary_move_detail');tap('Down');F.shot('summary_move_dash_state')
  tap('B');closeSummary()
  for index=1,5 do
    hook(1,index);F.shot('summary_info_slot'..index)
    tap('Right');F.shot('summary_stats_slot'..index)
    if index==5 then tap('Right');F.shot('summary_long_move_name') end
    closeSummary()
  end
  hook(2,0);F.shot('bag_quantities_1_9_10_99')
  tap('Down',3);F.shot('bag_quantity99');tap('Down');F.shot('bag_longest_item_name')
  tap('B');F.idle(120);F.check('bag returns to field',F.ow())
  hook(2,2);tap('Select');F.shot('bag_tm_info')
  tap('Down');F.shot('bag_tm_info2');tap('Down',2);F.shot('bag_tm_dash_state')
  tap('B');F.idle(120);F.check('TM bag returns to field',F.ow())
  hook(3);F.shot('storage_box')
  tap('Start');F.shot('storage_info_level1')
  tap('Right',5);F.shot('storage_narrower_name')
  F.check('storage callback active',F.cb2()==X.storage)
  -- End this normal UI path before the separate diagnostic overlay fixture.
  F.finish()
end)
