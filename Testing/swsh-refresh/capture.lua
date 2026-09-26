package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local F,S,U,X,tap,hook,close,tasks,windows=require('swsh_helpers')('SwShRefresh')
local function ptr(p)return p and F.r32(p) or 0 end
F.run(function()
  F.check('fresh fixture boots',F.boot(100));if not F.ow() then F.finish();return end
  hook(0)
  hook(1,0);F.shot('bag_items')
  tap('Select');F.shot('bag_swap');tap('B')
  tap('A');F.shot('bag_context');tap('A');F.shot('bag_party_target');tap('B')
  for i=1,4 do
    tap('Right');F.check('pocket '..i,F.r8(S.gBagPosition+5)==i);F.shot('bag_pocket_'..i)
    if i==2 then
      for j=1,4 do tap('Select');F.shot('bag_tm_info_'..j) end
    elseif i==3 then
      for j=1,3 do tap('Select');F.shot('bag_berry_info_'..j) end
    end
  end
  close('bag')
  hook(2,0);F.shot('bag_sell');tap('A');F.shot('bag_sell_quantity');close('sell')
  hook(3,0);F.check('summary owns state',ptr(U.sMonSummaryScreen)~=0);F.shot('summary_info')
  for _,name in ipairs({'skills','moves','contest_moves','conditions','memo'}) do
    tap('Right');F.shot('summary_'..name)
    if name=='skills' then tap('A');F.shot('summary_ivs');tap('A');F.shot('summary_evs') end
  end
  tap('Left');F.shot('summary_conditions_return');tap('Right');F.shot('summary_conditions_exit')
  close('summary');F.check('summary state freed',ptr(U.sMonSummaryScreen)==0)
  hook(4);F.shot('pc_main');tap('A');F.shot('pc_box')
  F.check('storage owns state',ptr(U.sStorage)~=0)
  tap('A');F.shot('pc_context');windows('PC context');tap('B');tap('Start');F.shot('pc_info');tap('Start')
  tap('R');F.shot('pc_box_next');close('pc')
  hook(6);F.shot('shop_menu');tap('A');F.shot('shop_buy');tap('A');F.shot('shop_quantity');tap('A');F.shot('shop_confirm');windows('Shop confirmation');close('shop')
  hook(7);F.shot('pyramid_bag');tap('A');F.shot('pyramid_action');tap('Down');tap('A');F.shot('pyramid_toss');tap('A');F.shot('pyramid_confirm');windows('Pyramid confirmation');close('pyramid')
  hook(8);F.shot('pokeblock_case');tap('A');F.shot('pokeblock_action');tap('Down');tap('A');F.shot('pokeblock_toss');windows('Pokeblock confirmation');close('pokeblock')
  hook(9);F.shot('blender_prompt');windows('Blender dialogue');tap('A',2);F.shot('blender_bag');tap('B');F.idle(300);F.shot('blender_return')
  F.finish()
end)
