-- Can a player actually reach the Johto Elite Four door?
--
-- JohtoIndigoPlateau_PokemonCenter warp 1 at (32,2) is the door to Will's Room. The layout's
-- collision makes it reachable from exactly one tile: at y=2 every x except 32 is solid, so the
-- only approach is (32,3) directly below it.
--
-- Two NPCs stand in that corridor, each behind a hide flag:
--   (32,8) Silver,     FLAG_HIDE_INDIGO_PLATEAU_SILVER -- set by Route27's first-steps flagheap
--   (32,3) Black Belt, FLAG_HIDE_LEAGUE_BLACKBELT      -- had NO setter anywhere in the repo
--
-- So the Black Belt spawned on every save and stood on the only tile that enters the League.
-- He is an ordinary object at elevation 0, which collides at every elevation. The Hall of Fame
-- clears his flag to bring him back after the championship, which only makes sense if something
-- set it on the way in -- and Route 27 is where its two siblings are set.
--
-- The suite walks the REAL Route 27 trigger rather than setting flags by hand, so it tests the
-- shipped script and not the test's own staging. It discriminates in both directions: before
-- Route 27 the gatekeeper must still block (that is his purpose), after it the door must open.
package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local H=require('audit_helpers')('JohtoProbe');local F,S,A,C,tap,cmd,state,flag,finish=H.F,H.S,H.A,H.C,H.tap,H.cmd,H.state,H.flag,H.finish
local maps=require('story_maps')

local DOOR_X,DOOR_Y=32,2
local BELT_X,BELT_Y=32,3
local START_X,START_Y=32,6   -- open floor in the same corridor, close enough to spawn the NPCs

local function enterNearDoor()
 local m=maps.JohtoIndigoPlateau_PokemonCenter
 cmd(1,m.g,m.m,START_X,START_Y,300)
 local x,y=F.pos()
 return F.grp()==m.g and F.mapn()==m.m and x==START_X and y==START_Y
end

local function dumpObjects(tag)
 local list={}
 for _,o in ipairs(F.objdump()) do list[#list+1]=string.format('%d@(%d,%d)',o.i,o.x,o.y) end
 F.L('  objects '..tag..': '..(#list>0 and table.concat(list,' ') or 'none'))
end

local function occupied(x,y)
 for _,o in ipairs(F.objdump()) do if o.x==x and o.y==y then return true,o.i end end
 return false
end

-- Step north up the corridor towards the door, reporting the tile that refuses.
local function climbToDoor()
 for _=1,6 do
  local x,y=F.pos()
  if y<=DOOR_Y then break end
  if not F.step('Up') then return false,x,y end
 end
 local x,y=F.pos()
 return y<=DOOR_Y,x,y
end

local function leaveAndReenter()
 local w=maps.JohtoPokemonLeague_WillsRoom;cmd(1,w.g,w.m,w.x,w.y,300)
 return enterNearDoor()
end

F.run(function()
 H.boot()

 -- ---- 1. Before Route 27: the gatekeeper is meant to block -------------------------------
 F.L('PROBE before-route27')
 -- Hide Silver only, so this pass isolates the Black Belt rather than stopping at (32,8).
 cmd(3,C.FLAG_HIDE_INDIGO_PLATEAU_SILVER)
 F.check('corridor entered before Route 27',enterNearDoor())
 dumpObjects('before-route27')
 F.check('Black Belt spawns before Route 27',occupied(BELT_X,BELT_Y))
 local reachedB,bx,by=climbToDoor()
 F.check('door is closed before Route 27, as intended',not reachedB,
   string.format('stopped at (%d,%d)',bx,by))
 F.shot('before_route27')

 -- ---- 2. The real Route 27 trigger -------------------------------------------------------
 F.L('PROBE route27-trigger')
 local m=maps.Route27
 cmd(1,m.g,m.m,25,23,300)
 F.check('Route 27 entered',F.grp()==m.g and F.mapn()==m.m)
 F.check('stepped onto the first-steps trigger',F.step('Down'))
 F.check('Route 27 first-steps scene completes',finish(900))
 F.check('Route 27 state advances',state(C.VAR_ROUTE27_STATE)==1,
   'state='..state(C.VAR_ROUTE27_STATE))
 F.check('Route 27 hides Silver from the Plateau',flag(C.FLAG_HIDE_INDIGO_PLATEAU_SILVER))
 F.check('Route 27 hides the League Black Belt',flag(C.FLAG_HIDE_LEAGUE_BLACKBELT))

 -- ---- 3. After Route 27: the door must open ----------------------------------------------
 F.L('PROBE after-route27')
 F.check('corridor entered after Route 27',enterNearDoor())
 dumpObjects('after-route27')
 F.check('Black Belt is gone after Route 27',not occupied(BELT_X,BELT_Y))
 local reachedA,ax,ay=climbToDoor()
 F.check('Elite Four door is reachable after Route 27',reachedA,
   string.format('stopped at (%d,%d)',ax,ay))
 F.shot('after_route27')

 -- ---- 4. Why the Hall of Fame must not restore him ---------------------------------------
 -- The Hall of Fame used to clearflag this, putting him back on (32,3) and walling off the
 -- Elite Four the moment you became Champion -- against the HARD rematches it enables in the
 -- same script. This pass re-creates that state to show the harm is real, so the removed line
 -- cannot be reinstated without this suite objecting. That the SHIPPED Hall of Fame no longer
 -- clears it is asserted end-to-end in audit_league.lua, which actually plays the ceremony.
 F.L('PROBE flag-cleared-is-self-healing')
 cmd(5,C.FLAG_HIDE_LEAGUE_BLACKBELT)
 F.check('corridor re-entered after clearing the flag',leaveAndReenter())
 dumpObjects('cleared')
 -- JohtoIndigoPlateau_Pokecenter_OnTransition re-asserts the flag for any save past Route 27,
 -- so a cleared flag heals on the next entry instead of walling the League off again. That
 -- also covers saves made before the Route 27 fix existed, which would never get its setflag.
 F.check('entering the Plateau re-hides the Black Belt',flag(C.FLAG_HIDE_LEAGUE_BLACKBELT))
 F.check('the door stays reachable after the flag was cleared',not occupied(BELT_X,BELT_Y))
 local reachedP,px,py=climbToDoor()
 F.check('a cleared flag cannot re-block the Elite Four door',reachedP,
   string.format('stopped at (%d,%d)',px,py))
 F.shot('flag_cleared_self_heals')

 F.finish()
end)
