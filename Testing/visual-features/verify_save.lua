-- Verify the generated save against the unmodified delivery ROM.
package.path=assert(os.getenv('PW_PROBE_LIB'))..'/?.lua;'..package.path
local S=require('symbols')
local F=require('lib').new(S,'VisualReviewSave')
F.run(function()
  assert(F.check('prepared save boots',F.boot(0)))
  F.check('Petalburg loaded',F.grp()==0 and F.mapn()==0)
  F.check('normal overworld callback',F.ow())
  F.shot('prepared_day_pond')
  local x,y=F.pos();F.step('Up');F.idle(60)
  local nx,ny=F.pos()
  F.check('player can walk normally',x~=nx or y~=ny)
  F.press('Start',8);F.idle(90)
  local st=F.r32(S.sUsmState)
  F.check('normal start wheel opens',st>=0x02000000 and st<0x02040000)
  F.press('Select',8);F.idle(90);F.shot('prepared_wheel_move')
  F.check('move mode opens',F.r32(st+24)==1)
  F.press('Select',8);F.idle(90)
  F.check('Done returns to normal mode',F.r32(st+24)==0)
  for i=1,4 do
    F.press('B',8);F.idle(90)
    if F.ow() and F.ensureFree() then break end
  end
  -- sUsmState is an alias into the released menu allocation and is not nulled.
  F.check('wheel closes normally',F.ow() and F.ensureFree())
  F.finish()
end)
