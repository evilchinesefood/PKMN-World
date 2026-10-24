-- Staged Johto loop on a disposable ROM with the existing test-only BW fixture.
-- Party/balls/wild encounter are injected; healing, menus, capture and save are live.
package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local F,S,U,X,tap,hook,controller,action=require('bw_helpers')('JohtoCoreLoop357')
local function free() return F.ow() and F.r8(S.sGlobalScriptContextStatus)==2 end
local function region()
 F.w8(F.sb2()+S.SaveBlock2.currentRegion,2);F.w32(S.gCurrentRegion,2)
end
F.run(function()
 assert(F.boot(100));hook(0);region()
 assert(F.warpTo(0,7,7,0,0,0,0,0,0,77,0,'cherrygrove_center'))
 assert(F.leg(7,5));F.face('Up')
 F.w16(S.gParties+S.Pokemon.hp,1)
 tap('A');for i=1,200 do tap('A',1,20) end
 F.dismiss(50)
 F.check('Johto nurse heals injured lead',F.r16(S.gParties+S.Pokemon.hp)==F.r16(S.gParties+S.Pokemon.maxHP))
 F.check('Johto nurse releases controls',free() and F.step('Down'));F.shot('nurse_complete')
 tap('Start');assert(F.selectStartIcon(1));tap('A',1,180)
 F.check('Johto party menu opens',not F.ow());F.shot('party_menu')
 for i=1,8 do tap('B') end
 F.check('party menu returns to Johto field',free() and F.grp()==77)
 assert(F.warpTo(0,7,5,0,0,2,0,0,0,75,2,'route29_capture'))
 hook(12);hook(1,0,600);assert(action());hook(126)
 F.check('wild capture is in Johto',F.grp()==75 and F.mapn()==2 and F.r8(F.sb2()+S.SaveBlock2.currentRegion)==2)
 tap('Right');tap('A',1,240);F.shot('bag_ball');tap('A');tap('A',1,540)
 for i=1,300 do if F.ow() then break end;tap('B',1,24) end
 F.check('Johto Bag capture returns to field',F.ow());assert(F.ow());hook(13)
 F.check('capture consumes last ball',F.r16(U.gSpecialVar_0x8006)==0)
 F.check('full-party catch is stored',F.r16(X.gSpecialVar_0x8005)==1);F.shot('capture_complete')
 -- Return to a safe Center for a real menu save and Continue.
 assert(F.warpTo(0,7,7,0,0,0,0,0,0,77,0,'center_return'))
 tap('Start');assert(F.selectStartIcon(7));tap('A');tap('A');tap('A');F.idle(600)
 client.reboot_core();F.idle(240)
 F.check('Johto Center save Continues',F.boot(77) and F.mapn()==0)
 F.check('prepared party persists',F.r8(S.gPartiesCount)==6)
 hook(13);F.check('caught boxed Pokemon persists',F.r16(X.gSpecialVar_0x8005)==1)
 F.check('Continue returns control',F.ensureFree());F.shot('continue')
 F.finish()
end)
