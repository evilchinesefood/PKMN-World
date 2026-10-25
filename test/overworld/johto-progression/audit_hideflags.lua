-- Objects that used to spawn on a fresh save because their hide flag was never registered.
--
-- Same class as the League Black Belt: a FLAG_HIDE_* that no new-game registration set, so it
-- read clear and the object rendered from the first minute. At elevation 0 such an object
-- collides at every elevation, and on a warp tile it seals the warp.
--
-- Johto registers these lazily instead, from a city "flagheap" invoked by coord_events on ONE
-- adjacent route. That leaves two windows: before the trigger fires, and at city entrances the
-- trigger does not cover -- Goldenrod's flagheap is reached only from Route 34, so arriving
-- through the Route 35 gate fired nothing. Both objects below are now registered in
-- src/new_game.c; this suite is the regression guard.
--
-- Each case is discriminating in both directions: the object must be absent on a fresh save,
-- and clearing its flag must bring it back and block again. Without the second half a suite
-- like this passes just as happily against a map with the object deleted.
package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local H=require('audit_helpers')('JohtoHideFlags');local F,S,A,C,tap,cmd,state,flag,finish=H.F,H.S,H.A,H.C,H.tap,H.cmd,H.state,H.flag,H.finish
local maps=require('story_maps')

local function enter(mapName,x,y)
 local m=maps[mapName];cmd(1,m.g,m.m,x,y,300)
 return F.grp()==m.g and F.mapn()==m.m,m
end
local function occupied(x,y)
 for _,o in ipairs(F.objdump()) do if o.x==x and o.y==y then return true,o.i end end
 return false
end
local function dump(tag)
 local l={}
 for _,o in ipairs(F.objdump()) do l[#l+1]=string.format('%d@(%d,%d)',o.i,o.x,o.y) end
 F.L('  objects '..tag..': '..(#l>0 and table.concat(l,' ') or 'none'))
end

F.run(function()
 H.boot()

 -- ---- 1. Radio Tower 1F: the stairs to 2F must be walkable on a fresh save ---------------
 -- warp 1 is (22,5) -> RadioTower_2F and (22,6) directly below is its only approach. A Rocket
 -- grunt stood ON that warp tile, sealing the entire Radio Tower arc for a player who entered
 -- Goldenrod from the north.
 F.L('PROBE radiotower-fresh')
 local ok=enter('GoldenrodCity_RadioTower_1F',22,6)
 F.check('Radio Tower 1F entered',ok)
 dump('radiotower-fresh')
 F.check('FLAG_HIDE_ROCKET_GOLDENROD_RADIOTOWER_1 is registered on a fresh save',
   flag(C.FLAG_HIDE_ROCKET_GOLDENROD_RADIOTOWER_1))
 F.check('no object on the 2F stairs tile',not occupied(22,5))
 local movedFresh=F.step('Up');F.idle(150)
 F.check('the 2F stairs tile can be entered on a fresh save',movedFresh,
   string.format('ended at (%d,%d)',F.pos(),select(2,F.pos())))
 F.shot('radiotower_fresh')

 -- Clear the flag and prove the suite would notice the regression.
 F.L('PROBE radiotower-regression')
 cmd(5,C.FLAG_HIDE_ROCKET_GOLDENROD_RADIOTOWER_1)
 enter('GoldenrodCity_RadioTower_1F',22,6)
 dump('radiotower-regression')
 F.check('clearing the flag puts the grunt back on the stairs',occupied(22,5))
 local movedBroken=F.step('Up');F.idle(150)
 F.check('the grunt blocks the stairs when he spawns',not movedBroken,
   string.format('ended at (%d,%d)',F.pos(),select(2,F.pos())))
 F.shot('radiotower_regression')
 cmd(3,C.FLAG_HIDE_ROCKET_GOLDENROD_RADIOTOWER_1)

 -- ---- 2. Champion's Room: Oak and Mary must not be in the entrance before Lance ----------
 -- Both are script NULL and the victory scene ADDS them with addobject, which only makes sense
 -- if they start absent. Route 27 also hides them before the League on the normal route.
 F.L('PROBE champions-room-fresh')
 F.check('Champion\'s Room entered',(enter('JohtoPokemonLeague_ChampionsRoom',6,17)))
 dump('champions-room-fresh')
 F.check('FLAG_HIDE_INDIGO_PLATEAU_MARY_OAK is registered on a fresh save',
   flag(C.FLAG_HIDE_INDIGO_PLATEAU_MARY_OAK))
 F.check('Oak and Mary are absent before Lance is fought',
   not (occupied(6,16) or occupied(6,15)))
 F.shot('champions_room_fresh')

 F.L('PROBE champions-room-regression')
 cmd(5,C.FLAG_HIDE_INDIGO_PLATEAU_MARY_OAK)
 enter('JohtoPokemonLeague_WillsRoom',6,10)
 enter('JohtoPokemonLeague_ChampionsRoom',6,17)
 dump('champions-room-regression')
 F.check('clearing the flag puts Oak and Mary back in the entrance',
   occupied(6,16) or occupied(6,15))
 F.shot('champions_room_regression')

 F.finish()
end)
