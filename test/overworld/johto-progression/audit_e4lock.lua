-- Does saving inside a cleared Johto Elite Four room seal the player in?
--
-- Each Johto E4 room opens its north exit at runtime with setmetatile when the member is
-- beaten, and seals the south entry behind the player. The rooms share one load-time hook,
-- EliteFourRoom_OnLoad, and it restores ONLY the entry seal -- nothing reopens the exit. The
-- base layout ships both exit tiles as the closed, collision-1 variants, so on a reload the
-- exit reverts while the entry stays sealed.
--
-- Kanto's equivalent rooms do it correctly:
--   PokemonLeague_LoreleisRoom_OnLoad:
--     call_if_set FLAG_DEFEATED_LORELEI, ..._EventScript_SetDoorOpen
--     call_if_eq VAR_MAP_SCENE_POKEMON_LEAGUE, 1, ..._EventScript_CloseEntry
-- The Johto set has no equivalent of the first line.
--
-- Re-talking the beaten member takes a no-op Defeated branch, the rooms are indoor with
-- allow_escaping false, and Fly/Teleport/Dig are all unavailable there -- so if both doors are
-- shut the save is unrecoverable.
--
-- This suite beats Will, saves inside the room, reboots, Continues, and then tries to leave by
-- both doors. It is deliberately run at a saved position of y>=10: a Continue replays recent
-- tile edits from the saved map view, but only within a window around the player, so standing
-- at the room's south end puts the exit tiles outside it. That position dependence is why the
-- defect is intermittent rather than universal.
package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local H=require('audit_helpers')('JohtoE4Lock');local F,S,A,C,tap,cmd,state,flag,finish=H.F,H.S,H.A,H.C,H.tap,H.cmd,H.state,H.flag,H.finish
local maps=require('story_maps')

local EXIT_Y=2      -- the north doorway tiles are (6,1)/(6,2)
local ENTRY_Y=11    -- the south entry the room seals behind the player

local function saveThroughMenu()
 tap('Start');F.idle(60)
 if not F.selectStartIcon(7) then return false end
 tap('A',1,90);tap('A',1,90);tap('A',1,90);F.idle(600)
 return true
end

-- Walk to the exit. The room is 13x13 with its open floor at y=3..10; Will stands at (6,6),
-- so a straight climb up x=6 is blocked by HIM, not by the door. Route around him via x=5,
-- which is open for the whole height, then come back to x=6 at y=3 and step into the doorway.
-- Getting this wrong reports a sealed exit when the only obstacle is the man you just beat.
local function tryNorthExit()
 local g,m=F.grp(),F.mapn()
 F.route({{5,7},{5,3},{6,3}},'north_exit')
 for _=1,3 do
  if F.grp()~=g or F.mapn()~=m then return true,F.pos() end
  local x,y=F.pos()
  if y<=EXIT_Y-1 then break end
  if not F.step('Up') then break end
 end
 F.idle(120)
 local left=(F.grp()~=g or F.mapn()~=m)
 local x,y=F.pos()
 return left,x,y
end

-- The entry warp is (6,12); row 11 is solid except x=6, so the way out is straight down x=6.
local function trySouthEntry()
 local g,m=F.grp(),F.mapn()
 -- Will at (6,6) blocks the straight descent too; x=5 is open for the room's full height.
 F.route({{5,3},{5,10},{6,10}},'south_entry')
 for _=1,3 do
  if F.grp()~=g or F.mapn()~=m then return true,F.pos() end
  if not F.step('Down') then break end
 end
 F.idle(120)
 local left=(F.grp()~=g or F.mapn()~=m)
 local x,y=F.pos()
 return left,x,y
end

F.run(function()
 H.boot()
 cmd(0,0)
 cmd(4,C.VAR_LEAGUE_STATE,1)
 for i=0,7 do cmd(3,C.FLAG_JOHTO_BADGE_1+i) end
 cmd(4,C.VAR_ECRUTEAK_CITY_THEATER,8)

 local m=maps.JohtoPokemonLeague_WillsRoom
 cmd(7,m.g,m.m,0,0,360)
 F.check('Will\'s Room entered',F.grp()==m.g and F.mapn()==m.m)
 F.check('door scene finishes',finish())
 local o=m.objects.JohtoPokemonLeague_WillsRoom_EventScript_Will
 F.check('reached Will',F.leg(o.x,o.y))
 F.face('Up');tap('A')
 local ok,n=finish(1500)
 F.check('Will is a battle',n and n==1)
 F.check('Will\'s victory script finishes',ok)
 F.check('League advances past Will',state(C.VAR_LEAGUE_STATE)==2,
   'state='..state(C.VAR_LEAGUE_STATE))

 -- Before saving: the exit must be open, or the premise is wrong and nothing below means
 -- anything. Prove it, then come back in and save.
 local openedX,openedY
 local opened;opened,openedX,openedY=tryNorthExit()
 F.check('beating Will opens the north exit',opened,
   string.format('stopped at (%s,%s)',tostring(openedX),tostring(openedY)))
 F.shot('exit_open_before_save')

 -- Re-enter and park at the room's south end, the position that makes the saved map view
 -- window exclude the exit tiles.
 cmd(7,m.g,m.m,0,0,360);finish()
 F.check('back inside Will\'s Room',F.grp()==m.g and F.mapn()==m.m)
 F.leg(6,10)
 local sx,sy=F.pos()
 F.L(string.format('  saving at (%d,%d) in %d/%d',sx,sy,F.grp(),F.mapn()))
 F.check('saved inside the cleared room',saveThroughMenu())

 client.reboot_core();F.idle(240)
 F.check('Continue boots',F.boot())
 F.L(string.format('  continued in %d/%d at (%d,%d)',F.grp(),F.mapn(),F.pos()))
 F.check('Continue resumes inside Will\'s Room',F.grp()==m.g and F.mapn()==m.m)
 F.check('Continue returns control',F.ensureFree())

 local outN,nx,ny=tryNorthExit()
 F.L(string.format('  north exit after reload: left=%s stopped=(%s,%s)',tostring(outN),tostring(nx),tostring(ny)))
 -- Only try the south entry if the north exit did NOT work. Once it does, the player is on
 -- another map, and walking the south route there reads that map's coordinates, can push the
 -- player through an unrelated warp, and makes the log describe a route that ran somewhere else.
 local outS,sx2,sy2=false,nx,ny
 if not outN then
  outS,sx2,sy2=trySouthEntry()
  F.L(string.format('  south entry after reload: left=%s stopped=(%s,%s)',tostring(outS),tostring(sx2),tostring(sy2)))
 else
  F.L('  south entry not tried: the north exit already left the room')
 end
 F.shot('after_reload')

 -- The headline: a save made in a cleared room must not be a dead end.
 F.check('a cleared Elite Four room can still be left after a reload',outN or outS,
   'both doors refused; the save is unrecoverable')
 F.finish()
end)
