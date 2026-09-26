-- The actual unpatched development ROM and prepared synthetic save, driven only
-- through normal inputs. The imported controller address is read-only.
package.path=assert(os.getenv('PW_PROBE_LIB'))..'/?.lua;'..package.path
local S=require('symbols');local U=require('bw_symbols');local F=require('lib').new(S,'BattlePaletteDelivery')
local function tap(key,delay) F.press(key,4);F.idle(delay or 60) end
local function commands()
 return F.cb2()==U.BattleMainCB2 and (F.r32(U.gBattlerControllerFuncs)&~1)==(U.HandleInputChooseAction&~1)
end
F.run(function()
 F.check('prepared save boots into Ice Path',F.boot(94) and F.mapn()==7);F.shot('ready_to_play')
 F.check('prepared party has six members',F.r8(S.gPartiesCount)==6)
 F.check('normal movement works',F.step('Up'))
 local encounter=false
 for i=1,150 do
  if F.cb2()~=S.CB2_Overworld then encounter=true;break end
  F.step(i%2==0 and 'Up' or 'Down');F.idle(20)
 end
 F.check('walking starts a natural encounter',encounter)
 for i=1,300 do if commands() then break end;tap('A',15) end
 F.check('natural encounter reaches commands',commands());F.shot('natural_battle')
 if commands() then
  tap('A');tap('L');F.shot('original_l_window');tap('L');tap('B')
  local cursor=F.r8(S.gActionSelectionCursor)
  if cursor&1==0 then tap('Right') end
  if cursor&2==0 then tap('Down') end
  tap('A',240)
  for i=1,100 do if F.ow() then break end;tap('A',15) end
  F.check('normal Run returns to Ice Path',F.ow())
 end
 F.finish()
end)
