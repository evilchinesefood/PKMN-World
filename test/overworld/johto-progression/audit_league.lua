package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local H=require('audit_helpers')('JohtoLeagueAudit');local F,S,A,C,tap,cmd,state,flag,finish=H.F,H.S,H.A,H.C,H.tap,H.cmd,H.state,H.flag,H.finish
local maps=require('story_maps')
F.run(function()
 H.boot();cmd(4,C.VAR_LEAGUE_STATE,1)
 for i=0,7 do cmd(3,C.FLAG_JOHTO_BADGE_1+i) end
 cmd(4,C.VAR_ECRUTEAK_CITY_THEATER,8)
 for i,c in ipairs({{'JohtoPokemonLeague_WillsRoom','JohtoPokemonLeague_WillsRoom_EventScript_Will'},{'JohtoPokemonLeague_KogasRoom','JohtoPokemonLeague_KogasRoom_EventScript_Koga'},{'JohtoPokemonLeague_BrunosRoom','JohtoPokemonLeague_BrunosRoom_EventScript_Bruno'},{'JohtoPokemonLeague_KarensRoom','JohtoPokemonLeague_KarensRoom_EventScript_Karen'}}) do
  local m=maps[c[1]];cmd(7,m.g,m.m,i==2 and 1 or 0,0,360);F.check(c[1]..' door scene finishes',finish())
  local o=m.objects[c[2]];assert(F.leg(o.x,o.y));F.face('Up');tap('A');local ok,n=finish(1500)
  F.check(c[1]..' battle and victory finish',ok and n==1);F.check(c[1]..' League state advances',state(C.VAR_LEAGUE_STATE)==i+1)
  F.check(c[1]..' returns movement',F.step('Down'));F.shot('elite_'..i)
 end
 local m=maps.JohtoPokemonLeague_ChampionsRoom;cmd(7,m.g,m.m,0,0,360);assert(finish())
 local o=m.objects.JohtoPokemonLeague_WillsRoom_EventScript_Lance;assert(F.leg(o.x,o.y));F.face('Up');tap('A')
 local ok,n=finish(2500)
 F.check('Lance battle and ceremony return to field',ok and n==1)
 F.check('Johto Champion recorded',flag(C.FLAG_JOHTO_CHAMPION))
 F.shot('champion_end')
 F.check('Champion return restores movement',F.step('Down'))
 tap('Start');assert(F.selectStartIcon(7));tap('A');tap('A');tap('A');F.idle(600)
 client.reboot_core();F.idle(240)
 F.check('Champion save Continues in New Bark',F.boot(75))
 F.check('Johto Champion persists after Continue',flag(C.FLAG_JOHTO_CHAMPION))
 F.check('Champion Continue returns movement',F.ensureFree());F.shot('champion_continue')
 F.finish()
end)
