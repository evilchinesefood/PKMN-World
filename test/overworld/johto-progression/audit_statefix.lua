-- Four progression defects raised by the static audits, reproduced before being fixed.
--
-- Each case stages a legitimate mid-story state, performs the ordinary player action, and reads
-- the variable the story depends on afterwards. PW_STATEFIX_EXPECT=broken asserts the defect is
-- present (used to prove the suite reproduces it); the default asserts the fixed behaviour.
--
--   pryce      MahoganyTown_Gym's victory sets VAR_MAHOGANY_TOWN_STATE = 15 unconditionally.
--              The gym door's approach tile is in the town's main walkable component from the
--              start, so Pryce can be beaten mid-hideout -- and states 5..13, the entire Rocket
--              Hideout arc, are dispatched by exact equality and become dead.
--   electrode  REFUTED as a defect, kept as the guard for why. removeobject FlagSets the
--              object's own hide flag, so beaten Electrodes stay gone and the count cannot
--              overshoot the completion trigger's exact == 3 match.
--   ssaqua     Sailor Stanly set VAR_SSAQUA_STATE = 3 unconditionally. From state 5 -- reached
--              by visiting the Captain's Room first, which the Grandpa quest points at -- that
--              is a regression into a state nothing can advance, with the door sailor refusing
--              to let the player off the ship. (He does NOT respawn: removeobject sets his
--              hide flag. That half of the report did not hold.)
--   ilex       Six Ilex Forest objects sit behind flags the Azalea flagheap sets but no
--              new-game registration does, three of them in one-tile-wide corridors.
package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local H=require('audit_helpers')('JohtoStateFix');local F,S,A,C,tap,cmd,state,flag,finish=H.F,H.S,H.A,H.C,H.tap,H.cmd,H.state,H.flag,H.finish
local maps=require('story_maps');local gyms=require('gym_cases')
local BROKEN=os.getenv('PW_STATEFIX_EXPECT')=='broken'

local function want(name,actualFixed,actualBroken,got)
 -- One assertion, phrased for whichever behaviour this run expects.
 local target=BROKEN and actualBroken or actualFixed
 return F.check(name..(BROKEN and ' (reproducing the defect)' or ''),got==target,
   string.format('got %s, wanted %s',tostring(got),tostring(target)))
end
local function enter(n,x,y)
 local m=maps[n];cmd(1,m.g,m.m,x or m.x,y or m.y,300)
 return F.grp()==m.g and F.mapn()==m.m
end
local function occupied(x,y)
 for _,o in ipairs(F.objdump()) do if o.x==x and o.y==y then return true end end
 return false
end

local cases={}

cases.pryce=function()
 -- Mid-hideout: the player has raided the shop (5) but not finished the generator (14).
 cmd(4,C.VAR_MAHOGANY_TOWN_STATE,5)
 local c=gyms[7]  -- Pryce
 cmd(1,c.g,c.m,c.x,c.y,360)
 if not F.check('positioned beside Pryce',F.grp()==c.g and F.mapn()==c.m) then return end
 F.face('Up');tap('A')
 local ok,n=finish(1200)
 F.check('Pryce is a battle',n and n==1)
 F.check('Pryce victory script finishes',ok)
 F.check('Glacier Badge awarded',flag(C.FLAG_JOHTO_BADGE_7))
 F.L('  VAR_MAHOGANY_TOWN_STATE after Pryce = '..state(C.VAR_MAHOGANY_TOWN_STATE))
 want('beating Pryce mid-hideout leaves the hideout arc intact',5,15,state(C.VAR_MAHOGANY_TOWN_STATE))
end

cases.electrode=function()
 -- The static audit predicted the three Electrodes respawn, letting VAR_ELECTRODES_FAINTED
 -- overshoot the completion trigger's exact == 3 match. That does NOT hold: removeobject goes
 -- through RemoveObjectEventByLocalIdAndMap, which FlagSets the object's own hide flag
 -- (src/event_object_movement.c:1713), so a beaten Electrode stays gone. The only writer that
 -- could clear those flags again is Mahogany's flagheap, which is gated on town state 0 and
 -- cannot re-run. So the overshoot is not naturally reachable.
 --
 -- What this case guards is the fact the conclusion rests on: beating an Electrode must set its
 -- hide flag. If that ever stops being true, the overshoot becomes reachable and the player is
 -- stranded with no HM and no state 14, while OnLoad's >= 4 check makes the room look finished.
 cmd(4,C.VAR_MAHOGANY_TOWN_STATE,13)
 cmd(4,C.VAR_ELECTRODES_FAINTED,0)
 for _,f in ipairs({'FLAG_HIDE_ROCKETHIDEOUT_ELECTRODE1','FLAG_HIDE_ROCKETHIDEOUT_ELECTRODE2',
                    'FLAG_HIDE_ROCKETHIDEOUT_ELECTRODE3'}) do cmd(5,(assert(C[f],f))) end
 if not F.check('Rocket Hideout B2F entered',enter('MahoganyHideout_B2F',11,10)) then return end
 F.check('an Electrode is present before the battle',occupied(11,9))
 F.face('Up');tap('A')
 finish(1200)
 F.L('  VAR_ELECTRODES_FAINTED='..state(C.VAR_ELECTRODES_FAINTED)
   ..' hideFlag1='..tostring(flag(C.FLAG_HIDE_ROCKETHIDEOUT_ELECTRODE1)))
 F.check('the count advanced by exactly one',state(C.VAR_ELECTRODES_FAINTED)==1,
   'count='..state(C.VAR_ELECTRODES_FAINTED))
 F.check('a beaten Electrode sets its hide flag, so it cannot respawn',
   flag(C.FLAG_HIDE_ROCKETHIDEOUT_ELECTRODE1))
end

cases.ssaqua=function()
 -- State 5: the granddaughter is found and the door sailor will let the player off.
 cmd(4,C.VAR_SSAQUA_STATE,5)
 if not F.check('S.S. Aqua Room NW entered',enter('SSAqua_RoomNW',2,7)) then return end
 F.face('Up');tap('A')
 finish(1200)
 F.L('  VAR_SSAQUA_STATE after Stanly = '..state(C.VAR_SSAQUA_STATE))
 want('beating Stanly does not rewind the voyage',5,3,state(C.VAR_SSAQUA_STATE))
 F.check('Stanly stays gone after the battle',flag(C.FLAG_HIDE_SSAQUA_SAILOR))
end

cases.ilex=function()
 -- Arriving from the Route 34 side, before Azalea's flagheap has ever fired.
 if not F.check('Ilex Forest entered',enter('IlexForest',42,41)) then return end
 local present=occupied(42,39)
 F.L('  object at the (42,39) corridor: '..tostring(present))
 want('no stray object in the Ilex corridor on a fresh save',false,true,present)
 F.check('FLAG_HIDE_ILEX_FOREST_FARFETCHD_2 registered at new game',
   BROKEN or flag(C.FLAG_HIDE_ILEX_FOREST_FARFETCHD_2))
end

-- Finishing the hideout must open the Radio Tower in BOTH orders. Mahoganytown's ON_FRAME
-- Rocket call matches VAR_MAHOGANY_TOWN_STATE == 15 exactly, and Pryce now only writes 15 from
-- state >= 14 -- so without the badge-aware advance in ElectrodeDone, a player who beat Pryce
-- early would finish the hideout at 14 and never reach the Radio Tower. That would be a worse
-- softlock than the clobber this set out to fix, so it is asserted directly.
local function hideoutFinale(withBadge)
 cmd(4,C.VAR_MAHOGANY_TOWN_STATE,13)
 cmd(4,C.VAR_ELECTRODES_FAINTED,3)
 cmd(5,(assert(C.FLAG_HIDE_ROCKETHIDEOUT2_LANCE_DRAGONITE)))
 if withBadge then cmd(3,(assert(C.FLAG_JOHTO_BADGE_7))) else cmd(5,(assert(C.FLAG_JOHTO_BADGE_7))) end
 if not F.check('Rocket Hideout B2F entered',enter('MahoganyHideout_B2F',13,17)) then return end
 F.step('Right')
 local ok=finish(2000)
 F.check('generator finale finishes',ok)
 F.L(string.format('  badge=%s -> VAR_MAHOGANY_TOWN_STATE=%d',
   tostring(withBadge),state(C.VAR_MAHOGANY_TOWN_STATE)))
 return state(C.VAR_MAHOGANY_TOWN_STATE)
end

cases['hideout-then-pryce']=function()
 -- Normal order: hideout first, so the town stops at 14 and Pryce supplies 15.
 -- 14 both before and after the fix: without the badge nothing changed on this path.
 want('hideout completion leaves the town at 14 without the badge',14,14,hideoutFinale(false))
end

cases['pryce-then-hideout']=function()
 -- Reverse order: Pryce already beaten, so completion must jump to 15 itself or the Radio
 -- Tower trigger can never fire.
 -- On the unfixed build ElectrodeDone writes 14 regardless of the badge, so this case needs
 -- its broken-mode expectation like the others, or a full PW_STATEFIX_EXPECT=broken run fails
 -- on the very defect it is meant to reproduce.
 want('hideout completion reaches 15 when the Glacier Badge is already held',15,14,
   hideoutFinale(true))
end

F.run(function()
 local only=os.getenv('PW_STATEFIX_CASE')
 for _,n in ipairs({'pryce','hideout-then-pryce','pryce-then-hideout','electrode','ssaqua','ilex'}) do
  if not only or only==n then
   F.L('CASE '..n)
   client.reboot_core();F.idle(120);H.boot()
   cases[n]()
   F.shot(n)
  end
 end
 F.finish()
end)
