package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local F,S,U,X,tap,hook,close,tasks,windows,summaryClean,heap=require('swsh_helpers')('SwShLifecycle')
local function palette(a,b,n)
 for i=0,n-1 do if F.r16(a+i*2)~=F.r16(b+i*2) then F.L(string.format("palette diff %d GPU=%x ROM=%x",i,F.r16(a+i*2),F.r16(b+i*2)));return false end end
 return true
end
local function storage()
 hook(4);tap('A');F.check('storage opened',F.r32(U.sStorage)~=0);assert(F.r32(U.sStorage)~=0)
end
F.run(function()
 assert(F.boot(100));hook(0)
 hook(1,0);tap('A',2);F.shot('healing_target')
 F.check('HP bar mapped',F.r8(U.sHPBarWindowMapped)~=0)
 tap('A');F.shot('healing_quantity');tap('A');F.shot('healing_result');close('heal')
 hook(14,0);F.check('Potion heals exactly 20 HP',F.r16(X.gSpecialVar_0x8005)==21,'hp='..F.r16(X.gSpecialVar_0x8005))
 -- Fresh fixture data for repeatable menu cycles.
 hook(0)
 local warmed
 for cycle=1,8 do
  hook(3,cycle%6);tap('Right',4)
  F.check('Conditions uses scanline window '..cycle,F.r16(0x4000000)&0x6000~=0)
  -- Interrupt entry at different animation phases, then change Pokemon rapidly.
  tap('Right');F.check('Conditions window cleared '..cycle,F.r16(0x4000000)&0x6000==0)
  F.check('Conditions DMA stopped '..cycle,F.r8(U.gScanlineEffect+21)==0)
  for n=1,8 do tap(n%2==0 and 'Left' or 'Right',1,4);tap('Down',1,4) end
  F.idle(180)
  for _,fn in ipairs({'Task_PrintConditionsPage','Task_PrintInfoPage','Task_PrintSkillsPage','Task_PrintBattleMoves','Task_PrintContestMoves','Task_PrintMemoPage'}) do
   F.check('single printer '..cycle..' '..fn,tasks(U[fn])<=1)
  end
  close('summary '..cycle);summaryClean('summary '..cycle)
  local used=heap();if cycle==2 then warmed=used elseif cycle>2 then F.check('no summary heap growth '..cycle,used==warmed,'bytes='..used..' expected='..warmed) end
 end
 hook(3,2);F.shot('summary_shiny');close('shiny');summaryClean('shiny')
 hook(15,5);hook(3,5);F.shot('summary_egg');close('egg');summaryClean('egg')
 hook(0)
 -- Party R uses the production saved-state and callback path.
 hook(5);F.shot('party_before_pc');tap('R',1,300)
 F.check('party R enters storage',F.r32(U.sStorage)~=0)
 F.check('party caller recorded',F.r32(U.sReturnToPartyCallback)~=0)
 tap('B',2,240);F.shot('party_after_pc')
 F.check('PC returns to party',not F.ow() and F.r32(U.sStorage)==0)
 F.check('PC return callback consumed',F.r32(U.sReturnToPartyCallback)==0)
 close('party')
 storage();F.shot('terminal_after_party');F.check('terminal has no stale caller',F.r32(U.sReturnToPartyCallback)==0)
 tap('Start');F.shot('pc_mon_info');windows('PC info')
 F.check('PC main and text palettes independent',palette(0x5000002,U.sSwShStorage_Pal+2,31))
 F.check('PC standard menus own bank 15',palette(0x50001e0,U.gStandardMenuPalette,16))
 tap('Start');tap('A');windows('PC mon menu');tap('Down');tap('A');F.shot('pc_summary')
 F.check('PC summary owns summary state',F.r32(U.sMonSummaryScreen)~=0);tap('Right',4);tap('B',1,300)
 F.check('PC summary returns to storage',F.r32(U.sMonSummaryScreen)==0 and F.r32(U.sStorage)~=0)
 F.check('PC return clears scanline',F.r8(U.gScanlineEffect+21)==0)
 tap('A');tap('Down',3);tap('A');F.shot('pc_markings');tap('B');close('pc terminal')
 -- All installed wallpaper IDs keep bank 2 and leave banks 0/1 and 15 untouched.
 for id=0,19 do
  hook(10,id);storage();tap('Start')
  F.check('wallpaper '..id..' preserves main/text palette',palette(0x5000002,U.sSwShStorage_Pal+2,31))
  F.check('wallpaper '..id..' preserves standard menu palette',palette(0x50001e0,U.gStandardMenuPalette,16))
  F.shot('wallpaper_'..id);close('wallpaper '..id)
 end
 hook(12)
 for pocket=0,4 do hook(1,pocket);windows('empty pocket '..pocket);F.shot('empty_pocket_'..pocket);close('empty pocket '..pocket) end
 hook(0);hook(10,19);hook(11,0,1200);F.check('synthetic save written',F.r16(X.gSpecialVar_0x8005)==1,'status='..F.r16(X.gSpecialVar_0x8005))
 local oldMoney=F.money()
 local oldWallpaper=F.r8(F.r32(U.gPokemonStoragePtr)+0x83c2)
 local oldHP=F.r16(S.gParties+S.Pokemon.hp)
 client.reboot_core();F.idle(5);F.check('saved fixture reloads',F.boot(100))
 F.check('money survives reload',F.money()==oldMoney)
 F.check('chosen wallpaper survives reload',oldWallpaper==19 and F.r8(F.r32(U.gPokemonStoragePtr)+0x83c2)==oldWallpaper)
 F.check('party HP survives reload',F.r16(S.gParties+S.Pokemon.hp)==oldHP)
 hook(4);tap('A');F.check('saved storage opens',F.r32(U.sStorage)~=0);F.shot('pc_after_save_reload');close('saved PC')
 F.finish()
end)
