package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local F,S,U,X,tap,hook,controller,action,exitBattle=require('bw_helpers')('BattlePaletteEntryEvolution')
local P=require('palette_symbols')
F.run(function()
 assert(F.boot(100));hook(202,0)
 for _,scene in ipairs({{0,12,'ice_entry'},{5,12,'snow_entry'},{8,22,'night_entry'}}) do
  hook(200,scene[1],480);hook(201,scene[2]);hook(1,0,1)
  for i=1,180 do F.idle(3);F.shot(scene[3]..'_'..string.format('%03d',i)) end
  F.check(scene[3]..' reaches commands',action());F.check(scene[3]..' returns',exitBattle())
 end
 hook(200,5,480);hook(201,22);hook(204,0,180)
 local plain=true
 for i=0,47 do plain=plain and F.r16(P.gPlttBufferUnfaded+64+i*2)==F.r16(P.gBattleEnvironmentPalette_Plain+i*2) end
 F.check('evolution uses untinted plain palette',plain);F.shot('evolution_plain')
 if P.sBattlePresentationCaptured then F.check('evolution clears stale snow snapshot',F.r8(P.sBattlePresentationCaptured)==0) end
 for i=1,400 do if F.ow() then break end;tap('A',1,12) end
 F.check('evolution finishes and returns to field',F.ow());hook(205)
 F.check('Eevee actually evolved into Vaporeon',F.r16(X.gSpecialVar_0x8005)==134)
 F.finish()
end)
